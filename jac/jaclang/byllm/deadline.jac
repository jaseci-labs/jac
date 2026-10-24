import time;

obj CallDeadline {
    has budget: float | None = None,
        model: str = "",
        started_at: float = 0.0;

    def postinit;
    def remaining -> float | None;
    def bound(seconds: float) -> float;
    def check;
    def expired -> LLMTimeout;
}

impl CallDeadline.postinit {
    if not self.started_at {
        self.started_at = time.monotonic();
    }
}

impl CallDeadline.remaining -> float | None {
    if self.budget is None {
        return None;
    }
    return self.budget - (time.monotonic() - self.started_at);
}

impl CallDeadline.bound(seconds: float) -> float {
    left = self.remaining();
    if left is None {
        return seconds;
    }
    return max(0.0, min(seconds, left));
}

impl CallDeadline.check {
    left = self.remaining();
    if left is not None and left <= 0 {
        raise self.expired();
    }
}

impl CallDeadline.expired -> LLMTimeout {
    return LLMTimeout(
        message=(
            f"by llm() call to {self.model} did not finish within its "
            f"{self.budget:g}s timeout"
        ),
        model=self.model
    );
}
