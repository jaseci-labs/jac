"""Guarded re-exports for opentelemetry (install group: [tracing]).

Mirrors `prometheus.jac` / `docker.jac`: callers import from here and
branch on `HAS_OTEL`. Symbols are None (and `HAS_OTEL` False) when the
optional dependency isn't installed, so tracing degrades to a no-op.
"""

with entry {
    try {
        import from opentelemetry { trace }
        import from opentelemetry.trace {
            SpanContext,
            NonRecordingSpan,
            SpanKind,
            TraceFlags,
            set_span_in_context
        }
        import from opentelemetry.sdk.resources { Resource }
        import from opentelemetry.sdk.trace { TracerProvider }
        import from opentelemetry.sdk.trace.export { BatchSpanProcessor }
        import from opentelemetry.sdk.trace.sampling { ParentBased, TraceIdRatioBased }
        import from opentelemetry.sdk.trace.id_generator { IdGenerator }
        import from opentelemetry.exporter.otlp.proto.http.trace_exporter {
            OTLPSpanExporter
        }
        HAS_OTEL = True;
    } except ImportError {
        trace = None;
        SpanContext = None;
        NonRecordingSpan = None;
        SpanKind = None;
        TraceFlags = None;
        set_span_in_context = None;
        Resource = None;
        TracerProvider = None;
        BatchSpanProcessor = None;
        ParentBased = None;
        TraceIdRatioBased = None;
        OTLPSpanExporter = None;
        # `object` (not None) so a subclass definition still compiles when
        # OpenTelemetry is absent; the subclass is only instantiated under
        # a HAS_OTEL guard, so the harmless base is never used at runtime.
        IdGenerator = object;
        HAS_OTEL = False;
    }
}
