"""Guarded re-exports for opentelemetry (install group: [tracing]).

O-02 distributed tracing. Mirrors `prometheus.jac` / `docker.jac`: a
single guarded import block so the rest of jac-scale can `import from
jac_scale._optdeps.opentelemetry { ... }` and branch on `HAS_OTEL`
instead of repeating try/except ImportError everywhere. Every symbol is
None when the optional dependency isn't installed, and `HAS_OTEL` is
False, so callers degrade to a no-op (the gateway + services run
unchanged, just without spans).
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
        import from opentelemetry.sdk.trace.sampling {
            ParentBased,
            TraceIdRatioBased
        }
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
