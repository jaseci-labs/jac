import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { GraphMendHelper }
import from jaclang.compiler.passes.main.graphmend.torch_attr_table {
    is_torch_attr_target
}

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
    return isinstance(base, uni.Name) and (base.value not in {'self', 'cls'});
}

impl DeferSideEffectPass._logger_emit(nd: uni.FuncCall) -> (uni.FuncCall | None) {
    callee = nd.target;
    n = self._counter;
    self._counter += 1;
    slot_name = f"_gm_log_slot_{n}";
    reg = self._register_assignment(nd, slot_name, callee);
    self._pending_regs.append((self._toplevel_archetype(nd), reg));
    self._need_helper(nd, GraphMendHelper.LOG_EMIT);
    (pos, kws) = self._split_params(nd.params);
    emit = self._gen_name(nd, '__jac_log_emit__', False);
    slot_ref = self._gen_name(nd, slot_name, False);
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
    self._need_helper(at, GraphMendHelper.LOG_REGISTER);
    reg_fn = self._gen_name(at, '__jac_log_register__', False);
    reg_call = uni.FuncCall(
        target=reg_fn, params=[callee], genai_call=None, kid=[reg_fn, callee]
    );
    slot = self._gen_name(at, slot_name, True);
    return uni.Assignment(
        target=[slot], value=reg_call, type_tag=None, mutable=True, kid=[slot, reg_call]
    );
}

impl DeferSideEffectPass._toplevel_archetype(
    nd: uni.UniNode
) -> (uni.Archetype | None) {
    top: (uni.Archetype | None) = None;
    cur: (uni.UniNode | None) = nd.parent;
    while cur is not None {
        if isinstance(cur, uni.Module) {
            break;
        }
        if isinstance(cur, uni.Archetype) {
            top = cur;
        }
        cur = cur.parent;
    }
    return top;
}

impl DeferSideEffectPass.exit_assignment(nd: uni.Assignment) -> None {
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
    self._insert_after(nd, self._hook_register_stmt(nd, tgt.value));
    self._insert_after(nd, self._pre_hook_register_stmt(nd, tgt.value));
}

impl DeferSideEffectPass._pre_hook_register_stmt(
    at: uni.UniNode, name: str
) -> uni.ExprStmt {
    self._need_helper(at, GraphMendHelper.SE_REGION_OPEN);
    recv = self._gen_name(at, name, False);
    meth = self._gen_name(at, 'register_forward_pre_hook', False);
    target = uni.AtomTrailer(
        target=recv, right=meth, is_attr=True, is_null_ok=False, kid=[recv, meth]
    );
    hook = self._gen_name(at, '__jac_se_region_open__', False);
    call = uni.FuncCall(
        target=target, params=[hook], genai_call=None, kid=[target, hook]
    );
    return uni.ExprStmt(expr=call, in_fstring=False, kid=[call]);
}

impl DeferSideEffectPass._hook_register_stmt(
    at: uni.UniNode, name: str
) -> uni.ExprStmt {
    self._need_helper(at, GraphMendHelper.LOG_FLUSH_HOOK);
    recv = self._gen_name(at, name, False);
    meth = self._gen_name(at, 'register_forward_hook', False);
    target = uni.AtomTrailer(
        target=recv, right=meth, is_attr=True, is_null_ok=False, kid=[recv, meth]
    );
    hook = self._gen_name(at, '__jac_log_flush_hook__', False);
    kw_key = self._gen_name(at, 'always_call', False);
    kw_val = self._gen_name(at, 'True', False);
    always = uni.KWPair(key=kw_key, value=kw_val, kid=[kw_key, kw_val]);
    params: list[uni.Expr] = [hook, always];
    call = uni.FuncCall(
        target=target, params=params, genai_call=None, kid=[target] + params
    );
    return uni.ExprStmt(expr=call, in_fstring=False, kid=[call]);
}
