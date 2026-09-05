#!/usr/bin/env bash
# Real-cluster e2e for KubernetesAutoscalerObserver target correlation on
# jac-scale's actual gateway deploy shape.
#
# Deploys a sanitized copy of jac/examples/todo_app (KEDA-autoscaled via a
# jac.toml overlay) through the SDK's deploy(), the same KubernetesTarget
# path `jac scale deploy` drives, instead of hand-building a Deployment and
# applying a KEDA ScaledObject directly. This produces a real
# "gateway-deployment" (labelled app=gateway, since that label doubles as
# its pod selector) with a real KEDA-generated ScaledObject/HPA (labelled
# app=gateway-deployment). Then runs the real KubernetesAutoscalerObserver
# and asserts its _target_cache has one fully populated slot for that
# target.
#
# Before a0e5c2213 this failed: the observer correlated all three resource
# kinds by the `app` label, and KEDA's own generated HPA/ScaledObject carry
# "gateway-deployment" there while the Deployment itself carries the bare
# "gateway" -- so the join could never complete for jac-scale's own primary
# deploy shape. Requires a reachable cluster (kind/minikube/microk8s/EKS) on
# the current kubeconfig context with KEDA core already installed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../../.." && pwd)"
DRIVER="${REPO_ROOT}/jac/jaclang/scale/tests/deploy/keda_gateway_correlation_verify.jac"
APP_SRC="${REPO_ROOT}/jac/examples/todo_app"
if [ ! -f "${DRIVER}" ] || [ ! -f "${APP_SRC}/main.jac" ]; then
    echo "FAIL: driver or todo_app fixture not found" >&2
    exit 1
fi

echo "=== preflight: KEDA core CRDs ==="
if ! kubectl get crd scaledobjects.keda.sh >/dev/null 2>&1; then
    echo "FAIL: scaledobjects.keda.sh CRD not found on cluster." >&2
    echo "Install KEDA core first, e.g. (version pinned to match CI):" >&2
    echo "  helm repo add kedacore https://kedacore.github.io/charts && helm repo update" >&2
    echo "  helm install keda kedacore/keda -n keda --create-namespace --wait --version 2.20.2" >&2
    exit 1
fi

export KEDA_GW_CORR_E2E_NAMESPACE="${KEDA_GW_CORR_E2E_NAMESPACE:-jac-gw-corr-e2e}"
export KEDA_GW_CORR_E2E_APP="${KEDA_GW_CORR_E2E_APP:-gw-corr-app}"
export KEDA_GW_CORR_E2E_OBSERVE_TIMEOUT="${KEDA_GW_CORR_E2E_OBSERVE_TIMEOUT:-180}"
NAMESPACE="${KEDA_GW_CORR_E2E_NAMESPACE}"
DEPLOYMENT="gateway-deployment"
DELETE_TIMEOUT="${DELETE_TIMEOUT:-300}"

CLUSTER_TYPE="${CLUSTER_TYPE:-kind}"
case "${CLUSTER_TYPE}" in
    microk8s) export KEDA_GW_CORR_E2E_STORAGE_CLASS="${KEDA_GW_CORR_E2E_STORAGE_CLASS-microk8s-hostpath}" ;;
    minikube) export KEDA_GW_CORR_E2E_STORAGE_CLASS="${KEDA_GW_CORR_E2E_STORAGE_CLASS-standard}" ;;
    kind)     export KEDA_GW_CORR_E2E_STORAGE_CLASS="${KEDA_GW_CORR_E2E_STORAGE_CLASS-jac-gw-corr-rwx}" ;;
    *)        export KEDA_GW_CORR_E2E_STORAGE_CLASS="${KEDA_GW_CORR_E2E_STORAGE_CLASS-}" ;;
esac

if [ -z "${JAC_SCALE_BINARY_PATH:-}" ]; then
    echo "WARN: JAC_SCALE_BINARY_PATH is unset; pods will bootstrap from a published release binary instead of the code under test."
fi

APP_DIR=""
cleanup() {
    rc="${1:-0}"
    echo "=== cleanup (rc=${rc}) ==="
    if [ -n "${APP_DIR}" ]; then
        rm -rf "$(dirname "${APP_DIR}")"
    fi
    if [ "${rc}" != "0" ] && [ "${E2E_KEEP_NS_ON_FAIL:-1}" = "1" ]; then
        echo "=== e2e failed (rc=${rc}); KEEPING namespace '${NAMESPACE}' for inspection (set E2E_KEEP_NS_ON_FAIL=0 to force cleanup) ==="
        return
    fi
    (cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" teardown) || true
    kubectl delete namespace "${NAMESPACE}" --ignore-not-found --timeout="${DELETE_TIMEOUT}s" || true
    if [ "${CLUSTER_TYPE}" = "kind" ]; then
        kubectl delete pv jac-gw-corr-rwx-bundle-pv --ignore-not-found 2>/dev/null || true
    fi
}
trap 'cleanup "$?"' EXIT

dump_state() {
    echo "--- diagnostics (namespace=${NAMESPACE}) ---"
    kubectl get deployment,scaledobject,hpa -n "${NAMESPACE}" -o wide || true
    kubectl describe deployment "${DEPLOYMENT}" -n "${NAMESPACE}" || true
    kubectl describe scaledobject -n "${NAMESPACE}" || true
    kubectl get events -n "${NAMESPACE}" --sort-by=.lastTimestamp || true
}

# shellcheck source=../../scripts/e2e_lib.sh
source "${REPO_ROOT}/jac/jaclang/scale/scripts/e2e_lib.sh"
e2e_timing_init

_t "prep start"
echo "=== stage a sanitized copy of jac/examples/todo_app ==="
# [dev].jaclang_source and [desktop] only make sense on a dev workstation;
# strip them so the pod runtime doesn't chase paths that don't exist in the
# shipped bundle. The KEDA engine is turned on via DeploySpec.extra in the
# driver's build_config(), not a jac.toml overlay here: the SDK's deploy()
# builds KubernetesConfig entirely from the DeploySpec it is given and never
# reads the staged app's own jac.toml [scale.kubernetes] table, so a `keda`
# engine written into that file would be silently ignored.
APP_DIR="$(mktemp -d)/todo_app"
mkdir -p "${APP_DIR}"
cp "${APP_SRC}"/*.jac "${APP_DIR}/"
python3 - "${APP_SRC}/jac.toml" "${APP_DIR}/jac.toml" <<'PYEOF'
import sys

drop_sections = ("dev", "desktop")
out, skipping = [], False
with open(sys.argv[1]) as f:
    for line in f:
        stripped = line.strip()
        if stripped.startswith("["):
            section = stripped.strip("[]").split(".")[0]
            skipping = section in drop_sections
        if skipping or stripped.startswith("kind ="):
            continue
        out.append(line)
with open(sys.argv[2], "w") as f:
    f.writelines(out)
PYEOF
export KEDA_GW_CORR_E2E_SOURCE="${APP_DIR}"
echo "  staged at ${APP_DIR}"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
if [ "${CLUSTER_TYPE}" = "kind" ]; then
    provision_kind_rwx_storage "${NAMESPACE}" "${KEDA_GW_CORR_E2E_STORAGE_CLASS}" \
        jac-gw-corr-rwx-bundle-pv /var/jac-gw-corr-rwx-bundle jac-gw-corr-rwx-perms
fi

_t "deploy start"
echo "=== deploy via the real KubernetesTarget path (SDK deploy()) ==="
if ! (cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" deploy </dev/null); then
    echo "FAIL: deploy errored" >&2
    dump_state
    exit 1
fi

_t "wait for KEDA to generate the HPA"
echo "=== confirm KEDA generated its HPA for the gateway's ScaledObject ==="
elapsed=0
while [ "${elapsed}" -lt 60 ]; do
    if kubectl get hpa -n "${NAMESPACE}" -o jsonpath='{.items[0].metadata.name}' >/dev/null 2>&1; then
        break
    fi
    sleep 2
    elapsed=$(( elapsed + 2 ))
done
kubectl get deployment,scaledobject,hpa -n "${NAMESPACE}" -o wide || true

_t "observe and assert correlation"
echo "=== run the real KubernetesAutoscalerObserver and assert one joined _target_cache slot ==="
if ! (cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" observe); then
    echo "FAIL: target correlation did not hold -- see output above" >&2
    dump_state
    exit 1
fi

_t "ALL DONE"
echo "=== KEDA gateway correlation REAL e2e PASSED ==="
print_timing_report
