impl PyJacAstLinkPass.init(
    ir_in: uni.Module, prog: Any, cancel_token: Any = None
) -> None {
    super.init(ir_in, prog, cancel_token);
}

impl PyJacAstLinkPass.exit_atom_trailer(<>node: uni.AtomTrailer) -> None {
    if (<>node.is_attr and isinstance(<>node.right, uni.AstSymbolNode)) {
        self.link_jac_py_nodes(
            jac_node=<>node.right.name_spec, py_nodes=<>node.gen.py_ast
        );
    }
}

impl PyJacAstLinkPass.exit_k_w_pair(<>node: uni.KWPair) -> None {
    if <>node.key {
        self.link_jac_py_nodes(jac_node=<>node.key, py_nodes=<>node.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_non_local_stmt(<>node: uni.NonLocalStmt) -> None {
    if (not <>node.gen.py_ast or (len(<>node.gen.py_ast) < len(<>node.target))) {
        return;
    }
    for (x, y) in enumerate(<>node.target) {
        self.link_jac_py_nodes(jac_node=y, py_nodes=[<>node.gen.py_ast[x]]);
    }
}

impl PyJacAstLinkPass.exit_global_stmt(<>node: uni.GlobalStmt) -> None {
    if (not <>node.gen.py_ast or (len(<>node.gen.py_ast) < len(<>node.target))) {
        return;
    }
    for (x, y) in enumerate(<>node.target) {
        self.link_jac_py_nodes(jac_node=y, py_nodes=[<>node.gen.py_ast[x]]);
    }
}

impl PyJacAstLinkPass.exit_expr_as_item(<>node: uni.ExprAsItem) -> None {
    self.link_jac_py_nodes(jac_node=<>node.expr, py_nodes=<>node.gen.py_ast);
    if <>node.alias {
        self.link_jac_py_nodes(jac_node=<>node.alias, py_nodes=<>node.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_except(<>node: uni.Except) -> None {
    if <>node.name {
        self.link_jac_py_nodes(jac_node=<>node.name, py_nodes=<>node.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_param_var(<>node: uni.ParamVar) -> None {
    self.link_jac_py_nodes(jac_node=<>node.name, py_nodes=<>node.gen.py_ast);
}

impl PyJacAstLinkPass.exit_impl_def(<>node: uni.ImplDef) -> None {
    for i in <>node.target {
        if i.name_spec.name_of.sym {
            self.link_jac_py_nodes(
                jac_node=i, py_nodes=i.name_spec.name_of.sym.decl.gen.py_ast
            );
            self.link_jac_py_nodes(
                jac_node=i.name_spec, py_nodes=i.name_spec.name_of.sym.decl.gen.py_ast
            );
        }
    }
    if (isinstance(<>node.decl_link, uni.Ability) and <>node.decl_link.signature) {
        if (isinstance(<>node.spec, uni.FuncSignature) and <>node.spec.params) {
            for src_prm in <>node.spec.params {
                if (
                    isinstance(<>node.decl_link.signature, uni.FuncSignature)
                    and <>node.decl_link.signature.params
                ) {
                    for trg_prm in <>node.decl_link.signature.params {
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
            (isinstance(<>node.spec, uni.FuncSignature) and <>node.spec.return_type)
            and (
                isinstance(<>node.decl_link.signature, uni.FuncSignature)
                and <>node.decl_link.signature.return_type
            )
        ) {
            self.link_jac_py_nodes(
                jac_node=<>node.spec.return_type,
                py_nodes=<>node.decl_link.signature.return_type.gen.py_ast
            );
        }
    }
    if (
        isinstance(<>node.decl_link, uni.Ability)
        and isinstance(<>node.target, Sequence)
    ) {
        for arch in <>node.target {
            if arch.name_spec.name_of.sym {
                arch.name_spec.name_of.sym.add_use(arch.name_spec);
            }
        }
    }
}

impl PyJacAstLinkPass.exit_ability(<>node: uni.Ability) -> None {
    self.link_jac_py_nodes(jac_node=<>node.name_ref, py_nodes=<>node.gen.py_ast);
    if isinstance(<>node.body, uni.ImplDef) {
        self.link_jac_py_nodes(jac_node=<>node.body, py_nodes=<>node.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_enum(<>node: uni.Enum) -> None {
    if isinstance(<>node.body, uni.ImplDef) {
        self.link_jac_py_nodes(jac_node=<>node.body, py_nodes=<>node.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_archetype(<>node: uni.Archetype) -> None {
    self.link_jac_py_nodes(jac_node=<>node.name, py_nodes=<>node.gen.py_ast);
    if isinstance(<>node.body, uni.ImplDef) {
        self.link_jac_py_nodes(jac_node=<>node.body, py_nodes=<>node.gen.py_ast);
    }
}

impl PyJacAstLinkPass.exit_module_path(<>node: uni.ModulePath) -> None {
    if <>node.alias {
        self.link_jac_py_nodes(jac_node=<>node.alias, py_nodes=<>node.gen.py_ast);
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
        if isinstance(i.jac_link, <>list) {
            i.jac_link.append(jac_node);
        }
    }
}
