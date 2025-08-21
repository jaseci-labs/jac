"""Semantic Definition Matching Pass for the Jac compiler.

This pass connects semantic string definitions (SemDefs) in the AST to their corresponding
declarations. It:

1. Establishes links between semantic string definitions in the main module and their declarations
2. Handles dotted name resolution for nested symbols
3. Issues warnings for unmatched semantic definitions

This pass is essential for Jac's semantic annotation system, allowing developers to define
semantics in one file and link them to their corresponding declarations in another.
"""

import jaclang.compiler.unitree as uni
from jaclang.compiler.passes.transform import Transform
from jaclang.compiler.unitree import Symbol, UniScopeNode


class SemDefMatchPass(Transform[uni.Module, uni.Module]):
    """Jac Semantic definition match pass."""

    def transform(self, ir_in: uni.Module) -> uni.Module:
        """Connect Decls and Defs."""
        self.cur_node = ir_in

        self.connect_sems(ir_in.sym_tab, ir_in.sym_tab)
        for impl_module in ir_in.impl_mod:
            self.connect_sems(impl_module.sym_tab, ir_in.sym_tab)

        return ir_in

    def find_symbol_from_dotted_name(
        self, dotted_name: str, target_sym_tab: UniScopeNode
    ) -> Symbol | None:
        """Find a symbol in the target symbol table by its dotted name.

        Example:
            "Foo.bar.baz" will do the following lookups:
            target_sym_tab.lookup("Foo").lookup("bar").lookup("baz")
        """
        parts = dotted_name.lstrip("sem.").split(".")
        current_sym_tab = target_sym_tab
        sym: uni.Symbol | None = None
        for part in parts:
            if current_sym_tab is None:
                return None
            sym = current_sym_tab.lookup(part, deep=False)
            if sym is None:
                return None
            current_sym_tab = sym.symbol_table
        return sym

    def connect_sems(
        self, source_sym_tab: UniScopeNode, target_sym_tab: UniScopeNode
    ) -> None:
        """Connect sem strings from source symbol table to declarations in target symbol table.

        When source_sym_tab and target_sym_tab are the same, this connects within the same module.
        When different, it connects implementations from impl_mod to declarations in the main module.
        """
        for sym in source_sym_tab.names_in_scope.values():
            if not isinstance(sym.decl.name_of, uni.SemDef):
                continue
            semdef = sym.decl.name_of
            target_sym = self.find_symbol_from_dotted_name(sym.sym_name, target_sym_tab)
            if target_sym is not None:
                target_sym.decl.name_of.semstr = semdef.value.lit_value
                target_sym.semstr = semdef.value.lit_value
