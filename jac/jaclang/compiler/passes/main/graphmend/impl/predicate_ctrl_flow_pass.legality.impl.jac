import from jaclang.compiler.passes.tool.unparse_pass { unparse_node }
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.main.graphmend.ast_edit { split_params_keyed }
import from jaclang.compiler.passes.main.graphmend.scope_facts {
    attr_annotation,
    attr_dict_kind,
    find_class,
    lexical_ability,
    module_imports_plain,
    param_annotation,
    param_names,
    self_attr_name,
    wrapping_classes
}
import from jaclang.jac0core.constant { SymbolType }
import from jaclang.jac0core.passes.sym_resolve { symbol_ability }

impl PredicateCtrlFlowPass._setups_safe(
    setups: Sequence[uni.CodeBlockStmt], region: uni.IfStmt
) -> bool {
    for s in setups {
        if isinstance(s, (uni.ReturnStmt, uni.RaiseStmt, uni.CtrlStmt))
            or s.get_all_sub_nodes(uni.ReturnStmt)
            or s.get_all_sub_nodes(uni.RaiseStmt)
            or s.get_all_sub_nodes(uni.CtrlStmt)
            or (not self._effect_neutral(s, region)) {
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
        return self._assignment_neutral(s, region);
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
        if not self._assignment_neutral(st, region) {
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
    calls = ([v] if isinstance(v, uni.FuncCall) else [])
        + list(v.get_all_sub_nodes(uni.FuncCall));
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
        fn = lexical_ability(c.find_parent_of_type(uni.Ability), t.value);
        if fn is None {
            fn = self._module_fn(mod, t.value);
        }
        if fn is None {
            return False;
        }
        return self._body_pure_nonraising(fn, c, None, self._callsite_ctx(fn, c));
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
            if not self._body_pure_nonraising(fn, c, None, self._callsite_ctx(fn, c)) {
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
    named = param_names(fn);
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
    return symbol_ability(mod.lookup(name, deep=False));
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
    fn: uni.Ability,
    c: uni.FuncCall,
    seen: (set[int] | None) = None,
    ctx: (dict[str, list[uni.Archetype]] | None) = None
) -> bool {
    marks = seen if seen is not None else set();
    if id(fn) in marks {
        return False;
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
    if self._impure_writes(fn, mod) {
        return False;
    }
    for call in fn.get_all_sub_nodes(uni.FuncCall) {
        if id(call) in raise_calls {
            continue;
        }
        if self._pure_callee(call.target) {
            continue;
        }
        if (ctx is not None) and self._ctx_dict_get(call, ctx) {
            continue;
        }
        if self._witnessed_dict_get(call, fn) {
            continue;
        }
        t = call.target;
        if isinstance(t, uni.AtomTrailer)
            and isinstance(t.right, uni.Name)
            and (t.right.value in _PURE_TENSOR_METHODS)
            and isinstance(t.target, uni.FuncCall) {
            continue;
        }
        local = None;
        if isinstance(t, uni.Name) {
            local = lexical_ability(fn, t.value);
            if (local is None) and (mod is not None) {
                local = self._module_fn(mod, t.value);
            }
        }
        if (local is None) or (not self._body_pure_nonraising(local, call, marks)) {
            return False;
        }
    }
    marks.discard(id(fn));
    return True;
}

impl PredicateCtrlFlowPass._witnessed_dict_get(
    call: uni.FuncCall, fn: uni.Ability
) -> bool {
    t = call.target;
    if not (
        isinstance(t, uni.AtomTrailer)
        and isinstance(t.right, uni.Name)
        and (t.right.value == 'get')
    ) {
        return False;
    }
    (pos, kw) = split_params_keyed(call.params);
    if kw or (not pos) or (len(pos) > 2) {
        return False;
    }
    for p in pos {
        if self._has_call(p) {
            return False;
        }
    }
    recv = t.target;
    if not isinstance(recv, uni.AtomTrailer) {
        return False;
    }
    base: any = recv;
    while isinstance(base, uni.AtomTrailer) {
        base = base.target;
    }
    if (not isinstance(base, uni.Name)) or (base.value not in param_names(fn)) {
        return False;
    }
    mod = fn.find_parent_of_type(uni.Module);
    if mod is None {
        return False;
    }
    return self._mapping_witnessed(mod, unparse_node(recv).replace(' ', ''));
}

impl PredicateCtrlFlowPass._mapping_witnessed(mod: uni.Module, key: str) -> bool {
    for tr in mod.get_all_sub_nodes(uni.AtomTrailer) {
        if isinstance(tr.right, uni.IndexSlice)
            and (unparse_node(tr.target).replace(' ', '') == key) {
            return True;
        }
    }
    for cmp in mod.get_all_sub_nodes(uni.CompareExpr) {
        for i in range(len(cmp.ops or [])) {
            if (cmp.ops[i].value != 'in') or (i >= len(cmp.rights or [])) {
                continue;
            }
            if unparse_node(cmp.rights[i]).replace(' ', '') == key {
                return True;
            }
        }
    }
    return False;
}

impl PredicateCtrlFlowPass._impure_writes(
    fn: uni.Ability, mod: (uni.Module | None)
) -> bool {
    outside = self._module_scope_names(mod) if mod is not None else set();
    if fn.get_all_sub_nodes(uni.DeleteStmt) {
        return True;
    }
    for a in fn.get_all_sub_nodes(uni.Assignment) {
        for t in (a.target or []) {
            targets = list(t.values) if isinstance(t, uni.TupleVal) else [t];
            for tg in targets {
                if not isinstance(tg, uni.Name) {
                    return True;
                }
                if tg.value in outside {
                    return True;
                }
            }
        }
    }
    return False;
}

impl PredicateCtrlFlowPass._module_scope_names(mod: uni.Module) -> set[str] {
    out: set[str] = set();
    for (name, sym) in mod.names_in_scope.items() {
        if (
            (sym.sym_type in {SymbolType.VAR, SymbolType.MOD_VAR})
            and (not sym.imported)
        ) {
            out.add(name);
        }
    }
    return out;
}

impl PredicateCtrlFlowPass._callsite_ctx(
    fn: uni.Ability, c: uni.FuncCall
) -> dict[str, list[uni.Archetype]] {
    sig = fn.signature;
    if (sig is None) or (not isinstance(sig, uni.FuncSignature)) {
        return {};
    }
    pnames = param_names(fn);
    ctx: dict[str, list[uni.Archetype]] = {};
    selfcls = self._self_classes(c);
    i = 0;
    for prm in (c.params or []) {
        if isinstance(prm, uni.KWPair) {
            continue;
        }
        if i >= len(pnames) {
            break;
        }
        classes = self._arg_classes(prm, c, selfcls);
        if classes {
            ctx[pnames[i]] = classes;
        }
        i += 1;
    }
    return ctx;
}

impl PredicateCtrlFlowPass._arg_classes(
    arg: uni.Expr, c: uni.FuncCall, selfcls: list[uni.Archetype]
) -> list[uni.Archetype] {
    mod = c.find_parent_of_type(uni.Module);
    if mod is None {
        return [];
    }
    if isinstance(arg, uni.Name) {
        site = c.find_parent_of_type(uni.Ability);
        if site is None {
            return [];
        }
        ann = param_annotation(site, arg.value);
        if isinstance(ann, uni.Name) {
            cls = find_class(mod, ann.value, self.prog, self._mat_seen);
            return [cls] if (cls is not None) else [];
        }
        return [];
    }
    attr = self_attr_name(arg);
    if attr is None {
        return [];
    }
    out: list[uni.Archetype] = [];
    for k in selfcls {
        ann_name = attr_annotation(k, attr);
        if ann_name is None {
            return [];
        }
        kmod = k.find_parent_of_type(uni.Module);
        if kmod is None {
            return [];
        }
        cls = find_class(kmod, ann_name, self.prog, self._mat_seen);
        if cls is None {
            return [];
        }
        if cls not in out {
            out.append(cls);
        }
    }
    return out;
}

impl PredicateCtrlFlowPass._self_classes(c: uni.FuncCall) -> list[uni.Archetype] {
    inner = c.find_parent_of_type(uni.Ability);
    if inner is None {
        return [];
    }
    outer: uni.Ability = inner;
    cur = outer.find_parent_of_type(uni.Ability);
    while cur is not None {
        outer = cur;
        cur = outer.find_parent_of_type(uni.Ability);
    }
    if outer is inner {
        return [];
    }
    sig = inner.signature;
    if not isinstance(sig, uni.FuncSignature) {
        return [];
    }
    params = sig.get_parameters() or [];
    if (not params) or (params[0]?.name is None) or (params[0].name.value != 'self') {
        return [];
    }
    mod = c.find_parent_of_type(uni.Module);
    if mod is None {
        return [];
    }
    return wrapping_classes(self.prog, mod, outer.sym_name);
}

impl PredicateCtrlFlowPass._ctx_dict_get(
    call: uni.FuncCall, ctx: dict[str, list[uni.Archetype]]
) -> bool {
    t = call.target;
    if not (
        isinstance(t, uni.AtomTrailer)
        and isinstance(t.right, uni.Name)
        and (t.right.value == 'get')
    ) {
        return False;
    }
    recv = t.target;
    if not (
        isinstance(recv, uni.AtomTrailer)
        and isinstance(recv.right, uni.Name)
        and isinstance(recv.target, uni.Name)
    ) {
        return False;
    }
    classes = ctx.get(recv.target.value, []);
    if not classes {
        return False;
    }
    for k in classes {
        kind = attr_dict_kind(k, recv.right.value);
        if kind not in ('dict', 'dict_or_none') {
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
    lit = key.lit_value;
    if not isinstance(lit, str) {
        return None;
    }
    return (unparse_node(recv).replace(' ', ''), lit);
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
                and (unparse_node(tg.target).replace(' ', '') == recv)
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
    named = param_names(fn);
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
        return (t.value in _PURE_BUILTINS) and (t.sym is None);
    }
    if isinstance(t, uni.AtomTrailer) {
        base = t.target;
        while isinstance(base, uni.AtomTrailer) {
            base = base.target;
        }
        if isinstance(base, uni.Name)
            and (base.value in {'torch', 'math'})
            and isinstance(t.right, uni.Name)
            and (t.right.value in _PURE_TORCH_FNS) {
            return self._pure_root(base);
        }
        return isinstance(t.right, uni.Name)
            and (t.right.value in _PURE_TENSOR_METHODS)
            and self._pure_receiver(t.target);
    }
    return False;
}

impl PredicateCtrlFlowPass._pure_receiver(recv: (uni.Expr | None)) -> bool {
    return isinstance(recv, uni.FuncCall) and self._pure_callee(recv.target);
}

impl PredicateCtrlFlowPass._pure_root(base: uni.Name) -> bool {
    sym = base.sym;
    if sym is not None {
        if sym.decl is None {
            return False;
        }
        mp = sym.decl.find_parent_of_type(uni.ModulePath);
        if mp is None {
            return False;
        }
        return mp.dot_path_str == base.value;
    }
    mod = base.find_parent_of_type(uni.Module);
    if mod is None {
        return False;
    }
    return module_imports_plain(mod, base.value);
}

impl PredicateCtrlFlowPass._assignment_neutral(
    s: uni.Assignment, region: uni.IfStmt
) -> bool {
    if self._is_device_move(s) {
        return self._move_consumed(s, region) and self._consumers_harmless(s, region);
    }
    return (
        (s.value is not None)
        and (not self._has_call(s.value))
        and self._all_local_targets(s.target, region)
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
    return (
        unparse_node(recv).replace(' ', '')
        == unparse_node(s.target[0]).replace(' ', '')
    );
}

impl PredicateCtrlFlowPass._move_consumed(
    s: uni.Assignment, region: uni.IfStmt
) -> bool {
    tgt = unparse_node(s.target[0]).replace(' ', '');
    for at in region.get_all_sub_nodes(uni.AtomTrailer) {
        if self._within(at, s) {
            continue;
        }
        if unparse_node(at).replace(' ', '') == tgt {
            return True;
        }
    }
    return False;
}

impl PredicateCtrlFlowPass._consumers_harmless(
    s: uni.Assignment, region: uni.IfStmt
) -> bool {
    tgt = unparse_node(s.target[0]).replace(' ', '');
    mod = region.find_parent_of_type(uni.Module);
    if mod is None {
        return False;
    }
    region_ab = region.find_parent_of_type(uni.Ability);
    checked: set[int] = set();
    for at in mod.get_all_sub_nodes(uni.AtomTrailer) {
        if unparse_node(at).replace(' ', '') != tgt {
            continue;
        }
        if self._within(at, region) {
            continue;
        }
        ab = at.find_parent_of_type(uni.Ability);
        if (ab is None) or (ab is region_ab) {
            return False;
        }
        if id(ab) in checked {
            continue;
        }
        checked.add(id(ab));
        if not self._normalizes_first(ab, tgt) {
            return False;
        }
    }
    return True;
}

impl PredicateCtrlFlowPass._normalizes_first(ab: uni.Ability, tgt: str) -> bool {
    norms: list[tuple[int, int]] = [];
    reads: list[uni.AtomTrailer] = [];
    for at in ab.get_all_sub_nodes(uni.AtomTrailer) {
        if unparse_node(at).replace(' ', '') != tgt {
            continue;
        }
        cur: (uni.UniNode | None) = at;
        while (cur is not None) and (not isinstance(cur, uni.Assignment)) {
            cur = cur.parent;
        }
        if isinstance(cur, uni.Assignment)
            and self._is_device_move(cur)
            and (unparse_node(cur.target[0]).replace(' ', '') == tgt) {
            spot = self._stmt_spot(cur);
            if spot is not None {
                norms.append(spot);
            }
            continue;
        }
        reads.append(at);
    }
    for m in reads {
        chain = self._spot_chain(m);
        ok = False;
        for (cid, aidx) in norms {
            midx = chain.get(cid);
            if (midx is not None) and (aidx < midx) {
                ok = True;
                break;
            }
        }
        if not ok {
            return False;
        }
    }
    return True;
}

impl PredicateCtrlFlowPass._stmt_spot(nd: uni.UniNode) -> (tuple[int, int] | None) {
    spots = list(self._spot_chain(nd).items());
    return spots[0] if spots else None;
}

impl PredicateCtrlFlowPass._spot_chain(nd: uni.UniNode) -> dict[int, int] {
    out: dict[int, int] = {};
    cur: (uni.UniNode | None) = nd;
    while cur is not None {
        p = cur.parent;
        if p is None {
            break;
        }
        holder: any = p;
        b = holder?.body;
        if isinstance(b, list) and (cur in b) {
            out[id(p)] = b.index(cur);
        }
        cur = p;
    }
    return out;
}

impl PredicateCtrlFlowPass._all_local_targets(
    targets: Sequence[uni.Expr], region: uni.IfStmt
) -> bool {
    scope: (uni.UniNode | None) = region.find_parent_of_type(uni.Ability);
    if scope is None {
        scope = region.find_parent_of_type(uni.Module);
    }
    if scope is None {
        return False;
    }
    vals: set[str] = set();
    for t in targets {
        if not isinstance(t, uni.Name) {
            return False;
        }
        vals.add(t.value);
    }
    if not vals {
        return False;
    }
    mod = region.find_parent_of_type(uni.Module);
    if (mod is not None) and (vals & self._module_scope_names(mod)) {
        return False;
    }
    for n in scope.get_all_sub_nodes(uni.Name) {
        if (n.value in vals) and (not self._within(n, region)) {
            return False;
        }
    }
    return True;
}

impl PredicateCtrlFlowPass._setup_writes(
    setups: Sequence[uni.CodeBlockStmt]
) -> set[str] {
    out: set[str] = set();
    for s in setups {
        assigns = ([s] if isinstance(s, uni.Assignment) else [])
            + list(s.get_all_sub_nodes(uni.Assignment));
        for a in assigns {
            for t in (a.target or []) {
                out.add(unparse_node(t).replace(' ', ''));
            }
        }
    }
    return out;
}
