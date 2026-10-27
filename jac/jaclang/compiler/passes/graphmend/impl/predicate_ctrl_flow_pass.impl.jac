impl PredicateCtrlFlowPass.prepare with entry {
    self._enabled = (self.prog.options.graphmend is True)
        and "where" not in (self.prog.options.graphmend_disable or []);
    if not self._enabled {
        disengage;
    }
    self._autograd_reachable = module_reaches_autograd(self.module)
        or self._wrapped_from_training();
}

impl PredicateCtrlFlowPass.exit_if_stmt with uni.IfStmt exit {
    nd = here;
    if not self._enabled {
        return;
    }
    if facts_for(nd).breaks.get(nd) != GraphBreakKind.DYN_CTRL_FL {
        return;
    }
    if not torch_binds_name(nd) {
        return;
    }
    if self._autograd_reachable and (not region_in_inference_ctx(nd)) {
        return;
    }
    eb = nd.else_body;
    if (eb is None) or (not isinstance(eb, uni.ElseStmt)) {
        return;
    }
    tb = nd.body;
    fb = eb.body;
    if (not tb) or (not fb) {
        return;
    }
    if cond_materializes_scalar(nd.condition) {
        return;
    }
    if not self._bool_tensor(nd.condition, set(), 0) {
        return;
    }
    if (len(tb) == 1) and (len(fb) == 1) {
        a0 = tb[0];
        b0 = fb[0];
        if isinstance(a0, uni.Assignment) and isinstance(b0, uni.Assignment) {
            lhs = self._same_lhs(a0, b0);
            av = a0.value;
            bv = b0.value;
            if (lhs is not None)
                and isinstance(av, uni.Expr)
                and isinstance(bv, uni.Expr)
                and (not self._has_none(av, bv)) {
                self._rewrite_assignment(nd, lhs, av, bv);
            }
        } elif isinstance(a0, uni.ReturnStmt) and isinstance(b0, uni.ReturnStmt) {
            if (a0.expr is not None)
                and (b0.expr is not None)
                and (not self._has_none(a0.expr, b0.expr)) {
                self._rewrite_return(nd, a0.expr, b0.expr);
            }
        } elif isinstance(a0, uni.ExprStmt) and isinstance(b0, uni.ExprStmt) {
            self._merge_common_call(nd, a0.expr, b0.expr, [], []);
        }
        return;
    }
    a_last = tb[-1];
    b_last = fb[-1];
    if isinstance(a_last, uni.ExprStmt) and isinstance(b_last, uni.ExprStmt) {
        (ts, fs) = (tb[:-1], fb[:-1]);
        if (not (self._setup_writes(ts) & self._setup_writes(fs)))
            and self._setups_safe(ts, nd)
            and self._setups_safe(fs, nd) {
            self._merge_common_call(nd, a_last.expr, b_last.expr, ts, fs);
        }
    }
}

impl PredicateCtrlFlowPass._rewrite_assignment(
    nd: uni.IfStmt, lhs: uni.Name, true_e: uni.Expr, false_e: uni.Expr
) -> None {
    if self._has_call(true_e) or self._has_call(false_e) {
        return;
    }
    if self._provably_non_tensor(true_e) or self._provably_non_tensor(false_e) {
        return;
    }
    if self._shape_divergent(true_e, false_e) {
        return;
    }
    (stmts, c_ref, t_ref, f_ref) = self._hoist(nd, nd.condition, true_e, false_e);
    where_call = torch_call(nd, 'where', [c_ref, t_ref, f_ref]);
    replace_stmt(nd, stmts + [self._assign(lhs, where_call)]);
}

impl PredicateCtrlFlowPass._rewrite_return(
    nd: uni.IfStmt, true_e: uni.Expr, false_e: uni.Expr
) -> None {
    if self._has_call(true_e) or self._has_call(false_e) {
        return;
    }
    if self._provably_non_tensor(true_e) or self._provably_non_tensor(false_e) {
        return;
    }
    if self._shape_divergent(true_e, false_e) {
        return;
    }
    (stmts, c_ref, t_ref, f_ref) = self._hoist(nd, nd.condition, true_e, false_e);
    where_call = torch_call(nd, 'where', [c_ref, t_ref, f_ref]);
    ret = uni.ReturnStmt(expr=where_call, kid=[where_call]);
    replace_stmt(nd, stmts + [ret]);
}

impl PredicateCtrlFlowPass._has_unpack(call: uni.FuncCall) -> bool {
    for p in (call.params or []) {
        if isinstance(p, uni.KWPair) {
            if p.key is None {
                return True;
            }
        } elif isinstance(p, uni.UnaryExpr)
            and (p.op.name in [Tok.STAR_MUL, Tok.STAR_POW]) {
            return True;
        }
    }
    return False;
}

impl PredicateCtrlFlowPass._merge_common_call(
    nd: uni.IfStmt,
    ca: uni.Expr,
    cb: uni.Expr,
    true_setups: Sequence[uni.CodeBlockStmt],
    false_setups: Sequence[uni.CodeBlockStmt]
) -> None {
    if (not isinstance(ca, uni.FuncCall)) or (not isinstance(cb, uni.FuncCall)) {
        return;
    }
    if self._has_unpack(ca) or self._has_unpack(cb) {
        return;
    }
    if (
        unparse_node(ca.target).replace(' ', '')
        != unparse_node(cb.target).replace(' ', '')
    ) {
        return;
    }
    (a_pos, a_kw) = split_params_keyed(ca.params);
    (b_pos, b_kw) = split_params_keyed(cb.params);
    if len(a_pos) != len(b_pos) {
        return;
    }
    if set(a_kw.keys()) != set(b_kw.keys()) {
        return;
    }
    for k in a_kw {
        if unparse_node(a_kw[k].value) != unparse_node(b_kw[k].value) {
            return;
        }
    }
    diff = [];
    for i in range(len(a_pos)) {
        if unparse_node(a_pos[i]) != unparse_node(b_pos[i]) {
            diff.append(i);
        }
    }
    if not diff {
        return;
    }
    for i in diff {
        if self._has_call(a_pos[i]) or self._has_call(b_pos[i]) {
            return;
        }
        if self._provably_non_tensor(a_pos[i]) or self._provably_non_tensor(b_pos[i]) {
            return;
        }
        if self._shape_divergent(a_pos[i], b_pos[i]) {
            return;
        }
    }
    for s in (list(true_setups) + list(false_setups)) {
        if self._is_eq_assert(s) {
            return;
        }
    }
    n = self._counter;
    self._counter += 1;
    cond_tmp = gen_name(nd, f"__gm_cond_{n}", True);
    cond_assign = self._assign(cond_tmp, nd.condition);
    merged: list[uni.Expr | uni.KWPair] = [];
    for i in range(len(a_pos)) {
        if i in diff {
            cref = gen_name(nd, f"__gm_cond_{n}", False);
            merged.append(torch_call(nd, 'where', [cref, a_pos[i], b_pos[i]]));
        } else {
            merged.append(a_pos[i]);
        }
    }
    for k in a_kw {
        merged.append(a_kw[k]);
    }
    new_call = uni.FuncCall(
        target=ca.target, params=merged, genai_call=None, kid=[ca.target] + merged
    );
    call_stmt = uni.ExprStmt(expr=new_call, in_fstring=False, kid=[new_call]);
    gated_true = self._gate_asserts(list(true_setups), n, True);
    gated_false = self._gate_asserts(list(false_setups), n, False);
    new_nodes = [cond_assign] + gated_true + gated_false + [call_stmt];
    replace_stmt(nd, new_nodes);
}

impl PredicateCtrlFlowPass._has_call(e: uni.UniNode) -> bool {
    return isinstance(e, uni.FuncCall) or bool(e.get_all_sub_nodes(uni.FuncCall));
}

impl PredicateCtrlFlowPass._has_none(a: uni.Expr, b: uni.Expr) -> bool {
    return isinstance(a, uni.Null) or isinstance(b, uni.Null);
}

impl PredicateCtrlFlowPass._provably_non_tensor(e: uni.Expr) -> bool {
    return self._scalar_literal(e) or self._non_tensor_container(e);
}

impl PredicateCtrlFlowPass._shape_divergent(a: uni.Expr, b: uni.Expr) -> bool {
    return self._subscript_texts(a) != self._subscript_texts(b);
}

impl PredicateCtrlFlowPass._subscript_texts(e: uni.Expr) -> set[str] {
    out: set[str] = set();
    for t in [e] + list(e.get_all_sub_nodes(uni.AtomTrailer)) {
        if isinstance(t, uni.AtomTrailer) and isinstance(t.right, uni.IndexSlice) {
            out.add(unparse_node(t).replace(' ', ''));
        }
    }
    return out;
}

impl PredicateCtrlFlowPass._wrapped_from_training -> bool {
    seen: set[str] = set();
    for m in self.prog.mod.hub.values() {
        if (m is self.module) or (not module_reaches_autograd(m)) {
            continue;
        }
        for call in m.get_all_sub_nodes(uni.FuncCall) {
            if not is_torch_attr_target(call.target, 'compile') {
                continue;
            }
            `entry = resolve_wrapped_entry(self.prog, call, seen);
            if (`entry is not None)
                and (`entry.find_parent_of_type(uni.Module) is self.module) {
                return True;
            }
        }
    }
    return False;
}

impl PredicateCtrlFlowPass._scalar_literal(e: uni.Expr) -> bool {
    if isinstance(e, uni.AtomUnit) {
        inner = e.value;
        return isinstance(inner, uni.Expr) and self._scalar_literal(inner);
    }
    if isinstance(e, uni.UnaryExpr) {
        return (e.op is not None)
            and (e.op.name in [Tok.PLUS, Tok.MINUS, Tok.BW_NOT, Tok.NOT])
            and self._scalar_literal(e.operand);
    }
    return isinstance(e, (uni.Int, uni.Float, uni.Bool));
}

impl PredicateCtrlFlowPass._non_tensor_container(e: uni.Expr) -> bool {
    if isinstance(e, uni.AtomUnit) {
        inner = e.value;
        return isinstance(inner, uni.Expr) and self._non_tensor_container(inner);
    }
    if isinstance(
        e,
        (
            uni.String,
            uni.MultiString,
            uni.FString,
            uni.ListVal,
            uni.SetVal,
            uni.TupleVal,
            uni.DictVal,
            uni.ListCompr,
            uni.DictCompr
        )
    ) {
        return True;
    }
    if isinstance(e, uni.BinaryExpr) {
        return self._non_tensor_container(e.left)
            or self._non_tensor_container(e.right);
    }
    return False;
}

impl PredicateCtrlFlowPass._same_lhs(
    a: uni.Assignment, b: uni.Assignment
) -> (uni.Name | None) {
    if (len(a.target) != 1) or (len(b.target) != 1) {
        return None;
    }
    if (a.aug_op is not None) or (b.aug_op is not None) {
        return None;
    }
    ta = a.target[0];
    tb = b.target[0];
    if (
        isinstance(ta, uni.Name) and isinstance(tb, uni.Name) and (ta.value == tb.value)
    ) {
        return gen_name(ta, ta.value, True);
    }
    return None;
}

impl PredicateCtrlFlowPass._bool_tensor(
    e: uni.Expr, seen: set[str], depth: int
) -> bool {
    if depth > 10 {
        return False;
    }
    if isinstance(e, uni.AtomUnit) {
        inner = e.value;
        return isinstance(inner, uni.Expr)
            and self._bool_tensor(inner, seen, depth + 1);
    }
    if isinstance(e, uni.CompareExpr) {
        if (len(e.ops) != 1)
            or (
                e.ops[0].name not in [Tok.LT, Tok.LTE, Tok.GT, Tok.GTE, Tok.EE, Tok.NE]
            ) {
            return False;
        }
        for side in [e.left] + list(e.rights) {
            if not self._python_valued(side, set(), 0) {
                return True;
            }
        }
        return False;
    }
    if isinstance(e, uni.UnaryExpr) {
        return (e.op.name == Tok.BW_NOT)
            and self._bool_tensor(e.operand, seen, depth + 1);
    }
    if isinstance(e, uni.BinaryExpr) {
        return isinstance(e.op, uni.Token)
            and (e.op.name in [Tok.BW_AND, Tok.BW_OR, Tok.BW_XOR])
            and self._bool_tensor(e.left, seen, depth + 1)
            and self._bool_tensor(e.right, seen, depth + 1);
    }
    if isinstance(e, uni.FuncCall) {
        t = e.target;
        return isinstance(t, uni.AtomTrailer)
            and t.is_attr
            and isinstance(t.right, uni.Name)
            and (t.right.value in _BOOL_TENSOR_FNS)
            and not self._foreign_module_call(e);
    }
    if (not isinstance(e, uni.Name)) or (e.value in seen) {
        return False;
    }
    st = e.sym_tab;
    sym = st.lookup(e.value, deep=True) if st else None;
    if (sym is None) or symbol_is_builtin(sym) or (len(sym.defn) != 1) {
        return False;
    }
    seen.add(e.value);
    assign = defining_assignment(sym);
    return (assign is not None)
        and isinstance(assign.value, uni.Expr)
        and self._bool_tensor(assign.value, seen, depth + 1);
}

impl PredicateCtrlFlowPass._foreign_module_call(c: uni.FuncCall) -> bool {
    base: uni.Expr = c.target;
    while isinstance(base, uni.AtomTrailer) {
        base = base.target;
    }
    if (not isinstance(base, uni.Name)) or (not base.sym_tab) {
        return False;
    }
    sym = base.sym_tab.lookup(base.value, deep=True);
    decl = sym.decl if (sym is not None) else None;
    if decl is None {
        return False;
    }
    imp = decl.find_parent_of_type(uni.Import);
    if imp is None {
        return False;
    }
    mp = decl.find_parent_of_type(uni.ModulePath) or imp.from_loc;
    path = mp.dot_path_str if (mp is not None) else "";
    return not ((path == 'torch') or path.startswith('torch.'));
}

impl PredicateCtrlFlowPass._python_valued(
    e: uni.Expr, seen: set[str], depth: int
) -> bool {
    if depth > 10 {
        return False;
    }
    if isinstance(e, uni.AtomUnit) {
        inner = e.value;
        return isinstance(inner, uni.Expr)
            and self._python_valued(inner, seen, depth + 1);
    }
    if isinstance(e, (uni.Literal, uni.BoolExpr)) {
        return True;
    }
    if isinstance(e, uni.UnaryExpr) {
        return (e.op.name == Tok.NOT)
            or self._python_valued(e.operand, seen, depth + 1);
    }
    if isinstance(e, uni.CompareExpr) {
        for side in [e.left] + list(e.rights) {
            if not self._python_valued(side, seen, depth + 1) {
                return False;
            }
        }
        return True;
    }
    if isinstance(e, uni.BinaryExpr) {
        return self._python_valued(e.left, seen, depth + 1)
            and self._python_valued(e.right, seen, depth + 1);
    }
    if isinstance(e, uni.FuncCall) {
        return (
            isinstance(e.target, uni.Name) and (e.target.value in _PY_VALUE_BUILTINS)
        )
            or self._foreign_module_call(e);
    }
    if (not isinstance(e, uni.Name)) or (e.value in seen) {
        return False;
    }
    st = e.sym_tab;
    sym = st.lookup(e.value, deep=True) if st else None;
    if (sym is None) or symbol_is_builtin(sym) or (len(sym.defn) != 1) {
        return False;
    }
    seen.add(e.value);
    assign = defining_assignment(sym);
    return (assign is not None)
        and isinstance(assign.value, uni.Expr)
        and self._python_valued(assign.value, seen, depth + 1);
}

impl PredicateCtrlFlowPass._assign(
    target: uni.Name, value: uni.Expr
) -> uni.Assignment {
    return uni.Assignment(
        target=[target], value=value, type_tag=None, mutable=True, kid=[target, value]
    );
}

impl PredicateCtrlFlowPass._hoist(
    at: uni.UniNode, cond: uni.Expr, t: uni.Expr, f: uni.Expr
) -> tuple[list[uni.CodeBlockStmt], uni.Name, uni.Name, uni.Name] {
    n = self._counter;
    (stmts, cond_ref) = self._hoist_cond(at, cond);
    true_tmp = gen_name(at, f"__gm_true_{n}", True);
    false_tmp = gen_name(at, f"__gm_false_{n}", True);
    stmts = stmts + [self._assign(true_tmp, t), self._assign(false_tmp, f)];
    true_ref = gen_name(at, f"__gm_true_{n}", False);
    false_ref = gen_name(at, f"__gm_false_{n}", False);
    return (stmts, cond_ref, true_ref, false_ref);
}

impl PredicateCtrlFlowPass._hoist_cond(
    at: uni.UniNode, cond: uni.Expr
) -> tuple[list[uni.CodeBlockStmt], uni.Name] {
    n = self._counter;
    self._counter += 1;
    cond_tmp = gen_name(at, f"__gm_cond_{n}", True);
    cond_ref = gen_name(at, f"__gm_cond_{n}", False);
    return ([self._assign(cond_tmp, cond)], cond_ref);
}

impl PredicateCtrlFlowPass._is_assert_async(stmt: uni.UniNode) -> bool {
    if not isinstance(stmt, uni.ExprStmt) {
        return False;
    }
    call = stmt.expr;
    if not isinstance(call, uni.FuncCall) {
        return False;
    }
    return is_torch_attr_target(call.target, '_assert_async');
}

impl PredicateCtrlFlowPass._is_eq_assert(stmt: uni.UniNode) -> bool {
    if not isinstance(stmt, uni.ExprStmt) {
        return False;
    }
    call = stmt.expr;
    return (
        isinstance(call, uni.FuncCall)
        and isinstance(call.target, uni.Name)
        and (call.target.value == '__jac_tensor_eq_assert__')
    );
}

impl PredicateCtrlFlowPass._gate_asserts(
    setups: list[uni.CodeBlockStmt], n: int, taken_when_true: bool
) -> list[uni.CodeBlockStmt] {
    out: list[uni.CodeBlockStmt] = [];
    for s in setups {
        if (not self._is_assert_async(s)) or (not isinstance(s, uni.ExprStmt)) {
            out.append(s);
            continue;
        }
        call = s.expr;
        if not isinstance(call, uni.FuncCall) {
            out.append(s);
            continue;
        }
        pos = split_params(call.params)[0];
        if not pos {
            out.append(s);
            continue;
        }
        check = pos[0];
        cref = gen_name(s, f"__gm_cond_{n}", False);
        gate: uni.Expr = (
            torch_call(s, 'logical_not', [cref]) if taken_when_true else cref
        );
        new_check = torch_call(s, 'logical_or', [gate, check]);
        new_params = [new_check] + list(call.params[1:]);
        new_call = uni.FuncCall(
            target=call.target,
            params=new_params,
            genai_call=None,
            kid=[call.target] + new_params
        );
        out.append(uni.ExprStmt(expr=new_call, in_fstring=False, kid=[new_call]));
    }
    return out;
}
