"""Minimal cancellation support for interruptible operations.

Simplified token system - no callbacks, no throttle.
Worker process uses multiprocessing.Event directly.
"""

"""Exception raised when an operation is cancelled."""
obj OperationCancelledException(Exception) {
    has message: str = "Operation was cancelled";
}

"""Simple cancellation token - just tracks cancelled state."""
obj CancellationToken {
    has _cancelled: bool = False;

    """Check if cancellation has been requested."""
    def is_cancelled -> bool;

    """Request cancellation."""
    def cancel -> None;
}

"""Factory for cancellation tokens."""
obj CancellationTokenSource {
    has token: CancellationToken | None = None,
        _disposed: bool = False;

    def postinit -> None;
    """Cancel the token."""
    def cancel -> None;
    """Dispose the source."""
    def dispose -> None;
}
