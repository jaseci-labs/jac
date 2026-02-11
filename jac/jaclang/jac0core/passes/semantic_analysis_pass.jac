"""Jac Semantic Analysis Pass."""
import ast as ast3;
import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.passes.uni_pass { UniPass }
"""Jac Semantic Analysis Pass."""
class SemanticAnalysisPass(UniPass) {
    def enter_archetype(self: SemanticAnalysisPass, `node: uni.Archetype) -> None {
        def inform_from_walker(`node: uni.UniNode) -> None {
            for i in `node.get_all_sub_nodes(uni.VisitStmt) + `node.get_all_sub_nodes(
                uni.DisengageStmt
            ) + `node.get_all_sub_nodes(uni.EdgeOpRef) + `node.get_all_sub_nodes(
                uni.EventSignature
            ) + `node.get_all_sub_nodes(uni.TypedCtxBlock) {
                i.from_walker = True;
            }
        }
        if (`node.arch_type.name == Tok.KW_WALKER) {
            inform_from_walker(`node);
            for i in self.get_all_sub_nodes(`node, uni.Ability) {
                if isinstance(i.body, uni.ImplDef) {
                    inform_from_walker(i.body);
                }
            }
        }
        self._check_archetype(`node);
    }

    """Check a single archetype for issues with attributes and methods."""
    def _check_archetype(self: SemanticAnalysisPass, `node: uni.Archetype) -> None {
        if (
            (`node.arch_type.name != Tok.KW_CLASS) and isinstance(`node.body, Sequence)
        ) {
            found_default_init = False;
            for stmnt in `node.body {
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
            for item in `node.body {
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

    def _update_ctx(self: SemanticAnalysisPass, `node: uni.UniNode) -> None {
        if isinstance(`node, uni.AtomTrailer) {
            self._change_atom_trailer_ctx(`node);
        } elif isinstance(`node, uni.AstSymbolNode) {
            `node.sym_tab.update_py_ctx_for_def(`node);
        } else {
            self.log_error(f"Invalid target for context update: {type(node).__name__}");
        }
    }

    def enter_has_var(self: SemanticAnalysisPass, `node: uni.HasVar) -> None {
        if isinstance(`node.parent, uni.ArchHas) {
            `node.sym_tab.update_py_ctx_for_def(`node);
        } else {
            self.ice('HasVar should be under ArchHas');
        }
    }

    def enter_param_var(self: SemanticAnalysisPass, `node: uni.ParamVar) -> None {
        `node.sym_tab.update_py_ctx_for_def(`node);
    }

    def enter_assignment(self: SemanticAnalysisPass, `node: uni.Assignment) -> None {
        for target in `node.target {
            self._update_ctx(target);
        }
    }

    def enter_in_for_stmt(self: SemanticAnalysisPass, `node: uni.InForStmt) -> None {
        self._update_ctx(`node.target);
    }

    def enter_expr_as_item(self: SemanticAnalysisPass, `node: uni.ExprAsItem) -> None {
        if `node.alias {
            self._update_ctx(`node.alias);
        }
    }

    def enter_inner_compr(self: SemanticAnalysisPass, `node: uni.InnerCompr) -> None {
        self._update_ctx(`node.target);
    }

    """Mark final element in trailer chain as a Store context."""
    def _change_atom_trailer_ctx(
        self: SemanticAnalysisPass, `node: uni.AtomTrailer
    ) -> None {
        last = `node.right;
        if isinstance(last, uni.AtomExpr) {
            last.name_spec.py_ctx_func = ast3.Store;
            if isinstance(last.name_spec, uni.AstSymbolNode) {
                last.name_spec.py_ctx_func = ast3.Store;
            }
        }
    }
}
