import from dataclasses { MISSING }
import from typing { Any }
import from uuid { UUID }
import from jaclang.pycore.constant { Constants as Con }
import from jaclang.runtimelib.context { ExecutionContext }

"""Jac Scale Execution Context with custom memory backend.

Storage backend is configured via environment variables (e.g., MONGODB_URI),
not per-context parameters.
"""
class JScaleExecutionContext(ExecutionContext) {
    def init(self: JScaleExecutionContext) -> None;
}
