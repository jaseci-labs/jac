impl RcFactsPass._run_impl(ir_in: Module) -> Module {
    self._stamp_param_rebound(ir_in);
    self._stamp_move_lowerable(ir_in);
    self._stamp_escapes(ir_in);
    self._stamp_region_handles(ir_in);
    self._stamp_last_use(ir_in);
    self._stamp_scope_cleanup(ir_in);
    self._stamp_move_in(ir_in);
    return ir_in;
}

impl RcFactsPass._enclosing_fn_scope(
    nd: UniNode, stop_at_comprehension: bool = False
) -> UniNode | None {
    cur = nd.decl_parent;
    while cur is not None and not isinstance(cur, Module) {
        if is_frame(cur) {
            return cur;
        }
        if stop_at_comprehension and isinstance(cur, (ListCompr, DictCompr)) {
            return cur;
        }
        cur = cur.decl_parent;
    }
    return None;
}

impl RcFactsPass._is_param_sym(sym: Symbol) -> bool {
    for d in sym.defn {
        if d.find_parent_of_type(ParamVar) is not None {
            return True;
        }
    }
    return False;
}

impl RcFactsPass._use_ok_for_stack(nm: NameAtom) -> bool {
    p = nm.parent;
    if isinstance(p, AtomTrailer) and p.target is nm {
        return True;
    }
    if isinstance(p, (BinaryExpr, CompareExpr, UnaryExpr, BoolExpr, IfElseExpr)) {
        return True;
    }
    if isinstance(p, Assignment) {
        targets = p.target if isinstance(p.target, (list, tuple)) else [(p.target)];
        for t in targets {
            if t is nm {
                return True;
            }
        }
        return False;
    }
    if isinstance(p, (IfStmt, WhileStmt)) {
        return True;
    }
    return False;
}

impl RcFactsPass._stamp_escapes(ir_in: Module) -> None {
    seen: set[int] = set();
    for nm in ir_in.get_all_sub_nodes(Name) {
        sym = nm.sym;
        if sym is None or id(sym) in seen {
            continue;
        }
        if sym.storage != SymbolStorage.LOCAL or self._is_param_sym(sym) {
            sym.na_escapes = True;
            sym.na_stack_ok = False;
            seen.add(id(sym));
            continue;
        }
        seen.add(id(sym));
        escapes = False;
        stack_ok = True;
        _def_scope = self._enclosing_fn_scope(sym.defn[0]) if sym.defn else None;
        for u in (list(sym.defn) + list(sym.uses)) {
            if u.find_parent_of_type(ReturnStmt) is not None {
                if self._scalar_attr_read(u) {
                    continue;
                }
                escapes = True;
                stack_ok = False;
                break;
            }
            if self._enclosing_fn_scope(u) is not _def_scope {
                escapes = True;
                stack_ok = False;
                break;
            }

            if u.find_parent_of_type(FuncCall) is not None
                and not self._call_use_stack_safe(u, sym) {
                escapes = True;
                stack_ok = False;
                break;
            }
            if stack_ok and not self._use_ok_for_stack(u) {
                stack_ok = False;
            }
        }
        sym.na_escapes = escapes;
        sym.na_stack_ok = stack_ok and not escapes;
    }
}

impl RcFactsPass._call_use_stack_safe(nm: NameAtom, sym: Symbol) -> bool {
    p = nm.parent;
    if isinstance(p, AtomTrailer) and p.target is nm {
        gp = p.parent;
        if isinstance(gp, FuncCall) and gp.target is p {
            return False;
        }
        return self._scalar_attr_read(nm);
    }
    if sym.ownership != OwnershipKind.OWN {
        return False;
    }
    if isinstance(p, UnaryExpr) and is_borrow_kind(p.ownership) {
        return self._borrow_arg_callee_ok(p);
    }
    return False;
}

impl RcFactsPass._scalar_attr_read(nm: NameAtom) -> bool {
    p = nm.parent;
    if not (isinstance(p, AtomTrailer) and p.target is nm and p.is_attr) {
        return False;
    }
    ty = p?.type;
    if ty is None {
        return False;
    }
    try {
        m = str(ty.mangle());
    } except Exception {
        return False;
    }
    return m in ("int", "float", "bool");
}

impl RcFactsPass._borrow_arg_callee_ok(bx: UnaryExpr) -> bool {
    call = bx.parent if isinstance(bx.parent, FuncCall) else None;
    if call is None or call.callee_decl is None {
        return False;
    }
    sig = call.callee_decl.signature;
    if sig is None or not isinstance(sig, FuncSignature) {
        return False;
    }
    idx = -1;
    for (i, a) in enumerate(call.params or []) {
        if isinstance(a, KWPair) {
            return False;
        }
        if a is bx {
            idx = i;
        }
    }
    params = sig.get_parameters();
    if idx < 0 or idx >= len(params) {
        return False;
    }
    ptag = params[idx].type_tag;
    if ptag is None or not is_borrow_kind(ptag.ownership) {
        return False;
    }
    ret = sig.return_type;
    if ret is None {
        return True;
    }
    return isinstance(ret, Name) and ret.value in ("int", "float", "bool", "None");
}

impl RcFactsPass._asn_makes_region_handle(nd: Assignment) -> bool {
    if isinstance(nd.value, FuncCall) and expr_is_builtin_region(nd.value) {
        return True;
    }
    if nd.type_tag is not None {
        for tgt in nd.target {
            if isinstance(tgt, Name)
                and tgt.sym is not None
                and tgt.sym.ownership == OwnershipKind.OWN
                and expr_is_builtin_region(tgt) {
                return True;
            }
        }
    }
    if isinstance(nd.value, Name)
        and nd.value.sym is not None
        and nd.value.sym.na_region_handle {
        return True;
    }
    if isinstance(nd.value, UnaryExpr)
        and nd.value.ownership == OwnershipKind.IMM
        and isinstance(nd.value.operand, Name)
        and nd.value.operand.sym is not None
        and nd.value.operand.sym.na_region_handle {
        return True;
    }
    return False;
}

impl RcFactsPass._stamp_region_handles(ir_in: Module) -> None {
    _changed = True;
    while _changed {
        _changed = False;
        for asn in ir_in.get_all_sub_nodes(Assignment) {
            if len(asn.target) != 1 or not isinstance(asn.target[0], Name) {
                continue;
            }
            _tgt = asn.target[0];
            if _tgt.sym is None or _tgt.sym.na_region_handle {
                continue;
            }
            if self._asn_makes_region_handle(asn) {
                _tgt.sym.na_region_handle = True;
                _changed = True;
            }
        }
    }
}

impl RcFactsPass._stamp_last_use(ir_in: Module) -> None {
    out: dict[int, list[str]] = {};
    for ab in ir_in.get_all_sub_nodes(Ability) {
        stmts = ModuleFacts.unwrap_body(ab);
        if isinstance(ab.signature, FuncSignature) and stmts is not None {
            self._collect_last_use(ab, stmts, out);
        }
    }
    for mc in ir_in.get_all_sub_nodes(ModuleCode) {
        if isinstance(mc.body, (list, tuple)) {
            self._collect_last_use(mc, mc.body, out);
        }
    }
    ir_in.rc_last_use = out;
}

impl RcFactsPass._collect_last_use(
    owner: UniNode, body: Sequence[UniNode], out: dict[int, list[str]]
) -> None {
    sym_last: dict[int, tuple[int, str]] = {};
    for (idx, stmt) in enumerate(body) {
        for nm in stmt.get_all_sub_nodes(Name) {
            sym = nm.sym;
            if sym is None
                or sym.na_escapes
                or (nm.sym_name == "self" and sym.ownership != OwnershipKind.OWN)
                or not self._last_use_tracked(sym) {
                continue;
            }
            if self._enclosing_fn_scope(nm) is not owner {
                continue;
            }
            decl = sym.decl;
            if decl is None
                or self._enclosing_fn_scope(decl, stop_at_comprehension=True)
                    is not owner {
                continue;
            }
            sym_last[id(sym)] = (idx, nm.sym_name);
        }
    }
    for `entry in sym_last.values() {
        _idx: int = `entry[0];
        _name: str = `entry[1];
        key = id(body[_idx]);
        if key not in out {
            out[key] = [];
        }
        if _name not in out[key] {
            out[key].append(_name);
        }
    }
}

impl RcFactsPass._last_use_tracked(sym: Symbol) -> bool {
    if sym.storage == SymbolStorage.LOCAL {
        return not self._is_param_sym(sym);
    }
    return sym.storage == SymbolStorage.PARAM and sym.ownership == OwnershipKind.OWN;
}

impl RcFactsPass._stamp_move_in(ir_in: Module) -> None {
    out: set[int] = set();
    seen: set[int] = set();
    for nm in ir_in.get_all_sub_nodes(Name) {
        sym = nm.sym;
        if sym is None {
            continue;
        }
        if id(sym) in seen {
            continue;
        }
        if sym.storage != SymbolStorage.LOCAL or self._is_param_sym(sym) {
            continue;
        }
        seen.add(id(sym));
        _use_map: dict[int, NameAtom] = {};
        for u in sym.uses {
            if not self._is_def_name(u) {
                _use_map[id(u)] = u;
            }
        }
        uses = list(_use_map.values());
        if len(uses) != 1 {
            continue;
        }
        use = uses[0];
        if use.find_parent_of_type(WhileStmt) is not None
            or use.find_parent_of_type(InForStmt) is not None
            or use.find_parent_of_type(IterForStmt) is not None
            or self._repeats_in_comprehension(use) {
            continue;
        }
        if sym.defn
            and self._enclosing_fn_scope(sym.defn[0])
                is not self._enclosing_fn_scope(use) {
            continue;
        }
        out.add(id(use));
    }
    ir_in.rc_move_in = out;
}

impl RcFactsPass._repeats_in_comprehension(use: NameAtom) -> bool {
    came_from: UniNode = use;
    cur = use.parent;
    while cur is not None {
        if isinstance(cur, (ListCompr, DictCompr)) {
            once = cur.compr[0].collection if cur.compr else None;
            if once is None or came_from is not cur.compr[0] {
                return True;
            }
            inner: UniNode = use;
            in_once = False;
            while inner is not cur {
                if inner is once {
                    in_once = True;
                    break;
                }
                if inner.parent is None {
                    break;
                }
                inner = inner.parent;
            }
            if not in_once {
                return True;
            }
        }
        came_from = cur;
        cur = cur.parent;
    }
    return False;
}

impl RcFactsPass._stamp_param_rebound(ir_in: Module) -> None {
    bound: set[tuple[int, str]] = set();
    for nm in ir_in.get_all_sub_nodes(Name) {
        if self._binds_local_name(nm) {
            bound.add((id(self._enclosing_fn_scope(nm)), nm.sym_name));
        }
    }
    for pv in ir_in.get_all_sub_nodes(ParamVar) {
        sym = pv.name.sym if pv.name else None;
        if sym is None {
            continue;
        }
        owner = self._enclosing_fn_scope(pv);
        sym.param_rebound = (id(owner), sym.sym_name) in bound;
    }
}

impl RcFactsPass._binds_local_name(nm: Name) -> bool {
    parent = nm.parent;
    if isinstance(parent, ParamVar)
        or (isinstance(parent, AtomTrailer) and parent.right is nm) {
        return False;
    }
    if isinstance(parent, BinaryExpr)
        and parent.left is nm
        and isinstance(parent.op, Token)
        and parent.op.name == Tok.WALRUS_EQ {
        return True;
    }
    return nm.expr_ctx == ExprCtx.STORE;
}

impl RcFactsPass._stamp_move_lowerable(ir_in: Module) -> None {
    cfg_nodes = [
        n
        for n in ir_in.flatten()
        if isinstance(n, UniCFGNode)
    ];
    all_names = ir_in.get_all_sub_nodes(Name);

    uses_by_sym: dict[SymId, list[Name]] = {};
    for nm in all_names {
        if nm.sym is None {
            continue;
        }
        if self._is_def_name(nm) {
            continue;
        }
        sid = id(nm.sym);
        if sid in uses_by_sym {
            uses_by_sym[sid].append(nm);
        } else {
            uses_by_sym[sid] = [nm];
        }
    }

    candidates: list[tuple[Assignment, SymId]] = [];
    tracked: set[SymId] = set();
    for nd in ir_in.get_all_sub_nodes(Assignment) {
        nd.na_move_lowerable = False;
        src = self._move_candidate_source(nd);
        if src is None {
            continue;
        }
        sid = id(src.sym);
        candidates.append((nd, sid));
        tracked.add(sid);
    }
    if not candidates {
        return;
    }

    sites_by_sym: dict[SymId, list[Assignment]] = {};
    for (nd, sid) in candidates {
        if sid in sites_by_sym {
            sites_by_sym[sid].append(nd);
        } else {
            sites_by_sym[sid] = [nd];
        }
    }
    import os;
    flow_moves = not os.environ.get("JAC_NO_MOVE_FLOW");
    qualified: set[SymId] = set();
    for sid in tracked {
        ok = True;
        for u in uses_by_sym.get(sid, []) {
            if not self._is_alias_value(u) {
                ok = False;
                break;
            }
        }
        if ok
            or (
                flow_moves
                and self._move_flow_safe(
                    uses_by_sym.get(sid, []), sites_by_sym.get(sid, [])
                )
            ) {
            qualified.add(sid);
        }
    }

    live_in = self._solve_liveness(cfg_nodes, qualified);
    for (nd, sid) in candidates {
        if sid not in qualified {
            continue;
        }
        live_out: set[SymId] = set();
        for succ in nd.bb_out {
            for x in live_in.get(id(succ), set()) {
                live_out.add(x);
            }
        }
        if sid not in live_out {
            nd.na_move_lowerable = True;
        }
    }
}

impl RcFactsPass._move_flow_safe(uses: list[Name], sites: list[Assignment]) -> bool {
    """Can liveness alone decide which copies of this local are its last use?

    A copy after which no path reads the local moves its reference: the copy
    is released no earlier than the local would have been, so the object
    lives exactly as long and whatever else holds it (a callee, a field) is
    unaffected. What liveness cannot see leaves the local to the alias-only
    rule: the statement graph has no edge from inside a `try` to its
    handlers, so a handler may read a local that looks dead; a lambda, a
    comprehension, a `flow` or a parallel loop reads it in a scope or at a
    time of its own; and a borrow (`&local`) refers to the local's slot.
    """;
    if not sites {
        return False;
    }
    owner = self._enclosing_fn_scope(sites[0]);
    nodes: list[UniNode] = [];
    for u in uses {
        nodes.append(u);
    }
    for nd in sites {
        nodes.append(nd);
    }
    for nd in nodes {
        if self._enclosing_fn_scope(nd) is not owner {
            return False;
        }
        if isinstance(nd.parent, UnaryExpr) and is_borrow_kind(nd.parent.ownership) {
            return False;
        }
        cur = nd.parent;
        while cur is not None and cur is not owner {
            if type(cur).__name__
                in (
                    "TryStmt",
                    "LambdaExpr",
                    "ListCompr",
                    "DictCompr",
                    "SetCompr",
                    "GenCompr",
                    "ConcurrentExpr"
                )
                or getattr(cur, "is_async", False) {
                return False;
            }
            cur = cur.parent;
        }
    }
    return True;
}

impl RcFactsPass._cfg_owner(sub: UniNode) -> (UniCFGNode | None) {
    if isinstance(sub, UniCFGNode) {
        return sub;
    }
    return sub.find_parent_of_type(UniCFGNode);
}

impl RcFactsPass._is_def_name(nm: NameAtom) -> bool {
    p = nm.parent;
    if isinstance(p, Assignment) and p.aug_op is None {
        for tgt in p.target {
            if tgt is nm {
                return True;
            }
        }
    }
    return False;
}

impl RcFactsPass._is_alias_value(nm: Name) -> bool {
    p = nm.parent;
    if not isinstance(p, Assignment) {
        return False;
    }
    if p.value is not nm or p.aug_op is not None or len(p.target) != 1 {
        return False;
    }
    tgt = p.target[0];
    if not (isinstance(tgt, Name) and tgt.sym is not None) {
        return False;
    }
    if tgt.sym.storage != SymbolStorage.LOCAL {
        return False;
    }
    if p.type_tag is not None
        and (
            is_borrow_kind(p.type_tag.ownership)
            or p.type_tag.ownership == OwnershipKind.IMM
        ) {
        return False;
    }
    return True;
}

impl RcFactsPass._move_candidate_source(nd: Assignment) -> (Name | None) {
    if nd.aug_op is not None or len(nd.target) != 1 {
        return None;
    }
    tgt = nd.target[0];
    if not (isinstance(tgt, Name) and tgt.sym is not None) {
        return None;
    }
    if tgt.sym.storage != SymbolStorage.LOCAL {
        return None;
    }
    if nd.type_tag is not None
        and nd.type_tag.ownership != OwnershipKind.NONE
        and nd.type_tag.ownership != OwnershipKind.OWN {
        return None;
    }
    val = nd.value;
    if not (isinstance(val, Name) and val.sym is not None) {
        return None;
    }
    if val.sym.storage != SymbolStorage.LOCAL {
        return None;
    }
    return val;
}

impl RcFactsPass._solve_liveness(
    cfg_nodes: list[UniCFGNode], tracked: set[SymId]
) -> dict[int, set[SymId]] {
    self._node_use = {};
    self._node_def = {};
    for n in cfg_nodes {
        use: set[SymId] = set();
        dfn: set[SymId] = set();
        for nm in n.get_all_sub_nodes(Name) {
            if self._cfg_owner(nm) is not n or nm.sym is None {
                continue;
            }
            sid = id(nm.sym);
            if sid not in tracked {
                continue;
            }
            if self._is_def_name(nm) {
                dfn.add(sid);
            } else {
                use.add(sid);
            }
        }
        self._node_use[id(n)] = use;
        self._node_def[id(n)] = dfn;
    }
    return solve_backward_gen_kill(cfg_nodes, self._node_use, self._node_def);
}

impl RcFactsPass.run_walk with Module entry {
    self.module = self._run_impl(here);
}

impl RcFactsPass._stamp_scope_cleanup(ir_in: Module) -> None {
    out: dict[int, list[str]] = {};
    for ability in ir_in.get_all_sub_nodes(Ability) {
        names: list[str] = [];
        borrows: list[str] = [];
        seen: set[int] = set();
        for nm in ability.element_sub_nodes(Name) {
            sym = nm.sym;
            if sym is None
                or id(sym) in seen
                or sym.storage not in (SymbolStorage.LOCAL, SymbolStorage.PARAM)
                or nm.enclosing_decl(Ability) is not ability {
                continue;
            }
            seen.add(id(sym));
            if is_borrow_kind(sym.ownership) {
                borrows.append(nm.sym_name);
                continue;
            }
            owns = sym.ownership == OwnershipKind.OWN;
            if not owns and sym.defn {
                decl = sym.defn[0].parent;
                if isinstance(decl, (Assignment, ParamVar))
                    and decl.type_tag is not None {
                    owns = any(
                        [
                            isinstance(un, UnaryExpr)
                                and un.ownership == OwnershipKind.OWN
                            for un in decl.type_tag.get_all_sub_nodes(UnaryExpr)
                        ]
                    );
                }
            }
            if owns {
                names.append(nm.sym_name);
            }
        }
        if names or borrows {
            out[id(ability)] = list(reversed(borrows)) + list(reversed(names));
        }
    }
    ir_in.rc_scope_cleanup = out;
}

impl method_returns_borrow(callee: (Ability | None)) -> bool {
    if not isinstance(callee, Ability)
        or not callee.is_method
        or callee.is_static
        or not isinstance(callee.signature, FuncSignature) {
        return False;
    }
    if type_tag_borrows(callee.signature.return_type) {
        return True;
    }
    _found = False;
    for _ret in callee.element_sub_nodes(ReturnStmt) {
        if _ret.enclosing_frame is not callee {
            continue;
        }
        if not (isinstance(_ret.expr, Name) and _ret.expr.value == "self") {
            return False;
        }
        _found = True;
    }
    return _found;
}

impl call_borrows_receiver(call: FuncCall) -> bool {
    if not isinstance(call.target, AtomTrailer) or not call.target.is_attr {
        return False;
    }
    _recv: (UniNode | None) = call.target.target;
    while isinstance(_recv, AtomTrailer) {
        _recv = _recv.target;
    }
    if not isinstance(_recv, Name) {
        return False;
    }
    return method_returns_borrow(call.callee_decl);
}

impl result_ownership(expr: (Expr | None)) -> Ownership {
    if expr is None {
        return Ownership.UNKNOWN;
    }
    if isinstance(expr, FuncCall) {
        import from jaclang.compiler.erased_imports { erased_identity_call_arg }
        erased_to = erased_identity_call_arg(expr);
        if erased_to is not None {
            return result_ownership(erased_to);
        }
        return Ownership.OWNED;
    }
    if isinstance(expr, BinaryExpr)
        and isinstance(expr.op, ConnectOp)
        and expr.op.capture_edges {
        return Ownership.OWNED;
    }
    if isinstance(expr, (ListVal, SetVal, DictVal, ListCompr, DictCompr)) {
        return Ownership.OWNED;
    }
    if isinstance(expr, FString) {
        return Ownership.OWNED;
    }
    if isinstance(expr, MultiString) {
        if len(expr.strings) == 1 and not isinstance(expr.strings[0], FString) {
            return Ownership.STATIC;
        }
        return Ownership.OWNED;
    }
    if isinstance(expr, String) {
        return Ownership.STATIC;
    }
    if isinstance(expr, AtomTrailer) {
        import from jaclang.compiler.c_interop { foreign_read_copies }
        if foreign_read_copies(expr) {
            return Ownership.OWNED;
        }
    }
    if isinstance(expr, (Name, AtomTrailer)) {
        return Ownership.BORROWED;
    }
    return Ownership.UNKNOWN;
}

impl loop_body_locals(body: (Sequence[UniNode] | None)) -> list[str] {
    out: list[str] = [];
    seen: set[str] = set();
    if not body {
        return out;
    }
    body_names: list[Name] = [];
    for stmt in body {
        body_names.extend(stmt.get_all_sub_nodes(typ=Name));
    }
    body_ids = {id(nm) for nm in body_names};
    for nm in body_names {
        sym = nm.sym;
        if sym is None or not sym.defn {
            continue;
        }
        if sym.defn[0] is nm and nm.sym_name not in seen {
            seen.add(nm.sym_name);

            if any(id(use) not in body_ids for use in sym.uses) {
                continue;
            }
            out.append(nm.sym_name);
        }
    }
    return out;
}
