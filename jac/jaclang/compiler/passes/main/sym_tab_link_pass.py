"""Symbol Table Linking Pass for the Jac compiler.

This pass connects symbol tables across different modules by:

1. Establishing relationships between importing and imported modules
2. Handling different import styles:
   - Direct imports (import x)
   - From imports (from x import y)
   - Star imports (from x import *)
   - Aliased imports (import x as y)

3. Creating appropriate symbol table inheritance relationships
4. Managing both Jac and Python module imports
5. Preventing circular import issues
6. Supporting relative and absolute import paths

This pass is essential for cross-module symbol resolution, allowing code in one module
to reference symbols defined in other modules while maintaining proper scoping rules.
"""

import os
from typing import Optional

import jaclang.compiler.unitree as uni
from jaclang.compiler.passes import Transform
from jaclang.compiler.unitree import InheritedSymbolTable, UniScopeNode


class SymTabLinkPass(Transform[uni.Module, uni.Module]):
    """Link the symbol table."""

    def transform(self, ir_in: uni.Module) -> uni.Module:
        """Link the symbol tables for all modules in the program."""
        # Process all modules in the program hub
        for node in ir_in.get_all_sub_nodes(uni.ModulePath):
            self.process_module_path(ir_in, node)
        return ir_in

    def process_module_path(self, mod: uni.Module, node: uni.ModulePath) -> None:
        """Process a module path node to link symbol tables."""
        imp_node = node.parent_of_type(uni.Import)

        # Get path to the imported module
        rel_path = self._get_module_path(mod, node, imp_node)
        if not rel_path or rel_path not in self.prog.mod.hub:
            return

        imported_mod_symtab = self.prog.mod.hub[rel_path].sym_tab
        # Skip if importing from itself
        if node.sym_tab == imported_mod_symtab:
            return

        # Determine if this is an "all import" (import everything)
        all_import = self._is_all_import(imp_node, node)
        symbols_str_list = self._get_imported_symbols(node)

        # Handle the import based on whether it's an all import or selective import
        if all_import:
            self._handle_all_import(node, imported_mod_symtab)
        else:
            self._handle_selective_import(
                node, imported_mod_symtab, symbols_str_list, imp_node
            )

    def _get_module_path(
        self, mod: uni.Module, node: uni.ModulePath, imp_node: uni.Import
    ) -> Optional[str]:
        """Get the path to the imported module."""
        if imp_node.is_jac:
            rel_path = node.resolve_relative_path()
            if os.path.isdir(rel_path):
                init_path = os.path.join(rel_path, "__init__")
                if os.path.isfile(f"{init_path}.jac"):
                    rel_path = f"{init_path}.jac"
                else:
                    rel_path = f"{init_path}.py"
            if rel_path not in self.prog.mod.hub:
                self.log_error(
                    f"Module {rel_path} not found in the program. Something went wrong.",
                    node,
                )
                return None
            return rel_path
        else:
            # Python import
            if node.sym_name in self.prog.py_raise_map:
                return self.prog.py_raise_map[node.sym_name]

            full_path = f"{mod.get_href_path(node)}.{node.sym_name}"
            if full_path in self.prog.py_raise_map:
                return self.prog.py_raise_map[full_path]

            return None

    def _is_all_import(self, imp_node: uni.Import, node: uni.ModulePath) -> bool:
        """Determine if this is an all import (import everything from module)."""
        return (imp_node.is_jac and node in imp_node.items) or (
            imp_node.is_py and imp_node.from_loc is None and not imp_node.is_absorb
        )

    def _get_imported_symbols(self, node: uni.ModulePath) -> list[str]:
        """Get list of specific symbols being imported."""
        symbols = []
        if node.parent and isinstance(node.parent, uni.Import):
            for mod_items in node.parent.items:
                if isinstance(mod_items, uni.ModuleItem):
                    symbols.append(mod_items.name.value)
        return symbols

    def _handle_all_import(
        self, node: uni.ModulePath, imported_mod_symtab: UniScopeNode
    ) -> None:
        """Handle an 'all import' by adding the imported symtable as a kid to the current sym table."""
        node.sym_tab.kid_scope.append(imported_mod_symtab)

    def _handle_selective_import(
        self,
        node: uni.ModulePath,
        imported_mod_symtab: UniScopeNode,
        symbols_str_list: list[str],
        imp_node: uni.Import,
    ) -> None:
        """Handle selective import of specific symbols."""
        # Check if we've already inherited from this symbol table
        for symtb in node.sym_tab.inherited_scope:
            if symtb.base_symbol_table == imported_mod_symtab:
                symtb.symbols.extend(symbols_str_list)
                return

        # If not inherited yet, add it to inherited scope
        node.sym_tab.inherited_scope.append(
            InheritedSymbolTable(
                base_symbol_table=imported_mod_symtab,
                # load_all_symbols needed for "from x import *" in Python imports
                load_all_symbols=imp_node.is_py and imp_node.is_absorb,
                symbols=symbols_str_list,
            )
        )
