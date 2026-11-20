impl endpoint_effects(module: Module, program: any) -> dict[str, dict[str, any]] {
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
        if arch.arch_kind == "walker" {
            endpoints.append(("walker", arch.name.sym_name, arch));
        }
    }
    scan = GraphEffectScan(evaluator=program.get_type_evaluator());
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
    roots: list[UniNode] = [];
    if isinstance(owner, Archetype) {
        roots = list(owner._get_impl_resolved_body());
    } elif isinstance(owner, Ability) and isinstance(owner.body, list) {
        roots = list(owner.body);
    } elif isinstance(owner, Ability)
        and isinstance(owner.body, ImplDef)
        and isinstance(owner.body.body, list) {
        roots = list(owner.body.body);
    } else {
        return True;
    }
    self._active.add(key);
    found = self._scan(roots);
    self._active.discard(key);
    if not self._active {
        self._memo[key] = found;
    }
    return found;
}

impl GraphEffectScan._scan(roots: list[UniNode]) -> bool {
    pending: list[UniNode] = list(roots);
    while pending {
        nd = pending.pop();
        if self._node_writes(nd) {
            return True;
        }
        pending.extend(
            [
                kid
                for kid in [nd->:Kid:->]
                if kid
            ]
        );
        pending.extend(nd.own_impls);
    }
    return False;
}

impl GraphEffectScan._node_writes(nd: UniNode) -> bool {
    if isinstance(nd, VisitStmt) {
        return True;
    }
    if isinstance(nd, BinaryExpr) {
        return isinstance(nd.op, (ConnectOp, DisconnectOp))
            or (isinstance(nd.op, Token) and nd.op.name == Tok.KW_SPAWN);
    }
    if isinstance(nd, UnaryExpr) {
        return nd.op.name == Tok.KW_SPAWN;
    }
    if isinstance(nd, DeleteStmt) {
        for target in nd.leaf_targets() {
            inner = DeleteStmt.unwrap_target(target);
            if not DeleteStmt.is_location(target)
                or DeleteStmt.type_may_hold_graph(self._type_of(inner))
                or (
                    isinstance(inner, AtomTrailer)
                    and not self._fresh_local(inner.target)
                ) {
                return True;
            }
        }
        return False;
    }
    if isinstance(nd, Assignment) {
        return any(self._store_writes(target) for target in nd.target);
    }
    if isinstance(nd, FuncCall) {
        return self._call_writes(nd);
    }
    return False;
}

impl GraphEffectScan._store_writes(target: Expr) -> bool {
    if isinstance(target, (TupleVal, ListVal)) {
        return any(
            self._store_writes(item)
            for item in target.values
            if isinstance(item, Expr)
        );
    }
    if not isinstance(target, AtomTrailer) {
        return False;
    }
    base = target.target;
    if target.is_attr and isinstance(base, Name) and base.sym_name == "self" {
        owner = self._type_of(base);
        if isinstance(owner, ClassType) and owner.is_walker_type() {
            return False;
        }
    }
    return not self._fresh_local(base);
}

impl GraphEffectScan._call_writes(call: FuncCall) -> bool {
    target = call.target;
    callee = self._type_of(target);
    if isinstance(callee, ClassType) and callee.is_instantiable_class() {
        if callee.is_node_type() or callee.is_edge_type() {
            return True;
        }
        holder = callee.shared.symbol_table;
        if not isinstance(holder, Archetype)
            or not str(holder.loc.mod_path).endswith(".jac") {
            return not callee.is_builtin();
        }
        key = id(holder);
        if is_compiler_source_path(str(holder.loc.mod_path)) or key in self._active {
            return key not in self._active;
        }
        self._active.add(key);
        found = False;
        for member in holder._get_impl_resolved_body() {
            if isinstance(member, Ability) {
                found = member.sym_name in ("init", "__init__", "postinit", "__post_init__") and self.writes(member);
            } else {
                found = self._scan([member]);
            }
            if found {
                break;
            }
        }
        self._active.discard(key);
        return found;
    }
    decl = call.callee_decl;
    if decl is not None and str(decl.loc.mod_path).endswith(".jac") {
        return is_compiler_source_path(str(decl.loc.mod_path)) or self.writes(decl);
    }
    named: any = target;
    if isinstance(target, AtomTrailer) {
        named = target.right;
    }
    if not isinstance(named, AstSymbolNode)
        or named.sym is None
        or not named.sym.defn {
        return True;
    }
    origin = str(named.sym.defn[0].loc.mod_path).replace("\\", "/");
    if not origin.endswith("/builtins.pyi") {
        return True;
    }
    name = named.sym.sym_name;
    if not isinstance(target, AtomTrailer) {
        return name not in PURE_BUILTINS;
    }
    receiver_type = self._type_of(target.target);
    return name not in READ_ONLY_METHODS
        and not (
            isinstance(receiver_type, ClassType)
            and receiver_type.is_builtin(
                ["str", "int", "float", "bool", "bytes", "tuple"]
            )
        )
        and not self._fresh_local(target.target);
}

impl GraphEffectScan._fresh_local(expr: Expr) -> bool {
    if not isinstance(expr, Name) {
        return False;
    }
    sym = expr.sym;
    if sym is None or not sym.defn {
        return False;
    }
    for defn in sym.defn {
        bound = defn.parent;
        if not isinstance(bound, Assignment)
            or not any(t is defn for t in bound.target) {
            return False;
        }
        value = bound.value;
        if isinstance(value, FRESH_VALUES) {
            continue;
        }
        made: any = None;
        if isinstance(value, FuncCall) {
            made = self._type_of(value.target);
        }
        if not isinstance(made, ClassType)
            or not made.is_instantiable_class()
            or made.is_node_type()
            or made.is_edge_type() {
            return False;
        }
    }
    return True;
}

impl GraphEffectScan._type_of(expr: Expr) -> (TypeBase | None) {
    found = expr.type;
    if found is None and self.evaluator is not None {
        found = self.evaluator.get_type_of_expression(expr);
    }
    return found;
}
