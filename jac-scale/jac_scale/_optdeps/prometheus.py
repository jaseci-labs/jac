"""Guarded re-exports for prometheus-client (install group: [monitoring])."""

try:
    from prometheus_client import (
        CONTENT_TYPE_LATEST,
        REGISTRY,
        CollectorRegistry,
        Counter,
        Gauge,
        Histogram,
        generate_latest,
    )

    HAS_PROMETHEUS = True
except ImportError:
    Counter = None
    Histogram = None
    Gauge = None
    generate_latest = None
    CONTENT_TYPE_LATEST = None
    REGISTRY = None
    CollectorRegistry = None

    HAS_PROMETHEUS = False
