#!/usr/bin/env bash
# Shared helpers for the real-cluster e2e scripts
# (k8s_microservice_real_e2e.sh and tests/deploy/sdk_deploy_real_e2e.sh).

# --- phase timing ----------------------------------------------------------
# Call e2e_timing_init once, then _t "label" per phase;
# print_timing_report renders the table (and the GitHub job summary).
_T0=0
_LAST_T=0
_PHASE_ROWS=""

e2e_timing_init() {
    _T0=$(date +%s)
    _LAST_T=0
    _PHASE_ROWS=""
}

_t() {
    now=$(( $(date +%s) - _T0 ))
    step=$(( now - _LAST_T ))
    echo "[TIMING +${now}s] $1 (+${step}s)"
    _PHASE_ROWS="${_PHASE_ROWS}${1}|${step}|${now}"$'\n'
    _LAST_T=${now}
}

print_timing_report() {
    echo ""
    echo "======================= E2E PHASE TIMING REPORT ======================="
    printf "%-38s %10s %12s\n" "PHASE" "STEP (s)" "CUMUL (s)"
    printf "%-38s %10s %12s\n" "--------------------------------------" "--------" "----------"
    printf '%s' "${_PHASE_ROWS}" | while IFS='|' read -r label step cumul; do
        [ -z "${label}" ] && continue
        printf "%-38s %10s %12s\n" "${label}" "${step}" "${cumul}"
    done
    printf "%-38s %10s %12s\n" "--------------------------------------" "--------" "----------"
    printf "%-38s %10s %12s\n" "TOTAL" "" "${_LAST_T}"
    echo "======================================================================="
    echo "# CLUSTER_TYPE=${CLUSTER_TYPE:-}  services=$(printf '%s' "${ROUTES:-}" | grep -c . || echo 0)"
    # Also surface the report on the GitHub Actions job-summary page.
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
        {
            echo "## E2E phase timing (${CLUSTER_TYPE:-})"
            echo ""
            echo "| Phase | Step (s) | Cumulative (s) |"
            echo "|---|---:|---:|"
            printf '%s' "${_PHASE_ROWS}" | while IFS='|' read -r label step cumul; do
                [ -z "${label}" ] && continue
                echo "| ${label} | ${step} | ${cumul} |"
            done
            echo "| **TOTAL** | | **${_LAST_T}** |"
        } >> "${GITHUB_STEP_SUMMARY}"
    fi
}

# --- kind RWX storage ------------------------------------------------------
# kind's local-path StorageClass is RWO-only; on single-node kind a static
# hostPath PV satisfies the ReadWriteMany bundle PVC. Recreated each run so a
# Released PV can't block binding. kubelet makes the hostPath dir root:0755
# but the pods run non-root; a one-shot root pod opens it up (0777 is fine on
# an ephemeral single-node test cluster).
provision_kind_rwx_storage() {
    local namespace="$1" storage_class="$2" pv_name="$3" host_path="$4" perms_pod="$5"
    echo "=== provisioning RWX hostPath storage for kind (class=${storage_class}) ==="
    kubectl delete pv "${pv_name}" --ignore-not-found >/dev/null 2>&1 || true
    kubectl apply -f - <<YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${storage_class}
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: Immediate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${pv_name}
  labels:
    managed: jac-scale-e2e
spec:
  capacity:
    storage: 20Gi
  accessModes: ["ReadWriteMany"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ${storage_class}
  hostPath:
    path: ${host_path}
    type: DirectoryOrCreate
YAML
    kubectl -n "${namespace}" delete pod "${perms_pod}" --ignore-not-found >/dev/null 2>&1 || true
    kubectl -n "${namespace}" apply -f - <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: ${perms_pod}
  labels:
    managed: jac-scale
spec:
  restartPolicy: Never
  securityContext:
    runAsUser: 0
  containers:
    - name: fix
      image: busybox:1.36
      command: ["sh", "-c", "chmod 0777 /host && echo perms-fixed"]
      volumeMounts:
        - { name: host, mountPath: /host }
  volumes:
    - name: host
      hostPath:
        path: ${host_path}
        type: DirectoryOrCreate
YAML
    if ! kubectl -n "${namespace}" wait --for=jsonpath='{.status.phase}'=Succeeded \
            "pod/${perms_pod}" --timeout=90s; then
        echo "FAIL: could not open up the RWX hostPath dir for non-root pods"
        kubectl -n "${namespace}" logs "${perms_pod}" || true
        kubectl -n "${namespace}" describe pod "${perms_pod}" || true
        return 1
    fi
    kubectl -n "${namespace}" delete pod "${perms_pod}" --ignore-not-found >/dev/null 2>&1 || true
}
