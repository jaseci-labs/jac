"""Metrics abstraction for jac_scale.

Provides a clean interface for collecting application metrics.
All metrics implementations should inherit from MetricsCollector.
"""
import from typing { Any, Callable }

"""Abstract base class for metrics collection.

Implementations can provide Prometheus, StatsD, or other backends.
The interface focuses on common HTTP server metrics.
"""
class MetricsCollector {
    """Initialize the metrics collector with configuration."""
    def init(self: MetricsCollector, config: dict[str, Any] = {}) -> None;

    """Record an HTTP request completion."""
    def record_request(
        self: MetricsCollector,
        method: str,
        path: str,
        status_code: int,
        duration_seconds: float
    ) -> None;

    """Increment active request count (call before processing)."""
    def request_started(self: MetricsCollector) -> None;

    """Decrement active request count (call after processing)."""
    def request_finished(self: MetricsCollector) -> None;

    """Record a walker execution."""
    def record_walker(
        self: MetricsCollector,
        walker_name: str,
        duration_seconds: float,
        success: bool = True
    ) -> None;

    """Get the handler for the metrics endpoint."""
    def get_endpoint_handler(self: MetricsCollector) -> Callable[..., Any];

    """Check if metrics collection is enabled."""
    def is_enabled(self: MetricsCollector) -> bool;
}

"""No-op metrics collector for when metrics are disabled.

All methods are safe to call but perform no operations.
This ensures zero overhead when metrics are not needed.
"""
class NoOpMetricsCollector(MetricsCollector) {
    def init(self: NoOpMetricsCollector, config: dict[str, Any] = {}) -> None { }
    def record_request(
        self: NoOpMetricsCollector,
        method: str,
        path: str,
        status_code: int,
        duration_seconds: float
    ) -> None { }

    def request_started(self: NoOpMetricsCollector) -> None { }
    def request_finished(self: NoOpMetricsCollector) -> None { }
    def record_walker(
        self: NoOpMetricsCollector,
        walker_name: str,
        duration_seconds: float,
        success: bool = True
    ) -> None { }

    def get_endpoint_handler(self: NoOpMetricsCollector) -> Callable[..., Any] {
        def noop -> None { }
        return noop;
    }

    def is_enabled(self: NoOpMetricsCollector) -> bool {
        return False;
    }
}
