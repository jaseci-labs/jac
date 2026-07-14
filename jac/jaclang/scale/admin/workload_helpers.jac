"""Pure projection helpers for the admin Workloads view.

These are side-effect-free functions (no I/O) extracted from the endpoint
implementation so they can be unit-tested directly. They encode the tricky
Kubernetes pod-naming and status heuristics that the endpoints rely on.
"""

"""Map replica counts to a UI-friendly status.

Picks the worst-case label so a workload with any failing replica surfaces as
'Broken' even if some are still running. Known limitation: a workload stuck with
ready=0, desired>0 and no restarts (e.g. ImagePullBackOff or indefinitely
Pending) falls through to 'Starting' since restart count is the only failure
signal available here; the pods endpoint exposes the true pod phase for that.
"""
def phase_to_status(ready: int, desired: int, restarts: int) -> str {
    if desired > 0 and ready == 0 and restarts > 0 {
        return "Broken";
    }
    if restarts > 0 and ready > 0 {
        return "Unstable";
    }
    if desired > 0 and ready < desired {
        return "Starting";
    }
    if ready > 0 {
        return "Healthy";
    }
    return "Unknown";
}

"""Best-effort recovery of a pod's parent workload name from the pod name.

Pod naming differs by controller:
  - Deployment:  <name>-<replicaset_hash>-<pod_hash>   (two trailing segments)
  - StatefulSet: <name>-<ordinal>                       (one numeric segment)
  - DaemonSet:   <name>-<pod_hash>                       (one segment)
Since this is ambiguous from the name alone, prefer `match_owner` (which
matches against the known workload-name list). This heuristic is the fallback
for the pods endpoint where the name list isn't queried.
"""
def owner_name_from_pod(pod: str) -> str {
    if not pod {
        return "";
    }
    parts = pod.split("-");
    if len(parts) < 2 {
        return pod;
    }
    # StatefulSet pod: trailing numeric ordinal.
    if parts[-1].isdigit() {
        return "-".join(parts[:-1]);
    }
    if len(parts) < 3 {
        return pod;
    }
    return "-".join(parts[:-2]);
}

"""Match a pod to the longest workload name it belongs to.

A pod belongs to workload `nm` when its name equals `nm` or starts with
`nm-`. Choosing the longest match disambiguates e.g. `jaseci-redis-<hash>`
(owner `jaseci-redis`, not `jaseci`). Falls back to the name heuristic when
no workload matches.
"""
def match_owner(pod: str, names: list[str]) -> str {
    best: str = "";
    for nm in names {
        if (pod == nm or pod.startswith(nm + "-")) and len(nm) > len(best) {
            best = nm;
        }
    }
    return best or owner_name_from_pod(pod);
}
