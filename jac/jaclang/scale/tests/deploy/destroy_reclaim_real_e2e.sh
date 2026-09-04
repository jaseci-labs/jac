#!/usr/bin/env bash
# Real-cluster e2e for destroy reclamation (#7968).
#
# Five properties, each one a bug this change fixes:
#
#   A  owned namespace     the namespace jac-scale created is reclaimed whole
#   B  adopted namespace   a namespace it did not create survives, foreign
#                          workloads untouched, the app's own resources go
#   C  co-tenant           destroying one app never deletes a namespace another
#                          app is still deployed into, in either direction:
#                          the app that created it and the app that adopted it
#   D  shared volume       a PVC named from user config, with no app prefix,
#                          is still reclaimed
#   E  sibling app         a PVC belonging to an app sharing a name prefix is
#                          never deleted
#
# Requires a reachable cluster (kind/minikube/microk8s/EKS) on the current
# kubeconfig context and the scale deploy deps installed for `jac`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../../.." && pwd)"
DRIVER="${REPO_ROOT}/jac/jaclang/scale/tests/deploy/sdk_deploy_driver.jac"
APP_SRC="${REPO_ROOT}/jac/examples/todo_app"
if [ ! -f "${DRIVER}" ] || [ ! -f "${APP_SRC}/main.jac" ]; then
    echo "FAIL: driver or todo_app fixture not found" >&2
    exit 1
fi

OWNER_LABEL="jac-scale.jaseci.org/owned-by"
OWNED_NS="${OWNED_NS:-jac-destroy-owned}"
ADOPTED_NS="${ADOPTED_NS:-jac-destroy-adopted}"
COTENANT_NS="${COTENANT_NS:-jac-destroy-cotenant}"
APP="${DESTROY_E2E_APP_NAME:-todo}"
SIBLING="${APP}-analytics"
COTENANT="${DESTROY_E2E_COTENANT:-billing}"
SENTINEL="foreign-workload"
SHARED_VOL="uploads"
SIBLING_VOL="reports"
LEGACY_VOL="legacy-cache"

CLUSTER_TYPE="${CLUSTER_TYPE:-kind}"
case "${CLUSTER_TYPE}" in
    microk8s) STORAGE_CLASS="${DESTROY_E2E_STORAGE_CLASS-microk8s-hostpath}" ;;
    minikube) STORAGE_CLASS="${DESTROY_E2E_STORAGE_CLASS-standard}" ;;
    kind)     STORAGE_CLASS="${DESTROY_E2E_STORAGE_CLASS-jac-destroy-rwx}" ;;
    *)        STORAGE_CLASS="${DESTROY_E2E_STORAGE_CLASS-}" ;;
esac

ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-600s}"
NS_DELETE_WAIT="${NS_DELETE_WAIT:-300}"
APP_DIR=""
ALL_NS="${OWNED_NS} ${ADOPTED_NS} ${COTENANT_NS}"

if [ -z "${JAC_SCALE_BINARY_PATH:-}" ]; then
    echo "WARN: JAC_SCALE_BINARY_PATH is unset; pods will bootstrap from a published release binary instead of the code under test."
fi

cleanup() {
    rc="${1:-0}"
    echo "=== cleanup (rc=${rc}) ==="
    [ -n "${APP_DIR}" ] && rm -rf "${APP_DIR}"
    if [ "${rc}" != "0" ] && [ "${E2E_KEEP_NS_ON_FAIL:-1}" = "1" ]; then
        echo "=== e2e failed (rc=${rc}); KEEPING namespaces for inspection (set E2E_KEEP_NS_ON_FAIL=0 to force cleanup) ==="
        return
    fi
    # shellcheck disable=SC2086
    kubectl delete namespace ${ALL_NS} --ignore-not-found --timeout=300s || true
    if [ "${CLUSTER_TYPE}" = "kind" ]; then
        kubectl delete pv jac-destroy-rwx-bundle-pv --ignore-not-found 2>/dev/null || true
    fi
}
trap 'cleanup "$?"' EXIT

dump_state() {
    kubectl get all,pvc -n "$1" -o wide || true
    kubectl get events -n "$1" --sort-by=.lastTimestamp | tail -30 || true
}

fail() {
    echo "FAIL: $2" >&2
    dump_state "$1"
    exit 1
}

# shellcheck source=../../scripts/e2e_lib.sh
source "${REPO_ROOT}/jac/jaclang/scale/scripts/e2e_lib.sh"
e2e_timing_init

_t "prep start"
echo "=== stage a sanitized copy of jac/examples/todo_app ==="
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

export SDK_DEPLOY_SOURCE="${APP_DIR}"
export SDK_DEPLOY_STORAGE_CLASS="${STORAGE_CLASS}"

# StorageClass and PV are cluster-scoped; the perms pod runs in 'default' so no
# app namespace is created early. Scenario A only holds if jac-scale is the one
# that creates its namespace.
if [ "${CLUSTER_TYPE}" = "kind" ]; then
    provision_kind_rwx_storage default "${STORAGE_CLASS}" \
        jac-destroy-rwx-bundle-pv /var/jac-destroy-rwx-bundle jac-destroy-rwx-perms
fi

deploy_app() {
    app="$1"; ns="$2"
    export SDK_DEPLOY_APP_NAME="${app}" SDK_DEPLOY_NAMESPACE="${ns}"
    if ! (cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" deploy </dev/null 2>&1 | tail -20); then
        fail "${ns}" "deploy of '${app}' into '${ns}' errored"
    fi
    kubectl rollout status "deployment/${app}-deployment" -n "${ns}" \
        --timeout="${ROLLOUT_TIMEOUT}" \
        || fail "${ns}" "'${app}' did not roll out in '${ns}'"
}

DESTROY_OUT=""
destroy_app() {
    app="$1"; ns="$2"
    export SDK_DEPLOY_APP_NAME="${app}" SDK_DEPLOY_NAMESPACE="${ns}"
    DESTROY_OUT="$(cd "${REPO_ROOT}/jac" && jac run "${DRIVER}" destroy </dev/null 2>&1 || true)"
    printf '%s\n' "${DESTROY_OUT}" | tail -20 | grep -q "DESTROY_OK" \
        || fail "${ns}" "destroy of '${app}' in '${ns}' errored (or prompted)"
}

# Console output wraps, so fold whitespace before matching a phrase.
destroy_said() {
    printf '%s\n' "${DESTROY_OUT}" | tr -s '[:space:]' ' ' | grep -q "$1"
}

ns_owner() {
    kubectl get namespace "$1" -o "jsonpath={.metadata.labels.${OWNER_LABEL//./\\.}}" 2>/dev/null || echo ""
}

deletion_timestamp() {
    kubectl get "$2" "$3" -n "$1" -o jsonpath='{.metadata.deletionTimestamp}' 2>/dev/null || true
}

# A PVC stays readable while its pvc-protection finalizer waits for the
# mounting pod to go, so "reclaimed" means gone or marked for deletion, not
# merely unreadable the instant destroy returns.
require_absent() {
    ns="$1"; kind="$2"; name="$3"
    waited=0
    while [ "${waited}" -lt "${RECLAIM_WAIT:-180}" ]; do
        if ! kubectl get "${kind}" "${name}" -n "${ns}" >/dev/null 2>&1; then
            return 0
        fi
        if [ -n "$(deletion_timestamp "${ns}" "${kind}" "${name}")" ]; then
            echo "  ${kind}/${name} is Terminating"
            return 0
        fi
        sleep 5
        waited=$(( waited + 5 ))
    done
    fail "${ns}" "${kind}/${name} still present in '${ns}' after destroy, with no deletion timestamp"
}

# Surviving means untouched: an object already marked for deletion has been
# reclaimed by something, which for a foreign object is the bug under test.
require_present() {
    ns="$1"; kind="$2"; name="$3"
    kubectl get "${kind}" "${name}" -n "${ns}" >/dev/null 2>&1 \
        || fail "${ns}" "${kind}/${name} was deleted from '${ns}' but jac-scale does not own it"
    [ -z "$(deletion_timestamp "${ns}" "${kind}" "${name}")" ] \
        || fail "${ns}" "${kind}/${name} is Terminating in '${ns}' but jac-scale does not own it"
    return 0
}

wait_ns_gone() {
    waited=0
    while [ "${waited}" -lt "${NS_DELETE_WAIT}" ]; do
        kubectl get namespace "$1" >/dev/null 2>&1 || return 0
        sleep 5
        waited=$(( waited + 5 ))
    done
    return 1
}

# Ops RBAC for one app. The sweep must delete only the rows carrying this
# app's label, so a co-tenant's Role and RoleBinding survive.
seed_ops_rbac() {
    ns="$1"; app="$2"
    kubectl apply -n "${ns}" -f - >/dev/null <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${app}-ops
  labels: { managed: jac-scale, app: ${app} }
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${app}-ops
  labels: { managed: jac-scale, app: ${app} }
roleRef: { apiGroup: rbac.authorization.k8s.io, kind: Role, name: ${app}-ops }
subjects:
  - { kind: ServiceAccount, name: default, namespace: ${ns} }
YAML
}

# A shared volume is named straight from user config, with no app prefix. It is
# the resource a startswith(app_name) sweep cannot see.
seed_shared_volume_pvc() {
    ns="$1"; name="$2"; owner="${3:-}"
    owner_label=""
    [ -n "${owner}" ] && owner_label=$'\n    jac-scale.owner: '"${owner}"
    kubectl apply -n "${ns}" -f - >/dev/null <<YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${name}
  labels:
    app: jac-scale-shared
    managed: jac-scale
    jac-scale.role: shared-volume${owner_label}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: { requests: { storage: 64Mi } }
YAML
}

######################## scenario A: owned namespace ########################
_t "A start"
echo "=== A: jac-scale creates the namespace, destroy must reclaim it ==="
kubectl delete namespace "${OWNED_NS}" --ignore-not-found --timeout=300s >/dev/null 2>&1 || true

deploy_app "${APP}" "${OWNED_NS}"

OWNER="$(ns_owner "${OWNED_NS}")"
[ "${OWNER}" = "${APP}" ] \
    || fail "${OWNED_NS}" "namespace owner label is '${OWNER}', expected '${APP}'. Ownership must name the app, not just jac-scale, or a co-tenant can delete it"

kubectl get statefulset "${APP}-postgres" -n "${OWNED_NS}" >/dev/null 2>&1 \
    || fail "${OWNED_NS}" "postgres was never provisioned, so this run cannot prove reclamation"
seed_shared_volume_pvc "${OWNED_NS}" "${SHARED_VOL}" "${APP}"
seed_shared_volume_pvc "${OWNED_NS}" "${LEGACY_VOL}"
PVC_BEFORE=$(kubectl get pvc -n "${OWNED_NS}" --no-headers 2>/dev/null | wc -l | tr -d ' ')
[ "${PVC_BEFORE}" -ge 1 ] \
    || fail "${OWNED_NS}" "no PVCs bound before destroy, so this run cannot prove reclamation"
echo "  postgres + ${PVC_BEFORE} PVC(s) present, namespace owned by '${OWNER}'"

_t "A deployed"
destroy_app "${APP}" "${OWNED_NS}"

if destroy_said "Another app has resources"; then
    fail "${OWNED_NS}" "'${APP}' was alone in '${OWNED_NS}' but destroy named a co-tenant"
fi

wait_ns_gone "${OWNED_NS}" \
    || fail "${OWNED_NS}" "namespace '${OWNED_NS}' still exists ${NS_DELETE_WAIT}s after destroy (#7968 regression)"
echo "  namespace reclaimed, so postgres and every PVC went with it"

STRANDED=$(kubectl get pv -o json 2>/dev/null | python3 -c "
import json, sys
pvs = json.load(sys.stdin).get('items', [])
print(' '.join(
    p['metadata']['name'] for p in pvs
    if (p.get('spec', {}).get('claimRef') or {}).get('namespace') == '${OWNED_NS}'
    and p.get('status', {}).get('phase') == 'Bound'
))")
[ -z "${STRANDED}" ] || { echo "FAIL: PersistentVolume(s) still Bound to the destroyed namespace: ${STRANDED}" >&2; exit 1; }
echo "  no stranded bound PVs"
_t "A PASSED"

####################### scenario B + D + E: adopted namespace #######################
echo "=== B: the namespace pre-exists, destroy must not delete it ==="
kubectl delete namespace "${ADOPTED_NS}" --ignore-not-found --timeout=300s >/dev/null 2>&1 || true
kubectl create namespace "${ADOPTED_NS}" >/dev/null
kubectl create configmap "${SENTINEL}" -n "${ADOPTED_NS}" --from-literal=owner=someone-else >/dev/null

deploy_app "${APP}" "${ADOPTED_NS}"

ADOPTED_OWNER="$(ns_owner "${ADOPTED_NS}")"
[ -z "${ADOPTED_OWNER}" ] \
    || fail "${ADOPTED_NS}" "pre-existing namespace was claimed as owned by '${ADOPTED_OWNER}'; destroy would delete a namespace jac-scale did not create"
echo "  adopted namespace left unclaimed"

# D: a shared volume, named from config with no app prefix.
# E: a sibling app's PVC, which shares this app's name prefix.
kubectl apply -n "${ADOPTED_NS}" -f - >/dev/null <<YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${SIBLING}-postgres-data-${SIBLING}-postgres-0
  labels: { managed: jac-scale }
spec:
  accessModes: ["ReadWriteOnce"]
  resources: { requests: { storage: 64Mi } }
YAML
seed_shared_volume_pvc "${ADOPTED_NS}" "${SHARED_VOL}" "${APP}"
seed_shared_volume_pvc "${ADOPTED_NS}" "${SIBLING_VOL}" "${SIBLING}"
seed_shared_volume_pvc "${ADOPTED_NS}" "${LEGACY_VOL}"
seed_ops_rbac "${ADOPTED_NS}" "${APP}"
seed_ops_rbac "${ADOPTED_NS}" "${SIBLING}"
echo "  seeded shared volumes (ours, the sibling's, one unlabelled), sibling PVC and ops RBAC"

_t "B deployed"
destroy_app "${APP}" "${ADOPTED_NS}"

kubectl get namespace "${ADOPTED_NS}" >/dev/null 2>&1 \
    || { echo "FAIL: destroy deleted namespace '${ADOPTED_NS}', which jac-scale did not create" >&2; exit 1; }
require_present "${ADOPTED_NS}" configmap "${SENTINEL}"
echo "  namespace and foreign workload intact"

require_absent "${ADOPTED_NS}" statefulset "${APP}-postgres"
require_absent "${ADOPTED_NS}" deployment "${APP}-deployment"
require_absent "${ADOPTED_NS}" pvc "${APP}-bundles"

# D: our shared volume goes. A co-tenant's stays, and so does one that predates
# the owner label, because in a namespace we do not own it may be the co-tenant's
# and nothing records whose it is.
require_absent  "${ADOPTED_NS}" pvc "${SHARED_VOL}"
require_present "${ADOPTED_NS}" pvc "${SIBLING_VOL}"
require_present "${ADOPTED_NS}" pvc "${LEGACY_VOL}"
echo "  shared volumes: '${SHARED_VOL}' reclaimed, '${SIBLING_VOL}' and unlabelled '${LEGACY_VOL}' kept"

# E: the sibling's PVC must survive. A prefix sweep would have deleted it.
require_present "${ADOPTED_NS}" pvc "${SIBLING}-postgres-data-${SIBLING}-postgres-0"
echo "  sibling app PVC for '${SIBLING}' untouched"

# The ops RBAC sweep must be scoped to the app, not to managed=jac-scale.
require_absent "${ADOPTED_NS}" role "${APP}-ops"
require_absent "${ADOPTED_NS}" rolebinding "${APP}-ops"
require_present "${ADOPTED_NS}" role "${SIBLING}-ops"
require_present "${ADOPTED_NS}" rolebinding "${SIBLING}-ops"
echo "  ops RBAC reclaimed for '${APP}', left alone for '${SIBLING}'"
_t "B+D+E PASSED"

########################## scenario C: co-tenant apps ##########################
echo "=== C: two apps in one namespace, destroying one must not delete the other ==="
kubectl delete namespace "${COTENANT_NS}" --ignore-not-found --timeout=300s >/dev/null 2>&1 || true

# The first deploy creates the namespace and stamps it for APP.
deploy_app "${APP}" "${COTENANT_NS}"
FIRST_OWNER="$(ns_owner "${COTENANT_NS}")"
[ "${FIRST_OWNER}" = "${APP}" ] \
    || fail "${COTENANT_NS}" "expected namespace owned by '${APP}', got '${FIRST_OWNER}'"

# The co-tenant adopts it; the label must still name the first app.
deploy_app "${COTENANT}" "${COTENANT_NS}"
STILL_OWNER="$(ns_owner "${COTENANT_NS}")"
[ "${STILL_OWNER}" = "${APP}" ] \
    || fail "${COTENANT_NS}" "adopting app '${COTENANT}' rewrote the owner label to '${STILL_OWNER}'"
echo "  namespace owned by '${APP}', co-tenant '${COTENANT}' adopted it"

_t "C deployed"
# Destroying the co-tenant must take the adopted path and spare the namespace.
destroy_app "${COTENANT}" "${COTENANT_NS}"

destroy_said "Another app has resources" \
    || fail "${COTENANT_NS}" "destroying '${COTENANT}' removed '${APP}' workloads from the namespace without naming '${APP}', so nobody knows to redeploy it"

kubectl get namespace "${COTENANT_NS}" >/dev/null 2>&1 \
    || { echo "FAIL: destroying co-tenant '${COTENANT}' deleted namespace '${COTENANT_NS}', taking '${APP}' and its database with it" >&2; exit 1; }
require_present "${COTENANT_NS}" statefulset "${APP}-postgres"
require_present "${COTENANT_NS}" pvc "${APP}-bundles"
require_absent "${COTENANT_NS}" statefulset "${COTENANT}-postgres"
echo "  '${APP}' database and volumes survived the co-tenant's destroy"
_t "C adopted-app destroy PASSED"

# The other direction: the owner label names the app that created the
# namespace, never the number of apps still in it, so destroying the owner
# while a co-tenant is deployed must take the shared path too.
deploy_app "${COTENANT}" "${COTENANT_NS}"
OWNER_BEFORE="$(ns_owner "${COTENANT_NS}")"
[ "${OWNER_BEFORE}" = "${APP}" ] \
    || fail "${COTENANT_NS}" "expected namespace still owned by '${APP}', got '${OWNER_BEFORE}'"

destroy_app "${APP}" "${COTENANT_NS}"

kubectl get namespace "${COTENANT_NS}" >/dev/null 2>&1 \
    || { echo "FAIL: destroying owner '${APP}' deleted namespace '${COTENANT_NS}', taking co-tenant '${COTENANT}' and its database with it" >&2; exit 1; }
require_present "${COTENANT_NS}" statefulset "${COTENANT}-postgres"
require_present "${COTENANT_NS}" pvc "${COTENANT}-bundles"
require_absent "${COTENANT_NS}" statefulset "${APP}-postgres"
require_absent "${COTENANT_NS}" pvc "${APP}-bundles"
echo "  '${COTENANT}' database and volumes survived the owner's destroy"
_t "C PASSED"

print_timing_report
echo "=== destroy reclamation REAL e2e PASSED (A B C D E) ==="
