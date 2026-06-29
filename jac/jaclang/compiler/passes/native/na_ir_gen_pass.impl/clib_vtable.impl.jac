impl NaIRGenPass._clib_struct_has_fn_ptr(name: str) -> bool {
    for ftype in self.struct_field_types.get(name, {}).values() {
        if isinstance(ftype, ir.PointerType)
        and isinstance(ftype.pointee, ir.FunctionType) {
            return True;
        }
    }
    return False;
}

impl NaIRGenPass._clib_detect_vtable_structs -> None {
    for name in self.clib_struct_names {
        if name not in self.clib_vtable_structs
        and self._clib_struct_has_fn_ptr(name) {
            self.clib_vtable_structs.add(name);
        }
    }
}

impl NaIRGenPass._clib_coerce_callback(val: ir.Value, c_fn_ty: ir.Type) -> ir.Value {
    if isinstance(val, ir.Function) {
        if val.function_type == c_fn_ty.pointee {
            return self.builder.bitcast(val, c_fn_ty, name="clibcb.direct");
        }
        tramp = self._emit_clib_c_trampoline(val, c_fn_ty);
        return self.builder.bitcast(tramp, c_fn_ty, name="clibcb.tramp");
    }
    return self._coerce_type(val, c_fn_ty);
}

impl NaIRGenPass._clib_cb_coerce_scalar(
    val: ir.Value, target_type: ir.Type
) -> ir.Value {
    if val.type == target_type {
        return val;
    }
    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.IntType) {
        if val.type.width < target_type.width {
            return self.builder.sext(val, target_type, name="clibcb.sext");
        }
        return self.builder.trunc(val, target_type, name="clibcb.trunc");
    }
    return self._coerce_type(val, target_type);
}

impl NaIRGenPass._emit_clib_c_trampoline(
    jac_fn: ir.Function, c_fn_ty: ir.Type
) -> ir.Function {
    key = f"{jac_fn.name}|{c_fn_ty}";
    cached = self.clib_trampoline_funcs.get(key);
    if cached is not None {
        return cached;
    }
    n = len(self.clib_trampoline_funcs);
    tramp = ir.Function(
        self.llvm_module, c_fn_ty.pointee, name=f"{jac_fn.name}.__clibcb.{n}"
    );
    tramp.linkage = "internal";
    entry = tramp.append_basic_block("entry");
    saved_builder = self._builder;
    self._builder = ir.IRBuilder(entry);
    jac_params = jac_fn.function_type.args;
    call_args: list[ir.Value] = [];
    for (i, arg) in enumerate(tramp.args) {
        arg.name = f"c.arg{i}";
        if i < len(jac_params) {
            call_args.append(self._clib_cb_coerce_scalar(arg, jac_params[i]));
        }
    }
    while len(call_args) < len(jac_params) {
        pty = jac_params[len(call_args)];
        if isinstance(pty, ir.PointerType) {
            call_args.append(ir.Constant(pty, None));
        } else {
            call_args.append(ir.Constant(pty, 0));
        }
    }
    result = self.builder.call(jac_fn, call_args, name="clibcb.call");
    c_ret = c_fn_ty.pointee.return_type;
    if isinstance(c_ret, ir.VoidType) {
        self.builder.ret_void();
    } elif isinstance(jac_fn.function_type.return_type, ir.VoidType) {
        if isinstance(c_ret, ir.PointerType) {
            self.builder.ret(ir.Constant(c_ret, None));
        } else {
            self.builder.ret(ir.Constant(c_ret, 0));
        }
    } else {
        self.builder.ret(self._clib_cb_coerce_scalar(result, c_ret));
    }
    self._builder = saved_builder;
    self.clib_trampoline_funcs[key] = tramp;
    return tramp;
}

impl NaIRGenPass._clib_alloc_vtable(name: str) -> ir.Value {
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    calloc_fn = self._get_or_declare_extern("calloc", i8_ptr, [i64, i64]);
    ct = self._clib_c_type(name);
    null_ptr = ir.Constant(ct.as_pointer(), None);
    size_gep = self.builder.gep(
        null_ptr, [ir.Constant(ir.IntType(32), 1)], name="clib.vt.sizeof.gep"
    );
    size = self.builder.ptrtoint(size_gep, i64, name="clib.vt.sizeof");
    raw = self.builder.call(calloc_fn, [ir.Constant(i64, 1), size], name="clib.vt.raw");
    return self.builder.bitcast(
        raw, self.struct_types[name].as_pointer(), name="clib.vt.ptr"
    );
}
