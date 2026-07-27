import from typing { Callable }
import from jaclang.scale.observability.metrics { MetricsCollector }
import from jaclang.scale._optdeps.prometheus {
    Counter,
    Histogram,
    Gauge,
    generate_latest,
    CONTENT_TYPE_LATEST,
    CollectorRegistry
}
import from fastapi.responses { Response }

glob DEFAULT_BUCKETS: tuple = (
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

obj PrometheusMetricsCollector(MetricsCollector) {
    has config: dict[str, any] = {},
        _enabled: bool postinit,
        _namespace: str postinit,
        _include_walker_metrics: bool postinit,
        _registry: CollectorRegistry | None = None,
        _request_count: Counter | None = None,
        _request_latency: Histogram | None = None,
        _active_requests: Gauge | None = None,
        _walker_latency: Histogram | None = None,
        _ws_connections_active: Gauge | None = None,
        _ws_broadcasts_total: Counter | None = None;

    def postinit {
        self._enabled = bool(self.config.get("enabled", True));
        self._namespace = str(self.config.get("namespace", "jaclang_scale"));
        self._include_walker_metrics = bool(self.config.get("walker_metrics", False));

        if not self._enabled {
            return;
        }

        if self._registry is None {
            self._registry = CollectorRegistry();
        }

        try {
            import from prometheus_client {
                ProcessCollector,
                PlatformCollector,
                GCCollector
            }
            ProcessCollector(registry=self._registry);
            PlatformCollector(registry=self._registry);
            GCCollector(registry=self._registry);
        } except Exception { }

        buckets = self.config.get("histogram_buckets");
        if buckets {
            buckets = tuple(buckets);
        } else {
            buckets = DEFAULT_BUCKETS;
        }

        self._request_count = Counter(
            f"{self._namespace}_http_requests_total",
            "Total HTTP requests processed",
            ["method", "path", "status_code"],
            registry=self._registry
        );

        self._request_latency = Histogram(
            f"{self._namespace}_http_request_duration_seconds",
            "HTTP request latency in seconds",
            ["method", "path"],
            buckets=buckets,
            registry=self._registry
        );

        self._active_requests = Gauge(
            f"{self._namespace}_http_requests_in_progress",
            "Number of HTTP requests currently being processed",
            registry=self._registry
        );

        if self._include_walker_metrics {
            self._walker_latency = Histogram(
                f"{self._namespace}_walker_duration_seconds",
                "Walker execution duration in seconds",
                ["walker_name", "success"],
                buckets=buckets,
                registry=self._registry
            );
        }

        self._ws_connections_active = Gauge(
            f"{self._namespace}_ws_connections_active",
            "Active WebSocket connections",
            registry=self._registry
        );

        self._ws_broadcasts_total = Counter(
            f"{self._namespace}_ws_broadcasts_total",
            "WebSocket broadcast publishes",
            registry=self._registry
        );
    }

    def record_ws_connection_opened {
        if self._enabled and self._ws_connections_active {
            self._ws_connections_active.inc();
        }
    }

    def record_ws_connection_closed {
        if self._enabled and self._ws_connections_active {
            self._ws_connections_active.dec();
        }
    }

    def record_ws_broadcast {
        if self._enabled and self._ws_broadcasts_total {
            self._ws_broadcasts_total.inc();
        }
    }

    def record_request(
        method: str, path: str, status_code: int, duration_seconds: float
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

    def request_started {
        if self._enabled and self._active_requests {
            self._active_requests.inc();
        }
    }

    def request_finished {
        if self._enabled and self._active_requests {
            self._active_requests.dec();
        }
    }

    def record_walker(walker_name: str, duration_seconds: float, success: bool = True) {
        if self._enabled and self._walker_latency {
            self._walker_latency.labels(
                walker_name=walker_name, success=str(success).lower()
            ).observe(
                duration_seconds
            );
        }
    }

    def get_endpoint_handler -> Callable[..., any] {
        registry = self._registry;
        def metrics_endpoint -> Response {
            return Response(
                content=generate_latest(registry), media_type=CONTENT_TYPE_LATEST
            );
        }
        return metrics_endpoint;
    }

    def expose -> bytes {
        return generate_latest(self._registry);
    }

    def is_enabled -> bool {
        return self._enabled;
    }
}
