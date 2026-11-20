impl graph_typed(t: (TypeBase | None)) -> bool {
    if t is None or isinstance(t, (AnyType, UnknownType)) {
        return True;
    }
    if isinstance(t, UnionType) {
        return any(graph_typed(member) for member in t.types);
    }
    return isinstance(t, ClassType) and (t.is_node_type() or t.is_edge_type());
}

impl endpoint_effects(module: Module, evaluator: any) -> dict[str, dict[str, any]] {
    endpoints: list[tuple[str, str, UniNode]] = [];
    for ability in module.get_all_sub_nodes(Ability) {
        if not ability.is_method
            and not ability.in_client_context()
            and ability.access is not None
            and ability.access.tag.name == Tok.KW_PUB
            and isinstance(ability.name_ref, Name) {
            endpoints.append(("func", ability.name_ref.sym_name, ability));
        }
    }
    for arch in module.get_all_sub_nodes(Archetype) {
        if arch.arch_kind == "walker" and isinstance(arch.name, Name) {
            endpoints.append(("walker", arch.name.sym_name, arch));
        }
    }
    scan = GraphEffectScan(evaluator=evaluator);
    out: dict[str, dict[str, any]] = {};
    for (kind, name, owner) in endpoints {
        record: dict[str, any] = dict(endpoint_descriptor(module, kind, name));
        record["reads"] = ["*"];
        record["writes"] = ["*"] if scan.writes(owner) else [];
        record["unknown"] = False;
        out[endpoint_key(module, kind, name)] = record;
    }
    return out;
}

impl GraphEffectScan.writes(owner: UniNode) -> bool {
    key = id(owner);
    if key in self._memo {
        return self._memo[key];
    }
    if key in self._active {
        return False;
    }
    pending: list[UniNode] = [];
    if isinstance(owner, Archetype) {
        pending = list(owner._get_impl_resolved_body());
    } elif isinstance(owner, Ability) and isinstance(owner.body, list) {
        pending = list(owner.body);
    } elif isinstance(owner, Ability)
        and isinstance(owner.body, ImplDef)
        and isinstance(owner.body.body, list) {
        pending = list(owner.body.body);
    } else {
        return True;
    }
    self._active.add(key);
    found = False;
    while pending and not found {
        nd = pending.pop();
        found = self._node_writes(nd);
        pending.extend([kid for kid in [nd->:Kid:->] if kid]);
        pending.extend(nd.own_impls);
    }
    self._active.discard(key);
    if not self._active {
        self._memo[key] = found;
    }
    return found;
}

impl GraphEffectScan._node_writes(nd: UniNode) -> bool {
    if isinstance(nd, BinaryExpr) {
        if isinstance(nd.op, (ConnectOp, DisconnectOp)) {
            return True;
        }
        return isinstance(nd.op, Token)
            and nd.op.name == Tok.KW_SPAWN
            and self._spawn_writes([nd.left, nd.right]);
    }
    if isinstance(nd, UnaryExpr) and nd.op.name == Tok.KW_SPAWN {
        return self._spawn_writes([nd.operand]);
    }
    if isinstance(nd, DeleteStmt) {
        for target in nd.leaf_targets() {
            if not DeleteStmt.is_location(target)
                or DeleteStmt.target_may_hold_graph(target)
                or (isinstance(target, AtomTrailer) and self._in_graph(target.target)) {
                return True;
            }
        }
        return False;
    }
    if isinstance(nd, Assignment) {
        for target in nd.target {
            if isinstance(target, AtomTrailer) and self._in_graph(target.target) {
                return True;
            }
        }
        return False;
    }
    if isinstance(nd, FuncCall) {
        return self._call_writes(nd);
    }
    return False;
}

impl GraphEffectScan._call_writes(call: FuncCall) -> bool {
    target = call.target;
    if isinstance(target, AtomTrailer)
        and target.is_attr
        and isinstance(target.right, Name)
        and target.right.sym_name in MUTATING_METHODS
        and self._in_graph(target.target) {
        return True;
    }
    callee = self._type_of(target);
    if isinstance(callee, ClassType) and callee.is_instantiable_class() {
        return callee.is_node_type() or callee.is_edge_type();
    }
    decl = call.callee_decl;
    if decl is None {
        if callee is None or isinstance(callee, (AnyType, UnknownType)) {
            return True;
        }
        if not isinstance(target, Name) or target.sym is None {
            return False;
        }
        defns = target.sym.defn;
        return bool(defns) and str(defns[0].loc.mod_path).endswith(".jac");
    }
    origin = str(decl.loc.mod_path);
    if not origin.endswith(".jac") {
        return False;
    }
    if is_compiler_source_path(origin) {
        return isinstance(decl.name_ref, Name)
            and decl.name_ref.sym_name in GRAPH_WRITING_RUNTIME_CALLS;
    }
    return self.writes(decl);
}

impl GraphEffectScan._spawn_writes(operands: list[Expr]) -> bool {
    for operand in operands {
        walker = self._type_of(operand);
        if isinstance(walker, ClassType) and walker.is_walker_type() {
            holder = walker.shared.symbol_table;
            if isinstance(holder, Archetype) {
                return self.writes(holder);
            }
        }
    }
    return True;
}

impl GraphEffectScan._in_graph(expr: Expr) -> bool {
    if graph_typed(self._type_of(expr)) {
        return True;
    }
    if isinstance(expr, AtomTrailer) {
        return self._in_graph(expr.target);
    }
    if not isinstance(expr, Name) {
        return False;
    }
    sym = expr.sym;
    if sym is None or id(sym) in self._aliasing {
        return False;
    }
    self._aliasing.add(id(sym));
    aliased = False;
    for defn in sym.defn {
        bound = defn.parent;
        if isinstance(bound, Assignment)
            and isinstance(bound.value, AtomTrailer)
            and self._in_graph(bound.value) {
            aliased = True;
        }
    }
    self._aliasing.discard(id(sym));
    return aliased;
}

impl GraphEffectScan._type_of(expr: Expr) -> (TypeBase | None) {
    found = expr.type;
    if found is None and self.evaluator is not None {
        found = self.evaluator.get_type_of_expression(expr);
    }
    return found;
}
