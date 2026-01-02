"""Semantic Definition Matching Pass for the Jac compiler.

This pass connects semantic string definitions (SemDefs) in the AST to their corresponding
declarations. It:

1. Establishes links between semantic string definitions in the main module and their declarations
2. Handles dotted name resolution for nested symbols
3. Issues warnings for unmatched semantic definitions

This pass is essential for Jac's semantic annotation system, allowing developers to define
semantics in one file and link them to their corresponding declarations in another.
"""
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.passes.transform { Transform }
import from jaclang.pycore.unitree { Symbol, UniScopeNode }
"""Jac Semantic definition match pass."""
obj SemDefMatchPass(Transform[(uni.Module, uni.Module)]) {
    def init(ir_in: uni.Module, prog: Any, cancel_token: Any = None) -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def find_symbol_from_dotted_name(
        dotted_name: str, target_sym_tab: UniScopeNode
    ) -> (Symbol | None);

    def connect_sems(
        source_sym_tab: UniScopeNode, target_sym_tab: UniScopeNode
    ) -> None;
}
