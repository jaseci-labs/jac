import from contextvars { ContextVar }
import from dataclasses { MISSING }
import from uuid { UUID }
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.jac0core.archetype { NodeAnchor }
import from jaclang.runtimelib.context { ExecutionContext, CallState }

def _independent_super_root(template: (NodeAnchor | None)) -> (NodeAnchor | None);

class JScaleExecutionContext(ExecutionContext) {
    def init(self: JScaleExecutionContext) -> None;
}
