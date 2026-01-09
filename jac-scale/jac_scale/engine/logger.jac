"""Abstract base class for loggers.

This allows different logging backends (standard, CloudWatch, Stackdriver, etc.)
to be plugged in without changing deployment code.
"""
"""Abstract base class for loggers."""
abstract class Logger {
    """Log an info message."""
    abstract def info(message: str, context: dict = {}) -> None;
    
    """Log an error message."""
    abstract def error(message: str, context: dict = {}) -> None;
    
    """Log a warning message."""
    abstract def warning(message: str, context: dict = {}) -> None;
    
    """Log a debug message."""
    abstract def debug(message: str, context: dict = {}) -> None;
    
    """Create a new logger with additional context."""
    abstract def with_context(context: dict) -> Logger;
}

