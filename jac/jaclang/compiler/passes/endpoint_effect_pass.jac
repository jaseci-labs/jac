import from dataclasses { field }
import from jaclang.compiler.frontend.unitree {
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
    KWPair,
    ability_of_symbol,
    ImplDef,
    Name,
    SpecialVarRef,
    Symbol,
    Token,
    UniNode
}
import from jaclang.compiler.frontend.constant { SymbolType, Tokens as Tok }
import from jaclang.compiler.passes.uni_pass { UniPass }

walker EndpointEffectPass(UniPass) {
    has _is_writer: bool = False,
        _unknown: bool = False,
        _declared_reads: set[str] = field(default_factory=set),
        _declared_writes: set[str] = field(default_factory=set),
        _assumptions: set[str] = field(default_factory=set),
        _touches: set[str] = field(default_factory=`set),
        _visited: set[int] = field(default_factory=set);

    def before_pass {
        self._is_writer = False;
        self._unknown = False;
        self._declared_reads.clear();
        self._declared_writes.clear();
        self._assumptions.clear();
        self._touches.clear();
        self._visited.clear();
    }

    can enter_ability with Ability entry {
        import from jaclang.compiler.frontend.codeinfo { endpoint_key }
        if (
            not here.is_method
            and not here.in_client_context()
            and here.access is not None
            and here.access.tag.name == Tok.KW_PUB
            and isinstance(here.name_ref, Name)
        ) {
            self.ir_in.gen.interop_manifest.endpoint_effects[
                endpoint_key(self.ir_in, "func", here.name_ref.sym_name)
            ] = self._classify(
                self._resolved_body(here), "func", here.name_ref.sym_name, here
            );
        }
    }

    can enter_archetype with Archetype entry {
        import from jaclang.compiler.frontend.codeinfo { endpoint_key }
        if here.arch_kind != "walker" {
            return;
        }
        if not isinstance(here.name, Name) {
            return;
        }
        self.ir_in.gen.interop_manifest.endpoint_effects[
            endpoint_key(self.ir_in, "walker", here.name.sym_name)
        ] = self._classify(self._resolved_body(here), "walker", here.name.sym_name);
    }

    def _classify(
        body_nodes: list, kind: str, name: str, declaration: Ability | None = None
    ) -> dict {
        import from jaclang.compiler.frontend.codeinfo { endpoint_descriptor }
        self._is_writer = False;
        self._unknown = False;
        self._declared_reads.clear();
        self._declared_writes.clear();
        self._assumptions.clear();
        self._touches.clear();
        self._visited.clear();
        declared = self._declaration_effects(declaration)
            if declaration is not None
            else None;
        if declared is not None {
            self._declared_reads.update(declared["reads"]);
            self._declared_writes.update(declared["writes"]);
            self._assumptions.add("Declared effects of " + name);
        } else {
            for nd in body_nodes {
                self._scan(nd);
            }
        }
        result = endpoint_descriptor(self.ir_in, kind, name);
        result["reads"] = sorted(list(self._declared_reads))
            if declared is not None
            else ["*"];
        result["writes"] = ["*"]
            if self._is_writer or self._unknown
            else sorted(list(self._declared_writes));
        result["assumptions"] = sorted(list(self._assumptions));
        result["unknown"] = self._unknown;
        result["observed_tags"] = sorted(list(self._touches));
        return result;
    }

    def _scan(nd: (UniNode | None)) -> None {
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
                    self._is_writer = True;
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
                declared = self._declared_effects(nd);
                if declared is not None {
                    import from jaclang.compiler.tools.unparse_pass { unparse_node }
                    self._declared_reads.update(declared["reads"]);
                    self._declared_writes.update(declared["writes"]);
                    self._assumptions.add(
                        "Declared effects of " + unparse_node(nd.target)
                    );
                } else {
                    body = self._callee_body(nd);
                    if not body {
                        self._unknown = True;
                    }
                    for stmt in body {
                        self._scan(stmt);
                    }
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

    def _call_target_symbol(call: FuncCall) -> (Symbol | None) {
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

    def _declared_effects(call: FuncCall) -> dict | None {
        decl = ability_of_symbol(self._call_target_symbol(call));
        return self._declaration_effects(decl) if decl is not None else None;
    }

    def _declaration_effects(decl: Ability) -> dict | None {
        import ast;
        for decorator in decl.decorators or [] {
            if not isinstance(decorator, FuncCall) {
                continue;
            }
            target = ability_of_symbol(self._call_target_symbol(decorator));
            if target is None
                or not target.loc.mod_path.replace("\\", "/").endswith(
                    "/jaclang/lib/effects.jac"
                ) {
                continue;
            }
            import from jaclang.compiler.tools.unparse_pass { unparse_node }
            result: dict = {"reads": [], "writes": []};
            for pair in decorator.params or [] {
                if not isinstance(pair, KWPair)
                    or pair.key is None
                    or pair.key.sym_name not in result {
                    raise ValueError(
                        "Effect declarations require reads= and writes= literal lists"
                    );
                }
                values = ast.literal_eval(unparse_node(pair.value));
                if not isinstance(values, list)
                    or any(not isinstance(v, str) or not v for v in values) {
                    raise ValueError(
                        "Effect dependencies must be literal nonempty strings"
                    );
                }
                result[pair.key.sym_name] = values;
            }
            return result;
        }
        return None;
    }

    def _callee_body(call: FuncCall) -> list {
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

    def _resolved_body(owner: UniNode) -> list {
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
