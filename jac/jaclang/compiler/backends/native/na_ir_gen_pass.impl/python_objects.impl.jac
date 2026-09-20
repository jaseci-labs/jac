impl NaIRGenPass._python_value(ty: ir.Type) -> bool {
    reference = self.struct_types.get("__JacPythonValue");
    return reference is not None and ty == reference.as_pointer();
}

impl NaIRGenPass._python_expr(nd: uni.UniNode) -> bool {
    if not self._python_imports {
        return False;
    }
    if isinstance(nd, uni.Name) {
        slot = self.local_vars.get(nd.value);
        if slot is not None {
            return self._python_value(slot.pointee_type);
        }
        return nd.sym is not None and id(nd.sym) in self._python_imports;
    }
    if isinstance(nd, uni.FuncCall) and self._python_builtin(nd) {
        return True;
    }
    if isinstance(nd, uni.AtomTrailer) or isinstance(nd, uni.FuncCall) {
        return self._python_expr(nd.target);
    }
    if isinstance(nd, uni.CfgExpr) {
        return self._python_expr(nd.expr);
    }
    if isinstance(nd, uni.AtomUnit) {
        return self._python_expr(nd.value);
    }
    if isinstance(nd, uni.BinaryExpr) {
        return self._python_expr(nd.left) or self._python_expr(nd.right);
    }
    if isinstance(nd, uni.UnaryExpr) and nd.op.name != Tok.NOT {
        return self._python_expr(nd.operand);
    }
    return False;
}

impl NaIRGenPass._python_runtime(name: str, args: list[ir.Value]) -> ir.Value {
    function = self.func_symtab["__jac_python_" + name];
    coerced = [
        self._coerce_borrowed(arg, param.type)
        for (arg, param) in zip(args, function.args)
    ];
    result = self.builder.call(function, coerced);
    self._emit_pending_error_check();
    self._release_owned_args(
        [
            value
            for (arg, value) in zip(args, coerced)
            if value is not arg
        ]
    );
    self._mark_reference_owned(result);
    self._protect_temporary(result);
    return result;
}

impl NaIRGenPass._python_box(value: ir.Value, consume: bool = True) -> ir.Value {
    if self._python_value(value.type) {
        return value;
    }
    if isinstance(value, ir.Constant)
        and value.type == ir.IntType(8).as_pointer()
        and value.constant is None {
        return self._python_runtime("none", []);
    }
    if isinstance(value.type, ir.IntType) {
        result = self._python_runtime(
            "bool" if value.type.width == 1 else "int", [value]
        );
    } elif isinstance(value.type, (ir.DoubleType, ir.FloatType)) {
        result = self._python_runtime("float", [value]);
    } elif value.type == self._str_desc_ty
        or value.type == ir.IntType(8).as_pointer() {
        result = self._python_runtime("text", [value]);
    } else {
        raise ValueError(f"Unsupported Python object conversion: {value.type}");
    }
    if consume {
        self._release_owned_args([value]);
    }
    return result;
}

impl NaIRGenPass._python_import(binding: NativePythonImport) -> ir.Value {
    if binding.attribute {
        return self._python_runtime(
            "import_from",
            [
                self._make_global_string(binding.module),
                self._make_global_string(binding.attribute)
            ]
        );
    }
    imported = self._python_runtime(
        "import", [self._make_global_string(binding.module)]
    );
    if binding.bind_module != binding.module {
        self._release_owned_args([imported]);
        imported = self._python_runtime(
            "import", [self._make_global_string(binding.bind_module)]
        );
    }
    return imported;
}

impl NaIRGenPass._python_import_statement(nd: uni.Import) -> None {
    import from jaclang.compiler.native_imports { python_import_symbol }
    import from jaclang.compiler.passes.capability_check_pass { import_bound_name }
    for item in nd.items {
        symbol = python_import_symbol(item);
        binding = self._python_imports.get(id(symbol)) if symbol is not None else None;
        if binding is None {
            continue;
        }
        value = self._python_import(binding);
        name = import_bound_name(item);
        assert name is not None;
        slot = self.local_vars.get(name);
        if slot is None {
            slot = self._entry_alloca(value.type, name);
            self.local_vars[name] = slot;
        }
        assert slot.pointee_type == value.type;
        self._emit_slot_rebind(slot, value, owned=True, op="python_import");
        self.builder.store(value, slot);
    }
}

impl NaIRGenPass._python_builtin(nd: uni.FuncCall) -> bool {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    name = self._get_name(nd.target);
    return nd.call_kind == "builtin"
        and name is not None
        and not JAC_TYPE_REGISTRY.is_sized(name)
        and any(
            self._python_expr(param.value if isinstance(param, uni.KWPair) else param)
            for param in (nd.params or [])
        );
}

impl NaIRGenPass._python_call(nd: uni.FuncCall) -> ir.Value {
    callable: ir.Value | None;
    if self._python_builtin(nd) {
        name = self._get_name(nd.target);
        assert name is not None;
        builtins = self._python_runtime(
            "import", [self._make_global_string("builtins")]
        );
        callable = self._python_runtime(
            "getattr", [builtins, self._make_global_string(name)]
        );
        self._release_owned_args([builtins]);
    } else {
        callable = self._codegen_required(nd.target);
    }
    assert callable is not None;
    params = list(nd.params or []);
    count = sum(
        1
        for param in params
        if not isinstance(param, uni.KWPair)
    );
    positional = self._python_runtime("tuple", [ir.Constant(ir.IntType(64), count)]);
    keywords = self._python_runtime("dict", []);
    index = 0;
    for param in params {
        if isinstance(param, uni.KWPair) {
            assert param.key is not None;
            raw = self._codegen_required(param.value);
            assert raw is not None;
            value = self._python_box(raw);
            key = self._python_runtime(
                "text", [self._make_global_string(param.key.sym_name)]
            );
            self._python_runtime("setitem", [keywords, key, value]);
            self._release_owned_args([key, value]);
        } else {
            raw = self._codegen_required(param);
            assert raw is not None;
            value = self._python_box(raw);
            self._python_runtime(
                "tuple_set", [positional, ir.Constant(ir.IntType(64), index), value]
            );
            self._release_owned_args([value]);
            index += 1;
        }
    }
    result = self._python_runtime("call", [callable, positional, keywords]);
    self._release_owned_args([callable, positional, keywords]);
    return result;
}

impl NaIRGenPass._python_attribute(nd: uni.AtomTrailer) -> ir.Value {
    target = self._codegen_required(nd.target);
    assert target is not None;
    if nd.is_attr {
        name = self._get_name(nd.right);
        assert name is not None;
        result = self._python_runtime(
            "getattr", [target, self._make_global_string(name)]
        );
    } else {
        assert isinstance(nd.right, uni.IndexSlice) and not nd.right.is_range;
        index = self._codegen_required(nd.right.slices[0].start);
        assert index is not None;
        key = self._python_box(index);
        result = self._python_runtime("getitem", [target, key]);
        self._release_owned_args([key]);
    }
    self._release_owned_args([target]);
    return result;
}


impl NaIRGenPass._python_error_payload(record: ir.Value) -> ir.Value {
    typed = self.builder.bitcast(record, self._get_error_record_type().as_pointer());
    payload = self.builder.load(
        self.builder.gep(
            typed, [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)]
        )
    );
    return self.builder.bitcast(
        payload, self.struct_types["__JacPythonError"].as_pointer()
    );
}

impl NaIRGenPass._python_error_matches(ex: uni.Expr) -> ir.Value {
    slots = self._error_slots(self.builder);
    saved = self._spill_error(tuple(self.builder.load(slot) for slot in slots));
    self._clear_pending_error(self.builder, release=False);
    if self._python_expr(ex) {
        kind = self._codegen_required(ex);
        assert kind is not None;
    } else {
        name = self._get_name(ex);
        assert name is not None;
        builtins = self._python_runtime(
            "import", [self._make_global_string("builtins")]
        );
        kind = self._python_runtime(
            "getattr", [builtins, self._make_global_string(name)]
        );
        self._release_owned_args([builtins]);
    }
    payload = self._python_error_payload(self.builder.load(saved[1]));
    result = self._python_runtime("matches", [payload, kind]);
    self._release_owned_args([kind]);
    self._restore_error(saved);
    return result;
}

impl NaIRGenPass._python_module_state -> ir.Value {
    identity = self._python_module_identity;
    assert identity is not None;
    return self._python_runtime(
        "module_state", [self.builder.ptrtoint(identity, ir.IntType(64))]
    );
}

impl NaIRGenPass._python_ensure_module -> None {
    initializer = self._python_init_fn;
    if initializer is not None and self.builder.function is not initializer {
        identity = self._python_module_identity;
        assert identity is not None;
        frame = self._error_frame;
        assert frame is not None;
        frame.temporaries.append([]);
        try {
            self._python_runtime(
                "initialize",
                [self.builder.ptrtoint(identity, ir.IntType(64)), initializer]
            );
        } finally {
            frame.temporaries.pop();
        }
    }
}

impl NaIRGenPass._python_global(name: str) -> ir.Value {
    self._python_ensure_module();
    namespace = self._python_module_state();
    key = self._python_runtime("text", [self._make_global_string(name)]);
    value = self._python_runtime("getitem", [namespace, key]);
    self._release_owned_args([namespace, key]);
    return value;
}

impl NaIRGenPass._emit_python_module_init -> None {
    if not self._python_globals {
        return;
    }
    identity = ir.GlobalVariable(
        self.llvm_module, ir.IntType(8), name="__jac_python_module_identity"
    );
    identity.linkage = "private";
    identity.initializer = ir.Constant(ir.IntType(8), 0);
    self._python_module_identity = identity;
    initializer = self._define_function(
        "__jac_python_module_init",
        ir.FunctionType(
            ir.VoidType(), [self.struct_types["__JacPythonValue"].as_pointer()]
        )
    );
    initializer.linkage = "private";
    self._python_init_fn = initializer;
    previous = self._enter_function(initializer);
    frame = self._error_frame;
    assert frame is not None;
    frame.temporaries.append([]);
    try {
        namespace = initializer.args[0];
        self._bind_function_parameter("namespace", namespace);
        for binding in self._python_globals.values() {
            value = self._python_import(binding);
            key = self._python_runtime(
                "text", [self._make_global_string(binding.binding)]
            );
            self._python_runtime("setitem", [namespace, key, value]);
            self._release_owned_args([key, value]);
        }
        self._release_temporaries();
        self._emit_scope_cleanup(loc="python.module.init");
        self.builder.ret_void();
    } finally {
        frame.temporaries.pop();
        self._leave_function(previous);
    }
}
