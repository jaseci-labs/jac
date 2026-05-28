"""Workloads admin endpoints implementation.

Queries the in-cluster Prometheus for kube-state-metrics and cAdvisor data,
then projects it into a flat, UI-friendly shape so the admin panel can render
traffic-light cards without doing any PromQL math.

Scopes everything by K8S_NAMESPACE — the namespace IS the application boundary,
no name-pattern filtering. The monitoring stack (Prometheus, Grafana, etc.)
shows up in the list and the UI labels it as infrastructure.
"""
import os;
import time;
import logging;
import from fastapi { Request }
import from jaclang.runtimelib.transport { TransportResponse, Meta }
import from jac_scale.jserver.jserver {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}
import from jac_scale.utilities.metrics.prometheus_client {
    query as prom_query,
    query_range as prom_query_range,
    scalar as prom_scalar,
    resolve_prometheus_url
}

glob logger = logging.getLogger(__name__);

"""Map replica counts to a UI-friendly status.

Picks the worst-case label so a workload with any failing replica surfaces as
'Broken' even if some are still running.
"""
def _phase_to_status(ready: int, desired: int, restarts: int) -> str {
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
Since this is ambiguous from the name alone, prefer `_match_owner` (which
matches against the known workload-name list). This heuristic is the fallback
for the pods endpoint where the name list isn't queried.
"""
def _owner_name_from_pod(pod: str) -> str {
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
def _match_owner(pod: str, names: list) -> str {
    best = "";
    for nm in names {
        if (pod == nm or pod.startswith(nm + "-")) and len(nm) > len(best) {
            best = nm;
        }
    }
    return best or _owner_name_from_pod(pod);
}

"""Return a user-facing reason string when metrics can't be shown, else "".

Distinguishes "monitoring disabled in jac.toml" (the stack was never deployed)
from "Prometheus URL unresolved" so the UI can tell the user to enable
monitoring rather than implying a transient outage.
"""
def _unavailable_reason() -> str {
    try {
        import from jac_scale.config_loader { get_scale_config }
        if not bool(get_scale_config().get_monitoring_config().get('enabled', False)) {
            return "Monitoring is disabled. Set [plugins.scale.monitoring] enabled = true in jac.toml and redeploy to see workload metrics.";
        }
    } except Exception {}
    if resolve_prometheus_url() is None {
        return "Prometheus URL not configured (K8S_APP_NAME unset).";
    }
    return "";
}

"""Register all workloads endpoints under /admin/workloads/*."""
impl JacAPIServerWorkloads.register_workloads_endpoints -> None {
    async def summary_handler(request: Request) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_workloads_summary(authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/workloads',
            callback=summary_handler,
            parameters=[],
            response_model=None,
            tags=['Admin'],
            summary='Workloads summary',
            description='Top-line workload health stats for the admin dashboard (admin only)'
        )
    );
    async def list_handler(request: Request) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_workloads_list(authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/workloads/list',
            callback=list_handler,
            parameters=[],
            response_model=None,
            tags=['Admin'],
            summary='List workloads',
            description='Per-workload health table (Deployments, StatefulSets, DaemonSets) for the admin dashboard (admin only)'
        )
    );
    async def pods_handler(request: Request) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_workloads_pods(authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/workloads/pods',
            callback=pods_handler,
            parameters=[],
            response_model=None,
            tags=['Admin'],
            summary='List pods',
            description='Per-pod health table for the admin dashboard (admin only)'
        )
    );
    # Registered before the '{name}' route so the static path wins the match.
    async def all_timeseries_handler(
        request: Request, range_minutes: int = 60
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_workloads_timeseries(range_minutes, authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/workloads/timeseries',
            callback=all_timeseries_handler,
            parameters=[
                APIParameter(
                    name='range_minutes',
                    data_type='integer',
                    required=False,
                    default=60,
                    description='Range in minutes (60=1h, 360=6h, 1440=24h, 10080=7d)',
                    type=ParameterType.QUERY
                )
            ],
            response_model=None,
            tags=['Admin'],
            summary='All-workload time-series',
            description='CPU + memory time-series for every workload over a range (admin only)'
        )
    );
    async def detail_handler(request: Request, name: str) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_workload_detail(name, authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/workloads/{name}',
            callback=detail_handler,
            parameters=[
                APIParameter(
                    name='name',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Workload name',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Admin'],
            summary='Workload detail',
            description='Per-pod breakdown for a single workload (admin only)'
        )
    );
    async def timeseries_handler(
        request: Request, name: str, metric: str = "cpu", range_minutes: int = 60
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_workload_timeseries(
            name, metric, range_minutes, authorization
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/workloads/{name}/timeseries',
            callback=timeseries_handler,
            parameters=[
                APIParameter(
                    name='name',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Workload name',
                    type=ParameterType.PATH
                ),
                APIParameter(
                    name='metric',
                    data_type='string',
                    required=False,
                    default='cpu',
                    description='Metric (cpu, memory, requests)',
                    type=ParameterType.QUERY
                ),
                APIParameter(
                    name='range_minutes',
                    data_type='integer',
                    required=False,
                    default=60,
                    description='Range in minutes (e.g. 60 for last hour)',
                    type=ParameterType.QUERY
                )
            ],
            response_model=None,
            tags=['Admin'],
            summary='Workload time-series',
            description='Time-series for CPU/memory/requests on a single workload (admin only)'
        )
    );
}

"""Build the top-of-page summary cards.

Runs ~5 instant queries against Prometheus and rolls them up into the shape
the UI renders directly. If Prometheus is unreachable the response still
succeeds with `metrics_available: false` so the UI can show a banner instead
of erroring.
"""
impl JacAPIServerWorkloads.admin_workloads_summary(
    Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    namespace = os.environ.get("K8S_NAMESPACE", "");
    reason = _unavailable_reason();
    if reason {
        return TransportResponse.success(
            data={
                'metrics_available': False,
                'reason': reason,
                'namespace': namespace
            },
            meta=Meta(extra={'http_status': 200})
        );
    }
    ns_filter = f'namespace="{namespace}"' if namespace else '';
    ns_and = f',{ns_filter}' if ns_filter else '';
    probe = prom_query(f'count(kube_pod_status_phase{{phase="Running"{ns_and}}} == 1)');
    if probe is None {
        return TransportResponse.success(
            data={
                'metrics_available': False,
                'reason': 'Prometheus is configured but unreachable from the app pod',
                'namespace': namespace
            },
            meta=Meta(extra={'http_status': 200})
        );
    }
    running = int(prom_scalar(probe));
    pending = int(
        prom_scalar(
            prom_query(f'count(kube_pod_status_phase{{phase="Pending"{ns_and}}} == 1)')
        )
    );
    failed = int(
        prom_scalar(
            prom_query(f'count(kube_pod_status_phase{{phase="Failed"{ns_and}}} == 1)')
        )
    );
    nodes_ready = int(
        prom_scalar(
            prom_query(
                'count(kube_node_status_condition{condition="Ready",status="true"} == 1)'
            )
        )
    );
    nodes_total = int(prom_scalar(prom_query('count(kube_node_info)')));
    # The app's own /metrics series carry no `namespace` label (only k8s SD
    # metrics do), so these app-traffic queries are NOT namespace-filtered.
    # Safe because Prometheus is per-namespace and only this app exposes
    # *_http_requests_total here.
    request_rate = prom_scalar(
        prom_query('sum(rate({__name__=~".+_http_requests_total"}[1m]))')
    );
    error_rate = prom_scalar(
        prom_query(
            'sum(rate({__name__=~".+_http_requests_total",status_code=~"5.."}[1m]))'
        )
    );
    error_pct = (error_rate / request_rate * 100.0) if request_rate > 0 else 0.0;
    p95_latency = prom_scalar(
        prom_query(
            'histogram_quantile(0.95, sum(rate({__name__=~".+_http_request_duration_seconds_bucket"}[5m])) by (le))'
        )
    );
    return TransportResponse.success(
        data={
            'metrics_available': True,
            'namespace': namespace,
            'pods': {'running': running, 'pending': pending, 'failed': failed},
            'nodes': {'ready': nodes_ready, 'total': nodes_total},
            'traffic': {
                'requests_per_sec': round(request_rate, 2),
                'error_rate_pct': round(error_pct, 2),
                'p95_latency_ms': round(p95_latency * 1000.0, 1)
            }
        },
        meta=Meta(extra={'http_status': 200})
    );
}

"""Build the per-workload table including Deployments, StatefulSets and DaemonSets.

Joins kube-state-metrics replica counts against cAdvisor CPU/memory metrics
and rolls each pod's usage up to its parent workload by stripping the
replicaset/pod hash suffix. Scope is the entire K8S_NAMESPACE.
"""
impl JacAPIServerWorkloads.admin_workloads_list(
    Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    namespace = os.environ.get("K8S_NAMESPACE", "");
    reason = _unavailable_reason();
    if reason {
        return TransportResponse.success(
            data={'metrics_available': False, 'reason': reason, 'workloads': []},
            meta=Meta(extra={'http_status': 200})
        );
    }
    ns_filter = f'namespace="{namespace}"' if namespace else '';
    ns_and = f',{ns_filter}' if ns_filter else '';
    # Probe Prometheus once before fanning out queries.
    dep_available_raw = prom_query(
        f'kube_deployment_status_replicas_available{{{ns_filter}}}'
            if ns_filter
            else 'kube_deployment_status_replicas_available'
    );
    if dep_available_raw is None {
        return TransportResponse.success(
            data={
                'metrics_available': False,
                'reason': 'Prometheus is configured but unreachable from the app pod',
                'workloads': []
            },
            meta=Meta(extra={'http_status': 200})
        );
    }
    dep_desired = prom_query(
        f'kube_deployment_spec_replicas{{{ns_filter}}}'
            if ns_filter
            else 'kube_deployment_spec_replicas'
    )
    or [];
    sts_ready = prom_query(
        f'kube_statefulset_status_replicas_ready{{{ns_filter}}}'
            if ns_filter
            else 'kube_statefulset_status_replicas_ready'
    )
    or [];
    sts_desired = prom_query(
        f'kube_statefulset_replicas{{{ns_filter}}}'
            if ns_filter
            else 'kube_statefulset_replicas'
    )
    or [];
    ds_ready = prom_query(
        f'kube_daemonset_status_number_available{{{ns_filter}}}'
            if ns_filter
            else 'kube_daemonset_status_number_available'
    )
    or [];
    ds_desired = prom_query(
        f'kube_daemonset_status_desired_number_scheduled{{{ns_filter}}}'
            if ns_filter
            else 'kube_daemonset_status_desired_number_scheduled'
    )
    or [];
    cpu_by_pod = prom_query(
        f'sum(rate(container_cpu_usage_seconds_total{{pod=~".+",container!=""{ns_and}}}[5m])) by (pod)'
    )
    or [];
    mem_by_pod = prom_query(
        f'sum(container_memory_working_set_bytes{{pod=~".+",container!=""{ns_and}}}) by (pod)'
    )
    or [];
    restarts_by_pod = prom_query(
        f'sum(increase(kube_pod_container_status_restarts_total{{{ns_filter}}}[1h])) by (pod)'
            if ns_filter
            else 'sum(increase(kube_pod_container_status_restarts_total[1h])) by (pod)'
    )
    or [];
    dep_created = prom_query(
        f'kube_deployment_created{{{ns_filter}}}'
            if ns_filter
            else 'kube_deployment_created'
    )
    or [];
    sts_created = prom_query(
        f'kube_statefulset_created{{{ns_filter}}}'
            if ns_filter
            else 'kube_statefulset_created'
    )
    or [];
    ds_created = prom_query(
        f'kube_daemonset_created{{{ns_filter}}}'
            if ns_filter
            else 'kube_daemonset_created'
    )
    or [];

    def _index_by_label(rows: list, label: str) -> dict {
        out: dict = {};
        for entry in rows {
            key = entry.get("metric", {}).get(label, "");
            v = entry.get("value", [0, "0"]);
            if key {
                out[key] = int(float(v[1])) if len(v) > 1 else 0;
            }
        }
        return out;
    }

    dep_desired_by = _index_by_label(dep_desired, "deployment");
    sts_desired_by = _index_by_label(sts_desired, "statefulset");
    ds_desired_by = _index_by_label(ds_desired, "daemonset");
    dep_created_by = _index_by_label(dep_created, "deployment");
    sts_created_by = _index_by_label(sts_created, "statefulset");
    ds_created_by = _index_by_label(ds_created, "daemonset");

    # Build the workload entries first so we know every workload name before
    # rolling pod-level metrics up to their owner.
    entries: list = [];
    wl_names: list = [];
    for entry in dep_available_raw {
        m = entry.get("metric", {});
        v = entry.get("value", [0, "0"]);
        name = m.get("deployment", "");
        if not name {
            continue;
        }
        ready = int(float(v[1])) if len(v) > 1 else 0;
        entries.append(
            {
                'name': name,
                'kind': "Deployment",
                'ready': ready,
                'desired': dep_desired_by.get(name, ready),
                'created': dep_created_by.get(name, 0)
            }
        );
        wl_names.append(name);
    }
    for entry in sts_ready {
        m = entry.get("metric", {});
        v = entry.get("value", [0, "0"]);
        name = m.get("statefulset", "");
        if not name {
            continue;
        }
        ready = int(float(v[1])) if len(v) > 1 else 0;
        entries.append(
            {
                'name': name,
                'kind': "StatefulSet",
                'ready': ready,
                'desired': sts_desired_by.get(name, ready),
                'created': sts_created_by.get(name, 0)
            }
        );
        wl_names.append(name);
    }
    for entry in ds_ready {
        m = entry.get("metric", {});
        v = entry.get("value", [0, "0"]);
        name = m.get("daemonset", "");
        if not name {
            continue;
        }
        ready = int(float(v[1])) if len(v) > 1 else 0;
        entries.append(
            {
                'name': name,
                'kind': "DaemonSet",
                'ready': ready,
                'desired': ds_desired_by.get(name, ready),
                'created': ds_created_by.get(name, 0)
            }
        );
        wl_names.append(name);
    }

    # Roll pod-level metrics up to the longest matching workload name.
    cpu_by_owner: dict = {};
    mem_by_owner: dict = {};
    restarts_by_owner: dict = {};
    for entry in cpu_by_pod {
        pod = entry.get("metric", {}).get("pod", "");
        v = entry.get("value", [0, "0"]);
        owner = _match_owner(pod, wl_names);
        cpu_by_owner[owner] = cpu_by_owner.get(owner, 0.0) + float(
            v[1] if len(v) > 1 else 0
        );
    }
    for entry in mem_by_pod {
        pod = entry.get("metric", {}).get("pod", "");
        v = entry.get("value", [0, "0"]);
        owner = _match_owner(pod, wl_names);
        mem_by_owner[owner] = mem_by_owner.get(owner, 0.0) + float(
            v[1] if len(v) > 1 else 0
        );
    }
    for entry in restarts_by_pod {
        pod = entry.get("metric", {}).get("pod", "");
        v = entry.get("value", [0, "0"]);
        owner = _match_owner(pod, wl_names);
        restarts_by_owner[owner] = restarts_by_owner.get(owner, 0) + int(
            float(v[1] if len(v) > 1 else 0)
        );
    }

    workloads: list = [];
    for e in entries {
        name = e["name"];
        restarts = restarts_by_owner.get(name, 0);
        status = _phase_to_status(e["ready"], e["desired"], restarts);
        workloads.append(
            {
                'name': name,
                'kind': e["kind"],
                'status': status,
                'replicas_ready': e["ready"],
                'replicas_desired': e["desired"],
                'cpu_cores': round(cpu_by_owner.get(name, 0.0), 3),
                'memory_bytes': int(mem_by_owner.get(name, 0.0)),
                'restarts_last_hour': restarts,
                'created': e["created"]
            }
        );
    }

    def _wl_name(d: dict) -> str {
        return d["name"];
    }
    workloads = sorted(workloads, key=_wl_name);
    return TransportResponse.success(
        data={
            'metrics_available': True,
            'namespace': namespace,
            'workloads': workloads
        },
        meta=Meta(extra={'http_status': 200})
    );
}

"""List every individual pod in the namespace with status + resource usage."""
impl JacAPIServerWorkloads.admin_workloads_pods(
    Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    namespace = os.environ.get("K8S_NAMESPACE", "");
    reason = _unavailable_reason();
    if reason {
        return TransportResponse.success(
            data={'metrics_available': False, 'reason': reason, 'pods': []},
            meta=Meta(extra={'http_status': 200})
        );
    }
    ns_filter = f'namespace="{namespace}"' if namespace else '';
    ns_and = f',{ns_filter}' if ns_filter else '';
    phase_by_pod = prom_query(
        f'kube_pod_status_phase{{{ns_filter}}} == 1'
            if ns_filter
            else 'kube_pod_status_phase == 1'
    );
    if phase_by_pod is None {
        return TransportResponse.success(
            data={
                'metrics_available': False,
                'reason': 'Prometheus is configured but unreachable from the app pod',
                'pods': []
            },
            meta=Meta(extra={'http_status': 200})
        );
    }
    cpu_by_pod = prom_query(
        f'sum(rate(container_cpu_usage_seconds_total{{pod=~".+",container!=""{ns_and}}}[5m])) by (pod)'
    )
    or [];
    mem_by_pod = prom_query(
        f'sum(container_memory_working_set_bytes{{pod=~".+",container!=""{ns_and}}}) by (pod)'
    )
    or [];
    restarts_by_pod = prom_query(
        f'sum(increase(kube_pod_container_status_restarts_total{{{ns_filter}}}[1h])) by (pod)'
            if ns_filter
            else 'sum(increase(kube_pod_container_status_restarts_total[1h])) by (pod)'
    )
    or [];
    node_by_pod = prom_query(
        f'kube_pod_info{{{ns_filter}}}' if ns_filter else 'kube_pod_info'
    )
    or [];
    started_by_pod = prom_query(
        f'kube_pod_start_time{{{ns_filter}}}' if ns_filter else 'kube_pod_start_time'
    )
    or [];

    def _index_float_by_pod(rows: list) -> dict {
        out: dict = {};
        for entry in rows {
            pod = entry.get("metric", {}).get("pod", "");
            v = entry.get("value", [0, "0"]);
            if pod {
                out[pod] = float(v[1]) if len(v) > 1 else 0.0;
            }
        }
        return out;
    }
    cpu = _index_float_by_pod(cpu_by_pod);
    mem = _index_float_by_pod(mem_by_pod);
    restarts = _index_float_by_pod(restarts_by_pod);
    started = _index_float_by_pod(started_by_pod);
    node_for: dict = {};
    for entry in node_by_pod {
        m = entry.get("metric", {});
        pod = m.get("pod", "");
        node_name = m.get("node", "");
        if pod {
            node_for[pod] = node_name;
        }
    }
    pods: list = [];
    for entry in phase_by_pod {
        m = entry.get("metric", {});
        pod = m.get("pod", "");
        phase = m.get("phase", "Unknown");
        if not pod {
            continue;
        }
        pods.append(
            {
                'name': pod,
                'phase': phase,
                'owner': _owner_name_from_pod(pod),
                'node': node_for.get(pod, ''),
                'cpu_cores': round(cpu.get(pod, 0.0), 3),
                'memory_bytes': int(mem.get(pod, 0.0)),
                'restarts_last_hour': int(restarts.get(pod, 0.0)),
                'created': int(started.get(pod, 0.0))
            }
        );
    }
    def _pod_name(d: dict) -> str {
        return d["name"];
    }
    pods = sorted(pods, key=_pod_name);
    return TransportResponse.success(
        data={'metrics_available': True, 'namespace': namespace, 'pods': pods},
        meta=Meta(extra={'http_status': 200})
    );
}

"""Per-pod breakdown for one workload plus requested-vs-used resources."""
impl JacAPIServerWorkloads.admin_workload_detail(
    name: str, Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    namespace = os.environ.get("K8S_NAMESPACE", "");
    if resolve_prometheus_url() is None {
        return TransportResponse.success(
            data={'metrics_available': False, 'name': name, 'pods': []},
            meta=Meta(extra={'http_status': 200})
        );
    }
    ns_filter = f'namespace="{namespace}"' if namespace else '';
    ns_and = f',{ns_filter}' if ns_filter else '';
    pod_filter = f'pod=~"{name}-.+"';
    cpu_by_pod = prom_query(
        f'sum(rate(container_cpu_usage_seconds_total{{{pod_filter},container!=""{ns_and}}}[5m])) by (pod)'
    )
    or [];
    mem_by_pod = prom_query(
        f'sum(container_memory_working_set_bytes{{{pod_filter},container!=""{ns_and}}}) by (pod)'
    )
    or [];
    cpu_request_by_pod = prom_query(
        f'sum(kube_pod_container_resource_requests{{resource="cpu",{pod_filter}{ns_and}}}) by (pod)'
    )
    or [];
    mem_request_by_pod = prom_query(
        f'sum(kube_pod_container_resource_requests{{resource="memory",{pod_filter}{ns_and}}}) by (pod)'
    )
    or [];
    phase_by_pod = prom_query(f'kube_pod_status_phase{{{pod_filter}{ns_and}}} == 1')
    or [];
    restarts_by_pod = prom_query(
        f'sum(increase(kube_pod_container_status_restarts_total{{{pod_filter}{ns_and}}}[1h])) by (pod)'
    )
    or [];
    def _index_by_pod(rows: list) -> dict {
        out = {};
        for entry in rows {
            pod = entry.get("metric", {}).get("pod", "");
            v = entry.get("value", [0, "0"]);
            if pod {
                out[pod] = float(v[1]) if len(v) > 1 else 0.0;
            }
        }
        return out;
    }
    cpu_used = _index_by_pod(cpu_by_pod);
    mem_used = _index_by_pod(mem_by_pod);
    cpu_req = _index_by_pod(cpu_request_by_pod);
    mem_req = _index_by_pod(mem_request_by_pod);
    restarts = _index_by_pod(restarts_by_pod);
    phase_for: dict = {};
    for entry in phase_by_pod {
        m = entry.get("metric", {});
        pod = m.get("pod", "");
        phase = m.get("phase", "");
        if pod and phase {
            phase_for[pod] = phase;
        }
    }
    all_pods = set();
    for d in [cpu_used, mem_used, cpu_req, mem_req, phase_for, restarts] {
        for k in d {
            all_pods.add(k);
        }
    }
    pods = [];
    for pod in sorted(all_pods) {
        pods.append(
            {
                'pod': pod,
                'phase': phase_for.get(pod, 'Unknown'),
                'cpu_cores': round(cpu_used.get(pod, 0.0), 3),
                'cpu_requested_cores': round(cpu_req.get(pod, 0.0), 3),
                'memory_bytes': int(mem_used.get(pod, 0.0)),
                'memory_requested_bytes': int(mem_req.get(pod, 0.0)),
                'restarts_last_hour': int(restarts.get(pod, 0.0))
            }
        );
    }
    return TransportResponse.success(
        data={
            'metrics_available': True,
            'name': name,
            'namespace': namespace,
            'pods': pods
        },
        meta=Meta(extra={'http_status': 200})
    );
}

"""Range query for one workload (CPU cores, memory bytes, or request rate)."""
impl JacAPIServerWorkloads.admin_workload_timeseries(
    name: str,
    metric: str = "cpu",
    range_minutes: int = 60,
    Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    namespace = os.environ.get("K8S_NAMESPACE", "");
    if resolve_prometheus_url() is None {
        return TransportResponse.success(
            data={
                'metrics_available': False,
                'name': name,
                'metric': metric,
                'points': []
            },
            meta=Meta(extra={'http_status': 200})
        );
    }
    ns_filter = f'namespace="{namespace}"' if namespace else '';
    ns_and = f',{ns_filter}' if ns_filter else '';
    pod_filter = f'pod=~"{name}-.+"';
    if metric == "memory" {
        promql = f'sum(container_memory_working_set_bytes{{{pod_filter},container!=""{ns_and}}})';
    } elif metric == "requests" {
        promql = 'sum(rate({__name__=~".+_http_requests_total"}[1m]))';
    } else {
        promql = f'sum(rate(container_cpu_usage_seconds_total{{{pod_filter},container!=""{ns_and}}}[5m]))';
    }
    now = time.time();
    start = now - (range_minutes * 60);
    step = "30s" if range_minutes <= 60 else "5m";
    result = prom_query_range(promql, start, now, step);
    points: list = [];
    if result {
        for entry in result {
            values = entry.get("values", []);
            for v in values {
                if len(v) >= 2 {
                    try {
                        points.append({'t': float(v[0]), 'v': float(v[1])});
                    } except (ValueError, TypeError) {
                        continue;
                    }
                }
            }
        }
    }
    return TransportResponse.success(
        data={
            'metrics_available': result is not None,
            'name': name,
            'metric': metric,
            'range_minutes': range_minutes,
            'points': points
        },
        meta=Meta(extra={'http_status': 200})
    );
}

"""Roll a `by (pod)` range-query result up to per-workload time-series.

Returns {workload_name: {timestamp: summed_value}}. Pods are matched to the
longest owning workload name (same logic as the list endpoint).
"""
def _rollup_range(rows: list, names: list) -> dict {
    out: dict = {};
    for entry in rows {
        pod = entry.get("metric", {}).get("pod", "");
        owner = _match_owner(pod, names);
        series = out.get(owner, {});
        for v in entry.get("values", []) {
            if len(v) >= 2 {
                try {
                    ts = float(v[0]);
                    series[ts] = series.get(ts, 0.0) + float(v[1]);
                } except (ValueError, TypeError) {
                    continue;
                }
            }
        }
        out[owner] = series;
    }
    return out;
}

"""Flatten a {timestamp: value} map into a sorted list of {t, v} points."""
def _series_points(tsmap: dict) -> list {
    pts: list = [];
    for ts in sorted(tsmap.keys()) {
        pts.append({'t': ts, 'v': round(tsmap[ts], 4)});
    }
    return pts;
}

"""CPU + memory time-series for every workload over a range, in one response.

Powers the admin Graphs tab: two range queries (cpu, memory) bucketed by pod,
rolled up to workloads. `range_minutes` picks both the window and the step so
point counts stay reasonable (1h/30s, 6h/2m, 24h/10m, 7d/1h).
"""
impl JacAPIServerWorkloads.admin_workloads_timeseries(
    range_minutes: int = 60, Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    namespace = os.environ.get("K8S_NAMESPACE", "");
    reason = _unavailable_reason();
    if reason {
        return TransportResponse.success(
            data={
                'metrics_available': False,
                'reason': reason,
                'range_minutes': range_minutes,
                'workloads': []
            },
            meta=Meta(extra={'http_status': 200})
        );
    }
    ns_filter = f'namespace="{namespace}"' if namespace else '';
    ns_and = f',{ns_filter}' if ns_filter else '';
    # Collect workload names so pods can be rolled up to their owner.
    names: list = [];
    for spec in [
        ('kube_deployment_created', 'deployment'),
        ('kube_statefulset_created', 'statefulset'),
        ('kube_daemonset_created', 'daemonset')
    ] {
        rows = prom_query(f'{spec[0]}{{{ns_filter}}}' if ns_filter else spec[0]) or [];
        for r in rows {
            nm = r.get("metric", {}).get(spec[1], "");
            if nm {
                names.append(nm);
            }
        }
    }
    if range_minutes <= 60 {
        step = "30s";
        step_seconds = 30;
    } elif range_minutes <= 360 {
        step = "2m";
        step_seconds = 120;
    } elif range_minutes <= 1440 {
        step = "10m";
        step_seconds = 600;
    } else {
        step = "1h";
        step_seconds = 3600;
    }
    now = time.time();
    start = now - (range_minutes * 60);
    cpu_rows = prom_query_range(
        f'sum(rate(container_cpu_usage_seconds_total{{pod=~".+",container!=""{ns_and}}}[5m])) by (pod)',
        start,
        now,
        step
    );
    if cpu_rows is None {
        return TransportResponse.success(
            data={
                'metrics_available': False,
                'reason': 'Prometheus is configured but unreachable from the app pod',
                'range_minutes': range_minutes,
                'workloads': []
            },
            meta=Meta(extra={'http_status': 200})
        );
    }
    mem_rows = prom_query_range(
        f'sum(container_memory_working_set_bytes{{pod=~".+",container!=""{ns_and}}}) by (pod)',
        start,
        now,
        step
    )
    or [];
    cpu_by_wl = _rollup_range(cpu_rows, names);
    mem_by_wl = _rollup_range(mem_rows, names);
    all_names = set();
    for nm in names {
        all_names.add(nm);
    }
    for nm in cpu_by_wl {
        all_names.add(nm);
    }
    for nm in mem_by_wl {
        all_names.add(nm);
    }
    workloads: list = [];
    for nm in sorted(all_names) {
        workloads.append(
            {
                'name': nm,
                'cpu': _series_points(cpu_by_wl.get(nm, {})),
                'memory': _series_points(mem_by_wl.get(nm, {}))
            }
        );
    }
    return TransportResponse.success(
        data={
            'metrics_available': True,
            'namespace': namespace,
            'range_minutes': range_minutes,
            'step_seconds': step_seconds,
            'workloads': workloads
        },
        meta=Meta(extra={'http_status': 200})
    );
}
