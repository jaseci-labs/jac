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
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { SymbolAccess, Tokens }
import from jaclang.jac0core.passes.uni_pass { UniPass }
import from jaclang.jac0core.unitree { UniScopeNode }
"""Jac Symbol table build pass."""
class SymTabBuildPass(UniPass) {
    """Before pass."""
    def before_pass(self: SymTabBuildPass) -> None {
        self.cur_sym_tab: list[UniScopeNode] = [];
    }

    """Push scope."""
    def push_scope_and_link(self: SymTabBuildPass, key_node: uni.UniScopeNode) -> None {
        if not len(self.cur_sym_tab) {
            self.cur_sym_tab.append(key_node);
        } else {
            self.cur_sym_tab.append(self.cur_scope.link_kid_scope(key_node=key_node));
        }
    }

    """Pop scope."""
    def pop_scope(self: SymTabBuildPass) -> UniScopeNode {
        return self.cur_sym_tab.pop();
    }

    """Return current scope."""
    @property
    def cur_scope(self: SymTabBuildPass) -> UniScopeNode {
        return self.cur_sym_tab[-1];
    }

    """Find scope node of a given node."""
    def find_python_scope_node_of(
        self: SymTabBuildPass, nd: uni.UniNode
    ) -> (UniScopeNode | None) {
        scope_types = uni.UniScopeNode.get_python_scoping_nodes();
        while nd.parent {
            if isinstance(nd.parent, scope_types) {
                return nd.parent;
            }
            nd = nd.parent;
        }
        return None;
    }

    """Check if a symbol's declaration has an explicit type annotation."""
    static def _outer_has_type_annotation(sym: uni.Symbol) -> bool {
        decl = sym.decl;
        if (decl is None) {
            return False;
        }
        name_of = decl?.name_of;
        if (name_of is None) {
            return False;
        }
        parent = name_of?.parent;
        return (
            (isinstance(parent, uni.Assignment) and (parent.type_tag is not None))
            or isinstance(name_of, (uni.HasVar, uni.ParamVar))
        );
    }

    """Create symbols for Name nodes in a module path."""
    def _bind_import_path_symbols(
        self: SymTabBuildPass, module_path: uni.ModulePath
    ) -> None {
        if module_path.path {
            for n in module_path.path {
                if isinstance(n, uni.Name) {
                    n.sym = n.create_symbol(access=SymbolAccess.PUBLIC, imported=True);
                }
            }
        }
    }

    def enter_module(self: SymTabBuildPass, nd: uni.Module) -> None {
        self.push_scope_and_link(nd);
    }

    def exit_module(self: SymTabBuildPass, nd: uni.Module) -> None {
        self.pop_scope();
    }

    def exit_global_vars(self: SymTabBuildPass, nd: uni.GlobalVars) -> None {
        for i in nd.assignments {
            for j in i.target {
                if isinstance(j, uni.AstSymbolNode) {
                    j.sym_tab.def_insert(j, access_spec=nd, single_decl='global var');
                } else {
                    self.ice('Expected name type for global vars');
                }
            }
        }
    }

    def exit_assignment(self: SymTabBuildPass, nd: uni.Assignment) -> None {
        for i in nd.target {
            if isinstance(i, uni.AstSymbolNode) {
                if isinstance(i, (uni.ListVal, uni.TupleVal)) {
                    self._def_insert_unpacking(i, i.sym_tab);
                } elif ((sym := i.sym_tab.lookup(i.sym_name, deep=False)) is not None) {
                    sym.add_use(i.name_spec);
                } elif (
                    (nd.type_tag is None)
                    and not isinstance(
                        i.sym_tab, uni.UniScopeNode.get_python_scoping_nodes()
                    )
                    and (
                        (outer := i.sym_tab.lookup(i.sym_name, deep=True)) is not None
                    )
                    and self._outer_has_type_annotation(outer)
                ) {
                    outer.add_use(i.name_spec);
                } else {
                    i.sym_tab.def_insert(i, single_decl='local var');
                }
            }
        }
    }

    """Handle walrus operator (:=) assignments."""
    def exit_binary_expr(self: SymTabBuildPass, nd: uni.BinaryExpr) -> None {
        import from jaclang.jac0core.constant { Tokens as Tok }
        if not (isinstance(nd.op, uni.Token) and (nd.op.name == Tok.WALRUS_EQ)) {
            return;
        }
        if isinstance(nd.left, uni.Name) {
            if ((sym := nd.left.sym_tab.lookup(nd.left.sym_name, deep=False)) is None) {
                nd.left.sym_tab.def_insert(nd.left, single_decl='walrus var');
            } else {
                sym.add_use(nd.left.name_spec);
            }
        }
    }

    def enter_test(self: SymTabBuildPass, nd: uni.Test) -> None {
        self.push_scope_and_link(nd);
        import unittest;
        for i in [
            j
            for j in dir(unittest.TestCase())
            if j.startswith('assert')
        ] {
            nd.sym_tab.def_insert(uni.Name.gen_stub_from_node(nd, i, set_name_of=nd));
        }
    }

    def exit_test(self: SymTabBuildPass, nd: uni.Test) -> None {
        self.pop_scope();
    }

    def _exit_import_absorb(self: SymTabBuildPass, nd: uni.Import) -> None {
        sym_table_to_update = self.find_python_scope_node_of(nd);
        if (sym_table_to_update is None) {
            return;
        }
        import_all_module_path_node: uni.ModulePath = nd.items[0];
        import_all_module_path = import_all_module_path_node.resolve_relative_path();
        module: (uni.Module | None) = None;
        if (import_all_module_path in self.prog.mod.hub) {
            module = self.prog.mod.hub[import_all_module_path];
        } else {
            try {
                module = self.prog.compile(
                    import_all_module_path, no_cgen=True, type_check=False
                );
            } except Exception {
                return;
            }
        }
        self._bind_import_path_symbols(import_all_module_path_node);
        if module {
            for sym in module.names_in_scope.values() {
                if (sym.access != SymbolAccess.PRIVATE) {
                    sym_table_to_update.def_insert(
                        sym.defn[0], single_decl='import absorb'
                    );
                }
            }
        }
    }

    def exit_import(self: SymTabBuildPass, nd: uni.Import) -> None {
        if nd.is_absorb {
            return self._exit_import_absorb(nd);
        }
    }

    def exit_module_path(self: SymTabBuildPass, nd: uni.ModulePath) -> None {
        if nd.alias {
            nd.alias.sym_tab.def_insert(nd.alias, single_decl='import');
        } elif (
            nd.path
            and not nd.is_import_from
            and nd.parent_of_type(uni.Import)
            and not (
                nd.parent_of_type(uni.Import).from_loc
                and nd.parent_of_type(uni.Import).is_jac
            )
        ) {
            if isinstance(nd.path[0], uni.Name) {
                nd.path[0].sym_tab.def_insert(nd.path[0]);
            }
        } else {
            ;
        }
        if (nd.path and (nd.is_import_from or nd.alias)) {
            self._bind_import_path_symbols(nd);
        }
    }

    def exit_module_item(self: SymTabBuildPass, nd: uni.ModuleItem) -> None {
        if isinstance(nd.name, uni.Name) {
            sym_node = nd.alias or nd.name;
            sym_node.sym_tab.def_insert(sym_node, single_decl='import');
            if nd.alias {
                nd.name.sym = nd.name.create_symbol(
                    access=SymbolAccess.PUBLIC, imported=True
                );
            }
        } elif (isinstance(nd.name, uni.Token) and nd.alias) {
            sym_node = nd.alias;
            sym_node.sym_tab.def_insert(sym_node, single_decl='import');
        }
    }

    def enter_archetype(self: SymTabBuildPass, nd: uni.Archetype) -> None {
        self.push_scope_and_link(nd);
        assert (nd.parent_scope is not None);
        nd.parent_scope.def_insert(nd, access_spec=nd, single_decl='archetype');
    }

    def exit_archetype(self: SymTabBuildPass, nd: uni.Archetype) -> None {
        self.pop_scope();
    }

    def enter_ability(self: SymTabBuildPass, nd: uni.Ability) -> None {
        self.push_scope_and_link(nd);
        assert (nd.parent_scope is not None);
        nd.parent_scope.def_insert(nd, access_spec=nd, single_decl='ability');
        if nd.is_method {
            nd.sym_tab.def_insert(uni.Name.gen_stub_from_node(nd, 'self'));
            nd.sym_tab.def_insert(
                uni.Name.gen_stub_from_node(nd, 'super', set_name_of=nd.method_owner)
            );
        }
    }

    def exit_ability(self: SymTabBuildPass, nd: uni.Ability) -> None {
        self.pop_scope();
    }

    def enter_impl_def(self: SymTabBuildPass, nd: uni.ImplDef) -> None {
        self.push_scope_and_link(nd);
        assert (nd.parent_scope is not None);
        nd.parent_scope.def_insert(nd, single_decl='impl');
    }

    def exit_impl_def(self: SymTabBuildPass, nd: uni.ImplDef) -> None {
        self.pop_scope();
    }

    def enter_sem_def(self: SymTabBuildPass, nd: uni.SemDef) -> None {
        self.push_scope_and_link(nd);
        assert (nd.parent_scope is not None);
        nd.parent_scope.def_insert(nd, single_decl='sem');
    }

    def exit_sem_def(self: SymTabBuildPass, nd: uni.SemDef) -> None {
        self.pop_scope();
    }

    def enter_enum(self: SymTabBuildPass, nd: uni.Enum) -> None {
        self.push_scope_and_link(nd);
        assert (nd.parent_scope is not None);
        nd.parent_scope.def_insert(nd, access_spec=nd, single_decl='enum');
    }

    def enter_has_var(self: SymTabBuildPass, nd: uni.HasVar) -> None {
        if isinstance(nd.parent, uni.ArchHas) {
            nd.sym_tab.def_insert(nd, single_decl='has var', access_spec=nd.parent);
        }
    }

    def enter_param_var(self: SymTabBuildPass, nd: uni.ParamVar) -> None {
        nd.sym_tab.def_insert(nd, single_decl='param');
    }

    """Handle attribute access for self member assignments."""
    def exit_atom_trailer(self: SymTabBuildPass, nd: uni.AtomTrailer) -> None {
        if not self._is_self_member_assignment(nd) {
            return;
        }
        chain = nd.as_attr_list;
        ability = nd.find_parent_of_type(uni.Ability);
        if (ability and ability.method_owner) {
            archetype = ability.method_owner;
            if isinstance(archetype, uni.Archetype) {
                archetype.sym_tab.def_insert(chain[1], access_spec=archetype);
            }
        }
    }

    """Check if the node represents a simple `self.attr = value` assignment."""
    def _is_self_member_assignment(self: SymTabBuildPass, nd: uni.AtomTrailer) -> bool {
        if not (nd.parent and isinstance(nd.parent, uni.Assignment)) {
            return False;
        }
        if (nd != nd.parent.target[0]) {
            return False;
        }
        chain = nd.as_attr_list;
        if ((len(chain) != 2) or (chain[0].sym_name != 'self')) {
            return False;
        }
        ability = nd.find_parent_of_type(uni.Ability);
        return (
            (ability is not None)
            and ability.is_method
            and not ability.is_static
            and not ability.is_cls_method
        );
    }

    def exit_enum(self: SymTabBuildPass, nd: uni.Enum) -> None {
        self.pop_scope();
    }

    def enter_typed_ctx_block(self: SymTabBuildPass, nd: uni.TypedCtxBlock) -> None {
        self.push_scope_and_link(nd);
    }

    def exit_typed_ctx_block(self: SymTabBuildPass, nd: uni.TypedCtxBlock) -> None {
        self.pop_scope();
    }

    def enter_if_stmt(self: SymTabBuildPass, nd: uni.IfStmt) -> None {
        self.push_scope_and_link(nd);
    }

    def exit_if_stmt(self: SymTabBuildPass, nd: uni.IfStmt) -> None {
        self.pop_scope();
    }

    def enter_else_if(self: SymTabBuildPass, nd: uni.ElseIf) -> None {
        self.push_scope_and_link(nd);
    }

    def exit_else_if(self: SymTabBuildPass, nd: uni.ElseIf) -> None {
        self.pop_scope();
    }

    def enter_else_stmt(self: SymTabBuildPass, nd: uni.ElseStmt) -> None {
        self.push_scope_and_link(nd);
    }

    def exit_else_stmt(self: SymTabBuildPass, nd: uni.ElseStmt) -> None {
        self.pop_scope();
    }

    def enter_try_stmt(self: SymTabBuildPass, nd: uni.TryStmt) -> None {
        self.push_scope_and_link(nd);
    }

    def exit_try_stmt(self: SymTabBuildPass, nd: uni.TryStmt) -> None {
        self.pop_scope();
    }

    def enter_except(self: SymTabBuildPass, nd: uni.Except) -> None {
        self.push_scope_and_link(nd);
        if nd.name {
            nd.sym_tab.def_insert(nd.name, single_decl='local var');
        }
    }

    def exit_except(self: SymTabBuildPass, nd: uni.Except) -> None {
        self.pop_scope();
    }

    def enter_finally_stmt(self: SymTabBuildPass, nd: uni.FinallyStmt) -> None {
        self.push_scope_and_link(nd);
    }

    def exit_finally_stmt(self: SymTabBuildPass, nd: uni.FinallyStmt) -> None {
        self.pop_scope();
    }

    def enter_iter_for_stmt(self: SymTabBuildPass, nd: uni.IterForStmt) -> None {
        self.push_scope_and_link(nd);
    }

    def exit_iter_for_stmt(self: SymTabBuildPass, nd: uni.IterForStmt) -> None {
        self.pop_scope();
    }

    """Recursively define symbols in unpacking expressions."""
    def _def_insert_unpacking(
        self: SymTabBuildPass, nd: uni.Expr, sym_tab: UniScopeNode
    ) -> None {
        if isinstance(nd, uni.Name) {
            sym_tab.def_insert(nd, single_decl='iterator');
        } elif isinstance(nd, (uni.TupleVal, uni.ListVal)) {
            for target_var in nd.values {
                if isinstance(target_var, uni.Expr) {
                    self._def_insert_unpacking(target_var, sym_tab);
                }
            }
        } elif (isinstance(nd, uni.UnaryExpr) and (nd.op.name == Tokens.STAR_MUL)) {
            self._def_insert_unpacking(nd.operand, sym_tab);
        }
    }

    def enter_in_for_stmt(self: SymTabBuildPass, nd: uni.InForStmt) -> None {
        self.push_scope_and_link(nd);
        self._def_insert_unpacking(nd.target, nd.sym_tab);
    }

    def exit_in_for_stmt(self: SymTabBuildPass, nd: uni.InForStmt) -> None {
        self.pop_scope();
    }

    def enter_while_stmt(self: SymTabBuildPass, nd: uni.WhileStmt) -> None {
        self.push_scope_and_link(nd);
    }

    def exit_while_stmt(self: SymTabBuildPass, nd: uni.WhileStmt) -> None {
        self.pop_scope();
    }

    def enter_with_stmt(self: SymTabBuildPass, nd: uni.WithStmt) -> None {
        self.push_scope_and_link(nd);
    }

    def exit_with_stmt(self: SymTabBuildPass, nd: uni.WithStmt) -> None {
        self.pop_scope();
    }

    def exit_expr_as_item(self: SymTabBuildPass, nd: uni.ExprAsItem) -> None {
        if (nd.alias and isinstance(nd.alias, uni.Name)) {
            nd.alias.sym_tab.def_insert(nd.alias, single_decl='context var');
        }
    }

    def enter_lambda_expr(self: SymTabBuildPass, nd: uni.LambdaExpr) -> None {
        self.push_scope_and_link(nd);
    }

    def exit_lambda_expr(self: SymTabBuildPass, nd: uni.LambdaExpr) -> None {
        self.pop_scope();
    }

    def enter_list_compr(self: SymTabBuildPass, nd: uni.ListCompr) -> None {
        self.push_scope_and_link(nd);
        for i in nd.compr {
            self._def_insert_unpacking(i.target, nd.sym_tab);
        }
    }

    def exit_list_compr(self: SymTabBuildPass, nd: uni.ListCompr) -> None {
        self.pop_scope();
    }

    def enter_set_compr(self: SymTabBuildPass, nd: uni.SetCompr) -> None {
        self.push_scope_and_link(nd);
        for i in nd.compr {
            self._def_insert_unpacking(i.target, nd.sym_tab);
        }
    }

    def exit_set_compr(self: SymTabBuildPass, nd: uni.SetCompr) -> None {
        self.pop_scope();
    }

    def enter_gen_compr(self: SymTabBuildPass, nd: uni.GenCompr) -> None {
        self.push_scope_and_link(nd);
        for i in nd.compr {
            self._def_insert_unpacking(i.target, nd.sym_tab);
        }
    }

    def exit_gen_compr(self: SymTabBuildPass, nd: uni.GenCompr) -> None {
        self.pop_scope();
    }

    def enter_dict_compr(self: SymTabBuildPass, nd: uni.DictCompr) -> None {
        self.push_scope_and_link(nd);
        for i in nd.compr {
            self._def_insert_unpacking(i.target, nd.sym_tab);
        }
    }

    def exit_dict_compr(self: SymTabBuildPass, nd: uni.DictCompr) -> None {
        self.pop_scope();
    }

    def enter_match_case(self: SymTabBuildPass, nd: uni.MatchCase) -> None {
        self.push_scope_and_link(nd);
    }

    def exit_match_case(self: SymTabBuildPass, nd: uni.MatchCase) -> None {
        self.pop_scope();
    }
}
