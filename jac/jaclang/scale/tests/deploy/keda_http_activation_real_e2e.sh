#!/usr/bin/env bash
# Real-cluster e2e for jac-scale KEDA HTTP Add-on activation (#7403/#7421).
#
# Starts from a zero-replica Deployment, applies HTTP activation twice (create
# then patch, to exercise both branches of apply_http_activation against a
# real API server), sends an HTTP request through the KEDA HTTP Add-on
# interceptor, waits for the target to become Ready, then confirms it scales
# back to zero after cooldown. Requires KEDA core + the HTTP Add-on already
# installed on the target cluster (this script does not install them -- see
# README.md in the fixture dir / the CI step that calls this script for the
# `helm install` invocations).

set -euo pipefail

FIXTURE_DIR="${1:-$(cd "$(dirname "$0")/../fixtures/keda_http_activation_e2e" && pwd)}"
if [ ! -f "${FIXTURE_DIR}/fixture.yaml" ]; then
    echo "FAIL: ${FIXTURE_DIR}/fixture.yaml not found" >&2
    echo "Usage: $0 [FIXTURE_DIR]" >&2
    exit 1
fi

# This script lives at jac/jaclang/scale/tests/deploy/, so the repo root is
# five levels up.
REPO_ROOT="$(cd "$(dirname "$0")/../../../../.." && pwd)"
DRIVER="${REPO_ROOT}/jac/jaclang/scale/tests/deploy/keda_http_activation_verify.jac"
if [ ! -f "${DRIVER}" ]; then
    echo "FAIL: driver script not found at ${DRIVER}" >&2
    exit 1
fi

export KEDA_HTTP_E2E_NAMESPACE="${KEDA_HTTP_E2E_NAMESPACE:-jac-http-e2e}"
export KEDA_HTTP_E2E_DEPLOYMENT="${KEDA_HTTP_E2E_DEPLOYMENT:-echo}"
export KEDA_HTTP_E2E_SERVICE="${KEDA_HTTP_E2E_SERVICE:-echo-svc}"
export KEDA_HTTP_E2E_ROUTE_HOST="${KEDA_HTTP_E2E_ROUTE_HOST:-echo.jac-http-e2e.local}"
export KEDA_HTTP_E2E_POLLING_INTERVAL="${KEDA_HTTP_E2E_POLLING_INTERVAL:-10}"
export KEDA_HTTP_E2E_COOLDOWN_PERIOD="${KEDA_HTTP_E2E_COOLDOWN_PERIOD:-60}"
NAMESPACE="${KEDA_HTTP_E2E_NAMESPACE}"
DEPLOYMENT="${KEDA_HTTP_E2E_DEPLOYMENT}"
# Bare seconds, like every other *_TIMEOUT var here -- "s" is appended at the
# call site. kubectl's --timeout requires a unit suffix (e.g. "120s"); baking
# it into the default here would make DELETE_TIMEOUT the only timeout var
# that breaks if overridden with a bare integer like the rest.
DELETE_TIMEOUT="${DELETE_TIMEOUT:-120}"
READY_TIMEOUT="${READY_TIMEOUT:-90}"
# Bound the scale-down wait comfortably above cooldown + one poll tick so a
# real hang fails loudly instead of the script exiting early on a fluke.
SCALE_DOWN_TIMEOUT="${SCALE_DOWN_TIMEOUT:-$(( KEDA_HTTP_E2E_COOLDOWN_PERIOD + KEDA_HTTP_E2E_POLLING_INTERVAL * 3 + 30 ))}"

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
    kubectl logs -n "${NAMESPACE}" -l "app=${DEPLOYMENT}" --tail=200 --all-containers=true || true
    kubectl describe interceptorroute "${DEPLOYMENT}-http-route" -n "${NAMESPACE}" || true
    kubectl describe scaledobject "${DEPLOYMENT}-http-scaledobject" -n "${NAMESPACE}" || true
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
    (cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" destroy) || true
    kubectl delete namespace "${NAMESPACE}" --ignore-not-found --timeout="${DELETE_TIMEOUT}s" || true
}
trap 'cleanup "$?"' EXIT

_T0=$(date +%s)
_t() { echo "[TIMING +$(( $(date +%s) - _T0 ))s] $1"; }

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

_t "fixture apply start"
echo "=== apply zero-replica Deployment + Service fixture ==="
kubectl apply -f "${FIXTURE_DIR}/fixture.yaml"
REPLICAS=$(kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}')
if [ "${REPLICAS}" != "0" ]; then
    echo "FAIL: fixture Deployment '${DEPLOYMENT}' did not start at 0 replicas (got ${REPLICAS})" >&2
    exit 1
fi
echo "  ${DEPLOYMENT} starts at 0 replicas"

_t "apply_http_activation (create path)"
echo "=== apply_http_activation: reconcile InterceptorRoute + ScaledObject (create) ==="
if ! (cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" apply); then
    echo "FAIL: first apply_http_activation call (create path) errored" >&2
    dump_state
    exit 1
fi

_t "apply_http_activation (patch path)"
echo "=== re-apply: both resources already exist, so this exercises the get-then-patch branch against the real API server (required behavior: idempotent create-or-patch) ==="
if ! (cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" apply); then
    echo "FAIL: second apply_http_activation call (patch path) errored" >&2
    dump_state
    exit 1
fi

_t "wait for InterceptorRoute + ScaledObject Ready"
echo "=== confirm InterceptorRoute and ScaledObject reconciled to Ready ==="
if ! wait_for_ready interceptorroute "${DEPLOYMENT}-http-route"; then
    dump_state
    exit 1
fi
if ! wait_for_ready scaledobject "${DEPLOYMENT}-http-scaledobject"; then
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
    -H "Host: ${KEDA_HTTP_E2E_ROUTE_HOST}" \
    "http://localhost:${INTERCEPTOR_LOCAL_PORT}/" || echo "000")
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
if ! kubectl wait --for=condition=Available "deployment/${DEPLOYMENT}" \
        -n "${NAMESPACE}" --timeout="${READY_TIMEOUT}s"; then
    echo "FAIL: ${DEPLOYMENT} did not become Available within ${READY_TIMEOUT}s" >&2
    dump_state
    exit 1
fi
READY_REPLICAS=$(kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" \
    -o jsonpath='{.status.readyReplicas}')
echo "  ${DEPLOYMENT} readyReplicas=${READY_REPLICAS}"

kill "${PORT_FORWARD_PID}" 2>/dev/null || true
PORT_FORWARD_PID=""

_t "wait for scale-down after cooldown"
echo "=== stop traffic; wait up to ${SCALE_DOWN_TIMEOUT}s for scale-down after ${KEDA_HTTP_E2E_COOLDOWN_PERIOD}s cooldown ==="
SCALED_DOWN=0
ELAPSED=0
while [ "${ELAPSED}" -lt "${SCALE_DOWN_TIMEOUT}" ]; do
    sleep "${KEDA_HTTP_E2E_POLLING_INTERVAL}"
    ELAPSED=$(( ELAPSED + KEDA_HTTP_E2E_POLLING_INTERVAL ))
    CURRENT_REPLICAS=$(kubectl get deployment "${DEPLOYMENT}" -n "${NAMESPACE}" \
        -o jsonpath='{.spec.replicas}')
    echo "  +${ELAPSED}s replicas=${CURRENT_REPLICAS}"
    if [ "${CURRENT_REPLICAS}" = "0" ]; then
        SCALED_DOWN=1
        break
    fi
done
if [ "${SCALED_DOWN}" != "1" ]; then
    echo "FAIL: ${DEPLOYMENT} did not scale back to 0 within ${SCALE_DOWN_TIMEOUT}s of cooldown" >&2
    dump_state
    exit 1
fi
echo "  scaled back to 0"

_t "ALL DONE"
echo "=== KEDA HTTP activation REAL e2e PASSED ==="
