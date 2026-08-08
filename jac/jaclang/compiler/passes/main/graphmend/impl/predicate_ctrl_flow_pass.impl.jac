import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { GraphBreakKind, Tokens as Tok }

impl PredicateCtrlFlowPass.before_pass -> None {
    self._enabled = self.prog._compile_options.graphmend;
    if not self._enabled {
        self.prune_signal = True;
    }
}

impl PredicateCtrlFlowPass.exit_if_stmt(nd: uni.IfStmt) -> None {
    if not self._enabled {
        return;
    }
    if self.prog.graphmend_breaks.get(id(nd)) != GraphBreakKind.DYN_CTRL_FL {
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
        if self._setups_safe(tb[:-1], nd) and self._setups_safe(fb[:-1], nd) {
            self._merge_common_call(nd, a_last.expr, b_last.expr, tb[:-1], fb[:-1]);
        }
    }
}

impl PredicateCtrlFlowPass._rewrite_assignment(
    nd: uni.IfStmt, lhs: uni.Name, true_e: uni.Expr, false_e: uni.Expr
) -> None {
    if self._unfixable_call_literal(true_e, false_e) {
        return;
    }
    if self._use_cond(true_e, false_e) {
        (stmts, c_ref) = self._hoist_cond(nd, nd.condition);
        cond_call = self._make_cond(nd, c_ref, true_e, false_e);
        self._replace(nd, stmts + [self._assign(lhs, cond_call)]);
        return;
    }
    (stmts, c_ref, t_ref, f_ref) = self._hoist(nd, nd.condition, true_e, false_e);
    where_call = self._make_where(nd, c_ref, t_ref, f_ref);
    final = self._assign(lhs, where_call);
    self._replace(nd, stmts + [final]);
}

impl PredicateCtrlFlowPass._rewrite_return(
    nd: uni.IfStmt, true_e: uni.Expr, false_e: uni.Expr
) -> None {
    if self._unfixable_call_literal(true_e, false_e) {
        return;
    }
    if self._use_cond(true_e, false_e) {
        (stmts, c_ref) = self._hoist_cond(nd, nd.condition);
        cond_call = self._make_cond(nd, c_ref, true_e, false_e);
        ret = uni.ReturnStmt(expr=cond_call, kid=[cond_call]);
        self._replace(nd, stmts + [ret]);
        return;
    }
    (stmts, c_ref, t_ref, f_ref) = self._hoist(nd, nd.condition, true_e, false_e);
    where_call = self._make_where(nd, c_ref, t_ref, f_ref);
    ret = uni.ReturnStmt(expr=where_call, kid=[where_call]);
    self._replace(nd, stmts + [ret]);
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
    if (ca.target.unparse().replace(' ', '') != cb.target.unparse().replace(' ', '')) {
        return;
    }
    (a_pos, a_kw) = self._split_params(ca.params);
    (b_pos, b_kw) = self._split_params(cb.params);
    if len(a_pos) != len(b_pos) {
        return;
    }
    if set(a_kw.keys()) != set(b_kw.keys()) {
        return;
    }
    for k in a_kw {
        if a_kw[k].value.unparse() != b_kw[k].value.unparse() {
            return;
        }
    }
    diff = [];
    for i in range(len(a_pos)) {
        if a_pos[i].unparse() != b_pos[i].unparse() {
            diff.append(i);
        }
    }
    if not diff {
        return;
    }
    for s in (list(true_setups) + list(false_setups)) {
        if self._is_eq_assert(s) {
            return;
        }
    }
    n = self._counter;
    self._counter += 1;
    cond_tmp = self._gen_name(nd, f"__gm_cond_{n}", True);
    cond_assign = self._assign(cond_tmp, nd.condition);
    merged: list = [];
    for i in range(len(a_pos)) {
        if i in diff {
            cref = self._gen_name(nd, f"__gm_cond_{n}", False);
            merged.append(self._make_where(nd, cref, a_pos[i], b_pos[i]));
        } else {
            merged.append(a_pos[i]);
        }
    }
    new_params = merged;
    for k in a_kw {
        new_params.append(a_kw[k]);
    }
    new_call = uni.FuncCall(
        target=ca.target,
        params=new_params,
        genai_call=None,
        kid=[ca.target] + new_params
    );
    call_stmt = uni.ExprStmt(expr=new_call, in_fstring=False, kid=[new_call]);
    gated_true = self._gate_asserts(list(true_setups), n, True);
    gated_false = self._gate_asserts(list(false_setups), n, False);
    new_nodes = [cond_assign] + gated_true + gated_false + [call_stmt];
    self._replace(nd, new_nodes);
}

impl PredicateCtrlFlowPass._use_cond(true_e: uni.Expr, false_e: uni.Expr) -> bool {
    if isinstance(true_e, uni.Literal) or isinstance(false_e, uni.Literal) {
        return False;
    }
    return self._has_call(true_e) or self._has_call(false_e);
}

impl PredicateCtrlFlowPass._unfixable_call_literal(
    true_e: uni.Expr, false_e: uni.Expr
) -> bool {
    has_lit = isinstance(true_e, uni.Literal) or isinstance(false_e, uni.Literal);
    return has_lit and (self._has_call(true_e) or self._has_call(false_e));
}

impl PredicateCtrlFlowPass._has_call(e: uni.UniNode) -> bool {
    return isinstance(e, uni.FuncCall) or bool(e.get_all_sub_nodes(uni.FuncCall));
}

impl PredicateCtrlFlowPass._has_none(a: uni.Expr, b: uni.Expr) -> bool {
    return isinstance(a, uni.Null) or isinstance(b, uni.Null);
}

impl PredicateCtrlFlowPass._same_lhs(
    a: uni.Assignment, b: uni.Assignment
) -> (uni.Name | None) {
    if (len(a.target) != 1) or (len(b.target) != 1) {
        return None;
    }
    ta = a.target[0];
    tb = b.target[0];
    if (
        isinstance(ta, uni.Name) and isinstance(tb, uni.Name) and (ta.value == tb.value)
    ) {
        return self._gen_name(ta, ta.value, True);
    }
    return None;
}

impl PredicateCtrlFlowPass._split_params(
    params: any
) -> tuple[list[uni.Expr], dict[str, uni.KWPair]] {
    pos: list[uni.Expr] = [];
    kw: dict[str, uni.KWPair] = {};
    for p in (params or []) {
        if isinstance(p, uni.KWPair) {
            if p.key is not None {
                kw[p.key.sym_name] = p;
            }
        } else {
            pos.append(p);
        }
    }
    return (pos, kw);
}

impl PredicateCtrlFlowPass._gen_name(
    at: uni.UniNode, value: str, store: bool
) -> uni.Name {
    anchor: any = at;
    nm = uni.Name.gen_stub_from_node(anchor, value);
    if store {
        nm.expr_ctx = uni.ExprCtx.STORE;
    }
    return nm;
}

impl PredicateCtrlFlowPass._assign(
    target: uni.Name, value: uni.Expr
) -> uni.Assignment {
    return uni.Assignment(
        target=[target], value=value, type_tag=None, mutable=True, kid=[target, value]
    );
}

impl PredicateCtrlFlowPass._make_where(
    at: uni.UniNode, cond: uni.Expr, t: uni.Expr, f: uni.Expr
) -> uni.FuncCall {
    return self._torch_call(at, 'where', [cond, t, f]);
}

impl PredicateCtrlFlowPass._make_cond(
    at: uni.UniNode, pred: uni.Expr, t: uni.Expr, f: uni.Expr
) -> uni.FuncCall {
    torch_nm = self._gen_name(at, 'torch', False);
    cond_nm = self._gen_name(at, 'cond', False);
    target = uni.AtomTrailer(
        target=torch_nm,
        right=cond_nm,
        is_attr=True,
        is_null_ok=False,
        kid=[torch_nm, cond_nm]
    );
    true_fn = uni.LambdaExpr(body=t, signature=None, kid=[t]);
    false_fn = uni.LambdaExpr(body=f, signature=None, kid=[f]);
    operands = uni.TupleVal(
        values=[], kid=[at.gen_token(Tok.LPAREN, '('), at.gen_token(Tok.RPAREN, ')')]
    );
    params = [pred, true_fn, false_fn, operands];
    return uni.FuncCall(
        target=target, params=params, genai_call=None, kid=[target] + params
    );
}

impl PredicateCtrlFlowPass._torch_call(
    at: uni.UniNode, fname: str, args: list
) -> uni.FuncCall {
    torch_nm = self._gen_name(at, 'torch', False);
    fn_nm = self._gen_name(at, fname, False);
    target = uni.AtomTrailer(
        target=torch_nm,
        right=fn_nm,
        is_attr=True,
        is_null_ok=False,
        kid=[torch_nm, fn_nm]
    );
    return uni.FuncCall(
        target=target, params=args, genai_call=None, kid=[target] + args
    );
}

impl PredicateCtrlFlowPass._hoist(
    at: uni.UniNode, cond: uni.Expr, t: uni.Expr, f: uni.Expr
) -> tuple[list, uni.Name, uni.Name, uni.Name] {
    n = self._counter;
    self._counter += 1;
    cond_tmp = self._gen_name(at, f"__gm_cond_{n}", True);
    true_tmp = self._gen_name(at, f"__gm_true_{n}", True);
    false_tmp = self._gen_name(at, f"__gm_false_{n}", True);
    stmts = [
        self._assign(cond_tmp, cond),
        self._assign(true_tmp, t),
        self._assign(false_tmp, f)
    ];
    cond_ref = self._gen_name(at, f"__gm_cond_{n}", False);
    true_ref = self._gen_name(at, f"__gm_true_{n}", False);
    false_ref = self._gen_name(at, f"__gm_false_{n}", False);
    return (stmts, cond_ref, true_ref, false_ref);
}

impl PredicateCtrlFlowPass._hoist_cond(
    at: uni.UniNode, cond: uni.Expr
) -> tuple[list, uni.Name] {
    n = self._counter;
    self._counter += 1;
    cond_tmp = self._gen_name(at, f"__gm_cond_{n}", True);
    cond_ref = self._gen_name(at, f"__gm_cond_{n}", False);
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
    t = call.target;
    return (
        isinstance(t, uni.AtomTrailer)
        and isinstance(t.right, uni.Name)
        and (t.right.value == '_assert_async')
        and isinstance(t.target, uni.Name)
        and (t.target.value == 'torch')
    );
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
    setups: list, n: int, taken_when_true: bool
) -> list {
    out = [];
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
        pos: list[uni.Expr] = [];
        for prm in (call.params or []) {
            if not isinstance(prm, uni.KWPair) {
                pos.append(prm);
            }
        }
        if not pos {
            out.append(s);
            continue;
        }
        check = pos[0];
        cref = self._gen_name(s, f"__gm_cond_{n}", False);
        gate: uni.Expr = (
            self._torch_call(s, 'logical_not', [cref]) if taken_when_true else cref
        );
        new_check = self._torch_call(s, 'logical_or', [gate, check]);
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

impl PredicateCtrlFlowPass._replace(old: uni.UniNode, new_nodes: list) -> None {
    parent = old.parent;
    if parent is None {
        return;
    }
    holder: any = parent;
    body = holder?.body;
    if isinstance(body, list) and (old in body) {
        i = body.index(old);
        setattr(holder, 'body', list(body[:i]) + new_nodes + list(body[(i + 1):]));
    }
    if old in parent.kid {
        j = parent.kid.index(old);
        parent.set_kids(list(parent.kid[:j]) + new_nodes + list(parent.kid[(j + 1):]));
    }
    for child in new_nodes {
        child.parent = parent;
    }
}
