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
    if not isinstance(callee, uni.Ability) and isinstance(binding.ast_node, uni.Ability) {
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
    fn_type = self.prog.get_type_evaluator().get_type_of_symbol(self.ability_sym(callee));
    ret = mir_none();
    if isinstance(fn_type, FunctionType) {
        ret = self.type_of(fn_type.return_type, MirPosition.SIGNATURE, nd);
    }
    bound = self.bound_args(nd, callee, False);
    if len(bound) != len(params) {
        raise MirRefused(mir_refusal("call", f"{name} with {len(bound)} arguments", nd));
    }
    args = [
        self.coerce(self.lower_expr(arg), ptype, arg) for (arg, ptype) in zip(bound, params)
    ];
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
                [b.str_part(text, "root"), b.str_part(text, "data"), b.str_part(text, "len")]
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
    self.state = MirFnState(fn=adapter, b=MirBuilder(fn=adapter, block=adapter.new_block("entry")));
    try {
        args: list[MirValue] = [];
        for (index, ptype) in enumerate(decl.params) {
            value = adapter.new_value(ptype, f"a{index}");
            adapter.params.append(MirParam(name=f"a{index}", value=value));
            args.append(value);
        }
        result = self.bridge_call(bridge, name, args, decl.ret, decl.ability);
        self.builder().ret(None if decl.ret.kind in (MirKind.NONE, MirKind.VOID) else result);
    } finally {
        self.state = saved;
    }
    self.mir.functions = [fn for fn in self.mir.functions if fn.symbol != symbol] + [adapter];
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
        if isinstance(base_expr, uni.AtomTrailer) and isinstance(base_expr.right, uni.IndexSlice) {
            base_expr = base_expr.target;
        }
        if not isinstance(base_expr, uni.Name) or base_expr.value in NATIVE_ERASED_BASES {
            continue;
        }
        base_type = base_expr.type;
        if not isinstance(base_type, ClassType) {
            continue;
        }
        if is_enum_class_type(base_type) or JAC_TYPE_REGISTRY.is_exception(base_expr.value) {
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
