import from jaclang.compiler.c_interop { c_variadic_param }
impl NaIRGenPass._foreign_model -> dict[str, list[tuple[str, str | None]]] {
    import from jaclang.compiler.backends.native.foreign { collect_foreign_structs }
    universe = [self.module] + self._foreign_modules;
    if self._foreign_structs is None or self._foreign_model_nmods != len(universe) {
        self._foreign_structs = collect_foreign_structs(universe);
        self._foreign_model_nmods = len(universe);
    }
    return self._foreign_structs;
}

impl NaIRGenPass._foreign_fns -> dict[str, dict[str, any]] {
    import from jaclang.compiler.backends.native.foreign { collect_foreign_fns }
    universe = [self.module] + self._foreign_modules;
    if self._foreign_fn_decls is None or self._foreign_fns_nmods != len(universe) {
        self._foreign_fn_decls = collect_foreign_fns(universe);
        self._foreign_fns_nmods = len(universe);
    }
    return self._foreign_fn_decls;
}

impl NaIRGenPass._clib_struct_layout(
    name: str
) -> tuple[int, int, list[tuple[int, bool, int]]] {
    import from jaclang.compiler.backends.native.foreign { foreign_struct_layout }
    return foreign_struct_layout(self._foreign_model(), name);
}

impl NaIRGenPass._clib_c_type(name: str) -> ir.Type {
    return self.struct_types[name];
}

impl NaIRGenPass._clib_alloc_box(name: str) -> ir.Value {
    import os;
    stype = self.struct_types[name];
    sptype = stype.as_pointer();
    null_ptr = ir.Constant(sptype, None);
    size_gep = self.builder.gep(
        null_ptr, [ir.Constant(ir.IntType(32), 1)], name="clib.box.sizeof.gep"
    );
    size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="clib.box.sizeof");
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    _alloc_fn = self.rc_alloc_fn;
    assert _alloc_fn is not None , "rc helpers are emitted before allocation";
    raw_ptr = self._rc_call_with_ctx(_alloc_fn, [size], op="box", name="clib.box.raw");
    typed_ptr = self.builder.bitcast(raw_ptr, sptype, name="clib.box.ptr");

    self._emit_struct_release_fn(name);
    dtor_fn = self.struct_release_fns.get(name);
    if dtor_fn is not None {
        i8p = ir.IntType(8).as_pointer();
        i64 = ir.IntType(64);
        i64p = i64.as_pointer();
        raw_i8 = self.builder.bitcast(typed_ptr, i8p, name="clib.box.i8");
        dtor_slot = self.builder.gep(
            raw_i8, [ir.Constant(i64, HDR_DTOR_OFF)], name="clib.box.dtorslot"
        );
        dtor_slot_i64 = self.builder.bitcast(dtor_slot, i64p, name="clib.box.dtori64p");
        dtor_i64 = self.builder.ptrtoint(dtor_fn, i64, name="clib.box.dtori64");
        self.builder.store(dtor_i64, dtor_slot_i64);
    }
    if self.rc_set_type_fn is not None {
        tag_i8 = self.builder.bitcast(
            typed_ptr, ir.IntType(8).as_pointer(), name="clib.box.tag"
        );
        self._emit_set_type_tag(self.builder, tag_i8, name);
    }
    return typed_ptr;
}

impl NaIRGenPass._clib_materialize_c_ptr(jac_ptr: ir.Value, name: str) -> ir.Value {
    ct = self._clib_c_type(name).as_pointer();
    if jac_ptr.type != ct {
        return self.builder.bitcast(jac_ptr, ct, name="clib.cptr");
    }
    return jac_ptr;
}

impl NaIRGenPass._clib_box_c_ptr(c_ptr: ir.Value, name: str) -> ir.Value {
    return self._foreign_copy_box(c_ptr, name);
}

impl NaIRGenPass._codegen_clib_call(
    func: ir.Function,
    func_name: str,
    args: list[ir.Value],
    copybacks: (list[tuple[ir.Value, ir.Value, any]] | None) = None
) -> (ir.Value | None) {
    plan = self.clib_fn_abi[func_name];
    param_plans = plan["params"];
    ret_plan = plan["ret"];
    call_args: list[ir.Value] = [];

    arg_attrs: dict[int, ir.ArgumentAttributes] = {};
    sret_buf = None;
    if plan["sret"] {
        sret_ct = self._clib_c_type(ret_plan["sname"]);
        sret_buf = self._entry_alloca(sret_ct, "clib.sret.buf");
        sret_aa = ir.ArgumentAttributes();
        sret_aa.add("sret");
        sret_aa.type = sret_ct;
        _sret_al = ret_plan["align"];
        sret_aa.align = _sret_al if _sret_al > 8 else 8;
        arg_attrs[len(call_args)] = sret_aa;
        call_args.append(sret_buf);
    }
    for (i, pp) in enumerate(param_plans) {
        jac_val = args[i] if i < len(args) else None;
        kind = pp["kind"];
        _c_arg = pp.get("c_arg") or {};
        if kind == "scalar" and _c_arg {
            if jac_val is None {
                call_args.append(ir.Constant(pp["type"], None));
            } else {
                call_args.append(self._clib_pointer_arg(jac_val));
            }
        } elif kind == "scalar" {
            if jac_val is None {
                call_args.append(ir.Constant(pp["type"], 0));
            } else {
                _cv = jac_val;
                scalar_type = pp["type"];
                if self._is_bytes_value(_cv)
                    and scalar_type == ir.IntType(8).as_pointer() {
                    _cv = self._bytes_data_ptr(_cv);
                } elif pp.get("is_str") and isinstance(_cv.type, ir.PointerType) {
                    _cv = self._membrane_str_out(self.builder, _cv);
                }
                if isinstance(scalar_type, ir.PointerType)
                    and not scalar_type.is_opaque
                    and isinstance(scalar_type.pointee, ir.FunctionType) {
                    call_args.append(self._clib_coerce_callback(_cv, scalar_type));
                } else {
                    call_args.append(self._coerce_type(_cv, scalar_type));
                }
            }
        } elif kind == "struct_mem" {
            if jac_val is None {
                return None;
            }
            c_ptr = self._clib_materialize_c_ptr(jac_val, pp["sname"]);
            if pp["byval"] {
                byval_aa = ir.ArgumentAttributes();
                byval_aa.add("byval");
                byval_aa.type = self._clib_c_type(pp["sname"]);
                _bv_al = pp["align"];
                byval_aa.align = _bv_al if _bv_al > 8 else 8;
                arg_attrs[len(call_args)] = byval_aa;
                call_args.append(c_ptr);
            } else {
                _ct = self._clib_c_type(pp["sname"]);
                _copy = self._entry_alloca(_ct, "clib.indir.copy");
                self.builder.store(
                    self.builder.load(c_ptr, name="clib.indir.load"), _copy
                );
                call_args.append(_copy);
            }
        } else {
            if jac_val is None {
                return None;
            }
            c_ptr = self._clib_materialize_c_ptr(jac_val, pp["sname"]);
            coerce = pp["coerce"];
            ct = ir.LiteralStructType(coerce);
            if pp["safe"] {
                _buf = self._entry_alloca(ct, "clib.arg.buf");
                _sct = self._clib_c_type(pp["sname"]);
                self.builder.store(
                    self.builder.load(c_ptr, name="clib.arg.sload"),
                    self.builder.bitcast(_buf, _sct.as_pointer(), name="clib.arg.bcopy")
                );
                ct_ptr = _buf;
            } else {
                ct_ptr = self.builder.bitcast(
                    c_ptr, ct.as_pointer(), name="clib.arg.cast"
                );
            }
            for j in range(len(coerce)) {
                piece_ptr = self.builder.gep(
                    ct_ptr,
                    [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), j)],
                    name="clib.arg.piece"
                );
                call_args.append(self.builder.load(piece_ptr, name="clib.arg.load"));
            }
        }
    }
    for extra in args[len(param_plans):] {
        call_args.append(extra);
    }
    _actual_params = func.function_type.args;
    for (k, _ca) in enumerate(call_args) {
        if k < len(_actual_params) and _ca.type != _actual_params[k] {
            call_args[k] = self._clib_reinterpret(
                _ca, _actual_params[k], name=f"clib.arg.{k}"
            );
        }
    }
    result: ir.Value = self.builder.call(
        func, call_args, name=f"call.{func_name}", arg_attrs=arg_attrs
    );
    for (_tmp, _slot, _elem) in (copybacks or []) {
        self._c_store_scalar(
            self._c_load_scalar(_tmp, _elem, "clib.copyback"), _slot, _elem
        );
    }
    _struct_temps: list[ir.Value] = [];
    for (i, pp) in enumerate(param_plans) {
        _tv = args[i] if i < len(args) else None;
        if _tv is not None
            and pp["kind"] != "scalar"
            and isinstance(_tv.type, ir.PointerType)
            and self._is_owned(_tv) {
            _struct_temps.append(_tv);
        }
    }
    for _st in _struct_temps {
        self._c_release_temp(_st);
    }
    rkind = ret_plan["kind"];
    if rkind == "sret" {
        assert sret_buf is not None , "the sret buffer is allocated whenever the plan asks for one";
        return self._clib_box_c_ptr(sret_buf, ret_plan["sname"]);
    }
    if rkind == "struct_reg" {
        sname = ret_plan["sname"];
        coerce = ret_plan["coerce"];

        if ret_plan["safe"] {
            rbuf = self._entry_alloca(ir.LiteralStructType(coerce), "clib.ret.rbuf");
        } else {
            rbuf = self._entry_alloca(self._clib_c_type(sname), "clib.ret.cbuf");
        }
        if len(coerce) == 1 {
            slot = self.builder.bitcast(
                rbuf, coerce[0].as_pointer(), name="clib.ret.cast"
            );
            self.builder.store(result, slot);
        } else {
            ct = ir.LiteralStructType(coerce);
            ct_ptr = self.builder.bitcast(rbuf, ct.as_pointer(), name="clib.ret.cast");
            for j in range(len(coerce)) {
                piece = self.builder.extract_value(result, j, name="clib.ret.piece");
                piece_ptr = self.builder.gep(
                    ct_ptr,
                    [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), j)],
                    name="clib.ret.slot"
                );
                self.builder.store(piece, piece_ptr);
            }
        }
        c_view = self.builder.bitcast(
            rbuf, self._clib_c_type(sname).as_pointer(), name="clib.ret.cview"
        );
        return self._clib_box_c_ptr(c_view, sname);
    }

    if ret_plan.get("cptr") {
        return self.builder.ptrtoint(result, ir.IntType(64), name="clib.ret.addr");
    }
    _declared_ret = ret_plan.get("type");
    if (
        isinstance(_declared_ret, ir.Type)
        and not isinstance(_declared_ret, ir.VoidType)
        and result.type != _declared_ret
    ) {
        return self._clib_reinterpret(result, _declared_ret, name="clib.ret");
    }
    if isinstance(result.type, ir.PointerType) {
        if ret_plan.get("is_str") {
            result = self._membrane_str_in(self.builder, result);
        }
        self._mark_owned(result);
    }
    return result;
}

impl NaIRGenPass._clib_reinterpret(
    val: ir.Value, want: ir.Type, name: str
) -> ir.Value {
    if val.type == want {
        return val;
    }
    if isinstance(val.type, ir.PointerType) and isinstance(want, ir.IntType) {
        return self.builder.ptrtoint(val, want, name=name);
    }
    if isinstance(val.type, ir.IntType) and isinstance(want, ir.PointerType) {
        return self.builder.inttoptr(val, want, name=name);
    }
    if isinstance(val.type, ir.PointerType) and isinstance(want, ir.PointerType) {
        return self.builder.bitcast(val, want, name=name);
    }
    return self._coerce_type(val, want);
}

impl NaIRGenPass._declare_clib_definitions -> None {
    for (name, decl) in self._clib_definitions.items() {
        if c_variadic_param(decl.signature) is not None {
            self._maybe_declare_ability(decl, symbol=name);
            self._record_export(name, name, "function", True);
            if self.module?.gen and name not in self.module.gen._exported_symbols {
                self.module.gen._exported_symbols.append(name);
            }
            continue;
        }
        cfunc = self.clib_extern_fns.get(name) or self.func_symtab.get(name);
        if not isinstance(cfunc, ir.Function) {
            continue;
        }
        self._clib_exports[name] = cfunc;
        self.clib_extern_fns.pop(name, None);
        self.func_symtab.pop(name, None);
        self.clib_extern_names.discard(name);
        self._clib_symbol_lib.pop(name, None);
        self._maybe_declare_ability(decl, symbol=f"{name}.jac");
        jac_fn = self.func_symtab.get(name);
        if isinstance(jac_fn, ir.Function) {
            jac_fn.linkage = "internal";
        }
        self._record_export(name, name, "function", True);
        if self.module?.gen and name not in self.module.gen._exported_symbols {
            self.module.gen._exported_symbols.append(name);
        }
    }
}

impl NaIRGenPass._emit_clib_definitions -> None {
    for (name, decl) in self._clib_definitions.items() {
        self._codegen_ability(decl);
        if name in self._clib_exports {
            self._emit_clib_export_thunk(name);
        }
    }
}

impl NaIRGenPass._emit_clib_export_thunk(name: str) -> None {
    cfunc = self._clib_exports[name];
    jac_fn = self.func_symtab.get(name);
    if not isinstance(jac_fn, ir.Function) or cfunc.blocks {
        return;
    }
    plan = self.clib_fn_abi.get(name);
    state = self._enter_function(cfunc);
    try {
        _scalar_only = plan is None
            or (
                not plan["sret"]
                and plan["ret"].get("kind") != "struct_reg"
                and all(pp["kind"] == "scalar" for pp in plan["params"])
                and all(pp["argpos"] == i for (i, pp) in enumerate(plan["params"]))
            );
        if _scalar_only and self._thunk_tail_call(cfunc, jac_fn) {
            return;
        }
        b = self.builder;
        i32 = ir.IntType(32);
        jac_args: list[ir.Value] = [];
        boxes: list[ir.Value] = [];
        params = plan["params"] if plan is not None else [];
        for (i, want) in enumerate(jac_fn.function_type.args) {
            if plan is None {
                jac_args.append(
                    self._clib_reinterpret(cfunc.args[i], want, name=f"cdef.arg.{i}")
                );
                continue;
            }
            pp = params[i];
            pos = pp["argpos"];
            if pp["kind"] == "scalar" {
                jac_args.append(
                    self._clib_reinterpret(cfunc.args[pos], want, name=f"cdef.arg.{i}")
                );
                continue;
            }
            c_struct = self._clib_c_type(pp["sname"]);
            if pp["kind"] == "struct_mem" {
                src = b.bitcast(
                    cfunc.args[pos], c_struct.as_pointer(), name="cdef.mem"
                );
            } else {
                pieces = ir.LiteralStructType(pp["coerce"]);
                buf = self._entry_alloca(
                    pieces if pp["safe"] else c_struct, "cdef.reg.buf"
                );
                view = b.bitcast(buf, pieces.as_pointer(), name="cdef.reg.view");
                for j in range(len(pp["coerce"])) {
                    b.store(
                        cfunc.args[pos + j],
                        b.gep(view, [ir.Constant(i32, 0), ir.Constant(i32, j)])
                    );
                }
                src = b.bitcast(buf, c_struct.as_pointer(), name="cdef.reg.struct");
            }
            box = self._clib_box_c_ptr(src, pp["sname"]);
            boxes.append(box);
            jac_args.append(self._clib_reinterpret(box, want, name=f"cdef.box.{i}"));
        }
        result = b.call(jac_fn, jac_args, name="cdef.call");
        for box in boxes {
            self._c_release_temp(box);
        }
        ret_type = cfunc.function_type.return_type;
        ret_plan = plan["ret"] if plan is not None else {};
        rkind = ret_plan.get("kind");
        if plan is not None and (plan["sret"] or rkind == "struct_reg") {
            self._mark_owned(result);
            c_struct = self._clib_c_type(ret_plan["sname"]);
            src = self._clib_materialize_c_ptr(result, ret_plan["sname"]);
            if plan["sret"] {
                b.store(
                    b.load(src, name="cdef.ret.value"),
                    b.bitcast(cfunc.args[0], c_struct.as_pointer(), name="cdef.sret")
                );
                self._c_release_temp(result);
                b.ret_void();
            } else {
                coerce = ret_plan["coerce"];
                shape = coerce[0] if len(coerce) == 1 else ir.LiteralStructType(coerce);
                if ret_plan["safe"] {
                    staged = self._entry_alloca(
                        ir.LiteralStructType(coerce), "cdef.ret.stage"
                    );
                    b.store(
                        b.load(src, name="cdef.ret.struct"),
                        b.bitcast(staged, c_struct.as_pointer())
                    );
                    src = staged;
                }
                value = b.load(b.bitcast(src, shape.as_pointer()), name="cdef.ret.reg");
                self._c_release_temp(result);
                b.ret(value);
            }
        } elif isinstance(ret_type, ir.VoidType) {
            b.ret_void();
        } else {
            b.ret(self._clib_reinterpret(result, ret_type, name="cdef.ret"));
        }
    } finally {
        self._leave_function(state);
    }
}

impl NaIRGenPass._thunk_tail_call(cfunc: ir.Function, jac_fn: ir.Function) -> bool {
    """Emit an exported C symbol's thunk as one `musttail` jump into its body.

    A C function defined in Jac is a thunk around the internal Jac body. When
    each C parameter reaches the body unchanged or as the same 64-bit word (a
    C pointer the body reads as `ptr[T]`, an i64), the thunk only adds a
    frame; a C function pointer dispatch (`return tail
    table.view(1)[0].step(...)`) jumps into the thunk, so an ordinary call here
    grows the stack by a frame per step on an unoptimized build and breaks the
    tail-call guarantee. The call goes through the body's address typed with
    the thunk's own prototype, which `musttail` requires, and passes the same
    registers the body reads.
    """;
    cty = cfunc.function_type;
    jty = jac_fn.function_type;
    triple = str(self.llvm_module.triple or "");
    if cty.var_arg
        or jty.var_arg
        or cty.return_type != jty.return_type
        or len(cty.args) != len(jty.args)
        or (cfunc.calling_convention or "") != (jac_fn.calling_convention or "")
        or "wasm" in triple
        or "i386" in triple
        or "i686" in triple
        or triple.startswith("arm-")
        or triple.startswith("armv7") {
        return False;
    }
    i64 = ir.IntType(64);
    for (c_arg, j_arg) in zip(cty.args, jty.args) {
        if c_arg == j_arg {
            continue;
        }
        if isinstance(c_arg, ir.PointerType) and j_arg == i64 {
            continue;
        }
        return False;
    }
    b = self.builder;
    target = jac_fn
        if cty == jty
        else b.bitcast(jac_fn, cty.as_pointer(), name="cdef.body");
    call = b.call(target, list(cfunc.args), name="cdef.call");
    call.tail = "musttail";
    if isinstance(cty.return_type, ir.VoidType) {
        b.ret_void();
    } else {
        b.ret(call);
    }
    return True;
}
