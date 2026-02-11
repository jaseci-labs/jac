"""Factory for creating utility instances (loggers, metrics, etc.)."""
import from typing { Any }
import from jac_scale.abstractions.logger { Logger }
import from jac_scale.abstractions.metrics { MetricsCollector, NoOpMetricsCollector }

"""Factory for creating utility instances."""
class UtilityFactory {
    """Create a logger based on type.

    Args:
        logger_type: Type of logger ('standard', 'cloudwatch', 'elasticsearch', etc.)
        config: Optional logger-specific configuration

    Returns:
        Logger instance

    Raises:
        ValueError: If logger_type is not supported
        NotImplementedError: If logger is not yet implemented
    """
    static def create_logger(
        logger_type: str = 'standard', config: (dict[str, Any] | None) = None
    ) -> Logger {
        if logger_type == 'standard' {
            import from jac_scale.utilities.loggers.standard_logger { StandardLogger }
            return StandardLogger(config=config or {});
        } elif logger_type == 'cloudwatch' {
            raise NotImplementedError("CloudWatch logger not yet implemented") ;
        } elif logger_type == 'elasticsearch' {
            raise NotImplementedError("Elasticsearch logger not yet implemented") ;
        } else {
            raise ValueError(f"Unsupported logger type: {logger_type}") ;
        }
    }

    """Create a metrics collector based on type.

    Args:
        metrics_type: Type of collector ('prometheus' or 'none')
        config: Metrics configuration from jac.toml

    Returns:
        MetricsCollector instance (NoOpMetricsCollector if disabled)
    """
    static def create_metrics(
        metrics_type: str = 'prometheus', config: (dict[str, Any] | None) = None
    ) -> MetricsCollector {
        # Return NoOp collector if metrics are disabled or no config
        if not config or not config.get('enabled', False) {
            return NoOpMetricsCollector();
        }

        if metrics_type == 'prometheus' {
            import from jac_scale.utilities.metrics.prometheus_metrics {
                PrometheusMetricsCollector
            }
            return PrometheusMetricsCollector(config=config);
        } elif metrics_type == 'none' {
            return NoOpMetricsCollector();
        } else {
            raise ValueError(f"Unsupported metrics type: {metrics_type}") ;
        }
    }
}
