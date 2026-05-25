"""Initialize per-classification accumulators."""
impl WalkerEffectsPass.before_pass(self: WalkerEffectsPass) -> None {
    # Per-classification accumulators (reset for each endpoint body).
    self._is_writer: bool = False;
    self._touches: set[str] = set();
    self._visited: set[int] = set();
}

"""Classify a walker archetype by the effects in its (impl-resolved) body."""
impl WalkerEffectsPass.enter_archetype(
    self: WalkerEffectsPass, nd: uni.Archetype
) -> None {
    if nd.arch_type.name != Tok.KW_WALKER {
        return;
    }
    if not isinstance(nd.name, uni.Name) {
        return;
    }
    self.ir_in.gen.client_manifest.endpoint_effects[f"walker:{nd.name.sym_name}"] = (
        self._classify(self._resolved_body(nd))
    );
}

"""Classify a public server-context module-level `def` (an RPC endpoint).

Methods (walker/node abilities) are skipped -- their effects are captured by the
owning archetype. Client functions are never RPC-called. Non-public helpers are
skipped -- they are followed *into* when a public endpoint calls them (see
`_callee_body`), not keyed as endpoints themselves.
"""
impl WalkerEffectsPass.enter_ability(self: WalkerEffectsPass, nd: uni.Ability) -> None {
    if nd.is_method {
        return;
    }
    # Only server-context public `def`s are RPC endpoints. Client functions are
    # never RPC-called; private helpers are followed into, not keyed.
    if nd.in_client_context() {
        return;
    }
    if nd.access is None or nd.access.tag.name != Tok.KW_PUB {
        return;
    }
    if not isinstance(nd.name_ref, uni.Name) {
        return;
    }
    self.ir_in.gen.client_manifest.endpoint_effects[f"func:{nd.name_ref.sym_name}"] = (
        self._classify(self._resolved_body(nd))
    );
}

"""Run the effect scan over a flat statement body, returning the manifest entry.
The single definition of the `["*"]`-when-empty conservative default for
`touches` lives here."""
impl WalkerEffectsPass._classify(self: WalkerEffectsPass, body_nodes: list) -> dict {
    self._is_writer = False;
    self._touches = set();
    self._visited = set();
    for nd in body_nodes {
        self._scan(nd);
    }
    touches_list = sorted(self._touches) if self._touches else ["*"];
    return {"is_writer": self._is_writer, "touches": touches_list};
}

"""Recursively classify a node and its descendants for graph effects. The two
context-dependent operations -- recognizing a node/edge constructor and
following a call into its callee -- both go through resolved symbols, so there is
no syntactic fallback."""
impl WalkerEffectsPass._scan(
    self: WalkerEffectsPass, nd: (uni.UniNode | None)
) -> None {
    if nd is None {
        return;
    }
    # Edge create / delete, or sub-walker spawn.
    if isinstance(nd, uni.BinaryExpr) {
        if isinstance(nd.op, uni.ConnectOp) {
            self._is_writer = True;
            # ++>, <++, <++> may carry an explicit edge type to record.
            if nd.op.conn_type and isinstance(nd.op.conn_type, uni.Name) {
                self._touches.add(nd.op.conn_type.sym_name);
            }
        } elif isinstance(nd.op, uni.DisconnectOp) {
            self._is_writer = True;
        } elif isinstance(nd.op, uni.Token) and nd.op.name == Tok.KW_SPAWN {
            self._is_writer = True;
        }
    }
    # Node / edge deletion.
    if isinstance(nd, uni.DeleteStmt) {
        self._is_writer = True;
    }
    # Field mutation on a non-self target: `n.attr = ...`. `self.x` is
    # walker-local state, not a graph write, so it is excluded.
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
    # FuncCall: arch construction (a write + a touch) and interprocedural follow
    # into the callee body.
    if isinstance(nd, uni.FuncCall) {
        arch_sym = self._call_target_symbol(nd);
        if arch_sym
        and arch_sym.sym_type in [SymbolType.NODE_ARCH, SymbolType.EDGE_ARCH] {
            self._is_writer = True;
            self._touches.add(arch_sym.sym_name);
        }
        # The id()-based visited guard makes mutual / self recursion terminate;
        # `_callee_body` returns [] when the call can't be resolved to an
        # ability.
        if id(nd) not in self._visited {
            self._visited.add(id(nd));
            for stmt in self._callee_body(nd) {
                self._scan(stmt);
            }
        }
    }
    # Node types from an EventSignature: `can foo with NodeType entry`.
    if isinstance(nd, uni.EventSignature) and nd.arch_tag_info {
        if isinstance(nd.arch_tag_info, uni.Name) {
            self._touches.add(nd.arch_tag_info.sym_name);
        } elif isinstance(nd.arch_tag_info, uni.BoolExpr) {
            # Union type: NodeA | NodeB
            for val in nd.arch_tag_info.values {
                if isinstance(val, uni.Name) {
                    self._touches.add(val.sym_name);
                }
            }
        }
    }
    # Recurse into children.
    for child in nd.kid {
        if child {
            self._scan(child);
        }
    }
}

"""Resolve a call's target to its symbol (resolved, with a scope lookup)."""
impl WalkerEffectsPass._call_target_symbol(
    self: WalkerEffectsPass, call: uni.FuncCall
) -> (uni.Symbol | None) {
    if isinstance(call.target, uni.Name) {
        sym = call.target.sym;
        if not sym and call.target.sym_tab {
            sym = call.target.sym_tab.lookup(call.target.sym_name, deep=True);
        }
        return sym;
    }
    # Dotted attribute chain (a.b.c): the call targets the last attribute.
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

"""The callee ability's impl-resolved body, or [] if the call can't be
statically resolved to an ability."""
impl WalkerEffectsPass._callee_body(
    self: WalkerEffectsPass, call: uni.FuncCall
) -> list {
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

"""Flatten an archetype / ability body to a list of statements, resolving a
separate `impl` block when the declaration and body are split."""
impl WalkerEffectsPass._resolved_body(
    self: WalkerEffectsPass, owner: uni.UniNode
) -> list {
    if hasattr(owner, "_get_impl_resolved_body") {
        try {
            resolved = owner._get_impl_resolved_body();
            if isinstance(resolved, list) {
                return resolved;
            }
        } except Exception {
            pass;
        }
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
