"""Implementation for semantic_analysis_pass constructs."""

impl SemanticAnalysisPass.enter_archetype(
    self: SemanticAnalysisPass, nd: uni.Archetype
) -> None {
    def inform_from_walker(nd: uni.UniNode) -> None {
        for i in nd.get_all_sub_nodes(uni.VisitStmt) + nd.get_all_sub_nodes(
            uni.DisengageStmt
        ) + nd.get_all_sub_nodes(uni.EdgeOpRef) + nd.get_all_sub_nodes(
            uni.EventSignature
        ) + nd.get_all_sub_nodes(uni.TypedCtxBlock) {
            i.from_walker = True;
        }
    }
    if (nd.arch_type.name == Tok.KW_WALKER) {
        inform_from_walker(nd);
        for i in self.get_all_sub_nodes(nd, uni.Ability) {
            if isinstance(i.body, uni.ImplDef) {
                inform_from_walker(i.body);
            }
        }
    }
    self._check_archetype(nd);
}

"""Check a single archetype for issues with attributes and methods."""
impl SemanticAnalysisPass._check_archetype(
    self: SemanticAnalysisPass, nd: uni.Archetype
) -> None {
    if ((nd.arch_type.name != Tok.KW_CLASS) and isinstance(nd.body, Sequence)) {
        found_default_init = False;
        for stmnt in nd.body {
            if not isinstance(stmnt, uni.ArchHas) {
                continue;
            }
            for var in stmnt.vars {
                if ((var.value is not None) or var.defer) {
                    found_default_init = True;
                } elif found_default_init {
                    self.log_error(
                        f"Non default attribute '{var.name.value}' follows default attribute",
                        node_override=var.name
                    );
                    break;
                }
            }
        }
        post_init_vars: list = [];
        postinit_method: (uni.Ability | None) = None;
        for item in nd.body {
            if isinstance(item, uni.ArchHas) {
                for var in item.vars {
                    if var.defer {
                        post_init_vars.append(var);
                    }
                }
            } elif isinstance(item, uni.Ability) {
                if item.is_abstract {
                    continue;
                }
                if (
                    isinstance(item.name_ref, uni.SpecialVarRef)
                    and (item.name_ref.name == Tok.KW_POST_INIT)
                ) {
                    postinit_method = item;
                }
            }
        }
        if ((len(post_init_vars) != 0) and (postinit_method is None)) {
            self.log_error(
                'Missing "postinit" method required by un initialized attribute(s).',
                node_override=post_init_vars[0].name_spec
            );
        }
    }
}

impl SemanticAnalysisPass._update_ctx(
    self: SemanticAnalysisPass, nd: uni.UniNode
) -> None {
    if isinstance(nd, uni.AtomTrailer) {
        self._change_atom_trailer_ctx(nd);
    } elif isinstance(nd, uni.AstSymbolNode) {
        nd.sym_tab.update_py_ctx_for_def(nd);
    } else {
        self.log_error(f"Invalid target for context update: {type(nd).__name__}");
    }
}

impl SemanticAnalysisPass.enter_has_var(
    self: SemanticAnalysisPass, nd: uni.HasVar
) -> None {
    if isinstance(nd.parent, uni.ArchHas) {
        nd.sym_tab.update_py_ctx_for_def(nd);
    } else {
        self.ice('HasVar should be under ArchHas');
    }
}

impl SemanticAnalysisPass.enter_param_var(
    self: SemanticAnalysisPass, nd: uni.ParamVar
) -> None {
    nd.sym_tab.update_py_ctx_for_def(nd);
}

impl SemanticAnalysisPass.enter_assignment(
    self: SemanticAnalysisPass, nd: uni.Assignment
) -> None {
    for target in nd.target {
        self._update_ctx(target);
    }
}

impl SemanticAnalysisPass.enter_in_for_stmt(
    self: SemanticAnalysisPass, nd: uni.InForStmt
) -> None {
    self._update_ctx(nd.target);
}

impl SemanticAnalysisPass.enter_expr_as_item(
    self: SemanticAnalysisPass, nd: uni.ExprAsItem
) -> None {
    if nd.alias {
        self._update_ctx(nd.alias);
    }
}

impl SemanticAnalysisPass.enter_inner_compr(
    self: SemanticAnalysisPass, nd: uni.InnerCompr
) -> None {
    self._update_ctx(nd.target);
}

"""Mark final element in trailer chain as a Store context."""
impl SemanticAnalysisPass._change_atom_trailer_ctx(
    self: SemanticAnalysisPass, nd: uni.AtomTrailer
) -> None {
    last = nd.right;
    if isinstance(last, uni.AtomExpr) {
        last.name_spec.py_ctx_func = ast3.Store;
        if isinstance(last.name_spec, uni.AstSymbolNode) {
            last.name_spec.py_ctx_func = ast3.Store;
        }
    }
}
