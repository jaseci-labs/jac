"""Inheritance Resolution Pass for the Jac compiler.

This pass handles the inheritance relationships between archetypes by:

1. Identifying base classes for each archetype in the program
2. Resolving the inheritance hierarchy, including multi-level inheritance
3. Populating derived class symbol tables with symbols from their base classes
4. Handling special cases like Python base classes and index slice expressions
5. Ensuring proper symbol visibility according to inheritance rules

This pass is essential for object-oriented features in Jac, allowing derived classes
to access methods and attributes defined in their parent classes.
"""

from __future__ import annotations

from typing import Optional

import jaclang.compiler.unitree as uni
from jaclang.compiler.passes.transform import Transform
from jaclang.compiler.unitree import Symbol, UniScopeNode


class InheritancePass(Transform[uni.Module, uni.Module]):
    """Add inherited abilities in the target symbol tables."""

    def transform(self, ir_in: uni.Module) -> uni.Module:
        """Entry point for the inheritance pass."""
        self.process_archetypes(ir_in)
        return ir_in

    def process_archetypes(self, module: uni.Module) -> None:
        """Process all archetypes in the module."""
        for node in module.get_all_sub_nodes(uni.Archetype):
            self.process_archetype_inheritance(node)

    def process_archetype_inheritance(self, node: uni.Archetype) -> None:
        """Fill archetype symbol tables with abilities from parent archetypes."""
        if not node.base_classes:
            return

        self.cur_node = node
        for item in node.base_classes:
            # Handle different types of base class references
            if isinstance(item, uni.Name):
                self.inherit_from_name(node, item)
            elif isinstance(item, uni.AtomTrailer):
                self.inherit_from_atom_trailer(node, item)
            elif isinstance(item, uni.FuncCall):
                self.log_info(
                    "Base class depends on the type of a function call "
                    "expression, this is not supported yet"
                )

    def inherit_from_name(self, node: uni.Archetype, item: uni.Name) -> None:
        """Handle inheritance from a simple name reference."""
        assert node.sym_tab.parent_scope is not None
        base_class_symbol = self.lookup_symbol(item.sym_name, node.sym_tab.parent_scope)

        if base_class_symbol is None:
            return

        base_class_symbol_table = base_class_symbol.symbol_table

        # FIXME: If the base class symbol is imported from another module, the symbol table
        # will be None. The imported symbols were ignored and introduced in the typecheck
        # for imported module items. This needs to be investigated to ensure that even imported
        # classes should have a symbol table (unless the module is not parsed and decided not to).
        if base_class_symbol_table is None:
            return

        if self.is_missing_py_symbol_table(base_class_symbol, base_class_symbol_table):
            return

        node.sym_tab.inherit_sym_tab(base_class_symbol_table)

    def inherit_from_atom_trailer(
        self, node: uni.Archetype, item: uni.AtomTrailer
    ) -> None:
        """Handle inheritance from an attribute access chain."""
        current_sym_table = node.sym_tab.parent_scope
        if current_sym_table:
            for name in item.as_attr_list:
                sym = self.lookup_symbol(name.sym_name, current_sym_table)
                if sym is None:
                    return
                current_sym_table = sym.symbol_table
                # Handle Python base classes or index slice expressions
                if self.is_missing_py_symbol_table(sym, current_sym_table):
                    return
                if self.is_index_slice_next(item, name):
                    # "Base class depends on the type of an Index slice expression, this is not supported yet"
                    return
                if current_sym_table is None:
                    return
            node.sym_tab.inherit_sym_tab(current_sym_table)

    def lookup_symbol(self, name: str, sym_table: UniScopeNode) -> Optional[Symbol]:
        """Look up a symbol in the symbol table or in builtins."""
        symbol = sym_table.lookup(name)
        if symbol is None:
            # Check for the symbol in builtins
            builtins_symtable = self.get_builtins_symtable()
            if builtins_symtable:
                symbol = builtins_symtable.lookup(name)
        return symbol

    def get_builtins_symtable(self) -> Optional[UniScopeNode]:
        """Get the builtins symbol table."""
        for mod in self.prog.mod.hub.values():
            if mod.name == "builtins":
                return mod.sym_tab
        return None

    def is_missing_py_symbol_table(
        self, symbol: Symbol, symbol_table: Optional[UniScopeNode]
    ) -> bool:
        """Check if a Python symbol table is missing."""
        return (
            symbol_table is None
            and symbol.defn[0].parent_of_type(uni.Module).is_raised_from_py
        )

    def is_index_slice_next(
        self, item: uni.AtomTrailer, name: uni.AstSymbolNode
    ) -> bool:
        """Check if the next item in the atom trailer is an index slice."""
        idx = item.as_attr_list.index(name)
        return idx < len(item.as_attr_list) - 1 and isinstance(
            item.as_attr_list[idx + 1], uni.IndexSlice
        )
