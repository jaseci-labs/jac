"""Cancellation token system for interruptible operations."""

import threading;
import time;
import from typing { Optional, Callable }

"""Minimum interval between cancellation checks (milliseconds).

Matches Pyright's CancellationThrottle behavior to avoid
performance impact from excessive checking.
"""
glob CANCELLATION_CHECK_INTERVAL_MS: int = 5;

"""Exception raised when an operation is cancelled."""
obj OperationCancelledException(Exception) {
    has message: str = "Operation was cancelled",
        is_type_cache_invalid: bool = False;
}

"""Throttles cancellation checks to avoid performance impact.

Only performs actual check every 5ms. Matches Pyright's
CancellationThrottle class from cancellationUtils.ts.
"""
obj CancellationThrottle {
    static has _last_check_timestamp: float = 0;

    static def should_check -> bool;
    static def reset -> None;
}

"""Token for cancelling long-running operations.

Provides thread-safe cancellation that can be checked
during analysis. Checked every ~5ms using CancellationThrottle.
"""
obj CancellationToken {
    has _cancelled: bool = False,
        _lock: threading.Lock | None = None,
        _callbacks: list | None = None;

    def postinit -> None;
    def is_cancelled -> bool;
    def cancel -> None;
    def throw_if_cancelled -> None;
    def register_callback(callback: Callable) -> None;
}

"""Factory for cancellation tokens.

Creates a token that can be cancelled. When cancelled,
all operations using the token should stop.
"""
obj CancellationTokenSource {
    has token: CancellationToken | None = None,
        _disposed: bool = False;

    def postinit -> None;
    def cancel -> None;
    def dispose -> None;
}

"""Check cancellation with throttling.

Only actually checks if 5ms has passed since last check.
Use this in tight loops to avoid performance impact.

Args:
    token: The cancellation token to check.

Raises:
    OperationCancelledException: If cancelled and throttle allows check.
"""
def throw_if_cancellation_requested(token: CancellationToken) -> None;

"""Create a combined token that cancels when any input token cancels.

Useful for combining LSP request cancellation with analysis cancellation.

Args:
    tokens: Variable number of tokens to combine.

Returns:
    A new token that is cancelled when any input is cancelled.
"""
def create_combined_token(*tokens: CancellationToken) -> CancellationToken;
