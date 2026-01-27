"""Implementation of minimal cancellation support."""

impl CancellationToken.is_cancelled -> bool {
    return self._cancelled;
}

impl CancellationToken.cancel -> None {
    self._cancelled = True;
}

impl CancellationTokenSource.postinit -> None {
    self.token = CancellationToken();
    self._disposed = False;
}

impl CancellationTokenSource.cancel -> None {
    if not self._disposed and self.token {
        self.token.cancel();
    }
}

impl CancellationTokenSource.dispose -> None {
    self._disposed = True;
    self.token = None;
}
