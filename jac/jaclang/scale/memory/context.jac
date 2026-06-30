import from contextvars { ContextVar }
import from dataclasses { MISSING }
import from uuid { UUID }
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.runtimelib.context { ExecutionContext, CallState }

class JScaleExecutionContext(ExecutionContext) {
    def init(self: JScaleExecutionContext) -> None;
}
