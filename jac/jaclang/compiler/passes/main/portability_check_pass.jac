"""Portability check pass for the Jac compiler.

This pass detects JS-idiomatic usage patterns in Jac code and suggests
portable Jac alternatives. Warns when code uses:
1. JS-specific globals (console, Math, JSON, Array, Object, Promise, etc.)
2. JS-idiomatic methods (.push, .forEach, .indexOf, .splice, etc.)
3. JS-specific keywords (undefined, typeof, etc.)
4. JS-specific property access (.length on list/str instead of len())

Warnings fire in ALL contexts (server, client, native) because Jac idioms
are the preferred style everywhere — the ES backend translates Jac idioms
to their JS equivalents, so there is no reason to use JS-specific patterns
even in cl {} blocks.
"""
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.diagnostics { W6001, W6002, W6003, W6004 }

"""Portability check pass -- warns on JS-specific idioms in Jac code.

Does not traverse the tree node-by-node; all analysis is performed
in transform() via bulk sub-node queries, so we extend Transform
directly instead of UniPass.
"""
obj PortabilityCheckPass(Transform[uni.Module, uni.Module]) {
    has ir_in: uni.Module,
        prog: Any,
        cancel_token: Any = None;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _check_js_globals(mod: uni.Module) -> None;
    def _check_js_methods(mod: uni.Module) -> None;
    def _check_js_keywords(mod: uni.Module) -> None;
    def _check_js_properties(mod: uni.Module) -> None;
}
