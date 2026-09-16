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

impl NaIRGenPass._clib_coerce_callback(
    val: ir.Value, c_fn_ty: ir.PointerType
) -> ir.Value {
    if self._closure_struct_of(val.type) is not None {
        self.ctx.emit(
            E5092,
            kind="expression",
            name="Jac closure passed as a C function pointer",
            help_text="A Jac Callable carries an environment and cannot be reinterpreted as a C code address. Use a named function in an explicit C-ABI callback record; pass captured state through the C API's context argument."
        );
        return ir.Constant(c_fn_ty, None);
    }
    if isinstance(val, ir.Function) {
        if val.function_type == c_fn_ty.pointee {
            return self.builder.bitcast(val, c_fn_ty, name="clibcb.direct");
        }
        tramp = self._emit_clib_c_trampoline(val, c_fn_ty);
        return self.builder.bitcast(tramp, c_fn_ty, name="clibcb.tramp");
    }
    typed_pointer = isinstance(val.type, ir.PointerType)
        and not val.type.is_opaque
        and isinstance(val.type.pointee, ir.FunctionType);
    null_pointer = isinstance(val, ir.Constant) and val.constant in (None, 0);

    native_address = val.type == ir.IntType(64);
    if not typed_pointer and not null_pointer and not native_address {
        self.ctx.emit(
            E5092,
            kind="expression",
            name="erased value passed as a C function pointer",
            help_text="A C callback requires a named function, native integer address, or typed C function pointer. A nullable or erased Jac Callable may carry an environment and cannot be cast to that address. Store named callbacks in an explicit C-ABI callback record."
        );
        return ir.Constant(c_fn_ty, None);
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
    jac_fn: ir.Function, c_fn_ty: ir.PointerType
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
    `entry = tramp.append_basic_block("entry");
    saved_builder = self._builder;
    self._builder = ir.IRBuilder(`entry);
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

impl NaIRGenPass._lower_clib_function_type(
    arch_name: str, fname: str, t: any
) -> ir.Type {
    i8p = ir.IntType(8).as_pointer();
    _sd = self._str_desc_ty;
    _bt = self._get_bytes_struct_type();

    def c_scalar(lowered: (ir.Type | None)) -> ir.Type {
        if lowered is None {
            return ir.IntType(64);
        }
        if _sd is not None and lowered == _sd {
            return i8p;
        }
        if isinstance(lowered, ir.PointerType) and lowered.pointee == _bt {
            return i8p;
        }
        return lowered;
    }
    ret_type: ir.Type = ir.VoidType();
    if t.return_type is not None {
        _r = self._lower_type(t.return_type);
        if _r is not None {
            if _sd is not None and _r == _sd {
                if arch_name not in self.clib_fnptr_str_ret {
                    self.clib_fnptr_str_ret[arch_name] = set();
                }
                self.clib_fnptr_str_ret[arch_name].add(fname);
            }
            ret_type = c_scalar(_r);
        }
    }
    param_types: list[ir.Type] = [];
    for p in (t.parameters or []) {
        param_types.append(c_scalar(self._lower_type(p.param_type)));
    }
    return ir.FunctionType(ret_type, param_types).as_pointer();
}

impl NaIRGenPass._clib_fnptr_arg(val: ir.Value, target: ir.Type) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    if target == i8p {
        _bt = self._get_bytes_struct_type();
        if isinstance(val.type, ir.PointerType) and val.type.pointee == _bt {
            return self._bytes_data_ptr(val);
        }
        if isinstance(val.type, ir.PointerType) and val.type == i8p {
            return self._membrane_str_out(self.builder, val);
        }
    }
    return self._coerce_type(val, target);
}

impl NaIRGenPass._clib_fnptr_ret(
    arch_name: str, fname: str, result: ir.Value
) -> ir.Value {
    if fname in self.clib_fnptr_str_ret.get(arch_name, set())
        and isinstance(result.type, ir.PointerType) {
        wrapped = self._membrane_str_in(self.builder, result);
        self._mark_owned(wrapped);
        return wrapped;
    }
    return result;
}
