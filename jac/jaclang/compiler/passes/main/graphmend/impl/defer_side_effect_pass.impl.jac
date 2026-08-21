import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { GraphBreakKind, GraphMendHelper, Tokens as Tok }
import from jaclang.compiler.passes.main.graphmend.ast_edit {
    append_stmt,
    facts_for,
    gen_name,
    gen_string,
    insert_after,
    insert_before,
    need_helper,
    split_params
}
import from jaclang.compiler.passes.main.graphmend.torch_attr_table {
    has_torch_compile_decorator
}

impl DeferSideEffectPass.before_pass -> None {
    import from jaclang.jac0core.compile_options { defer_declines_here }
    self._enabled = (self.prog._compile_options.graphmend is True)
        and "defer" not in (self.prog._compile_options.graphmend_disable or [])
        and (not defer_declines_here());
    if not self._enabled {
        self.prune_signal = True;
    }
    self._pending_regs = [];
}

impl DeferSideEffectPass.exit_func_call(nd: uni.FuncCall) -> None {
    if not self._enabled {
        return;
    }
    if facts_for(nd).breaks.get(nd) != GraphBreakKind.SIDE_EFFECT {
        return;
    }
    parent = nd.parent;
    if not isinstance(parent, uni.ExprStmt) {
        return;
    }
    ability = nd.find_parent_of_type(uni.Ability);
    if ability is None {
        return;
    }
    if self._has_unpack(nd) {
        return;
    }
    if self._is_logger_call(nd) and (ability?.sym_name == 'forward') {
        emit_call = self._logger_emit(nd);
        if emit_call is not None {
            parent.expr = emit_call;
            parent.set_kids([emit_call]);
            return;
        }
    }
    (`entry, hoists) = self._buffer_entry(nd);
    append_call = self._buffer_append(nd, `entry);
    parent.expr = append_call;
    parent.set_kids([append_call]);
    for h in hoists {
        insert_before(parent, h);
    }
    self._needs_se.add(id(ability));
}

impl DeferSideEffectPass.exit_module(nd: uni.Module) -> None {
    if not self._enabled {
        return;
    }
    if id(nd) in self._defer_mods {
        for ab in nd.get_all_sub_nodes(uni.Ability) {
            if has_torch_compile_decorator(ab) and (id(ab) not in self._guarded) {
                self._attach_se_guard(ab);
            }
        }
    }
    if not self._pending_regs {
        return;
    }
    for (anchor, reg) in self._pending_regs {
        placed = False;
        if (anchor is not None) and (anchor.parent is nd) and (anchor in nd.kid) {
            placed = insert_after(anchor, reg);
        }
        if not placed {
            append_stmt(nd, reg);
        }
    }
    self._pending_regs = [];
}

impl DeferSideEffectPass.exit_return_stmt(nd: uni.ReturnStmt) -> None {
    if not self._enabled {
        return;
    }
    ability = nd.find_parent_of_type(uni.Ability);
    if (ability is None) or (id(ability) not in self._needs_se) {
        return;
    }
    if not self._is_compiled_entry(ability) {
        return;
    }
    if nd.expr is None {
        insert_before(nd, self._flush_stmt(nd));
        return;
    }
    n = self._counter;
    self._counter += 1;
    tmp = gen_name(nd, f"__gm_ret_{n}", True);
    ret_assign = uni.Assignment(
        target=[tmp], value=nd.expr, type_tag=None, mutable=True, kid=[tmp, nd.expr]
    );
    ref = gen_name(nd, f"__gm_ret_{n}", False);
    nd.expr = ref;
    nd.set_kids([ref]);
    insert_before(nd, ret_assign);
    insert_before(nd, self._flush_stmt(nd));
}

impl DeferSideEffectPass.exit_ability(nd: uni.Ability) -> None {
    if not self._enabled {
        return;
    }
    if id(nd) not in self._needs_se {
        return;
    }
    body = nd.body;
    if (not isinstance(body, list)) or (not body) {
        return;
    }
    mod = nd.find_parent_of_type(uni.Module);
    if mod is not None {
        self._defer_mods.add(id(mod));
    }
    if not self._is_compiled_entry(nd) {
        return;
    }
    tail = body[-1];
    if not isinstance(tail, uni.ReturnStmt) {
        append_stmt(nd, self._flush_stmt(nd));
    }
    if has_torch_compile_decorator(nd) {
        self._attach_se_guard(nd);
    }
}

impl DeferSideEffectPass._attach_se_guard(nd: uni.Ability) -> None {
    if id(nd) in self._guarded {
        return;
    }
    need_helper(nd, GraphMendHelper.SE_GUARD);
    guard = gen_name(nd, '__jac_se_guard__', False);
    nd.decorators = [guard] + list(nd.decorators or []);
    nd.set_kids([guard] + list(nd.kid));
    guard.parent = nd;
    self._guarded.add(id(nd));
}

impl DeferSideEffectPass._is_compiled_entry(nd: uni.Ability) -> bool {
    return facts_for(nd).boundary.get(nd) is nd;
}

impl DeferSideEffectPass._str(at: uni.UniNode, text: str) -> uni.String {
    return gen_string(at, f'"{text}"');
}

impl DeferSideEffectPass._has_unpack(call: uni.FuncCall) -> bool {
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

impl DeferSideEffectPass._tuple(
    at: uni.UniNode, values: list[uni.Expr]
) -> uni.TupleVal {
    kid: list[uni.UniNode] = (
        list(values)
            if values
            else [at.gen_token(Tok.LPAREN, '('), at.gen_token(Tok.RPAREN, ')')]
    );
    return uni.TupleVal(values=values, kid=kid);
}

impl DeferSideEffectPass._dict_from_kws(
    at: uni.UniNode, kws: list[uni.KWPair]
) -> uni.DictVal {
    pairs: list[uni.KVPair] = [];
    for kw in kws {
        key_nm = kw.key;
        if key_nm is None {
            continue;
        }
        key = self._str(at, key_nm.sym_name);
        pairs.append(uni.KVPair(key=key, value=kw.value, kid=[key, kw.value]));
    }
    kid: list[uni.UniNode] = (
        list(pairs)
            if pairs
            else [at.gen_token(Tok.LBRACE, '{'), at.gen_token(Tok.RBRACE, '}')]
    );
    return uni.DictVal(kv_pairs=pairs, kid=kid);
}

impl DeferSideEffectPass._buffer_entry(
    call: uni.FuncCall
) -> tuple[uni.TupleVal, list[uni.UniNode]] {
    (pos, kws) = split_params(call.params);
    hoists: list[uni.UniNode] = [];
    new_pos: list[uni.Expr] = [];
    for p in pos {
        if isinstance(p, (uni.Literal, uni.MultiString, uni.FString)) {
            new_pos.append(p);
        } else {
            new_pos.append(self._snapshot(call, p, hoists));
        }
    }
    new_kws: list[uni.KWPair] = [];
    for kw in kws {
        v = kw.value;
        if isinstance(v, (uni.Literal, uni.MultiString, uni.FString))
            or (kw.key is None) {
            new_kws.append(kw);
        } else {
            snap = self._snapshot(call, v, hoists);
            new_kws.append(uni.KWPair(key=kw.key, value=snap, kid=[kw.key, snap]));
        }
    }
    args_tuple = self._tuple(call, new_pos);
    kwargs_dict = self._dict_from_kws(call, new_kws);
    items: list[uni.Expr] = [call.target, args_tuple, kwargs_dict];
    return (uni.TupleVal(values=items, kid=items), hoists);
}

impl DeferSideEffectPass._snapshot(
    call: uni.FuncCall, v: uni.Expr, hoists: list[uni.UniNode]
) -> uni.Expr {
    n = self._se_arg_counter;
    self._se_arg_counter += 1;
    tmp = f"__gm_se_arg_{n}";
    store = gen_name(call, tmp, True);
    hoists.append(
        uni.Assignment(
            target=[store], value=v, type_tag=None, mutable=True, kid=[store, v]
        )
    );
    return self._clone_guard(call, tmp);
}

impl DeferSideEffectPass._clone_guard(at: uni.UniNode, tmp: str) -> uni.IfElseExpr {
    recv = gen_name(at, tmp, False);
    clone_nm = gen_name(at, 'clone', False);
    trailer = uni.AtomTrailer(
        target=recv,
        right=clone_nm,
        is_attr=True,
        is_null_ok=False,
        kid=[recv, clone_nm]
    );
    clone_call = uni.FuncCall(
        target=trailer, params=[], genai_call=None, kid=[trailer]
    );
    has_nm = gen_name(at, 'hasattr', False);
    test_recv = gen_name(at, tmp, False);
    attr_name = self._str(at, 'clone');
    `test = uni.FuncCall(
        target=has_nm,
        params=[test_recv, attr_name],
        genai_call=None,
        kid=[has_nm, test_recv, attr_name]
    );
    else_recv = gen_name(at, tmp, False);
    val_cfg = uni.CfgExpr(expr=clone_call, kid=[clone_call]);
    cond_cfg = uni.CfgExpr(expr=`test, kid=[`test]);
    else_cfg = uni.CfgExpr(expr=else_recv, kid=[else_recv]);
    return uni.IfElseExpr(
        value=val_cfg,
        condition=cond_cfg,
        else_value=else_cfg,
        kid=[val_cfg, cond_cfg, else_cfg]
    );
}

impl DeferSideEffectPass._buffer_append(
    at: uni.UniNode, ent: uni.TupleVal
) -> uni.FuncCall {
    need_helper(at, GraphMendHelper.SE_EMIT);
    emit = gen_name(at, '__jac_se_emit__', False);
    params = list(ent.values);
    return uni.FuncCall(
        target=emit, params=params, genai_call=None, kid=[emit] + params
    );
}

impl DeferSideEffectPass._flush_stmt(at: uni.UniNode) -> uni.ExprStmt {
    need_helper(at, GraphMendHelper.SE_FLUSH);
    helper = gen_name(at, '__jac_se_flush__', False);
    call = uni.FuncCall(target=helper, params=[], genai_call=None, kid=[helper]);
    return uni.ExprStmt(expr=call, in_fstring=False, kid=[call]);
}
