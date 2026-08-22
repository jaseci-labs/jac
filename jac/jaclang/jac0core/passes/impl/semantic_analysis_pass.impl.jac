impl inform_from_walker(nd: UniNode) -> None {
    for i in nd.get_all_sub_nodes(VisitStmt)
        + nd.get_all_sub_nodes(DisengageStmt)
        + nd.get_all_sub_nodes(EdgeOpRef)
        + nd.get_all_sub_nodes(EventSignature)
        + nd.get_all_sub_nodes(TypedCtxBlock) {
        i.from_walker = True;
    }
}

impl SemanticAnalysisPass.enter_archetype(
    self: SemanticAnalysisPass, nd: Archetype
) -> None {
    if (nd.arch_kind == "walker") {
        inform_from_walker(nd);
        for i in nd.get_all_sub_nodes(Ability) {
            if isinstance(i.body, ImplDef) {
                inform_from_walker(i.body);
            }
        }
    }
    self._check_archetype(nd);
}

impl SemanticAnalysisPass._check_archetype(
    self: SemanticAnalysisPass, nd: Archetype
) -> None {
    if ((nd.arch_type.name != Tok.KW_CLASS) and isinstance(nd.body, Sequence)) {
        found_default_init = False;
        for stmnt in nd.body {
            if not isinstance(stmnt, ArchHas) or stmnt.is_static {
                continue;
            }
            for var in stmnt.vars {
                if var.accessors {
                    continue;
                }
                if ((var.value is not None) or var.defer) {
                    found_default_init = True;
                } elif found_default_init {
                    self.emit(E2004, node_override=var.name, name=var.name.value);
                    break;
                }
            }
        }
        post_init_vars: list[HasVar] = [];
        postinit_method: (Ability | None) = None;
        for item in nd.body {
            if isinstance(item, ArchHas) {
                if item.is_static {
                    continue;
                }
                for var in item.vars {
                    if var.defer {
                        post_init_vars.append(var);
                    }
                }
            } elif isinstance(item, Ability) {
                if item.is_abstract {
                    continue;
                }
                if (
                    isinstance(item.name_ref, SpecialVarRef)
                    and (
                        item.name_ref.name == Tok.KW_POST_INIT
                        or item.name_ref.name == Tok.KW_INIT
                    )
                )
                    or (
                        isinstance(item.name_ref, Name)
                        and item.name_ref.value.startswith("_init_")
                    ) {
                    postinit_method = item;
                }
            }
        }
        if ((len(post_init_vars) != 0) and (postinit_method is None)) {
            self.emit(E2005, node_override=post_init_vars[0].name_spec);
        }
        arch_kind = nd.arch_type.value;
        methods = nd.get_methods();
        prop_types = self._property_type_names(methods);
        for method in methods {
            prop_name = (
                method.name_ref.value if isinstance(method.name_ref, Name) else "x"
            );
            method_decorators: list[UniNode] = [];
            if method.decorators is not None {
                for dec_item in method.decorators {
                    method_decorators.append(dec_item);
                }
            }
            for dec in method_decorators {
                prop_dec = "";
                if isinstance(dec, Name) {
                    if dec.sym_name == 'classmethod' {
                        self.emit(W2006, node_override=dec, kind=arch_kind);
                    } elif dec.sym_name == 'staticmethod' {
                        self.emit(W2007, node_override=dec, kind=arch_kind);
                    } elif dec.value == 'property' {
                        prop_dec = dec.value;
                    }
                } elif (
                    isinstance(dec, AtomTrailer)
                    and dec.is_attr
                    and isinstance(dec.right, Name)
                    and isinstance(dec.target, Name)
                    and dec.right.value in ['getter', 'setter', 'deleter']
                ) {
                    prop_dec = f"{dec.target.value}.{dec.right.value}";
                }
                if prop_dec != "" {
                    self.emit(
                        W2029,
                        node_override=dec,
                        decorator=prop_dec,
                        kind=arch_kind,
                        name=prop_name,
                        type_name=prop_types.get(prop_name, "...")
                    );
                }
            }
        }
    }
}

impl SemanticAnalysisPass._property_type_names(
    self: SemanticAnalysisPass, methods: list[Ability]
) -> dict[str, str] {
    names: dict[str, str] = {};
    for method in methods {
        sig = method.signature;
        if not isinstance(sig, FuncSignature) {
            continue;
        }
        ret = sig.return_type;
        if isinstance(method.name_ref, Name) and isinstance(ret, Name) {
            names[method.name_ref.value] = ret.value;
        }
    }
    return names;
}

impl SemanticAnalysisPass._update_ctx(self: SemanticAnalysisPass, nd: UniNode) -> None {
    if isinstance(nd, AtomTrailer) {
        self._change_atom_trailer_ctx(nd);
    } elif isinstance(nd, AstSymbolNode) {
        nd.sym_tab.update_expr_ctx_for_def(nd);
    } else {
        self.emit(E2008, target=type(nd).__name__);
    }
}

impl SemanticAnalysisPass.enter_has_var(
    self: SemanticAnalysisPass, nd: HasVar
) -> None {
    if isinstance(nd.parent, ArchHas) {
        nd.sym_tab.update_expr_ctx_for_def(nd);
    } else {
        self.ice('HasVar should be under ArchHas');
    }
}

impl SemanticAnalysisPass.enter_param_var(
    self: SemanticAnalysisPass, nd: ParamVar
) -> None {
    nd.sym_tab.update_expr_ctx_for_def(nd);
}

impl SemanticAnalysisPass.enter_assignment(
    self: SemanticAnalysisPass, nd: Assignment
) -> None {
    for target in nd.target {
        self._update_ctx(target);
    }
}

impl SemanticAnalysisPass.enter_in_for_stmt(
    self: SemanticAnalysisPass, nd: InForStmt
) -> None {
    self._update_ctx(nd.target);
}

impl SemanticAnalysisPass.enter_expr_as_item(
    self: SemanticAnalysisPass, nd: ExprAsItem
) -> None {
    if nd.alias {
        self._update_ctx(nd.alias);
    }
}

impl SemanticAnalysisPass.enter_inner_compr(
    self: SemanticAnalysisPass, nd: InnerCompr
) -> None {
    self._update_ctx(nd.target);
}

impl SemanticAnalysisPass._change_atom_trailer_ctx(
    self: SemanticAnalysisPass, nd: AtomTrailer
) -> None {
    last = nd.right;
    if isinstance(last, AtomExpr) {
        last.name_spec.expr_ctx = ExprCtx.STORE;
        if isinstance(last.name_spec, AstSymbolNode) {
            last.name_spec.expr_ctx = ExprCtx.STORE;
        }
    }
}
