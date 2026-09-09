import from jaclang.server.transport { TransportResponse }
import from jaclang.server.server { EndpointHost }

obj JacAPIServerWorkloads {
    has server: (EndpointHost | None) = None;

    def require_admin(Authorization: str | None) -> (TransportResponse | None);
    def register_workloads_endpoints -> None;
    def admin_workloads_summary(Authorization: str | None = None) -> TransportResponse;
    def admin_workloads_list(Authorization: str | None = None) -> TransportResponse;
    def admin_workloads_pods(Authorization: str | None = None) -> TransportResponse;
    def admin_workloads_timeseries(
        range_minutes: int = 60, Authorization: str | None = None
    ) -> TransportResponse;
}
