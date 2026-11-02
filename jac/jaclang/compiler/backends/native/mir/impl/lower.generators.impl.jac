impl MirLowering.is_generator(ab: uni.Ability) -> bool {
    for found in ab.element_sub_nodes(uni.YieldExpr) {
        if found.enclosing_frame is ab {
            return True;
        }
    }
    return False;
}

impl MirLowering.ability_sig(ab: uni.Ability) -> (uni.FuncSignature | None) {
    sig = ab.signature;
    return sig if isinstance(sig, uni.FuncSignature) else None;
}

impl MirLowering.alias_twins(ab: uni.Ability, sig: uni.FuncSignature, skip_self: bool) {
    declared = self.ability_sig(ab);
    if declared is None or declared is sig {
        return;
    }
    for (twin, pv) in zip(
        self.param_nodes(declared, skip_self), self.param_nodes(sig, skip_self)
    ) {
        if twin.name.sym is not None and pv.name.sym is not None {
            found = self.st().locals.get(id(pv.name.sym));
            if found is not None {
                self.st().locals[id(twin.name.sym)] = found;
            }
        }
    }
}

impl MirLowering.lower_generator(decl: MirDecl) -> (MirFunction | None) {
    ab = decl.ability;
    name = self.name_of(ab);
    i8p = mir_c_ptr(mir_int(8, False));
    resume = MirFunction(
        name=f"{name}.__next",
        symbol=f"{decl.symbol}.__next",
        ret=mir_none(),
        resumable=True,
        linkage="internal"
    );
    start = MirFunction(name=name, symbol=decl.symbol, ret=decl.ret);
    saved = self.state;
    try {
        if decl.ret.kind != MirKind.ITER {
            raise MirRefused(
                mir_refusal(
                    "function",
                    name,
                    ab,
                    "A native generator must declare a generator-family return type with a lowerable element, e.g. `-> Iterator[int]`."
                )
            );
        }
        sig = ab.signature;
        body = ab.body;
        if isinstance(body, uni.ImplDef) {
            spec = body.spec;
            if isinstance(spec, uni.FuncSignature) {
                sig = spec;
            } elif spec is not None {
                sig = None;
            }
            body = body.body;
        }
        if not isinstance(sig, uni.FuncSignature)
            or not isinstance(body, (list, tuple)) {
            raise MirRefused(mir_refusal("function", "generator body", ab));
        }
        frame = resume.new_value(i8p, "frame");
        out = resume.new_value(i8p, "out");
        resume.params.append(MirParam(name="frame", value=frame));
        resume.params.append(MirParam(name="out", value=out));
        first = resume.new_block("entry");
        self.state = MirFnState(
            fn=resume,
            b=MirBuilder(fn=resume, block=first),
            generator=MirGenInfo(elem=decl.ret.payload(), frame=frame, out=out)
        );
        slots: list[MirValue] = [];
        if decl.self_type is not None {
            receiver = self.temp_slot(decl.self_type);
            slots.append(receiver);
            self.st().self_value = self.builder().load(receiver, decl.self_type);
        }
        nodes = self.param_nodes(sig, decl.self_type is not None);
        if len(nodes) != len(decl.params) {
            raise MirRefused(mir_refusal("function", "impl parameters differ", ab));
        }
        for pv in nodes {
            slots.append(self.local_slot(pv.name.sym, pv));
        }
        self.alias_twins(ab, sig, decl.self_type is not None);
        self.prepare_cells(ab, list(body));
        self.lower_body(body);
        if not self.builder().block.terminated() {
            self.builder().ret(None);
        }
        for blk in resume.blocks {
            if not blk.terminated() {
                self.builder().position(blk);
                self.builder().unreachable();
            }
        }
        self.state = MirFnState(
            fn=start, b=MirBuilder(fn=start, block=start.new_block("entry"))
        );
        b = self.builder();
        values: list[MirValue] = [];
        if decl.self_type is not None {
            receiver_param = start.new_value(decl.self_type, "self");
            start.params.append(MirParam(name="self", value=receiver_param));
            values.append(receiver_param);
        }
        for (pv, ptype) in zip(nodes, decl.params) {
            value = start.new_value(ptype, pv.name.value);
            start.params.append(MirParam(name=pv.name.value, value=value));
            values.append(value);
        }
        frame_obj = start.new_value(mir_ref(), "frame");
        frame_obj.owned = True;
        b.emit(
            MirInstr(
                op=MirOp.FRAME_NEW,
                result=frame_obj,
                callee=resume.symbol,
                type_arg=mir_ref()
            )
        );
        for (value, slot) in zip(values, slots) {
            place = self.emit_value(
                MirOp.FRAME_FIELD,
                mir_c_ptr(slot.type),
                [frame_obj],
                callee=resume.symbol,
                int_value=slot.id
            );
            b.store(place, self.coerce(value, slot.type, ab));
        }
        code = self.emit_value(
            MirOp.PTR_INT,
            mir_int(),
            [
                self.emit_value(
                    MirOp.FN_ADDR,
                    mir_c_fn([i8p, i8p], mir_bool()),
                    [],
                    callee=resume.symbol
                )
            ]
        );
        made = self.runtime_value("__jac_rt_iter_new", [code, frame_obj]);
        b.ret(b.ref_cast(made, decl.ret, True));
    } except MirRefused as err {
        self.refusals.setdefault(name, []).append(refusal_of(err));
        self.state = saved;
        return None;
    }
    self.state = saved;
    self.nested.append(resume);
    return start;
}

impl MirLowering.lower_yield(nd: uni.YieldExpr) {
    info = self.st().generator;
    if info is None {
        raise MirRefused(
            mir_refusal(
                "expression",
                "YieldExpr",
                nd,
                "yield lowers natively only directly inside a generator function (declared `-> Iterator[T]`); it is not supported in lambdas, nested functions, or non-generator bodies."
            )
        );
    }
    cursor = nd.parent;
    while cursor is not None and not isinstance(cursor, (uni.Ability, uni.Module)) {
        if isinstance(cursor, uni.WithStmt) {
            raise MirRefused(
                mir_refusal(
                    "expression",
                    "yield inside with",
                    nd,
                    "A native generator resumes in a fresh activation, so a context around its yield would not be entered again; move the yield out of the with."
                )
            );
        }
        cursor = cursor.parent;
    }
    b = self.builder();
    if nd.with_from {
        if nd.expr is None {
            raise MirRefused(mir_refusal("expression", "yield from", nd));
        }
        walker_state = self.iter_open(self.lower_expr(nd.expr), nd);
        fn = self.st().fn;
        head = fn.new_block("yf.head");
        body = fn.new_block("yf.body");
        after = fn.new_block("yf.exit");
        b.branch(head);
        b.position(head);
        element = self.iter_step(walker_state, body, after);
        self.yield_value(element, nd);
        b.branch(head);
        b.position(after);
        return;
    }
    if nd.expr is not None {
        self.yield_value(self.lower_expr(nd.expr), nd);
        return;
    }
    elem = info.elem;
    if elem.kind == MirKind.NONE {
        self.yield_value(self.none_value(), nd);
    } elif elem.kind == MirKind.FLOAT {
        self.yield_value(b.const_float(0.0, elem), nd);
    } elif elem.kind == MirKind.BOOL {
        self.yield_value(b.const_bool(False), nd);
    } elif elem.kind in (MirKind.INT, MirKind.ENUM) {
        self.yield_value(b.const_int(0, elem), nd);
    } else {
        raise MirRefused(
            mir_refusal(
                "expression",
                "bare yield",
                nd,
                "A bare `yield` suspends with the element type's unit value; this element type has no native unit carrier."
            )
        );
    }
}

impl MirLowering.yield_value(value: MirValue, site: uni.UniNode) {
    info = self.st().generator;
    if info is None {
        raise MirRefused(mir_refusal("expression", "YieldExpr", site));
    }
    b = self.builder();
    shared: MirValue;
    if info.elem.kind == MirKind.NONE {
        shared = b.const_int(0, mir_int());
    } else {
        bits = self.to_bits(self.coerce(value, info.elem, site), info.elem, site);
        shared = self.runtime_value(
            "__jac_rt_elem_share",
            [bits, b.const_int(self.elem_kind(info.elem, site), mir_int())]
        );
    }
    self.leave_tries(0, False);
    b.emit(MirInstr(op=MirOp.YIELD, operands=[shared]));
    self.rearm_tries();
}

impl MirLowering.yield_expression(nd: uni.YieldExpr) -> MirValue {
    raise MirRefused(
        mir_refusal(
            "expression",
            "yield as a value",
            nd,
            "A native generator yields as a statement; nothing is sent back into it, so a yield cannot be used as a value."
        )
    );
}

impl MirLowering.runtime_value(name: str, args: list[MirValue]) -> MirValue {
    made = self.runtime(name, args);
    if made is None {
        raise RuntimeError(f"runtime function {name} returns no value");
    }
    return made;
}

impl MirLowering.iter_open(value: MirValue, site: uni.UniNode) -> MirIterCursor {
    b = self.builder();
    t = value.type;
    if t.kind == MirKind.LIST {
        position = self.temp_slot(mir_int());
        b.store(position, b.const_int(-1, mir_int()));
        return MirIterCursor(
            kind="list", elem=t.payload(), source=self.spill(value), position=position
        );
    }
    if t.kind in (MirKind.DICT, MirKind.SET) {
        position = self.temp_slot(mir_int());
        b.store(position, b.const_int(-1, mir_int()));
        return MirIterCursor(
            kind="keys", elem=t.args[0], source=self.spill(value), position=position
        );
    }
    if t.kind == MirKind.RANGE {
        base = self.address_of(value);
        position = self.temp_slot(mir_int());
        limit = self.temp_slot(mir_int());
        stride = self.temp_slot(mir_int());
        b.store(position, self.emit_value(MirOp.MEM_LOAD, mir_int(), [base]));
        b.store(
            limit,
            self.emit_value(
                MirOp.MEM_LOAD,
                mir_int(),
                [b.binary("add", base, b.const_int(8, mir_int()))]
            )
        );
        b.store(
            stride,
            self.emit_value(
                MirOp.MEM_LOAD,
                mir_int(),
                [b.binary("add", base, b.const_int(16, mir_int()))]
            )
        );
        return MirIterCursor(
            kind="range", elem=mir_int(), position=position, limit=limit, stride=stride
        );
    }
    if t.kind == MirKind.ITER {
        return MirIterCursor(
            kind="iter",
            elem=t.payload(),
            source=self.spill(value),
            out=self.temp_slot(mir_int())
        );
    }
    if t.kind == MirKind.STR {
        return self.iter_open(self.iter_value(value, site), site);
    }
    if t.kind in (MirKind.BYTES, MirKind.BYTEARRAY) {
        position = self.temp_slot(mir_int());
        b.store(position, b.const_int(-1, mir_int()));
        return MirIterCursor(
            kind="bytes", elem=mir_int(), source=self.spill(value), position=position
        );
    }
    if t.kind == MirKind.TUPLE {
        return self.tuple_cursor(value, self.tuple_elem(value, site));
    }
    found = self.user_cursor(value, site);
    if found is not None {
        return found;
    }
    raise MirRefused(mir_refusal("iteration", t.render(), site));
}

impl MirLowering.iter_step(
    cursor: MirIterCursor, body: MirBlock, done: MirBlock
) -> MirValue {
    b = self.builder();
    one = b.const_int(1, mir_int());
    zero = b.const_int(0, mir_int());
    if cursor.kind in ("list", "enum") and cursor.position is not None {
        current = b.load(cursor.position, mir_int());
        following = b.binary("add", current, one);
        b.store(cursor.position, following);
        if cursor.kind == "enum" {
            b.cond_branch(
                b.compare(
                    "lt", following, b.const_int(len(cursor.payloads), mir_int())
                ),
                body,
                done
            );
            b.position(body);
            index = b.load(cursor.position, mir_int());
            result = b.const_int(cursor.payloads[-1], cursor.elem);
            for (at, payload) in reversed(list(enumerate(cursor.payloads))[:-1]) {
                result = b.select(
                    b.compare("eq", index, b.const_int(at, mir_int())),
                    b.const_int(payload, cursor.elem),
                    result
                );
            }
            return result;
        }
        source = cursor.source;
        if source is None {
            raise RuntimeError("list cursor has no source");
        }
        b.cond_branch(
            b.compare("lt", following, self.container_len(source)), body, done
        );
        b.position(body);
        return self.list_read(source, b.load(cursor.position, mir_int()));
    }
    if cursor.kind == "keys"
        and cursor.position is not None
        and cursor.source is not None {
        source = cursor.source;
        upcoming = self.runtime_value(
            "__jac_rt_dict_next", [source, b.load(cursor.position, mir_int())]
        );
        b.store(cursor.position, upcoming);
        b.cond_branch(b.compare("ge", upcoming, zero), body, done);
        b.position(body);
        at = b.load(cursor.position, mir_int());
        kind = self.elem_kind(cursor.elem, self.module);
        if kind in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY) {
            handle = self.runtime_value(
                "__jac_rt_dict_key_ref", [source, at, b.const_int(kind, mir_int())]
            );
            return self.owned_element(handle, cursor.elem);
        }
        return self.scalar_from_bits(
            self.runtime_value("__jac_rt_dict_key_at", [source, at]), cursor.elem
        );
    }
    if cursor.kind == "range"
        and cursor.position is not None
        and cursor.limit is not None
        and cursor.stride is not None {
        now = b.load(cursor.position, mir_int());
        end = b.load(cursor.limit, mir_int());
        pace = b.load(cursor.stride, mir_int());
        more = b.select(
            b.compare("gt", pace, zero),
            b.compare("lt", now, end),
            b.compare("gt", now, end)
        );
        b.cond_branch(more, body, done);
        b.position(body);
        was = b.load(cursor.position, mir_int());
        step_value = b.load(cursor.stride, mir_int());
        b.store(
            cursor.position,
            b.select(
                b.overflows("add", was, step_value),
                b.load(cursor.limit, mir_int()),
                b.binary("add", was, step_value)
            )
        );
        return was;
    }
    if cursor.kind == "iter" and cursor.source is not None and cursor.out is not None {
        b.cond_branch(self.iter_advance(cursor.source, cursor.out), body, done);
        b.position(body);
        return self.element_from_bits(b.load(cursor.out, mir_int()), cursor.elem);
    }
    if cursor.kind == "bytes"
        and cursor.source is not None
        and cursor.position is not None {
        following = b.binary("add", b.load(cursor.position, mir_int()), one);
        b.store(cursor.position, following);
        (data, size) = self.byte_parts(cursor.source);
        b.cond_branch(b.compare("lt", following, size), body, done);
        b.position(body);
        return self.byte_at(data, following);
    }
    if cursor.kind == "group" {
        return self.step_group(cursor, body, done);
    }
    if cursor.kind == "map" and cursor.callee is not None {
        values = self.step_parts(cursor.parts, None, body, done);
        return self.call_closure(cursor.callee, values, cursor.site or self.module);
    }
    if cursor.kind == "filter" {
        return self.step_filter(cursor, body, done);
    }
    if cursor.kind == "user" {
        return self.step_user(cursor, body, done);
    }
    if cursor.kind == "tuple" {
        return self.step_tuple(cursor, body, done);
    }
    raise RuntimeError(f"malformed iteration cursor {cursor.kind}");
}

impl MirLowering.iter_advance(it: MirValue, out: MirValue) -> MirValue {
    b = self.builder();
    i8p = mir_c_ptr(mir_int(8, False));
    base = self.address_of(it);
    code = self.emit_value(MirOp.MEM_LOAD, mir_int(), [base]);
    state = self.emit_value(
        MirOp.PTR_CAST,
        i8p,
        [
            self.emit_value(
                MirOp.MEM_LOAD,
                mir_int(),
                [b.binary("add", base, b.const_int(8, mir_int()))]
            )
        ]
    );
    target = self.emit_value(MirOp.PTR_CAST, mir_c_fn([i8p, i8p], mir_bool()), [code]);
    return self.emit_value(
        MirOp.CALL_FNPTR,
        mir_bool(),
        [target, state, self.emit_value(MirOp.PTR_CAST, i8p, [out])]
    );
}

impl MirLowering.element_from_bits(bits: MirValue, elem: MirType) -> MirValue {
    if elem.kind == MirKind.NONE {
        return self.none_value();
    }
    kind = self.elem_kind(elem, self.module);
    if kind in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY) {
        return self.owned_element(self.builder().ref_cast(bits, mir_ref(), True), elem);
    }
    return self.scalar_from_bits(bits, elem);
}

impl MirLowering.iter_value(value: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    t = value.type;
    if t.kind == MirKind.ITER {
        return value;
    }
    if t.kind == MirKind.LIST {
        made = self.runtime_value(
            "__jac_rt_iter_list",
            [value, b.const_int(self.elem_kind(t.payload(), site), mir_int())]
        );
        return b.ref_cast(made, mir_iter(t.payload()), True);
    }
    if t.kind in (MirKind.DICT, MirKind.SET) {
        made = self.runtime_value(
            "__jac_rt_iter_keys",
            [value, b.const_int(self.elem_kind(t.args[0], site), mir_int())]
        );
        return b.ref_cast(made, mir_iter(t.args[0]), True);
    }
    if t.kind == MirKind.RANGE {
        base = self.address_of(value);
        made = self.runtime_value(
            "__jac_rt_iter_range",
            [
                self.emit_value(MirOp.MEM_LOAD, mir_int(), [base]),
                self.emit_value(
                    MirOp.MEM_LOAD,
                    mir_int(),
                    [b.binary("add", base, b.const_int(8, mir_int()))]
                ),
                self.emit_value(
                    MirOp.MEM_LOAD,
                    mir_int(),
                    [b.binary("add", base, b.const_int(16, mir_int()))]
                )
            ]
        );
        return b.ref_cast(made, mir_iter(mir_int()), True);
    }
    if t.kind == MirKind.STR {
        held = self.runtime_value(
            "__jac_rt_str_ref",
            [
                b.str_part(value, "root"),
                b.str_part(value, "data"),
                b.str_part(value, "len")
            ]
        );
        made = self.runtime_value("__jac_rt_iter_str", [held]);
        return b.ref_cast(made, mir_iter(mir_str_ref()), True);
    }
    if t.kind in (MirKind.BYTES, MirKind.BYTEARRAY) {
        return self.iter_adapter("each", mir_int(), [value], site);
    }
    if t.kind == MirKind.TUPLE {
        return self.iter_value(self.tuple_items(value, site), site);
    }
    iterated = self.user_method(value, "__iter__", site);
    if iterated is not None and iterated.type.kind != MirKind.OBJ {
        return self.iter_value(iterated, site);
    }
    if iterated is not None {
        elem = self.user_next(iterated, site).elem;
        return self.iter_adapter(
            "next",
            mir_str_ref() if elem.kind == MirKind.STR else elem,
            [iterated],
            site
        );
    }
    raise MirRefused(mir_refusal("iteration", t.render(), site));
}

impl MirLowering.iter_coerce(
    value: MirValue, to: MirType, site: uni.UniNode
) -> MirValue {
    made = self.iter_value(value, site);
    if made.type is not to {
        raise MirRefused(
            mir_refusal("conversion", f"{value.type.render()} to {to.render()}", site)
        );
    }
    return made;
}

impl MirLowering.builtin_source(nd: uni.UniNode, names: list[str]) -> str {
    if not isinstance(nd, uni.FuncCall) or not isinstance(nd.target, uni.Name) {
        return "";
    }
    if nd.target.value not in names {
        return "";
    }
    callee = nd.callee_decl;
    if callee is not None
        and os.path.basename(callee.loc.mod_path)
            not in ("builtins.pyi", "builtins.jac", "na_builtins.pyi") {
        return "";
    }
    return nd.target.value;
}

impl MirLowering.is_special_source(nd: uni.Expr) -> bool {
    return bool(self.builtin_source(nd, ["enumerate", "zip", "map", "filter"]))
        or self.is_enum_class(nd);
}

impl MirLowering.open_sources(
    collection: uni.Expr
) -> tuple[list[MirIterCursor], (MirValue | None)] {
    b = self.builder();
    name = self.builtin_source(collection, ["enumerate", "zip", "map", "filter"]);
    if self.is_enum_class(collection) {
        return ([self.enum_cursor(collection)], None);
    }
    if name in ("map", "filter") {
        return ([self.open_cursor(collection)], None);
    }
    if not name or not isinstance(collection, uni.FuncCall) {
        return ([self.iter_open(self.lower_expr(collection), collection)], None);
    }
    (args, named) = self.split_args(collection);
    if name == "enumerate" {
        start = named.get("start");
        if len(args) == 2 and start is None {
            start = args[1];
        }
        if len(args) not in (1, 2) or len(named) > (1 if "start" in named else 0) {
            raise MirRefused(mir_refusal("call", "enumerate arguments", collection));
        }
        counter = self.temp_slot(mir_int());
        b.store(
            counter,
            self.coerce(self.lower_expr(start), mir_int(), start)
                if start is not None
                else b.const_int(0, mir_int())
        );
        return ([self.open_cursor(args[0])], counter);
    }
    if named {
        raise MirRefused(
            mir_refusal("call", f"{name} with keyword arguments", collection)
        );
    }
    return ([self.open_cursor(arg) for arg in args], None);
}

impl MirLowering.step_sources(
    cursors: list[MirIterCursor], counter: (MirValue | None), done: MirBlock
) -> list[MirValue] {
    return self.step_parts(cursors, counter, self.st().fn.new_block("each.body"), done);
}

impl MirLowering.step_parts(
    parts: list[MirIterCursor],
    counter: (MirValue | None),
    body: MirBlock,
    done: MirBlock
) -> list[MirValue] {
    b = self.builder();
    fn = self.st().fn;
    values: list[MirValue] = [];
    for (index, cursor) in enumerate(parts) {
        last = index + 1 == len(parts);
        element = self.iter_step(
            cursor, body if last else fn.new_block("each.body"), done
        );
        values.append(element if last else self.spill(element));
    }
    if counter is not None {
        current = b.load(counter, mir_int());
        b.store(counter, b.binary("add", current, b.const_int(1, mir_int())));
        values.insert(0, current);
    }
    return values;
}

impl MirLowering.step_group(
    cursor: MirIterCursor, body: MirBlock, done: MirBlock
) -> MirValue {
    values = self.step_parts(cursor.parts, cursor.counter, body, done);
    if len(values) == 1 {
        return values[0];
    }
    return self.emit_value(
        MirOp.TUPLE_MAKE, mir_tuple([value.type for value in values]), values
    );
}

impl MirLowering.step_filter(
    cursor: MirIterCursor, body: MirBlock, done: MirBlock
) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    site = cursor.site or self.module;
    retry = fn.new_block("filter.next");
    b.branch(retry);
    b.position(retry);
    value = self.spill(
        self.iter_step(cursor.parts[0], fn.new_block("filter.item"), done)
    );
    verdict = self.truthy(
        self.call_closure(cursor.callee, [value], site)
            if cursor.callee is not None
            else value,
        site
    );
    b.cond_branch(verdict, body, retry);
    b.position(body);
    return value;
}

impl MirLowering.step_user(
    cursor: MirIterCursor, body: MirBlock, done: MirBlock
) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    site = cursor.site or self.module;
    source = cursor.source;
    if source is None {
        raise RuntimeError("user iteration cursor has no iterator");
    }
    frame = fn.new_value(mir_c_ptr(mir_int(8, False)), "exc.frame");
    fn.blocks[0].instrs.insert(0, MirInstr(op=MirOp.EXC_FRAME, result=frame));
    self.runtime("__jac_rt_exc_push", [frame]);
    buffer = self.runtime_value("__jac_rt_exc_jmp_buf", [frame]);
    armed = self.emit_value(MirOp.SETJMP, mir_int(32, True, True), [buffer]);
    caught = fn.new_block("user.caught");
    stopped = fn.new_block("user.stop");
    failed = fn.new_block("user.raise");
    b.cond_branch(b.compare("eq", armed, b.const_int(0, armed.type)), body, caught);
    b.position(caught);
    self.runtime("__jac_rt_exc_pop", [frame]);
    address = self.address_of(frame);
    type_id = self.emit_value(
        MirOp.MEM_LOAD,
        mir_int(32, True, True),
        [b.binary("add", address, b.const_int(EXC_TYPE_OFFSET, mir_int()))]
    );
    stop_id = b.const_int(
        JAC_TYPE_REGISTRY.exception_type_id("StopIteration"), type_id.type
    );
    b.cond_branch(b.compare("eq", type_id, stop_id), stopped, failed);
    b.position(failed);
    message = self.emit_value(
        MirOp.PTR_CAST,
        mir_c_ptr(mir_int(8, False)),
        [
            self.emit_value(
                MirOp.MEM_LOAD,
                mir_int(),
                [b.binary("add", address, b.const_int(EXC_MESSAGE_OFFSET, mir_int()))]
            )
        ]
    );
    origin = self.emit_value(
        MirOp.PTR_CAST,
        mir_c_ptr(mir_int(8, False)),
        [self.emit_value(MirOp.MEM_LOAD, mir_int(), [address])]
    );
    self.runtime("__jac_rt_raise", [origin, type_id, message]);
    b.unreachable();
    b.position(stopped);
    b.branch(done);
    b.position(body);
    made = self.user_method(source, "__next__", site);
    if made is None {
        raise MirRefused(mir_refusal("iteration", source.type.render(), site));
    }
    self.runtime("__jac_rt_exc_pop", [frame]);
    return made;
}

impl MirLowering.open_cursor(source: uni.Expr) -> MirIterCursor {
    name = self.builtin_source(source, ["enumerate", "zip", "map", "filter"]);
    if name in ("enumerate", "zip") and isinstance(source, uni.FuncCall) {
        (cursors, counter) = self.open_sources(source);
        if len(cursors) == 1 and counter is None {
            return cursors[0];
        }
        return MirIterCursor(
            kind="group",
            elem=mir_tuple(
                ([mir_int()] if counter is not None else [])
                    + [cursor.elem for cursor in cursors]
            ),
            parts=cursors,
            counter=counter,
            site=source
        );
    }
    if name not in ("map", "filter") or not isinstance(source, uni.FuncCall) {
        return self.iter_open(self.lower_expr(source), source);
    }
    (args, named) = self.split_args(source);
    if named or len(args) < 2 or (name == "filter" and len(args) != 2) {
        raise MirRefused(mir_refusal("call", f"{name} arguments", source));
    }
    if name == "filter" and isinstance(args[0], uni.Null) {
        return self.filter_cursor(None, self.open_cursor(args[1]), source);
    }
    callee = self.adapter_callee(args[0], name);
    if name == "filter" {
        return self.filter_cursor(callee, self.open_cursor(args[1]), source);
    }
    return self.map_cursor(callee, [self.open_cursor(arg) for arg in args[1:]], source);
}

impl MirLowering.adapter_callee(arg: uni.Expr, name: str) -> MirValue {
    callee = self.lower_expr(arg);
    if callee.type.kind == MirKind.C_FN and callee.id in self.fn_values {
        callee = self.coerce(
            callee, mir_fn(callee.type.args[1:], callee.type.args[0]), arg
        );
    }
    if callee.type.kind != MirKind.FN {
        raise MirRefused(
            mir_refusal("call", f"{name} over {callee.type.render()}", arg)
        );
    }
    return self.spill(callee);
}

impl MirLowering.map_cursor(
    callee: MirValue, parts: list[MirIterCursor], site: uni.UniNode
) -> MirIterCursor {
    if len(callee.type.args) - 1 != len(parts) {
        raise MirRefused(
            mir_refusal(
                "call",
                f"map of a {len(callee.type.args) - 1}-argument function over {len(
                    parts
                )} iterables",
                site
            )
        );
    }
    return MirIterCursor(
        kind="map", elem=callee.type.args[0], parts=parts, callee=callee, site=site
    );
}

impl MirLowering.filter_cursor(
    callee: (MirValue | None), part: MirIterCursor, site: uni.UniNode
) -> MirIterCursor {
    if callee is not None and len(callee.type.args) != 2 {
        raise MirRefused(mir_refusal("call", "filter predicate arity", site));
    }
    return MirIterCursor(
        kind="filter", elem=part.elem, parts=[part], callee=callee, site=site
    );
}

impl MirLowering.user_cursor(
    value: MirValue, site: uni.UniNode
) -> (MirIterCursor | None) {
    if value.type.kind != MirKind.OBJ {
        return None;
    }
    made = self.user_method(value, "__iter__", site);
    if made is None {
        return None;
    }
    if made.type.kind != MirKind.OBJ {
        return self.iter_open(made, site);
    }
    return self.user_next(self.spill(made), site);
}

impl MirLowering.user_next(it: MirValue, site: uni.UniNode) -> MirIterCursor {
    arch = self.archetypes.get(it.type.name) if it.type.kind == MirKind.OBJ else None;
    method = self.find_method(arch, "__next__") if arch is not None else None;
    if arch is None or method is None {
        raise MirRefused(
            mir_refusal(
                "iteration",
                it.type.render(),
                site,
                "An object's __iter__ must return an iterator: an object with __next__, or a native iterator."
            )
        );
    }
    decl = self.method_decl(arch, method, "__next__", site);
    return MirIterCursor(kind="user", elem=decl.ret, source=it, site=site);
}

impl MirLowering.user_method(
    receiver: MirValue, name: str, site: uni.UniNode
) -> (MirValue | None) {
    if receiver.type.kind != MirKind.OBJ {
        return None;
    }
    arch = self.archetypes.get(receiver.type.name);
    method = self.find_method(arch, name) if arch is not None else None;
    if arch is None or method is None {
        return None;
    }
    if id(method) in self.templates {
        raise MirRefused(
            mir_refusal("method", f"generic {archetype_native_name(arch)}.{name}", site)
        );
    }
    decl = self.method_decl(arch, method, name, site);
    if decl.params {
        raise MirRefused(
            mir_refusal(
                "method", f"{archetype_native_name(arch)}.{name} parameters", site
            )
        );
    }
    held = self.method_receiver(decl, arch, receiver, site);
    return self.invoke_method(decl, arch, name, [held]);
}

impl MirLowering.tuple_elem(value: MirValue, site: uni.UniNode) -> MirType {
    members = list(value.type.args);
    if not members {
        raise MirRefused(mir_refusal("iteration", "empty tuple", site));
    }
    elem = members[0];
    if all(member is elem for member in members) {
        return elem;
    }
    for member in members {
        if member.kind not in ANY_BOXABLE {
            raise MirRefused(
                mir_refusal(
                    "iteration",
                    value.type.render(),
                    site,
                    f"A tuple whose members share no representation iterates as `any`, and a {member.render()} has no `any` box."
                )
            );
        }
    }
    return mir_any();
}

impl MirLowering.tuple_cursor(value: MirValue, elem: MirType) -> MirIterCursor {
    position = self.temp_slot(mir_int());
    self.builder().store(position, self.builder().const_int(-1, mir_int()));
    return MirIterCursor(
        kind="tuple", elem=elem, source=self.spill(value), position=position
    );
}

impl MirLowering.step_tuple(
    cursor: MirIterCursor, body: MirBlock, done: MirBlock
) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    source = cursor.source;
    position = cursor.position;
    if source is None or position is None {
        raise RuntimeError("tuple cursor has no tuple");
    }
    site = cursor.site or self.module;
    size = len(source.type.args);
    following = b.binary("add", b.load(position, mir_int()), b.const_int(1, mir_int()));
    b.store(position, following);
    b.cond_branch(b.compare("lt", following, b.const_int(size, mir_int())), body, done);
    b.position(body);
    held = self.temp_slot(cursor.elem);
    joined = fn.new_block("tuple.item");
    for index in range(size) {
        hit = fn.new_block("tuple.member");
        missed = joined;
        if index + 1 < size {
            missed = fn.new_block("tuple.next");
            b.cond_branch(
                b.compare("eq", following, b.const_int(index, mir_int())), hit, missed
            );
        } else {
            b.branch(hit);
        }
        b.position(hit);
        b.store(held, self.coerce(self.tuple_get(source, index), cursor.elem, site));
        b.branch(joined);
        b.position(missed);
    }
    return b.load(held, cursor.elem);
}

impl MirLowering.tuple_items(value: MirValue, site: uni.UniNode) -> MirValue {
    elem = self.tuple_elem(value, site);
    if elem.kind == MirKind.STR {
        elem = mir_str_ref();
    }
    members = list(value.type.args);
    held = self.spill(value);
    made = self.spill(self.new_list(elem, len(members)));
    kind = self.builder().const_int(self.elem_kind(elem, site), mir_int());
    for index in range(len(members)) {
        self.runtime(
            "__jac_rt_list_push",
            [
                made,
                self.to_bits(
                    self.coerce(self.tuple_get(held, index), elem, site), elem, site
                ),
                kind
            ]
        );
    }
    return made;
}

impl MirLowering.adapter_value(nd: uni.FuncCall, name: str) -> MirValue {
    result_type = self.expr_type(nd);
    if result_type.kind != MirKind.ITER {
        raise MirRefused(mir_refusal("call", f"{name} as {result_type.render()}", nd));
    }
    (args, named) = self.split_args(nd);
    if named or len(args) < 2 or (name == "filter" and len(args) != 2) {
        raise MirRefused(mir_refusal("call", f"{name} arguments", nd));
    }
    if name == "filter" and isinstance(args[0], uni.Null) {
        return self.iter_adapter(
            "truthy",
            result_type.payload(),
            [self.iter_value(self.lower_expr(args[1]), args[1])],
            nd
        );
    }
    callee = self.adapter_callee(args[0], name);
    sources = [
        self.spill(self.iter_value(self.lower_expr(arg), arg)) for arg in args[1:]
    ];
    return self.iter_adapter(name, result_type.payload(), [callee] + sources, nd);
}

impl MirLowering.adapter_cursor(
    kind: str, elem: MirType, inputs: list[MirValue], site: uni.UniNode
) -> MirIterCursor {
    if kind == "map" {
        return self.map_cursor(
            inputs[0], [self.iter_open(value, site) for value in inputs[1:]], site
        );
    }
    if kind == "filter" {
        return self.filter_cursor(inputs[0], self.iter_open(inputs[1], site), site);
    }
    if kind == "truthy" {
        return self.filter_cursor(None, self.iter_open(inputs[0], site), site);
    }
    if kind == "next" {
        return self.user_next(inputs[0], site);
    }
    return self.iter_open(inputs[0], site);
}

impl MirLowering.iter_adapter(
    kind: str, elem: MirType, inputs: list[MirValue], site: uni.UniNode
) -> MirValue {
    key = f"iter.{kind}({', '.join(value.type.render() for value in inputs)}) -> {elem.render()}";
    symbol = self.adapters.get(key);
    if symbol is None {
        symbol = f"{self.mir.prefix}.__iter_{kind}_{len(self.adapters)}";
        i8p = mir_c_ptr(mir_int(8, False));
        resume = MirFunction(
            name=f"__iter_{kind}.__next",
            symbol=f"{symbol}.__next",
            ret=mir_none(),
            resumable=True,
            linkage="internal"
        );
        start = MirFunction(
            name=f"__iter_{kind}", symbol=symbol, ret=mir_iter(elem), linkage="internal"
        );
        saved = self.state;
        try {
            frame = resume.new_value(i8p, "frame");
            out = resume.new_value(i8p, "out");
            resume.params.append(MirParam(name="frame", value=frame));
            resume.params.append(MirParam(name="out", value=out));
            self.state = MirFnState(
                fn=resume,
                b=MirBuilder(fn=resume, block=resume.new_block("entry")),
                generator=MirGenInfo(elem=elem, frame=frame, out=out)
            );
            slots = [self.temp_slot(value.type) for value in inputs];
            held = [self.builder().load(slot, slot.type) for slot in slots];
            cursor = self.adapter_cursor(kind, elem, held, site);
            head = resume.new_block("adapt.head");
            after = resume.new_block("adapt.exit");
            self.builder().branch(head);
            self.builder().position(head);
            element = self.iter_step(cursor, resume.new_block("adapt.body"), after);
            self.yield_value(element, site);
            self.builder().branch(head);
            self.builder().position(after);
            self.builder().ret(None);
            for blk in resume.blocks {
                if not blk.terminated() {
                    self.builder().position(blk);
                    self.builder().unreachable();
                }
            }
            self.state = MirFnState(
                fn=start, b=MirBuilder(fn=start, block=start.new_block("entry"))
            );
            b = self.builder();
            values: list[MirValue] = [];
            for (index, value) in enumerate(inputs) {
                param = start.new_value(value.type, f"a{index}");
                start.params.append(MirParam(name=f"a{index}", value=param));
                values.append(param);
            }
            frame_obj = start.new_value(mir_ref(), "frame");
            frame_obj.owned = True;
            b.emit(
                MirInstr(
                    op=MirOp.FRAME_NEW,
                    result=frame_obj,
                    callee=resume.symbol,
                    type_arg=mir_ref()
                )
            );
            for (value, slot) in zip(values, slots) {
                place = self.emit_value(
                    MirOp.FRAME_FIELD,
                    mir_c_ptr(slot.type),
                    [frame_obj],
                    callee=resume.symbol,
                    int_value=slot.id
                );
                b.store(place, value);
            }
            code = self.emit_value(
                MirOp.PTR_INT,
                mir_int(),
                [
                    self.emit_value(
                        MirOp.FN_ADDR,
                        mir_c_fn([i8p, i8p], mir_bool()),
                        [],
                        callee=resume.symbol
                    )
                ]
            );
            made = self.runtime_value("__jac_rt_iter_new", [code, frame_obj]);
            b.ret(b.ref_cast(made, start.ret, True));
        } except MirRefused as err {
            self.state = saved;
            raise err;
        }
        self.state = saved;
        self.nested.append(start);
        self.nested.append(resume);
        self.adapters[key] = symbol;
    }
    adapted = self.builder().call(symbol, inputs, mir_iter(elem));
    if adapted is None {
        raise RuntimeError(f"iterator adapter {symbol} returns no value");
    }
    return adapted;
}

impl MirLowering.bind_values(
    target: uni.Expr, values: list[MirValue], site: uni.UniNode
) {
    if len(values) == 1 {
        self.bind_target(target, values[0]);
        return;
    }
    if isinstance(target, uni.AtomUnit) and isinstance(target.value, uni.Expr) {
        self.bind_values(target.value, values, site);
        return;
    }
    if isinstance(target, uni.TupleVal) and len(target.values) == len(values) {
        for (part, value) in zip(target.values, values) {
            if not isinstance(part, uni.Expr) {
                raise MirRefused(mir_refusal("for target", type(part).__name__, part));
            }
            self.bind_target(part, value);
        }
        return;
    }
    if isinstance(target, uni.Name) {
        made = self.emit_value(
            MirOp.TUPLE_MAKE, mir_tuple([value.type for value in values]), values
        );
        self.store_name(target, made);
        return;
    }
    raise MirRefused(mir_refusal("for target", type(target).__name__, site));
}

impl MirLowering.bind_target(target: uni.Expr, value: MirValue) {
    if isinstance(target, uni.Name) {
        self.store_name(target, value);
    } elif isinstance(target, uni.AtomUnit) and isinstance(target.value, uni.Expr) {
        self.bind_target(target.value, value);
    } elif isinstance(target, uni.TupleVal) {
        self.unpack_into(
            [
                part
                for part in target.values
                if isinstance(part, uni.Expr)
            ],
            value,
            target
        );
    } else {
        raise MirRefused(mir_refusal("for target", type(target).__name__, target));
    }
}

impl MirLowering.lower_for_sources(nd: uni.InForStmt, holder: (MirValue | None)) {
    b = self.builder();
    fn = self.st().fn;
    cursors: list[MirIterCursor] = [];
    counter: (MirValue | None) = None;
    if holder is None {
        (cursors, counter) = self.open_sources(nd.collection);
    } elif holder.type.kind == MirKind.TUPLE
        and isinstance(nd.target, uni.Name)
        and nd.target.sym is not None {
        cursors = [
            self.tuple_cursor(holder, self.symbol_type(nd.target.sym, nd.target))
        ];
    } else {
        cursors = [self.iter_open(holder, nd)];
    }
    head = fn.new_block("each.head");
    otherwise = fn.new_block("each.else");
    after = fn.new_block("each.exit");
    b.branch(head);
    b.position(head);
    values = self.step_sources(cursors, counter, otherwise);
    self.bind_values(nd.target, values, nd);
    self.st().loops.append(MirLoopTarget(head=head, after=after));
    self.lower_body(nd.body);
    self.st().loops.pop();
    if not self.builder().block.terminated() {
        self.builder().branch(head);
    }
    b.position(otherwise);
    self.lower_else(nd.else_body, after);
    b.position(after);
}

impl MirLowering.split_args(
    nd: uni.FuncCall
) -> tuple[list[uni.Expr], dict[str, uni.Expr]] {
    args: list[uni.Expr] = [];
    named: dict[str, uni.Expr] = {};
    for arg in list(nd.params or []) {
        if isinstance(arg, uni.KWPair) {
            if arg.key is None {
                raise MirRefused(
                    mir_refusal("call argument", "keyword unpacking", arg)
                );
            }
            named[arg.key.sym_name] = arg.value;
        } else {
            args.append(arg);
        }
    }
    return (args, named);
}

impl MirLowering.iter_builtin(nd: uni.FuncCall, name: str) -> (MirValue | None) {
    if name
        not in (
            "iter",
            "next",
            "range",
            "sorted",
            "sum",
            "any",
            "all",
            "enumerate",
            "zip",
            "map",
            "filter"
        ) {
        return None;
    }
    if name in ("map", "filter") {
        return self.adapter_value(nd, name);
    }
    b = self.builder();
    (args, named) = self.split_args(nd);
    if name in ("enumerate", "zip") {
        raise MirRefused(
            mir_refusal(
                "call",
                name,
                nd,
                f"Native {name}() is the source of a for loop or a comprehension; its tuples are not kept as an iterator value."
            )
        );
    }
    if name == "sorted" {
        return self.builtin_sorted(nd, args, named);
    }
    if named {
        raise MirRefused(mir_refusal("call", f"{name} with keyword arguments", nd));
    }
    if name == "iter" and len(args) == 1 {
        return self.iter_value(self.lower_expr(args[0]), nd);
    }
    if name == "next" and len(args) in (1, 2) {
        return self.builtin_next(nd, args);
    }
    if name == "range" and 1 <= len(args) <= 3 {
        values = [self.coerce(self.lower_expr(arg), mir_int(), arg) for arg in args];
        start = b.const_int(0, mir_int());
        step = b.const_int(1, mir_int());
        stop = values[0];
        if len(values) >= 2 {
            start = values[0];
            stop = values[1];
        }
        if len(values) == 3 {
            step = values[2];
            self.raise_if(
                b.compare("eq", step, b.const_int(0, mir_int())),
                "ValueError",
                RANGE_STEP_MESSAGE
            );
        }
        made = self.runtime_value("__jac_rt_range_new", [start, stop, step]);
        return b.ref_cast(made, mir_range(), True);
    }
    if name in ("sum", "any", "all") and len(args) == 1 {
        return self.builtin_fold(nd, name, args[0]);
    }
    return None;
}

impl MirLowering.builtin_next(nd: uni.FuncCall, args: list[uni.Expr]) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    it = self.spill(self.lower_expr(args[0]));
    if it.type.kind == MirKind.OBJ and len(args) == 1 {
        made = self.user_method(it, "__next__", nd);
        if made is None {
            raise MirRefused(mir_refusal("call", f"next of {it.type.render()}", nd));
        }
        return self.coerce(made, self.expr_type(nd), nd);
    }
    if it.type.kind == MirKind.OBJ {
        elem = self.user_next(it, nd).elem;
        it = self.spill(
            self.iter_adapter(
                "next", mir_str_ref() if elem.kind == MirKind.STR else elem, [it], nd
            )
        );
    }
    if it.type.kind != MirKind.ITER {
        raise MirRefused(mir_refusal("call", f"next of {it.type.render()}", nd));
    }
    result_type = self.expr_type(nd);
    held = self.temp_slot(result_type);
    out = self.temp_slot(mir_int());
    hit = fn.new_block("next.hit");
    miss = fn.new_block("next.miss");
    done = fn.new_block("next.done");
    b.cond_branch(self.iter_advance(it, out), hit, miss);
    b.position(hit);
    b.store(
        held,
        self.coerce(
            self.element_from_bits(b.load(out, mir_int()), it.type.payload()),
            result_type,
            nd
        )
    );
    b.branch(done);
    b.position(miss);
    if len(args) == 2 {
        b.store(held, self.coerce(self.lower_expr(args[1]), result_type, args[1]));
        b.branch(done);
    } else {
        b.raise_builtin("StopIteration", "");
    }
    b.position(done);
    return b.load(held, result_type);
}

impl MirLowering.builtin_sorted(
    nd: uni.FuncCall, args: list[uni.Expr], named: dict[str, uni.Expr]
) -> MirValue {
    b = self.builder();
    if len(args) != 1 or set(named) - {"reverse", "key"} {
        raise MirRefused(
            mir_refusal(
                "call",
                "sorted arguments",
                nd,
                "Native sorted() takes one iterable and optional `key` and `reverse`."
            )
        );
    }
    result_type = self.expr_type(nd);
    if result_type.kind != MirKind.LIST {
        raise MirRefused(mir_refusal("call", f"sorted as {result_type.render()}", nd));
    }
    elem = result_type.payload();
    kind = self.elem_kind(elem, nd);
    if kind == KIND_REF and "key" not in named {
        raise MirRefused(
            mir_refusal(
                "call",
                f"sorted of {elem.render()}",
                nd,
                "Native sorting orders ints, floats, bools and strings."
            )
        );
    }
    source = self.lower_expr(args[0]);
    made: MirValue;
    if source.type is result_type {
        made = b.ref_cast(
            self.runtime_value(
                "__jac_rt_list_copy", [source, b.const_int(kind, mir_int())]
            ),
            result_type,
            True
        );
    } else {
        made = self.drain(source, elem, nd);
    }
    key_fn: (MirValue | None) = None;
    if "key" in named {
        key_fn = self.key_function(named["key"]);
    }
    flag = b.const_bool(False);
    order = named.get("reverse");
    if order is not None {
        flag = self.truthy(self.lower_expr(order), order);
    }
    if key_fn is not None {
        held = self.spill(made);
        self.keyed_sort(held, key_fn, flag, nd);
        return held;
    }
    self.runtime(
        "__jac_rt_list_sort",
        [made, b.const_int(self.sort_kind(elem, nd), mir_int()), flag]
    );
    return made;
}

impl MirLowering.key_function(key_nd: uni.Expr) -> MirValue {
    made = self.lower_expr(key_nd);
    if made.type.kind != MirKind.FN {
        made = self.coerce(made, self.expr_type(key_nd), key_nd);
    }
    if made.type.kind != MirKind.FN or len(made.type.args) != 2 {
        raise MirRefused(
            mir_refusal(
                "call argument",
                f"key function of {made.type.render()}",
                key_nd,
                "A native sort or min/max key is a function of one argument."
            )
        );
    }
    return self.spill(made);
}

impl MirLowering.key_slot_type(key_fn: MirValue, site: uni.UniNode) -> MirType {
    key_type = key_fn.type.args[0];
    if key_type.kind == MirKind.STR {
        key_type = mir_str_ref();
    }
    if self.elem_kind(key_type, site) == KIND_REF {
        raise MirRefused(
            mir_refusal(
                "call argument",
                f"key of {key_type.render()}",
                site,
                "Native keys order ints, floats, bools, strings, tuples and boxed values."
            )
        );
    }
    return key_type;
}

impl MirLowering.keyed_sort(
    made: MirValue, key_fn: MirValue, flag: MirValue, site: uni.UniNode
) {
    b = self.builder();
    fn = self.st().fn;
    key_type = self.key_slot_type(key_fn, site);
    keys = self.spill(self.new_list(key_type, 8));
    key_kind = b.const_int(self.elem_kind(key_type, site), mir_int());
    cursor = self.temp_slot(mir_int());
    b.store(cursor, b.const_int(0, mir_int()));
    head = fn.new_block("keyed.head");
    body = fn.new_block("keyed.body");
    done = fn.new_block("keyed.done");
    b.branch(head);
    b.position(head);
    at = b.load(cursor, mir_int());
    b.cond_branch(b.compare("lt", at, self.container_len(made)), body, done);
    b.position(body);
    computed = self.call_closure(key_fn, [self.list_read(made, at)], site);
    self.runtime(
        "__jac_rt_list_push", [keys, self.to_bits(computed, key_type, site), key_kind]
    );
    b.store(cursor, b.binary("add", at, b.const_int(1, mir_int())));
    b.branch(head);
    b.position(done);
    self.runtime(
        "__jac_rt_list_sort_keyed",
        [made, keys, b.const_int(self.sort_kind(key_type, site), mir_int()), flag]
    );
}

impl MirLowering.builtin_fold(
    nd: uni.FuncCall, name: str, source: uni.Expr
) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    wanted = self.expr_type(nd);
    result_type = wanted if name == "sum" else mir_bool();
    if name == "sum" and wanted.kind == MirKind.ANY {
        source_type = self.expr_type(source);
        if source_type.kind in (MirKind.LIST, MirKind.SET, MirKind.ITER)
            and source_type.args
            and source_type.payload().kind in (MirKind.INT, MirKind.FLOAT) {
            result_type = source_type.payload();
        }
    }
    held = self.temp_slot(result_type);
    if name == "sum" {
        if not result_type.is_numeric() {
            raise MirRefused(mir_refusal("call", f"sum to {result_type.render()}", nd));
        }
        b.store(held, self.coerce(b.const_int(0, mir_int()), result_type, nd));
    } else {
        b.store(held, b.const_bool(name == "all"));
    }
    (cursors, counter) = self.open_sources(source);
    head = fn.new_block("fold.head");
    after = fn.new_block("fold.exit");
    b.branch(head);
    b.position(head);
    values = self.step_sources(cursors, counter, after);
    if len(values) != 1 {
        raise MirRefused(mir_refusal("call", f"{name} over tuples", nd));
    }
    if name == "sum" {
        b.store(
            held,
            self.coerce(
                self.arith(Tok.PLUS, b.load(held, result_type), values[0], nd),
                result_type,
                nd
            )
        );
        b.branch(head);
    } else {
        verdict = self.truthy(values[0], nd);
        if name == "any" {
            found = fn.new_block("fold.found");
            b.cond_branch(verdict, found, head);
            b.position(found);
            b.store(held, b.const_bool(True));
        } else {
            missed = fn.new_block("fold.missed");
            b.cond_branch(verdict, head, missed);
            b.position(missed);
            b.store(held, b.const_bool(False));
        }
        b.branch(after);
    }
    b.position(after);
    if result_type is not wanted and wanted.kind == MirKind.ANY {
        return b.load(held, result_type);
    }
    return self.coerce(b.load(held, result_type), wanted, nd);
}

impl MirLowering.drain(value: MirValue, elem: MirType, site: uni.UniNode) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    made = self.spill(self.new_list(elem, 8));
    kind = b.const_int(self.elem_kind(elem, site), mir_int());
    walker_state = self.iter_open(value, site);
    head = fn.new_block("drain.head");
    body = fn.new_block("drain.body");
    after = fn.new_block("drain.exit");
    b.branch(head);
    b.position(head);
    element = self.iter_step(walker_state, body, after);
    self.runtime(
        "__jac_rt_list_push",
        [made, self.to_bits(self.coerce(element, elem, site), elem, site), kind]
    );
    b.branch(head);
    b.position(after);
    return made;
}
