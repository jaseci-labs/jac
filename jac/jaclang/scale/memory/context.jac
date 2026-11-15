import from contextvars { ContextVar }

class JScaleExecutionContext(ExecutionContext) {
    def init(
        self: JScaleExecutionContext,
        base_path_dir: str | None = None,
        full_target_path: str | None = None
    ) -> None;
}
