impl NoOpMetricsCollector.init(
    self: NoOpMetricsCollector, config: dict[str, any] = {}, worker_count: int = 1
) {}

impl NoOpMetricsCollector.record_request(
    self: NoOpMetricsCollector,
    method: str,
    path: str,
    status_code: int,
    duration_seconds: float
) {}

impl NoOpMetricsCollector.request_started(self: NoOpMetricsCollector) {}

impl NoOpMetricsCollector.request_finished(self: NoOpMetricsCollector) {}

impl NoOpMetricsCollector.record_walker(
    self: NoOpMetricsCollector,
    walker_name: str,
    duration_seconds: float,
    success: bool = True
) {}

impl NoOpMetricsCollector.record_ws_connection_opened(self: NoOpMetricsCollector) {}

impl NoOpMetricsCollector.record_ws_connection_closed(self: NoOpMetricsCollector) {}

impl NoOpMetricsCollector.record_ws_broadcast(self: NoOpMetricsCollector) {}

impl NoOpMetricsCollector.record_read_tier_retry(
    self: NoOpMetricsCollector, unit_key: str
) {}

impl NoOpMetricsCollector.worker_exited(self: NoOpMetricsCollector, pid: int) {}

impl NoOpMetricsCollector.get_endpoint_handler(
    self: NoOpMetricsCollector
) -> Callable[..., any] {
    def noop {}
    return noop;
}

impl NoOpMetricsCollector.expose(self: NoOpMetricsCollector) -> bytes {
    return b"";
}

impl NoOpMetricsCollector.is_enabled(self: NoOpMetricsCollector) -> bool {
    return False;
}
