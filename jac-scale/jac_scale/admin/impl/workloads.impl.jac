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

"""Strip the trailing replicaset/pod hash segments to recover the parent name.

K8s pod names look like `<owner>-<replicaset_hash>-<pod_hash>`. We strip the
trailing two hash segments to roll pod-level metrics up to their owner.
"""
def _owner_name_from_pod(pod: str) -> str {
    if not pod {
        return "";
    }
    parts = pod.split("-");
    if len(parts) < 3 {
        return pod;
    }
    return "-".join(parts[:-2]);
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
    if resolve_prometheus_url() is None {
        return TransportResponse.success(
            data={
                'metrics_available': False,
                'reason': 'Prometheus URL not configured (K8S_APP_NAME unset)',
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
    request_rate = prom_scalar(
        prom_query(f'sum(rate({{__name__=~".+_http_requests_total"{ns_and}}}[1m]))')
    );
    error_rate = prom_scalar(
        prom_query(
            f'sum(rate({{__name__=~".+_http_requests_total",status_code=~"5.."{ns_and}}}[1m]))'
        )
    );
    error_pct = (error_rate / request_rate * 100.0) if request_rate > 0 else 0.0;
    p95_latency = prom_scalar(
        prom_query(
            f'histogram_quantile(0.95, sum(rate({{__name__=~".+_http_request_duration_seconds_bucket"{ns_and}}}[5m])) by (le))'
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
    if resolve_prometheus_url() is None {
        return TransportResponse.success(
            data={'metrics_available': False, 'workloads': []},
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
        f'sum(rate(container_cpu_usage_seconds_total{{pod=~".+"{ns_and}}}[5m])) by (pod)'
    )
    or [];
    mem_by_pod = prom_query(
        f'sum(container_memory_working_set_bytes{{pod=~".+"{ns_and}}}) by (pod)'
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

    cpu_by_owner: dict = {};
    mem_by_owner: dict = {};
    restarts_by_owner: dict = {};
    for entry in cpu_by_pod {
        pod = entry.get("metric", {}).get("pod", "");
        v = entry.get("value", [0, "0"]);
        owner = _owner_name_from_pod(pod);
        cpu_by_owner[owner] = cpu_by_owner.get(owner, 0.0) + float(
            v[1] if len(v) > 1 else 0
        );
    }
    for entry in mem_by_pod {
        pod = entry.get("metric", {}).get("pod", "");
        v = entry.get("value", [0, "0"]);
        owner = _owner_name_from_pod(pod);
        mem_by_owner[owner] = mem_by_owner.get(owner, 0.0) + float(
            v[1] if len(v) > 1 else 0
        );
    }
    for entry in restarts_by_pod {
        pod = entry.get("metric", {}).get("pod", "");
        v = entry.get("value", [0, "0"]);
        owner = _owner_name_from_pod(pod);
        restarts_by_owner[owner] = restarts_by_owner.get(owner, 0) + int(
            float(v[1] if len(v) > 1 else 0)
        );
    }

    workloads: list = [];

    def _append(name: str, kind: str, ready: int, desired: int, created: int) {
        restarts = restarts_by_owner.get(name, 0);
        status = _phase_to_status(ready, desired, restarts);
        workloads.append(
            {
                'name': name,
                'kind': kind,
                'status': status,
                'replicas_ready': ready,
                'replicas_desired': desired,
                'cpu_cores': round(cpu_by_owner.get(name, 0.0), 3),
                'memory_bytes': int(mem_by_owner.get(name, 0.0)),
                'restarts_last_hour': restarts,
                'created': created
            }
        );
    }

    for entry in dep_available_raw {
        m = entry.get("metric", {});
        v = entry.get("value", [0, "0"]);
        name = m.get("deployment", "");
        if not name {
            continue;
        }
        ready = int(float(v[1])) if len(v) > 1 else 0;
        _append(
            name,
            "Deployment",
            ready,
            dep_desired_by.get(name, ready),
            dep_created_by.get(name, 0)
        );
    }
    for entry in sts_ready {
        m = entry.get("metric", {});
        v = entry.get("value", [0, "0"]);
        name = m.get("statefulset", "");
        if not name {
            continue;
        }
        ready = int(float(v[1])) if len(v) > 1 else 0;
        _append(
            name,
            "StatefulSet",
            ready,
            sts_desired_by.get(name, ready),
            sts_created_by.get(name, 0)
        );
    }
    for entry in ds_ready {
        m = entry.get("metric", {});
        v = entry.get("value", [0, "0"]);
        name = m.get("daemonset", "");
        if not name {
            continue;
        }
        ready = int(float(v[1])) if len(v) > 1 else 0;
        _append(
            name,
            "DaemonSet",
            ready,
            ds_desired_by.get(name, ready),
            ds_created_by.get(name, 0)
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
    if resolve_prometheus_url() is None {
        return TransportResponse.success(
            data={'metrics_available': False, 'pods': []},
            meta=Meta(extra={'http_status': 200})
        );
    }
    ns_filter = f'namespace="{namespace}"' if namespace else '';
    ns_and = f',{ns_filter}' if ns_filter else '';
    phase_by_pod = prom_query(f'kube_pod_status_phase{{{ns_filter}}} == 1' if ns_filter
        else 'kube_pod_status_phase == 1');
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
        f'sum(rate(container_cpu_usage_seconds_total{{pod=~".+"{ns_and}}}[5m])) by (pod)'
    )
    or [];
    mem_by_pod = prom_query(
        f'sum(container_memory_working_set_bytes{{pod=~".+"{ns_and}}}) by (pod)'
    )
    or [];
    restarts_by_pod = prom_query(
        f'sum(increase(kube_pod_container_status_restarts_total{{{ns_filter}}}[1h])) by (pod)'
            if ns_filter
            else 'sum(increase(kube_pod_container_status_restarts_total[1h])) by (pod)'
    )
    or [];
    node_by_pod = prom_query(f'kube_pod_info{{{ns_filter}}}' if ns_filter
        else 'kube_pod_info')
    or [];
    started_by_pod = prom_query(f'kube_pod_start_time{{{ns_filter}}}' if ns_filter
        else 'kube_pod_start_time')
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
        data={
            'metrics_available': True,
            'namespace': namespace,
            'pods': pods
        },
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
        f'sum(rate(container_cpu_usage_seconds_total{{{pod_filter}{ns_and}}}[5m])) by (pod)'
    )
    or [];
    mem_by_pod = prom_query(
        f'sum(container_memory_working_set_bytes{{{pod_filter}{ns_and}}}) by (pod)'
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
        promql = f'sum(container_memory_working_set_bytes{{{pod_filter}{ns_and}}})';
    } elif metric == "requests" {
        promql = f'sum(rate({{__name__=~".+_http_requests_total"{ns_and}}}[1m]))';
    } else {
        promql = f'sum(rate(container_cpu_usage_seconds_total{{{pod_filter}{ns_and}}}[5m]))';
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
