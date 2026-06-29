impl DeclImplMatchPass.transform(
    self: DeclImplMatchPass, ir_in: uni.Module
) -> uni.Module {
    self._e2026_reported = set();
    self.cur_node = ir_in;

    self.connect_impls(ir_in.sym_tab, ir_in.sym_tab);

    self._resolve_symbols_in_subtree(ir_in);

    for arch in ir_in.get_all_sub_nodes(uni.Archetype) {
        self._populate_inline_init_symbols(arch);
    }
    return ir_in;
}

impl DeclImplMatchPass.defn_lookup(
    self: DeclImplMatchPass, lookup: Symbol
) -> (uni.NameAtom | None) {
    for defn in range(len(lookup.defn)) {
        candidate = lookup.defn[(len(lookup.defn) - (defn + 1))];
        if (
            isinstance(candidate.name_of, uni.AstImplNeedingNode)
            and candidate.name_of.needs_impl
        ) {
            return candidate;
        }
    }
    return None;
}

impl DeclImplMatchPass._find_archetype_defn(
    self: DeclImplMatchPass, lookup: Symbol
) -> (uni.NameAtom | None) {
    for defn_idx in range(len(lookup.defn)) {
        candidate = lookup.defn[defn_idx];
        if (
            isinstance(candidate.name_of, uni.Archetype)
            and candidate.name_of.body is not None
        ) {
            return candidate;
        }
    }

    for defn_idx in range(len(lookup.defn)) {
        candidate = lookup.defn[defn_idx];
        if isinstance(candidate.name_of, uni.Archetype) {
            return candidate;
        }
    }

    return lookup.defn[-1] if lookup.defn else None;
}

impl DeclImplMatchPass.connect_impls(
    self: DeclImplMatchPass, source_sym_tab: UniScopeNode, target_sym_tab: UniScopeNode
) -> None {
    for sym in source_sym_tab.names_in_scope.values() {
        for defn in sym.defn {
            if isinstance(defn.name_of, uni.ImplDef) {
                self._connect_one_impl(defn.name_of, sym.sym_name, target_sym_tab);
            }
        }
    }
    self._report_bare_redecls(source_sym_tab);
    for source_scope in source_sym_tab.kid_scope {
        if (source_sym_tab is target_sym_tab) {
            self.connect_impls(source_scope, source_scope);
        } else {
            for target_scope in target_sym_tab.kid_scope {
                if (source_scope.scope_name == target_scope.scope_name) {
                    self.connect_impls(source_scope, target_scope);
                    break;
                }
            }
        }
    }
}

impl DeclImplMatchPass._connect_one_impl(
    self: DeclImplMatchPass,
    impl_node: uni.ImplDef,
    sym_name: str,
    target_sym_tab: UniScopeNode
) -> None {
    arch_refs = sym_name.split('.')[1:];
    name_of_links: list = [];
    lookup = target_sym_tab.lookup(arch_refs[0]);
    if (lookup and not isinstance(lookup.decl.name_of, uni.AstImplNeedingNode)) {
        lookup = target_sym_tab.parent_scope.lookup(arch_refs[0])
            if target_sym_tab.parent_scope
            else target_sym_tab.lookup(arch_refs[0]);
    }
    decl_node = self.defn_lookup(lookup)
        if ((len(arch_refs) == 1) and lookup)
        else self._find_archetype_defn(lookup) if lookup else None;
    name_of_links.append(decl_node) if decl_node else None;
    for name in arch_refs[1:] {
        if decl_node {
            if (
                isinstance(decl_node.name_of, uni.HasVar)
                and (decl_node.name_of.accessors is not None)
                and (name in ["getter", "setter", "deleter"])
            ) {
                want_kind = "property" if (name == "getter") else name;
                acc_match: (uni.Ability | None) = None;
                for acc in decl_node.name_of.accessors {
                    if acc.accessor_kind == want_kind {
                        acc_match = acc;
                        break;
                    }
                }
                decl_node = acc_match.name_ref if acc_match else None;
                name_of_links.append(decl_node) if decl_node else None;
                continue;
            }
            lookup = decl_node.name_of.sym_tab.lookup(name, deep=False)
                if decl_node.name_of.sym_tab
                else None;
            decl_node = lookup.defn[-1] if lookup else None;
            name_of_links.append(decl_node) if decl_node else None;
        } else {
            break;
        }
    }
    if not decl_node {
        if len(name_of_links) > 0 {
            self.emit(E2009, node_override=impl_node);
        }
        return;
    } elif (isinstance(decl_node, uni.Ability) and decl_node.is_abstract) {
        self.emit(W2010, node_override=decl_node, name=decl_node.py_resolve_name());
        return;
    }
    if (
        not isinstance((valid_decl := decl_node.name_of), uni.AstImplNeedingNode)
        or not (valid_decl.sym_tab and impl_node.sym_tab)
    ) {
        raise self.ice(
            f"Expected AstImplNeedingNode, got {valid_decl.__class__.__name__}. Not possible."
        );
    }
    if not valid_decl.needs_impl and valid_decl.body {
        if isinstance(valid_decl.body, uni.ImplDef) {
            if valid_decl.body is impl_node {
                return;
            }
            self.emit(E2017, node_override=impl_node);
        } else {
            self.emit(E2016, node_override=impl_node);
        }
        return;
    }
    self.validate_params_match(impl_node, sym_name, decl_node.name_of);
    valid_decl.body = impl_node;
    impl_node.decl_link = valid_decl;
    for (idx, a) in enumerate(impl_node.target) {
        if ((idx < len(name_of_links)) and (link := name_of_links[idx])) {
            a.name_spec.name_of = link.name_of;
            if ((link_sym := link.sym) is not None) {
                a.name_spec.sym = link_sym;
            }
        }
    }
    impl_node.sym_tab.names_in_scope.update(valid_decl.sym_tab.names_in_scope);
    valid_decl.sym_tab.names_in_scope = impl_node.sym_tab.names_in_scope;

    for global_stmt in impl_node.get_all_sub_nodes(uni.GlobalStmt) {
        bind_global_stmt(global_stmt);
    }
    for assignment in impl_node.get_all_sub_nodes(uni.Assignment) {
        bind_assignment_targets(assignment);
    }
    self._resolve_symbols_in_subtree(impl_node);

    if (
        len(name_of_links) >= 1
        and name_of_links[0]
        and isinstance(name_of_links[0].name_of, uni.Archetype)
    ) {
        self._populate_self_member_symbols(impl_node, name_of_links[0].name_of);
    }
}

impl DeclImplMatchPass._report_bare_redecls(
    self: DeclImplMatchPass, sym_tab: UniScopeNode
) -> None {
    import from jaclang.jac0core.ext_registry { is_annex }
    for sym in sym_tab.names_in_scope.values() {
        stub: (uni.UniNode | None) = None;
        bare: (uni.UniNode | None) = None;
        for defn in sym.defn {
            defn_node = defn.name_of;
            if isinstance(defn_node, uni.ImplDef) {
                continue;
            }
            if not isinstance(defn_node, uni.AstImplNeedingNode) {
                continue;
            }
            if defn_node.body is None {
                stub = defn_node;
            } elif is_annex(defn_node.loc.mod_path) {
                bare = defn_node;
            }
        }
        if (stub is not None) and (bare is not None) {
            node_key = id(bare);
            if node_key in self._e2026_reported {
                continue;
            }
            self._e2026_reported.add(node_key);
            self.emit(E2026, node_override=bare, name=sym.sym_name);
        }
    }
}

impl DeclImplMatchPass.validate_params_match(
    self: DeclImplMatchPass,
    impl_node: uni.ImplDef,
    sym_name: str,
    valid_decl: uni.AstSymbolNode
) -> None {
    if (
        isinstance(valid_decl, uni.Ability)
        and isinstance(valid_decl.signature, uni.FuncSignature)
        and isinstance(impl_node.spec, uni.FuncSignature)
    ) {
        params_decl = valid_decl.signature.params;
        params_defn = impl_node.spec.params;
        decl_count = len(params_decl) if params_decl else 0;
        defn_count = len(params_defn) if params_defn else 0;
        if (defn_count != decl_count) {
            self.emit(E2011, node_override=impl_node.name_spec, name=sym_name);
            self.emit(
                E2012,
                node_override=valid_decl.name_spec,
                name=valid_decl.name_spec.sym_name
            );
        } elif (params_decl and params_defn) {
            for idx in range(len(params_decl)) {
                decl_name = params_decl[idx].name.value;
                impl_name = params_defn[idx].name.value;
                if decl_name != impl_name {
                    self.emit(
                        W2013,
                        node_override=params_defn[idx].name,
                        decl_name=decl_name,
                        impl_name=impl_name
                    );
                }
            }
        }
    }
}

impl DeclImplMatchPass._resolve_symbols_in_subtree(
    self: DeclImplMatchPass, root_node: uni.UniNode
) -> None {
    for name_node in root_node.get_all_sub_nodes(uni.Name) {
        if name_node.sym is not None {
            continue;
        }
        if isinstance(name_node.parent, uni.AtomTrailer) {
            continue;
        }
        if name_node.sym_tab {
            try {
                name_node.sym_tab.use_lookup(name_node);
            } except ValueError { }
        }
    }
    for trailer_node in root_node.get_all_sub_nodes(uni.AtomTrailer) {
        chain = trailer_node.as_attr_list;
        if chain and chain[0].sym is None and trailer_node.sym_tab {
            try {
                trailer_node.sym_tab.chain_use_lookup(chain);
            } except ValueError { }
        }
    }
}


impl DeclImplMatchPass._populate_self_member_symbols(
    self: DeclImplMatchPass, impl_def: uni.ImplDef, archetype: uni.Archetype
) -> None {
    import from jaclang.jac0core.diagnostics { W2080 }

    for trailer_node in impl_def.get_all_sub_nodes(uni.AtomTrailer) {
        if not (
            trailer_node.parent and isinstance(trailer_node.parent, uni.Assignment)
        ) {
            continue;
        }
        if (trailer_node != trailer_node.parent.target[0]) {
            continue;
        }
        chain = trailer_node.as_attr_list;
        if ((len(chain) != 2) or (chain[0].sym_name != 'self')) {
            continue;
        }
        attr_name = chain[1];

        if archetype.sym_tab.lookup(attr_name.sym_name, deep=False) is not None {
            continue;
        }
        assign: uni.Assignment = trailer_node.parent;
        if archetype.arch_type.name == 'KW_CLASS' {
            archetype.sym_tab.def_insert(attr_name, access_spec=archetype);
        } elif assign.type_tag is not None {
            archetype.sym_tab.def_insert(attr_name, access_spec=archetype);
            method_name = "init";
            if (
                impl_def.decl_link
                and isinstance(impl_def.decl_link, uni.Ability)
                and isinstance(impl_def.decl_link.name_ref, uni.SpecialVarRef)
            ) {
                method_name = impl_def.decl_link.name_ref.value;
            } elif (
                impl_def.decl_link and isinstance(impl_def.decl_link, uni.Ability)
            ) {
                method_name = impl_def.decl_link.name_spec.sym_name;
            }
            self.emit(
                W2080,
                node_override=attr_name,
                attr=attr_name.sym_name,
                method=method_name,
                arch_type=archetype.arch_type.value,
                name=archetype.name_spec.sym_name
            );
        }
    }
}

impl DeclImplMatchPass._populate_inline_init_symbols(
    self: DeclImplMatchPass, archetype: uni.Archetype
) -> None {
    import from jaclang.jac0core.diagnostics { W2080 }

    if archetype.arch_type.name == 'KW_CLASS' {
        return;
    }

    for method_name in ('init', '__post_init__') {
        method_sym = archetype.sym_tab.lookup(method_name, deep=False);
        if not method_sym or not isinstance(method_sym.decl.name_of, uni.Ability) {
            continue;
        }
        ability: uni.Ability = method_sym.decl.name_of;

        body_node = ability.body
            if not isinstance(ability.body, uni.ImplDef)
            else ability.body;
        for trailer_node in ability.get_all_sub_nodes(uni.AtomTrailer) {
            if not (
                trailer_node.parent and isinstance(trailer_node.parent, uni.Assignment)
            ) {
                continue;
            }
            if (trailer_node != trailer_node.parent.target[0]) {
                continue;
            }
            chain = trailer_node.as_attr_list;
            if ((len(chain) != 2) or (chain[0].sym_name != 'self')) {
                continue;
            }
            attr_name = chain[1];

            if archetype.sym_tab.lookup(attr_name.sym_name, deep=False) is not None {
                continue;
            }
            assign: uni.Assignment = trailer_node.parent;

            if assign.type_tag is None {
                continue;
            }
            archetype.sym_tab.def_insert(attr_name, access_spec=archetype);
            display_name = "postinit"
                if method_name == "__post_init__"
                else method_name;
            self.emit(
                W2080,
                node_override=attr_name,
                attr=attr_name.sym_name,
                method=display_name,
                arch_type=archetype.arch_type.value,
                name=archetype.name_spec.sym_name
            );
        }
    }
}
