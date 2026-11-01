impl MirLowering.function_of(nd: uni.UniNode) -> (uni.UniNode | None) {
    cursor = nd.parent;
    while cursor is not None {
        if isinstance(cursor, (uni.Ability, uni.LambdaExpr)) {
            return cursor;
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
        pending.extend(list(current.kid or []));
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
            if sym is None or id(sym) in seen or sym.decl is None {
                continue;
            }
            if self.function_of(name) is owner or self.function_of(sym.decl) is not owner {
                continue;
            }
            seen.add(id(sym));
            found.append(sym);
        }
    }
    return found;
}

impl MirLowering.prepare_cells(owner: uni.UniNode, body: Sequence[uni.UniNode]) {
    b = self.builder();
    for sym in self.captured_symbols(owner, body) {
        value_type = self.symbol_type(sym, owner);
        cell = self.runtime(
            "__jac_rt_cell_new", [b.const_int(self.elem_kind(value_type, owner), mir_int())]
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
            self.cell_write(b.load(slot, mir_ref()), b.load(bound, bound.type), value_type, owner);
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
        "add", self.address_of(env), b.const_int(CLOSURE_CELLS_OFFSET + index * 8, mir_int())
    );
    return b.ref_cast(self.emit_value(MirOp.MEM_LOAD, mir_int(), [address]), mir_ref(), False);
}

impl MirLowering.cell_read(cell: MirValue, value_type: MirType) -> MirValue {
    kind = self.elem_kind(value_type, self.module);
    if kind in (KIND_STR, KIND_REF) {
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
    statements: list[uni.UniNode] = [body] if isinstance(body, uni.Expr) else list(body);
    captures: list[int] = [];
    for stmt in statements {
        for name in self.names_within(stmt) {
            sym = name.sym;
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
        MirOp.PTR_INT, mir_int(), [self.emit_value(MirOp.FN_ADDR, code_type, [], callee=fn.symbol)]
    );
    made = self.runtime("__jac_rt_closure_new", [code, b.const_int(len(captures), mir_int())]);
    if made is None {
        raise MirRefused(mir_refusal("closure", label, owner));
    }
    held = self.spill(made);
    for (index, sym_id) in enumerate(captures) {
        cell = self.cell_of(sym_id);
        if cell is None {
            raise MirRefused(mir_refusal("closure", label, owner));
        }
        self.runtime("__jac_rt_closure_set", [held, b.const_int(index, mir_int()), cell]);
    }
    return b.ref_cast(held, fn_type, False);
}

impl MirLowering.closure_call(nd: uni.FuncCall, callee: MirValue) -> MirValue {
    ret = callee.type.args[0];
    params = callee.type.args[1:];
    args = self.call_args(nd);
    if len(args) != len(params) {
        raise MirRefused(mir_refusal("call", f"function value with {len(args)} arguments", nd));
    }
    i8p = mir_c_ptr(mir_int(8, False));
    held = self.spill(callee);
    values = [self.coerce(self.lower_expr(arg), ptype, arg) for (arg, ptype) in zip(args, params)];
    code = self.emit_value(MirOp.MEM_LOAD, mir_int(), [self.address_of(held)]);
    target = self.emit_value(MirOp.PTR_CAST, mir_c_fn([i8p] + params, ret), [code]);
    result_type = mir_none() if ret.kind in (MirKind.NONE, MirKind.VOID) else ret;
    result = self.emit_value(
        MirOp.CALL_FNPTR, result_type, [target, self.emit_value(MirOp.PTR_CAST, i8p, [held])] + values
    );
    result.owned = mir_holds_ref(result_type);
    return result;
}

impl MirLowering.function_value(decl: MirDecl, to: MirType) -> MirValue {
    i8p = mir_c_ptr(mir_int(8, False));
    adapter = self.adapters.get(decl.symbol);
    if adapter is None {
        adapter = f"{decl.symbol}.__value";
        fn = MirFunction(name=f"{self.name_of(decl.ability)}.__value", symbol=adapter, ret=decl.ret);
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
        [self.emit_value(MirOp.FN_ADDR, mir_c_fn([i8p] + decl.params, decl.ret), [], callee=adapter)]
    );
    made = self.runtime("__jac_rt_closure_new", [code, b.const_int(0, mir_int())]);
    if made is None {
        raise MirRefused(mir_refusal("function value", decl.symbol));
    }
    return b.ref_cast(made, to, True);
}
