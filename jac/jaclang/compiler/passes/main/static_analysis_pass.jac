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
import from jaclang.jac0core.constant { SymbolType }

"""Static analysis pass for JacLang."""
obj StaticAnalysisPass(UniPass) {
    def init(ir_in: uni.Module, prog: Any, cancel_token: Any = None) -> None;
    def after_pass -> None;
    def _check_unused_symbols(scope: uni.UniScopeNode) -> None;
    def _check_undefined_names(mod: uni.Module) -> None;
    def _check_unreachable_code(mod: uni.Module) -> None;
}
