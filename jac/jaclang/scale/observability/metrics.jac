import from typing { Callable }

class MetricsCollector {
    def init(self: MetricsCollector, config: dict[str, any] = {}) -> None;
    def record_request(
        self: MetricsCollector,
        method: str,
        path: str,
        status_code: int,
        duration_seconds: float
    ) -> None;

    def request_started(self: MetricsCollector) -> None;
    def request_finished(self: MetricsCollector) -> None;
    def record_walker(
        self: MetricsCollector,
        walker_name: str,
        duration_seconds: float,
        success: bool = True
    ) -> None;

    def get_endpoint_handler(self: MetricsCollector) -> Callable[..., any];
    def is_enabled(self: MetricsCollector) -> bool;
}

class NoOpMetricsCollector(MetricsCollector) {
    def init(self: NoOpMetricsCollector, config: dict[str, any] = {}) { }
    def record_request(
        self: NoOpMetricsCollector,
        method: str,
        path: str,
        status_code: int,
        duration_seconds: float
    ) { }

    def request_started(self: NoOpMetricsCollector) { }
    def request_finished(self: NoOpMetricsCollector) { }
    def record_walker(
        self: NoOpMetricsCollector,
        walker_name: str,
        duration_seconds: float,
        success: bool = True
    ) { }

    def get_endpoint_handler(self: NoOpMetricsCollector) -> Callable[..., any] {
        def noop { }
        return noop;
    }

    def is_enabled(self: NoOpMetricsCollector) -> bool {
        return False;
    }
}
