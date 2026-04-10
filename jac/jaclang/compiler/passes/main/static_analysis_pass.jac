"""Static analysis pass for the Jac compiler.

This pass detects:
1. Unused variables - symbols defined but never referenced
2. Undefined variables - name references that failed to resolve
3. Unreachable code - statements with no incoming control flow edges
"""
import ast as ast3;
import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.constant { SymbolType }
import from jaclang.jac0core.diagnostics {
    W0062,
    W2001,
    W2002,
    W2003,
    W2058,
    W2063,
    W2070,
    W2074,
    W2075,
    E2055,
    E2083
}

"""Static analysis pass for JacLang.

Does not traverse the tree node-by-node; all analysis is performed
in transform() via bulk sub-node queries, so we extend Transform
directly instead of UniPass.
"""
obj StaticAnalysisPass(Transform[uni.Module, uni.Module]) {
    has ir_in: uni.Module,
        prog: Any,
        cancel_token: Any = None;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _check_unused_symbols(scope: uni.UniScopeNode) -> None;
    def _check_undefined_names(mod: uni.Module) -> None;
    def _check_unreachable_code(mod: uni.Module) -> None;
    def _check_semantic_patterns(mod: uni.Module) -> None;
}
