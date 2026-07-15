impl RcFactsPass.postinit -> None {
    super.postinit();
}

impl RcFactsPass.transform(ir_in: uni.Module) -> uni.Module {
    self._stamp_param_rebound(ir_in);
    self._stamp_move_lowerable(ir_in);
    self._stamp_escapes(ir_in);
    self._stamp_last_use(ir_in);
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
                escapes = True;
                stack_ok = False;
                break;
            }
            if self._enclosing_fn_scope(u) is not _def_scope {
                escapes = True;
                stack_ok = False;
                break;
            }

            if u.find_parent_of_type(uni.FuncCall) is not None {
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

impl RcFactsPass._is_def_name(nm: uni.Name) -> bool {
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
        or p.type_tag.ownership == OwnershipKind.VAL
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
