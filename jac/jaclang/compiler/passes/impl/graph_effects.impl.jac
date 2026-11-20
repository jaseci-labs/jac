impl graph_typed(t: (TypeBase | None)) -> bool {
    if t is None or isinstance(t, (AnyType, UnknownType)) {
        return True;
    }
    if isinstance(t, TypeVarType) {
        return t.bound is None or graph_typed(t.bound);
    }
    if isinstance(t, UnionType) {
        return any(graph_typed(member) for member in t.types);
    }
    return isinstance(t, ClassType)
        and (
            t.is_node_type()
            or t.is_edge_type()
            or t.is_any_type()
            or t.is_builtin("object")
        );
}

impl immutable_type(t: (TypeBase | None)) -> bool {
    if isinstance(t, UnionType) {
        return all(immutable_type(member) for member in t.types);
    }
    return isinstance(t, ClassType) and t.is_builtin(IMMUTABLE_TYPES);
}

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
    scan = GraphEffectScan(
        evaluator=program.get_type_evaluator(),
        modules=[
            mod
            for mod in program.mod.hub.values()
            if mod is not None and not is_compiler_source_path(mod.loc.mod_path)
        ]
    );
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
    if not found and isinstance(owner, Archetype) and owner.arch_kind == "walker" {
        found = self._walker_writes(owner);
    }
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
        pending.extend([kid for kid in [nd->:Kid:->] if kid]);
        pending.extend(nd.own_impls);
    }
    return False;
}

impl GraphEffectScan._walker_writes(walker: Archetype) -> bool {
    if any(
        isinstance(mod, CatModule) and str(mod.loc.mod_path).endswith(".jac")
        for mod in self.modules
    ) {
        return True;
    }
    reactions = self._reactions;
    if reactions is None {
        reactions = [];
        for mod in self.modules {
            for arch in mod.get_all_sub_nodes(Archetype) {
                if arch.arch_kind not in ("node", "edge") {
                    continue;
                }
                for ability in arch.get_all_sub_nodes(Ability) {
                    sig = ability.signature;
                    if not isinstance(sig, EventSignature) {
                        continue;
                    }
                    tag = sig.arch_tag_info;
                    names: (set[str] | None) = None;
                    if isinstance(tag, Name) {
                        names = {tag.sym_name};
                    } elif isinstance(tag, BoolExpr)
                        and all(isinstance(val, Name) for val in tag.values) {
                        names = {val.sym_name for val in tag.values};
                    }
                    reactions.append((ability, names));
                }
            }
        }
        self._reactions = reactions;
    }
    for (ability, names) in reactions {
        if (names is None or walker.name.sym_name in names) and self.writes(ability) {
            return True;
        }
    }
    return False;
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
            inner = DeleteStmt.unwrap_target(target);
            if not DeleteStmt.is_location(target)
                or DeleteStmt.type_may_hold_graph(self._type_of(inner))
                or (isinstance(inner, AtomTrailer) and not self._fresh_local(inner.target)) {
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

impl GraphEffectScan._store_writes(target: Expr) -> bool {
    if isinstance(target, (TupleVal, ListVal)) {
        return any(
            self._store_writes(item) for item in target.values if isinstance(item, Expr)
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
    holder: any = None;
    if isinstance(callee, ClassType) and callee.is_instantiable_class() {
        if callee.is_node_type() or callee.is_edge_type() {
            return True;
        }
        holder = callee.shared.symbol_table;
    }
    decl: any = holder if holder is not None else call.callee_decl;
    if not isinstance(decl, (Ability, Archetype)) {
        decl = None;
        named: any = target;
        if isinstance(target, AtomTrailer) {
            named = target.right;
        }
        sym = named.sym if isinstance(named, AstSymbolNode) else None;
        if sym is None or not sym.defn {
            return True;
        }
        origin = str(sym.defn[0].loc.mod_path);
        name = sym.sym_name;
    } else {
        origin = str(decl.loc.mod_path);
        name = decl.sym_name;
    }
    if not origin.endswith(".jac") {
        return self._library_call_writes(call, origin.replace("\\", "/"), name);
    }
    if decl is None or is_compiler_source_path(origin) {
        return True;
    }
    if isinstance(decl, Ability) {
        return self.writes(decl);
    }
    for member in decl._get_impl_resolved_body() {
        if isinstance(member, Ability) {
            if member.sym_name in ("init", "postinit") and self.writes(member) {
                return True;
            }
        } elif self._scan([member]) {
            return True;
        }
    }
    return False;
}

impl GraphEffectScan._library_call_writes(
    call: FuncCall, origin: str, name: str
) -> bool {
    if "/typeshed/" not in origin {
        return True;
    }
    target = call.target;
    if isinstance(target, AtomTrailer)
        and target.is_attr
        and not isinstance(self._type_of(target.target), ModuleType) {
        receiver = target.target;
        return name not in READ_ONLY_METHODS and not self._safe_to_share(receiver);
    }
    if origin.endswith("/builtins.pyi") and name in PURE_BUILTINS {
        return False;
    }
    for param in call.params or [] {
        arg: any = param;
        if isinstance(param, KWPair) {
            arg = param.value;
        }
        if isinstance(arg, Expr) and not self._safe_to_share(arg) {
            return True;
        }
    }
    return False;
}

impl GraphEffectScan._safe_to_share(expr: Expr) -> bool {
    found = self._type_of(expr);
    if immutable_type(found) or isinstance(expr, FRESH_VALUES) or self._fresh_local(expr) {
        return True;
    }
    if graph_typed(found)
        or not isinstance(found, ClassType)
        or found.is_builtin(["list", "dict", "set", "bytearray"]) {
        return False;
    }
    sym = found.get_class_symbol();
    return sym is None
        or not sym.defn
        or not str(sym.defn[0].loc.mod_path).endswith(".jac");
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
        if not isinstance(bound, Assignment) or not any(t is defn for t in bound.target) {
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
