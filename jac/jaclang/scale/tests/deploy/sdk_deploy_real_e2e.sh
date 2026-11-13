#!/usr/bin/env bash
# Real-cluster e2e for the programmatic deploy SDK (jaclang.scale.sdk).
#
# Deploys a sanitized copy of jac/examples/todo_app (a real single-service
# full-stack app; no microservice routes) through the SDK's one-call
# deploy(path, config) instead of `jac start --scale`, then proves the deploy
# is real: typed progress events reached the caller, the app rolls out,
# DeploySpec.env and DeploySpec.secrets reach the pod (checked via kubectl
# exec), an authenticated walker call works end to end, status/url work, and
# destroy tears everything down without ever prompting.
#
# Requires a reachable cluster (kind/minikube/microk8s/EKS) on the current
# kubeconfig context and the scale deploy deps installed for `jac`.

set -euo pipefail

# This script lives at jac/jaclang/scale/tests/deploy/, so the repo root is
# five levels up.
REPO_ROOT="$(cd "$(dirname "$0")/../../../../.." && pwd)"
DRIVER="${REPO_ROOT}/jac/jaclang/scale/tests/deploy/sdk_deploy_driver.jac"
APP_SRC="${REPO_ROOT}/jac/examples/todo_app"
if [ ! -f "${DRIVER}" ] || [ ! -f "${APP_SRC}/main.jac" ]; then
    echo "FAIL: driver or todo_app fixture not found" >&2
    exit 1
fi

export SDK_DEPLOY_NAMESPACE="${SDK_DEPLOY_NAMESPACE:-jac-sdk-e2e}"
export SDK_DEPLOY_APP_NAME="${SDK_DEPLOY_APP_NAME:-sdk-todo}"
export SDK_DEPLOY_GREETING="${SDK_DEPLOY_GREETING:-howdy}"
export SDK_DEPLOY_SECRET="${SDK_DEPLOY_SECRET:-sdk-e2e-secret}"
NAMESPACE="${SDK_DEPLOY_NAMESPACE}"
APP="${SDK_DEPLOY_APP_NAME}"

CLUSTER_TYPE="${CLUSTER_TYPE:-kind}"
case "${CLUSTER_TYPE}" in
    microk8s) export SDK_DEPLOY_STORAGE_CLASS="${SDK_DEPLOY_STORAGE_CLASS-microk8s-hostpath}" ;;
    minikube) export SDK_DEPLOY_STORAGE_CLASS="${SDK_DEPLOY_STORAGE_CLASS-standard}" ;;
    kind)     export SDK_DEPLOY_STORAGE_CLASS="${SDK_DEPLOY_STORAGE_CLASS-jac-sdk-rwx}" ;;
    *)        export SDK_DEPLOY_STORAGE_CLASS="${SDK_DEPLOY_STORAGE_CLASS-}" ;;
esac

ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-600s}"
DELETE_TIMEOUT="${DELETE_TIMEOUT:-300s}"
APP_LOCAL_PORT="${APP_LOCAL_PORT:-18300}"


PORT_FORWARD_PID=""
SHIM_PID=""
APP_DIR=""
cleanup() {
    rc="${1:-0}"
    echo "=== cleanup (rc=${rc}) ==="
    if [ -n "${PORT_FORWARD_PID}" ]; then
        kill "${PORT_FORWARD_PID}" 2>/dev/null || true
    fi
    if [ -n "${SHIM_PID}" ]; then
        kill "${SHIM_PID}" 2>/dev/null || true
    fi
    if [ -n "${APP_DIR}" ]; then
        rm -rf "${APP_DIR}"
    fi
    if [ "${rc}" != "0" ] && [ "${E2E_KEEP_NS_ON_FAIL:-1}" = "1" ]; then
        echo "=== e2e failed (rc=${rc}); KEEPING namespace '${NAMESPACE}' for inspection (set E2E_KEEP_NS_ON_FAIL=0 to force cleanup) ==="
        return
    fi
    kubectl delete namespace "${NAMESPACE}" --ignore-not-found --timeout="${DELETE_TIMEOUT}" || true
    if [ "${CLUSTER_TYPE}" = "kind" ]; then
        kubectl delete pv jac-sdk-rwx-bundle-pv --ignore-not-found 2>/dev/null || true
    fi
}
trap 'cleanup "$?"' EXIT

dump_state() {
    kubectl get pods -n "${NAMESPACE}" -o wide || true
    kubectl get events -n "${NAMESPACE}" --sort-by=.lastTimestamp | tail -40 || true
    for pod in $(kubectl get pods -n "${NAMESPACE}" -o name 2>/dev/null); do
        kubectl logs -n "${NAMESPACE}" "${pod}" --all-containers=true --tail=120 || true
    done
}

# shellcheck source=../../scripts/e2e_lib.sh
source "${REPO_ROOT}/jac/jaclang/scale/scripts/e2e_lib.sh"
e2e_timing_init

_t "prep start"
echo "=== stage a sanitized copy of jac/examples/todo_app ==="
# [dev].jaclang_source and the [desktop] sections only make sense on a dev
# workstation; strip them so the pod runtime doesn't chase paths that don't
# exist in the shipped bundle.
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
ship_checkout_binary "${APP_DIR}" \
    || echo "WARN: pods will bootstrap from a published release binary instead of the code under test."
export SDK_DEPLOY_SOURCE="${APP_DIR}"
echo "  staged at ${APP_DIR}"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
if [ "${CLUSTER_TYPE}" = "kind" ]; then
    provision_kind_rwx_storage "${NAMESPACE}" "${SDK_DEPLOY_STORAGE_CLASS}" \
        jac-sdk-rwx-bundle-pv /var/jac-sdk-rwx-bundle jac-sdk-rwx-perms
fi

if [ "${CLUSTER_TYPE}" != "remote" ]; then
    # The engine's reachability probe hits http://localhost:30080 (the
    # LocalProvider NodePort assumption), which kind and docker-driver
    # minikube don't map to the host. Keep a port-forward shim pointed at the
    # per-app ingress controller service so the probe reaches the app.
    (
        while true; do
            if kubectl get svc "${APP}-ingress-nginx-service" -n "${NAMESPACE}" >/dev/null 2>&1; then
                kubectl port-forward -n "${NAMESPACE}" "svc/${APP}-ingress-nginx-service" \
                    30080:80 >/dev/null 2>&1 || true
            fi
            sleep 3
        done
    ) &
    SHIM_PID=$!
fi

_t "SDK deploy start"
echo "=== deploy programmatically via the SDK one-call deploy() ==="
DEPLOY_LOG="$(mktemp)"
# </dev/null: any interactive prompt in the SDK path is an instant failure
# instead of a hang.
if ! (cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" deploy </dev/null 2>&1 | tee "${DEPLOY_LOG}"); then
    echo "FAIL: SDK deploy errored" >&2
    dump_state
    rm -f "${DEPLOY_LOG}"
    exit 1
fi

echo "=== assert the typed event stream reached the caller ==="
for marker in "[deploy:start]" "[provision:ok]" "[bundle:ok]" "[apply:ok]" "[rollout:ok]" "[deploy:ok]" "DEPLOY_OK"; do
    if ! grep -qF "${marker}" "${DEPLOY_LOG}"; then
        echo "FAIL: expected event marker '${marker}' missing from the deploy output" >&2
        cat "${DEPLOY_LOG}" >&2
        rm -f "${DEPLOY_LOG}"
        exit 1
    fi
done
rm -f "${DEPLOY_LOG}"
echo "  all phase events streamed"

_t "deploy returned; verifying rollout"
# The unified deploy realizes a no-routes app as the N=1 fleet: the app's own
# service behind the gateway.
for dep in "deployment/${APP}-deployment" "deployment/gateway-deployment"; do
    if ! kubectl rollout status "${dep}" -n "${NAMESPACE}" --timeout="${ROLLOUT_TIMEOUT}"; then
        echo "FAIL: ${dep} did not complete its rollout" >&2
        dump_state
        exit 1
    fi
done

_t "pods Ready"
echo "=== assert DeploySpec.labels stamped on the app manifests ==="
for res in "deployment/${APP}-deployment" "service/${APP}-service"; do
    LABEL=$(kubectl get "${res}" -n "${NAMESPACE}" -o jsonpath='{.metadata.labels.jac-scale\.example}')
    if [ "${LABEL}" != "sdk-deploy" ]; then
        echo "FAIL: ${res} missing the platform label (jac-scale.example='${LABEL}')" >&2
        dump_state
        exit 1
    fi
done
echo "  labels stamped"

echo "=== assert DeploySpec.env and DeploySpec.secrets reached the pod ==="
POD_GREETING=$(kubectl exec -n "${NAMESPACE}" "deploy/${APP}-deployment" -- printenv GREETING_PREFIX 2>/dev/null || echo "")
if [ "${POD_GREETING}" != "${SDK_DEPLOY_GREETING}" ]; then
    echo "FAIL: GREETING_PREFIX in the pod is '${POD_GREETING}', expected '${SDK_DEPLOY_GREETING}' (DeploySpec.env not wired)" >&2
    dump_state
    exit 1
fi
POD_SECRET=$(kubectl exec -n "${NAMESPACE}" "deploy/${APP}-deployment" -- printenv GREETER_SECRET 2>/dev/null || echo "")
if [ "${POD_SECRET}" != "${SDK_DEPLOY_SECRET}" ]; then
    echo "FAIL: GREETER_SECRET missing in the pod (DeploySpec.secrets not wired)" >&2
    dump_state
    exit 1
fi
echo "  env + secret reached the pod through the spec"

echo "=== port-forward the app service + liveness ==="
kubectl port-forward -n "${NAMESPACE}" "svc/gateway-service" "${APP_LOCAL_PORT}:8000" >/dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 2
LIVE_CODE="000"
for attempt in $(seq 1 10); do
    LIVE_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
        "http://localhost:${APP_LOCAL_PORT}/healthz/live" || echo "000")
    [ "${LIVE_CODE}" = "200" ] && break
    sleep 3
done
if [ "${LIVE_CODE}" != "200" ]; then
    echo "FAIL: /healthz/live returned '${LIVE_CODE}'" >&2
    dump_state
    exit 1
fi
echo "  /healthz/live OK"

_t "health OK"
echo "=== journey: register/login, then create a todo through a walker ==="
APP_URL="http://localhost:${APP_LOCAL_PORT}"
E2E_EMAIL="sdk-e2e@example.com"
REG_BODY="{\"identities\":[{\"type\":\"email\",\"value\":\"${E2E_EMAIL}\"}],\"credential\":{\"type\":\"password\",\"password\":\"pw12345678\"}}"
LOGIN_BODY="{\"identity\":{\"type\":\"email\",\"value\":\"${E2E_EMAIL}\"},\"credential\":{\"type\":\"password\",\"password\":\"pw12345678\"}}"
REG_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${APP_URL}/user/register" \
    -H 'content-type: application/json' -d "${REG_BODY}")
case "${REG_CODE}" in
    200 | 201 | 409) : ;;
    *) echo "FAIL: /user/register returned ${REG_CODE}" >&2; dump_state; exit 1 ;;
esac
TOKEN=$(curl -fsS -X POST "${APP_URL}/user/login" -H 'content-type: application/json' \
    -d "${LOGIN_BODY}" \
    | python3 -c "import json, sys; print((json.load(sys.stdin).get('data') or {}).get('token', ''))")
if [ -z "${TOKEN}" ]; then echo "FAIL: /user/login returned no token" >&2; exit 1; fi

TODO_RESP=$(curl -fsS --max-time 20 --retry 5 --retry-delay 3 --retry-all-errors \
    -X POST "${APP_URL}/walker/create_todo" \
    -H "Authorization: Bearer ${TOKEN}" -H 'content-type: application/json' \
    -d '{"text": "sdk e2e todo"}' || true)
if ! printf '%s' "${TODO_RESP}" | grep -q "sdk e2e todo"; then
    echo "FAIL: create_todo walker did not echo the todo. Response head:" >&2
    printf '%s' "${TODO_RESP}" | head -c 300 >&2
    dump_state
    exit 1
fi
echo "  walker journey OK"

_t "journey OK"
# The #8115 repro end to end: change only configuration and deploy again. The
# Secret is referenced by a constant name and its sections are stripped from
# the bundle, so before the config marker the pod template came out byte
# identical, the patch was a no-op, and the old value kept serving while the
# deploy reported success.
echo "=== redeploy with only the configuration changed (#8115) ==="
REV_PATH='{.spec.template.metadata.annotations.jac-scale\.config-revision}'
REV_BEFORE=$(kubectl get deploy "${APP}-deployment" -n "${NAMESPACE}" -o jsonpath="${REV_PATH}")
export SDK_DEPLOY_SECRET="${SDK_DEPLOY_SECRET}-rotated"
if ! (cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" deploy </dev/null >/dev/null 2>&1); then
    echo "FAIL: config-only redeploy errored" >&2
    dump_state
    exit 1
fi
REV_AFTER=$(kubectl get deploy "${APP}-deployment" -n "${NAMESPACE}" -o jsonpath="${REV_PATH}")
if [ -z "${REV_AFTER}" ] || [ "${REV_BEFORE}" = "${REV_AFTER}" ]; then
    echo "FAIL: the config marker did not move on a config-only redeploy (before='${REV_BEFORE}' after='${REV_AFTER}'), so the pod template is unchanged and the old configuration is still serving" >&2
    dump_state
    exit 1
fi
if ! kubectl rollout status "deployment/${APP}-deployment" -n "${NAMESPACE}" --timeout="${ROLLOUT_TIMEOUT}"; then
    echo "FAIL: the config-only rollout did not complete" >&2
    dump_state
    exit 1
fi
POD_SECRET_ROTATED=$(kubectl exec -n "${NAMESPACE}" "deploy/${APP}-deployment" -- printenv GREETER_SECRET 2>/dev/null || echo "")
if [ "${POD_SECRET_ROTATED}" != "${SDK_DEPLOY_SECRET}" ]; then
    echo "FAIL: running pods report GREETER_SECRET='${POD_SECRET_ROTATED}', expected the rotated '${SDK_DEPLOY_SECRET}'" >&2
    dump_state
    exit 1
fi
echo "  config-only redeploy rolled the fleet and the new value is live"
_t "config redeploy OK"
# #10095: with a history limit of 1, the third code change prunes the first bundle.
echo "=== code redeploys prune the bundle PVC; a retained release still rolls back (#10095) ==="
export SDK_DEPLOY_REVISION_HISTORY_LIMIT=1
PRUNE_LOG="$(mktemp)"
for change in 1 2 3; do
    printf '\nglob _bundle_prune_e2e: int = %s;\n' "${change}" >> "${APP_DIR}/main.jac"
    if ! (cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" deploy </dev/null 2>&1 | tee -a "${PRUNE_LOG}"); then
        echo "FAIL: code redeploy ${change} errored" >&2
        dump_state
        exit 1
    fi
    if ! kubectl rollout status "deployment/${APP}-deployment" -n "${NAMESPACE}" --timeout="${ROLLOUT_TIMEOUT}"; then
        echo "FAIL: code redeploy ${change} did not complete its rollout" >&2
        dump_state
        exit 1
    fi
done
if ! grep -q "pruned bundles/" "${PRUNE_LOG}"; then
    echo "FAIL: three code redeploys never pruned a bundle from the PVC" >&2
    exit 1
fi
grep "pruned " "${PRUNE_LOG}" | sed 's/^/  /'
rm -f "${PRUNE_LOG}"

release_field() {
    (cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" revisions </dev/null | grep '^\[' | tail -1) \
        | python3 -c "import json, sys; r = json.load(sys.stdin); print(r[$1]['$2'] if len(r) > $1 else '')"
}
ROLLBACK_TO=$(release_field 1 revision)
ROLLBACK_DIGEST=$(release_field 1 bundle_digest)
if [ -z "${ROLLBACK_TO}" ]; then
    echo "FAIL: no retained release to roll back to after the pruning redeploys" >&2
    dump_state
    exit 1
fi
ROLLBACK_OUT=$(cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" rollback "${ROLLBACK_TO}" </dev/null 2>&1) || true
if ! printf '%s' "${ROLLBACK_OUT}" | grep -q "ROLLBACK_OK"; then
    echo "FAIL: rollback to release ${ROLLBACK_TO} errored: ${ROLLBACK_OUT}" >&2
    dump_state
    exit 1
fi
if ! kubectl rollout status "deployment/${APP}-deployment" -n "${NAMESPACE}" --timeout="${ROLLOUT_TIMEOUT}"; then
    echo "FAIL: the rollback to release ${ROLLBACK_TO} did not start; its bundle may have been pruned" >&2
    dump_state
    exit 1
fi
LIVE_DIGEST=$(release_field 0 bundle_digest)
if [ "${LIVE_DIGEST}" != "${ROLLBACK_DIGEST}" ]; then
    echo "FAIL: after the rollback the live bundle is '${LIVE_DIGEST}', expected '${ROLLBACK_DIGEST}'" >&2
    dump_state
    exit 1
fi
echo "  pruning redeploys kept the retained release, and it rolled back"
_t "prune + rollback OK"
echo "=== status + url through the SDK ==="
# grep '^{': first-run compiles print "Jac setup complete" lines around the payload.
STATUS_JSON=$(cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" status </dev/null | grep '^{' | tail -1)
if ! printf '%s' "${STATUS_JSON}" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
comps = {c.get('name'): c.get('status') for c in d.get('components', [])}
assert d.get('app_name') == '${APP}', d
assert comps, d
sys.exit(0)
"; then
    echo "FAIL: SDK status() returned an unexpected payload: ${STATUS_JSON}" >&2
    exit 1
fi
echo "  status OK: ${STATUS_JSON}"
(cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" url </dev/null | tail -1 | sed 's/^/  url -> /') || true

_t "status OK"
echo "=== destroy through the SDK (must never prompt) ==="
DESTROY_OUT=$(cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" destroy </dev/null 2>&1) || true
printf '%s\n' "${DESTROY_OUT}"
if ! printf '%s' "${DESTROY_OUT}" | grep -q "DESTROY_OK"; then
    echo "FAIL: SDK destroy errored (or prompted)" >&2
    exit 1
fi
DESTROY_WAIT=0
GONE=0
while [ "${DESTROY_WAIT}" -lt 120 ]; do
    if ! kubectl get deployment "${APP}" -n "${NAMESPACE}" >/dev/null 2>&1; then
        GONE=1
        break
    fi
    sleep 5
    DESTROY_WAIT=$(( DESTROY_WAIT + 5 ))
done
if [ "${GONE}" != "1" ]; then
    echo "FAIL: deployment '${APP}' still present 120s after destroy" >&2
    dump_state
    exit 1
fi
echo "  app destroyed"

_t "ALL DONE"
echo "=== SDK programmatic deploy REAL e2e PASSED ==="
