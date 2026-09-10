impl DeclImplMatchPass._run_impl(ir_in: Module) -> Module {
    fresh_reported: set[int] = set();
    self._e2026_reported = fresh_reported;
    self.cur_node = ir_in;

    self.connect_impls(ir_in.sym_tab);

    for arch in ir_in.get_all_sub_nodes(Archetype) {
        self._populate_inline_init_symbols(arch);
    }
    self._resolve_symbols_in_subtree(ir_in);
    return ir_in;
}

impl DeclImplMatchPass.defn_lookup(lookup: Symbol) -> (NameAtom | None) {
    for candidate in reversed(lookup.defn) {
        declaration = candidate.name_of;
        if isinstance(declaration, AstImplNeedingNode) and declaration.needs_impl {
            return candidate;
        }
    }
    return None;
}

impl DeclImplMatchPass._find_archetype_defn(lookup: Symbol) -> (NameAtom | None) {
    first_archetype: NameAtom | None = None;
    last_definition: NameAtom | None = None;
    for candidate in lookup.defn {
        last_definition = candidate;
        declaration = candidate.name_of;
        if isinstance(declaration, Archetype) {
            if declaration.body is not None {
                return candidate;
            }
            if first_archetype is None {
                first_archetype = candidate;
            }
        }
    }
    return first_archetype if first_archetype is not None else last_definition;
}

impl DeclImplMatchPass.connect_impls(root_scope: UniScopeNode) -> None {
    pending: list[UniScopeNode] = [root_scope];
    visited_scopes: set[int] = set();
    visited_bindings: set[int] = set();
    while pending {
        scope = pending.pop();
        if id(scope) in visited_scopes {
            continue;
        }
        visited_scopes.add(id(scope));
        binding_scope = scope.primary_scope;
        if id(binding_scope) not in visited_bindings {
            visited_bindings.add(id(binding_scope));
            seen_symbols: set[int] = set();
            for sym in binding_scope.names_in_scope.values() {
                if id(sym) in seen_symbols {
                    continue;
                }
                seen_symbols.add(id(sym));
                for defn in sym.defn {
                    declaration = defn.name_of;
                    if isinstance(declaration, ImplDef) {
                        self._connect_one_impl(declaration, sym.sym_name, binding_scope);
                    }
                }
            }
            self._report_bare_redecls(binding_scope);
        }
        # Linked scopes share bindings but retain their distinct lexical
        # children. Visit both child sets without deriving the bindings twice.
        for child in reversed(scope.kid_scope) {
            pending.append(child);
        }
    }
}

impl DeclImplMatchPass._connect_one_impl(
    impl_node: ImplDef, sym_name: str, target_sym_tab: UniScopeNode
) -> None {
    arch_refs = sym_name.split('.')[1:];
    name_of_links: list[NameAtom] = [];
    lookup = target_sym_tab.lookup(arch_refs[0]);
    if (lookup and not isinstance(lookup.decl.name_of, AstImplNeedingNode)) {
        lookup = target_sym_tab.parent_scope.lookup(arch_refs[0])
            if target_sym_tab.parent_scope
            else target_sym_tab.lookup(arch_refs[0]);
    }
    decl_node: (NameAtom | None) = self.defn_lookup(lookup)
        if ((len(arch_refs) == 1) and lookup)
        else self._find_archetype_defn(lookup) if lookup else None;
    name_of_links.append(decl_node) if decl_node else None;
    for (ref_idx, name) in enumerate(arch_refs[1:]) {
        if decl_node {
            if (
                isinstance(decl_node.name_of, HasVar)
                and (decl_node.name_of.accessors is not None)
                and (name in ["getter", "setter", "deleter"])
            ) {
                want_kind = "property" if (name == "getter") else name;
                acc_match: (Ability | None) = None;
                for acc in decl_node.name_of.accessors {
                    if acc.accessor_kind == want_kind {
                        acc_match = acc;
                        break;
                    }
                }
                acc_name = acc_match.name_ref if acc_match else None;
                decl_node = acc_name if isinstance(acc_name, NameAtom) else None;
                name_of_links.append(decl_node) if decl_node else None;
                continue;
            }
            lookup = decl_node.name_of.sym_tab.lookup(name, deep=False)
                if decl_node.name_of.sym_tab
                else None;
            decl_node = lookup.defn[-1] if lookup else None;
            next_ref = arch_refs[ref_idx + 2] if (ref_idx + 2) < len(arch_refs) else "";
            if lookup and next_ref in ["getter", "setter", "deleter"] {
                for cand in reversed(lookup.defn) {
                    if isinstance(cand.name_of, HasVar) and cand.name_of.accessors {
                        decl_node = cand;
                        break;
                    }
                }
            }
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
    }
    if (
        not isinstance((valid_decl := decl_node.name_of), AstImplNeedingNode)
        or not (valid_decl.sym_tab and impl_node.sym_tab)
    ) {
        raise RuntimeError(
            self.ice(
                f"Expected AstImplNeedingNode, got {valid_decl.__class__.__name__}. Not possible."
            )
        );
    }
    if not valid_decl.needs_impl and valid_decl.body {
        if isinstance(valid_decl.body, ImplDef) {
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
    valid_decl.link_impl(impl_node);
    for (idx, a) in enumerate(impl_node.target) {
        if ((idx < len(name_of_links)) and (link := name_of_links[idx])) {
            a.name_spec.name_of = link.name_of;
            if ((link_sym := link.sym) is not None) {
                a.name_spec.sym = link_sym;
            }
        }
    }

    for assignment in impl_node.get_all_sub_nodes(Assignment) {
        if assignment.type_tag is not None {
            import from jaclang.compiler.frontend.diagnostics { E0064 }
            for i in assignment.target {
                if isinstance(i, Name) {
                    scope = find_python_scope_node_of(i);
                    if scope is not None and i.sym_name in scope.implicit_rebinds {
                        self.emit(E0064, node_override=i, name=i.sym_name);
                    }
                }
            }
        }
        bind_assignment_targets(assignment);
    }

    if (
        len(name_of_links) >= 1
        and name_of_links[0]
        and isinstance(name_of_links[0].name_of, Archetype)
    ) {
        self._populate_self_member_symbols(impl_node, name_of_links[0].name_of);
    }
}

impl DeclImplMatchPass._report_bare_redecls(sym_tab: UniScopeNode) -> None {
    for sym in sym_tab.names_in_scope.values() {
        stub: (UniNode | None) = None;
        bare: (UniNode | None) = None;
        for defn in sym.defn {
            defn_node = defn.name_of;
            if isinstance(defn_node, ImplDef) {
                continue;
            }
            if not isinstance(defn_node, AstImplNeedingNode) {
                continue;
            }
            defn_path = defn_node.loc.mod_path;
            if defn_node.body is None {
                stub = defn_node;
            } elif (
                defn_path.endswith('.impl.jac') or defn_path.endswith('.test.jac')
            ) {
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
    impl_node: ImplDef, sym_name: str, valid_decl: AstSymbolNode
) -> None {
    if (
        isinstance(valid_decl, Ability)
        and isinstance(valid_decl.signature, FuncSignature)
        and isinstance(impl_node.spec, FuncSignature)
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
                decl_param = params_decl[idx];
                defn_param = params_defn[idx];
                if not (
                    isinstance(decl_param, ParamVar)
                    and isinstance(defn_param, ParamVar)
                ) {
                    continue;
                }
                decl_name = decl_param.name.value;
                impl_name = defn_param.name.value;
                if decl_name != impl_name {
                    self.emit(
                        W2013,
                        node_override=defn_param.name,
                        decl_name=decl_name,
                        impl_name=impl_name
                    );
                }
            }
        }
    }
}

impl DeclImplMatchPass._resolve_symbols_in_subtree(root_node: UniNode) -> None {
    for name_node in root_node.get_all_sub_nodes(Name) {
        if name_node.sym is not None {
            continue;
        }
        if isinstance(name_node.parent, AtomTrailer) {
            continue;
        }
        if is_identifier_slot(name_node) {
            continue;
        }
        if name_node.sym_tab {
            try {
                name_node.sym_tab.use_lookup(name_node);
            } except ValueError {}
        }
    }
    for trailer_node in root_node.get_all_sub_nodes(AtomTrailer) {
        chain = trailer_node.as_attr_list;
        if chain and chain[0].sym is None and trailer_node.sym_tab {
            try {
                trailer_node.sym_tab.chain_use_lookup(chain);
            } except ValueError {}
        }
    }
}


impl DeclImplMatchPass._populate_self_member_symbols(
    impl_def: ImplDef, archetype: Archetype
) -> None {
    import from jaclang.compiler.frontend.diagnostics { W2080 }

    for trailer_node in impl_def.get_all_sub_nodes(AtomTrailer) {
        if not (trailer_node.parent and isinstance(trailer_node.parent, Assignment)) {
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
        assign: Assignment = trailer_node.parent;
        if archetype.arch_type.name == 'KW_CLASS' {
            archetype.sym_tab.def_insert(attr_name, access_spec=archetype);
        } elif assign.type_tag is not None {
            archetype.sym_tab.def_insert(attr_name, access_spec=archetype);
            method_name = "init";
            if (
                impl_def.decl_link
                and isinstance(impl_def.decl_link, Ability)
                and isinstance(impl_def.decl_link.name_ref, SpecialVarRef)
            ) {
                method_name = impl_def.decl_link.name_ref.value;
            } elif (impl_def.decl_link and isinstance(impl_def.decl_link, Ability)) {
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

impl DeclImplMatchPass._populate_inline_init_symbols(archetype: Archetype) -> None {
    import from jaclang.compiler.frontend.diagnostics { W2080 }

    if archetype.arch_type.name == 'KW_CLASS' {
        return;
    }

    for method_name in ('init', '__post_init__') {
        method_sym = archetype.sym_tab.lookup(method_name, deep=False);
        if not method_sym or not isinstance(method_sym.decl.name_of, Ability) {
            continue;
        }
        ability: Ability = method_sym.decl.name_of;

        for trailer_node in ability.get_all_sub_nodes(AtomTrailer) {
            if not (
                trailer_node.parent and isinstance(trailer_node.parent, Assignment)
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
            assign: Assignment = trailer_node.parent;

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

impl DeclImplMatchPass.transform(ir_in: Module) -> Module {
    self.ir_out = ir_in;
    ir_in spawn self;
    out = self.ir_out;
    assert isinstance(out, Module);
    return out;
}

impl DeclImplMatchPass.run_walk with Module entry {
    self.ir_out = self._run_impl(here);
}
