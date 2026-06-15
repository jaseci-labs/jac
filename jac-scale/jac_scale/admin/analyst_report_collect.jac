"""A-07 Performance Report - deterministic collectors (health + per-pod USE).

Reuses the in-cluster Prometheus via prometheus_client with the SAME proven
PromQL the admin Workloads view (#6186) uses, so metric names / labels are
correct (app traffic is `*_http_requests_total` / `*_http_request_duration_
seconds_bucket` with a `status_code` label; resource usage is cAdvisor +
kube-state-metrics). Namespace-scoped by K8S_NAMESPACE - the namespace is the
application boundary. No model involved; pure read-only metric queries.
"""
import os;
import logging;
import from jac_scale.utilities.metrics.prometheus_client { query, scalar }
import from jac_scale.admin.analyst_report { ReportHealth, PodUsage }

glob logger = logging.getLogger(__name__);


"""Namespace filter fragments from K8S_NAMESPACE: ('namespace="x"', ',namespace="x"')
or ('', '') off-K8s. The second form appends into a selector with other labels."""
def _ns_filters -> tuple {
    ns = os.environ.get("K8S_NAMESPACE", "").strip();
    if not ns {
        return ("", "");
    }
    return (f'namespace="{ns}"', f',namespace="{ns}"');
}


"""Index a Prometheus vector result `[{metric:{pod:..}, value:[ts,"v"]}]` into
{pod -> float}. Skips entries with no `pod` label."""
def _by_pod(rows: any) -> dict {
    out: dict = {};
    for r in (rows or []) {
        pod = str((r.get("metric", {}) or {}).get("pod", "") or "");
        if not pod {
            continue;
        }
        try {
            out[pod] = float((r.get("value", [0, 0]) or [0, 0])[1]);
        } except Exception {
            out[pod] = 0.0;
        }
    }
    return out;
}


"""Index pod -> phase from `kube_pod_status_phase == 1` (carries pod + phase)."""
def _phase_by_pod(rows: any) -> dict {
    out: dict = {};
    for r in (rows or []) {
        m = r.get("metric", {}) or {};
        pod = str(m.get("pod", "") or "");
        phase = str(m.get("phase", "") or "");
        if pod and phase {
            out[pod] = phase;
        }
    }
    return out;
}


"""Memory rank key for a PodUsage (typed so mem_mb resolves to float)."""
def _pod_mem(p: PodUsage) -> float {
    return p.mem_mb;
}


"""Collect the executive-summary health: pod/node counts + top-line RED
(req/s, 5xx ratio, p95). Best-effort: missing series fall back to 0 via
scalar(). Off-cluster (no Prometheus) yields an all-zero 'unknown' health."""
def collect_health -> ReportHealth {
    (ns_filter, ns_and) = _ns_filters();
    running = int(scalar(query(f'count(kube_pod_status_phase{{phase="Running"{ns_and}}} == 1)')));
    pending = int(scalar(query(f'count(kube_pod_status_phase{{phase="Pending"{ns_and}}} == 1)')));
    failed = int(scalar(query(f'count(kube_pod_status_phase{{phase="Failed"{ns_and}}} == 1)')));
    nodes = int(scalar(query('count(kube_node_info)')));
    # App traffic series carry no namespace label (only k8s SD metrics do);
    # Prometheus is per-namespace so an unfiltered match is safe (#6186).
    req_ps = scalar(query('sum(rate({__name__=~".+_http_requests_total"}[1m]))'));
    err_ps = scalar(
        query('sum(rate({__name__=~".+_http_requests_total",status_code=~"5.."}[1m]))')
    );
    p95 = scalar(
        query(
            'histogram_quantile(0.95, sum(rate({__name__=~".+_http_request_duration_seconds_bucket"}[5m])) by (le))'
        )
    );
    error_rate = (err_ps / req_ps) if req_ps > 0.0 else 0.0;
    if failed > 0 or error_rate > 0.05 {
        status = "Degraded";
    } elif running > 0 {
        status = "Healthy";
    } else {
        status = "Unknown";
    }
    return ReportHealth(
        status=status,
        pods_running=running,
        pods_pending=pending,
        pods_failed=failed,
        nodes_ready=nodes,
        req_per_s=req_ps,
        error_rate=error_rate,
        p95_latency_s=p95
    );
}


"""Collect per-pod USE: CPU cores, memory (MB), restarts, status - joined by
pod name across four Prometheus queries. Sorted by memory desc, top `top_n`."""
def collect_pod_usage(top_n: int = 20) -> list[PodUsage] {
    (ns_filter, ns_and) = _ns_filters();
    cpu = _by_pod(
        query(f'sum(rate(container_cpu_usage_seconds_total{{pod=~".+",container!=""{ns_and}}}[5m])) by (pod)')
    );
    mem = _by_pod(
        query(f'sum(container_memory_working_set_bytes{{pod=~".+",container!=""{ns_and}}}) by (pod)')
    );
    restarts_q = (
        f'sum(increase(kube_pod_container_status_restarts_total{{{ns_filter}}}[1h])) by (pod)'
        if ns_filter
        else 'sum(increase(kube_pod_container_status_restarts_total[1h])) by (pod)'
    );
    restarts = _by_pod(query(restarts_q));
    phase_q = (
        f'kube_pod_status_phase{{{ns_filter}}} == 1' if ns_filter
        else 'kube_pod_status_phase == 1'
    );
    phases = _phase_by_pod(query(phase_q));

    names: dict = {};
    for src in [cpu, mem, restarts, phases] {
        for k in src {
            names[k] = True;
        }
    }
    pods: list[PodUsage] = [];
    for pod_key in names.keys() {
        pod = str(pod_key);
        pods.append(
            PodUsage(
                pod=pod,
                status=str(phases.get(pod, "") or ""),
                cpu_cores=float(cpu.get(pod, 0.0)),
                mem_mb=float(mem.get(pod, 0.0)) / 1000000.0,
                restarts=int(float(restarts.get(pod, 0.0)))
            )
        );
    }
    pods.sort(key=_pod_mem, reverse=True);
    return pods[:top_n];
}
