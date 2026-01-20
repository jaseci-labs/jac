"""Implementation of cancellation token system."""

import threading;
import time;
import from typing { Optional, Callable }

"""Check if enough time has passed to perform a cancellation check.

Returns True if at least 5ms has passed since last check.
This prevents excessive checking in tight loops.
"""
impl CancellationThrottle.should_check -> bool {
    current_time_ms = time.time() * 1000;
    time_since_last_check = current_time_ms - CancellationThrottle._last_check_timestamp;
    if time_since_last_check >= CANCELLATION_CHECK_INTERVAL_MS {
        CancellationThrottle._last_check_timestamp = current_time_ms;
        return True;
    }
    return False;
}

"""Reset the throttle timestamp (for testing)."""
impl CancellationThrottle.reset -> None {
    CancellationThrottle._last_check_timestamp = 0;
}

"""Initialize CancellationToken."""
impl CancellationToken.postinit -> None {
    self._cancelled = False;
    self._lock = threading.Lock();
    self._callbacks = [];
}

"""Check if cancellation has been requested.

Thread-safe check that can be called from any thread.
"""
impl CancellationToken.is_cancelled -> bool {
    with self._lock {
        return self._cancelled;
    }
}

"""Request cancellation and notify all registered callbacks.

Once cancelled, the token stays cancelled (cannot be reset).
"""
impl CancellationToken.cancel -> None {
    callbacks_to_run = [];
    with self._lock {
        if self._cancelled {
            return;  # Already cancelled

        }
        self._cancelled = True;
        callbacks_to_run = self._callbacks.copy();
    }
    # Run callbacks outside the lock
    for callback in callbacks_to_run {
        try {
            callback();
        } except Exception as e {
            # Log but don't fail
            print(f"Cancellation callback error: {e}");
        }
    }
}

"""Throw OperationCancelledException if cancelled.

Use this in operations that should stop when cancelled.
"""
impl CancellationToken.throw_if_cancelled -> None {
    if self.is_cancelled() {
        raise OperationCancelledException() ;
    }
}

"""Register a callback to be called when cancellation is requested.

Callbacks are called immediately if already cancelled.

Args:
    callback: Function to call on cancellation.
"""
impl CancellationToken.register_callback(callback: Callable) -> None {
    run_immediately = False;
    with self._lock {
        if self._cancelled {
            run_immediately = True;
        } else {
            self._callbacks.append(callback);
        }
    }
    if run_immediately {
        try {
            callback();
        } except Exception as e {
            print(f"Cancellation callback error: {e}");
        }
    }
}

"""Initialize CancellationTokenSource with a new token."""
impl CancellationTokenSource.postinit -> None {
    self.token = CancellationToken();
    self._disposed = False;
}

"""Cancel the token created by this source."""
impl CancellationTokenSource.cancel -> None {
    if not self._disposed and self.token {
        self.token.cancel();
    }
}

"""Dispose the token source (prevents further use)."""
impl CancellationTokenSource.dispose -> None {
    self._disposed = True;
    self.token = None;
}

"""Check cancellation with throttling.

Only actually checks if 5ms has passed since last check.
Raises OperationCancelledException if cancelled.
"""
impl throw_if_cancellation_requested(token: CancellationToken) -> None {
    if CancellationThrottle.should_check() and token.is_cancelled() {
        raise OperationCancelledException() ;
    }
}

"""Create a combined token that cancels when any input token cancels."""
impl create_combined_token(*tokens: CancellationToken) -> CancellationToken {
    combined = CancellationToken();
    # Check if any token is already cancelled
    for token in tokens {
        if token.is_cancelled() {
            combined.cancel();
            return combined;
        }
    }
    # Register callbacks to propagate cancellation
    def propagate_cancellation {
        combined.cancel();
    }
    for token in tokens {
        token.register_callback(propagate_cancellation);
    }
    return combined;
}
