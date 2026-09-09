impl SymTabBuildPass.before_pass -> None {
    self.cur_sym_tab = [];
}

impl SymTabBuildPass.push_scope_and_link(key_node: UniScopeNode) -> None {
    if not len(self.cur_sym_tab) {
        self.cur_sym_tab.append(key_node);
    } else {
        self.cur_sym_tab.append(self.cur_scope.link_kid_scope(key_node=key_node));
    }
}

impl SymTabBuildPass.pop_scope -> UniScopeNode {
    return self.cur_sym_tab.pop();
}

impl SymTabBuildPass.cur_scope.getter -> UniScopeNode {
    return self.cur_sym_tab[-1];
}

impl SymTabBuildPass._bind_import_path_symbols(module_path: ModulePath) -> None {
    if module_path.path {
        for n in module_path.path {
            if isinstance(n, Name) {
                n.sym = n.create_symbol(access=SymbolAccess.PUBLIC, imported=True);
            }
        }
    }
}

impl SymTabBuildPass.enter_module with Module entry {
    self.push_scope_and_link(here);
}

impl SymTabBuildPass.exit_module with Module exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_type_alias with TypeAlias entry {
    self.push_scope_and_link(here);
    assert (here.parent_scope is not None);
    here.parent_scope.def_insert(here, access_spec=here, single_decl='type_alias');
}

impl SymTabBuildPass.exit_type_alias with TypeAlias exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_type_param with TypeParam entry {
    if here.sym_tab is not None {
        here.sym_tab.def_insert(here, single_decl='type_param');
    }
}

impl SymTabBuildPass.exit_global_vars with GlobalVars exit {
    import from jaclang.compiler.frontend.constant { SymbolType }
    for i in here.assignments {
        for j in i.target {
            if isinstance(j, AstSymbolNode) {
                j.name_spec._sym_category = SymbolType.MOD_VAR;
                j.sym_tab.def_insert(j, access_spec=here, single_decl='global var');
            } else {
                self.ice('Expected name type for global vars');
            }
        }
    }
}

impl SymTabBuildPass.exit_assignment with Assignment exit {
    if here.find_parent_of_type(ImplDef) is not None {
        return;
    }

    if isinstance(here.parent, GlobalVars) {
        return;
    }
    if here.type_tag is not None {
        for i in here.target {
            if isinstance(i, Name) {
                scope = find_python_scope_node_of(i);
                if scope is not None and i.sym_name in scope.implicit_rebinds {
                    self.emit(E0064, node_override=i, name=i.sym_name);
                }
            }
        }
    }
    bind_assignment_targets(here);
}

impl SymTabBuildPass.exit_binary_expr with BinaryExpr exit {
    import from jaclang.compiler.frontend.constant { Tokens as Tok }
    if not (isinstance(here.op, Token) and (here.op.name == Tok.WALRUS_EQ)) {
        return;
    }
    if isinstance(here.left, Name) {
        target_scope = here.left.sym_tab;
        owner: (UniNode | None) = here.parent;
        while (owner is not None and not isinstance(owner, (Ability, LambdaExpr))) {
            owner = owner.parent;
        }
        if owner is not None {
            target_scope = owner.sym_tab;
        }
        if ((sym := target_scope.lookup(here.left.sym_name, deep=False)) is None) {
            rebind_or_def_insert(here.left, target_scope, single_decl='walrus var');
        } else {
            sym.add_use(here.left.name_spec);
            record_cross_scope_rebind(target_scope, here.left.sym_name, sym);
        }
    }
}

impl SymTabBuildPass.enter_test with Test entry {
    self.push_scope_and_link(here);
    for i in TEST_ASSERT_METHOD_NAMES {
        here.sym_tab.def_insert(
            Name.gen_stub_from_node(here, i, set_name_of=here), imported=True
        );
    }
}

impl SymTabBuildPass.exit_test with Test exit {
    self.pop_scope();
}

impl SymTabBuildPass._exit_import_absorb(nd: Import) -> None {
    sym_table_to_update = find_python_scope_node_of(nd);
    if (sym_table_to_update is None) {
        return;
    }
    first_item = nd.items[0];
    if not isinstance(first_item, ModulePath) {
        return;
    }
    import_all_module_path_node: ModulePath = first_item;
    module: (Module | None) = nd.absorbed_mod;
    if (module is None) {
        return;
    }
    self._bind_import_path_symbols(import_all_module_path_node);
    if module {
        for sym in module.names_in_scope.values() {
            if (sym.access != SymbolAccess.PRIVATE) {
                sym_table_to_update.def_insert(
                    sym.defn[0], single_decl='import absorb', imported=True
                );
            }
        }

        for (name, overload_syms) in module.names_in_scope_overload.items() {
            for sym in overload_syms {
                if (sym.access != SymbolAccess.PRIVATE) {
                    sym_table_to_update.def_insert(
                        sym.defn[0], single_decl='import absorb', imported=True
                    );
                }
            }
        }
    }
}

impl SymTabBuildPass.exit_import with Import exit {
    if here.is_absorb {
        return self._exit_import_absorb(here);
    }
}

impl SymTabBuildPass.import_binding_scope(nd: AstSymbolNode) -> UniScopeNode {
    scope = nd.sym_tab;
    while (
        not isinstance(
            scope, (Module, Ability, Archetype, Enum, ImplDef, Test, LambdaExpr)
        )
        and scope.parent_scope is not None
    ) {
        scope = scope.parent_scope;
    }
    return scope;
}

impl SymTabBuildPass.exit_module_path with ModulePath exit {
    if here.alias {
        self.import_binding_scope(here.alias).def_insert(
            here.alias, single_decl='import', imported=True
        );
    } elif (
        here.path
        and not here.is_import_from
        and here.parent_of_type(Import)
        and not (
            here.parent_of_type(Import).from_loc
            and here.parent_of_type(Import).jac_detected
        )
    ) {
        if isinstance(here.path[0], Name) {
            self.import_binding_scope(here.path[0]).def_insert(
                here.path[0], imported=True
            );
        }
    } else {}
    if (here.path and (here.is_import_from or here.alias)) {
        self._bind_import_path_symbols(here);
    }
}

impl SymTabBuildPass.exit_module_item with ModuleItem exit {
    if isinstance(here.name, Name) {
        sym_node = here.alias or here.name;
        self.import_binding_scope(sym_node).def_insert(
            sym_node, single_decl='import', imported=True
        );
        if here.alias {
            here.name.sym = here.name.create_symbol(
                access=SymbolAccess.PUBLIC, imported=True
            );
        }
    } elif (isinstance(here.name, Token) and here.alias) {
        sym_node = here.alias;
        self.import_binding_scope(sym_node).def_insert(
            sym_node, single_decl='import', imported=True
        );
    }
}

impl SymTabBuildPass.enter_archetype with Archetype entry {
    if self.cur_sym_tab {
        existing_sym = self.cur_scope.names_in_scope.get(here.sym_name, None);
        if existing_sym {
            nd_native = here.in_native_context();
            nd_client = here.in_client_context();
            for d in existing_sym.defn {
                if (
                    isinstance(d.name_of, Archetype)
                    and (d.name_of.in_native_context() == nd_native)
                    and (d.name_of.in_client_context() == nd_client)
                ) {
                    self.emit(
                        E0077,
                        node_override=here,
                        name=here.sym_name,
                        kind=d.name_of.arch_type.value
                    );
                    break;
                }
            }
        }
    }
    self.push_scope_and_link(here);
    assert (here.parent_scope is not None);
    here.parent_scope.def_insert(here, access_spec=here, single_decl='archetype');
}

impl SymTabBuildPass.exit_archetype with Archetype exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_ability with Ability entry {
    self.push_scope_and_link(here);
    assert (here.parent_scope is not None);
    here.parent_scope.def_insert(here, access_spec=here, single_decl='ability');
    if here.is_method {
        here.sym_tab.def_insert(Name.gen_stub_from_node(here, 'self'));
        here.sym_tab.def_insert(
            Name.gen_stub_from_node(here, 'super', set_name_of=here.method_owner)
        );
    }
}

impl SymTabBuildPass.exit_ability with Ability exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_impl_def with ImplDef entry {
    self.push_scope_and_link(here);
    assert (here.parent_scope is not None);
    here.parent_scope.def_insert(here, single_decl='impl');
}

impl SymTabBuildPass.exit_impl_def with ImplDef exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_sem_def with SemDef entry {
    self.push_scope_and_link(here);
    assert (here.parent_scope is not None);
    here.parent_scope.def_insert(here, single_decl='sem');
}

impl SymTabBuildPass.exit_sem_def with SemDef exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_enum with Enum entry {
    self.push_scope_and_link(here);
    assert (here.parent_scope is not None);
    here.parent_scope.def_insert(here, access_spec=here, single_decl='enum');
}

impl SymTabBuildPass.enter_has_var with HasVar entry {
    if isinstance(here.parent, ArchHas) {
        here.sym_tab.def_insert(here, single_decl='has var', access_spec=here.parent);
    }
}

impl SymTabBuildPass.enter_param_var with ParamVar entry {
    here.sym_tab.def_insert(here, single_decl='param');
}

impl SymTabBuildPass.exit_atom_trailer with AtomTrailer exit {
    if not self._is_self_member_assignment(here) {
        return;
    }
    chain = here.as_attr_list;

    ability = here.find_parent_of_type(Ability);
    if (ability and ability.method_owner) {
        archetype = ability.method_owner;
        if isinstance(archetype, Archetype) {
            if (
                archetype.arch_type.name == 'KW_CLASS'
                or archetype.sym_tab.lookup(chain[1].sym_name, deep=False) is not None
            ) {
                archetype.sym_tab.def_insert(chain[1], access_spec=archetype);
            }
        }
        return;
    }

    impl_def = here.find_parent_of_type(ImplDef);
    if (impl_def and (len(impl_def.target) >= 2)) {
        archetype_name = impl_def.target[0].sym_name;
        if impl_def.sym_tab and impl_def.sym_tab.parent_scope {
            lookup = impl_def.sym_tab.parent_scope.lookup(archetype_name, deep=True);
            if (lookup and isinstance(lookup.decl.name_of, Archetype)) {
                archetype = lookup.decl.name_of;

                if (
                    archetype.arch_type.name == 'KW_CLASS'
                    or archetype.sym_tab.lookup(chain[1].sym_name, deep=False)
                        is not None
                ) {
                    archetype.sym_tab.def_insert(chain[1], access_spec=archetype);
                }
            }
        }
    }
}

impl SymTabBuildPass._is_self_member_assignment(nd: AtomTrailer) -> bool {
    if not (nd.parent and isinstance(nd.parent, Assignment)) {
        return False;
    }
    if (nd != nd.parent.target[0]) {
        return False;
    }
    chain = nd.as_attr_list;
    if ((len(chain) != 2) or (chain[0].sym_name != 'self')) {
        return False;
    }

    ability = nd.find_parent_of_type(Ability);
    if ability is not None {
        return (
            ability.is_method and not ability.is_static and not ability.is_cls_method
        );
    }

    impl_def = nd.find_parent_of_type(ImplDef);
    if (impl_def and (len(impl_def.target) >= 2)) {
        return True;
    }
    return False;
}

impl SymTabBuildPass.exit_enum with Enum exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_typed_ctx_block with TypedCtxBlock entry {
    self.push_scope_and_link(here);
}

impl SymTabBuildPass.exit_typed_ctx_block with TypedCtxBlock exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_open_stmt with OpenStmt entry {
    self.push_scope_and_link(here);
}

impl SymTabBuildPass.exit_open_stmt with OpenStmt exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_if_stmt with IfStmt entry {
    if type(here) is not IfStmt {
        return;
    }
    self.push_scope_and_link(here);
}

impl SymTabBuildPass.exit_if_stmt with IfStmt exit {
    if type(here) is not IfStmt {
        return;
    }
    self.pop_scope();
}

impl SymTabBuildPass.enter_else_if with ElseIf entry {
    self.push_scope_and_link(here);
}

impl SymTabBuildPass.exit_else_if with ElseIf exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_else_stmt with ElseStmt entry {
    self.push_scope_and_link(here);
}

impl SymTabBuildPass.exit_else_stmt with ElseStmt exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_try_stmt with TryStmt entry {
    self.push_scope_and_link(here);
}

impl SymTabBuildPass.exit_try_stmt with TryStmt exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_except with Except entry {
    self.push_scope_and_link(here);
    if here.name {
        here.sym_tab.def_insert(here.name, single_decl='local var');
    }
}

impl SymTabBuildPass.exit_except with Except exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_finally_stmt with FinallyStmt entry {
    self.push_scope_and_link(here);
}

impl SymTabBuildPass.exit_finally_stmt with FinallyStmt exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_iter_for_stmt with IterForStmt entry {
    self.push_scope_and_link(here);
}

impl SymTabBuildPass.exit_iter_for_stmt with IterForStmt exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_in_for_stmt with InForStmt entry {
    self.push_scope_and_link(here);
    def_insert_unpacking(here.target, here.sym_tab);
}

impl SymTabBuildPass.exit_in_for_stmt with InForStmt exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_while_stmt with WhileStmt entry {
    self.push_scope_and_link(here);
}

impl SymTabBuildPass.exit_while_stmt with WhileStmt exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_forever_stmt with ForeverStmt entry {
    self.push_scope_and_link(here);
}

impl SymTabBuildPass.exit_forever_stmt with ForeverStmt exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_with_stmt with WithStmt entry {
    self.push_scope_and_link(here);
}

impl SymTabBuildPass.exit_with_stmt with WithStmt exit {
    self.pop_scope();
}

impl SymTabBuildPass.exit_expr_as_item with ExprAsItem exit {
    if (here.alias and isinstance(here.alias, Name)) {
        here.alias.sym_tab.def_insert(here.alias, single_decl='context var');
    }
}

impl SymTabBuildPass.enter_lambda_expr with LambdaExpr entry {
    self.push_scope_and_link(here);
}

impl SymTabBuildPass.exit_lambda_expr with LambdaExpr exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_list_compr with ListCompr entry {
    if type(here) is not ListCompr {
        return;
    }
    self.push_scope_and_link(here);
    for i in here.compr {
        def_insert_unpacking(i.target, here.sym_tab);
    }
}

impl SymTabBuildPass.exit_list_compr with ListCompr exit {
    if type(here) is not ListCompr {
        return;
    }
    self.pop_scope();
}

impl SymTabBuildPass.enter_set_compr with SetCompr entry {
    self.push_scope_and_link(here);
    for i in here.compr {
        def_insert_unpacking(i.target, here.sym_tab);
    }
}

impl SymTabBuildPass.exit_set_compr with SetCompr exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_gen_compr with GenCompr entry {
    self.push_scope_and_link(here);
    for i in here.compr {
        def_insert_unpacking(i.target, here.sym_tab);
    }
}

impl SymTabBuildPass.exit_gen_compr with GenCompr exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_dict_compr with DictCompr entry {
    self.push_scope_and_link(here);
    for i in here.compr {
        def_insert_unpacking(i.target, here.sym_tab);
    }
}

impl SymTabBuildPass.exit_dict_compr with DictCompr exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_inner_compr with InnerCompr entry {
    self.push_scope_and_link(here);
}

impl SymTabBuildPass.exit_inner_compr with InnerCompr exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_match_case with MatchCase entry {
    self.push_scope_and_link(here);
}

impl SymTabBuildPass.exit_match_case with MatchCase exit {
    self.pop_scope();
}

impl SymTabBuildPass.enter_switch_case with SwitchCase entry {
    self.push_scope_and_link(here);
}

impl SymTabBuildPass.exit_switch_case with SwitchCase exit {
    self.pop_scope();
}
