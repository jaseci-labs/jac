import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { GraphBreakKind, GraphMendHelper }
import from jaclang.compiler.passes.main.graphmend.torch_attr_table {
    has_torch_compile_decorator,
    is_torch_attr_target
}

impl TrapLoweringPass.before_pass -> None {
    self._enabled = self.prog._compile_options.graphmend;
    if not self._enabled {
        self.prune_signal = True;
    }
}

impl TrapLoweringPass.exit_if_stmt(nd: uni.IfStmt) -> None {
    if not self._enabled {
        return;
    }
    if self.prog.graphmend_breaks.get(id(nd)) != GraphBreakKind.VAL_GUARD {
        return;
    }
    if (not nd.body) or (len(nd.body) != 1) {
        return;
    }
    rs = nd.body[0];
    if not isinstance(rs, uni.RaiseStmt) {
        return;
    }
    cond = nd.condition;
    if not isinstance(cond, uni.UnaryExpr) {
        return;
    }
    if (cond.op is None) or (cond.op.value != 'not') {
        return;
    }
    x = cond.operand;
    msg = self._raise_message(rs, nd);
    wrap = self._enclosing_compiled_fn(nd);
    type_name = self._exception_type_name(rs) if (wrap is not None) else None;
    marked = (
        self._marked_message(nd, msg, type_name) if (type_name is not None) else None
    );
    if marked is None {
        return;
    }
    eq = self._torch_equal_args(x);
    if eq is not None {
        (a, b) = eq;
        self._need_helper(nd, GraphMendHelper.EQ_ASSERT);
        self._replace(nd, [self._eq_assert_stmt(nd, a, b, marked)]);
        self._mark_guard(wrap);
    } elif self._returns_tensor_bool(x) {
        self._replace(nd, [self._assert_async_stmt(nd, x, marked)]);
        self._mark_guard(wrap);
    }
}

impl TrapLoweringPass._enclosing_compiled_fn(nd: uni.UniNode) -> (uni.Ability | None) {
    ab = nd.find_parent_of_type(uni.Ability);
    if (ab is not None) and has_torch_compile_decorator(ab) {
        return ab;
    }
    return None;
}

impl TrapLoweringPass._exception_type_name(rs: uni.RaiseStmt) -> (str | None) {
    cause = rs.cause;
    if cause is None {
        return None;
    }
    target = cause.target if isinstance(cause, uni.FuncCall) else cause;
    if isinstance(target, uni.Name) {
        return target.value;
    }
    if isinstance(target, uni.AtomTrailer) and isinstance(target.right, uni.Name) {
        return target.right.value;
    }
    return None;
}

impl TrapLoweringPass._marked_message(
    at: uni.UniNode, msg: uni.Expr, type_name: str
) -> (uni.String | None) {
    if not isinstance(msg, (uni.String, uni.MultiString)) {
        return None;
    }
    if isinstance(msg, uni.MultiString) {
        for part in msg.strings {
            if not isinstance(part, uni.String) {
                return None;
            }
        }
    }
    text = "[[GM-TRAP " + type_name + "]]" + str(msg.lit_value) + "[[/GM-TRAP]]";
    return self._str(at, text);
}

impl TrapLoweringPass._need_helper(at: uni.UniNode, helper: GraphMendHelper) -> None {
    mod = at.find_parent_of_type(uni.Module);
    if mod is None {
        return;
    }
    needed = self.prog.graphmend_helpers.get(id(mod));
    if needed is None {
        needed = set();
        self.prog.graphmend_helpers[id(mod)] = needed;
    }
    needed.add(helper);
}

impl TrapLoweringPass._mark_guard(ability: (uni.Ability | None)) -> None {
    if ability is None {
        return;
    }
    self._guarded_fns.add(id(ability));
    self._need_helper(ability, GraphMendHelper.TRAP_GUARD);
}

impl TrapLoweringPass.exit_ability(nd: uni.Ability) -> None {
    if not self._enabled {
        return;
    }
    if id(nd) not in self._guarded_fns {
        return;
    }
    dec = self._gen_name(nd, '__jac_trap_guard__');
    nd.decorators = [dec] + list(nd.decorators or []);
    nd.set_kids([dec] + list(nd.kid));
    dec.parent = nd;
}

impl TrapLoweringPass._torch_equal_args(x: uni.Expr) -> (tuple | None) {
    if not isinstance(x, uni.FuncCall) {
        return None;
    }
    call: uni.FuncCall = x;
    if not is_torch_attr_target(call.target, 'equal') {
        return None;
    }
    pos = [
        p
        for p in (call.params or [])
        if not isinstance(p, uni.KWPair)
    ];
    if len(pos) < 2 {
        return None;
    }
    return (pos[0], pos[1]);
}

impl TrapLoweringPass._returns_tensor_bool(x: uni.Expr) -> bool {
    return (
        isinstance(x, uni.FuncCall)
        and isinstance(x.target, uni.AtomTrailer)
        and isinstance(x.target.right, uni.Name)
        and (x.target.right.value in _TENSOR_BOOL_OPS)
    );
}

impl TrapLoweringPass._raise_message(rs: uni.RaiseStmt, at: uni.UniNode) -> uni.Expr {
    cause = rs.cause;
    if isinstance(cause, uni.FuncCall) {
        for p in (cause.params or []) {
            if not isinstance(p, uni.KWPair) {
                return p;
            }
        }
    }
    return self._str(at, '');
}

impl TrapLoweringPass._gen_name(at: uni.UniNode, value: str) -> uni.Name {
    anchor: any = at;
    return uni.Name.gen_stub_from_node(anchor, value);
}

impl TrapLoweringPass._str(at: uni.UniNode, text: str) -> uni.String {
    return uni.String(
        orig_src=at.loc.orig_src,
        name='STRING',
        value=f'"{text}"',
        line=at.loc.first_line,
        end_line=at.loc.last_line,
        col_start=at.loc.col_start,
        col_end=at.loc.col_end,
        pos_start=at.loc.pos_start,
        pos_end=at.loc.pos_end
    );
}

impl TrapLoweringPass._call_stmt(call: uni.FuncCall) -> uni.ExprStmt {
    return uni.ExprStmt(expr=call, in_fstring=False, kid=[call]);
}

impl TrapLoweringPass._eq_assert_stmt(
    at: uni.UniNode, a: uni.Expr, b: uni.Expr, msg: uni.Expr
) -> uni.ExprStmt {
    helper = self._gen_name(at, '__jac_tensor_eq_assert__');
    params = [a, b, msg];
    call = uni.FuncCall(
        target=helper, params=params, genai_call=None, kid=[helper] + params
    );
    return self._call_stmt(call);
}

impl TrapLoweringPass._assert_async_stmt(
    at: uni.UniNode, x: uni.Expr, msg: uni.Expr
) -> uni.ExprStmt {
    torch_nm = self._gen_name(at, 'torch');
    assert_nm = self._gen_name(at, '_assert_async');
    target = uni.AtomTrailer(
        target=torch_nm,
        right=assert_nm,
        is_attr=True,
        is_null_ok=False,
        kid=[torch_nm, assert_nm]
    );
    params = [x, msg];
    call = uni.FuncCall(
        target=target, params=params, genai_call=None, kid=[target] + params
    );
    return self._call_stmt(call);
}

impl TrapLoweringPass._replace(old: uni.UniNode, new_nodes: list) -> None {
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
