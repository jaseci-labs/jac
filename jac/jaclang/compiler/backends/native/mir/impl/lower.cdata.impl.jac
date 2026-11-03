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

impl MirLowering.note_clib(imp: (uni.Import | None)) -> int {
    if imp is None or imp.from_loc is None or not imp.from_loc.path {
        return -1;
    }
    found: list[tuple[str, list[str], int]] = [];
    names: list[str] = [];
    for part in imp.from_loc.path {
        if isinstance(part, uni.String) {
            raw = part.value;
            if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "\"'" {
                raw = raw[1:-1];
            }
            found.append(("raw", [raw], 0));
        } elif isinstance(part, uni.Name) {
            names.append(part.value);
        }
    }
    if names {
        found.append(("name", names, imp.from_loc.level));
    }
    index = -1;
    for spec in found {
        if spec not in self.mir.clib_specs {
            self.mir.clib_specs.append(spec);
        }
        index = self.mir.clib_specs.index(spec);
    }
    if index < 0 {
        return index;
    }
    for decl in imp.clib_decls {
        if isinstance(decl, uni.GlobalVars) {
            for assign in decl.assignments {
                target = assign.target[0] if assign.target else None;
                if isinstance(target, uni.Name) {
                    self.mir.clib_symbols.setdefault(target.sym_name, index);
                }
            }
        } elif isinstance(decl, uni.Ability) and decl.name_ref is not None {
            self.mir.clib_symbols.setdefault(decl.name_ref.sym_name, index);
        }
    }
    return index;
}

impl MirLowering.declare_c_data {
    for imp in self.module.get_all_sub_nodes(typ=uni.Import) {
        if not imp.clib_decls {
            continue;
        }
        self.note_clib(imp);
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
    self.note_clib(clib_import_of(assign));
    owner = assign.find_parent_of_type(uni.Module);
    defines = assign.value is not None
        and owner is not None
        and os.path.realpath(owner.loc.mod_path)
            == os.path.realpath(self.module.loc.mod_path);
    group = assign.parent;
    access = group.access if isinstance(group, uni.GlobalVars) else None;
    is_priv = bool(access and access.tag.name == Tok.KW_PRIV);
    made = MirGlobal(
        name=name, symbol=name, type=mir_int(8, False), linkage="external", c_data=True
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
    self.c_views[id(assign)] = made;
    if defines and isinstance(initial, uni.Expr) {
        made.linkage = "internal" if is_priv else "";
        made.c_init = self.c_const(initial, ctype, made.type, made.count);
    } elif assign.value is not None
        and owner is not None
        and owner.loc.mod_path.endswith(".jac") {
        self.add_dep(owner.loc.mod_path, name, assign);
    }
    self.c_views[id(assign)] = made;
    held = self.mir.globals.get(name);
    if held is None
        or (held.c_data and held.c_init is None and made.c_init is not None) {
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
    arch = self.c_struct_of(ctype);
    if arch is not None {
        return self.c_const_struct(expr, arch);
    }
    if target.kind == MirKind.C_FN {
        return self.c_const_address(expr);
    }
    if target.kind == MirKind.C_PTR {
        return self.c_const_address(expr);
    }
    (ok, value) = c_scalar_constant(expr, 0, self.prog);
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
    made_arch = self.c_struct_of(expr.type);
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
    (ok, value) = c_scalar_constant(expr, 0, self.prog);
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
    if isinstance(target, uni.Ability) {
        target = self.live_member(target);
    }
    if not isinstance(target, uni.Ability) or not isinstance(expr, uni.Name) {
        raise MirRefused(self.c_const_refusal(expr));
    }
    sym = target.name_ref.sym if target.name_ref is not None else None;
    decl = self.decls.get(self.decl_syms.get(id(sym), -1)) if sym is not None else None;
    if decl is not None {
        return self.c_entry(decl.symbol, decl.params, decl.ret, decl.ability);
    }
    fn_type = self.prog.get_type_evaluator().get_type_of_symbol(sym)
        if sym is not None
        else None;
    if not isinstance(fn_type, FunctionType) {
        raise MirRefused(mir_refusal("function address", expr.sym_name, expr));
    }
    if clib_import_of(target) is not None {
        self.ensure_c_types(fn_type);
        return self.c_extern(target, expr)[0];
    }
    path = target.loc.mod_path;
    if isinstance(target.parent, uni.Module) and path.endswith(".jac") {
        symbol = self.unit_symbol(self.name_of(target), target.access, path);
        made = MirExtern(
            symbol=symbol,
            ret=self.type_of(fn_type.return_type, MirPosition.SIGNATURE, expr),
            params=[
                self.type_of(p.param_type, MirPosition.VALUE, expr)
                for p in fn_type.parameters
            ]
        );
        self.mir.externs[symbol] = made;
        self.add_dep(path, symbol, expr);
        return self.c_entry(symbol, made.params, made.ret, target);
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
                glob_def.symbol,
                f"its initializer takes the address of {lost}, which is not native"
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
    arch = self.c_struct_of(nd.type);
    if arch is None and isinstance(nd.target, uni.Name) and nd.target.sym is not None {
        held: (uni.UniNode | None) = nd.target.sym.decl;
        while held is not None and not isinstance(held, uni.Archetype) {
            held = held.parent;
        }
        if isinstance(held, uni.Archetype) and held.name.value == struct_type.name {
            arch = self.variant_struct(held);
        }
    }
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
            if key in given or not any(hv.name.sym_name == key for hv in fields) {
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
                    "call",
                    f"{arch.name.value} with {len(list(nd.params or []))} arguments",
                    nd
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
    if member.kind == MirKind.C_STRUCT
        and isinstance(expr, uni.FuncCall)
        and expr.type is None {
        return self.c_struct_call(expr, member);
    }
    if member.kind in (MirKind.C_PTR, MirKind.C_FN) {
        if isinstance(expr, uni.Null) {
            return self.builder().const_null(member);
        }
        if isinstance(expr, uni.FuncCall) and not list(expr.params or []) {
            maker = expr.target;
            if isinstance(maker, uni.AtomTrailer)
                and not maker.is_attr
                and isinstance(maker.right, uni.IndexSlice) {
                maker = maker.target;
            }
            if isinstance(maker, uni.Name) and maker.value == "ptr" {
                return self.builder().const_null(member);
            }
        }
        (ok, folded) = c_scalar_constant(expr, 0, self.prog);
        if ok
            and isinstance(folded, int)
            and not isinstance(folded, bool)
            and folded == 0 {
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
    shim = self.c_entries.get(symbol);
    if shim is not None {
        shape = mir_c_fn([param.value.type for param in shim.params], shim.ret);
    }
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
    (ok, folded) = c_scalar_constant(size, 0, self.prog);
    if ok
        and isinstance(folded, int)
        and not isinstance(folded, bool)
        and folded >= 0 {
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

impl MirLowering.c_struct_of(t: (TypeBase | None)) -> (uni.Archetype | None) {
    arch = foreign_struct_of_type(t);
    return self.variant_struct(arch) if arch is not None else None;
}

impl MirLowering.variant_struct(arch: uni.Archetype) -> uni.Archetype {
    owner = arch.find_parent_of_type(uni.Module);
    twin = self.variant_unit(owner) if owner is not None else None;
    if twin is None or arch.name is None {
        return arch;
    }
    for found in twin.get_all_sub_nodes(uni.Archetype) {
        if found.name is not None and found.name.value == arch.name.value {
            return found;
        }
    }
    return arch;
}

impl MirLowering.variant_unit(mod: uni.Module) -> (uni.Module | None) {
    if mod.loc is None or not mod.loc.mod_path.endswith(".jac") {
        return None;
    }
    path = os.path.realpath(mod.loc.mod_path);
    if path in self.variant_units {
        return self.variant_units[path];
    }
    found = variant_module(self.prog, mod);
    if found is not None {
        import from jaclang.compiler.driver.pipeline { require }
        import from jaclang.compiler.driver.pipeline_types {
            AnalysisFact,
            CompilationProduct
        }
        if found is not None
            and not self.prog.analysis.provides(found, AnalysisFact.TYPE_OF)
            and not self.prog.analysis.provides(found, AnalysisFact.DECL_TYPES) {
            require(self.prog, found, CompilationProduct.DECLARATIONS);
        }
    }
    self.variant_units[path] = found;
    return found;
}

impl MirLowering.variant_ability(callee: uni.Ability) -> uni.Ability {
    if not isinstance(callee.parent, uni.Module) {
        return callee;
    }
    twin = self.variant_unit(callee.parent);
    if twin is None {
        return callee;
    }
    found = self.module_member(twin, self.name_of(callee));
    return found if isinstance(found, uni.Ability) else callee;
}

impl MirLowering.variant_glob(nd: uni.Name) -> (uni.Name | None) {
    if nd.sym is None {
        return None;
    }
    declaration = self.glob_assignment_of(nd);
    if declaration is None {
        return None;
    }
    twin = self.variant_declaration(declaration);
    if twin is None {
        return None;
    }
    wanted = {
        target.value
        for target in declaration.target
        if isinstance(target, uni.Name)
    };
    for held in twin.target {
        if isinstance(held, uni.Name) and held.value in wanted {
            return held;
        }
    }
    return None;
}

impl MirLowering.variant_declaration(
    declaration: uni.Assignment
) -> (uni.Assignment | None) {
    owner = declaration.find_parent_of_type(uni.Module);
    if owner is None or owner is self.module or self.variant_unit(owner) is None {
        return None;
    }
    for target in declaration.target {
        if isinstance(target, uni.Name) {
            found = variant_assignment(self.prog, declaration, target.value);
            if found is not None {
                return found;
            }
        }
    }
    return None;
}

impl MirLowering.variant_value(nd: uni.Name, twin: uni.Name) -> (MirValue | None) {
    b = self.builder();
    wanted = self.expr_type(nd);
    if final_glob_value(twin) is None {
        held = self.global_place(twin);
        return b.load(held, self.place_elem(held)) if held is not None else None;
    }
    folded = twin.ct_value;
    whole = int_host(folded) if isinstance(folded, CtInt) else None;
    if whole is not None and -(1 << 63) <= whole < (1 << 63) {
        return b.const_int(whole, wanted);
    }
    if isinstance(folded, CtBool) {
        return b.const_bool(folded.value);
    }
    if isinstance(folded, CtFloat) {
        return b.const_float(folded.value, wanted);
    }
    final_value = final_glob_value(twin);
    (settled, scalar) = c_scalar_constant(final_value, 0, self.prog)
        if final_value is not None
        else (False, None);
    if settled and isinstance(scalar, bool) {
        return b.const_bool(scalar);
    }
    if settled
        and isinstance(scalar, int)
        and -(1 << 63) <= scalar < (1 << 64)
        and wanted.kind == MirKind.INT {
        return b.const_int(
            scalar - (1 << 64) if scalar >= (1 << 63) else scalar, wanted
        );
    }
    if settled and isinstance(scalar, float) and wanted.kind == MirKind.FLOAT {
        return b.const_float(scalar, wanted);
    }
    place = self.global_place(twin);
    if place is not None {
        return b.load(place, self.place_elem(place));
    }
    return None;
}

impl MirLowering.c_entry(
    symbol: str, params: list[MirType], ret: MirType, target: uni.Ability
) -> str {
    if is_kernel_unit_path(self.module.loc.mod_path)
        or clib_import_of(target) is not None {
        return symbol;
    }
    shim = f"{symbol}.c_entry";
    if shim in self.c_entries {
        return shim;
    }
    fn = MirFunction(
        name=f"{self.name_of(target)}.c_entry",
        symbol=shim,
        ret=ret,
        linkage="linkonce_odr"
    );
    self.c_entries[shim] = fn;
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=fn.new_block("entry")));
    try {
        args: list[MirValue] = [];
        for (index, ptype) in enumerate(params) {
            value = fn.new_value(ptype, f"a{index}");
            fn.params.append(MirParam(name=f"a{index}", value=value));
            args.append(value);
        }
        self.region_escape_entry();
        result = self.builder().call(symbol, args, ret);
        self.drop_regions();
        self.builder().ret(
            None
                if ret.kind in (MirKind.NONE, MirKind.VOID) or result is None
                else result
        );
    } finally {
        self.state = saved;
    }
    self.mir.functions.append(fn);
    return shim;
}

impl MirLowering.glob_assignment_of(nd: uni.Name) -> (uni.Assignment | None) {
    value = final_glob_value(nd);
    if value is not None and isinstance(value.parent, uni.Assignment) {
        return value.parent;
    }
    return self.global_declaration(nd.sym) if nd.sym is not None else None;
}
