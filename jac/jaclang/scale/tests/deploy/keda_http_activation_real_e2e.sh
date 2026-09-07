#!/usr/bin/env bash
# Real-cluster e2e for jac-scale KEDA HTTP Add-on activation (#7403/#7421),
# deployed through the jac.toml [scale.kubernetes.http_activation] wiring
# (#7475) instead of calling KEDAAutoscaler.apply_http_activation directly.
#
# Deploys the fixture app via `jac scale deploy`, confirms the resulting
# InterceptorRoute + ScaledObject reconcile to Ready, sends an HTTP request
# through the KEDA HTTP Add-on interceptor (should block on cold start, then
# respond), waits for the target to scale 0 -> 1 and become Available, then
# confirms it scales back to zero after cooldown. Requires KEDA core + the
# HTTP Add-on already installed on the target cluster (this script does not
# install them -- see README.md in the fixture dir for the `helm install`
# invocations).

set -euo pipefail

# shellcheck source=../../scripts/e2e_lib.sh
source "$(cd "$(dirname "$0")/../../scripts" && pwd)/e2e_lib.sh"
e2e_timing_init

FIXTURE_DIR="${1:-$(cd "$(dirname "$0")/../fixtures/keda_http_activation_e2e" && pwd)}"
if [ ! -f "${FIXTURE_DIR}/jac.toml" ]; then
    echo "FAIL: ${FIXTURE_DIR}/jac.toml not found" >&2
    echo "Usage: $0 [FIXTURE_DIR]" >&2
    exit 1
fi

# The manifest builder refuses to guess a RWX-capable StorageClass for the
# bundle PVC (see manifest_builder.jac): most cloud defaults are
# ReadWriteOnce-only, so it now requires bundle_storage_class set explicitly
# rather than trusting the cluster default. Local/kind runs edit jac.toml by
# hand per the fixture README; a CI lane on a different cluster type sets
# BUNDLE_STORAGE_CLASS instead, applied here so the file itself stays
# cluster-agnostic.
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
proj = cfg['project']
k8s = cfg['scale']['kubernetes']
act = k8s['http_activation']
print(proj['name'])
print(k8s.get('namespace', 'default'))
print(act['rules'][0]['hosts'][0])
print(act.get('polling_interval', 30))
print(act.get('cooldown_period', 300))
")
APP_NAME=$(echo "${CFG}" | sed -n '1p')
# The unified deploy path names every workload "<app>-deployment" (even a solo
# app behind its gateway), and the KEDA InterceptorRoute/ScaledObject are named
# after that scale target, so they are "<app>-deployment-http-{route,scaledobject}".
SCALE_TARGET="${APP_NAME}-deployment"
NAMESPACE=$(echo "${CFG}" | sed -n '2p')
ROUTE_HOST=$(echo "${CFG}" | sed -n '3p')
POLLING_INTERVAL=$(echo "${CFG}" | sed -n '4p')
COOLDOWN_PERIOD=$(echo "${CFG}" | sed -n '5p')

# Bare seconds, like every other *_TIMEOUT var here -- "s" is appended at the
# call site. kubectl's --timeout requires a unit suffix (e.g. "120s"); baking
# it into the default here would make DELETE_TIMEOUT the only timeout var
# that breaks if overridden with a bare integer like the rest.
DELETE_TIMEOUT="${DELETE_TIMEOUT:-120}"
# A real jac-scale pod's cold start runs jac-pvc-bootstrap + jac-bootstrap
# init containers (installing deps, first-run compile) before it's Ready -
# tens of seconds, not the near-instant start of a bare container image. 90s
# (right for the old fixture.yaml's http-echo image) was too tight for that;
# 180s gives real headroom while still failing fast on an actual hang.
READY_TIMEOUT="${READY_TIMEOUT:-180}"
# Bound the scale-down wait comfortably above cooldown + three poll ticks so a
# real hang fails loudly instead of the script exiting early on a fluke.
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
    kubectl logs -n "${NAMESPACE}" -l "app=${APP_NAME}" --tail=200 --all-containers=true || true
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
    # Deleting the namespace sweeps the Deployment/Service and the namespaced
    # InterceptorRoute/ScaledObject together; no separate destroy call needed.
    kubectl delete namespace "${NAMESPACE}" --ignore-not-found --timeout="${DELETE_TIMEOUT}s" || true
}
trap 'cleanup "$?"' EXIT

# Polls a resource's status.conditions[type=Ready].status, per the HTTP
# Add-on's own "Autoscale an App" verify step (kubectl get <kind> <name> and
# check the READY column) -- done here as a jsonpath poll instead so the
# script can fail fast on the actual condition rather than timing out later
# on an interceptor request that can never succeed.
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

_t "deploy start"
echo "=== deploy via jac scale deploy (jac.toml [scale.kubernetes.http_activation] wiring) ==="
if ! (cd "${FIXTURE_DIR}" && jac scale deploy app.jac); then
    echo "FAIL: deploy failed" >&2
    dump_state
    exit 1
fi

_t "redeploy (idempotency check)"
echo "=== redeploy: confirms InterceptorRoute + ScaledObject reconcile is idempotent (get-then-patch, not create-or-duplicate) ==="
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

_t "port-forward interceptor"
echo "=== port-forward the HTTP Add-on interceptor ==="
INTERCEPTOR_LOCAL_PORT="${INTERCEPTOR_LOCAL_PORT:-18080}"
PORT_FORWARD_LOG="$(mktemp)"
kubectl port-forward -n keda svc/keda-add-ons-http-interceptor-proxy \
    "${INTERCEPTOR_LOCAL_PORT}:8080" >"${PORT_FORWARD_LOG}" 2>&1 &
PORT_FORWARD_PID=$!
sleep 2
if ! kill -0 "${PORT_FORWARD_PID}" 2>/dev/null; then
    echo "FAIL: kubectl port-forward exited immediately (port ${INTERCEPTOR_LOCAL_PORT} in use?)" >&2
    cat "${PORT_FORWARD_LOG}" >&2
    PORT_FORWARD_PID=""
    exit 1
fi

_t "send activating request"
echo "=== send HTTP request through the interceptor (should block on cold start, then respond) ==="
RESP_BODY_FILE="$(mktemp)"
RESP_CODE=$(curl -s -o "${RESP_BODY_FILE}" -w "%{http_code}" \
    --max-time "${READY_TIMEOUT}" \
    -X POST \
    -H "Host: ${ROUTE_HOST}" \
    "http://localhost:${INTERCEPTOR_LOCAL_PORT}/walker/echo" || echo "000")
if [ "${RESP_CODE}" != "200" ]; then
    echo "FAIL: interceptor request returned '${RESP_CODE}' (expected 200) within ${READY_TIMEOUT}s" >&2
    dump_state
    rm -f "${RESP_BODY_FILE}"
    exit 1
fi
echo "  interceptor responded 200: $(cat "${RESP_BODY_FILE}")"
rm -f "${RESP_BODY_FILE}"

_t "wait for readiness"
echo "=== confirm the target scaled 0 -> 1 and became Ready ==="
if ! kubectl wait --for=condition=Available "deployment/${SCALE_TARGET}" \
        -n "${NAMESPACE}" --timeout="${READY_TIMEOUT}s"; then
    echo "FAIL: ${APP_NAME} did not become Available within ${READY_TIMEOUT}s" >&2
    dump_state
    exit 1
fi
READY_REPLICAS=$(kubectl get deployment "${SCALE_TARGET}" -n "${NAMESPACE}" \
    -o jsonpath='{.status.readyReplicas}')
echo "  ${APP_NAME} readyReplicas=${READY_REPLICAS}"

kill "${PORT_FORWARD_PID}" 2>/dev/null || true
PORT_FORWARD_PID=""

_t "wait for scale-down after cooldown"
echo "=== stop traffic; wait up to ${SCALE_DOWN_TIMEOUT}s for scale-down after ${COOLDOWN_PERIOD}s cooldown ==="
SCALED_DOWN=0
ELAPSED=0
while [ "${ELAPSED}" -lt "${SCALE_DOWN_TIMEOUT}" ]; do
    sleep "${POLLING_INTERVAL}"
    ELAPSED=$(( ELAPSED + POLLING_INTERVAL ))
    CURRENT_REPLICAS=$(kubectl get deployment "${SCALE_TARGET}" -n "${NAMESPACE}" \
        -o jsonpath='{.spec.replicas}')
    echo "  +${ELAPSED}s replicas=${CURRENT_REPLICAS}"
    if [ "${CURRENT_REPLICAS}" = "0" ]; then
        SCALED_DOWN=1
        break
    fi
done
if [ "${SCALED_DOWN}" != "1" ]; then
    echo "FAIL: ${APP_NAME} did not scale back to 0 within ${SCALE_DOWN_TIMEOUT}s of cooldown" >&2
    dump_state
    exit 1
fi
echo "  scaled back to 0"

_t "ALL DONE"
echo "=== KEDA HTTP activation REAL e2e PASSED ==="
