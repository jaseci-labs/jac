import from dataclasses { MISSING }
import from typing { Any }
import from uuid { UUID }
import from jaclang.pycore.constant { Constants as Con }
import from jaclang.runtimelib.context { ExecutionContext }

"""Jac Scale Execution Context with custom memory backend."""
class JScaleExecutionContext(ExecutionContext) {
    def init(
        self: JScaleExecutionContext,
        session: (str | None) = None,
        <>root: (str | None) = None
    ) -> None;
}
