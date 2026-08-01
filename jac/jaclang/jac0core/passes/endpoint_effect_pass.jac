import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { SymbolType, Tokens as Tok }
import from jaclang.jac0core.passes.uni_pass { UniPass }

class EndpointEffectPass(UniPass) {
    def before_pass(self: EndpointEffectPass) {
        self._is_writer: bool = False;
        self._touches: set[str] = set();
        self._visited: set[int] = set();
    }

    def enter_ability(self: EndpointEffectPass, nd: uni.Ability) {
        if (
            not nd.is_method
            and not nd.in_client_context()
            and nd.access is not None
            and nd.access.tag.name == Tok.KW_PUB
            and isinstance(nd.name_ref, uni.Name)
        ) {
            self.ir_in.gen.interop_manifest.endpoint_effects[
                f"func:{nd.name_ref.sym_name}"
            ] = self._classify(self._resolved_body(nd));
        }
    }

    def enter_archetype(self: EndpointEffectPass, nd: uni.Archetype) -> None {
        if nd.arch_kind != "walker" {
            return;
        }
        if not isinstance(nd.name, uni.Name) {
            return;
        }
        self.ir_in.gen.interop_manifest.endpoint_effects[
            f"walker:{nd.name.sym_name}"
        ] = self._classify(self._resolved_body(nd));
    }

    def _classify(self: EndpointEffectPass, body_nodes: list) -> dict {
        self._is_writer = False;
        self._touches = set();
        self._visited = set();
        for nd in body_nodes {
            self._scan(nd);
        }
        touches_list = sorted(self._touches) if self._touches else ["*"];
        return {"is_writer": self._is_writer, "touches": touches_list};
    }

    def _scan(self: EndpointEffectPass, nd: (uni.UniNode | None)) -> None {
        if nd is None {
            return;
        }

        if isinstance(nd, uni.BinaryExpr) {
            if isinstance(nd.op, uni.ConnectOp) {
                self._is_writer = True;

                if nd.op.conn_type and isinstance(nd.op.conn_type, uni.Name) {
                    self._touches.add(nd.op.conn_type.sym_name);
                }
            } elif isinstance(nd.op, uni.DisconnectOp) {
                self._is_writer = True;
            } elif isinstance(nd.op, uni.Token) and nd.op.name == Tok.KW_SPAWN {
                self._is_writer = True;
            }
        }

        if isinstance(nd, uni.DeleteStmt) {
            self._is_writer = True;
        }

        if isinstance(nd, uni.Assignment) and nd.target {
            for tgt in nd.target {
                if isinstance(tgt, uni.AtomTrailer) and tgt.is_attr {
                    root_expr = tgt.target;
                    while isinstance(root_expr, uni.AtomTrailer) {
                        root_expr = root_expr.target;
                    }
                    is_self = (
                        isinstance(root_expr, uni.SpecialVarRef)
                        and root_expr.sym_name == 'self'
                    );
                    if not is_self {
                        self._is_writer = True;
                    }
                }
            }
        }

        if isinstance(nd, uni.FuncCall) {
            arch_sym = self._call_target_symbol(nd);
            if arch_sym
                and arch_sym.sym_type in [SymbolType.NODE_ARCH, SymbolType.EDGE_ARCH] {
                self._is_writer = True;
                self._touches.add(arch_sym.sym_name);
            }

            if id(nd) not in self._visited {
                self._visited.add(id(nd));
                for stmt in self._callee_body(nd) {
                    self._scan(stmt);
                }
            }
        }

        if isinstance(nd, uni.EventSignature) and nd.arch_tag_info {
            if isinstance(nd.arch_tag_info, uni.Name) {
                self._touches.add(nd.arch_tag_info.sym_name);
            } elif isinstance(nd.arch_tag_info, uni.BoolExpr) {
                for val in nd.arch_tag_info.values {
                    if isinstance(val, uni.Name) {
                        self._touches.add(val.sym_name);
                    }
                }
            }
        }

        for child in nd.kid {
            if child {
                self._scan(child);
            }
        }
    }

    def _call_target_symbol(
        self: EndpointEffectPass, call: uni.FuncCall
    ) -> (uni.Symbol | None) {
        if isinstance(call.target, uni.Name) {
            sym = call.target.sym;
            if not sym and call.target.sym_tab {
                sym = call.target.sym_tab.lookup(call.target.sym_name, deep=True);
            }
            return sym;
        }

        if isinstance(call.target, uni.AtomTrailer) {
            attrs = call.target.as_attr_list;
            if attrs {
                last = attrs[-1];
                if isinstance(last, uni.AstSymbolNode) and last.sym {
                    return last.sym;
                }
            }
        }
        return None;
    }

    def _callee_body(self: EndpointEffectPass, call: uni.FuncCall) -> list {
        sym = self._call_target_symbol(call);
        if not sym or not sym.defn {
            return [];
        }
        defn_node = sym.defn[0];
        ability = None;
        if isinstance(defn_node, uni.Ability) {
            ability = defn_node;
        } elif defn_node.parent and isinstance(defn_node.parent, uni.Ability) {
            ability = defn_node.parent;
        }
        if ability {
            return self._resolved_body(ability);
        }
        return [];
    }

    def _resolved_body(self: EndpointEffectPass, owner: uni.UniNode) -> list {
        resolver: any = owner?._get_impl_resolved_body;
        if resolver is not None {
            try {
                resolved = resolver();
                if isinstance(resolved, list) {
                    return resolved;
                }
            } except Exception { }
        }
        body = owner?.body;
        if isinstance(body, list) {
            return body;
        }
        if isinstance(body, uni.ImplDef) and isinstance(body.body, Sequence) {
            return [stmt for stmt in body.body];
        }
        return [];
    }
}
