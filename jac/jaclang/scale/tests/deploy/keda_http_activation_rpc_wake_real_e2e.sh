#!/usr/bin/env bash
# Real-cluster e2e proving jac-scale routes traffic to a scaled-to-zero
# HTTP-activated microservice through the KEDA HTTP Add-on interceptor
# automatically, with no manually-set Host header anywhere in this script --
# unlike the sibling keda_http_activation_real_e2e.sh, which curls the
# interceptor proxy directly with a hand-set Host header to prove the KEDA
# HTTP Add-on itself works once routed to correctly.
#
# Deploys a two-service app (app.jac at the gateway root, worker.jac
# HTTP-activated) via `jac scale deploy`, confirms the InterceptorRoute +
# ScaledObject reconcile to Ready, then proves BOTH traffic patterns wake
# `worker` from zero replicas:
#   1. an external request straight at the gateway's own Service
#      (POST /worker/walker/ping) -- exercises the gateway's HTTP-forward
#      path (microservice_gateway.impl.jac)
#   2. an internal sv-to-sv RPC call from `app` (POST /walker/trigger_ping,
#      whose handler calls worker.ping()) -- exercises the separate RPC path
#      (rpc.jac)
# waiting out the cooldown and confirming scale-back to zero after each.
# Requires KEDA core + the HTTP Add-on already installed on the target
# cluster (this script does not install them -- see README.md in the
# fixture dir for the `helm install` invocations).

set -euo pipefail

# shellcheck source=../../scripts/e2e_lib.sh
source "$(cd "$(dirname "$0")/../../scripts" && pwd)/e2e_lib.sh"
e2e_timing_init

FIXTURE_DIR="${1:-$(cd "$(dirname "$0")/../fixtures/keda_http_activation_rpc_wake_e2e" && pwd)}"
if [ ! -f "${FIXTURE_DIR}/jac.toml" ]; then
    echo "FAIL: ${FIXTURE_DIR}/jac.toml not found" >&2
    echo "Usage: $0 [FIXTURE_DIR]" >&2
    exit 1
fi

# See the sibling script for why this exists: the manifest builder requires
# an explicit RWX-capable bundle_storage_class, and most cloud defaults are
# ReadWriteOnce-only.
if [ -n "${BUNDLE_STORAGE_CLASS:-}" ]; then
    python3 - "${FIXTURE_DIR}/jac.toml" "${BUNDLE_STORAGE_CLASS}" <<'PYEOF'
import sys

path, storage_class = sys.argv[1], sys.argv[2]
with open(path) as f:
    lines = f.readlines()
out, in_k8s, done = [], False, False
for line in lines:
    stripped = line.strip()
    if stripped.startswith("["):
        in_k8s = stripped == "[scale.kubernetes]"
    if in_k8s and stripped.startswith("bundle_storage_class"):
        continue
    out.append(line)
    if in_k8s and not done and stripped == "[scale.kubernetes]":
        out.append(f'bundle_storage_class = "{storage_class}"\n')
        done = True
with open(path, "w") as f:
    f.writelines(out)
PYEOF
fi

CFG=$(cd "${FIXTURE_DIR}" && jac -c "
import tomllib
with open('jac.toml', 'rb') as f:
    cfg = tomllib.load(f)
k8s = cfg['scale']['kubernetes']
act = cfg['apps']['worker']['scale']['http_activation']
# Touching act['rules'][0]['hosts'][0] here (unused otherwise -- this script
# never sets a Host header) validates the fixture's rules block is shaped as
# expected, failing loudly here rather than as a later, cryptic kubectl error.
_ = act['rules'][0]['hosts'][0]
print(k8s.get('namespace', 'default'))
print(act.get('polling_interval', 30))
print(act.get('cooldown_period', 300))
")
NAMESPACE=$(echo "${CFG}" | sed -n '1p')
POLLING_INTERVAL=$(echo "${CFG}" | sed -n '2p')
COOLDOWN_PERIOD=$(echo "${CFG}" | sed -n '3p')

# The scale target that actually scales to zero -- unlike the sibling
# fixture (a monolith where the one app IS the scale target), here it's
# specifically `worker`; `app` stays warm and always-on.
SCALE_TARGET="worker-deployment"

DELETE_TIMEOUT="${DELETE_TIMEOUT:-120}"
READY_TIMEOUT="${READY_TIMEOUT:-180}"
SCALE_DOWN_TIMEOUT="${SCALE_DOWN_TIMEOUT:-$(( COOLDOWN_PERIOD + POLLING_INTERVAL * 3 + 30 ))}"

echo "=== preflight: KEDA HTTP Add-on CRDs ==="
if ! kubectl get crd interceptorroutes.http.keda.sh >/dev/null 2>&1; then
    echo "FAIL: interceptorroutes.http.keda.sh CRD not found on cluster." >&2
    echo "Install KEDA + the HTTP Add-on first, e.g.:" >&2
    echo "  helm repo add kedacore https://kedacore.github.io/charts && helm repo update" >&2
    echo "  helm install keda kedacore/keda -n keda --create-namespace --wait" >&2
    echo "  helm install http-add-on kedacore/keda-add-ons-http -n keda --wait" >&2
    exit 1
fi

PORT_FORWARD_LOG=""
dump_state() {
    echo "--- diagnostics (namespace=${NAMESPACE}) ---"
    kubectl get pods -n "${NAMESPACE}" -o wide || true
    kubectl describe pods -n "${NAMESPACE}" || true
    kubectl get events -n "${NAMESPACE}" --sort-by=.lastTimestamp || true
    kubectl logs -n "${NAMESPACE}" -l "managed=jac-scale" --tail=200 --all-containers=true || true
    kubectl describe interceptorroute "${SCALE_TARGET}-http-route" -n "${NAMESPACE}" || true
    kubectl describe scaledobject "${SCALE_TARGET}-http-scaledobject" -n "${NAMESPACE}" || true
    echo "--- HTTP Add-on component logs (namespace=keda) ---"
    kubectl logs -n keda -l app=keda-add-ons-http-interceptor --tail=100 || true
    kubectl logs -n keda -l app=keda-add-ons-http-external-scaler --tail=100 || true
    if [ -n "${PORT_FORWARD_LOG}" ] && [ -f "${PORT_FORWARD_LOG}" ]; then
        echo "--- kubectl port-forward output ---"
        cat "${PORT_FORWARD_LOG}" || true
    fi
}

PORT_FORWARD_PID=""
cleanup() {
    rc="${1:-0}"
    echo "=== cleanup (rc=${rc}) ==="
    if [ -n "${PORT_FORWARD_PID}" ]; then
        kill "${PORT_FORWARD_PID}" 2>/dev/null || true
    fi
    if [ -n "${PORT_FORWARD_LOG}" ]; then
        rm -f "${PORT_FORWARD_LOG}"
    fi
    if [ "${rc}" != "0" ] && [ "${E2E_KEEP_NS_ON_FAIL:-1}" = "1" ]; then
        echo "=== e2e failed (rc=${rc}); KEEPING namespace '${NAMESPACE}' for inspection (set E2E_KEEP_NS_ON_FAIL=0 to force cleanup) ==="
        return
    fi
    kubectl delete namespace "${NAMESPACE}" --ignore-not-found --timeout="${DELETE_TIMEOUT}s" || true
}
trap 'cleanup "$?"' EXIT

wait_for_ready() {
    kind="$1"
    name="$2"
    elapsed=0
    while [ "${elapsed}" -lt "${READY_TIMEOUT}" ]; do
        status=$(kubectl get "${kind}" "${name}" -n "${NAMESPACE}" \
            -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
        if [ "${status}" = "True" ]; then
            echo "  ${kind}/${name} Ready"
            return 0
        fi
        sleep 2
        elapsed=$(( elapsed + 2 ))
    done
    echo "FAIL: ${kind}/${name} did not report Ready within ${READY_TIMEOUT}s (last status: '${status}')" >&2
    kubectl get "${kind}" "${name}" -n "${NAMESPACE}" -o yaml >&2 || true
    return 1
}

# Sends `request`, waits for `worker` to become Available, stops traffic,
# then waits out the cooldown and confirms it scales back to zero. Shared by
# both the external and internal-RPC wake tests below -- only how the
# request is sent differs between them.
wake_and_verify_scale_cycle() {
    label="$1"
    _t "${label}: send request"
    RESP_BODY_FILE="$(mktemp)"
    RESP_CODE=$(curl -s -o "${RESP_BODY_FILE}" -w "%{http_code}" \
        --max-time "${READY_TIMEOUT}" \
        -X POST \
        "http://localhost:${GATEWAY_LOCAL_PORT}${2}" || echo "000")
    if [ "${RESP_CODE}" != "200" ]; then
        echo "FAIL: ${label} request to '${2}' returned '${RESP_CODE}' (expected 200) within ${READY_TIMEOUT}s" >&2
        dump_state
        rm -f "${RESP_BODY_FILE}"
        exit 1
    fi
    echo "  ${label}: gateway responded 200: $(cat "${RESP_BODY_FILE}")"
    rm -f "${RESP_BODY_FILE}"

    _t "${label}: wait for readiness"
    if ! kubectl wait --for=condition=Available "deployment/${SCALE_TARGET}" \
            -n "${NAMESPACE}" --timeout="${READY_TIMEOUT}s"; then
        echo "FAIL: worker did not become Available within ${READY_TIMEOUT}s after ${label}" >&2
        dump_state
        exit 1
    fi
    READY_REPLICAS=$(kubectl get deployment "${SCALE_TARGET}" -n "${NAMESPACE}" \
        -o jsonpath='{.status.readyReplicas}')
    echo "  ${label}: worker readyReplicas=${READY_REPLICAS}"

    _t "${label}: wait for scale-down after cooldown"
    SCALED_DOWN=0
    ELAPSED=0
    while [ "${ELAPSED}" -lt "${SCALE_DOWN_TIMEOUT}" ]; do
        sleep "${POLLING_INTERVAL}"
        ELAPSED=$(( ELAPSED + POLLING_INTERVAL ))
        CURRENT_REPLICAS=$(kubectl get deployment "${SCALE_TARGET}" -n "${NAMESPACE}" \
            -o jsonpath='{.spec.replicas}')
        echo "  ${label}: +${ELAPSED}s replicas=${CURRENT_REPLICAS}"
        if [ "${CURRENT_REPLICAS}" = "0" ]; then
            SCALED_DOWN=1
            break
        fi
    done
    if [ "${SCALED_DOWN}" != "1" ]; then
        echo "FAIL: worker did not scale back to 0 within ${SCALE_DOWN_TIMEOUT}s of cooldown after ${label}" >&2
        dump_state
        exit 1
    fi
    echo "  ${label}: scaled back to 0"
}

_t "deploy start"
echo "=== deploy via jac scale deploy (microservices mode; worker is HTTP-activated) ==="
if ! (cd "${FIXTURE_DIR}" && jac scale deploy app.jac); then
    echo "FAIL: deploy failed" >&2
    dump_state
    exit 1
fi

_t "redeploy (idempotency check)"
echo "=== redeploy: confirms InterceptorRoute + ScaledObject reconcile is idempotent ==="
if ! (cd "${FIXTURE_DIR}" && jac scale deploy app.jac); then
    echo "FAIL: redeploy failed" >&2
    dump_state
    exit 1
fi

_t "wait for InterceptorRoute + ScaledObject Ready"
echo "=== confirm InterceptorRoute and ScaledObject reconciled to Ready ==="
if ! wait_for_ready interceptorroute "${SCALE_TARGET}-http-route"; then
    dump_state
    exit 1
fi
if ! wait_for_ready scaledobject "${SCALE_TARGET}-http-scaledobject"; then
    dump_state
    exit 1
fi

_t "wait for worker to reach 0 replicas before the first wake test"
echo "=== a fresh deploy starts worker at 1 replica; confirm KEDA has scaled it to 0 ==="
echo "    before test 1, or that test would pass even with broken interceptor routing ==="
SCALED_DOWN=0
ELAPSED=0
while [ "${ELAPSED}" -lt "${SCALE_DOWN_TIMEOUT}" ]; do
    CURRENT_REPLICAS=$(kubectl get deployment "${SCALE_TARGET}" -n "${NAMESPACE}" \
        -o jsonpath='{.spec.replicas}')
    if [ "${CURRENT_REPLICAS}" = "0" ]; then
        SCALED_DOWN=1
        break
    fi
    sleep "${POLLING_INTERVAL}"
    ELAPSED=$(( ELAPSED + POLLING_INTERVAL ))
    echo "  +${ELAPSED}s replicas=${CURRENT_REPLICAS}"
done
if [ "${SCALED_DOWN}" != "1" ]; then
    echo "FAIL: worker did not reach 0 replicas within ${SCALE_DOWN_TIMEOUT}s of the initial deploy" >&2
    dump_state
    exit 1
fi
echo "  worker is at 0 replicas"

_t "port-forward gateway"
echo "=== port-forward the gateway's own Service (not the interceptor) ==="
GATEWAY_LOCAL_PORT="${GATEWAY_LOCAL_PORT:-18081}"
PORT_FORWARD_LOG="$(mktemp)"
kubectl port-forward -n "${NAMESPACE}" svc/gateway-service \
    "${GATEWAY_LOCAL_PORT}:8000" >"${PORT_FORWARD_LOG}" 2>&1 &
PORT_FORWARD_PID=$!
sleep 2
if ! kill -0 "${PORT_FORWARD_PID}" 2>/dev/null; then
    echo "FAIL: kubectl port-forward exited immediately (port ${GATEWAY_LOCAL_PORT} in use?)" >&2
    cat "${PORT_FORWARD_LOG}" >&2
    PORT_FORWARD_PID=""
    exit 1
fi

echo "=== test 1/2: external request straight at the gateway wakes worker ==="
echo "    (no Host header set here -- the gateway must resolve and set it itself)"
wake_and_verify_scale_cycle "external-wake" "/worker/walker/ping"

echo "=== test 2/2: internal sv-to-sv RPC call from app wakes worker ==="
wake_and_verify_scale_cycle "rpc-wake" "/walker/trigger_ping"

kill "${PORT_FORWARD_PID}" 2>/dev/null || true
PORT_FORWARD_PID=""

_t "ALL DONE"
echo "=== KEDA HTTP activation automatic-routing REAL e2e PASSED ==="
