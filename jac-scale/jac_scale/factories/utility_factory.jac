"""Factory for creating utility instances (loggers, monitoring, etc.)."""
import from typing { Any }
import from jac_scale.abstractions.logger { Logger }

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
}
