"""Prometheus metrics implementation for jac_scale.

Provides HTTP request metrics, active request tracking, and optional
walker execution timing using the prometheus-client library.
"""
import from typing { Any, Callable }
import from jac_scale.abstractions.metrics { MetricsCollector }
import from prometheus_client {
    Counter,
    Histogram,
    Gauge,
    generate_latest,
    CONTENT_TYPE_LATEST,
    REGISTRY,
    CollectorRegistry
}
import from fastapi.responses { Response }

# Default histogram buckets (in seconds) - optimized for typical web latencies
glob DEFAULT_BUCKETS:
         tuple = (
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

"""Prometheus-based metrics collector.

Exposes standard HTTP metrics that can be scraped by Prometheus:
- Request count by method, path, and status code
- Request latency histogram
- Active requests gauge
- Optional walker execution timing
"""
class PrometheusMetricsCollector(MetricsCollector) {
    has _enabled: bool = True,
        _namespace: str = "jac_scale",
        _include_walker_metrics: bool = False,
        _registry: CollectorRegistry | None = None,
        _request_count: Counter | None = None,
        _request_latency: Histogram | None = None,
        _active_requests: Gauge | None = None,
        _walker_latency: Histogram | None = None;

    def init(self: PrometheusMetricsCollector, config: dict[str, Any] = {}) -> None {
        self._enabled = bool(config.get("enabled", True));
        self._namespace = str(config.get("namespace", "jac_scale"));
        self._include_walker_metrics = bool(config.get("walker_metrics", False));

        if not self._enabled {
            return;
        }

        # Use custom registry to avoid conflicts in tests
        self._registry = REGISTRY;

        buckets = config.get("histogram_buckets");
        if buckets {
            buckets = tuple(buckets);
        } else {
            buckets = DEFAULT_BUCKETS;
        }

        # HTTP request counter
        self._request_count = Counter(
            f"{self._namespace}_http_requests_total",
            "Total HTTP requests processed",
            ["method", "path", "status_code"],
            registry=self._registry
        );

        # HTTP request latency histogram
        self._request_latency = Histogram(
            f"{self._namespace}_http_request_duration_seconds",
            "HTTP request latency in seconds",
            ["method", "path"],
            buckets=buckets,
            registry=self._registry
        );

        # Active requests gauge
        self._active_requests = Gauge(
            f"{self._namespace}_http_requests_in_progress",
            "Number of HTTP requests currently being processed",
            registry=self._registry
        );

        # Optional walker metrics
        if self._include_walker_metrics {
            self._walker_latency = Histogram(
                f"{self._namespace}_walker_duration_seconds",
                "Walker execution duration in seconds",
                ["walker_name", "success"],
                buckets=buckets,
                registry=self._registry
            );
        }
    }

    def record_request(
        self: PrometheusMetricsCollector,
        method: str,
        path: str,
        status_code: int,
        duration_seconds: float
    ) -> None {
        if not self._enabled {
            return;
        }
        self._request_count.labels(
            method=method, path=path, status_code=str(status_code)
        ).inc();
        self._request_latency.labels(method=method, path=path).observe(
            duration_seconds
        );
    }

    def request_started(self: PrometheusMetricsCollector) -> None {
        if self._enabled and self._active_requests {
            self._active_requests.inc();
        }
    }

    def request_finished(self: PrometheusMetricsCollector) -> None {
        if self._enabled and self._active_requests {
            self._active_requests.dec();
        }
    }

    def record_walker(
        self: PrometheusMetricsCollector,
        walker_name: str,
        duration_seconds: float,
        success: bool = True
    ) -> None {
        if self._enabled and self._walker_latency {
            self._walker_latency.labels(
                walker_name=walker_name, success=str(success).lower()
            ).observe(
                duration_seconds
            );
        }
    }

    def get_endpoint_handler(self: PrometheusMetricsCollector) -> Callable[..., Any] {
        registry = self._registry;
        def metrics_endpoint -> Response {
            return Response(
                content=generate_latest(registry), media_type=CONTENT_TYPE_LATEST
            );
        }
        return metrics_endpoint;
    }

    def is_enabled(self: PrometheusMetricsCollector) -> bool {
        return self._enabled;
    }
}
