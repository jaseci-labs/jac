import builtins;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { GraphBreakKind, GraphMendHelper }
import from jaclang.compiler.passes.main.graphmend.ast_edit {
    facts_for,
    gen_name,
    gen_string,
    insert_after,
    need_helper,
    replace_stmt,
    split_params,
    torch_call
}
import from jaclang.compiler.passes.main.graphmend.scope_facts {
    claim_chain_reaches,
    entry_key,
    entry_module,
    param_annotation
}
import from jaclang.compiler.passes.main.graphmend.torch_attr_table {
    defining_assignment,
    has_torch_compile_decorator,
    is_torch_attr_target
}

impl TrapLoweringPass.exit_assignment(nd: uni.Assignment) -> None {
    if not self._enabled {
        return;
    }
    value = nd.value;
    if (
        (not isinstance(value, uni.FuncCall))
        or (not is_torch_attr_target(value.target, 'compile'))
    ) {
        return;
    }
    if (not nd.target) or (len(nd.target) != 1) {
        return;
    }
    tgt = nd.target[0];
    if not isinstance(tgt, uni.Name) {
        return;
    }
    if not insert_after(nd, self._boundary_attach_stmt(nd, tgt.value)) {
        return;
    }
    need_helper(nd, GraphMendHelper.TRAP_GUARD);
}

impl TrapLoweringPass._boundary_attach_stmt(
    at: uni.UniNode, name: str
) -> uni.Assignment {
    store = self._gen_name(at, name);
    store.expr_ctx = uni.ExprCtx.STORE;
    guard = self._gen_name(at, '__jac_trap_guard__');
    arg = self._gen_name(at, name);
    call = uni.FuncCall(target=guard, params=[arg], genai_call=None, kid=[guard, arg]);
    return uni.Assignment(
        target=[store], value=call, type_tag=None, mutable=True, kid=[store, call]
    );
}

impl TrapLoweringPass.before_pass -> None {
    self._enabled = (self.prog._compile_options.graphmend is True)
        and "trap" not in (self.prog._compile_options.graphmend_disable or []);
    if not self._enabled {
        self.prune_signal = True;
    }
}

impl TrapLoweringPass.exit_if_stmt(nd: uni.IfStmt) -> None {
    if not self._enabled {
        return;
    }
    if facts_for(nd).breaks.get(nd) != GraphBreakKind.VAL_GUARD {
        return;
    }
    if self._inside_try(nd) {
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
    negated_compare = False;
    x: (uni.Expr | None) = None;
    if isinstance(cond, uni.UnaryExpr)
        and (cond.op is not None)
        and (cond.op.value == 'not') {
        x = cond.operand;
    } elif self._condition_is_tensor(cond, nd) {
        x = torch_call(nd, 'logical_not', [cond]);
        negated_compare = True;
    }
    if x is None {
        return;
    }
    msg = self._raise_message(rs);
    wrap = self._boundary_ability(nd);
    covered = (wrap is not None) or self._call_site_covered(nd);
    type_name = self._exception_type_name(rs) if covered else None;
    marked = (
        self._marked_message(nd, msg, type_name)
            if ((type_name is not None) and (msg is not None))
            else None
    );
    if marked is None {
        return;
    }
    if not self._torch_binds_module(nd) {
        return;
    }
    eq = self._torch_equal_args(x);
    if eq is not None {
        (a, b) = eq;
        need_helper(nd, GraphMendHelper.EQ_ASSERT);
        replace_stmt(nd, [self._eq_assert_stmt(nd, a, b, marked)]);
        self._mark_guard(wrap);
    } elif negated_compare {
        replace_stmt(nd, [self._assert_async_stmt(nd, x, marked)]);
        self._mark_guard(wrap);
    } elif self._returns_tensor_bool(x) and self._tensor_receiver_provable(x, nd) {
        replace_stmt(nd, [self._assert_async_stmt(nd, x, marked)]);
        self._mark_guard(wrap);
    }
}

impl TrapLoweringPass._inside_try(nd: uni.UniNode) -> bool {
    tp = nd.find_parent_of_type(uni.TryStmt);
    return (tp is not None)
        and (
            tp.find_parent_of_type(uni.Ability) is nd.find_parent_of_type(uni.Ability)
        );
}

impl TrapLoweringPass._boundary_ability(nd: uni.UniNode) -> (uni.Ability | None) {
    ab = nd.find_parent_of_type(uni.Ability);
    if ab is None {
        return None;
    }
    if has_torch_compile_decorator(ab) {
        return ab;
    }
    seed = facts_for(ab).boundary.get(ab);
    if (seed is None) or (not has_torch_compile_decorator(seed)) {
        return None;
    }
    return seed if (seed.find_parent_of_type(uni.Module) is self.ir_in) else None;
}

impl TrapLoweringPass._call_site_covered(nd: uni.UniNode) -> bool {
    return self._covering_entry(nd) is not None;
}

impl TrapLoweringPass._covering_entry(nd: uni.UniNode) -> (str | None) {
    ab = nd.find_parent_of_type(uni.Ability);
    if ab is None {
        return None;
    }
    facts = facts_for(ab);
    bound = facts.boundary.get(ab);
    if bound is None {
        return None;
    }
    site_key = entry_key(ab);
    root_key = entry_key(bound);
    if root_key in facts.wrapped_keys {
        facts.covered_by[site_key] = root_key;
        return root_key;
    }
    guard_mod = entry_module(site_key);
    for wrapped in sorted(facts.wrapped_keys) {
        if claim_chain_reaches(self.prog, entry_module(wrapped), guard_mod) {
            facts.covered_by[site_key] = wrapped;
            return wrapped;
        }
    }
    return None;
}

impl TrapLoweringPass._exception_type_name(rs: uni.RaiseStmt) -> (str | None) {
    cause = rs.cause;
    if cause is None {
        return None;
    }
    target = cause.target if isinstance(cause, uni.FuncCall) else cause;
    if not isinstance(target, uni.Name) {
        return None;
    }
    if target.sym is not None {
        return None;
    }
    cls = getattr(builtins, target.value, None);
    if isinstance(cls, type) and issubclass(cls, BaseException) {
        return target.value;
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
    lit = str(msg.lit_value);
    if "[[/GM-TRAP]]" in lit {
        return None;
    }
    text = "[[GM-TRAP " + type_name + "]]" + lit + "[[/GM-TRAP]]";
    return self._str(at, text);
}

impl TrapLoweringPass._mark_guard(ability: (uni.Ability | None)) -> None {
    if ability is None {
        return;
    }
    for known in self._guarded_fns {
        if known is ability {
            return;
        }
    }
    self._guarded_fns.append(ability);
    need_helper(ability, GraphMendHelper.TRAP_GUARD);
}

impl TrapLoweringPass.after_pass -> None {
    for ab in self._guarded_fns {
        dec = self._gen_name(ab, '__jac_trap_guard__');
        ab.decorators = [dec] + list(ab.decorators or []);
        ab.set_kids([dec] + list(ab.kid));
        dec.parent = ab;
    }
    self._guarded_fns = [];
}

impl TrapLoweringPass._torch_equal_args(x: uni.Expr) -> (tuple | None) {
    if not isinstance(x, uni.FuncCall) {
        return None;
    }
    call: uni.FuncCall = x;
    if not is_torch_attr_target(call.target, 'equal') {
        return None;
    }
    pos = split_params(call.params)[0];
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

impl TrapLoweringPass._raise_message(rs: uni.RaiseStmt) -> (uni.Expr | None) {
    if rs.from_target is not None {
        return None;
    }
    cause = rs.cause;
    if not isinstance(cause, uni.FuncCall) {
        return None;
    }
    call: uni.FuncCall = cause;
    pos = split_params(call.params)[0];
    if (len(pos) != 1) or (len(pos) != len(call.params or [])) {
        return None;
    }
    return pos[0];
}

impl TrapLoweringPass._gen_name(at: uni.UniNode, value: str) -> uni.Name {
    return gen_name(at, value, False);
}

impl TrapLoweringPass._str(at: uni.UniNode, text: str) -> uni.String {
    esc = text.encode('unicode_escape').decode('ascii').replace('"', '\\"');
    return gen_string(at, f'"{esc}"');
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

impl TrapLoweringPass._condition_is_tensor(cond: uni.Expr, site: uni.UniNode) -> bool {
    if isinstance(cond, uni.AtomUnit) and isinstance(cond.value, uni.Expr) {
        return self._condition_is_tensor(cond.value, site);
    }
    if isinstance(cond, uni.CompareExpr) {
        if len(cond.ops or []) != 1 {
            return False;
        }
        if cond.ops[0].value not in {'==', '!=', '<', '>', '<=', '>='} {
            return False;
        }
        operands = [cond.left] + list(cond.rights or []);
        for e in operands {
            if self._operand_is_tensor(e, site) {
                return True;
            }
        }
    }
    return False;
}

impl TrapLoweringPass._operand_is_tensor(e: uni.Expr, site: uni.UniNode) -> bool {
    if isinstance(e, uni.AtomUnit) and isinstance(e.value, uni.Expr) {
        return self._operand_is_tensor(e.value, site);
    }
    if self._returns_tensor_bool(e) or isinstance(e, uni.FuncCall) {
        if self._tensor_receiver_provable(e, site) {
            return True;
        }
    }
    return self._tensor_expr_provable(e, site);
}

impl TrapLoweringPass._tensor_receiver_provable(
    x: uni.Expr, site: uni.UniNode
) -> bool {
    if not (isinstance(x, uni.FuncCall) and isinstance(x.target, uni.AtomTrailer)) {
        return False;
    }
    return self._tensor_expr_provable(x.target.target, site);
}

impl TrapLoweringPass._tensor_expr_provable(e: uni.Expr, site: uni.UniNode) -> bool {
    if isinstance(e, uni.AtomUnit) and isinstance(e.value, uni.Expr) {
        return self._tensor_expr_provable(e.value, site);
    }
    if isinstance(e, uni.Name) {
        if self._param_is_tensor(e.value, site) {
            return True;
        }
        return self._assigned_tensor_provable(e, site);
    }
    if isinstance(e, uni.BinaryExpr) {
        return self._tensor_expr_provable(e.left, site)
            or self._tensor_expr_provable(e.right, site);
    }
    if isinstance(e, uni.CompareExpr) {
        if self._tensor_expr_provable(e.left, site) {
            return True;
        }
        for r in (e.rights or []) {
            if self._tensor_expr_provable(r, site) {
                return True;
            }
        }
        return False;
    }
    return False;
}

impl TrapLoweringPass._assigned_tensor_provable(
    nm: uni.Name, site: uni.UniNode
) -> bool {
    if nm.value in self._tensor_trace {
        return False;
    }
    st = nm.sym_tab;
    sym = st.lookup(nm.value, deep=True) if st else None;
    if sym is None {
        return False;
    }
    if len(sym.defn) > 1 {
        return False;
    }
    assign = defining_assignment(sym);
    if (assign is None) or (assign.value is None) {
        return False;
    }
    self._tensor_trace.add(nm.value);
    try {
        return self._tensor_expr_provable(assign.value, site);
    } finally {
        self._tensor_trace.discard(nm.value);
    }
}

impl TrapLoweringPass._param_is_tensor(name: str, site: uni.UniNode) -> bool {
    ab = site.find_parent_of_type(uni.Ability);
    if ab is None {
        return False;
    }
    ann = param_annotation(ab, name);
    if isinstance(ann, uni.Name) {
        return self._binds_torch_tensor(ann);
    }
    return is_torch_attr_target(ann, 'Tensor');
}

impl TrapLoweringPass._torch_binds_module(site: uni.UniNode) -> bool {
    sym = site.sym_tab.lookup('torch');
    decl = sym.decl if (sym is not None) else None;
    mp = decl.find_parent_of_type(uni.ModulePath) if (decl is not None) else None;
    if (mp is None) or mp.is_import_from or (mp.alias is not None) {
        return False;
    }
    return mp.dot_path_str == 'torch';
}

impl TrapLoweringPass._binds_torch_tensor(ann: uni.Name) -> bool {
    decl = ann.sym.decl if (ann.sym is not None) else None;
    mi = decl.find_parent_of_type(uni.ModuleItem) if (decl is not None) else None;
    if mi is None {
        return False;
    }
    if not (isinstance(mi.name, uni.Name) and (mi.name.value == 'Tensor')) {
        return False;
    }
    mp = mi.parent.from_loc if isinstance(mi.parent, uni.Import) else None;
    return (mp is not None) and (mp.dot_path_str == 'torch');
}
