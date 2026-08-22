import from jaclang.jac0core.unitree {
    Ability,
    Archetype,
    Assignment,
    AstSymbolNode,
    AtomTrailer,
    BinaryExpr,
    BoolExpr,
    ConnectOp,
    DeleteStmt,
    DisconnectOp,
    EventSignature,
    FuncCall,
    ImplDef,
    Name,
    SpecialVarRef,
    Symbol,
    Token,
    UniNode
}
import from jaclang.jac0core.constant { SymbolType, Tokens as Tok }
import from jaclang.jac0core.passes.uni_pass { UniPass }

class EndpointEffectPass(UniPass) {
    has _is_writer: bool = False,
        _touches: set[str] = set(),
        _visited: set[int] = set();

    def before_pass(self: EndpointEffectPass) {
        self._is_writer = False;
        self._touches.clear();
        self._visited.clear();
    }

    def enter_ability(self: EndpointEffectPass, nd: Ability) {
        if (
            not nd.is_method
            and not nd.in_client_context()
            and nd.access is not None
            and nd.access.tag.name == Tok.KW_PUB
            and isinstance(nd.name_ref, Name)
        ) {
            self.ir_in.gen.interop_manifest.endpoint_effects[
                f"func:{nd.name_ref.sym_name}"
            ] = self._classify(self._resolved_body(nd));
        }
    }

    def enter_archetype(self: EndpointEffectPass, nd: Archetype) -> None {
        if nd.arch_kind != "walker" {
            return;
        }
        if not isinstance(nd.name, Name) {
            return;
        }
        self.ir_in.gen.interop_manifest.endpoint_effects[
            f"walker:{nd.name.sym_name}"
        ] = self._classify(self._resolved_body(nd));
    }

    def _classify(self: EndpointEffectPass, body_nodes: list) -> dict {
        self._is_writer = False;
        self._touches.clear();
        self._visited.clear();
        for nd in body_nodes {
            self._scan(nd);
        }
        touches_list = sorted(list(self._touches)) if self._touches else ["*"];
        return {"is_writer": self._is_writer, "touches": touches_list};
    }

    def _scan(self: EndpointEffectPass, nd: (UniNode | None)) -> None {
        if nd is None {
            return;
        }

        if isinstance(nd, BinaryExpr) {
            if isinstance(nd.op, ConnectOp) {
                self._is_writer = True;

                if nd.op.conn_type and isinstance(nd.op.conn_type, Name) {
                    self._touches.add(nd.op.conn_type.sym_name);
                }
            } elif isinstance(nd.op, DisconnectOp) {
                self._is_writer = True;
            } elif isinstance(nd.op, Token) and nd.op.name == Tok.KW_SPAWN {
                self._is_writer = True;
            }
        }

        if isinstance(nd, DeleteStmt) {
            self._is_writer = True;
        }

        if isinstance(nd, Assignment) and nd.target {
            for tgt in nd.target {
                if isinstance(tgt, AtomTrailer) and tgt.is_attr {
                    root_expr = tgt.target;
                    while isinstance(root_expr, AtomTrailer) {
                        root_expr = root_expr.target;
                    }
                    is_self = (
                        isinstance(root_expr, SpecialVarRef)
                        and root_expr.sym_name == 'self'
                    );
                    if not is_self {
                        self._is_writer = True;
                    }
                }
            }
        }

        if isinstance(nd, FuncCall) {
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

        if isinstance(nd, EventSignature) and nd.arch_tag_info {
            if isinstance(nd.arch_tag_info, Name) {
                self._touches.add(nd.arch_tag_info.sym_name);
            } elif isinstance(nd.arch_tag_info, BoolExpr) {
                for val in nd.arch_tag_info.values {
                    if isinstance(val, Name) {
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
        self: EndpointEffectPass, call: FuncCall
    ) -> (Symbol | None) {
        if isinstance(call.target, Name) {
            sym = call.target.sym;
            if not sym and call.target.sym_tab {
                sym = call.target.sym_tab.lookup(call.target.sym_name, deep=True);
            }
            return sym;
        }

        if isinstance(call.target, AtomTrailer) {
            attrs = call.target.as_attr_list;
            if attrs {
                last = attrs[-1];
                if isinstance(last, AstSymbolNode) and last.sym {
                    return last.sym;
                }
            }
        }
        return None;
    }

    def _callee_body(self: EndpointEffectPass, call: FuncCall) -> list {
        sym = self._call_target_symbol(call);
        if not sym or not sym.defn {
            return [];
        }
        defn_node = sym.defn[0];
        ability = None;
        if isinstance(defn_node, Ability) {
            ability = defn_node;
        } elif defn_node.parent and isinstance(defn_node.parent, Ability) {
            ability = defn_node.parent;
        }
        if ability {
            return self._resolved_body(ability);
        }
        return [];
    }

    def _resolved_body(self: EndpointEffectPass, owner: UniNode) -> list {
        if isinstance(owner, Archetype) {
            return owner._get_impl_resolved_body();
        }
        if not isinstance(owner, Ability) {
            return [];
        }
        body = owner.body;
        if isinstance(body, list) {
            return body;
        }
        out: list[UniNode] = [];
        if isinstance(body, ImplDef) and isinstance(body.body, list) {
            for stmt in body.body {
                out.append(stmt);
            }
        }
        return out;
    }
}
