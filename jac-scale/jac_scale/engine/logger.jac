"""Abstract base class for loggers.

This allows different logging backends (standard, CloudWatch, Stackdriver, etc.)
to be plugged in without changing deployment code.
"""
"""Abstract base class for loggers."""
abstract class Logger {
    """Log an info message."""
    def info(message: str, context: dict = {}) -> None abs;

    """Log an error message."""
    def error(message: str, context: dict = {}) -> None abs;

    """Log a warning message."""
    def warning(message: str, context: dict = {}) -> None abs;

    """Log a debug message."""
    def debug(message: str, context: dict = {}) -> None abs;

    """Create a new logger with additional context."""
    def with_context(context: dict) -> Logger abs;
}
