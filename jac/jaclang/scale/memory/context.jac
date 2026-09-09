import from contextvars { ContextVar }
import from jaclang.runtime.object_model { MISSING }
import from jaclang.runtime.context { ExecutionContext, CallState }

class JScaleExecutionContext(ExecutionContext) {
    def init(self: JScaleExecutionContext) -> None;
}
