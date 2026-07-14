"""Workloads admin endpoints.

Exposes a non-technical-friendly view over Kubernetes workloads (Deployments,
StatefulSets, DaemonSets and Pods) in the application's namespace by querying
the in-cluster Prometheus already provisioned by jac-scale's monitoring stack.

All endpoints are admin-only and translate raw PromQL output into friendly
status strings ('Healthy', 'Starting', 'Broken', 'Unstable') so the UI is
purely presentational.

Scoping rule: anything in the user's K8S_NAMESPACE is considered part of
their application. No name-pattern filters; the namespace is the boundary.
"""
import from jaclang.runtimelib.transport { TransportResponse }

"""Workloads mixin providing /admin/workloads/* endpoints."""
obj JacAPIServerWorkloads {
    def register_workloads_endpoints -> None;
    def admin_workloads_summary(Authorization: str | None = None) -> TransportResponse;
    def admin_workloads_list(Authorization: str | None = None) -> TransportResponse;
    def admin_workloads_pods(Authorization: str | None = None) -> TransportResponse;
    def admin_workloads_timeseries(
        range_minutes: int = 60, Authorization: str | None = None
    ) -> TransportResponse;
}
