"""Deployments admin endpoints implementation.

Queries the in-cluster Prometheus for kube-state-metrics, node-exporter and
cAdvisor data, then projects it into a flat, UI-friendly shape so the admin
panel can render traffic-light cards without doing any PromQL math.
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

"""Suffixes (relative to the app name) used by the monitoring stack itself.

We hide these from the deployments list so users see only *their* deployments,
not jac-scale's own observability sidecars.
"""
glob _MONITORING_SUFFIXES: list = [
         "-prometheus",
         "-grafana",
         "-kube-state-metrics",
         "-node-exporter"
     ];

"""Map a kube_pod_status_phase result set to a UI-friendly status.

The phase counts come from Prometheus as separate metrics per phase; we pick
the worst-case label so a deployment with any failing pod surfaces as
'Broken' even if some pods are still Running.
"""
def _phase_to_status(running: int, pending: int, failed: int, restarts: int) -> str {
    if failed > 0 {
        return "Broken";
    }
    if restarts > 0 and running > 0 {
        return "Unstable";
    }
    if pending > 0 and running == 0 {
        return "Starting";
    }
    if running > 0 {
        return "Healthy";
    }
    return "Unknown";
}

"""Return True if a deployment name belongs to the jac-scale monitoring stack.

Used to filter out Prometheus/Grafana/kube-state-metrics/node-exporter from
the user-facing deployments list. Matches by suffix to handle apps with
arbitrary `app_name` prefixes.
"""
def _is_monitoring_stack(name: str) -> bool {
    for suffix in _MONITORING_SUFFIXES {
        if name.endswith(suffix) {
            return True;
        }
    }
    return False;
}

"""Group a list of {pod, value} entries by their parent deployment name.

K8s pod names look like `<deployment>-<replicaset_hash>-<pod_hash>`. We strip
the trailing two hash segments to roll pod-level metrics up to the deployment.
"""
def _deployment_name_from_pod(pod: str) -> str {
    if not pod {
        return "";
    }
    parts = pod.split("-");
    if len(parts) < 3 {
        return pod;
    }
    return "-".join(parts[:-2]);
}

"""Register all deployments endpoints under /admin/deployments/*."""
impl JacAPIServerDeployments.register_deployments_endpoints -> None {
    async def summary_handler(request: Request) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_deployments_summary(authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/deployments',
            callback=summary_handler,
            parameters=[],
            response_model=None,
            tags=['Admin'],
            summary='Deployments summary',
            description='Top-line deployment health stats for the admin dashboard (admin only)'
        )
    );
    async def list_handler(request: Request) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_deployments_list(authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/deployments/list',
            callback=list_handler,
            parameters=[],
            response_model=None,
            tags=['Admin'],
            summary='List deployments',
            description='Per-deployment health table for the admin dashboard (admin only)'
        )
    );
    async def detail_handler(request: Request, name: str) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_deployment_detail(name, authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/deployments/{name}',
            callback=detail_handler,
            parameters=[
                APIParameter(
                    name='name',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Deployment name',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Admin'],
            summary='Deployment detail',
            description='Per-pod breakdown for a single deployment (admin only)'
        )
    );
    async def timeseries_handler(
        request: Request, name: str, metric: str = "cpu", range_minutes: int = 60
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.admin_deployment_timeseries(
            name, metric, range_minutes, authorization
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/admin/deployments/{name}/timeseries',
            callback=timeseries_handler,
            parameters=[
                APIParameter(
                    name='name',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Deployment name',
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
            summary='Deployment time-series',
            description='Time-series for CPU/memory/requests on a single deployment (admin only)'
        )
    );
}

"""Build the top-of-page summary cards.

Runs ~5 instant queries against Prometheus and rolls them up into the shape
the UI renders directly. If Prometheus is unreachable the response still
succeeds with `metrics_available: false` so the UI can show a banner instead
of erroring.
"""
impl JacAPIServerDeployments.admin_deployments_summary(
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
    # Probe Prometheus once before fanning out queries. If we can't reach it,
    # surface metrics_available: false so the UI shows the right banner
    # instead of pretending the cluster is empty.
    probe = prom_query(
        f'count(kube_pod_status_phase{{phase="Running"{ns_and}}} == 1)'
    );
    if probe is None {
        return TransportResponse.success(
            data={
                'metrics_available': False,
                'reason': 'Prometheus is configured but unreachable from the app pod (check cross-node networking)',
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

"""Build the per-deployment table.

Joins kube_deployment_status_replicas_available against cAdvisor CPU/memory
metrics, hides the monitoring stack itself, and translates phase + restart
counts into Healthy/Starting/Broken/Unstable.
"""
impl JacAPIServerDeployments.admin_deployments_list(
    Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    namespace = os.environ.get("K8S_NAMESPACE", "");
    if resolve_prometheus_url() is None {
        return TransportResponse.success(
            data={'metrics_available': False, 'deployments': []},
            meta=Meta(extra={'http_status': 200})
        );
    }
    ns_filter = f'namespace="{namespace}"' if namespace else '';
    ns_and = f',{ns_filter}' if ns_filter else '';
    available_raw = prom_query(
        f'kube_deployment_status_replicas_available{{{ns_filter}}}'
            if ns_filter
            else 'kube_deployment_status_replicas_available'
    );
    if available_raw is None {
        return TransportResponse.success(
            data={
                'metrics_available': False,
                'reason': 'Prometheus is configured but unreachable from the app pod',
                'deployments': []
            },
            meta=Meta(extra={'http_status': 200})
        );
    }
    available = available_raw;
    desired = prom_query(
        f'kube_deployment_spec_replicas{{{ns_filter}}}'
            if ns_filter
            else 'kube_deployment_spec_replicas'
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
    desired_by_name = {};
    for entry in desired {
        m = entry.get("metric", {});
        v = entry.get("value", [0, "0"]);
        desired_by_name[m.get("deployment", "")] = int(float(v[1]))
            if len(v) > 1
            else 0;
    }
    cpu_by_deploy: dict = {};
    mem_by_deploy: dict = {};
    restarts_by_deploy: dict = {};
    for entry in cpu_by_pod {
        pod = entry.get("metric", {}).get("pod", "");
        v = entry.get("value", [0, "0"]);
        deploy = _deployment_name_from_pod(pod);
        cpu_by_deploy[deploy] = cpu_by_deploy.get(deploy, 0.0) + float(
            v[1] if len(v) > 1 else 0
        );
    }
    for entry in mem_by_pod {
        pod = entry.get("metric", {}).get("pod", "");
        v = entry.get("value", [0, "0"]);
        deploy = _deployment_name_from_pod(pod);
        mem_by_deploy[deploy] = mem_by_deploy.get(deploy, 0.0) + float(
            v[1] if len(v) > 1 else 0
        );
    }
    for entry in restarts_by_pod {
        pod = entry.get("metric", {}).get("pod", "");
        v = entry.get("value", [0, "0"]);
        deploy = _deployment_name_from_pod(pod);
        restarts_by_deploy[deploy] = restarts_by_deploy.get(deploy, 0) + int(
            float(v[1] if len(v) > 1 else 0)
        );
    }
    deployments: list = [];
    for entry in available {
        m = entry.get("metric", {});
        v = entry.get("value", [0, "0"]);
        name = m.get("deployment", "");
        if not name or _is_monitoring_stack(name) {
            continue;
        }
        avail_count = int(float(v[1])) if len(v) > 1 else 0;
        desired_count = desired_by_name.get(name, avail_count);
        restarts = restarts_by_deploy.get(name, 0);
        running = avail_count;
        pending = max(0, desired_count - avail_count);
        failed = 0;
        if desired_count > 0 and avail_count == 0 and restarts > 0 {
            failed = desired_count;
        }
        status = _phase_to_status(running, pending, failed, restarts);
        deployments.append(
            {
                'name': name,
                'status': status,
                'replicas_ready': avail_count,
                'replicas_desired': desired_count,
                'cpu_cores': round(cpu_by_deploy.get(name, 0.0), 3),
                'memory_bytes': int(mem_by_deploy.get(name, 0.0)),
                'restarts_last_hour': restarts
            }
        );
    }
    def _dep_name(d: dict) -> str {
        return d["name"];
    }
    deployments = sorted(deployments, key=_dep_name);
    return TransportResponse.success(
        data={
            'metrics_available': True,
            'namespace': namespace,
            'deployments': deployments
        },
        meta=Meta(extra={'http_status': 200})
    );
}

"""Per-pod breakdown for one deployment plus requested-vs-used resources."""
impl JacAPIServerDeployments.admin_deployment_detail(
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

"""Range query for one deployment (CPU cores, memory bytes, or request rate)."""
impl JacAPIServerDeployments.admin_deployment_timeseries(
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
