import from contextvars { ContextVar }
import from dataclasses { MISSING }
import from jaclang.runtimelib.context { ExecutionContext, CallState }

class JScaleExecutionContext(ExecutionContext) {
    def init(self: JScaleExecutionContext) -> None;
}
