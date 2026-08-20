impl NaIRGenEnums._class_form_enum_self_type(arch_name: str) -> (ir.Type | None) {
    _arch = self.arch_ast_map.get(arch_name);
    if _arch is None or not (_arch?.name) {
        return None;
    }
    return self._ensure_enum_lowered(_arch.name.type);
}

impl NaIRGenEnums._codegen_class_form_enum_member(
    nd: uni.AtomTrailer
) -> (ir.Value | None) {
    import from jaclang.compiler.passes.main.layout_pass { class_form_enum_member }
    _member = class_form_enum_member(nd.type if isinstance(nd, uni.Expr) else None);
    if _member is None {
        return None;
    }
    (_scalar, _lit, _name) = _member;
    if _scalar == "int" {
        return ir.Constant(ir.IntType(64), _lit);
    }
    return self._make_global_string(_lit, name_prefix=".cfenum");
}

impl NaIRGenEnums._ensure_enum_lowered(t: any) -> (ir.Type | None) {
    import from jaclang.compiler.passes.main.layout_pass {
        is_enum_class_type,
        enum_decl_of,
        enum_value_type_of,
        class_form_enum_scalar
    }
    if not is_enum_class_type(t) {
        return None;
    }
    _decl = enum_decl_of(t);
    if _decl is not None {
        self._codegen_enum(_decl);
    } else {
        _shared = t?.shared;
        _enm = _shared.class_name if _shared is not None else None;
        if _enm is not None {
            self._codegen_enum_layout(_enm, None);
        }
    }
    if class_form_enum_scalar(t) is not None {
        return self._lower_type(enum_value_type_of(t));
    }
    return ir.IntType(64);
}

impl NaIRGenEnums._codegen_enum(nd: (uni.Enum | uni.Archetype)) -> None {
    enum_name = (nd).name.value if (nd).name else "unknown_enum";
    if isinstance(nd, uni.Archetype) {
        self.has_native_code = True;
        return;
    }
    _owner_mod = nd.find_parent_of_type(uni.Module) or self.ir_in;
    self._codegen_enum_layout(enum_name, _owner_mod);
}

impl NaIRGenEnums._codegen_enum_layout(
    enum_name: str, owner: (uni.Module | None)
) -> None {
    if enum_name in self.enum_types {
        return;
    }

    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }
    candidates: list = [];
    if owner is not None {
        candidates.append(owner);
    }
    candidates.append(self.ir_in);
    for _fm in (self?._foreign_modules or []) {
        candidates.append(_fm);
    }
    lay = None;
    for _cand in candidates {
        lay = get_layout_registry(_cand, self.prog).get_enum_layout(enum_name);
        if lay is not None and lay.members {
            break;
        }
    }
    if lay is None or not lay.members {
        return;
    }
    if lay.is_class_form {
        self.has_native_code = True;
        return;
    }
    self.enum_types[enum_name] = ir.IntType(64);
    self.has_native_code = True;

    i64 = ir.IntType(64);
    if lay.is_string_enum {
        entries: list = [];
        for m in lay.members {
            full_name = f"{enum_name}.{m.name}";
            self.enum_values[full_name] = ir.Constant(i64, m.ordinal);
            self.enum_member_ordinal[full_name] = m.ordinal;
            entries.append((m.name, m.str_value or "", m.ordinal));
        }
        self.enum_string_values[enum_name] = entries;
        self._build_enum_string_table(enum_name, entries);
    } else {
        name_entries: list = [];
        int_entries: list = [];
        for m in lay.members {
            full_name = f"{enum_name}.{m.name}";
            self.enum_values[full_name] = ir.Constant(i64, m.int_value);
            self.enum_member_ordinal[full_name] = m.ordinal;
            name_entries.append((m.name, "", m.ordinal));
            int_entries.append((m.int_value, m.ordinal));
        }
        self.enum_int_values[enum_name] = int_entries;
        self._build_enum_string_table(enum_name, name_entries, with_values=False);
    }
}

impl NaIRGenEnums._build_enum_string_table(
    enum_name: str, entries: list, with_values: bool = True
) -> None {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    value_ptrs: list = [];
    name_ptrs: list = [];
    for (mname, str_val, ordinal) in entries {
        if with_values {
            (val_struct_type, val_struct) = self._static_str_struct_const(
                (str_val + "\0").encode("utf8")
            );
            val_gv = ir.GlobalVariable(
                self.llvm_module,
                val_struct_type,
                name=f"__enum.{enum_name}.v.{ordinal}"
            );
            val_gv.linkage = "private";
            val_gv.global_constant = True;
            val_gv.initializer = val_struct;

            val_ptr = val_gv.gep(
                [ir.Constant(i32, 0), ir.Constant(i32, 2), ir.Constant(i32, 0)]
            );
            value_ptrs.append(val_ptr);
        }

        (name_struct_type, name_struct) = self._static_str_struct_const(
            (mname + "\0").encode("utf8")
        );
        name_gv = ir.GlobalVariable(
            self.llvm_module, name_struct_type, name=f"__enum.{enum_name}.n.{ordinal}"
        );
        name_gv.linkage = "private";
        name_gv.global_constant = True;
        name_gv.initializer = name_struct;
        name_ptr = name_gv.gep(
            [ir.Constant(i32, 0), ir.Constant(i32, 2), ir.Constant(i32, 0)]
        );
        name_ptrs.append(name_ptr);
    }
    n = len(entries);
    arr_type = ir.ArrayType(i8p, n);

    if with_values {
        val_arr_gv = ir.GlobalVariable(
            self.llvm_module, arr_type, name=f"__enum_values.{enum_name}"
        );
        val_arr_gv.linkage = "private";
        val_arr_gv.global_constant = True;
        val_arr_gv.initializer = ir.Constant(arr_type, value_ptrs);
        self.enum_value_arrays[enum_name] = val_arr_gv;
    }

    name_arr_gv = ir.GlobalVariable(
        self.llvm_module, arr_type, name=f"__enum_names.{enum_name}"
    );
    name_arr_gv.linkage = "private";
    name_arr_gv.global_constant = True;
    name_arr_gv.initializer = ir.Constant(arr_type, name_ptrs);
    self.enum_name_arrays[enum_name] = name_arr_gv;
}

impl NaIRGenEnums._codegen_enum_value_lookup(
    enum_name: str, ordinal_val: ir.Value, use_name: bool = False
) -> (ir.Value | None) {
    arr_global = (self.enum_name_arrays if use_name else self.enum_value_arrays).get(
        enum_name
    );
    if arr_global is None {
        return None;
    }
    i32 = ir.IntType(32);
    i8p = ir.IntType(8).as_pointer();

    idx = self.builder.trunc(ordinal_val, i32, name="enum.idx");

    ptr_ptr = self.builder.gep(
        arr_global, [ir.Constant(i32, 0), idx], name=f"enum.{enum_name}.ptr"
    );
    return self.builder.load(ptr_ptr, name=f"enum.{enum_name}.str");
}

impl NaIRGenEnums._wrap_enum_str(raw: (ir.Value | None)) -> (ir.Value | None) {
    if raw is None or self.str_wrap_raw_fn is None {
        return raw;
    }
    return self.builder.call(self.str_wrap_raw_fn, [raw], name="enum.s.desc");
}

impl NaIRGenEnums._enum_is_string_valued(enum_name: str) -> bool {
    return enum_name in self.enum_string_values;
}

impl NaIRGenEnums._enum_ordinal_fn(enum_name: str) -> (ir.Function | None) {
    _cached = self.enum_ordinal_fns.get(enum_name);
    if _cached is not None {
        return _cached;
    }
    entries = self.enum_int_values.get(enum_name);
    if not entries {
        return None;
    }
    i64 = ir.IntType(64);
    fn = ir.Function(
        self.llvm_module, ir.FunctionType(i64, [i64]), name=f"__enum_ord.{enum_name}"
    );
    fn.linkage = "private";
    fn.args[0].name = "val";
    b = ir.IRBuilder(fn.append_basic_block("entry"));
    seen: set = set();
    ordered: list = [];
    for (_iv, _ord) in entries {
        if _iv in seen {
            continue;
        }
        seen.add(_iv);
        ordered.append((_iv, _ord));
    }
    acc: any = ir.Constant(i64, 0);
    for (_iv, _ord) in ordered[::-1] {
        _hit = b.icmp_signed(
            "==", fn.args[0], ir.Constant(i64, _iv), name=f"eo.hit{_ord}"
        );
        acc = b.select(_hit, ir.Constant(i64, _ord), acc, name=f"eo.sel{_ord}");
    }
    b.ret(acc);
    self.enum_ordinal_fns[enum_name] = fn;
    return fn;
}

impl NaIRGenEnums._codegen_enum_ordinal_of(
    enum_name: str, runtime_val: ir.Value
) -> (ir.Value | None) {
    if self._enum_is_string_valued(enum_name) {
        return runtime_val;
    }
    _fn = self._enum_ordinal_fn(enum_name);
    if _fn is None {
        return None;
    }
    i64 = ir.IntType(64);
    _arg = runtime_val;
    if isinstance(_arg.type, ir.IntType) and _arg.type.width != 64 {
        _arg = self.builder.zext(_arg, i64, name="enum.ord.wide");
    }
    return self.builder.call(_fn, [_arg], name=f"enum.{enum_name}.ord");
}

impl NaIRGenEnums._codegen_enum_attr_runtime(
    enum_name: str, runtime_val: ir.Value, use_name: bool
) -> (ir.Value | None) {
    if not use_name and not self._enum_is_string_valued(enum_name) {
        return runtime_val;
    }
    _ord = self._codegen_enum_ordinal_of(enum_name, runtime_val);
    if _ord is None {
        return None;
    }
    return self._codegen_enum_value_lookup(enum_name, _ord, use_name=use_name);
}

impl NaIRGenEnums._enum_ctor_layout(enum_name: str) -> (any | None) {
    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }
    candidates: list = [];
    _arch = self.arch_ast_map.get(enum_name);
    if _arch is not None {
        _own = _arch.find_parent_of_type(uni.Module);
        if _own is not None {
            candidates.append(_own);
        }
    }
    candidates.append(self.ir_in);
    for _fm in (self?._foreign_modules or []) {
        candidates.append(_fm);
    }
    for _cand in candidates {
        lay = get_layout_registry(_cand, self.prog).get_enum_layout(enum_name);
        if lay is not None and lay.members {
            return lay;
        }
    }
    return None;
}

impl NaIRGenEnums._enum_ctor_target(nd: uni.FuncCall) -> (str | None) {
    _key = self._type_key_of(nd.target);
    if _key is None {
        return None;
    }
    _key = _key.replace(" ", "");
    if not _key.startswith("type[") or not _key.endswith("]") {
        return None;
    }
    _name = _key[5:-1];
    if not _name or not _name.isidentifier() {
        return None;
    }
    return _name if self._enum_ctor_layout(_name) is not None else None;
}

impl NaIRGenEnums._emit_enum_ctor_refusal(
    nd: uni.FuncCall, enum_name: str, why: str
) -> None {
    self.emit(
        E5092,
        node_override=nd,
        kind="enum constructor",
        name=enum_name,
        help_text=(
            f"Invoking '{enum_name}' as a constructor is a value-to-member "
            f"lookup: the emitter checks the value against the declared "
            f"member table and raises ValueError when it misses. {why} Read "
            f"the member off the class, or move this call to a @sv/Python "
            f"context."
        )
    );
}

impl NaIRGenEnums._codegen_enum_ctor(
    nd: uni.FuncCall, enum_name: str
) -> (ir.Value | None) {
    lay = self._enum_ctor_layout(enum_name);
    if lay is None {
        return None;
    }
    _params = nd.params or [];
    if len(_params) != 1 or isinstance(_params[0], uni.KWPair) {
        self._emit_enum_ctor_refusal(
            nd, enum_name, "It takes exactly one positional value."
        );
        return None;
    }
    if lay.is_string_enum {
        self._emit_enum_ctor_refusal(
            nd,
            enum_name,
            "Its members carry string values, whose runtime form is the "
            "ordinal rather than the value, so the lookup is not the identity."
        );
        return None;
    }
    if not lay.all_values_known {
        self._emit_enum_ctor_refusal(
            nd,
            enum_name,
            "At least one member's value is not compile-time known, so the "
            "table to validate against cannot be encoded."
        );
        return None;
    }
    _arg = self._codegen_expr(_params[0]);
    if _arg is None {
        self._emit_enum_ctor_refusal(nd, enum_name, "Its argument did not lower.");
        return None;
    }
    if not isinstance(_arg.type, ir.IntType) {
        self._emit_enum_ctor_refusal(
            nd,
            enum_name,
            "Its argument is not already an integer value, and coercing one "
            "to reach the table would answer for a value the caller never "
            "passed."
        );
        return None;
    }
    i64 = ir.IntType(64);
    _val = self._coerce_type(_arg, i64);
    b = self.builder;
    _ok: any = ir.Constant(ir.IntType(1), 0);
    _seen: set = set();
    for m in lay.members {
        if m.int_value in _seen {
            continue;
        }
        _seen.add(m.int_value);
        _hit = b.icmp_signed(
            "==", _val, ir.Constant(i64, m.int_value), name=f"ec.{enum_name}.{m.name}"
        );
        _ok = b.or_(_ok, _hit, name=f"ec.{enum_name}.acc.{m.name}");
    }
    _bad = b.not_(_ok, name=f"ec.{enum_name}.bad");
    self._emit_runtime_raise(_bad, "ValueError", f"is not a valid {enum_name}");
    return _val;
}
