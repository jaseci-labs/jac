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
    for (twin, pv) in zip(self.param_nodes(declared, skip_self), self.param_nodes(sig, skip_self)) {
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
            sig = body.spec;
            body = body.body;
        }
        if not isinstance(sig, uni.FuncSignature) or not isinstance(body, (list, tuple)) {
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
        self.state = MirFnState(fn=start, b=MirBuilder(fn=start, block=start.new_block("entry")));
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
            [self.emit_value(
                MirOp.FN_ADDR, mir_c_fn([i8p, i8p], mir_bool()), [], callee=resume.symbol
            )]
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
        if isinstance(cursor, (uni.TryStmt, uni.WithStmt)) {
            raise MirRefused(
                mir_refusal(
                    "expression",
                    "yield inside try or with",
                    nd,
                    "A native generator resumes in a fresh activation, so a handler or context around its yield would not be armed again; move the yield out of the try or with."
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
    b.emit(MirInstr(op=MirOp.YIELD, operands=[shared]));
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
                MirOp.MEM_LOAD, mir_int(), [b.binary("add", base, b.const_int(8, mir_int()))]
            )
        );
        b.store(
            stride,
            self.emit_value(
                MirOp.MEM_LOAD, mir_int(), [b.binary("add", base, b.const_int(16, mir_int()))]
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
                b.compare("lt", following, b.const_int(len(cursor.payloads), mir_int())),
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
        b.cond_branch(b.compare("lt", following, self.container_len(source)), body, done);
        b.position(body);
        return self.list_read(source, b.load(cursor.position, mir_int()));
    }
    if cursor.kind == "keys" and cursor.position is not None and cursor.source is not None {
        source = cursor.source;
        upcoming = self.runtime_value(
            "__jac_rt_dict_next", [source, b.load(cursor.position, mir_int())]
        );
        b.store(cursor.position, upcoming);
        b.cond_branch(b.compare("ge", upcoming, zero), body, done);
        b.position(body);
        at = b.load(cursor.position, mir_int());
        kind = self.elem_kind(cursor.elem, self.module);
        if kind in (KIND_STR, KIND_REF) {
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
            b.compare("gt", pace, zero), b.compare("lt", now, end), b.compare("gt", now, end)
        );
        b.cond_branch(more, body, done);
        b.position(body);
        was = b.load(cursor.position, mir_int());
        by = b.load(cursor.stride, mir_int());
        b.store(
            cursor.position,
            b.select(
                b.overflows("add", was, by),
                b.load(cursor.limit, mir_int()),
                b.binary("add", was, by)
            )
        );
        return was;
    }
    if cursor.kind == "iter" and cursor.source is not None and cursor.out is not None {
        b.cond_branch(self.iter_advance(cursor.source, cursor.out), body, done);
        b.position(body);
        return self.element_from_bits(b.load(cursor.out, mir_int()), cursor.elem);
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
        [self.emit_value(
            MirOp.MEM_LOAD, mir_int(), [b.binary("add", base, b.const_int(8, mir_int()))]
        )]
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
    if kind in (KIND_STR, KIND_REF) {
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
            [b.str_part(value, "root"), b.str_part(value, "data"), b.str_part(value, "len")]
        );
        made = self.runtime_value("__jac_rt_iter_str", [held]);
        return b.ref_cast(made, mir_iter(mir_str()), True);
    }
    raise MirRefused(mir_refusal("iteration", t.render(), site));
}

impl MirLowering.iter_coerce(value: MirValue, to: MirType, site: uni.UniNode) -> MirValue {
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
        and os.path.basename(callee.loc.mod_path) not in ("builtins.pyi", "builtins.jac") {
        return "";
    }
    return nd.target.value;
}

impl MirLowering.is_special_source(nd: uni.Expr) -> bool {
    return bool(self.builtin_source(nd, ["enumerate", "zip"])) or self.is_enum_class(nd);
}

impl MirLowering.open_sources(
    collection: uni.Expr
) -> tuple[list[MirIterCursor], (MirValue | None)] {
    b = self.builder();
    name = self.builtin_source(collection, ["enumerate", "zip"]);
    if self.is_enum_class(collection) {
        return ([self.enum_cursor(collection)], None);
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
        return ([self.iter_open(self.lower_expr(args[0]), args[0])], counter);
    }
    if named {
        raise MirRefused(mir_refusal("call", f"{name} with keyword arguments", collection));
    }
    return ([self.iter_open(self.lower_expr(arg), arg) for arg in args], None);
}

impl MirLowering.step_sources(
    cursors: list[MirIterCursor], counter: (MirValue | None), done: MirBlock
) -> list[MirValue] {
    b = self.builder();
    fn = self.st().fn;
    values: list[MirValue] = [];
    for (index, cursor) in enumerate(cursors) {
        body = fn.new_block("each.body");
        element = self.iter_step(cursor, body, done);
        values.append(self.spill(element) if index + 1 < len(cursors) else element);
    }
    if counter is not None {
        current = b.load(counter, mir_int());
        b.store(counter, b.binary("add", current, b.const_int(1, mir_int())));
        values.insert(0, current);
    }
    return values;
}

impl MirLowering.bind_values(target: uni.Expr, values: list[MirValue], site: uni.UniNode) {
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
        self.unpack_into([part for part in target.values if isinstance(part, uni.Expr)], value, target);
    } else {
        raise MirRefused(mir_refusal("for target", type(target).__name__, target));
    }
}

impl MirLowering.lower_for_sources(nd: uni.InForStmt, holder: (MirValue | None)) {
    b = self.builder();
    fn = self.st().fn;
    (cursors, counter) = self.open_sources(nd.collection)
        if holder is None
        else ([self.iter_open(holder, nd)], None);
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

impl MirLowering.split_args(nd: uni.FuncCall) -> tuple[list[uni.Expr], dict[str, uni.Expr]] {
    args: list[uni.Expr] = [];
    named: dict[str, uni.Expr] = {};
    for arg in list(nd.params or []) {
        if isinstance(arg, uni.KWPair) {
            if arg.key is None {
                raise MirRefused(mir_refusal("call argument", "keyword unpacking", arg));
            }
            named[arg.key.sym_name] = arg.value;
        } else {
            args.append(arg);
        }
    }
    return (args, named);
}

impl MirLowering.iter_builtin(nd: uni.FuncCall, name: str) -> (MirValue | None) {
    if name not in ("iter", "next", "range", "sorted", "sum", "any", "all", "enumerate", "zip") {
        return None;
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
            self.element_from_bits(b.load(out, mir_int()), it.type.payload()), result_type, nd
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
    if len(args) != 1 or set(named) - {"reverse"} {
        raise MirRefused(
            mir_refusal(
                "call",
                "sorted arguments",
                nd,
                "Native sorted() takes one iterable and an optional `reverse`; a `key` function is not lowered."
            )
        );
    }
    result_type = self.expr_type(nd);
    if result_type.kind != MirKind.LIST {
        raise MirRefused(mir_refusal("call", f"sorted as {result_type.render()}", nd));
    }
    elem = result_type.payload();
    kind = self.elem_kind(elem, nd);
    if kind == KIND_REF {
        raise MirRefused(
            mir_refusal("call", f"sorted of {elem.render()}", nd, "Native sorting orders ints, floats, bools and strings.")
        );
    }
    source = self.lower_expr(args[0]);
    made: MirValue;
    if source.type is result_type {
        made = b.ref_cast(
            self.runtime_value("__jac_rt_list_copy", [source, b.const_int(kind, mir_int())]),
            result_type,
            True
        );
    } else {
        made = self.drain(source, elem, nd);
    }
    flag = b.const_bool(False);
    order = named.get("reverse");
    if order is not None {
        flag = self.truthy(self.lower_expr(order), order);
    }
    self.runtime("__jac_rt_list_sort", [made, b.const_int(kind, mir_int()), flag]);
    return made;
}

impl MirLowering.builtin_fold(nd: uni.FuncCall, name: str, source: uni.Expr) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    result_type = self.expr_type(nd);
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
                self.arith(Tok.PLUS, b.load(held, result_type), values[0], nd), result_type, nd
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
    return b.load(held, result_type);
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
    self.runtime("__jac_rt_list_push", [made, self.to_bits(self.coerce(element, elem, site), elem, site), kind]);
    b.branch(head);
    b.position(after);
    return made;
}
