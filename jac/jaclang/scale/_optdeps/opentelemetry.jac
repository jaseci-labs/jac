import from jaclang.scale._optdeps.optional_deps { is_optional_available }

glob HAS_OTEL: bool = is_optional_available(
         "opentelemetry.exporter.otlp.proto.http.trace_exporter"
     );
