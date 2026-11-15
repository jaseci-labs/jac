glob HAS_OTEL: bool = is_optional_available(
         "opentelemetry.exporter.otlp.proto.http.trace_exporter"
     );
