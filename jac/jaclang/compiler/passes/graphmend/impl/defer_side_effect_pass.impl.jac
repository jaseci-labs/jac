impl DeferSideEffectPass.prepare with entry {
    self._enabled = (self.prog.options.graphmend is True)
        and "defer" not in (self.prog.options.graphmend_disable or [])
        and (not defer_declines_here());
    self._pending_regs = [];
    if not self._enabled {
        disengage;
    }
    self._module_eager = False;
    for c in self.module.get_all_sub_nodes(uni.FuncCall) {
        ab = c.enclosing_decl(uni.Ability);
        if (ab is not None)
            and (facts_for(c).breaks.get(c) == GraphBreakKind.SIDE_EFFECT)
            and self._stays_eager(c, ab) {
            self._module_eager = True;
            break;
        }
    }
}

impl DeferSideEffectPass.exit_func_call with uni.FuncCall exit {
    nd = here;
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
    ability = nd.enclosing_decl(uni.Ability);
    if ability is None {
        return;
    }
    if self._module_eager or self._stays_eager(nd, ability) {
        return;
    }
    if self._is_logger_call(nd) and (ability.sym_name == 'forward') {
        emit_call = self._logger_emit(nd);
        if emit_call is not None {
            parent.replace_kid(nd, emit_call);
            return;
        }
    }
    (`entry, hoists) = self._buffer_entry(nd);
    append_call = self._buffer_append(nd, `entry);
    parent.replace_kid(nd, append_call);
    for h in hoists {
        insert_before(parent, h);
    }
    self._needs_se.add(id(ability));
}

impl DeferSideEffectPass.exit_module with uni.Module exit {
    nd = here;
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
        if (anchor is not None)
            and (anchor.parent is nd)
            and (anchor in [nd->:Kid:->]) {
            placed = insert_after(anchor, reg);
        }
        if not placed {
            append_stmt(nd, reg);
        }
    }
    self._pending_regs = [];
}

impl DeferSideEffectPass.exit_return_stmt with uni.ReturnStmt exit {
    nd = here;
    if not self._enabled {
        return;
    }
    ability = nd.enclosing_decl(uni.Ability);
    if (ability is None) or (id(ability) not in self._needs_se) {
        return;
    }
    if not self._is_compiled_entry(ability) {
        return;
    }
    ret_val = nd.expr;
    if ret_val is None {
        insert_before(nd, self._flush_stmt(nd));
        return;
    }
    n = self._counter;
    self._counter += 1;
    tmp = gen_name(nd, f"__gm_ret_{n}", True);
    ret_assign = uni.Assignment(
        target=[tmp], value=ret_val, type_tag=None, mutable=True, kid=[tmp, ret_val]
    );
    ref = gen_name(nd, f"__gm_ret_{n}", False);
    nd.replace_kid(ret_val, ref);
    insert_before(nd, ret_assign);
    insert_before(nd, self._flush_stmt(nd));
}

impl DeferSideEffectPass.exit_ability with uni.Ability exit {
    nd = here;
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
    nd._role_set(DecoratorsRole, [guard] + list(nd.decorators or []));
    nd.set_kids([guard] + [nd->:Kid:->]);
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
    (new_pos, new_kws, hoists) = self._snapshot_args(call);
    args_tuple = self._tuple(call, new_pos);
    kwargs_dict = self._dict_from_kws(call, new_kws);
    items: list[uni.Expr] = [call.target, args_tuple, kwargs_dict];
    return (uni.TupleVal(values=items, kid=items), hoists);
}

impl DeferSideEffectPass._snapshot_args(
    call: uni.FuncCall
) -> tuple[list[uni.Expr], list[uni.KWPair], list[uni.UniNode]] {
    (pos, kws) = split_params(call.params);
    hoists: list[uni.UniNode] = [];
    new_pos: list[uni.Expr] = [];
    for p in pos {
        if self._static_str(p) {
            new_pos.append(p);
        } else {
            new_pos.append(self._snapshot(call, p, hoists));
        }
    }
    new_kws: list[uni.KWPair] = [];
    for kw in kws {
        v = kw.value;
        if self._static_str(v) or (kw.key is None) {
            new_kws.append(kw);
        } else {
            snap = self._snapshot(call, v, hoists);
            new_kws.append(uni.KWPair(key=kw.key, value=snap, kid=[kw.key, snap]));
        }
    }
    return (new_pos, new_kws, hoists);
}

impl DeferSideEffectPass._static_str(v: uni.Expr) -> bool {
    if isinstance(v, uni.Literal) {
        return True;
    }
    if not isinstance(v, uni.MultiString) {
        return False;
    }
    for s in v.strings {
        if not isinstance(s, uni.String) {
            return False;
        }
    }
    return True;
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
    return self._snap_call(call, tmp);
}

impl DeferSideEffectPass._snap_call(at: uni.UniNode, tmp: str) -> uni.FuncCall {
    need_helper(at, GraphMendHelper.SE_SNAP);
    snap = gen_name(at, '__jac_se_snap__', False);
    recv = gen_name(at, tmp, False);
    torch_nm = gen_name(at, 'torch', False);
    tensor_nm = gen_name(at, 'Tensor', False);
    tensor_ref = uni.AtomTrailer(
        target=torch_nm,
        right=tensor_nm,
        is_attr=True,
        is_null_ok=False,
        kid=[torch_nm, tensor_nm]
    );
    return uni.FuncCall(
        target=snap,
        params=[recv, tensor_ref],
        genai_call=None,
        kid=[snap, recv, tensor_ref]
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
