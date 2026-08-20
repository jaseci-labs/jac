impl RcFactsPass.postinit -> None {
    super.postinit();
}

impl RcFactsPass.transform(ir_in: Module) -> Module {
    self._stamp_param_rebound(ir_in);
    self._stamp_move_lowerable(ir_in);
    self._stamp_escapes(ir_in);
    self._stamp_region_handles(ir_in);
    self._stamp_last_use(ir_in);
    self._stamp_move_in(ir_in);
    self._stamp_anon_regions(ir_in);
    return ir_in;
}

impl RcFactsPass._enclosing_fn_scope(nd: UniNode) -> (UniNode | None) {
    cur = nd.parent;
    while cur is not None {
        if isinstance(cur, (Ability, LambdaExpr, Test, ModuleCode)) {
            return cur;
        }
        cur = cur.parent;
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
    import from jaclang.compiler.expr_keys { is_builtin_region_name }
    if isinstance(nd.value, FuncCall) and is_builtin_region_name(nd.value.target) {
        return True;
    }
    if nd.type_tag is not None {
        _tt_expr = nd.type_tag.tag;
        while isinstance(_tt_expr, AtomTrailer) {
            _tt_expr = _tt_expr.target;
        }
        if is_builtin_region_name(_tt_expr) {
            return True;
        }
    }
    if (
        isinstance(nd.value, FuncCall)
        and isinstance(nd.value.target, Name)
        and nd.value.target.sym is not None
        and nd.value.target.sym.decl is not None
    ) {
        _cal_ab = nd.value.target.sym.decl.find_parent_of_type(Ability);
        if _cal_ab is not None
            and isinstance(_cal_ab.signature, FuncSignature)
            and _cal_ab.signature.return_type is not None {
            _rt_expr = _cal_ab.signature.return_type;
            while isinstance(_rt_expr, AtomTrailer) {
                _rt_expr = _rt_expr.target;
            }
            if is_builtin_region_name(_rt_expr) {
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
        if isinstance(ab.signature, FuncSignature)
            and isinstance(ab.body, (list, tuple)) {
            self._collect_last_use(ab, ab.body, out);
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
                or sym.storage != SymbolStorage.LOCAL
                or sym.na_escapes
                or self._is_param_sym(sym)
                or nm.sym_name == "self" {
                continue;
            }
            if self._enclosing_fn_scope(nm) is not owner {
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
        if sym.storage != SymbolStorage.LOCAL
            or self._is_param_sym(sym)
            or nm.sym_name == "self" {
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
            or use.find_parent_of_type(IterForStmt) is not None {
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

impl RcFactsPass._stamp_anon_regions(ir_in: Module) -> None {
    open_map: dict[int, int] = {};
    close_map: dict[int, int] = {};
    locals_map: dict[int, list[str]] = {};
    gidx = 0;
    blocks: list[Sequence[UniNode]] = [];
    for ab in ir_in.get_all_sub_nodes(Ability) {
        if isinstance(ab.signature, FuncSignature)
            and isinstance(ab.body, (list, tuple)) {
            blocks.append(ab.body);
        }
    }
    for mc in ir_in.get_all_sub_nodes(ModuleCode) {
        if isinstance(mc.body, (list, tuple)) {
            blocks.append(mc.body);
        }
    }
    for body in blocks {
        for grp in self._scan_anon_region_block(body) {
            (o, c, names) = grp;
            open_map[id(body[o])] = gidx;
            close_map[id(body[c])] = gidx;
            locals_map[gidx] = names;
            gidx += 1;
        }
    }
    ir_in.anon_region_open = open_map;
    ir_in.anon_region_close = close_map;
    ir_in.anon_region_locals = locals_map;
}

impl RcFactsPass._arch_of_call(expr: (UniNode | None)) -> (Archetype | None) {
    if not isinstance(expr, FuncCall) or not isinstance(expr.target, Name) {
        return None;
    }
    sym = expr.target.sym;
    if sym is None or sym.decl is None {
        return None;
    }
    decl = sym.decl;
    arch = decl if isinstance(decl, Archetype) else decl.find_parent_of_type(Archetype);
    if arch is not None and arch.name.value == expr.target.sym_name {
        return arch;
    }
    return None;
}

impl RcFactsPass._connect_chain_leaves(expr: UniNode) -> (list[Name] | None) {
    if isinstance(expr, BinaryExpr) and isinstance(expr.op, ConnectOp) {
        l = self._connect_chain_leaves(expr.left);
        r = self._connect_chain_leaves(expr.right);
        if l is None or r is None {
            return None;
        }
        return l + r;
    }
    if isinstance(expr, Name) {
        return [expr];
    }
    return None;
}

impl RcFactsPass._blessed_arch_call(fc: FuncCall, member_sids: set[int]) -> bool {
    par = fc.parent;
    if isinstance(par, Assignment) and par.value is fc {
        tgts = par.target if isinstance(par.target, (list, tuple)) else [(par.target)];
        if len(tgts) == 1
            and isinstance(tgts[0], Name)
            and tgts[0].sym is not None
            and id(tgts[0].sym) in member_sids {
            return True;
        }
    }
    if isinstance(par, BinaryExpr)
        and isinstance(par.op, Token)
        and par.op.name == Tok.KW_SPAWN
        and (par.left is fc or par.right is fc) {
        arch = self._arch_of_call(fc);
        return arch is not None and arch.arch_type.name == Tok.KW_WALKER;
    }
    if isinstance(par, ConnectOp) and par.conn_type is fc {
        return True;
    }
    return False;
}

impl RcFactsPass._anon_extent_poisoned(
    body: Sequence[UniNode], open_idx: int, close_idx: int, member_sids: set[int]
) -> bool {
    for s2 in body[open_idx:close_idx + 1] {
        if isinstance(s2, (OpenStmt, ReturnStmt, CtrlStmt, RaiseStmt)) {
            return True;
        }
        if s2.get_all_sub_nodes(ReturnStmt)
            or s2.get_all_sub_nodes(CtrlStmt)
            or s2.get_all_sub_nodes(RaiseStmt)
            or s2.get_all_sub_nodes(YieldExpr)
            or s2.get_all_sub_nodes(OpenStmt) {
            return True;
        }
        for sub in s2.get_all_sub_nodes(Name) {
            if sub.sym_name in ("root", "here") {
                return True;
            }
        }
        for sub in s2.get_all_sub_nodes(FuncCall) {
            if self._arch_of_call(sub) is not None
                and not self._blessed_arch_call(sub, member_sids) {
                return True;
            }
        }
    }
    return False;
}

impl RcFactsPass._scan_anon_region_block(
    body: Sequence[UniNode]
) -> list[tuple[int, int, list[str]]] {
    stmt_idx: dict[int, int] = {};
    for (i, s) in enumerate(body) {
        stmt_idx[id(s)] = i;
    }
    members: dict[int, tuple[Symbol, int, str]] = {};
    order: list[int] = [];
    bad: set[int] = set();
    for (i, s) in enumerate(body) {
        if not isinstance(s, Assignment) {
            continue;
        }
        tgts = s.target if isinstance(s.target, (list, tuple)) else [(s.target)];
        if len(tgts) != 1 or not isinstance(tgts[0], Name) {
            continue;
        }
        tsym = tgts[0].sym;
        if tsym is None
            or tsym.storage not in (SymbolStorage.LOCAL, SymbolStorage.MODULE_GLOBAL) {
            continue;
        }
        arch = self._arch_of_call(s.value);
        if arch is None or arch.arch_type.name != Tok.KW_NODE {
            continue;
        }
        sid = id(tsym);
        if sid in members {
            bad.add(sid);
            continue;
        }
        for d in tsym.defn {
            _dc: (UniNode | None) = d;
            while _dc is not None and id(_dc) not in stmt_idx {
                _dc = _dc.parent;
            }
            if _dc is None {
                bad.add(sid);
            }
        }
        members[sid] = (tsym, i, tgts[0].sym_name);
        order.append(sid);
    }
    if not members {
        return [];
    }
    label: dict[int, int] = {};
    for (k, sid) in enumerate(order) {
        label[sid] = k;
    }
    spawned: set[int] = set();
    last_idx: dict[int, int] = {sid: members[sid][1] for sid in order};
    for sid in order {
        _mrec = members[sid];
        sym: Symbol = _mrec[0];
        _use_map2: dict[int, NameAtom] = {};
        for u0 in sym.uses {
            if not self._is_def_name(u0) {
                _use_map2[id(u0)] = u0;
            }
        }
        for u in _use_map2.values() {
            _cur: (UniNode | None) = u;
            top: (UniNode | None) = None;
            while _cur is not None {
                if id(_cur) in stmt_idx {
                    top = _cur;
                    break;
                }
                _cur = _cur.parent;
            }
            if top is None {
                bad.add(sid);
                continue;
            }
            ti = stmt_idx[id(top)];
            expr = top.expr if isinstance(top, ExprStmt) else top;
            ok = False;
            if isinstance(expr, BinaryExpr) and isinstance(expr.op, ConnectOp) {
                leaves = self._connect_chain_leaves(expr);
                if leaves is not None {
                    good = True;
                    seen_u = False;
                    lsids: list[int] = [];
                    for lf in leaves {
                        if lf is u {
                            seen_u = True;
                        }
                        if lf.sym is None or id(lf.sym) not in members {
                            good = False;
                        } else {
                            lsids.append(id(lf.sym));
                        }
                    }
                    if good and seen_u {
                        ok = True;
                        for l2 in lsids {
                            if label[l2] != label[sid] {
                                _from = label[l2];
                                for s3 in order {
                                    if label[s3] == _from {
                                        label[s3] = label[sid];
                                    }
                                }
                            }
                        }
                    }
                }
            } elif isinstance(expr, BinaryExpr)
                and isinstance(expr.op, Token)
                and expr.op.name == Tok.KW_SPAWN
                and isinstance(top, ExprStmt)
                and (expr.left is u or expr.right is u) {
                ok = True;
                spawned.add(sid);
            }
            if not ok {
                bad.add(sid);
            } elif ti > last_idx[sid] {
                last_idx[sid] = ti;
            }
        }
    }
    groups: dict[int, list[int]] = {};
    for sid in order {
        lb = label[sid];
        if lb not in groups {
            groups[lb] = [];
        }
        groups[lb].append(sid);
    }
    out: list[tuple[int, int, list[str]]] = [];
    used_ranges: list[tuple[int, int]] = [];
    for (lb, sids) in groups.items() {
        if any([(s in bad) for s in sids]) {
            continue;
        }
        if not any([(s in spawned) for s in sids]) {
            continue;
        }
        open_idx = -1;
        close_idx = -1;
        for s in sids {
            _oi: int = members[s][1];
            _ci: int = last_idx[s];
            if open_idx < 0 or _oi < open_idx {
                open_idx = _oi;
            }
            if _ci > close_idx {
                close_idx = _ci;
            }
        }
        if close_idx <= open_idx {
            continue;
        }
        member_sids = set(sids);
        if self._anon_extent_poisoned(body, open_idx, close_idx, member_sids) {
            continue;
        }
        overlap = False;
        for rng in used_ranges {
            (ro, rc) = rng;
            if not (close_idx < ro or rc < open_idx) {
                overlap = True;
            }
        }
        if overlap {
            continue;
        }
        used_ranges.append((open_idx, close_idx));
        pairs = sorted([(members[s][1], members[s][2]) for s in sids]);
        out.append((open_idx, close_idx, [p[1] for p in pairs]));
    }
    return out;
}

impl RcFactsPass._stamp_param_rebound(ir_in: Module) -> None {
    for pv in ir_in.get_all_sub_nodes(ParamVar) {
        sym = pv.name.sym if pv.name else None;
        if sym is not None {
            sym.param_rebound = self._param_plainly_rebound(sym);
        }
    }
}

impl RcFactsPass._param_plainly_rebound(sym: Symbol) -> bool {
    for d in (list(sym.defn) + list(sym.uses)) {
        asg = d.find_parent_of_type(Assignment);
        if asg is None or asg.aug_op is not None {
            continue;
        }
        targets = asg.target
            if isinstance(asg.target, (list, tuple))
            else [(asg.target)];
        if d in targets {
            return True;
        }
    }
    return False;
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

    qualified: set[SymId] = set();
    for sid in tracked {
        ok = True;
        for u in uses_by_sym.get(sid, []) {
            if not self._is_alias_value(u) {
                ok = False;
                break;
            }
        }
        if ok {
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
