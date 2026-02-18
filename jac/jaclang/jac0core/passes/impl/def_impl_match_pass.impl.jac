"""Implementation for def_impl_match_pass constructs."""

"""Connect Decls and Defs."""
impl DeclImplMatchPass.transform(
    self: DeclImplMatchPass, ir_in: uni.Module
) -> uni.Module {
    self.cur_node = ir_in;
    self.connect_impls(ir_in.sym_tab, ir_in.sym_tab);
    for impl_module in ir_in.impl_mod {
        self.connect_impls(impl_module.sym_tab, ir_in.sym_tab);
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

"""Connect implementations from source symbol table to declarations in
target symbol table.

        When source_sym_tab and target_sym_tab are the same, this connects
within the same module.
        When different, it connects implementations from impl_mod to
declarations in the main module.
        """
impl DeclImplMatchPass.connect_impls(
    self: DeclImplMatchPass, source_sym_tab: UniScopeNode, target_sym_tab: UniScopeNode
) -> None {
    for sym in source_sym_tab.names_in_scope.values() {
        if not isinstance(sym.decl.name_of, uni.ImplDef) {
            continue;
        }
        arch_refs = sym.sym_name.split('.')[1:];
        name_of_links: list = [];
        lookup = target_sym_tab.lookup(arch_refs[0]);
        if (lookup and not isinstance(lookup.decl.name_of, uni.AstImplNeedingNode)) {
            lookup = target_sym_tab.parent_scope.lookup(arch_refs[0])
            if target_sym_tab.parent_scope
            else target_sym_tab.lookup(arch_refs[0]);
        }
        decl_node = self.defn_lookup(lookup)
        if ((len(arch_refs) == 1) and lookup)
        else lookup.defn[-1] if lookup else None;
        name_of_links.append(decl_node) if decl_node else None;
        for name in arch_refs[1:] {
            if decl_node {
                lookup = decl_node.name_of.sym_tab.lookup(name, deep=False)
                if decl_node.name_of.sym_tab
                else None;
                decl_node = self.defn_lookup(lookup)
                if ((len(arch_refs) == 1) and lookup)
                else lookup.defn[-1] if lookup else None;
                name_of_links.append(decl_node) if decl_node else None;
            } else {
                break;
            }
        }
        if not decl_node {
            # Only log error if the archetype was found but the ability wasn't
            if len(name_of_links) > 0 {
                self.log_error(
                    f"Implementation could not be matched to a declaration.",
                    sym.decl.name_of
                );
            }
            continue;
        } elif (isinstance(decl_node, uni.Ability) and decl_node.is_abstract) {
            self.log_warning(
                f"Abstract ability {decl_node.py_resolve_name()} should not have a definition.",
                decl_node
            );
            continue;
        }
        if (
            not isinstance((valid_decl := decl_node.name_of), uni.AstImplNeedingNode)
            or not (valid_decl.sym_tab and sym.decl.name_of.sym_tab)
        ) {
            raise self.ice(
                f"Expected AstImplNeedingNode, got {valid_decl.__class__.__name__}. Not possible."
            ) ;
        }
        self.validate_params_match(sym, decl_node.name_of);
        valid_decl.body = sym.decl.name_of;
        sym.decl.name_of.decl_link = valid_decl;
        for (idx, a) in enumerate(sym.decl.name_of.target) {
            if ((idx < len(name_of_links)) and (link := name_of_links[idx])) {
                a.name_spec.name_of = link.name_of;
                if ((link_sym := link.sym) is not None) {
                    a.name_spec.sym = link_sym;
                }
            }
        }
        sym.decl.name_of.sym_tab.names_in_scope.update(
            valid_decl.sym_tab.names_in_scope
        );
        valid_decl.sym_tab.names_in_scope = sym.decl.name_of.sym_tab.names_in_scope;
        self._resolve_impl_body_symbols(sym.decl.name_of);
    }
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

"""Validate if the parameters match."""
impl DeclImplMatchPass.validate_params_match(
    self: DeclImplMatchPass, sym: Symbol, valid_decl: uni.AstSymbolNode
) -> None {
    if (
        isinstance(valid_decl, uni.Ability)
        and isinstance(sym.decl.name_of, uni.ImplDef)
        and isinstance(valid_decl.signature, uni.FuncSignature)
        and isinstance(sym.decl.name_of.spec, uni.FuncSignature)
    ) {
        params_decl = valid_decl.signature.params;
        params_defn = sym.decl.name_of.spec.params;
        decl_count = len(params_decl) if params_decl else 0;
        defn_count = len(params_defn) if params_defn else 0;
        if (defn_count != decl_count) {
            self.log_error(
                f"Parameter count mismatch for ability {sym.sym_name}.",
                sym.decl.name_of.name_spec
            );
            self.log_error(
                f"From the declaration of {valid_decl.name_spec.sym_name}.",
                valid_decl.name_spec
            );
        } elif (params_decl and params_defn) {
            for idx in range(len(params_defn)) {
                if ((par := params_decl[idx].parent) is not None) {
                    loc_in_kid = par.kid.index(params_decl[idx]);
                    par.kid[loc_in_kid] = params_defn[idx];
                }
                params_decl[idx] = params_defn[idx];
            }
        }
    }
}

"""Re-resolve symbols in an impl body after symbol table synchronization.

        When impl files are compiled, they don't have access to the base
module's
        symbols (like 'self' or archetype members). After DeclImplMatchPass
links
        the impl to its declaration and synchronizes symbol tables, we need to
        re-traverse the impl body to resolve these symbols.
        """
impl DeclImplMatchPass._resolve_impl_body_symbols(
    self: DeclImplMatchPass, impl_def: uni.ImplDef
) -> None {
    for name_node in impl_def.get_all_sub_nodes(uni.Name) {
        if (name_node.sym is not None) {
            continue;
        }
        if isinstance(name_node.parent, uni.AtomTrailer) {
            continue;
        }
        if name_node.sym_tab {
            name_node.sym_tab.use_lookup(name_node);
        }
    }
    for trailer_node in impl_def.get_all_sub_nodes(uni.AtomTrailer) {
        chain = trailer_node.as_attr_list;
        if (chain and (chain[0].sym is None) and trailer_node.sym_tab) {
            trailer_node.sym_tab.chain_use_lookup(chain);
        }
    }
}
