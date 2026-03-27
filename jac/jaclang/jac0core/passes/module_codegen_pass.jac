"""Shared base for codegen passes that operate on Module AST."""
import from collections.abc { Sequence }
import from typing { TYPE_CHECKING }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { CodeContext }
import from jaclang.jac0core.passes.transform { Transform }

with entry {
    if TYPE_CHECKING {
        import from jaclang.jac0core.program { JacProgram }
    }
}

"""Base for all module-level codegen passes.

Provides static helpers for context-block unwrapping and body
extraction, used by PyastGenPass, EsastGenPass, and NaIRGenPass.
"""
obj ModuleCodegenPass(Transform[uni.Module, uni.Module]) {
    """Unwrap ImplDef wrapper to get body statements.

    Returns the body as a Sequence, handling both direct list bodies
    and ImplDef-wrapped bodies. Returns None if body is not a list.
    """
    static def unwrap_body(
        nd: uni.Archetype | uni.Enum | uni.Ability
    ) -> (Sequence | None) {
        body = nd.body;
        if (isinstance(body, uni.ImplDef) and isinstance(body.body, `list)) {
            return body.body;
        }
        if isinstance(body, `list) {
            return body;
        }
        return None;
    }

    """Iterate top-level statements for a given context.

    Unwraps NativeBlock/ClientBlock/ServerBlock and yields their
    children matching the given CodeContext. When ctx is None, yields
    all statements from all blocks (flat iteration).
    """
    static def iter_context_stmts(
        module: uni.Module, ctx: (CodeContext | None) = None
    ) -> list[uni.ElementStmt] {
        result: list[uni.ElementStmt] = [];
        for stmt in module.body {
            if isinstance(stmt, uni.NativeBlock) {
                if (ctx is None or ctx == CodeContext.NATIVE) {
                    result.extend(stmt.body);
                }
            } elif isinstance(stmt, uni.ClientBlock) {
                if (ctx is None or ctx == CodeContext.CLIENT) {
                    result.extend(stmt.body);
                }
            } elif isinstance(stmt, uni.ServerBlock) {
                if (ctx is None or ctx == CodeContext.SERVER) {
                    result.extend(stmt.body);
                }
            } elif ctx is None {
                result.append(stmt);
            } elif (
                isinstance(stmt, uni.ContextAwareNode) and stmt.code_context == ctx
            ) {
                result.append(stmt);
            } elif (
                not isinstance(stmt, uni.ContextAwareNode)
                and ctx == CodeContext.SERVER
            ) {
                # Undecorated top-level nodes default to SERVER context
                result.append(stmt);
            }
        }
        return result;
    }
}
