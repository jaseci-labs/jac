impl DeferSideEffectPass._is_logger_call(nd: uni.FuncCall) -> bool {
    t = nd.target;
    if not isinstance(t, uni.AtomTrailer) {
        return False;
    }
    if (not isinstance(t.right, uni.Name))
        or (t.right.value not in self._LOG_METHODS) {
        return False;
    }
    base = t.target;
    return isinstance(base, uni.Name)
        and (base.value not in {'self', 'cls'})
        and self._base_binds_at_module(base);
}

impl DeferSideEffectPass._base_binds_at_module(base: uni.Name) -> bool {
    sym = base.sym;
    if sym is None {
        return False;
    }
    decl = sym.decl;
    return (decl is not None) and (decl.enclosing_decl(uni.Ability) is None);
}

impl DeferSideEffectPass._stays_eager(nd: uni.FuncCall, ability: uni.Ability) -> bool {
    if (not isinstance(nd.parent, uni.ExprStmt)) or self._has_unpack(nd) {
        return True;
    }
    if self._decline_call(nd) {
        return True;
    }
    return self._is_logger_call(nd)
        and (ability.sym_name == 'forward')
        and (not self._logger_bound_before(nd));
}

impl DeferSideEffectPass._decline_call(nd: uni.FuncCall) -> bool {
    if not torch_binds_name(nd) {
        return True;
    }
    t = nd.target;
    if isinstance(t, uni.AtomTrailer)
        and isinstance(t.right, uni.Name)
        and (t.right.value == 'exception') {
        return True;
    }
    for kw in split_params(nd.params)[1] {
        if kw.key is None {
            continue;
        }
        k = kw.key.sym_name;
        if k in ('exc_info', 'stack_info') {
            return True;
        }
        if (k == 'file')
            and (
                unparse_node(kw.value).replace(' ', '')
                not in ('sys.stdout', 'sys.stderr')
            ) {
            return True;
        }
    }
    return False;
}

impl DeferSideEffectPass._logger_bound_before(nd: uni.FuncCall) -> bool {
    t = nd.target;
    if not (isinstance(t, uni.AtomTrailer) and isinstance(t.target, uni.Name)) {
        return False;
    }
    sym = t.target.sym;
    if (sym is None) or (sym.decl is None) or (len(sym.defn) > 1) {
        return False;
    }
    mod = nd.find_parent_of_type(uni.Module);
    anchor = self._toplevel_archetype(nd);
    if (mod is None) or (anchor is None) or (anchor.parent is not mod) {
        return True;
    }
    top: (uni.UniNode | None) = sym.decl;
    while (top is not None) and (top.parent is not mod) {
        top = top.parent;
    }
    for k in [mod->:Kid:->] {
        if k is top {
            return True;
        }
        if k is anchor {
            return False;
        }
    }
    return False;
}

impl DeferSideEffectPass._logger_emit(nd: uni.FuncCall) -> (uni.FuncCall | None) {
    callee = nd.target;
    n = self._counter;
    self._counter += 1;
    slot_name = f"_gm_log_slot_{n}";
    reg = self._register_assignment(nd, slot_name, callee);
    self._pending_regs.append((self._toplevel_archetype(nd), reg));
    need_helper(nd, GraphMendHelper.LOG_EMIT);
    (pos, kws, hoists) = self._snapshot_args(nd);
    stmt = nd.parent;
    if stmt is not None {
        for h in hoists {
            insert_before(stmt, h);
        }
    }
    emit = gen_name(nd, '__jac_log_emit__', False);
    slot_ref = gen_name(nd, slot_name, False);
    args_tuple = self._tuple(nd, pos);
    kwargs_dict = self._dict_from_kws(nd, kws);
    params: list[uni.Expr] = [slot_ref, args_tuple, kwargs_dict];
    return uni.FuncCall(
        target=emit, params=params, genai_call=None, kid=[emit] + params
    );
}

impl DeferSideEffectPass._register_assignment(
    at: uni.UniNode, slot_name: str, callee: uni.Expr
) -> uni.Assignment {
    need_helper(at, GraphMendHelper.LOG_REGISTER);
    reg_fn = gen_name(at, '__jac_log_register__', False);
    reg_call = uni.FuncCall(
        target=reg_fn, params=[callee], genai_call=None, kid=[reg_fn, callee]
    );
    slot = gen_name(at, slot_name, True);
    return uni.Assignment(
        target=[slot], value=reg_call, type_tag=None, mutable=True, kid=[slot, reg_call]
    );
}

impl DeferSideEffectPass._toplevel_archetype(
    nd: uni.UniNode
) -> (uni.Archetype | None) {
    mod = nd.find_parent_of_type(uni.Module);
    top: (uni.Archetype | None) = None;
    cur: (uni.Archetype | None) = nd.enclosing_decl(uni.Archetype);
    while (cur is not None) and (cur.find_parent_of_type(uni.Module) is mod) {
        top = cur;
        cur = cur.enclosing_decl(uni.Archetype);
    }
    return top;
}

impl DeferSideEffectPass.exit_assignment with uni.Assignment exit {
    nd = here;
    if (not self._enabled) or (not torch_binds_name(nd)) {
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
    hooks: list[uni.CodeBlockStmt] = [
        self._pre_hook_register_stmt(nd, tgt.value),
        self._hook_register_stmt(nd, tgt.value)
    ];
    if not insert_after(nd, self._hook_guard_stmt(nd, tgt.value, hooks)) {
        return;
    }
    need_helper(nd, GraphMendHelper.SE_REGION_OPEN);
    need_helper(nd, GraphMendHelper.LOG_FLUSH_HOOK);
}

impl DeferSideEffectPass._hook_guard_stmt(
    at: uni.UniNode, name: str, body: list[uni.CodeBlockStmt]
) -> uni.IfStmt {
    has_nm = gen_name(at, 'hasattr', False);
    recv = gen_name(at, name, False);
    attr = self._str(at, 'register_forward_pre_hook');
    `test = uni.FuncCall(
        target=has_nm, params=[recv, attr], genai_call=None, kid=[has_nm, recv, attr]
    );
    return uni.IfStmt(condition=`test, body=body, kid=[`test] + body);
}

impl DeferSideEffectPass._pre_hook_register_stmt(
    at: uni.UniNode, name: str
) -> uni.ExprStmt {
    recv = gen_name(at, name, False);
    meth = gen_name(at, 'register_forward_pre_hook', False);
    target = uni.AtomTrailer(
        target=recv, right=meth, is_attr=True, is_null_ok=False, kid=[recv, meth]
    );
    hook = gen_name(at, '__jac_se_region_open__', False);
    call = uni.FuncCall(
        target=target, params=[hook], genai_call=None, kid=[target, hook]
    );
    return uni.ExprStmt(expr=call, in_fstring=False, kid=[call]);
}

impl DeferSideEffectPass._hook_register_stmt(
    at: uni.UniNode, name: str
) -> uni.ExprStmt {
    recv = gen_name(at, name, False);
    meth = gen_name(at, 'register_forward_hook', False);
    target = uni.AtomTrailer(
        target=recv, right=meth, is_attr=True, is_null_ok=False, kid=[recv, meth]
    );
    hook = gen_name(at, '__jac_log_flush_hook__', False);
    kw_key = gen_name(at, 'always_call', False);
    kw_val = gen_bool(at, True);
    always = uni.KWPair(key=kw_key, value=kw_val, kid=[kw_key, kw_val]);
    params: list[uni.Expr | uni.KWPair] = [hook, always];
    call = uni.FuncCall(
        target=target, params=params, genai_call=None, kid=[target] + params
    );
    return uni.ExprStmt(expr=call, in_fstring=False, kid=[call]);
}
