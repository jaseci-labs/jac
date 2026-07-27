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

        IdGenerator = object;
        HAS_OTEL = False;
    }
}
