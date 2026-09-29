class MetricsCollector {
    def init(
        self: MetricsCollector, config: dict[str, any] = {}, worker_count: int = 1
    ) -> None abst;

    def record_request(
        self: MetricsCollector,
        method: str,
        path: str,
        status_code: int,
        duration_seconds: float
    ) -> None abst;

    def request_started(self: MetricsCollector) -> None abst;
    def request_finished(self: MetricsCollector) -> None abst;
    def record_walker(
        self: MetricsCollector,
        walker_name: str,
        duration_seconds: float,
        success: bool = True
    ) -> None abst;

    def record_ws_connection_opened(self: MetricsCollector) -> None abst;
    def record_ws_connection_closed(self: MetricsCollector) -> None abst;
    def record_ws_broadcast(self: MetricsCollector) -> None abst;
    def record_read_tier_retry(self: MetricsCollector, unit_key: str) -> None abst;
    def worker_exited(self: MetricsCollector, pid: int) -> None abst;
    def get_endpoint_handler(self: MetricsCollector) -> Callable[..., any] abst;
    def expose(self: MetricsCollector) -> bytes abst;
    def is_enabled(self: MetricsCollector) -> bool abst;
}

class NoOpMetricsCollector(MetricsCollector) {
    def init(
        self: NoOpMetricsCollector, config: dict[str, any] = {}, worker_count: int = 1
    ) {}

    def record_request(
        self: NoOpMetricsCollector,
        method: str,
        path: str,
        status_code: int,
        duration_seconds: float
    ) {}

    def request_started(self: NoOpMetricsCollector) {}
    def request_finished(self: NoOpMetricsCollector) {}
    def record_walker(
        self: NoOpMetricsCollector,
        walker_name: str,
        duration_seconds: float,
        success: bool = True
    ) {}

    def record_ws_connection_opened(self: NoOpMetricsCollector) {}
    def record_ws_connection_closed(self: NoOpMetricsCollector) {}
    def record_ws_broadcast(self: NoOpMetricsCollector) {}
    def record_read_tier_retry(self: NoOpMetricsCollector, unit_key: str) {}
    def worker_exited(self: NoOpMetricsCollector, pid: int) {}
    def get_endpoint_handler(self: NoOpMetricsCollector) -> Callable[..., any] {
        def noop {}
        return noop;
    }

    def expose(self: NoOpMetricsCollector) -> bytes {
        return b"";
    }

    def is_enabled(self: NoOpMetricsCollector) -> bool {
        return False;
    }
}
