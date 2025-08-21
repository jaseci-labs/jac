"""Symbol Table Construction Pass for the Jac compiler.

This pass builds the hierarchical symbol table structure for the entire program by:

1. Creating symbol tables for each scope in the program (modules, archetypes, abilities, blocks)
2. Establishing parent-child relationships between nested scopes
3. Registering symbols for various language constructs:
   - Global variables and imports
   - Archetypes (objects, nodes, edges, walkers) and their members
   - Abilities (methods and functions) and their parameters
   - Enums and their values
   - Local variables in various block scopes

4. Adding special symbols like 'self' and 'super' in appropriate contexts
5. Maintaining scope boundaries for proper symbol resolution

The symbol table is a fundamental data structure that enables name resolution,
type checking, and semantic analysis throughout the compilation process.
"""

import jaclang.compiler.unitree as uni
from jaclang.compiler.passes import UniPass
from jaclang.compiler.unitree import UniScopeNode


class SymTabBuildPass(UniPass):
    """Jac Symbol table build pass."""

    def before_pass(self) -> None:
        """Before pass."""
        self.cur_sym_tab: list[UniScopeNode] = []

    def push_scope_and_link(self, key_node: uni.UniScopeNode) -> None:
        """Push scope."""
        if not len(self.cur_sym_tab):
            self.cur_sym_tab.append(key_node)
        else:
            self.cur_sym_tab.append(self.cur_scope.link_kid_scope(key_node=key_node))

    def pop_scope(self) -> UniScopeNode:
        """Pop scope."""
        return self.cur_sym_tab.pop()

    @property
    def cur_scope(self) -> UniScopeNode:
        """Return current scope."""
        return self.cur_sym_tab[-1]

    def enter_module(self, node: uni.Module) -> None:
        self.push_scope_and_link(node)

    def exit_module(self, node: uni.Module) -> None:
        self.pop_scope()

    def exit_global_vars(self, node: uni.GlobalVars) -> None:
        for i in self.get_all_sub_nodes(node, uni.Assignment):
            for j in i.target:
                if isinstance(j, uni.AstSymbolNode):
                    j.sym_tab.def_insert(j, access_spec=node, single_decl="global var")
                else:
                    self.ice("Expected name type for globabl vars")

    def enter_test(self, node: uni.Test) -> None:
        self.push_scope_and_link(node)
        import unittest

        for i in [j for j in dir(unittest.TestCase()) if j.startswith("assert")]:
            node.sym_tab.def_insert(
                uni.Name.gen_stub_from_node(node, i, set_name_of=node)
            )

    def exit_test(self, node: uni.Test) -> None:
        self.pop_scope()

    def exit_module_path(self, node: uni.ModulePath) -> None:
        if node.alias:
            node.alias.sym_tab.def_insert(node.alias, single_decl="import")
        elif node.path and isinstance(node.path[0], uni.Name):
            if node.parent_of_type(uni.Import) and not (
                node.parent_of_type(uni.Import).from_loc
                and node.parent_of_type(uni.Import).is_jac
            ):
                node.path[0].sym_tab.def_insert(node.path[0])
        else:
            pass  # Need to support pythonic import symbols with dots in it

    def enter_archetype(self, node: uni.Archetype) -> None:
        self.push_scope_and_link(node)
        assert node.parent_scope is not None
        node.parent_scope.def_insert(node, access_spec=node, single_decl="archetype")

    def exit_archetype(self, node: uni.Archetype) -> None:
        self.pop_scope()

    def enter_ability(self, node: uni.Ability) -> None:
        self.push_scope_and_link(node)
        assert node.parent_scope is not None
        node.parent_scope.def_insert(node, access_spec=node, single_decl="ability")
        if node.is_method:
            node.sym_tab.def_insert(uni.Name.gen_stub_from_node(node, "self"))
            node.sym_tab.def_insert(
                uni.Name.gen_stub_from_node(
                    node, "super", set_name_of=node.method_owner
                )
            )

    def exit_ability(self, node: uni.Ability) -> None:
        self.pop_scope()

    def enter_impl_def(self, node: uni.ImplDef) -> None:
        self.push_scope_and_link(node)
        assert node.parent_scope is not None
        node.parent_scope.def_insert(node, single_decl="impl")

    def exit_impl_def(self, node: uni.ImplDef) -> None:
        self.pop_scope()

    def enter_sem_def(self, node: uni.SemDef) -> None:
        self.push_scope_and_link(node)
        assert node.parent_scope is not None
        node.parent_scope.def_insert(node, single_decl="sem")

    def exit_sem_def(self, node: uni.SemDef) -> None:
        self.pop_scope()

    def enter_enum(self, node: uni.Enum) -> None:
        self.push_scope_and_link(node)
        assert node.parent_scope is not None
        node.parent_scope.def_insert(node, access_spec=node, single_decl="enum")

    def exit_enum(self, node: uni.Enum) -> None:
        self.pop_scope()

    def enter_typed_ctx_block(self, node: uni.TypedCtxBlock) -> None:
        self.push_scope_and_link(node)

    def exit_typed_ctx_block(self, node: uni.TypedCtxBlock) -> None:
        self.pop_scope()

    def enter_if_stmt(self, node: uni.IfStmt) -> None:
        self.push_scope_and_link(node)

    def exit_if_stmt(self, node: uni.IfStmt) -> None:
        self.pop_scope()

    def enter_else_if(self, node: uni.ElseIf) -> None:
        self.push_scope_and_link(node)

    def exit_else_if(self, node: uni.ElseIf) -> None:
        self.pop_scope()

    def enter_else_stmt(self, node: uni.ElseStmt) -> None:
        self.push_scope_and_link(node)

    def exit_else_stmt(self, node: uni.ElseStmt) -> None:
        self.pop_scope()

    def enter_try_stmt(self, node: uni.TryStmt) -> None:
        self.push_scope_and_link(node)

    def exit_try_stmt(self, node: uni.TryStmt) -> None:
        self.pop_scope()

    def enter_except(self, node: uni.Except) -> None:
        self.push_scope_and_link(node)

    def exit_except(self, node: uni.Except) -> None:
        self.pop_scope()

    def enter_finally_stmt(self, node: uni.FinallyStmt) -> None:
        self.push_scope_and_link(node)

    def exit_finally_stmt(self, node: uni.FinallyStmt) -> None:
        self.pop_scope()

    def enter_iter_for_stmt(self, node: uni.IterForStmt) -> None:
        self.push_scope_and_link(node)

    def exit_iter_for_stmt(self, node: uni.IterForStmt) -> None:
        self.pop_scope()

    def enter_in_for_stmt(self, node: uni.InForStmt) -> None:
        self.push_scope_and_link(node)

    def exit_in_for_stmt(self, node: uni.InForStmt) -> None:
        self.pop_scope()

    def enter_while_stmt(self, node: uni.WhileStmt) -> None:
        self.push_scope_and_link(node)

    def exit_while_stmt(self, node: uni.WhileStmt) -> None:
        self.pop_scope()

    def enter_with_stmt(self, node: uni.WithStmt) -> None:
        self.push_scope_and_link(node)

    def exit_with_stmt(self, node: uni.WithStmt) -> None:
        self.pop_scope()

    def enter_lambda_expr(self, node: uni.LambdaExpr) -> None:
        self.push_scope_and_link(node)

    def exit_lambda_expr(self, node: uni.LambdaExpr) -> None:
        self.pop_scope()

    def enter_inner_compr(self, node: uni.InnerCompr) -> None:
        self.push_scope_and_link(node)

    def exit_inner_compr(self, node: uni.InnerCompr) -> None:
        self.pop_scope()

    def enter_dict_compr(self, node: uni.DictCompr) -> None:
        self.push_scope_and_link(node)

    def exit_dict_compr(self, node: uni.DictCompr) -> None:
        self.pop_scope()

    def enter_match_case(self, node: uni.MatchCase) -> None:
        self.push_scope_and_link(node)

    def exit_match_case(self, node: uni.MatchCase) -> None:
        self.pop_scope()
