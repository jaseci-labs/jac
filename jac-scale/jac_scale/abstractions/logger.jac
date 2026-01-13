"""Base logger abstraction for jac_scale.

All logger implementations should inherit from this class.
"""
import from typing { Any }

"""Base class for all logger implementations."""
class Logger {
    """Log an info message."""
    def info(self: Logger, message: str, context: dict[str, Any] = {}) -> None;

    """Log an error message."""
    def error(self: Logger, message: str, context: dict[str, Any] = {}) -> None;

    """Log a warning message."""
    def warn(self: Logger, message: str, context: dict[str, Any] = {}) -> None;

    """Log a debug message."""
    def debug(self: Logger, message: str, context: dict[str, Any] = {}) -> None;
}
