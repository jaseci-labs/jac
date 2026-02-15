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
    self: SymTabBuildPass, `node: uni.UniNode
) -> (UniScopeNode | None) {
    scope_types = uni.UniScopeNode.get_python_scoping_nodes();
    while `node.parent {
        if isinstance(`node.parent, scope_types) {
            return `node.parent;
        }
        `node = `node.parent;
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

impl SymTabBuildPass.enter_module(self: SymTabBuildPass, `node: uni.Module) -> None {
    self.push_scope_and_link(`node);
}

impl SymTabBuildPass.exit_module(self: SymTabBuildPass, `node: uni.Module) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.exit_global_vars(
    self: SymTabBuildPass, `node: uni.GlobalVars
) -> None {
    for i in `node.assignments {
        for j in i.target {
            if isinstance(j, uni.AstSymbolNode) {
                j.sym_tab.def_insert(j, access_spec=`node, single_decl='global var');
            } else {
                self.ice('Expected name type for global vars');
            }
        }
    }
}

impl SymTabBuildPass.exit_assignment(
    self: SymTabBuildPass, `node: uni.Assignment
) -> None {
    for i in `node.target {
        if isinstance(i, uni.AstSymbolNode) {
            if isinstance(i, (uni.ListVal, uni.TupleVal)) {
                self._def_insert_unpacking(i, i.sym_tab);
            } elif ((sym := i.sym_tab.lookup(i.sym_name, deep=False)) is not None) {
                sym.add_use(i.name_spec);
            } elif (
                (`node.type_tag is None)
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
    self: SymTabBuildPass, `node: uni.BinaryExpr
) -> None {
    import from jaclang.jac0core.constant { Tokens as Tok }
    if not (isinstance(`node.op, uni.Token) and (`node.op.name == Tok.WALRUS_EQ)) {
        return;
    }
    if isinstance(`node.left, uni.Name) {
        if (
            (sym := `node.left.sym_tab.lookup(`node.left.sym_name, deep=False)) is None
        ) {
            `node.left.sym_tab.def_insert(`node.left, single_decl='walrus var');
        } else {
            sym.add_use(`node.left.name_spec);
        }
    }
}

impl SymTabBuildPass.enter_test(self: SymTabBuildPass, `node: uni.Test) -> None {
    self.push_scope_and_link(`node);
    import unittest;
    for i in [
        j
        for j in dir(unittest.TestCase())
        if j.startswith('assert')
    ] {
        `node.sym_tab.def_insert(
            uni.Name.gen_stub_from_node(`node, i, set_name_of=`node)
        );
    }
}

impl SymTabBuildPass.exit_test(self: SymTabBuildPass, `node: uni.Test) -> None {
    self.pop_scope();
}

impl SymTabBuildPass._exit_import_absorb(
    self: SymTabBuildPass, `node: uni.Import
) -> None {
    sym_table_to_update = self.find_python_scope_node_of(`node);
    if (sym_table_to_update is None) {
        return;
    }
    import_all_module_path_node: uni.ModulePath = `node.items[0];
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

impl SymTabBuildPass.exit_import(self: SymTabBuildPass, `node: uni.Import) -> None {
    if `node.is_absorb {
        return self._exit_import_absorb(`node);
    }
}

impl SymTabBuildPass.exit_module_path(
    self: SymTabBuildPass, `node: uni.ModulePath
) -> None {
    if `node.alias {
        `node.alias.sym_tab.def_insert(`node.alias, single_decl='import');
    } elif (
        `node.path
        and not `node.is_import_from
        and `node.parent_of_type(uni.Import)
        and not (
            `node.parent_of_type(uni.Import).from_loc
            and `node.parent_of_type(uni.Import).is_jac
        )
    ) {
        if isinstance(`node.path[0], uni.Name) {
            `node.path[0].sym_tab.def_insert(`node.path[0]);
        }
    } else {
        ;
    }
    if (`node.path and (`node.is_import_from or `node.alias)) {
        self._bind_import_path_symbols(`node);
    }
}

impl SymTabBuildPass.exit_module_item(
    self: SymTabBuildPass, `node: uni.ModuleItem
) -> None {
    if isinstance(`node.name, uni.Name) {
        sym_node = `node.alias or `node.name;
        sym_node.sym_tab.def_insert(sym_node, single_decl='import');
        if `node.alias {
            `node.name.sym = `node.name.create_symbol(
                access=SymbolAccess.PUBLIC, imported=True
            );
        }
    } elif (isinstance(`node.name, uni.Token) and `node.alias) {
        sym_node = `node.alias;
        sym_node.sym_tab.def_insert(sym_node, single_decl='import');
    }
}

impl SymTabBuildPass.enter_archetype(
    self: SymTabBuildPass, `node: uni.Archetype
) -> None {
    self.push_scope_and_link(`node);
    assert (`node.parent_scope is not None);
    `node.parent_scope.def_insert(`node, access_spec=`node, single_decl='archetype');
}

impl SymTabBuildPass.exit_archetype(
    self: SymTabBuildPass, `node: uni.Archetype
) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_ability(self: SymTabBuildPass, `node: uni.Ability) -> None {
    self.push_scope_and_link(`node);
    assert (`node.parent_scope is not None);
    `node.parent_scope.def_insert(`node, access_spec=`node, single_decl='ability');
    if `node.is_method {
        `node.sym_tab.def_insert(uni.Name.gen_stub_from_node(`node, 'self'));
        `node.sym_tab.def_insert(
            uni.Name.gen_stub_from_node(`node, 'super', set_name_of=`node.method_owner)
        );
    }
}

impl SymTabBuildPass.exit_ability(self: SymTabBuildPass, `node: uni.Ability) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_impl_def(self: SymTabBuildPass, `node: uni.ImplDef) -> None {
    self.push_scope_and_link(`node);
    assert (`node.parent_scope is not None);
    `node.parent_scope.def_insert(`node, single_decl='impl');
}

impl SymTabBuildPass.exit_impl_def(self: SymTabBuildPass, `node: uni.ImplDef) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_sem_def(self: SymTabBuildPass, `node: uni.SemDef) -> None {
    self.push_scope_and_link(`node);
    assert (`node.parent_scope is not None);
    `node.parent_scope.def_insert(`node, single_decl='sem');
}

impl SymTabBuildPass.exit_sem_def(self: SymTabBuildPass, `node: uni.SemDef) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_enum(self: SymTabBuildPass, `node: uni.Enum) -> None {
    self.push_scope_and_link(`node);
    assert (`node.parent_scope is not None);
    `node.parent_scope.def_insert(`node, access_spec=`node, single_decl='enum');
}

impl SymTabBuildPass.enter_has_var(self: SymTabBuildPass, `node: uni.HasVar) -> None {
    if isinstance(`node.parent, uni.ArchHas) {
        `node.sym_tab.def_insert(
            `node, single_decl='has var', access_spec=`node.parent
        );
    }
}

impl SymTabBuildPass.enter_param_var(
    self: SymTabBuildPass, `node: uni.ParamVar
) -> None {
    `node.sym_tab.def_insert(`node, single_decl='param');
}

"""Handle attribute access for self member assignments."""
impl SymTabBuildPass.exit_atom_trailer(
    self: SymTabBuildPass, `node: uni.AtomTrailer
) -> None {
    if not self._is_self_member_assignment(`node) {
        return;
    }
    chain = `node.as_attr_list;
    ability = `node.find_parent_of_type(uni.Ability);
    if (ability and ability.method_owner) {
        archetype = ability.method_owner;
        if isinstance(archetype, uni.Archetype) {
            archetype.sym_tab.def_insert(chain[1], access_spec=archetype);
        }
    }
}

"""Check if the node represents a simple `self.attr = value` assignment."""
impl SymTabBuildPass._is_self_member_assignment(
    self: SymTabBuildPass, `node: uni.AtomTrailer
) -> bool {
    if not (`node.parent and isinstance(`node.parent, uni.Assignment)) {
        return False;
    }
    if (`node != `node.parent.target[0]) {
        return False;
    }
    chain = `node.as_attr_list;
    if ((len(chain) != 2) or (chain[0].sym_name != 'self')) {
        return False;
    }
    ability = `node.find_parent_of_type(uni.Ability);
    return (
        (ability is not None)
        and ability.is_method
        and not ability.is_static
        and not ability.is_cls_method
    );
}

impl SymTabBuildPass.exit_enum(self: SymTabBuildPass, `node: uni.Enum) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_typed_ctx_block(
    self: SymTabBuildPass, `node: uni.TypedCtxBlock
) -> None {
    self.push_scope_and_link(`node);
}

impl SymTabBuildPass.exit_typed_ctx_block(
    self: SymTabBuildPass, `node: uni.TypedCtxBlock
) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_if_stmt(self: SymTabBuildPass, `node: uni.IfStmt) -> None {
    self.push_scope_and_link(`node);
}

impl SymTabBuildPass.exit_if_stmt(self: SymTabBuildPass, `node: uni.IfStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_else_if(self: SymTabBuildPass, `node: uni.ElseIf) -> None {
    self.push_scope_and_link(`node);
}

impl SymTabBuildPass.exit_else_if(self: SymTabBuildPass, `node: uni.ElseIf) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_else_stmt(
    self: SymTabBuildPass, `node: uni.ElseStmt
) -> None {
    self.push_scope_and_link(`node);
}

impl SymTabBuildPass.exit_else_stmt(self: SymTabBuildPass, `node: uni.ElseStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_try_stmt(self: SymTabBuildPass, `node: uni.TryStmt) -> None {
    self.push_scope_and_link(`node);
}

impl SymTabBuildPass.exit_try_stmt(self: SymTabBuildPass, `node: uni.TryStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_except(self: SymTabBuildPass, `node: uni.Except) -> None {
    self.push_scope_and_link(`node);
    if `node.name {
        `node.sym_tab.def_insert(`node.name, single_decl='local var');
    }
}

impl SymTabBuildPass.exit_except(self: SymTabBuildPass, `node: uni.Except) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_finally_stmt(
    self: SymTabBuildPass, `node: uni.FinallyStmt
) -> None {
    self.push_scope_and_link(`node);
}

impl SymTabBuildPass.exit_finally_stmt(
    self: SymTabBuildPass, `node: uni.FinallyStmt
) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_iter_for_stmt(
    self: SymTabBuildPass, `node: uni.IterForStmt
) -> None {
    self.push_scope_and_link(`node);
}

impl SymTabBuildPass.exit_iter_for_stmt(
    self: SymTabBuildPass, `node: uni.IterForStmt
) -> None {
    self.pop_scope();
}

"""Recursively define symbols in unpacking expressions."""
impl SymTabBuildPass._def_insert_unpacking(
    self: SymTabBuildPass, `node: uni.Expr, sym_tab: UniScopeNode
) -> None {
    if isinstance(`node, uni.Name) {
        sym_tab.def_insert(`node, single_decl='iterator');
    } elif isinstance(`node, (uni.TupleVal, uni.ListVal)) {
        for target_var in `node.values {
            if isinstance(target_var, uni.Expr) {
                self._def_insert_unpacking(target_var, sym_tab);
            }
        }
    } elif (isinstance(`node, uni.UnaryExpr) and (`node.op.name == Tokens.STAR_MUL)) {
        self._def_insert_unpacking(`node.operand, sym_tab);
    }
}

impl SymTabBuildPass.enter_in_for_stmt(
    self: SymTabBuildPass, `node: uni.InForStmt
) -> None {
    self.push_scope_and_link(`node);
    self._def_insert_unpacking(`node.target, `node.sym_tab);
}

impl SymTabBuildPass.exit_in_for_stmt(
    self: SymTabBuildPass, `node: uni.InForStmt
) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_while_stmt(
    self: SymTabBuildPass, `node: uni.WhileStmt
) -> None {
    self.push_scope_and_link(`node);
}

impl SymTabBuildPass.exit_while_stmt(
    self: SymTabBuildPass, `node: uni.WhileStmt
) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_with_stmt(
    self: SymTabBuildPass, `node: uni.WithStmt
) -> None {
    self.push_scope_and_link(`node);
}

impl SymTabBuildPass.exit_with_stmt(self: SymTabBuildPass, `node: uni.WithStmt) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.exit_expr_as_item(
    self: SymTabBuildPass, `node: uni.ExprAsItem
) -> None {
    if (`node.alias and isinstance(`node.alias, uni.Name)) {
        `node.alias.sym_tab.def_insert(`node.alias, single_decl='context var');
    }
}

impl SymTabBuildPass.enter_lambda_expr(
    self: SymTabBuildPass, `node: uni.LambdaExpr
) -> None {
    self.push_scope_and_link(`node);
}

impl SymTabBuildPass.exit_lambda_expr(
    self: SymTabBuildPass, `node: uni.LambdaExpr
) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_list_compr(
    self: SymTabBuildPass, `node: uni.ListCompr
) -> None {
    self.push_scope_and_link(`node);
    for i in `node.compr {
        self._def_insert_unpacking(i.target, `node.sym_tab);
    }
}

impl SymTabBuildPass.exit_list_compr(
    self: SymTabBuildPass, `node: uni.ListCompr
) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_set_compr(
    self: SymTabBuildPass, `node: uni.SetCompr
) -> None {
    self.push_scope_and_link(`node);
    for i in `node.compr {
        self._def_insert_unpacking(i.target, `node.sym_tab);
    }
}

impl SymTabBuildPass.exit_set_compr(self: SymTabBuildPass, `node: uni.SetCompr) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_gen_compr(
    self: SymTabBuildPass, `node: uni.GenCompr
) -> None {
    self.push_scope_and_link(`node);
    for i in `node.compr {
        self._def_insert_unpacking(i.target, `node.sym_tab);
    }
}

impl SymTabBuildPass.exit_gen_compr(self: SymTabBuildPass, `node: uni.GenCompr) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_dict_compr(
    self: SymTabBuildPass, `node: uni.DictCompr
) -> None {
    self.push_scope_and_link(`node);
    for i in `node.compr {
        self._def_insert_unpacking(i.target, `node.sym_tab);
    }
}

impl SymTabBuildPass.exit_dict_compr(
    self: SymTabBuildPass, `node: uni.DictCompr
) -> None {
    self.pop_scope();
}

impl SymTabBuildPass.enter_match_case(
    self: SymTabBuildPass, `node: uni.MatchCase
) -> None {
    self.push_scope_and_link(`node);
}

impl SymTabBuildPass.exit_match_case(
    self: SymTabBuildPass, `node: uni.MatchCase
) -> None {
    self.pop_scope();
}
