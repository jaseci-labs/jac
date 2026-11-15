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
