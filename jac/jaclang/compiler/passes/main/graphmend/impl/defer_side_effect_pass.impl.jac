import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { GraphBreakKind, GraphMendHelper, Tokens as Tok }
import from jaclang.compiler.passes.main.graphmend.torch_attr_table {
    has_torch_compile_decorator
}

impl DeferSideEffectPass.before_pass -> None {
    self._enabled = self.prog._compile_options.graphmend;
    if not self._enabled {
        self.prune_signal = True;
    }
    self._pending_regs = [];
}

impl DeferSideEffectPass.exit_func_call(nd: uni.FuncCall) -> None {
    if not self._enabled {
        return;
    }
    if self.prog.graphmend_breaks.get(id(nd)) != GraphBreakKind.SIDE_EFFECT {
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
    if self._is_logger_call(nd) and (ability?.sym_name == 'forward') {
        emit_call = self._logger_emit(nd);
        if emit_call is not None {
            parent.expr = emit_call;
            parent.set_kids([emit_call]);
            return;
        }
    }
    (entry, hoists) = self._buffer_entry(nd);
    append_call = self._buffer_append(nd, entry);
    parent.expr = append_call;
    parent.set_kids([append_call]);
    for h in hoists {
        self._insert_before(parent, h);
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
        if (anchor is not None) and (anchor.parent is nd) and (anchor in nd.kid) {
            self._insert_after(anchor, reg);
        } else {
            self._append_module_stmt(nd, reg);
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
        self._insert_before(nd, self._flush_stmt(nd));
        return;
    }
    n = self._counter;
    self._counter += 1;
    tmp = self._gen_name(nd, f"__gm_ret_{n}", True);
    ret_assign = uni.Assignment(
        target=[tmp], value=nd.expr, type_tag=None, mutable=True, kid=[tmp, nd.expr]
    );
    ref = self._gen_name(nd, f"__gm_ret_{n}", False);
    nd.expr = ref;
    nd.set_kids([ref]);
    self._insert_before(nd, ret_assign);
    self._insert_before(nd, self._flush_stmt(nd));
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
        self._append_stmt(nd, self._flush_stmt(nd));
    }
    if has_torch_compile_decorator(nd) {
        self._attach_se_guard(nd);
    }
}

impl DeferSideEffectPass._attach_se_guard(nd: uni.Ability) -> None {
    if id(nd) in self._guarded {
        return;
    }
    self._need_helper(nd, GraphMendHelper.SE_GUARD);
    guard = self._gen_name(nd, '__jac_se_guard__', False);
    nd.decorators = [guard] + list(nd.decorators or []);
    nd.set_kids([guard] + list(nd.kid));
    guard.parent = nd;
    self._guarded.add(id(nd));
}

impl DeferSideEffectPass._is_compiled_entry(nd: uni.Ability) -> bool {
    return has_torch_compile_decorator(nd) or (nd?.sym_name == 'forward');
}

impl DeferSideEffectPass._need_helper(
    at: uni.UniNode, helper: GraphMendHelper
) -> None {
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

impl DeferSideEffectPass._gen_name(
    at: uni.UniNode, value: str, store: bool
) -> uni.Name {
    anchor: any = at;
    nm = uni.Name.gen_stub_from_node(anchor, value);
    if store {
        nm.expr_ctx = uni.ExprCtx.STORE;
    }
    return nm;
}

impl DeferSideEffectPass._str(at: uni.UniNode, text: str) -> uni.String {
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

impl DeferSideEffectPass._split_params(
    params: any
) -> tuple[list[uni.Expr], list[uni.KWPair]] {
    pos: list[uni.Expr] = [];
    kws: list[uni.KWPair] = [];
    for p in (params or []) {
        if isinstance(p, uni.KWPair) {
            kws.append(p);
        } else {
            pos.append(p);
        }
    }
    return (pos, kws);
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
    (pos, kws) = self._split_params(call.params);
    hoists: list[uni.UniNode] = [];
    new_pos: list[uni.Expr] = [];
    for p in pos {
        if isinstance(p, (uni.Literal, uni.MultiString, uni.FString)) {
            new_pos.append(p);
        } else {
            n = self._se_arg_counter;
            self._se_arg_counter += 1;
            tmp = f"__gm_se_arg_{n}";
            store = self._gen_name(call, tmp, True);
            hoists.append(
                uni.Assignment(
                    target=[store], value=p, type_tag=None, mutable=True, kid=[store, p]
                )
            );
            new_pos.append(self._clone_guard(call, tmp));
        }
    }
    args_tuple = self._tuple(call, new_pos);
    kwargs_dict = self._dict_from_kws(call, kws);
    items: list[uni.Expr] = [call.target, args_tuple, kwargs_dict];
    return (uni.TupleVal(values=items, kid=items), hoists);
}

impl DeferSideEffectPass._clone_guard(at: uni.UniNode, tmp: str) -> uni.IfElseExpr {
    recv = self._gen_name(at, tmp, False);
    clone_nm = self._gen_name(at, 'clone', False);
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
    has_nm = self._gen_name(at, 'hasattr', False);
    test_recv = self._gen_name(at, tmp, False);
    attr_name = self._str(at, 'clone');
    test = uni.FuncCall(
        target=has_nm,
        params=[test_recv, attr_name],
        genai_call=None,
        kid=[has_nm, test_recv, attr_name]
    );
    else_recv = self._gen_name(at, tmp, False);
    val_cfg = uni.CfgExpr(expr=clone_call, kid=[clone_call]);
    cond_cfg = uni.CfgExpr(expr=test, kid=[test]);
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
    self._need_helper(at, GraphMendHelper.SE_EMIT);
    emit = self._gen_name(at, '__jac_se_emit__', False);
    params = list(ent.values);
    return uni.FuncCall(
        target=emit, params=params, genai_call=None, kid=[emit] + params
    );
}

impl DeferSideEffectPass._flush_stmt(at: uni.UniNode) -> uni.ExprStmt {
    self._need_helper(at, GraphMendHelper.SE_FLUSH);
    helper = self._gen_name(at, '__jac_se_flush__', False);
    call = uni.FuncCall(target=helper, params=[], genai_call=None, kid=[helper]);
    return uni.ExprStmt(expr=call, in_fstring=False, kid=[call]);
}

impl DeferSideEffectPass._append_stmt(
    ability: uni.Ability, new_stmt: uni.UniNode
) -> None {
    body = ability.body;
    if (not isinstance(body, list)) or (not body) {
        return;
    }
    last = body[-1];
    ability.body = list(body) + [new_stmt];
    if last in ability.kid {
        j = ability.kid.index(last);
        ability.set_kids(
            list(ability.kid[:(j + 1)]) + [new_stmt] + list(ability.kid[(j + 1):])
        );
    }
    new_stmt.parent = ability;
}

impl DeferSideEffectPass._append_module_stmt(
    mod: uni.Module, new_stmt: uni.UniNode
) -> None {
    body = mod.body;
    if not isinstance(body, list) {
        return;
    }
    if body {
        last = body[-1];
        mod.body = list(body) + [new_stmt];
        if last in mod.kid {
            j = mod.kid.index(last);
            mod.set_kids(
                list(mod.kid[:(j + 1)]) + [new_stmt] + list(mod.kid[(j + 1):])
            );
        } else {
            mod.set_kids(list(mod.kid) + [new_stmt]);
        }
    } else {
        mod.body = [new_stmt];
        mod.set_kids(list(mod.kid) + [new_stmt]);
    }
    new_stmt.parent = mod;
}

impl DeferSideEffectPass._insert_after(
    stmt: uni.UniNode, new_stmt: uni.UniNode
) -> None {
    parent = stmt.parent;
    if parent is None {
        return;
    }
    body = parent?.body;
    if isinstance(body, list) and (stmt in body) {
        i = body.index(stmt);
        parent.body = body[:(i + 1)] + [new_stmt] + body[(i + 1):];
    }
    if stmt in parent.kid {
        j = parent.kid.index(stmt);
        parent.set_kids(
            list(parent.kid[:(j + 1)]) + [new_stmt] + list(parent.kid[(j + 1):])
        );
    }
    new_stmt.parent = parent;
}

impl DeferSideEffectPass._insert_before(
    stmt: uni.UniNode, new_stmt: uni.UniNode
) -> None {
    parent = stmt.parent;
    if parent is None {
        return;
    }
    body = parent?.body;
    if isinstance(body, list) and (stmt in body) {
        i = body.index(stmt);
        parent.body = body[:i] + [new_stmt] + body[i:];
    }
    if stmt in parent.kid {
        j = parent.kid.index(stmt);
        parent.set_kids(list(parent.kid[:j]) + [new_stmt] + list(parent.kid[j:]));
    }
    new_stmt.parent = parent;
}
