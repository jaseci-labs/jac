import logging;

glob logger = logging.getLogger(__name__),
     MULTIPROC_DIR_ENV: str = 'PROMETHEUS_MULTIPROC_DIR',
     DEFAULT_BUCKETS: tuple[float, ...] = (
         0.005,
         0.01,
         0.025,
         0.05,
         0.075,
         0.1,
         0.25,
         0.5,
         0.75,
         1.0,
         2.5,
         5.0,
         10.0
     );

def _merges_across_workers -> bool;


obj PrometheusMetricsCollector(MetricsCollector) {
    has config: dict[str, any] = {},
        worker_count: int = 1,
        _multiprocess: bool = False,
        _enabled: bool postinit,
        _namespace: str postinit,
        _include_walker_metrics: bool postinit,
        _registry: any = None,
        _request_count: any = None,
        _request_latency: any = None,
        _active_requests: any = None,
        _walker_latency: any = None,
        _ws_connections_active: any = None,
        _ws_broadcasts_total: any = None,
        _read_tier_retries: any = None,
        _jac_info: any = None;

    def postinit;
    def record_read_tier_retry(unit_key: str);
    def record_ws_connection_opened;
    def record_ws_connection_closed;
    def record_ws_broadcast;
    def record_request(
        method: str, path: str, status_code: int, duration_seconds: float
    ) -> None;

    def request_started;
    def request_finished;
    def record_walker(walker_name: str, duration_seconds: float, success: bool = True);
    def _fleet_diagnosis -> str;
    def worker_exited(pid: int);
    def _scrape_registry -> any;
    def get_endpoint_handler -> Callable[..., any];
    def expose -> bytes;
    def is_enabled -> bool;
}
