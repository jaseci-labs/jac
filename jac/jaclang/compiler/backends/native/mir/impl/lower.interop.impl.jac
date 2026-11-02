impl MirLowering.python_call(nd: uni.FuncCall) -> (MirValue | None) {
    if not isinstance(nd.target, uni.Name) {
        return None;
    }
    name = nd.target.value;
    binding = self.module.gen.interop_manifest.bindings.get(name);
    if binding is None or not binding.native_callable {
        return None;
    }
    callee = nd.callee_decl;
    if not isinstance(callee, uni.Ability)
        and isinstance(binding.ast_node, uni.Ability) {
        callee = binding.ast_node;
    }
    sig = self.ability_sig(callee) if isinstance(callee, uni.Ability) else None;
    if sig is None or not isinstance(callee, uni.Ability) {
        raise MirRefused(mir_refusal("function signature", name, nd));
    }
    if sig.varargs is not None or sig.kwargs is not None {
        raise MirRefused(
            mir_refusal(
                "function",
                name,
                nd,
                "A variadic function cannot be called across the native interop boundary yet; wrap it in a fixed-arity function on the defining side."
            )
        );
    }
    params = [self.symbol_type(pv.name.sym, pv) for pv in self.param_nodes(sig, False)];
    fn_type = self.prog.get_type_evaluator().get_type_of_symbol(
        self.ability_sym(callee)
    );
    ret = mir_none();
    if isinstance(fn_type, FunctionType) {
        ret = self.type_of(fn_type.return_type, MirPosition.SIGNATURE, nd);
    }
    bound = self.bound_args(nd, callee, False);
    if len(bound) != len(params) {
        raise MirRefused(
            mir_refusal("call", f"{name} with {len(bound)} arguments", nd)
        );
    }
    args = self.bound_values(list(bound), params);
    return self.bridge_call(binding.symbol, binding.name, args, ret, nd);
}

impl MirLowering.bridge_type(t: MirType, site: uni.UniNode) -> MirType {
    if t.kind in (MirKind.INT, MirKind.FLOAT, MirKind.BOOL) {
        return t;
    }
    if t.kind in (MirKind.NONE, MirKind.VOID) {
        return mir_none();
    }
    if t.kind in (MirKind.STR, MirKind.STR_REF) {
        return mir_c_ptr(mir_int(8, False));
    }
    raise MirRefused(
        mir_refusal(
            "Python call",
            f"{t.render()} across the bridge",
            site,
            "Native code calls Python with ints, floats, bools and strings, and receives the same back."
        )
    );
}

impl MirLowering.bridge_type_name(t: MirType) -> str {
    if t.kind == MirKind.INT {
        return t.render();
    }
    if t.kind == MirKind.FLOAT {
        return "float" if t.width == 64 else t.render();
    }
    if t.kind == MirKind.BOOL {
        return "bool";
    }
    if t.kind in (MirKind.STR, MirKind.STR_REF) {
        return "str";
    }
    return "None";
}

impl MirLowering.bridge_call(
    symbol: str, name: str, args: list[MirValue], ret: MirType, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    i8p = mir_c_ptr(mir_int(8, False));
    wire: list[MirValue] = [];
    for arg in args {
        carried = self.bridge_type(arg.type, site);
        if carried.kind == MirKind.C_PTR {
            text = self.coerce(arg, mir_str(), site);
            held = self.runtime_value(
                "__jac_rt_str_ref",
                [
                    b.str_part(text, "root"),
                    b.str_part(text, "data"),
                    b.str_part(text, "len")
                ]
            );
            wire.append(self.emit_value(MirOp.PTR_CAST, i8p, [held]));
        } else {
            wire.append(arg);
        }
    }
    back = self.bridge_type(ret, site);
    self.mir.externs[symbol] = MirExtern(
        symbol=symbol, ret=back, params=[value.type for value in wire]
    );
    if name not in self.mir.python_imports {
        self.mir.python_imports.append(name);
    }
    result = self.emit_value(MirOp.CALL_PYTHON, back, wire, callee=symbol);
    if back.kind == MirKind.NONE {
        return self.none_value();
    }
    if back.kind == MirKind.C_PTR {
        text = self.runtime_value("__jac_rt_str_from_cstr", [result]);
        return b.str_make(text, text, self.runtime_value("__jac_rt_str_size", [text]));
    }
    return result;
}

impl MirLowering.bridge_symbol(symbol: str) {
    if symbol in self.mir.bridged
        or self.prog.options.native_required_for(self.module.loc.mod_path) {
        return;
    }
    decl: (MirDecl | None) = None;
    for candidate in self.decls.values() {
        if candidate.symbol == symbol and candidate.owner is None {
            decl = candidate;
        }
    }
    if decl is None {
        return;
    }
    for t in decl.params + [decl.ret] {
        if t.kind
            not in (
                MirKind.INT,
                MirKind.FLOAT,
                MirKind.BOOL,
                MirKind.NONE,
                MirKind.VOID,
                MirKind.STR,
                MirKind.STR_REF
            ) {
            return;
        }
    }
    sig = self.ability_sig(decl.ability);
    if sig is None {
        return;
    }
    name = self.name_of(decl.ability);
    bridge = interop_callback_symbol(self.module.loc.mod_path, name);
    adapter = MirFunction(name=name, symbol=symbol, ret=decl.ret);
    saved = self.state;
    self.state = MirFnState(
        fn=adapter, b=MirBuilder(fn=adapter, block=adapter.new_block("entry"))
    );
    try {
        args: list[MirValue] = [];
        for (index, ptype) in enumerate(decl.params) {
            value = adapter.new_value(ptype, f"a{index}");
            adapter.params.append(MirParam(name=f"a{index}", value=value));
            args.append(value);
        }
        result = self.bridge_call(bridge, name, args, decl.ret, decl.ability);
        self.builder().ret(
            None if decl.ret.kind in (MirKind.NONE, MirKind.VOID) else result
        );
    } finally {
        self.state = saved;
    }
    self.mir.functions = [
        fn
        for fn in self.mir.functions
        if fn.symbol != symbol
    ]
        + [adapter];
    self.mir.bridged[symbol] = bridge;
    nodes = self.param_nodes(sig, False);
    self.bindings.append(
        InteropBinding(
            name=name,
            source_context=InteropContext.SERVER,
            callers={InteropContext.NATIVE},
            ret_type=self.bridge_type_name(decl.ret),
            param_types=[self.bridge_type_name(t) for t in decl.params],
            param_names=[pv.name.value for pv in nodes],
            ast_node=decl.ability,
            kind="function",
            symbol=bridge
        )
    );
}

impl MirLowering.python_base_of(arch: uni.Archetype) -> (str | None) {
    for base_expr in list(arch.base_classes or []) {
        if isinstance(base_expr, uni.AtomTrailer)
            and isinstance(base_expr.right, uni.IndexSlice) {
            base_expr = base_expr.target;
        }
        if not isinstance(base_expr, uni.Name)
            or base_expr.value in NATIVE_ERASED_BASES {
            continue;
        }
        base_type = base_expr.type;
        if not isinstance(base_type, ClassType) {
            continue;
        }
        if is_enum_class_type(base_type)
            or JAC_TYPE_REGISTRY.is_exception(base_expr.value) {
            continue;
        }
        scope = base_type.shared.symbol_table;
        if isinstance(scope, uni.Archetype) {
            decl_mod = scope.find_parent_of_type(uni.Module);
            path = decl_mod.loc.mod_path if decl_mod is not None else "";
            if path.endswith(".jac") and config_module_pin(path) != "server" {
                continue;
            }
        }
        if base_type.shared.class_name in ("object", "Enum", "IntEnum", "StrEnum") {
            continue;
        }
        return base_expr.value;
    }
    return None;
}

impl MirLowering.c_param_borrowed(pv: uni.ParamVar) -> bool {
    tag = pv.type_tag;
    if tag is None {
        return False;
    }
    if is_borrow_kind(tag.ownership) {
        return True;
    }
    pending: list[uni.UniNode] = [tag.tag];
    while pending {
        expr = pending.pop();
        while isinstance(expr, uni.AtomUnit) and isinstance(expr.value, uni.Expr) {
            expr = expr.value;
        }
        if isinstance(expr, uni.UnaryExpr) and is_borrow_kind(expr.ownership) {
            return True;
        }
        if isinstance(expr, uni.BinaryExpr) {
            pending.append(expr.left);
            pending.append(expr.right);
        }
    }
    return False;
}

impl MirLowering.c_declared_type(
    declared: (TypeBase | None), fallback: (TypeBase | None)
) -> (TypeBase | None) {
    t = declared if declared is not None else fallback;
    if isinstance(t, ClassType) and not t.is_instance() {
        t = t.clone_as_instance();
    }
    if isinstance(t, UnionType) {
        members = [
            member
            for member in t.types
            if not (
                isinstance(member, ClassType)
                and member.shared.class_name in ("NoneType", "None")
            )
        ];
        if len(members) == 1 and len(members) < len(t.types) {
            return members[0];
        }
    }
    return t;
}

impl MirLowering.c_param_plan(
    pv: uni.ParamVar, fallback: (TypeBase | None), site: uni.UniNode
) -> tuple[MirType, str] {
    declared = pv.type;
    if declared is None and pv.type_tag is not None and not self.c_param_borrowed(pv) {
        declared = self.prog.get_type_evaluator().get_type_of_expression(
            pv.type_tag.tag
        );
    }
    t = self.c_declared_type(declared, fallback);
    self.ensure_c_types(t);
    if self.c_param_borrowed(pv) {
        lent = mir_c_elem(t, site);
        if lent.kind == MirKind.C_PIN {
            return (mir_c_ptr(lent.payload()), "pinned");
        }
        return (mir_c_ptr(lent), "lend");
    }
    if isinstance(t, ClassType) and t.shared.class_name in ("str", "bytes") {
        return (mir_c_ptr(mir_int(8, False)), t.shared.class_name);
    }
    return (mir_type_of(t, MirPosition.C_FIELD, site), "value");
}

impl MirLowering.c_bare(nd: uni.Expr) -> uni.Expr {
    inner: uni.Expr = nd;
    while True {
        if isinstance(inner, uni.AtomUnit) and isinstance(inner.value, uni.Expr) {
            inner = inner.value;
        } elif isinstance(inner, uni.CfgExpr) {
            inner = inner.expr;
        } else {
            return inner;
        }
    }
}

impl MirLowering.c_borrow_operand(arg: uni.Expr) -> (uni.Expr | None) {
    bare = self.c_bare(arg);
    if isinstance(bare, uni.UnaryExpr) and is_borrow_kind(bare.ownership) {
        return self.c_bare(bare.operand);
    }
    return None;
}

impl MirLowering.c_same_storage(a: MirType, b: MirType) -> bool {
    if a is b {
        return True;
    }
    if a.kind in (MirKind.INT, MirKind.FLOAT) and a.kind == b.kind {
        return a.width == b.width;
    }
    return a.kind in (MirKind.C_PTR, MirKind.C_FN)
        and b.kind in (MirKind.C_PTR, MirKind.C_FN);
}

impl MirLowering.c_address(place: MirValue, to: MirType) -> MirValue {
    return self.emit_value(MirOp.PTR_CAST, to, [self.coerce_place(place)]);
}

impl MirLowering.c_lend(
    arg: uni.Expr,
    to: MirType,
    exact: bool,
    copybacks: list[tuple[MirValue, MirValue, MirType]]
) -> MirValue {
    b = self.builder();
    operand = self.c_borrow_operand(arg);
    if operand is None {
        arg = self.c_bare(arg);
        if isinstance(arg, uni.Null) {
            return self.emit_value(MirOp.PTR_NULL, to, []);
        }
        if not isinstance(arg, (uni.Name, uni.AtomTrailer))
            or self.expr_type(arg).kind in (MirKind.C_PTR, MirKind.C_FN) {
            value = self.lower_expr(arg);
            if value.type.kind in (MirKind.C_PTR, MirKind.C_FN, MirKind.INT) {
                return self.emit_value(MirOp.PTR_CAST, to, [value]);
            }
            elem = to.payload();
            tmp = self.temp_slot(elem);
            b.store(tmp, self.coerce(value, elem, arg));
            return self.c_address(tmp, to);
        }
        operand = arg;
    }
    place = self.lower_place(operand);
    held = self.place_elem(place);
    elem = to.payload();
    if not exact or self.c_same_storage(held, elem) {
        if mir_holds_ref(held) {
            raise MirRefused(
                mir_refusal(
                    "C pointer argument",
                    held.render(),
                    arg,
                    "`&mut x` lends C storage: a variable or field holding a C scalar, pointer or struct."
                )
            );
        }
        return self.c_address(place, to);
    }
    if mir_holds_ref(held) or elem.kind == MirKind.C_STRUCT {
        raise MirRefused(
            mir_refusal(
                "C pointer argument",
                f"{held.render()} as {elem.render()}",
                arg,
                "`&mut x` passed to a `&mut T` parameter lends a variable whose storage is the C `T`."
            )
        );
    }
    tmp = self.temp_slot(elem);
    b.store(tmp, self.coerce(b.load(place, held), elem, arg));
    copybacks.append((tmp, place, held));
    return self.c_address(tmp, to);
}

impl MirLowering.c_text_arg(value: MirValue, site: uni.UniNode) -> MirValue {
    u8p = mir_c_ptr(mir_int(8, False));
    if value.type.kind in (MirKind.C_PTR, MirKind.INT) {
        return self.emit_value(MirOp.PTR_CAST, u8p, [value]);
    }
    if value.type.kind in (MirKind.BYTES, MirKind.BYTEARRAY) {
        (data, size) = self.byte_parts(self.spill(value));
        return data;
    }
    held = self.coerce(value, mir_str_ref(), site);
    return self.emit_value(MirOp.PTR_CAST, u8p, [held]);
}

impl MirLowering.c_arg(
    arg: uni.Expr,
    to: MirType,
    plan: str,
    copybacks: list[tuple[MirValue, MirValue, MirType]]
) -> MirValue {
    if isinstance(self.c_bare(arg), uni.Null)
        and to.kind in (MirKind.C_PTR, MirKind.C_FN) {
        return self.emit_value(MirOp.PTR_NULL, to, []);
    }
    if plan == "lend" {
        return self.c_lend(arg, to, True, copybacks);
    }
    if plan == "pinned" {
        held = self.c_borrow_operand(arg);
        box = self.lower_expr(held if held is not None else arg);
        if box.type.kind != MirKind.C_PIN {
            raise MirRefused(
                mir_refusal(
                    "C pointer argument",
                    box.type.render(),
                    arg,
                    "A `&mut Pinned[T]` parameter lends the payload of a `Pinned[T]` box made by `pin(...)`."
                )
            );
        }
        return self.emit_value(MirOp.PTR_CAST, to, [box]);
    }
    if plan in ("str", "bytes") {
        return self.c_text_arg(self.lower_expr(arg), arg);
    }
    if to.kind == MirKind.C_PTR and self.c_borrow_operand(arg) is not None {
        return self.c_lend(arg, to, False, copybacks);
    }
    return self.coerce(self.lower_expr(arg), to, arg);
}

impl MirLowering.c_vararg(arg: uni.Expr) -> MirValue {
    b = self.builder();
    u8p = mir_c_ptr(mir_int(8, False));
    if self.c_borrow_operand(arg) is not None {
        return self.c_lend(arg, u8p, False, []);
    }
    if isinstance(self.c_bare(arg), uni.Null) {
        return self.emit_value(MirOp.PTR_NULL, u8p, []);
    }
    value = self.enum_as_int(self.lower_expr(arg), arg);
    kind = value.type.kind;
    if kind == MirKind.BOOL {
        return b.convert(value, mir_int(32, False, True));
    }
    if kind == MirKind.INT {
        if value.type.width >= 32 {
            return value;
        }
        return b.convert(value, mir_int(32, value.type.signed, True));
    }
    if kind == MirKind.FLOAT {
        return b.convert(value, mir_float(64));
    }
    if kind in (MirKind.C_PTR, MirKind.C_FN) {
        return value;
    }
    if kind in (MirKind.STR, MirKind.STR_REF, MirKind.BYTES, MirKind.BYTEARRAY) {
        return self.c_text_arg(value, arg);
    }
    if kind == MirKind.OPT
        and value.type.payload().kind in (MirKind.C_PTR, MirKind.C_FN) {
        return b.select(
            self.opt_present(value),
            self.emit_value(MirOp.PTR_CAST, u8p, [self.opt_get(value)]),
            self.emit_value(MirOp.PTR_NULL, u8p, [])
        );
    }
    raise MirRefused(
        mir_refusal(
            "C variadic argument",
            value.type.render(),
            arg,
            "A C variadic argument is a C scalar, `ptr`, `str` or `bytes`; a Jac object has no C representation to pass."
        )
    );
}

impl MirLowering.c_return_plan(
    sig: uni.FuncSignature, fallback: (TypeBase | None), site: uni.UniNode
) -> tuple[MirType, str] {
    if sig.return_type is None {
        return (mir_void(), "value");
    }
    declared = sig.return_type.type if isinstance(sig.return_type, uni.Expr) else None;
    t = self.c_declared_type(declared if declared is not None else fallback, fallback);
    if isinstance(t, ClassType) and t.shared.class_name in ("NoneType", "None") {
        return (mir_void(), "value");
    }
    self.ensure_c_types(t);
    if isinstance(t, ClassType) and t.shared.class_name == "str" {
        return (mir_c_ptr(mir_int(8, False)), "str");
    }
    return (mir_type_of(t, MirPosition.C_FIELD, site), "value");
}

impl MirLowering.condition(nd: uni.Expr) -> MirValue {
    b = self.builder();
    inner = self.c_bare(nd);
    if isinstance(inner, uni.UnaryExpr)
        and isinstance(inner.op, uni.Token)
        and inner.op.name == Tok.NOT {
        return b.logical_not(self.condition(inner.operand));
    }
    if not isinstance(inner, uni.BoolExpr) {
        return self.truthy(self.lower_expr(nd), nd);
    }
    fn = self.st().fn;
    result = self.temp_slot(mir_bool());
    done = fn.new_block("cond.done");
    is_and = inner.op.name == Tok.KW_AND;
    values = list(inner.values);
    for (index, operand_nd) in enumerate(values) {
        verdict = self.condition(operand_nd);
        b.store(result, verdict);
        if index + 1 < len(values) {
            more = fn.new_block("cond.next");
            if is_and {
                b.cond_branch(verdict, more, done);
            } else {
                b.cond_branch(verdict, done, more);
            }
            b.position(more);
        } else {
            b.branch(done);
        }
    }
    b.position(done);
    return b.load(result, mir_bool());
}

impl MirLowering.c_defines(decl: uni.UniNode) -> bool {
    return isinstance(decl, uni.Ability)
        and isinstance(decl.signature, uni.FuncSignature)
        and decl.body is not None
        and not (isinstance(decl.body, list) and not decl.body);
}

impl MirLowering.declare_c_definition(ab: uni.Ability) {
    sig = ab.signature;
    name = self.name_of(ab);
    if not isinstance(sig, uni.FuncSignature) {
        raise MirRefused(mir_refusal("C function definition", name, ab));
    }
    params: list[MirType] = [];
    packed = False;
    for pv in self.param_nodes(sig, False) {
        if pv.is_vararg and is_va_list_type(pv.type) and sig.kwargs is None {
            packed = True;
            continue;
        }
        if pv.is_vararg or pv.is_kwargs {
            raise MirRefused(
                mir_refusal(
                    "C function definition",
                    f"{name} with variadic parameters",
                    pv,
                    "A C variadic function defined in Jac is not lowered natively yet."
                )
            );
        }
        if self.c_param_borrowed(pv) {
            raise MirRefused(
                mir_refusal(
                    "C function definition",
                    f"{name} parameter {pv.name.value}",
                    pv,
                    "A C function defined in Jac takes a pointer as `ptr[T]`, not `&mut T`."
                )
            );
        }
        ptype = self.symbol_type(pv.name.sym, pv);
        if ptype.kind not in C_ABI_KINDS {
            raise MirRefused(
                mir_refusal(
                    "C function definition",
                    f"{name} parameter {pv.name.value} of {ptype.render()}",
                    pv,
                    "A C function defined in Jac takes C scalars and pointers; structs and Jac values do not cross its C ABI natively yet."
                )
            );
        }
        params.append(ptype);
    }
    fn_type = self.prog.get_type_evaluator().get_type_of_symbol(self.ability_sym(ab));
    ret = mir_none();
    if sig.return_type is not None and isinstance(fn_type, FunctionType) {
        (ret, plan) = self.c_return_plan(sig, fn_type.return_type, ab);
        if ret.kind == MirKind.VOID {
            ret = mir_none();
        }
        if plan != "value" or ret.kind not in C_ABI_KINDS + [MirKind.NONE] {
            raise MirRefused(
                mir_refusal(
                    "C function definition",
                    f"{name} returning {ret.render()}",
                    ab,
                    "A C function defined in Jac returns a C scalar or pointer; structs and Jac values do not cross its C ABI natively yet."
                )
            );
        }
    }
    key = id(ab);
    self.decl_syms[id(self.ability_sym(ab))] = key;
    self.decls[key] = MirDecl(
        ability=ab, symbol=name, params=params, ret=ret, c_variadic=packed
    );
    self.order.append(key);
}

impl MirLowering.va_arg(nd: uni.FuncCall, receiver: uni.Expr) -> MirValue {
    b = self.builder();
    want = self.expr_type(nd);
    if want.kind not in C_ABI_KINDS {
        raise MirRefused(
            mir_refusal(
                "call",
                "VaList.arg(T)",
                nd,
                "`args.arg(T)` reads the next C variadic argument; T is a sized scalar, `int`, `float`, `bool` or a `ptr`."
            )
        );
    }
    held = self.c_address(
        self.lower_place(receiver), mir_c_ptr(mir_c_ptr(mir_int(8, False)))
    );
    floating = want.kind == MirKind.FLOAT;
    symbol = "__jac_va_f64" if floating else "__jac_va_i64";
    word = mir_float(64) if floating else mir_int(64, True, True);
    self.mir.externs[symbol] = MirExtern(symbol=symbol, ret=word, params=[held.type]);
    raw = self.emit_value(MirOp.CALL_C, word, [held], callee=symbol);
    if want.kind == MirKind.BOOL {
        return b.compare("ne", raw, b.const_int(0, word));
    }
    if want.kind in (MirKind.C_PTR, MirKind.C_FN) {
        return self.emit_value(MirOp.PTR_CAST, want, [raw]);
    }
    return b.convert(raw, want);
}
