#!/usr/bin/env bash
# Real-cluster e2e for a first deploy on a machine without the Kubernetes client.
#
# Each command runs on a fresh HOME, so it has to install the client and use it
# in the same run. The lane's own client install lives under its real HOME and
# stays out of the way.
#
# Requires a reachable cluster on the current kubeconfig context.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../../.." && pwd)"
source "${REPO_ROOT}/jac/jaclang/scale/scripts/e2e_lib.sh"

NAMESPACE="${FIRST_DEPLOY_NAMESPACE:-jac-first-deploy}"
APP="first-deploy"
STORAGE_CLASS="${BUNDLE_STORAGE_CLASS:-microk8s-hostpath}"
LOCAL_PORT="${APP_LOCAL_PORT:-18310}"
export KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/config}"

WORK="$(mktemp -d)"
PORT_FORWARD_PID=""
cleanup() {
    if [ -n "${PORT_FORWARD_PID}" ]; then
        kill "${PORT_FORWARD_PID}" 2>/dev/null || true
    fi
    kubectl delete namespace "${NAMESPACE}" --ignore-not-found --timeout=300s || true
    rm -rf "${WORK}"
}
trap cleanup EXIT

fresh_home() {
    HOME="$(mktemp -d -p "${WORK}")"
    export HOME
    # `env` is a separate capability that a deploy does not install for itself.
    jac install --global "python-dotenv>=1.2.1,<2.0.0" > /dev/null
}

assert_installed_client() {
    if ! grep -q "Deploy tooling missing" "$1"; then
        echo "FAIL: $1 did not install the client, so it proves nothing" >&2
        exit 1
    fi
}

cd "${WORK}"
cat > jac.toml <<TOML
[project]
name = "${APP}"
version = "0.1.0"
entry-point = "main"

[scale.kubernetes]
app_name = "${APP}"
namespace = "${NAMESPACE}"
bundle_storage_class = "${STORAGE_CLASS}"
TOML
cat > main.jac <<'JAC'
walker:pub hello {
    can go with Root entry {
        report "hello from the first deploy";
    }
}
JAC
ship_checkout_binary "${WORK}"

echo "=== first deploy ==="
fresh_home
jac scale deploy main.jac 2>&1 | tee "${WORK}/deploy.log"
assert_installed_client "${WORK}/deploy.log"
kubectl rollout status "deployment/${APP}-deployment" -n "${NAMESPACE}" --timeout=600s

kubectl port-forward -n "${NAMESPACE}" "svc/${APP}-service" "${LOCAL_PORT}:8000" > /dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 8
BODY="$(curl -s -m 20 -X POST -H 'Content-Type: application/json' -d '{}' "http://127.0.0.1:${LOCAL_PORT}/walker/hello")"
kill "${PORT_FORWARD_PID}" 2>/dev/null || true
PORT_FORWARD_PID=""
if ! echo "${BODY}" | grep -q "hello from the first deploy"; then
    echo "FAIL: the deployed app did not answer: ${BODY}" >&2
    exit 1
fi

echo "=== first destroy ==="
fresh_home
echo y | jac scale destroy main.jac 2>&1 | tee "${WORK}/destroy.log"
assert_installed_client "${WORK}/destroy.log"
LEFT="$(kubectl get deploy -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l)"
if [ "${LEFT}" -ne 0 ]; then
    echo "FAIL: ${LEFT} deployments left after destroy" >&2
    exit 1
fi

echo "=== first deploy e2e PASSED ==="
