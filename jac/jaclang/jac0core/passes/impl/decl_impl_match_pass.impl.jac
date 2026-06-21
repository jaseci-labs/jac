"""Implementation for decl_impl_match_pass constructs."""

"""Connect Decls and Defs."""
impl DeclImplMatchPass.transform(
    self: DeclImplMatchPass, ir_in: uni.Module
) -> uni.Module {
    self._e2026_reported = set();
    self.cur_node = ir_in;
    # Annex (and variant) bodies are merged into ir_in's own tree by
    # JacAnnexPass, so a single same-module connect binds head and annex
    # decls/impls alike — no per-annex-module cross-table wiring needed.
    self.connect_impls(ir_in.sym_tab, ir_in.sym_tab);
    # Resolve all Load-context names across the unified tree. Idempotent — skips
    # Names whose sym is already set by the matched-impl path above. Catches
    # standalone top-level constructs (def/obj/node/walker/enum) merged from
    # .impl.jac files whose body reads would otherwise defeat type inference.
    self._resolve_symbols_in_subtree(ir_in);
    # Scan inline init/postinit for annotated self-assignments on obj types.
    # Must run after symbol resolution so all names are connected.
    for arch in ir_in.get_all_sub_nodes(uni.Archetype) {
        self._populate_inline_init_symbols(arch);
    }
    return ir_in;
}

"""Lookup a definition in a symbol table."""
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

"""Find the archetype definition from a symbol's definitions.

        When a class is used as a base class or has forward declarations,
        its symbol may have multiple definitions. This method finds the
        Archetype with a body (not a forward declaration).
        """
impl DeclImplMatchPass._find_archetype_defn(
    self: DeclImplMatchPass, lookup: Symbol
) -> (uni.NameAtom | None) {
    # First pass: find an Archetype with a body (not a forward declaration)
    for defn_idx in range(len(lookup.defn)) {
        candidate = lookup.defn[defn_idx];
        if (
            isinstance(candidate.name_of, uni.Archetype)
            and candidate.name_of.body is not None
        ) {
            return candidate;
        }
    }
    # Second pass: find any Archetype (including forward declarations)
    for defn_idx in range(len(lookup.defn)) {
        candidate = lookup.defn[defn_idx];
        if isinstance(candidate.name_of, uni.Archetype) {
            return candidate;
        }
    }
    # Fallback to last definition if no Archetype found
    return lookup.defn[-1] if lookup.defn else None;
}

"""Connect implementations from source symbol table to declarations in
target symbol table.

        When source_sym_tab and target_sym_tab are the same, this connects
within the same module.
        When different, it connects implementations in one scope to
declarations in another.
        """
impl DeclImplMatchPass.connect_impls(
    self: DeclImplMatchPass, source_sym_tab: UniScopeNode, target_sym_tab: UniScopeNode
) -> None {
    for sym in source_sym_tab.names_in_scope.values() {
        # Connect every ImplDef that defines this symbol, not just the primary:
        # after annex/variant merge, a head impl and an annex impl for the same
        # decl share one symbol, and connecting each is what surfaces a
        # duplicate implementation (E2017) -- the second to resolve a decl that
        # the first already bodied.
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

"""Connect a single ImplDef to its declaration in target_sym_tab."""
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
            # Native property accessor (`impl Cls.prop.getter/.setter/.deleter`):
            # resolve within the property's own accessor list rather than the
            # enclosing class scope, where every accessor of a given kind is
            # registered under the same bare name (`getter`) and would
            # otherwise all collapse onto one symbol.
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
        # Only log error if the archetype was found but the ability wasn't
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
    # SymTabBuildPass deferred assignment-target binding for impl bodies
    # because it can't see the decl's scope chain. Now that decl_link is
    # set and UniScopeNode.lookup follows it into the enclosing scope,
    # run the same binding decision here — shared helper, single source
    # of truth. Must run before _resolve_symbols_in_subtree because that
    # skips Names whose sym is already set.
    # `global x;` must be re-bound before its assignments: it pulls the
    # decl-module global into the body's Python scope (decl_link is only
    # reachable now) so the assignment below rebinds the global instead
    # of shadowing it with an inferred local that drops its type.
    for global_stmt in impl_node.get_all_sub_nodes(uni.GlobalStmt) {
        bind_global_stmt(global_stmt);
    }
    for assignment in impl_node.get_all_sub_nodes(uni.Assignment) {
        bind_assignment_targets(assignment);
    }
    self._resolve_symbols_in_subtree(impl_node);
    # Populate self-member symbols from impl to archetype for method impls
    # (e.g., impl Foo.init { self.x = 1; } should add 'x' to Foo's symbol table)
    if (
        len(name_of_links) >= 1
        and name_of_links[0]
        and isinstance(name_of_links[0].name_of, uni.Archetype)
    ) {
        self._populate_self_member_symbols(impl_node, name_of_links[0].name_of);
    }
}

"""Detect bare re-declaring definitions merged from annex files.

Catches the common mistake of writing `def foo() { ... }` instead of
`impl foo() { ... }` in an annex: after the merge, the bare definition and the
unlinked stub share one symbol, so the redecl is the symbol that carries both a
stub defn (no body) and a separate non-impl AstImplNeedingNode defn that owns a
body and originates in an annex file. Reported once per bare node (deduped via
`_e2026_reported`), so cross-variant stubs do not multiply the diagnostic.
"""
impl DeclImplMatchPass._report_bare_redecls(
    self: DeclImplMatchPass, sym_tab: UniScopeNode
) -> None {
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
            } elif (
                defn_node.loc.mod_path.endswith('.impl.jac')
                or defn_node.loc.mod_path.endswith('.test.jac')
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

"""Validate if the parameters match."""
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

"""Resolve unresolved Name and AtomTrailer symbols in a subtree.

Best-effort: a single Name or chain whose scope chain is detached
(seen in synthetic nodes from pyast_load_pass when type-checking
imported `.py` modules) must not abort resolution for the rest of
the subtree. The lookups here only ever populate `.sym`; failing
to do so on one node is a degraded-info outcome, not a correctness
hazard for the others.
"""
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


"""Populate self-member symbols from impl body to archetype's symbol table."""
impl DeclImplMatchPass._populate_self_member_symbols(
    self: DeclImplMatchPass, impl_def: uni.ImplDef, archetype: uni.Archetype
) -> None {
    import from jaclang.jac0core.diagnostics { W2080 }
    # Find all self.x = value assignments in the impl body
    for trailer_node in impl_def.get_all_sub_nodes(uni.AtomTrailer) {
        # Check if this is a self.attr = value assignment
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
        # Skip if already defined in the archetype
        if archetype.sym_tab.lookup(attr_name.sym_name, deep=False) is not None {
            continue;
        }
        assign: uni.Assignment = trailer_node.parent;
        if archetype.arch_type.name == 'KW_CLASS' {
            # class archetypes (Python-style): register all self-assignments.
            archetype.sym_tab.def_insert(attr_name, access_spec=archetype);
        } elif assign.type_tag is not None {
            # obj/node/edge/walker with annotated self-assignment
            # (e.g. self.x: int = 5 in init/postinit).
            # Register the symbol so downstream code resolves correctly,
            # but warn the user to declare it as a proper 'has' field.
            archetype.sym_tab.def_insert(attr_name, access_spec=archetype);
            # Determine the method name for the diagnostic message.
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
        # Unannotated self-assignments on obj/node/edge/walker are silently
        # skipped — these will be caught by E1030 "has no attribute".
    }
}

"""Scan inline init/postinit bodies for annotated self-assignments."""
impl DeclImplMatchPass._populate_inline_init_symbols(
    self: DeclImplMatchPass, archetype: uni.Archetype
) -> None {
    import from jaclang.jac0core.diagnostics { W2080 }
    # Only check obj/node/edge/walker (class types are handled above).
    if archetype.arch_type.name == 'KW_CLASS' {
        return;
    }
    # Scan init and __post_init__ (postinit) abilities within the archetype.
    for method_name in ('init', '__post_init__') {
        method_sym = archetype.sym_tab.lookup(method_name, deep=False);
        if not method_sym or not isinstance(method_sym.decl.name_of, uni.Ability) {
            continue;
        }
        ability: uni.Ability = method_sym.decl.name_of;
        # Scan the ability body (inline or impl-linked).
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
            # Skip if already defined in the archetype.
            if archetype.sym_tab.lookup(attr_name.sym_name, deep=False) is not None {
                continue;
            }
            assign: uni.Assignment = trailer_node.parent;
            # Only resolve annotated self-assignments (self.x: Type = value).
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
