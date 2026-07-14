import from jaclang.scale.observability.logger { Logger }
import from jaclang.scale.observability.metrics {
    MetricsCollector,
    NoOpMetricsCollector
}
import from jaclang.scale._optdeps.optional_deps { is_optional_available }

class UtilityFactory {
    static def create_logger(
        logger_type: str = 'standard', config: (dict[str, any] | None) = None
    ) -> Logger {
        if logger_type == 'standard' {
            import from jaclang.scale.observability.standard_logger { StandardLogger }
            return StandardLogger(config=config or {});
        } elif logger_type == 'cloudwatch' {
            raise NotImplementedError("CloudWatch logger not yet implemented");
        } elif logger_type == 'elasticsearch' {
            raise NotImplementedError("Elasticsearch logger not yet implemented");
        } else {
            raise ValueError(f"Unsupported logger type: {logger_type}");
        }
    }

    static def create_metrics(
        metrics_type: str = 'prometheus', config: (dict[str, any] | None) = None
    ) -> MetricsCollector {
        if not config or not config.get('enabled', False) {
            return NoOpMetricsCollector();
        }

        if metrics_type == 'prometheus' {
            if not is_optional_available("prometheus_client") {
                return NoOpMetricsCollector();
            }
            import from jaclang.scale.observability.prometheus_metrics {
                PrometheusMetricsCollector
            }
            return PrometheusMetricsCollector(config=config);
        } elif metrics_type == 'none' {
            return NoOpMetricsCollector();
        } else {
            raise ValueError(f"Unsupported metrics type: {metrics_type}");
        }
    }
}
