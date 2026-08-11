impl RcFactsPass.postinit -> None {
    super.postinit();
}

impl RcFactsPass.transform(ir_in: uni.Module) -> uni.Module {
    self._stamp_param_rebound(ir_in);
    self._stamp_move_lowerable(ir_in);
    self._stamp_escapes(ir_in);
    self._stamp_region_handles(ir_in);
    self._stamp_last_use(ir_in);
    self._stamp_move_in(ir_in);
    self._stamp_anon_regions(ir_in);
    return ir_in;
}

impl RcFactsPass._enclosing_fn_scope(nd: uni.UniNode) -> (uni.UniNode | None) {
    cur = nd.parent;
    while cur is not None {
        if isinstance(cur, (uni.Ability, uni.LambdaExpr, uni.Test, uni.ModuleCode)) {
            return cur;
        }
        cur = cur.parent;
    }
    return None;
}

impl RcFactsPass._is_param_sym(sym: uni.Symbol) -> bool {
    for d in sym.defn {
        if d.find_parent_of_type(uni.ParamVar) is not None {
            return True;
        }
    }
    return False;
}

impl RcFactsPass._use_ok_for_stack(nm: uni.NameAtom) -> bool {
    p = nm.parent;
    if isinstance(p, uni.AtomTrailer) and p.target is nm {
        return True;
    }
    if isinstance(
        p,
        (uni.BinaryExpr, uni.CompareExpr, uni.UnaryExpr, uni.BoolExpr, uni.IfElseExpr)
    ) {
        return True;
    }
    if isinstance(p, uni.Assignment) {
        targets = p.target if isinstance(p.target, (list, tuple)) else [(p.target)];
        for t in targets {
            if t is nm {
                return True;
            }
        }
        return False;
    }
    if isinstance(p, (uni.IfStmt, uni.WhileStmt)) {
        return True;
    }
    return False;
}

impl RcFactsPass._stamp_escapes(ir_in: uni.Module) -> None {
    seen: set[int] = set();
    for nm in ir_in.get_all_sub_nodes(uni.Name) {
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
            if u.find_parent_of_type(uni.ReturnStmt) is not None {
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

            if u.find_parent_of_type(uni.FuncCall) is not None
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

impl RcFactsPass._call_use_stack_safe(nm: uni.NameAtom, sym: uni.Symbol) -> bool {
    p = nm.parent;
    if isinstance(p, uni.AtomTrailer) and p.target is nm {
        gp = p.parent;
        if isinstance(gp, uni.FuncCall) and gp.target is p {
            return False;
        }
        return self._scalar_attr_read(nm);
    }
    if sym.ownership != OwnershipKind.OWN {
        return False;
    }
    if isinstance(p, uni.UnaryExpr) and is_borrow_kind(p.ownership) {
        return self._borrow_arg_callee_ok(p);
    }
    return False;
}

impl RcFactsPass._scalar_attr_read(nm: uni.NameAtom) -> bool {
    p = nm.parent;
    if not (isinstance(p, uni.AtomTrailer) and p.target is nm and p.is_attr) {
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

impl RcFactsPass._borrow_arg_callee_ok(bx: uni.UnaryExpr) -> bool {
    call = bx.parent if isinstance(bx.parent, uni.FuncCall) else None;
    if call is None or call.callee_decl is None {
        return False;
    }
    sig = call.callee_decl.signature;
    if sig is None or not isinstance(sig, uni.FuncSignature) {
        return False;
    }
    idx = -1;
    for (i, a) in enumerate(call.params or []) {
        if isinstance(a, uni.KWPair) {
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
    return isinstance(ret, uni.Name) and ret.value in ("int", "float", "bool", "None");
}

impl RcFactsPass._asn_makes_region_handle(nd: uni.Assignment) -> bool {
    import from jaclang.compiler.symbol_utils { is_builtin_region_name }
    if isinstance(nd.value, uni.FuncCall) and is_builtin_region_name(nd.value.target) {
        return True;
    }
    if nd.type_tag is not None {
        _tt_expr = nd.type_tag.tag;
        while isinstance(_tt_expr, uni.AtomTrailer) {
            _tt_expr = _tt_expr.target;
        }
        if is_builtin_region_name(_tt_expr) {
            return True;
        }
    }
    if (
        isinstance(nd.value, uni.FuncCall)
        and isinstance(nd.value.target, uni.Name)
        and nd.value.target.sym is not None
        and nd.value.target.sym.decl is not None
    ) {
        _cal_ab = nd.value.target.sym.decl.find_parent_of_type(uni.Ability);
        if _cal_ab is not None
            and isinstance(_cal_ab.signature, uni.FuncSignature)
            and _cal_ab.signature.return_type is not None {
            _rt_expr = _cal_ab.signature.return_type;
            while isinstance(_rt_expr, uni.AtomTrailer) {
                _rt_expr = _rt_expr.target;
            }
            if is_builtin_region_name(_rt_expr) {
                return True;
            }
        }
    }
    if isinstance(nd.value, uni.Name)
        and nd.value.sym is not None
        and nd.value.sym.na_region_handle {
        return True;
    }
    if isinstance(nd.value, uni.UnaryExpr)
        and nd.value.ownership == OwnershipKind.IMM
        and isinstance(nd.value.operand, uni.Name)
        and nd.value.operand.sym is not None
        and nd.value.operand.sym.na_region_handle {
        return True;
    }
    return False;
}

impl RcFactsPass._stamp_region_handles(ir_in: uni.Module) -> None {
    _changed = True;
    while _changed {
        _changed = False;
        for asn in ir_in.get_all_sub_nodes(uni.Assignment) {
            if len(asn.target) != 1 or not isinstance(asn.target[0], uni.Name) {
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

impl RcFactsPass._stamp_last_use(ir_in: uni.Module) -> None {
    out: dict[int, list[str]] = {};
    for ab in ir_in.get_all_sub_nodes(uni.Ability) {
        if isinstance(ab.signature, uni.FuncSignature)
            and isinstance(ab.body, (list, tuple)) {
            self._collect_last_use(ab, ab.body, out);
        }
    }
    for mc in ir_in.get_all_sub_nodes(uni.ModuleCode) {
        if isinstance(mc.body, (list, tuple)) {
            self._collect_last_use(mc, mc.body, out);
        }
    }
    ir_in.gen.rc_last_use = out;
}

impl RcFactsPass._collect_last_use(
    owner: uni.UniNode, body: Sequence[uni.UniNode], out: dict[int, list[str]]
) -> None {
    sym_last: dict[int, tuple[int, str]] = {};
    for (idx, stmt) in enumerate(body) {
        for nm in stmt.get_all_sub_nodes(uni.Name) {
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
    for (_, entry) in sym_last.items() {
        (idx, name) = entry;
        key = id(body[idx]);
        if key not in out {
            out[key] = [];
        }
        if name not in out[key] {
            out[key].append(name);
        }
    }
}

impl RcFactsPass._stamp_move_in(ir_in: uni.Module) -> None {
    out: set[int] = set();
    seen: set[int] = set();
    for nm in ir_in.get_all_sub_nodes(uni.Name) {
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
        _use_map: dict[int, uni.NameAtom] = {};
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
        if use.find_parent_of_type(uni.WhileStmt) is not None
            or use.find_parent_of_type(uni.InForStmt) is not None
            or use.find_parent_of_type(uni.IterForStmt) is not None {
            continue;
        }
        if sym.defn
            and self._enclosing_fn_scope(sym.defn[0])
                is not self._enclosing_fn_scope(use) {
            continue;
        }
        out.add(id(use));
    }
    ir_in.gen.rc_move_in = out;
}

impl RcFactsPass._stamp_anon_regions(ir_in: uni.Module) -> None {
    open_map: dict[int, int] = {};
    close_map: dict[int, int] = {};
    locals_map: dict[int, list[str]] = {};
    gidx = 0;
    blocks: list = [];
    for ab in ir_in.get_all_sub_nodes(uni.Ability) {
        if isinstance(ab.signature, uni.FuncSignature)
            and isinstance(ab.body, (list, tuple)) {
            blocks.append(ab.body);
        }
    }
    for mc in ir_in.get_all_sub_nodes(uni.ModuleCode) {
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
    ir_in.gen.anon_region_open = open_map;
    ir_in.gen.anon_region_close = close_map;
    ir_in.gen.anon_region_locals = locals_map;
}

impl RcFactsPass._arch_of_call(expr: (uni.UniNode | None)) -> (uni.Archetype | None) {
    if not isinstance(expr, uni.FuncCall) or not isinstance(expr.target, uni.Name) {
        return None;
    }
    sym = expr.target.sym;
    if sym is None or sym.decl is None {
        return None;
    }
    decl = sym.decl;
    arch = decl
        if isinstance(decl, uni.Archetype)
        else decl.find_parent_of_type(uni.Archetype);
    if arch is not None and arch.name.value == expr.target.sym_name {
        return arch;
    }
    return None;
}

impl RcFactsPass._connect_chain_leaves(expr: uni.UniNode) -> (list[uni.Name] | None) {
    if isinstance(expr, uni.BinaryExpr) and isinstance(expr.op, uni.ConnectOp) {
        l = self._connect_chain_leaves(expr.left);
        r = self._connect_chain_leaves(expr.right);
        if l is None or r is None {
            return None;
        }
        return l + r;
    }
    if isinstance(expr, uni.Name) {
        return [expr];
    }
    return None;
}

impl RcFactsPass._blessed_arch_call(fc: uni.FuncCall, member_sids: set[int]) -> bool {
    par = fc.parent;
    if isinstance(par, uni.Assignment) and par.value is fc {
        tgts = par.target if isinstance(par.target, (list, tuple)) else [(par.target)];
        if len(tgts) == 1
            and isinstance(tgts[0], uni.Name)
            and tgts[0].sym is not None
            and id(tgts[0].sym) in member_sids {
            return True;
        }
    }
    if isinstance(par, uni.BinaryExpr)
        and isinstance(par.op, uni.Token)
        and par.op.name == Tok.KW_SPAWN
        and (par.left is fc or par.right is fc) {
        arch = self._arch_of_call(fc);
        return arch is not None and arch.arch_type.name == Tok.KW_WALKER;
    }
    if isinstance(par, uni.ConnectOp) and par.conn_type is fc {
        return True;
    }
    return False;
}

impl RcFactsPass._anon_extent_poisoned(
    body: Sequence[uni.UniNode], open_idx: int, close_idx: int, member_sids: set[int]
) -> bool {
    for s2 in body[open_idx:close_idx + 1] {
        if isinstance(
            s2, (uni.OpenStmt, uni.ReturnStmt, uni.CtrlStmt, uni.RaiseStmt)
        ) {
            return True;
        }
        if s2.get_all_sub_nodes(uni.ReturnStmt)
            or s2.get_all_sub_nodes(uni.CtrlStmt)
            or s2.get_all_sub_nodes(uni.RaiseStmt)
            or s2.get_all_sub_nodes(uni.YieldExpr)
            or s2.get_all_sub_nodes(uni.OpenStmt) {
            return True;
        }
        for sub in s2.get_all_sub_nodes(uni.Name) {
            if sub.sym_name in ("root", "here") {
                return True;
            }
        }
        for sub in s2.get_all_sub_nodes(uni.FuncCall) {
            if self._arch_of_call(sub) is not None
                and not self._blessed_arch_call(sub, member_sids) {
                return True;
            }
        }
    }
    return False;
}

impl RcFactsPass._scan_anon_region_block(body: Sequence[uni.UniNode]) -> list[tuple] {
    stmt_idx: dict[int, int] = {};
    for (i, s) in enumerate(body) {
        stmt_idx[id(s)] = i;
    }
    members: dict[int, tuple] = {};
    order: list[int] = [];
    bad: set[int] = set();
    for (i, s) in enumerate(body) {
        if not isinstance(s, uni.Assignment) {
            continue;
        }
        tgts = s.target if isinstance(s.target, (list, tuple)) else [(s.target)];
        if len(tgts) != 1 or not isinstance(tgts[0], uni.Name) {
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
            _dc: (uni.UniNode | None) = d;
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
        sym: uni.Symbol = _mrec[0];
        _use_map2: dict[int, uni.NameAtom] = {};
        for u0 in sym.uses {
            if not self._is_def_name(u0) {
                _use_map2[id(u0)] = u0;
            }
        }
        for u in _use_map2.values() {
            _cur: (uni.UniNode | None) = u;
            top: (uni.UniNode | None) = None;
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
            expr = top.expr if isinstance(top, uni.ExprStmt) else top;
            ok = False;
            if isinstance(expr, uni.BinaryExpr)
                and isinstance(expr.op, uni.ConnectOp) {
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
            } elif isinstance(expr, uni.BinaryExpr)
                and isinstance(expr.op, uni.Token)
                and expr.op.name == Tok.KW_SPAWN
                and isinstance(top, uni.ExprStmt)
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
    out: list[tuple] = [];
    used_ranges: list[tuple] = [];
    for (lb, sids) in groups.items() {
        if any([(s in bad) for s in sids]) {
            continue;
        }
        if not any([(s in spawned) for s in sids]) {
            continue;
        }
        open_idx = min([members[s][1] for s in sids]);
        close_idx = max([last_idx[s] for s in sids]);
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

impl RcFactsPass._stamp_param_rebound(ir_in: uni.Module) -> None {
    for pv in ir_in.get_all_sub_nodes(uni.ParamVar) {
        sym = pv.name.sym if pv.name else None;
        if sym is not None {
            sym.param_rebound = self._param_plainly_rebound(sym);
        }
    }
}

impl RcFactsPass._param_plainly_rebound(sym: uni.Symbol) -> bool {
    for d in (list(sym.defn) + list(sym.uses)) {
        asg = d.find_parent_of_type(uni.Assignment);
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

impl RcFactsPass._stamp_move_lowerable(ir_in: uni.Module) -> None {
    cfg_nodes = [
        n
        for n in ir_in.flatten()
        if isinstance(n, uni.UniCFGNode)
    ];
    all_names = ir_in.get_all_sub_nodes(uni.Name);

    uses_by_sym: dict[SymId, list[uni.Name]] = {};
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

    candidates: list[tuple[uni.Assignment, SymId]] = [];
    tracked: set[SymId] = set();
    for nd in ir_in.get_all_sub_nodes(uni.Assignment) {
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

impl RcFactsPass._cfg_owner(sub: uni.UniNode) -> (uni.UniCFGNode | None) {
    if isinstance(sub, uni.UniCFGNode) {
        return sub;
    }
    return sub.find_parent_of_type(uni.UniCFGNode);
}

impl RcFactsPass._is_def_name(nm: uni.NameAtom) -> bool {
    p = nm.parent;
    if isinstance(p, uni.Assignment) and p.aug_op is None {
        for tgt in p.target {
            if tgt is nm {
                return True;
            }
        }
    }
    return False;
}

impl RcFactsPass._is_alias_value(nm: uni.Name) -> bool {
    p = nm.parent;
    if not isinstance(p, uni.Assignment) {
        return False;
    }
    if p.value is not nm or p.aug_op is not None or len(p.target) != 1 {
        return False;
    }
    tgt = p.target[0];
    if not (isinstance(tgt, uni.Name) and tgt.sym is not None) {
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

impl RcFactsPass._move_candidate_source(nd: uni.Assignment) -> (uni.Name | None) {
    if nd.aug_op is not None or len(nd.target) != 1 {
        return None;
    }
    tgt = nd.target[0];
    if not (isinstance(tgt, uni.Name) and tgt.sym is not None) {
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
    if not (isinstance(val, uni.Name) and val.sym is not None) {
        return None;
    }
    if val.sym.storage != SymbolStorage.LOCAL {
        return None;
    }
    return val;
}

impl RcFactsPass._live_transfer(nd: uni.UniCFGNode, out_set: set[SymId]) -> set[SymId] {
    new_in = set(self._node_use.get(id(nd), set()));
    dfn = self._node_def.get(id(nd), set());
    for x in out_set {
        if x not in dfn {
            new_in.add(x);
        }
    }
    return new_in;
}

impl RcFactsPass._solve_liveness(
    cfg_nodes: list[uni.UniCFGNode], tracked: set[SymId]
) -> dict[int, set[SymId]] {
    self._node_use = {};
    self._node_def = {};
    for n in cfg_nodes {
        use: set[SymId] = set();
        dfn: set[SymId] = set();
        for nm in n.get_all_sub_nodes(uni.Name) {
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
    return dataflow.solve_backward(cfg_nodes, self._live_transfer);
}
