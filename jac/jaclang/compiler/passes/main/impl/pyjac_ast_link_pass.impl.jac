impl PyJacAstLinkPass.init(
    ir_in: uni.Module, prog: Any, cancel_token: Any = None
) -> None {
    super.init(ir_in, prog, cancel_token);
}

impl PyJacAstLinkPass.exit_atom_trailer(nd: uni.AtomTrailer) -> None {
    if (nd.is_attr and isinstance(nd.right, uni.AstSymbolNode)) {
        self.link_jac_py_nodes(jac_node=nd.right.name_spec, py_nodes=nd.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_k_w_pair(nd: uni.KWPair) -> None {
    if nd.key {
        self.link_jac_py_nodes(jac_node=nd.key, py_nodes=nd.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_non_local_stmt(nd: uni.NonLocalStmt) -> None {
    if (not nd.gen.py_ast or (len(nd.gen.py_ast) < len(nd.target))) {
        return;
    }
    for (x, y) in enumerate(nd.target) {
        self.link_jac_py_nodes(jac_node=y, py_nodes=[nd.gen.py_ast[x]]);
    }
}

impl PyJacAstLinkPass.exit_global_stmt(nd: uni.GlobalStmt) -> None {
    if (not nd.gen.py_ast or (len(nd.gen.py_ast) < len(nd.target))) {
        return;
    }
    for (x, y) in enumerate(nd.target) {
        self.link_jac_py_nodes(jac_node=y, py_nodes=[nd.gen.py_ast[x]]);
    }
}

impl PyJacAstLinkPass.exit_expr_as_item(nd: uni.ExprAsItem) -> None {
    self.link_jac_py_nodes(jac_node=nd.expr, py_nodes=nd.gen.py_ast);
    if nd.alias {
        self.link_jac_py_nodes(jac_node=nd.alias, py_nodes=nd.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_except(nd: uni.Except) -> None {
    if nd.name {
        self.link_jac_py_nodes(jac_node=nd.name, py_nodes=nd.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_param_var(nd: uni.ParamVar) -> None {
    self.link_jac_py_nodes(jac_node=nd.name, py_nodes=nd.gen.py_ast);
}

impl PyJacAstLinkPass.exit_impl_def(nd: uni.ImplDef) -> None {
    for i in nd.target {
        if i.name_spec.name_of.sym {
            self.link_jac_py_nodes(
                jac_node=i, py_nodes=i.name_spec.name_of.sym.decl.gen.py_ast
            );
            self.link_jac_py_nodes(
                jac_node=i.name_spec, py_nodes=i.name_spec.name_of.sym.decl.gen.py_ast
            );
        }
    }
    if (isinstance(nd.decl_link, uni.Ability) and nd.decl_link.signature) {
        if (isinstance(nd.spec, uni.FuncSignature) and nd.spec.params) {
            for src_prm in nd.spec.params {
                if (
                    isinstance(nd.decl_link.signature, uni.FuncSignature)
                    and nd.decl_link.signature.params
                ) {
                    for trg_prm in nd.decl_link.signature.params {
                        if (src_prm.name.sym_name == trg_prm.name.sym_name) {
                            self.link_jac_py_nodes(
                                jac_node=src_prm, py_nodes=trg_prm.gen.py_ast
                            );
                            self.link_jac_py_nodes(
                                jac_node=src_prm.name, py_nodes=trg_prm.name.gen.py_ast
                            );
                        }
                    }
                }
            }
        }
        if (
            (isinstance(nd.spec, uni.FuncSignature) and nd.spec.return_type)
            and (
                isinstance(nd.decl_link.signature, uni.FuncSignature)
                and nd.decl_link.signature.return_type
            )
        ) {
            self.link_jac_py_nodes(
                jac_node=nd.spec.return_type,
                py_nodes=nd.decl_link.signature.return_type.gen.py_ast
            );
        }
    }
    if (isinstance(nd.decl_link, uni.Ability) and isinstance(nd.target, Sequence)) {
        for arch in nd.target {
            if arch.name_spec.name_of.sym {
                arch.name_spec.name_of.sym.add_use(arch.name_spec);
            }
        }
    }
}

impl PyJacAstLinkPass.exit_ability(nd: uni.Ability) -> None {
    self.link_jac_py_nodes(jac_node=nd.name_ref, py_nodes=nd.gen.py_ast);
    if isinstance(nd.body, uni.ImplDef) {
        self.link_jac_py_nodes(jac_node=nd.body, py_nodes=nd.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_enum(nd: uni.Enum) -> None {
    if isinstance(nd.body, uni.ImplDef) {
        self.link_jac_py_nodes(jac_node=nd.body, py_nodes=nd.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_type_alias(nd: uni.TypeAlias) -> None {
    self.link_jac_py_nodes(jac_node=nd.name, py_nodes=nd.gen.py_ast);
}

impl PyJacAstLinkPass.exit_archetype(nd: uni.Archetype) -> None {
    self.link_jac_py_nodes(jac_node=nd.name, py_nodes=nd.gen.py_ast);
    if isinstance(nd.body, uni.ImplDef) {
        self.link_jac_py_nodes(jac_node=nd.body, py_nodes=nd.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_module_path(nd: uni.ModulePath) -> None {
    if nd.alias {
        self.link_jac_py_nodes(jac_node=nd.alias, py_nodes=nd.gen.py_ast);
    }
}

"""Link jac name ast to py ast nodes."""
impl PyJacAstLinkPass.link_jac_py_nodes(
    jac_node: uni.UniNode, py_nodes: list[ast3.AST]
) -> None {
    if (
        isinstance(jac_node, uni.ContextAwareNode)
        and jac_node.code_context == CodeContext.CLIENT
    ) {
        return;
    }
    jac_node.gen.py_ast = py_nodes;
    for i in py_nodes {
        if isinstance(i.jac_link, list) {
            i.jac_link.append(jac_node);
        }
    }
}
