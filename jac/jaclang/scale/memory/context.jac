import from contextvars { ContextVar }
import from jaclang.runtime.object_model { MISSING }
import from jaclang.runtime.context { ExecutionContext, CallState }

class JScaleExecutionContext(ExecutionContext) {
    def init(
        self: JScaleExecutionContext,
        base_path_dir: str | None = None,
        full_target_path: str | None = None
    ) -> None;
}
