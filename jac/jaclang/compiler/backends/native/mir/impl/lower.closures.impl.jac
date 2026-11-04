impl MirLowering.function_of(nd: uni.UniNode) -> (uni.UniNode | None) {
    cursor = nd.parent;
    while cursor is not None {
        if isinstance(cursor, (uni.Ability, uni.LambdaExpr, uni.Test)) {
            return cursor;
        }
        if isinstance(cursor, uni.ImplDef) {
            return cursor.decl_link
                if isinstance(cursor.decl_link, uni.Ability)
                else None;
        }
        if isinstance(cursor, uni.Module) {
            return None;
        }
        cursor = cursor.parent;
    }
    return None;
}

impl MirLowering.names_within(nd: uni.UniNode) -> list[uni.Name] {
    found: list[uni.Name] = [];
    pending: list[uni.UniNode] = [nd];
    while pending {
        current = pending.pop();
        if isinstance(current, uni.Name) {
            found.append(current);
        }
        pending.extend(current._children());
    }
    return found;
}

impl MirLowering.captured_symbols(
    owner: uni.UniNode, body: Sequence[uni.UniNode]
) -> list[uni.Symbol] {
    found: list[uni.Symbol] = [];
    seen: set[int] = set();
    for stmt in body {
        for name in self.names_within(stmt) {
            sym = name.sym;
            if isinstance(name, uni.SpecialVarRef) and name.value == "super" {
                sym = self.super_self(name);
            }
            if sym is not None
                and name.value in ("self", "super")
                and id(sym) not in seen
                and self.st().self_value is not None
                and self.function_of(name) is not owner {
                seen.add(id(sym));
                found.append(sym);
                continue;
            }
            if sym is None or id(sym) in seen or sym.decl is None {
                continue;
            }
            declared_in = self.function_of(sym.decl);
            holder = sym.decl.parent;
            if isinstance(holder, uni.Ability) and holder.name_ref is sym.decl {
                declared_in = self.function_of(holder);
            }
            if self.function_of(name) is owner or declared_in is not owner {
                continue;
            }
            seen.add(id(sym));
            found.append(sym);
        }
    }
    return found;
}

impl MirLowering.super_self(nd: uni.UniNode) -> (uni.Symbol | None) {
    scope = nd.find_parent_of_type(uni.UniScopeNode);
    return scope.lookup("self") if scope is not None else None;
}

impl MirLowering.prepare_cells(owner: uni.UniNode, body: Sequence[uni.UniNode]) {
    b = self.builder();
    for sym in self.captured_symbols(owner, body) {
        receiver = self.st().self_value if sym.sym_name == "self" else None;
        value_type = receiver.type
            if receiver is not None
            else self.symbol_type(sym, owner);
        cell = self.runtime(
            "__jac_rt_cell_new",
            [b.const_int(self.elem_kind(value_type, owner), mir_int())]
        );
        if cell is None {
            raise MirRefused(mir_refusal("closure", sym.sym_name, owner));
        }
        slot = self.temp_slot(mir_ref());
        b.store(slot, cell);
        bound = self.st().locals.get(id(sym));
        self.st().captured[id(sym)] = slot;
        self.st().cell_types[id(sym)] = value_type;
        if bound is not None {
            self.cell_write(
                b.load(slot, mir_ref()), b.load(bound, bound.type), value_type, owner
            );
        } elif receiver is not None {
            self.cell_write(b.load(slot, mir_ref()), receiver, value_type, owner);
        }
    }
}

impl MirLowering.cell_of(sym_id: int) -> (MirValue | None) {
    b = self.builder();
    slot = self.st().captured.get(sym_id);
    if slot is not None {
        return b.load(slot, mir_ref());
    }
    index = self.st().env_cells.get(sym_id);
    env = self.st().env;
    if index is None or env is None {
        return None;
    }
    address = b.binary(
        "add",
        self.address_of(env),
        b.const_int(CLOSURE_CELLS_OFFSET + index * 8, mir_int())
    );
    return b.ref_cast(
        self.emit_value(MirOp.MEM_LOAD, mir_int(), [address]), mir_ref(), False
    );
}

impl MirLowering.cell_read(cell: MirValue, value_type: MirType) -> MirValue {
    kind = self.elem_kind(value_type, self.module);
    if kind in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY) {
        handle = self.runtime("__jac_rt_cell_get_ref", [cell]);
        if handle is None {
            raise MirRefused(mir_refusal("closure", value_type.render()));
        }
        return self.owned_element(handle, value_type);
    }
    bits = self.emit_value(MirOp.MEM_LOAD, mir_int(), [self.address_of(cell)]);
    return self.scalar_from_bits(bits, value_type);
}

impl MirLowering.cell_write(
    cell: MirValue, value: MirValue, value_type: MirType, site: uni.UniNode
) {
    b = self.builder();
    self.runtime(
        "__jac_rt_cell_set",
        [
            cell,
            self.to_bits(self.coerce(value, value_type, site), value_type, site),
            b.const_int(self.elem_kind(value_type, site), mir_int())
        ]
    );
}

impl MirLowering.lower_closure(
    owner: uni.UniNode,
    signature: (uni.FuncSignature | None),
    body: (uni.Expr | Sequence[uni.UniNode]),
    fn_type: MirType,
    label: str
) -> MirValue {
    outer = self.st();
    statements: list[uni.UniNode] = [body]
        if isinstance(body, uni.Expr)
        else list(body);
    captures: list[int] = [];
    for stmt in statements {
        for name in self.names_within(stmt) {
            sym = name.sym;
            if isinstance(name, uni.SpecialVarRef) and name.value == "super" {
                sym = self.super_self(name);
            }
            if sym is not None
                and id(sym) not in captures
                and (id(sym) in outer.captured or id(sym) in outer.env_cells) {
                captures.append(id(sym));
            }
        }
    }
    i8p = mir_c_ptr(mir_int(8, False));
    ret = fn_type.args[0];
    params = fn_type.args[1:];
    fn = MirFunction(name=label, symbol=f"{outer.fn.symbol}.{label}", ret=ret);
    first = fn.new_block("entry");
    env_param = fn.new_value(i8p, "env");
    fn.params.append(MirParam(name="env", value=env_param));
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        inner = self.st();
        inner.env = self.builder().ref_cast(env_param, mir_ref(), False);
        for (index, sym_id) in enumerate(captures) {
            inner.env_cells[sym_id] = index;
            inner.cell_types[sym_id] = outer.cell_types[sym_id];
        }
        nodes = list(signature.posonly_params) + list(signature.params or [])
            if signature is not None
            else [];
        if len(nodes) != len(params) {
            raise MirRefused(mir_refusal("closure", f"{label} parameters", owner));
        }
        for (pv, ptype) in zip(nodes, params) {
            value = fn.new_value(ptype, pv.name.value);
            fn.params.append(MirParam(name=pv.name.value, value=value));
            self.builder().store(self.local_slot(pv.name.sym, pv), value);
        }
        self.prepare_cells(owner, statements);
        if isinstance(body, uni.Expr) {
            result = self.lower_expr(body);
            if ret.kind in (MirKind.NONE, MirKind.VOID) {
                self.builder().ret(None);
            } else {
                self.builder().ret(self.coerce(result, ret, body));
            }
        } else {
            self.lower_body(list(body));
            if not self.builder().block.terminated() {
                if ret.kind in (MirKind.NONE, MirKind.VOID) {
                    self.builder().ret(None);
                } else {
                    self.builder().unreachable();
                }
            }
        }
        for blk in fn.blocks {
            if not blk.terminated() {
                self.builder().position(blk);
                self.builder().unreachable();
            }
        }
    } finally {
        self.state = outer;
    }
    self.nested.append(fn);
    b = self.builder();
    code_type = mir_c_fn([i8p] + params, ret);
    code = self.emit_value(
        MirOp.PTR_INT,
        mir_int(),
        [self.emit_value(MirOp.FN_ADDR, code_type, [], callee=fn.symbol)]
    );
    made = self.runtime(
        "__jac_rt_closure_new", [code, b.const_int(len(captures), mir_int())]
    );
    if made is None {
        raise MirRefused(mir_refusal("closure", label, owner));
    }
    held = self.spill(made);
    for (index, sym_id) in enumerate(captures) {
        cell = self.cell_of(sym_id);
        if cell is None {
            raise MirRefused(mir_refusal("closure", label, owner));
        }
        self.runtime(
            "__jac_rt_closure_set", [held, b.const_int(index, mir_int()), cell]
        );
    }
    return b.ref_cast(held, fn_type, False);
}

impl MirLowering.closure_call(nd: uni.FuncCall, callee: MirValue) -> MirValue {
    fn_type = callee.type.payload() if callee.type.kind == MirKind.OPT else callee.type;
    params = fn_type.args[1:];
    nested = nd.target.sym.decl.parent
        if isinstance(nd.target, uni.Name)
            and nd.target.sym is not None
            and nd.target.sym.decl is not None
        else None;
    keyed = any(isinstance(arg, uni.KWPair) for arg in list(nd.params or []));
    args = [] if keyed else self.call_args(nd);
    if (keyed or len(args) != len(params))
        and isinstance(nested, uni.Ability)
        and isinstance(nested.signature, uni.FuncSignature) {
        bound = self.bound_args(nd, nested, False);
        if len(bound) == len(params) {
            held = self.spill(callee);
            if held.type.kind == MirKind.OPT {
                held = self.opt_unwrap_checked(
                    held, "'NoneType' object is not callable"
                );
            }
            return self.call_closure(held, self.bound_values(list(bound), params), nd);
        }
    }
    if keyed {
        args = self.call_args(nd);
    }
    if len(args) != len(params) {
        raise MirRefused(
            mir_refusal("call", f"function value with {len(args)} arguments", nd)
        );
    }
    held = self.spill(callee);
    values = [
        self.coerce(self.lower_expr(arg), ptype, arg)
        for (arg, ptype) in zip(args, params)
    ];
    if held.type.kind == MirKind.OPT {
        held = self.opt_unwrap_checked(held, "'NoneType' object is not callable");
    }
    return self.call_closure(held, values, nd);
}

impl MirLowering.callee_value(target: uni.Expr) -> MirValue {
    if isinstance(target, uni.AtomTrailer) and target.is_attr {
        place = self.lower_place(target);
        loaded = self.builder().load(place, self.place_elem(place));
        if loaded.type.kind == MirKind.OPT
            and loaded.type.payload().kind == MirKind.FN {
            return loaded;
        }
        return self.lower_expr(target);
    }
    if isinstance(target, uni.Name) and target.sym is not None {
        slot = self.st().locals.get(id(target.sym));
        if slot is not None
            and self.cell_of(id(target.sym)) is None
            and slot.type.kind == MirKind.OPT
            and slot.type.payload().kind == MirKind.FN {
            return self.builder().load(slot, slot.type);
        }
    }
    return self.lower_expr(target);
}

impl MirLowering.call_closure(
    callee: MirValue, values: list[MirValue], site: uni.UniNode
) -> MirValue {
    ret = callee.type.args[0];
    params = callee.type.args[1:];
    if len(values) != len(params) {
        raise MirRefused(
            mir_refusal("call", f"function value with {len(values)} arguments", site)
        );
    }
    i8p = mir_c_ptr(mir_int(8, False));
    held = self.spill(callee);
    coerced = [
        self.coerce(value, ptype, site) for (value, ptype) in zip(values, params)
    ];
    code = self.emit_value(MirOp.MEM_LOAD, mir_int(), [self.address_of(held)]);
    target = self.emit_value(MirOp.PTR_CAST, mir_c_fn([i8p] + params, ret), [code]);
    result_type = mir_none() if ret.kind in (MirKind.NONE, MirKind.VOID) else ret;
    result = self.emit_value(
        MirOp.CALL_FNPTR,
        result_type,
        [target, self.emit_value(MirOp.PTR_CAST, i8p, [held])] + coerced
    );
    result.owned = mir_holds_ref(result_type);
    return result;
}

impl MirLowering.function_value(decl: MirDecl, to: MirType) -> MirValue {
    i8p = mir_c_ptr(mir_int(8, False));
    adapter = self.adapters.get(decl.symbol);
    if adapter is None {
        adapter = f"{decl.symbol}.__value";
        fn = MirFunction(
            name=f"{self.name_of(decl.ability)}.__value", symbol=adapter, ret=decl.ret
        );
        first = fn.new_block("entry");
        fn.params.append(MirParam(name="env", value=fn.new_value(i8p, "env")));
        forwarded: list[MirValue] = [];
        for (index, ptype) in enumerate(decl.params) {
            value = fn.new_value(ptype, f"a{index}");
            fn.params.append(MirParam(name=f"a{index}", value=value));
            forwarded.append(value);
        }
        b = MirBuilder(fn=fn, block=first);
        result = b.call(decl.symbol, forwarded, decl.ret);
        if decl.ret.kind in (MirKind.NONE, MirKind.VOID) or result is None {
            b.ret(None);
        } else {
            b.ret(result);
        }
        self.nested.append(fn);
        self.adapters[decl.symbol] = adapter;
    }
    b = self.builder();
    code = self.emit_value(
        MirOp.PTR_INT,
        mir_int(),
        [
            self.emit_value(
                MirOp.FN_ADDR,
                mir_c_fn([i8p] + decl.params, decl.ret),
                [],
                callee=adapter
            )
        ]
    );
    made = self.runtime("__jac_rt_closure_new", [code, b.const_int(0, mir_int())]);
    if made is None {
        raise MirRefused(mir_refusal("function value", decl.symbol));
    }
    self.closure_key(made, f"function {decl.symbol}");
    return b.ref_cast(made, to, True);
}

impl MirLowering.closure_key(made: MirValue, identity: str) {
    key = int(hashlib.sha256(identity.encode()).hexdigest()[:15], 16) or 1;
    self.runtime(
        "__jac_rt_closure_key", [made, self.builder().const_int(key, mir_int())]
    );
}

impl MirLowering.closure_adapter(
    value: MirValue, to: MirType, site: uni.UniNode
) -> MirValue {
    i8p = mir_c_ptr(mir_int(8, False));
    inner_type = value.type;
    key = f"adapt|{inner_type.render()}|{to.render()}";
    symbol = self.adapters.get(key);
    if symbol is None {
        symbol = f"{self.mir.prefix}.__fn_adapt_{len(self.adapters)}";
        fn = MirFunction(name="__fn_adapt", symbol=symbol, ret=to.args[0]);
        first = fn.new_block("entry");
        env = fn.new_value(i8p, "env");
        fn.params.append(MirParam(name="env", value=env));
        given: list[MirValue] = [];
        for (index, ptype) in enumerate(to.args[1:]) {
            arg = fn.new_value(ptype, f"a{index}");
            fn.params.append(MirParam(name=f"a{index}", value=arg));
            given.append(arg);
        }
        outer = self.state;
        self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
        try {
            b = self.builder();
            slot = b.binary(
                "add",
                self.address_of(env),
                b.const_int(CLOSURE_CELLS_OFFSET, mir_int())
            );
            inner = b.ref_cast(
                self.emit_value(MirOp.MEM_LOAD, mir_int(), [slot]), inner_type, False
            );
            converted = [
                self.coerce(arg, ptype, site)
                for (arg, ptype) in zip(given, inner_type.args[1:])
            ];
            result = self.call_closure(inner, converted, site);
            if to.args[0].kind in (MirKind.NONE, MirKind.VOID) {
                b.ret(None);
            } else {
                b.ret(self.coerce(result, to.args[0], site));
            }
        } finally {
            self.state = outer;
        }
        self.nested.append(fn);
        self.adapters[key] = symbol;
    }
    b = self.builder();
    held = self.spill(value);
    code = self.emit_value(
        MirOp.PTR_INT,
        mir_int(),
        [
            self.emit_value(
                MirOp.FN_ADDR,
                mir_c_fn([i8p] + to.args[1:], to.args[0]),
                [],
                callee=symbol
            )
        ]
    );
    made = self.runtime("__jac_rt_closure_new", [code, b.const_int(1, mir_int())]);
    if made is None {
        raise MirRefused(mir_refusal("function value", "adapter", site));
    }
    self.runtime("__jac_rt_closure_set", [made, b.const_int(0, mir_int()), held]);
    return b.ref_cast(made, to, True);
}

impl MirLowering.flow_threaded -> bool {
    return (self.prog.options.na_gc_mode or "cycles") == "rc";
}

impl MirLowering.task_store(base: MirValue, offset: int, value: MirValue) {
    b = self.builder();
    self.emit_value(
        MirOp.MEM_STORE,
        mir_none(),
        [b.binary("add", base, b.const_int(offset, mir_int())), value]
    );
}

impl MirLowering.lower_concurrent(nd: uni.ConcurrentExpr) -> MirValue {
    b = self.builder();
    i8p = mir_c_ptr(mir_int(8, False));
    keyword = nd.tok.value if nd.tok else "";
    if keyword == "wait" {
        handle_type = self.expr_type(nd.target);
        if handle_type.kind != MirKind.OBJ or handle_type.name != "*" {
            return self.lower_expr(nd.target);
        }
        handle = self.spill(self.lower_expr(nd.target));
        if self.flow_threaded() {
            fn = self.st().fn;
            base = self.address_of(handle);
            state_place = b.binary("add", base, b.const_int(TASK_STATE, mir_int()));
            state = self.emit_value(MirOp.MEM_LOAD, mir_int(), [state_place]);
            joining = fn.new_block("wait.join");
            joined = fn.new_block("wait.ready");
            b.cond_branch(
                b.compare("eq", state, b.const_int(1, mir_int())), joining, joined
            );
            b.position(joining);
            if "pthread_join" not in self.mir.externs {
                self.mir.externs["pthread_join"] = MirExtern(
                    symbol="pthread_join",
                    ret=mir_int(32, True, True),
                    params=[mir_int(), i8p]
                );
            }
            thread = self.emit_value(
                MirOp.MEM_LOAD,
                mir_int(),
                [b.binary("add", base, b.const_int(TASK_THREAD, mir_int()))]
            );
            b.call(
                "pthread_join",
                [thread, self.emit_value(MirOp.PTR_NULL, i8p, [])],
                mir_int(32, True, True)
            );
            self.emit_value(
                MirOp.MEM_STORE, mir_none(), [state_place, b.const_int(2, mir_int())]
            );
            b.branch(joined);
            b.position(joined);
        }
        bits = self.runtime_value("__jac_rt_task_result", [handle]);
        return self.element_from_bits(bits, self.expr_type(nd));
    }
    if keyword != "flow" {
        raise MirRefused(mir_refusal("expression", f"{keyword} expression", nd));
    }
    target = nd.target;
    callee = target.callee_decl if isinstance(target, uni.FuncCall) else None;
    decl = self.decls.get(id(callee)) if callee is not None else None;
    runs = isinstance(target, uni.FuncCall)
        and decl is not None
        and decl.self_type is None
        and not decl.event
        and not decl.c_variadic;
    count = len(decl.params) if runs and decl is not None else 0;
    task = self.spill(
        b.ref_cast(
            self.runtime_value("__jac_rt_task_new", [b.const_int(count, mir_int())]),
            mir_ref(),
            True
        )
    );
    base = self.address_of(task);
    if not runs or decl is None or not isinstance(target, uni.FuncCall) {
        value = self.lower_expr(target);
        elem = self.expr_type(target);
        if elem.kind not in (MirKind.NONE, MirKind.VOID) {
            kind = self.elem_kind(elem, nd);
            shared = self.runtime_value(
                "__jac_rt_elem_share",
                [
                    self.to_bits(self.coerce(value, elem, nd), elem, nd),
                    b.const_int(kind, mir_int())
                ]
            );
            self.task_store(base, TASK_BITS, shared);
            self.task_store(base, TASK_KIND, b.const_int(kind, mir_int()));
        } else {
            self.task_store(base, TASK_KIND, b.const_int(KIND_INT, mir_int()));
        }
        return task;
    }
    args = self.bound_args(target, decl.ability, False);
    if len(args) != len(decl.params) {
        raise MirRefused(mir_refusal("call", f"flow with {len(args)} arguments", nd));
    }
    values = self.bound_values(list(args), decl.params);
    for (index, (value, ptype)) in enumerate(zip(values, decl.params)) {
        kind = self.elem_kind(ptype, nd);
        shared = self.runtime_value(
            "__jac_rt_elem_share",
            [self.to_bits(value, ptype, nd), b.const_int(kind, mir_int())]
        );
        self.task_store(base, TASK_ARGS + index * 8, shared);
    }
    thunk = self.flow_thunk(decl);
    self.runtime("__jac_rt_retain", [task]);
    launcher = self.emit_value(MirOp.FN_ADDR, mir_c_fn([i8p], i8p), [], callee=thunk);
    handle = self.emit_value(MirOp.PTR_CAST, i8p, [task]);
    if self.flow_threaded() {
        if "pthread_create" not in self.mir.externs {
            self.mir.externs["pthread_create"] = MirExtern(
                symbol="pthread_create",
                ret=mir_int(32, True, True),
                params=[i8p, i8p, i8p, i8p]
            );
        }
        self.task_store(base, TASK_STATE, b.const_int(1, mir_int()));
        self.mark_threaded();
        place = self.emit_value(
            MirOp.PTR_CAST,
            i8p,
            [b.binary("add", base, b.const_int(TASK_THREAD, mir_int()))]
        );
        b.call(
            "pthread_create",
            [
                place,
                self.emit_value(MirOp.PTR_NULL, i8p, []),
                self.emit_value(MirOp.PTR_CAST, i8p, [launcher]),
                handle
            ],
            mir_int(32, True, True)
        );
    } else {
        b.call(thunk, [handle], i8p);
    }
    return task;
}

impl MirLowering.flow_thunk(decl: MirDecl) -> str {
    i8p = mir_c_ptr(mir_int(8, False));
    self.flow_sites += 1;
    symbol = f"{self.mir.prefix}.__flow{self.flow_sites}";
    fn = MirFunction(
        name=f"__flow{self.flow_sites}", symbol=symbol, ret=i8p, linkage="internal"
    );
    param = fn.new_value(i8p, "task");
    fn.params.append(MirParam(name="task", value=param));
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=fn.new_block("entry")));
    try {
        b = self.builder();
        base = self.emit_value(MirOp.PTR_INT, mir_int(), [param]);
        values: list[MirValue] = [];
        for (index, ptype) in enumerate(decl.params) {
            bits = self.emit_value(
                MirOp.MEM_LOAD,
                mir_int(),
                [b.binary("add", base, b.const_int(TASK_ARGS + index * 8, mir_int()))]
            );
            values.append(self.spill(self.element_from_bits(bits, ptype)));
        }
        (frame, dispatch) = self.guard_open();
        result = b.call(decl.symbol, values, decl.ret);
        if result is not None and decl.ret.kind not in (MirKind.NONE, MirKind.VOID) {
            kind = self.elem_kind(decl.ret, decl.ability);
            shared = self.runtime_value(
                "__jac_rt_elem_share",
                [
                    self.to_bits(result, decl.ret, decl.ability),
                    b.const_int(kind, mir_int())
                ]
            );
            self.task_store(base, TASK_BITS, shared);
            self.task_store(base, TASK_KIND, b.const_int(kind, mir_int()));
        } else {
            self.task_store(base, TASK_KIND, b.const_int(KIND_INT, mir_int()));
        }
        self.runtime("__jac_rt_exc_pop", [frame]);
        self.runtime("__jac_rt_release", [b.ref_cast(param, mir_ref(), False)]);
        b.ret(self.emit_value(MirOp.PTR_NULL, i8p, []));
        b.position(dispatch);
        self.runtime("__jac_rt_exc_pop", [frame]);
        (origin, type_id, message) = self.guard_caught(frame);
        self.task_store(base, TASK_ERROR, b.convert(type_id, mir_int()));
        self.task_store(
            base, TASK_MESSAGE, self.emit_value(MirOp.PTR_INT, mir_int(), [message])
        );
        self.task_store(
            base, TASK_ORIGIN, self.emit_value(MirOp.PTR_INT, mir_int(), [origin])
        );
        self.runtime("__jac_rt_release", [b.ref_cast(param, mir_ref(), False)]);
        b.ret(self.emit_value(MirOp.PTR_NULL, i8p, []));
    } finally {
        self.state = saved;
    }
    self.nested.append(fn);
    return symbol;
}

impl MirLowering.bound_method_value(nd: uni.AtomTrailer) -> (MirValue | None) {
    if not nd.is_attr
        or not isinstance(nd.right, uni.Name)
        or not isinstance(nd.target, uni.Expr)
        or not isinstance(nd.target.type, ClassType) {
        return None;
    }
    owner_type = self.expr_type(nd.target);
    if owner_type.kind != MirKind.OBJ {
        return None;
    }
    arch = self.archetypes.get(owner_type.name);
    if arch is None {
        return None;
    }
    name = nd.right.value;
    method = self.find_method(arch, name);
    if method is None or method.is_static {
        return None;
    }
    wanted = self.expr_type(nd);
    if wanted.kind != MirKind.FN {
        return None;
    }
    decl = self.method_decl(arch, method, name, nd);
    i8p = mir_c_ptr(mir_int(8, False));
    key = f"bound|{decl.symbol}|{owner_type.name}";
    symbol = self.adapters.get(key);
    if symbol is None {
        symbol = f"{self.mir.prefix}.__bound_{len(self.adapters)}";
        fn = MirFunction(name="__bound", symbol=symbol, ret=decl.ret);
        first = fn.new_block("entry");
        env = fn.new_value(i8p, "env");
        fn.params.append(MirParam(name="env", value=env));
        given: list[MirValue] = [];
        for (index, ptype) in enumerate(decl.params) {
            arg = fn.new_value(ptype, f"a{index}");
            fn.params.append(MirParam(name=f"a{index}", value=arg));
            given.append(arg);
        }
        outer = self.state;
        self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
        try {
            b = self.builder();
            slot = b.binary(
                "add",
                self.address_of(env),
                b.const_int(CLOSURE_CELLS_OFFSET, mir_int())
            );
            receiver = b.ref_cast(
                self.emit_value(MirOp.MEM_LOAD, mir_int(), [slot]), owner_type, False
            );
            held = self.method_receiver(decl, arch, receiver, nd);
            result = self.invoke_method(decl, arch, name, [held] + given);
            if decl.ret.kind in (MirKind.NONE, MirKind.VOID) {
                b.ret(None);
            } else {
                b.ret(result);
            }
        } finally {
            self.state = outer;
        }
        self.nested.append(fn);
        self.adapters[key] = symbol;
    }
    b = self.builder();
    receiver = self.spill(self.lower_expr(nd.target));
    code = self.emit_value(
        MirOp.PTR_INT,
        mir_int(),
        [
            self.emit_value(
                MirOp.FN_ADDR,
                mir_c_fn([i8p] + decl.params, decl.ret),
                [],
                callee=symbol
            )
        ]
    );
    made = self.runtime("__jac_rt_closure_new", [code, b.const_int(1, mir_int())]);
    if made is None {
        raise MirRefused(mir_refusal("function value", f"{name} bound", nd));
    }
    self.runtime("__jac_rt_closure_set", [made, b.const_int(0, mir_int()), receiver]);
    self.closure_key(made, f"method {name}");
    value = b.ref_cast(made, mir_fn(decl.params, decl.ret), True);
    return value if value.type is wanted else self.coerce(value, wanted, nd);
}
