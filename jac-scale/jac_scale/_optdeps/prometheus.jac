"""Guarded re-exports for prometheus-client (install group: [monitoring])."""

with entry {
    try {
        import from prometheus_client {
            Counter,
            Histogram,
            Gauge,
            generate_latest,
            CONTENT_TYPE_LATEST,
            REGISTRY,
            CollectorRegistry
        }
        HAS_PROMETHEUS = True;
    } except ImportError {
        Counter = None;
        Histogram = None;
        Gauge = None;
        generate_latest = None;
        CONTENT_TYPE_LATEST = None;
        REGISTRY = None;
        CollectorRegistry = None;
        HAS_PROMETHEUS = False;
    }
}
