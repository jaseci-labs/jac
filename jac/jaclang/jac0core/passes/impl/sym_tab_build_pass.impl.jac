"""Implementation for sym_tab_build_pass constructs."""

"""Before pass."""
impl SymTabBuildPass.before_pass(self: SymTabBuildPass) -> None {
    self.cur_sym_tab: list[UniScopeNode] = [];
}

"""Push scope."""
impl SymTabBuildPass.push_scope_and_link(
    self: SymTabBuildPass, key_node: uni.UniScopeNode
) -> None {
    if not len(self.cur_sym_tab) {
        self.cur_sym_tab.append(key_node);
    } else {
        self.cur_sym_tab.append(self.cur_scope.link_kid_scope(key_node=key_node));
    }
}

"""Pop scope."""
impl SymTabBuildPass.pop_scope(self: SymTabBuildPass) -> UniScopeNode {
    return self.cur_sym_tab.pop();
}

"""Return current scope."""
@ property
impl SymTabBuildPass.cur_scope(self: SymTabBuildPass) -> UniScopeNode {
    return self.cur_sym_tab[-1];
}

"""Find scope node of a given node."""
impl SymTabBuildPass.find_python_scope_node_of(
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

"""Create symbols for Name nodes in a module path."""
impl SymTabBuildPass._bind_import_path_symbols(
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

impl SymTabBuildPass.enter_module(self: SymTabBuildPass, nd: uni.Module) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_module(self: SymTabBuildPass, nd: uni.Module) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_type_alias(self: SymTabBuildPass, nd: uni.TypeAlias) -> None {
    self.push_scope_and_link(nd);
    assert (nd.parent_scope is not None);
    nd.parent_scope.def_insert(nd, access_spec=nd, single_decl='type_alias');
}

impl SymTabBuildPass.exit_type_alias(self: SymTabBuildPass, nd: uni.TypeAlias) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_type_param(self: SymTabBuildPass, nd: uni.TypeParam) -> None {
    if nd.sym_tab is not None {
        nd.sym_tab.def_insert(nd, single_decl='type_param');
    }
}

impl SymTabBuildPass.exit_global_vars(
    self: SymTabBuildPass, nd: uni.GlobalVars
) -> None {
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

impl SymTabBuildPass.exit_assignment(self: SymTabBuildPass, nd: uni.Assignment) -> None {
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
                and ((outer := i.sym_tab.lookup(i.sym_name, deep=True)) is not None)
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
impl SymTabBuildPass.exit_binary_expr(
    self: SymTabBuildPass, nd: uni.BinaryExpr
) -> None {
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

impl SymTabBuildPass.enter_test(self: SymTabBuildPass, nd: uni.Test) -> None {
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

impl SymTabBuildPass.exit_test(self: SymTabBuildPass, nd: uni.Test) -> None {
    self.pop_scope();
}

impl SymTabBuildPass._exit_import_absorb(self: SymTabBuildPass, nd: uni.Import) -> None {
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

impl SymTabBuildPass.exit_import(self: SymTabBuildPass, nd: uni.Import) -> None {
    if nd.is_absorb {
        return self._exit_import_absorb(nd);
    }
}

impl SymTabBuildPass.exit_module_path(
    self: SymTabBuildPass, nd: uni.ModulePath
) -> None {
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

impl SymTabBuildPass.exit_module_item(
    self: SymTabBuildPass, nd: uni.ModuleItem
) -> None {
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

impl SymTabBuildPass.enter_archetype(self: SymTabBuildPass, nd: uni.Archetype) -> None {
    self.push_scope_and_link(nd);
    assert (nd.parent_scope is not None);
    nd.parent_scope.def_insert(nd, access_spec=nd, single_decl='archetype');
}

impl SymTabBuildPass.exit_archetype(self: SymTabBuildPass, nd: uni.Archetype) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_ability(self: SymTabBuildPass, nd: uni.Ability) -> None {
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

impl SymTabBuildPass.exit_ability(self: SymTabBuildPass, nd: uni.Ability) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_impl_def(self: SymTabBuildPass, nd: uni.ImplDef) -> None {
    self.push_scope_and_link(nd);
    assert (nd.parent_scope is not None);
    nd.parent_scope.def_insert(nd, single_decl='impl');
}

impl SymTabBuildPass.exit_impl_def(self: SymTabBuildPass, nd: uni.ImplDef) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_sem_def(self: SymTabBuildPass, nd: uni.SemDef) -> None {
    self.push_scope_and_link(nd);
    assert (nd.parent_scope is not None);
    nd.parent_scope.def_insert(nd, single_decl='sem');
}

impl SymTabBuildPass.exit_sem_def(self: SymTabBuildPass, nd: uni.SemDef) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_enum(self: SymTabBuildPass, nd: uni.Enum) -> None {
    self.push_scope_and_link(nd);
    assert (nd.parent_scope is not None);
    nd.parent_scope.def_insert(nd, access_spec=nd, single_decl='enum');
}

impl SymTabBuildPass.enter_has_var(self: SymTabBuildPass, nd: uni.HasVar) -> None {
    if isinstance(nd.parent, uni.ArchHas) {
        nd.sym_tab.def_insert(nd, single_decl='has var', access_spec=nd.parent);
    }
}

impl SymTabBuildPass.enter_param_var(self: SymTabBuildPass, nd: uni.ParamVar) -> None {
    nd.sym_tab.def_insert(nd, single_decl='param');
}

"""Handle attribute access for self member assignments."""
impl SymTabBuildPass.exit_atom_trailer(
    self: SymTabBuildPass, nd: uni.AtomTrailer
) -> None {
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
impl SymTabBuildPass._is_self_member_assignment(
    self: SymTabBuildPass, nd: uni.AtomTrailer
) -> bool {
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

impl SymTabBuildPass.exit_enum(self: SymTabBuildPass, nd: uni.Enum) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_typed_ctx_block(
    self: SymTabBuildPass, nd: uni.TypedCtxBlock
) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_typed_ctx_block(
    self: SymTabBuildPass, nd: uni.TypedCtxBlock
) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_if_stmt(self: SymTabBuildPass, nd: uni.IfStmt) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_if_stmt(self: SymTabBuildPass, nd: uni.IfStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_else_if(self: SymTabBuildPass, nd: uni.ElseIf) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_else_if(self: SymTabBuildPass, nd: uni.ElseIf) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_else_stmt(self: SymTabBuildPass, nd: uni.ElseStmt) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_else_stmt(self: SymTabBuildPass, nd: uni.ElseStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_try_stmt(self: SymTabBuildPass, nd: uni.TryStmt) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_try_stmt(self: SymTabBuildPass, nd: uni.TryStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_except(self: SymTabBuildPass, nd: uni.Except) -> None {
    self.push_scope_and_link(nd);
    if nd.name {
        nd.sym_tab.def_insert(nd.name, single_decl='local var');
    }
}

impl SymTabBuildPass.exit_except(self: SymTabBuildPass, nd: uni.Except) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_finally_stmt(
    self: SymTabBuildPass, nd: uni.FinallyStmt
) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_finally_stmt(
    self: SymTabBuildPass, nd: uni.FinallyStmt
) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_iter_for_stmt(
    self: SymTabBuildPass, nd: uni.IterForStmt
) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_iter_for_stmt(
    self: SymTabBuildPass, nd: uni.IterForStmt
) -> None {
    self.pop_scope();
}

"""Recursively define symbols in unpacking expressions."""
impl SymTabBuildPass._def_insert_unpacking(
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

impl SymTabBuildPass.enter_in_for_stmt(
    self: SymTabBuildPass, nd: uni.InForStmt
) -> None {
    self.push_scope_and_link(nd);
    self._def_insert_unpacking(nd.target, nd.sym_tab);
}

impl SymTabBuildPass.exit_in_for_stmt(self: SymTabBuildPass, nd: uni.InForStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_while_stmt(self: SymTabBuildPass, nd: uni.WhileStmt) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_while_stmt(self: SymTabBuildPass, nd: uni.WhileStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_with_stmt(self: SymTabBuildPass, nd: uni.WithStmt) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_with_stmt(self: SymTabBuildPass, nd: uni.WithStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.exit_expr_as_item(
    self: SymTabBuildPass, nd: uni.ExprAsItem
) -> None {
    if (nd.alias and isinstance(nd.alias, uni.Name)) {
        nd.alias.sym_tab.def_insert(nd.alias, single_decl='context var');
    }
}

impl SymTabBuildPass.enter_lambda_expr(
    self: SymTabBuildPass, nd: uni.LambdaExpr
) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_lambda_expr(
    self: SymTabBuildPass, nd: uni.LambdaExpr
) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_list_compr(self: SymTabBuildPass, nd: uni.ListCompr) -> None {
    self.push_scope_and_link(nd);
    for i in nd.compr {
        self._def_insert_unpacking(i.target, nd.sym_tab);
    }
}

impl SymTabBuildPass.exit_list_compr(self: SymTabBuildPass, nd: uni.ListCompr) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_set_compr(self: SymTabBuildPass, nd: uni.SetCompr) -> None {
    self.push_scope_and_link(nd);
    for i in nd.compr {
        self._def_insert_unpacking(i.target, nd.sym_tab);
    }
}

impl SymTabBuildPass.exit_set_compr(self: SymTabBuildPass, nd: uni.SetCompr) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_gen_compr(self: SymTabBuildPass, nd: uni.GenCompr) -> None {
    self.push_scope_and_link(nd);
    for i in nd.compr {
        self._def_insert_unpacking(i.target, nd.sym_tab);
    }
}

impl SymTabBuildPass.exit_gen_compr(self: SymTabBuildPass, nd: uni.GenCompr) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_dict_compr(self: SymTabBuildPass, nd: uni.DictCompr) -> None {
    self.push_scope_and_link(nd);
    for i in nd.compr {
        self._def_insert_unpacking(i.target, nd.sym_tab);
    }
}

impl SymTabBuildPass.exit_dict_compr(self: SymTabBuildPass, nd: uni.DictCompr) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_match_case(self: SymTabBuildPass, nd: uni.MatchCase) -> None {
    self.push_scope_and_link(nd);
}

impl SymTabBuildPass.exit_match_case(self: SymTabBuildPass, nd: uni.MatchCase) -> None {
    self.pop_scope();
}
