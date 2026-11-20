impl graph_type_effect(t: (TypeBase | None)) -> GraphEffect {
    if t is None or isinstance(t, (AnyType, UnknownType)) {
        return GraphEffect.UNKNOWN;
    }
    if isinstance(t, TypeVarType) {
        if t.bound is None {
            return GraphEffect.UNKNOWN;
        }
        return graph_type_effect(t.bound);
    }
    if isinstance(t, UnionType) {
        verdict = GraphEffect.PURE;
        for member in t.types {
            found = graph_type_effect(member);
            if found == GraphEffect.WRITES {
                return GraphEffect.WRITES;
            }
            if found == GraphEffect.UNKNOWN {
                verdict = GraphEffect.UNKNOWN;
            }
        }
        return verdict;
    }
    if not isinstance(t, ClassType) {
        return GraphEffect.PURE;
    }
    if t.is_node_type() or t.is_edge_type() {
        return GraphEffect.WRITES;
    }
    if t.is_any_type() or t.is_builtin("object") {
        return GraphEffect.UNKNOWN;
    }
    return GraphEffect.PURE;
}

impl owner_body(owner: UniNode) -> list[UniNode] {
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
    if isinstance(body, ImplDef) and isinstance(body.body, list) {
        return list(body.body);
    }
    return [];
}

impl call_symbol(call: FuncCall) -> (Symbol | None) {
    if isinstance(call.target, Name) {
        sym = call.target.sym;
        if not sym {
            try {
                sym = call.target.sym_tab.lookup(call.target.sym_name, deep=True);
            } except ValueError {
                return None;
            }
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

impl effect_record(
    module: Module, kind: str, name: str, effect: GraphEffect
) -> dict[str, any] {
    record: dict[str, any] = dict(endpoint_descriptor(module, kind, name));
    record["reads"] = ["*"];
    record["writes"] = [] if effect == GraphEffect.PURE else ["*"];
    record["unknown"] = effect == GraphEffect.UNKNOWN;
    return record;
}

impl endpoint_effects(module: Module, evaluator: any) -> dict[str, dict[str, any]] {
    scan = GraphEffectScan(evaluator=evaluator);
    out: dict[str, dict[str, any]] = {};
    for ability in module.get_all_sub_nodes(Ability) {
        if ability.is_method
            or ability.in_client_context()
            or ability.access is None
            or ability.access.tag.name != Tok.KW_PUB
            or not isinstance(ability.name_ref, Name) {
            continue;
        }
        name = ability.name_ref.sym_name;
        out[endpoint_key(module, "func", name)] = effect_record(
            module, "func", name, scan.of_owner(ability)
        );
    }
    for arch in module.get_all_sub_nodes(Archetype) {
        if arch.arch_kind != "walker" or not isinstance(arch.name, Name) {
            continue;
        }
        name = arch.name.sym_name;
        out[endpoint_key(module, "walker", name)] = effect_record(
            module, "walker", name, scan.of_owner(arch)
        );
    }
    return out;
}

impl GraphEffectScan.of_owner(owner: UniNode) -> GraphEffect {
    key = id(owner);
    if key in self._memo {
        return self._memo[key];
    }
    if isinstance(owner, Ability) and owner.body is None {
        return GraphEffect.UNKNOWN;
    }
    if key in self._active {
        self._cycle_hits += 1;
        return GraphEffect.PURE;
    }
    hits = self._cycle_hits;
    self._active.add(key);
    try {
        found = self._of_nodes(owner_body(owner));
    } finally {
        self._active.discard(key);
    }
    if hits == self._cycle_hits or not self._active {
        self._memo[key] = found;
    }
    return found;
}

impl GraphEffectScan._of_nodes(roots: list[UniNode]) -> GraphEffect {
    pending: list[UniNode] = list(roots);
    pending.reverse();
    verdict = GraphEffect.PURE;
    while pending {
        nd = pending.pop();
        found = self._node_effect(nd);
        if found == GraphEffect.WRITES {
            return GraphEffect.WRITES;
        }
        if found == GraphEffect.UNKNOWN {
            verdict = GraphEffect.UNKNOWN;
        }
        kids: list[UniNode] = [kid for kid in [nd->:Kid:->] if kid];
        kids.extend(nd.own_impls);
        kids.reverse();
        pending.extend(kids);
    }
    return verdict;
}

impl GraphEffectScan._node_effect(nd: UniNode) -> GraphEffect {
    if isinstance(nd, BinaryExpr) {
        if isinstance(nd.op, (ConnectOp, DisconnectOp)) {
            return GraphEffect.WRITES;
        }
        if isinstance(nd.op, Token) and nd.op.name == Tok.KW_SPAWN {
            return self._spawn_effect([nd.left, nd.right]);
        }
        return GraphEffect.PURE;
    }
    if isinstance(nd, UnaryExpr) and nd.op.name == Tok.KW_SPAWN {
        return self._spawn_effect([nd.operand]);
    }
    if isinstance(nd, DeleteStmt) {
        return self._delete_effect(nd);
    }
    if isinstance(nd, Assignment) {
        verdict = GraphEffect.PURE;
        for target in nd.target {
            found = self._store_effect(target);
            if found == GraphEffect.WRITES {
                return GraphEffect.WRITES;
            }
            if found == GraphEffect.UNKNOWN {
                verdict = GraphEffect.UNKNOWN;
            }
        }
        return verdict;
    }
    if isinstance(nd, FuncCall) {
        return self._call_effect(nd);
    }
    return GraphEffect.PURE;
}

impl GraphEffectScan._call_effect(call: FuncCall) -> GraphEffect {
    callee_type = self._type_of(call.target);
    if isinstance(callee_type, ClassType) and callee_type.is_instantiable_class() {
        if callee_type.is_node_type() or callee_type.is_edge_type() {
            return GraphEffect.WRITES;
        }
        holder = callee_type.shared.symbol_table;
        if not isinstance(holder, Archetype) {
            return self._foreign_call_effect(call, True);
        }
        verdict = GraphEffect.PURE;
        for member in owner_body(holder) {
            if isinstance(member, Ability)
                and isinstance(member.name_ref, Name)
                and member.name_ref.sym_name in ("init", "postinit") {
                found = self.of_owner(member);
                if found == GraphEffect.WRITES {
                    return GraphEffect.WRITES;
                }
                if found == GraphEffect.UNKNOWN {
                    verdict = GraphEffect.UNKNOWN;
                }
            }
        }
        return verdict;
    }
    decl = call.callee_decl;
    sym = call_symbol(call);
    if decl is None {
        decl = ability_of_symbol(sym);
    }
    origin = "";
    if decl is not None {
        origin = str(decl.loc.mod_path);
    } elif sym is not None and sym.defn {
        origin = str(sym.defn[0].loc.mod_path);
    }
    origin = origin.replace("\\", "/");
    if origin.endswith(".jac") and is_compiler_source_path(origin) {
        if sym is not None and sym.sym_name in GRAPH_WRITING_RUNTIME_CALLS {
            return GraphEffect.WRITES;
        }
        return GraphEffect.PURE;
    }
    if origin.endswith(".jac") {
        if decl is None {
            return GraphEffect.UNKNOWN;
        }
        return self.of_owner(decl);
    }
    if not origin {
        receiver = self._foreign_call_effect(call, True);
        return GraphEffect.UNKNOWN if receiver == GraphEffect.PURE else receiver;
    }
    return self._foreign_call_effect(call, origin.endswith("builtins.pyi"));
}

impl GraphEffectScan._foreign_call_effect(call: FuncCall, builtin: bool) -> GraphEffect {
    target = call.target;
    if isinstance(target, AtomTrailer)
        and target.is_attr
        and isinstance(target.right, Name)
        and target.right.sym_name in MUTATING_METHODS {
        found = self._rooted(target.target);
        if found != GraphEffect.PURE {
            return found;
        }
    }
    args: list[Expr] = [];
    for param in call.params or [] {
        if isinstance(param, KWPair) {
            args.append(param.value);
        } elif isinstance(param, Expr) {
            args.append(param);
        }
    }
    if builtin {
        if isinstance(target, Name)
            and target.sym_name in ATTRIBUTE_WRITING_BUILTINS
            and args {
            return self._rooted(args[0]);
        }
        return GraphEffect.PURE;
    }
    for arg in args {
        if self._rooted(arg) != GraphEffect.WRITES {
            continue;
        }
        arg_type = self._type_of(arg);
        if graph_type_effect(arg_type) == GraphEffect.WRITES
            or (
                isinstance(arg_type, ClassType)
                and arg_type.is_builtin(["list", "dict", "set", "bytearray"])
            ) {
            return GraphEffect.UNKNOWN;
        }
    }
    return GraphEffect.PURE;
}

impl GraphEffectScan._spawn_effect(operands: list[Expr]) -> GraphEffect {
    for operand in operands {
        walker_type = self._type_of(operand);
        if isinstance(walker_type, ClassType) and walker_type.is_walker_type() {
            holder = walker_type.shared.symbol_table;
            if not isinstance(holder, Archetype) {
                return GraphEffect.UNKNOWN;
            }
            return self.of_owner(holder);
        }
    }
    return GraphEffect.UNKNOWN;
}

impl GraphEffectScan._delete_effect(stmt: DeleteStmt) -> GraphEffect {
    verdict = GraphEffect.PURE;
    for target in stmt.leaf_targets() {
        if not DeleteStmt.is_location(target) {
            return GraphEffect.WRITES;
        }
        inner = DeleteStmt.unwrap_target(target);
        found = GraphEffect.PURE;
        value_type = self._type_of(inner);
        if DeleteStmt.type_has_graph_member(value_type) {
            found = GraphEffect.WRITES;
        } elif DeleteStmt.type_may_hold_graph(value_type) {
            found = GraphEffect.UNKNOWN;
        }
        if found == GraphEffect.PURE and isinstance(inner, AtomTrailer) {
            found = self._rooted(inner.target);
        }
        if found == GraphEffect.WRITES {
            return GraphEffect.WRITES;
        }
        if found == GraphEffect.UNKNOWN {
            verdict = GraphEffect.UNKNOWN;
        }
    }
    return verdict;
}

impl GraphEffectScan._store_effect(target: Expr) -> GraphEffect {
    if isinstance(target, (TupleVal, ListVal)) {
        verdict = GraphEffect.PURE;
        for item in target.values {
            if not isinstance(item, Expr) {
                continue;
            }
            found = self._store_effect(item);
            if found == GraphEffect.WRITES {
                return GraphEffect.WRITES;
            }
            if found == GraphEffect.UNKNOWN {
                verdict = GraphEffect.UNKNOWN;
            }
        }
        return verdict;
    }
    if isinstance(target, AtomTrailer)
        and (target.is_attr or isinstance(target.right, IndexSlice)) {
        return self._rooted(target.target);
    }
    return GraphEffect.PURE;
}

impl GraphEffectScan._rooted(expr: Expr) -> GraphEffect {
    found = graph_type_effect(self._type_of(expr));
    if found == GraphEffect.WRITES {
        return GraphEffect.WRITES;
    }
    if isinstance(expr, AtomTrailer) {
        base = self._rooted(expr.target);
        return base if base != GraphEffect.PURE else found;
    }
    if not isinstance(expr, Name) or found != GraphEffect.PURE {
        return found;
    }
    sym = expr.sym;
    if sym is None or id(sym) in self._aliasing {
        return GraphEffect.PURE;
    }
    self._aliasing.add(id(sym));
    try {
        for defn in sym.defn {
            bound = defn.parent;
            if isinstance(bound, Assignment)
                and isinstance(bound.value, Expr)
                and not isinstance(bound.value, Name) {
                aliased = self._rooted(bound.value);
                if aliased != GraphEffect.PURE {
                    return aliased;
                }
            }
        }
    } finally {
        self._aliasing.discard(id(sym));
    }
    return GraphEffect.PURE;
}

impl GraphEffectScan._type_of(expr: Expr) -> (TypeBase | None) {
    found = expr.type;
    if found is None and self.evaluator is not None {
        found = self.evaluator.get_type_of_expression(expr);
    }
    return found;
}
