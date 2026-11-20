glob LOG_DEPTH: int = 6;

obj JobStep {
    has label: str = "",
        state: str = "wait",
        detail: str = "";
}

obj JobProgress {
    has active: bool = False,
        phase: str = "idle",
        detail: str = "",
        steps: list[JobStep] = [],
        log: list[str] = [],
        updated_at: str = "";

    def begin(phase: str);
    def note(detail: str);
    def mark(label: str, state: str, detail: str);
    def finish;
    def fail(detail: str);
}
