import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;

impl PredicateCtrlFlowPass._setups_safe(
    setups: Sequence[uni.CodeBlockStmt], region: uni.IfStmt
) -> bool {
    for s in setups {
        if isinstance(s, (uni.ReturnStmt, uni.RaiseStmt, uni.CtrlStmt)) {
            return False;
        }
        if s.get_all_sub_nodes(uni.ReturnStmt) {
            return False;
        }
        if s.get_all_sub_nodes(uni.RaiseStmt) {
            return False;
        }
        if s.get_all_sub_nodes(uni.CtrlStmt) {
            return False;
        }
        if not self._effect_neutral(s, region) {
            return False;
        }
    }
    return True;
}

impl PredicateCtrlFlowPass._effect_neutral(s: uni.UniNode, region: uni.IfStmt) -> bool {
    if self._is_assert_async(s) {
        return True;
    }
    if self._is_existence_guard(s, region) {
        return True;
    }
    if isinstance(s, uni.Assignment) {
        return self._assignment_neutral(s);
    }
    return False;
}

impl PredicateCtrlFlowPass._is_existence_guard(
    s: uni.UniNode, region: uni.IfStmt
) -> bool {
    if not isinstance(s, uni.IfStmt) {
        return False;
    }
    if s.else_body is not None {
        return False;
    }
    keyed = self._hasattr_key(s.condition);
    if keyed is None {
        return False;
    }
    (recv, key) = keyed;
    memoized = False;
    for st in (s.body or []) {
        if not isinstance(st, uni.Assignment) {
            return False;
        }
        if self._writes_attr(st, recv, key) {
            if not self._init_value_safe(st.value) {
                return False;
            }
            memoized = True;
            continue;
        }
        if not self._assignment_neutral(st) {
            return False;
        }
    }
    if not memoized {
        return False;
    }
    return self._attr_confined(region, key);
}

impl PredicateCtrlFlowPass._init_value_safe(
    v: (uni.Expr | uni.YieldExpr | None)
) -> bool {
    if v is None {
        return False;
    }
    calls = [v] if isinstance(v, uni.FuncCall) else [];
    calls = calls + list(v.get_all_sub_nodes(uni.FuncCall));
    for c in calls {
        if not self._call_speculatable(c) {
            return False;
        }
    }
    return True;
}

impl PredicateCtrlFlowPass._call_speculatable(c: uni.FuncCall) -> bool {
    mod = c.find_parent_of_type(uni.Module);
    if mod is None {
        return False;
    }
    t = c.target;
    if isinstance(t, uni.Name) {
        fn = self._module_fn(mod, t.value);
        return (fn is not None) and self._body_pure_nonraising(fn, c);
    }
    if isinstance(t, uni.AtomTrailer) and isinstance(t.right, uni.Name) {
        cands = [
            fn
            for fn in self._dispatch_table_fns(mod)
            if self._signature_accepts(fn, c)
        ];
        if not cands {
            return False;
        }
        for fn in cands {
            if not self._body_pure_nonraising(fn, c) {
                return False;
            }
        }
        return True;
    }
    return False;
}

impl PredicateCtrlFlowPass._signature_accepts(
    fn: uni.Ability, c: uni.FuncCall
) -> bool {
    sig = fn.signature;
    if (sig is None) or (not isinstance(sig, uni.FuncSignature)) {
        return False;
    }
    named = set();
    for p in (sig.get_parameters() or []) {
        if p?.name is not None {
            named.add(p.name.value);
        }
    }
    n_pos = 0;
    for prm in (c.params or []) {
        if isinstance(prm, uni.KWPair) and (prm.key is not None) {
            if (prm.key.sym_name not in named) and (self._varkw_name(fn) is None) {
                return False;
            }
        } else {
            n_pos += 1;
        }
    }
    capacity = len(named) + (1 if sig.varargs is not None else 0);
    return n_pos <= capacity;
}

impl PredicateCtrlFlowPass._module_fn(
    mod: uni.Module, name: str
) -> (uni.Ability | None) {
    for ab in mod.get_all_sub_nodes(uni.Ability) {
        if ab?.sym_name == name {
            return ab;
        }
    }
    return None;
}

impl PredicateCtrlFlowPass._dispatch_table_fns(mod: uni.Module) -> list[uni.Ability] {
    out: list[uni.Ability] = [];
    for a in mod.get_all_sub_nodes(uni.Assignment) {
        d = a.value;
        if not isinstance(d, uni.DictVal) {
            continue;
        }
        fns: list[uni.Ability] = [];
        ok = len(d.kv_pairs or []) > 0;
        for kv in (d.kv_pairs or []) {
            val = kv.value;
            fn = None;
            if isinstance(val, uni.Name) {
                fn = self._module_fn(mod, val.value);
            }
            if fn is None {
                ok = False;
                break;
            }
            fns.append(fn);
        }
        if ok {
            out.extend(fns);
        }
    }
    return out;
}

impl PredicateCtrlFlowPass._body_pure_nonraising(
    fn: uni.Ability, c: uni.FuncCall, seen: (set[int] | None) = None
) -> bool {
    marks = seen if seen is not None else set();
    if id(fn) in marks {
        return True;
    }
    marks.add(id(fn));
    varkw = self._varkw_name(fn);
    extra_kw = self._passes_extra_kwargs(fn, c);
    raise_calls: set[int] = set();
    for r in fn.get_all_sub_nodes(uni.RaiseStmt) {
        if (varkw is None) or extra_kw or (not self._guarded_by_varkw(r, varkw, fn)) {
            return False;
        }
        for rc in r.get_all_sub_nodes(uni.FuncCall) {
            raise_calls.add(id(rc));
        }
    }
    mod = fn.find_parent_of_type(uni.Module);
    for call in fn.get_all_sub_nodes(uni.FuncCall) {
        if id(call) in raise_calls {
            continue;
        }
        if self._pure_callee(call.target) {
            continue;
        }
        t = call.target;
        local = None;
        if isinstance(t, uni.Name) and (mod is not None) {
            local = self._module_fn(mod, t.value);
        }
        if (local is None) or (not self._body_pure_nonraising(local, call, marks)) {
            return False;
        }
    }
    return True;
}

impl PredicateCtrlFlowPass._hasattr_key(c: uni.Expr) -> (tuple[str, str] | None) {
    if (not isinstance(c, uni.UnaryExpr)) or (c.op is None) or (c.op.value != 'not') {
        return None;
    }
    inner = c.operand;
    if not (
        isinstance(inner, uni.FuncCall)
        and isinstance(inner.target, uni.Name)
        and (inner.target.value == 'hasattr')
    ) {
        return None;
    }
    params = list(inner.params or []);
    if len(params) != 2 {
        return None;
    }
    (recv, key) = (params[0], params[1]);
    if isinstance(recv, uni.KWPair)
        or (not isinstance(key, (uni.String, uni.MultiString))) {
        return None;
    }
    return (recv.unparse().replace(' ', ''), key.lit_value);
}

impl PredicateCtrlFlowPass._writes_attr(
    s: uni.Assignment, recv: str, key: str
) -> bool {
    for t in (s.target or []) {
        targets = list(t.values) if isinstance(t, uni.TupleVal) else [t];
        for tg in targets {
            if (
                isinstance(tg, uni.AtomTrailer)
                and isinstance(tg.right, uni.Name)
                and (tg.right.value == key)
                and (tg.target.unparse().replace(' ', '') == recv)
            ) {
                return True;
            }
        }
    }
    return False;
}

impl PredicateCtrlFlowPass._attr_confined(region: uni.IfStmt, key: str) -> bool {
    mod = region.find_parent_of_type(uni.Module);
    if mod is None {
        return False;
    }
    for at in mod.get_all_sub_nodes(uni.AtomTrailer) {
        if (
            isinstance(at.right, uni.Name)
            and (at.right.value == key)
            and (not self._within(at, region))
        ) {
            return False;
        }
    }
    for st in mod.get_all_sub_nodes(uni.String) {
        if (st.lit_value == key) and (not self._within(st, region)) {
            return False;
        }
    }
    for ms in mod.get_all_sub_nodes(uni.MultiString) {
        if (ms.lit_value == key) and (not self._within(ms, region)) {
            return False;
        }
    }
    return True;
}

impl PredicateCtrlFlowPass._within(nd: uni.UniNode, anc: uni.UniNode) -> bool {
    cur: (uni.UniNode | None) = nd;
    while cur is not None {
        if cur is anc {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

impl PredicateCtrlFlowPass._varkw_name(fn: uni.Ability) -> (str | None) {
    sig = fn.signature;
    if (sig is None) or (not isinstance(sig, uni.FuncSignature)) {
        return None;
    }
    kw = sig.kwargs;
    if (kw is None) or (kw.name is None) {
        return None;
    }
    return kw.name.value;
}

impl PredicateCtrlFlowPass._passes_extra_kwargs(
    fn: uni.Ability, c: uni.FuncCall
) -> bool {
    sig = fn.signature;
    if (sig is None) or (not isinstance(sig, uni.FuncSignature)) {
        return True;
    }
    named = set();
    for p in (sig.get_parameters() or []) {
        if p?.name is not None {
            named.add(p.name.value);
        }
    }
    for prm in (c.params or []) {
        if isinstance(prm, uni.KWPair) and (prm.key is not None) {
            if prm.key.sym_name not in named {
                return True;
            }
        }
    }
    return False;
}

impl PredicateCtrlFlowPass._guarded_by_varkw(
    r: uni.RaiseStmt, varkw: str, fn: uni.Ability
) -> bool {
    cur = r.parent;
    while (cur is not None) and (cur is not fn) {
        if isinstance(cur, uni.IfStmt) {
            if self._mentions_name(cur.condition, varkw) {
                return True;
            }
        }
        cur = cur.parent;
    }
    return False;
}

impl PredicateCtrlFlowPass._mentions_name(e: (uni.Expr | None), nm: str) -> bool {
    if e is None {
        return False;
    }
    if isinstance(e, uni.Name) and (e.value == nm) {
        return True;
    }
    for n in e.get_all_sub_nodes(uni.Name) {
        if n.value == nm {
            return True;
        }
    }
    return False;
}

impl PredicateCtrlFlowPass._pure_callee(t: (uni.Expr | None)) -> bool {
    if t is None {
        return False;
    }
    if isinstance(t, uni.Name) {
        return t.value in _PURE_BUILTINS;
    }
    if isinstance(t, uni.AtomTrailer) {
        base = t.target;
        while isinstance(base, uni.AtomTrailer) {
            base = base.target;
        }
        if isinstance(base, uni.Name) and (base.value in {'torch', 'math'}) {
            return True;
        }
        return isinstance(t.right, uni.Name)
            and (t.right.value in _PURE_TENSOR_METHODS);
    }
    return False;
}

impl PredicateCtrlFlowPass._assignment_neutral(s: uni.Assignment) -> bool {
    if self._is_device_move(s) {
        return True;
    }
    return (
        (s.value is not None)
        and (not self._has_call(s.value))
        and self._all_local_targets(s.target)
    );
}

impl PredicateCtrlFlowPass._is_device_move(s: uni.Assignment) -> bool {
    v = s.value;
    if (v is None) or (len(s.target) != 1) {
        return False;
    }
    if not (
        isinstance(v, uni.FuncCall)
        and isinstance(v.target, uni.AtomTrailer)
        and isinstance(v.target.right, uni.Name)
        and (v.target.right.value == 'to')
    ) {
        return False;
    }
    recv = v.target.target;
    return (recv.unparse().replace(' ', '') == s.target[0].unparse().replace(' ', ''));
}

impl PredicateCtrlFlowPass._all_local_targets(targets: Sequence[uni.Expr]) -> bool {
    for t in targets {
        if not isinstance(t, uni.Name) {
            return False;
        }
    }
    return len(targets) > 0;
}
