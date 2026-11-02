impl MirLowering.declare_module_globals {
    for elem in self.module.body {
        if not isinstance(elem, uni.GlobalVars) {
            continue;
        }
        if elem.access is not None and elem.access.tag.name == Tok.KW_PRIV {
            continue;
        }
        for assign in elem.assignments {
            for target in assign.target {
                if isinstance(target, uni.Name) and target.sym is not None {
                    try {
                        self.declare_global(target);
                    } except MirRefused {
                        continue;
                    }
                }
            }
        }
    }
}

impl MirLowering.declare_c_data {
    for imp in self.module.get_all_sub_nodes(typ=uni.Import) {
        if not imp.clib_decls {
            continue;
        }
        for decl in imp.clib_decls {
            if not isinstance(decl, uni.GlobalVars) {
                continue;
            }
            for assign in decl.assignments {
                if assign.value is None or not assign.target {
                    continue;
                }
                target = assign.target[0];
                if not isinstance(target, uni.Name) {
                    continue;
                }
                try {
                    self.declare_c_global(assign);
                } except MirRefused as err {
                    self.refusals.setdefault(target.sym_name, []).append(
                        refusal_of(err)
                    );
                }
            }
        }
    }
}

impl MirLowering.declare_c_global(assign: uni.Assignment) -> MirGlobal {
    target = assign.target[0] if assign.target else None;
    if not isinstance(target, uni.Name) or target.sym is None {
        raise MirRefused(mir_refusal("C data object", "unnamed", assign));
    }
    name = target.sym_name;
    found = self.c_views.get(id(assign));
    if found is not None {
        return found;
    }
    ctype = self.prog.get_type_evaluator().get_type_of_symbol(target.sym);
    owner = assign.find_parent_of_type(uni.Module);
    defines = assign.value is not None
        and owner is not None
        and os.path.realpath(owner.loc.mod_path)
        == os.path.realpath(self.module.loc.mod_path);
    group = assign.parent;
    access = group.access if isinstance(group, uni.GlobalVars) else None;
    is_priv = bool(access and access.tag.name == Tok.KW_PRIV);
    made = MirGlobal(
        name=name,
        symbol=name,
        type=mir_int(8, False),
        linkage="external",
        c_data=True
    );
    elem = c_array_elem(ctype);
    if elem is not None {
        made.type = self.type_of(elem, MirPosition.C_FIELD, assign);
        made.count = 0;
        if defines and isinstance(assign.value, uni.Expr) {
            made.count = self.c_array_count(assign.value, elem);
        }
    } elif opaque_c_of_type(ctype) is not None {
        made.opaque = True;
    } else {
        made.type = self.type_of(ctype, MirPosition.C_FIELD, assign);
    }
    initial = assign.value;
    if defines and isinstance(initial, uni.Expr) {
        made.linkage = "internal" if is_priv else "";
        made.c_init = self.c_const(initial, ctype, made.type, made.count);
    } elif assign.value is not None and owner is not None {
        unit = os.path.realpath(owner.loc.mod_path);
        if unit.endswith(".jac") and unit not in self.mir.deps {
            self.mir.deps.append(unit);
        }
    }
    self.c_views[id(assign)] = made;
    held = self.mir.globals.get(name);
    if held is None or (held.c_data and held.c_init is None and made.c_init is not None) {
        self.mir.globals[name] = made;
    }
    return made;
}

impl MirLowering.c_array_count(value: uni.Expr, elem: TypeBase) -> int {
    while isinstance(value, uni.AtomUnit) and isinstance(value.value, uni.Expr) {
        value = value.value;
    }
    if isinstance(value, uni.ListVal) {
        return len(value.values);
    }
    data = c_bytes_literal(value);
    shape = c_bytes_elem_shape(elem);
    if data is not None and shape is not None {
        return len(data) // shape[0];
    }
    raise MirRefused(
        mir_refusal(
            "C data definition",
            "array initializer",
            value,
            "A C array is initialized by a list literal or, for an integer array, a bytes literal of its little-endian elements."
        )
    );
}

impl MirLowering.c_const(
    expr: uni.Expr, ctype: (TypeBase | None), target: MirType, count: int = -1
) -> MirConst {
    while isinstance(expr, uni.AtomUnit) and isinstance(expr.value, uni.Expr) {
        expr = expr.value;
    }
    if isinstance(expr, uni.Null) {
        return MirConst(kind="zero");
    }
    elem = c_array_elem(ctype);
    if elem is not None and count >= 0 {
        data = c_bytes_literal(expr);
        if data is not None {
            shape = c_bytes_elem_shape(elem);
            if shape is None or len(data) != shape[0] * count {
                raise MirRefused(self.c_const_refusal(expr));
            }
            if shape[0] == 1 {
                return MirConst(kind="bytes", data=data);
            }
            return MirConst(
                kind="aggregate",
                items=[
                    MirConst(kind="int", int_value=item)
                    for item in c_bytes_array_values(data, shape[0], shape[1])
                ]
            );
        }
        if not isinstance(expr, uni.ListVal) {
            raise MirRefused(self.c_const_refusal(expr));
        }
        return MirConst(
            kind="aggregate",
            items=[
                self.c_const(item, elem, target)
                for item in expr.values
                if isinstance(item, uni.Expr)
            ]
        );
    }
    arch = foreign_struct_of_type(ctype);
    if arch is not None {
        return self.c_const_struct(expr, arch);
    }
    if target.kind == MirKind.C_FN {
        return self.c_const_address(expr);
    }
    if target.kind == MirKind.C_PTR {
        return self.c_const_address(expr);
    }
    (ok, value) = c_scalar_constant(expr);
    if ok and isinstance(value, (bool, int, float)) {
        if target.kind == MirKind.FLOAT {
            return MirConst(kind="float", float_value=float(value));
        }
        if isinstance(value, float) {
            raise MirRefused(self.c_const_refusal(expr));
        }
        return MirConst(kind="int", int_value=int(value));
    }
    raise MirRefused(self.c_const_refusal(expr));
}

impl MirLowering.c_const_refusal(expr: uni.UniNode) -> NativeRefusal {
    return mir_refusal(
        "C data definition",
        type(expr).__name__,
        expr,
        "A C data definition is laid out at link time, so its initializer is a C constant: literals, `ptr[T]()`, `ptr[u8](\"text\")`, `addressof(symbol)`, named functions for callback fields, `ptr(f)` for a named function's address, `ptr[T](...)` casts of these addresses, constructors of foreign structs made of these, and for an integer array a bytes literal of its little-endian elements."
    );
}

impl MirLowering.c_const_struct(expr: uni.Expr, arch: uni.Archetype) -> MirConst {
    if not isinstance(expr, uni.FuncCall) {
        raise MirRefused(self.c_const_refusal(expr));
    }
    made_arch = foreign_struct_of_type(expr.type);
    if made_arch is None
        or made_arch.name is None
        or made_arch.name.value != arch.name.value {
        raise MirRefused(self.c_const_refusal(expr));
    }
    self.ensure_c_types(expr.type);
    layout = self.mir.structs[arch.name.value];
    fields = self.arch_fields(arch);
    given: dict[str, uni.Expr] = {};
    for (index, param) in enumerate(expr.params or []) {
        if isinstance(param, uni.KWPair) {
            if isinstance(param.key, uni.Name) {
                given[param.key.sym_name] = param.value;
            }
        } elif index < len(fields) {
            given[fields[index].name.sym_name] = param;
        }
    }
    items = [MirConst(kind="zero") for _ in layout.fields];
    evaluator = self.prog.get_type_evaluator();
    for hv in fields {
        arg = given.get(hv.name.sym_name);
        if arg is None {
            continue;
        }
        index = layout.index_of(hv.name.value);
        field_type = evaluator.get_type_of_symbol(hv.name.sym)
            if hv.name.sym is not None
            else None;
        items[index] = self.c_const(arg, field_type, layout.fields[index].type);
    }
    return MirConst(kind="aggregate", items=items);
}

impl MirLowering.c_const_address(expr: uni.Expr) -> MirConst {
    while isinstance(expr, uni.AtomUnit) and isinstance(expr.value, uni.Expr) {
        expr = expr.value;
    }
    if isinstance(expr, uni.Null) {
        return MirConst(kind="zero");
    }
    if named_function_of(expr) is not None {
        return MirConst(kind="fn", symbol=self.c_function_symbol(expr));
    }
    if isinstance(expr, uni.FuncCall) {
        params = list(expr.params or []);
        if is_builtin_addressof_call(expr) {
            return MirConst(kind="global", symbol=self.c_addressed(expr).symbol);
        }
        callee_type = expr.target.type;
        if is_ptr_type(callee_type)
            and callee_type is not None
            and not callee_type.is_instance() {
            if not params {
                return MirConst(kind="zero");
            }
            arg = params[0];
            if len(params) != 1 or not isinstance(arg, uni.Expr) {
                raise MirRefused(self.c_const_refusal(expr));
            }
            text = c_string_literal(arg);
            if text is not None {
                return MirConst(kind="cstr", data=text.encode("utf-8"));
            }
            if isinstance(arg, uni.Int) {
                bits = uni.int_literal_u64_bits(arg.value);
                if bits is not None {
                    return MirConst(kind="int", int_value=bits);
                }
            }
            (base, steps) = c_offset_address(arg);
            if isinstance(base, uni.FuncCall) {
                return MirConst(
                    kind="global", symbol=self.c_addressed(base).symbol, offset=steps
                );
            }
            return self.c_const_address(arg);
        }
        raise MirRefused(self.c_const_refusal(expr));
    }
    (ok, value) = c_scalar_constant(expr);
    if ok and isinstance(value, int) {
        return MirConst(kind="int", int_value=value);
    }
    raise MirRefused(self.c_const_refusal(expr));
}

impl MirLowering.c_function_symbol(expr: uni.Expr) -> str {
    while isinstance(expr, uni.AtomUnit) and isinstance(expr.value, uni.Expr) {
        expr = expr.value;
    }
    target = named_function_of(expr);
    if not isinstance(target, uni.Ability) or not isinstance(expr, uni.Name) {
        raise MirRefused(self.c_const_refusal(expr));
    }
    sym = target.name_ref.sym if target.name_ref is not None else None;
    decl = self.decls.get(self.decl_syms.get(id(sym), -1)) if sym is not None else None;
    if decl is not None {
        return decl.symbol;
    }
    fn_type = self.prog.get_type_evaluator().get_type_of_symbol(sym)
        if sym is not None
        else None;
    if not isinstance(fn_type, FunctionType) {
        raise MirRefused(mir_refusal("function address", expr.sym_name, expr));
    }
    if clib_import_of(target) is not None {
        self.ensure_c_types(fn_type);
        self.ensure_objects(fn_type);
        symbol = self.name_of(target);
        self.mir.externs[symbol] = MirExtern(
            symbol=symbol,
            ret=mir_type_of(fn_type.return_type, MirPosition.C_FIELD, expr),
            params=[
                mir_type_of(p.param_type, MirPosition.C_FIELD, expr)
                for p in fn_type.parameters
            ]
        );
        return symbol;
    }
    path = target.loc.mod_path;
    if isinstance(target.parent, uni.Module) and path.endswith(".jac") {
        symbol = self.unit_symbol(self.name_of(target), target.access, path);
        self.mir.externs[symbol] = MirExtern(
            symbol=symbol,
            ret=self.type_of(fn_type.return_type, MirPosition.SIGNATURE, expr),
            params=[
                self.type_of(p.param_type, MirPosition.VALUE, expr)
                for p in fn_type.parameters
            ]
        );
        unit = os.path.realpath(path);
        if unit not in self.mir.deps {
            self.mir.deps.append(unit);
        }
        return symbol;
    }
    raise MirRefused(mir_refusal("function address", expr.sym_name, expr));
}

impl MirLowering.c_addressed(nd: uni.FuncCall) -> MirGlobal {
    params = list(nd.params or []);
    symbol = params[0] if len(params) == 1 else None;
    while isinstance(symbol, uni.AtomUnit) and isinstance(symbol.value, uni.Expr) {
        symbol = symbol.value;
    }
    assign = clib_global_of_name(symbol) if isinstance(symbol, uni.Name) else None;
    if assign is None {
        raise MirRefused(
            mir_refusal(
                "call",
                "addressof(C data symbol)",
                nd,
                "addressof takes a C data symbol: a `glob` declared in a C library import."
            )
        );
    }
    return self.declare_c_global(assign);
}

impl MirLowering.c_addressof(nd: uni.FuncCall) -> MirValue {
    found = self.c_addressed(nd);
    place = self.emit_value(
        MirOp.GLOBAL_ADDR, mir_c_ptr(found.type), [], str_value=found.symbol
    );
    wanted = self.expr_type(nd);
    if wanted is place.type {
        return place;
    }
    return self.emit_value(MirOp.PTR_CAST, wanted, [place]);
}

impl MirLowering.c_global_settle {
    for glob_def in self.mir.globals.values() {
        if glob_def.c_init is None {
            continue;
        }
        lost = self.c_const_lost(glob_def.c_init);
        if lost {
            self.mir.demoted.setdefault(
                glob_def.symbol, f"its initializer takes the address of {lost}, which is not native"
            );
        }
    }
}

impl MirLowering.c_const_lost(made: MirConst) -> str {
    if made.kind == "fn"
        and made.symbol in self.mir.demoted
        and made.symbol not in self.mir.bridged {
        lost = made.symbol;
        made.kind = "zero";
        return lost;
    }
    found = "";
    for item in made.items {
        lost = self.c_const_lost(item);
        if lost and not found {
            found = lost;
        }
    }
    return found;
}

impl MirLowering.c_struct_call(nd: uni.FuncCall, struct_type: MirType) -> MirValue {
    arch = foreign_struct_of_type(nd.type);
    if arch is None {
        raise MirRefused(mir_refusal("call", struct_type.render(), nd));
    }
    layout = self.mir.structs[struct_type.name];
    fields = self.arch_fields(arch);
    given: dict[str, uni.Expr] = {};
    for (index, param) in enumerate(nd.params or []) {
        if isinstance(param, uni.KWPair) {
            if not isinstance(param.key, uni.Name) {
                raise MirRefused(
                    mir_refusal("call argument", "keyword unpacking", param)
                );
            }
            key = param.key.sym_name;
            if key in given
                or not any(hv.name.sym_name == key for hv in fields) {
                raise MirRefused(
                    mir_refusal("call", f"{arch.name.value} argument {key}", param)
                );
            }
            given[key] = param.value;
        } elif index < len(fields)
            and not (
                isinstance(param, uni.UnaryExpr)
                and param.op.name in (Tok.STAR_MUL, Tok.STAR_POW)
            ) {
            given[fields[index].name.sym_name] = param;
        } else {
            raise MirRefused(
                mir_refusal(
                    "call", f"{arch.name.value} with {len(nd.params)} arguments", nd
                )
            );
        }
    }
    b = self.builder();
    slot = self.temp_slot(struct_type);
    b.store(slot, b.const_null(struct_type));
    for hv in fields {
        source = given.get(hv.name.sym_name, hv.value);
        if source is None {
            continue;
        }
        index = layout.index_of(hv.name.value);
        member = layout.fields[index].type;
        place = self.emit_value(
            MirOp.FIELD_ADDR,
            mir_c_ptr(member),
            [self.coerce_place(slot)],
            int_value=index
        );
        b.store(place, self.c_field_value(source, member));
    }
    return b.load(slot, struct_type);
}

impl MirLowering.c_field_value(expr: uni.Expr, member: MirType) -> MirValue {
    while isinstance(expr, uni.AtomUnit) and isinstance(expr.value, uni.Expr) {
        expr = expr.value;
    }
    if member.kind in (MirKind.C_PTR, MirKind.C_FN) {
        if isinstance(expr, uni.Null) {
            return self.builder().const_null(member);
        }
        (ok, folded) = c_scalar_constant(expr);
        if ok and isinstance(folded, int) and not isinstance(folded, bool) and folded == 0 {
            return self.builder().const_null(member);
        }
    }
    if member.kind in (MirKind.C_PTR, MirKind.C_FN)
        and named_function_of(expr) is not None {
        return self.c_function_value(expr, member);
    }
    value = self.lower_expr(expr);
    if member.kind in (MirKind.C_PTR, MirKind.C_FN)
        and value.type.kind in (MirKind.C_PTR, MirKind.C_FN)
        and value.type is not member {
        return self.emit_value(MirOp.PTR_CAST, member, [value]);
    }
    return self.coerce(value, member, expr);
}

impl MirLowering.c_pin(nd: uni.FuncCall) -> MirValue {
    args = self.call_args(nd);
    if len(args) != 1 {
        raise MirRefused(mir_refusal("call", "pin(value)", nd));
    }
    pinned = self.expr_type(nd);
    if pinned.kind != MirKind.C_PIN {
        raise MirRefused(mir_refusal("call", f"pin as {pinned.render()}", nd));
    }
    payload = pinned.payload();
    value = self.coerce(self.lower_expr(args[0]), payload, args[0]);
    b = self.builder();
    size = self.st().fn.new_value(mir_int());
    b.emit(MirInstr(op=MirOp.SIZEOF, result=size, type_arg=pinned));
    raw = self.runtime("__jac_rt_alloc_zeroed", [size]);
    if raw is None {
        raise MirRefused(mir_refusal("call", "pin(value)", nd));
    }
    made = b.ref_cast(raw, pinned, True);
    b.store(self.emit_value(MirOp.PTR_CAST, mir_c_ptr(payload), [made]), value);
    return made;
}

impl MirLowering.c_function_value(expr: uni.Expr, member: MirType) -> MirValue {
    symbol = self.c_function_symbol(expr);
    shape: (MirType | None) = None;
    for decl in self.decls.values() {
        if decl.symbol == symbol {
            shape = mir_c_fn(decl.params, decl.ret);
        }
    }
    held = self.mir.externs.get(symbol);
    if shape is None and held is not None {
        shape = mir_c_fn(held.params, held.ret);
    }
    if shape is None {
        raise MirRefused(mir_refusal("function address", symbol, expr));
    }
    address = self.emit_value(MirOp.FN_ADDR, shape, [], callee=symbol);
    if shape is member {
        return address;
    }
    return self.emit_value(MirOp.PTR_CAST, member, [address]);
}

impl MirLowering.c_thread_local(
    nd: uni.FuncCall, name: str, args: list[uni.Expr]
) -> MirValue {
    label = c_string_literal(args[0]) if len(args) == 1 else None;
    if not label {
        raise MirRefused(
            mir_refusal(
                "intrinsic",
                name,
                nd,
                "The C variable is named by a string literal.",
                "E5095"
            )
        );
    }
    defining = name == "__thread_local";
    found = self.mir.globals.get(label);
    if found is None {
        found = MirGlobal(
            name=label,
            symbol=label,
            type=mir_int(64) if defining else mir_int(8, False),
            linkage="weak" if defining else "external",
            c_data=True,
            thread_local=True
        );
        self.mir.globals[label] = found;
    } elif not found.thread_local {
        raise MirRefused(
            mir_refusal(
                "intrinsic",
                name,
                nd,
                f"'{label}' is already declared and is not thread-local.",
                "E5095"
            )
        );
    } elif defining and found.linkage == "external" {
        found.linkage = "weak";
        found.type = mir_int(64);
    }
    place = self.emit_value(
        MirOp.GLOBAL_ADDR, mir_c_ptr(found.type), [], str_value=found.symbol
    );
    return self.emit_value(MirOp.PTR_INT, mir_int(64, True, True), [place]);
}

impl MirLowering.c_alloca(size: uni.Expr) -> MirValue {
    fn = self.st().fn;
    words = mir_c_ptr(mir_int(64));
    (ok, folded) = c_scalar_constant(size);
    if ok and isinstance(folded, int) and not isinstance(folded, bool) and folded >= 0 {
        made = fn.new_value(words);
        fn.blocks[0].instrs.insert(
            0, MirInstr(op=MirOp.ALLOCA, result=made, int_value=(folded + 7) // 8)
        );
    } else {
        count = self.coerce(self.lower_expr(size), mir_int(64, True, True), size);
        made = self.emit_value(MirOp.ALLOCA, words, [count]);
    }
    return self.emit_value(MirOp.PTR_INT, mir_int(64, True, True), [made]);
}
