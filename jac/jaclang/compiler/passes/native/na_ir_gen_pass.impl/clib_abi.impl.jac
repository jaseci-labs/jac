impl NaIRGenPass._foreign_model -> dict {
    import from jaclang.compiler.targets.foreign { collect_foreign_structs }
    universe = [self.ir_in] + self._foreign_modules;
    if self._foreign_structs is None or self._foreign_model_nmods != len(universe) {
        self._foreign_structs = collect_foreign_structs(universe);
        self._foreign_model_nmods = len(universe);
    }
    return self._foreign_structs;
}

impl NaIRGenPass._foreign_fns -> dict {
    import from jaclang.compiler.targets.foreign { collect_foreign_fns }
    universe = [self.ir_in] + self._foreign_modules;
    if self._foreign_fn_decls is None or self._foreign_fns_nmods != len(universe) {
        self._foreign_fn_decls = collect_foreign_fns(universe);
        self._foreign_fns_nmods = len(universe);
    }
    return self._foreign_fn_decls;
}

impl NaIRGenPass._foreign_fields_of(name: str) -> list {
    model = self._foreign_model();
    indices = self.struct_field_indices.get(name, {});
    out: list = [];
    for (i, (fn, tn)) in enumerate(model.get(name, [])) {
        assert fn not in indices or indices[fn] == i , f"foreign field order mismatch for {name}.{fn}";
        out.append((fn, tn if (tn is not None and tn in model) else None));
    }
    return out;
}

impl NaIRGenPass._clib_struct_layout(name: str) -> tuple {
    import from jaclang.compiler.targets.foreign { foreign_struct_layout }
    return foreign_struct_layout(self._foreign_model(), name);
}

impl NaIRGenPass._clib_has_nested(name: str) -> bool {
    for (_fn, nested) in self._foreign_fields_of(name) {
        if nested is not None {
            return True;
        }
    }
    return False;
}

impl NaIRGenPass._clib_c_type(name: str) -> ir.Type {
    if not self._clib_has_nested(name) {
        return self.struct_types[name];
    }
    key = name + ".cabi";
    if key in self.struct_types {
        return self.struct_types[key];
    }
    ct = self.llvm_module.context.get_identified_type(key);
    self.struct_types[key] = ct;
    ftypes = self.struct_field_types.get(name, {});
    body: list = [];
    for (fn, nested) in self._foreign_fields_of(name) {
        if nested is not None {
            body.append(self._clib_c_type(nested));
        } else {
            body.append(ftypes.get(fn, ir.IntType(64)));
        }
    }
    ct.set_body(*body);
    return ct;
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
    raw_ptr = self._rc_call_with_ctx(
        self.rc_alloc_fn, [size], op="box", name="clib.box.raw"
    );
    typed_ptr = self.builder.bitcast(raw_ptr, sptype, name="clib.box.ptr");

    self._emit_struct_release_fn(name);
    dtor_fn = self.struct_release_fns.get(name);
    if dtor_fn is not None {
        i8p = ir.IntType(8).as_pointer();
        i64 = ir.IntType(64);
        i64p = i64.as_pointer();
        raw_i8 = self.builder.bitcast(typed_ptr, i8p, name="clib.box.i8");
        dtor_slot = self.builder.gep(
            raw_i8, [ir.Constant(i64, -8)], name="clib.box.dtorslot"
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

impl NaIRGenPass._clib_copy_jac_to_c(
    jac_ptr: ir.Value, c_ptr: ir.Value, name: str
) -> None {
    for (ix, (fn, tn)) in enumerate(self._foreign_fields_of(name)) {
        jac_field = self.builder.gep(
            jac_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), ix)],
            name="clib.j2c.jf"
        );
        c_field = self.builder.gep(
            c_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), ix)],
            name="clib.j2c.cf"
        );
        if tn is not None {
            sub_jac = self.builder.load(jac_field, name="clib.j2c.subptr");
            self._clib_copy_jac_to_c(sub_jac, c_field, tn);
        } else {
            v = self.builder.load(jac_field, name="clib.j2c.v");
            self.builder.store(v, c_field);
        }
    }
}

impl NaIRGenPass._clib_copy_c_to_jac(
    c_ptr: ir.Value, jac_ptr: ir.Value, name: str
) -> None {
    for (ix, (fn, tn)) in enumerate(self._foreign_fields_of(name)) {
        c_field = self.builder.gep(
            c_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), ix)],
            name="clib.c2j.cf"
        );
        jac_field = self.builder.gep(
            jac_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), ix)],
            name="clib.c2j.jf"
        );
        if tn is not None {
            sub_box = self._clib_alloc_box(tn);
            self._clib_copy_c_to_jac(c_field, sub_box, tn);
            self.builder.store(sub_box, jac_field);
            self._mark_owned(sub_box);
        } else {
            v = self.builder.load(c_field, name="clib.c2j.v");
            self.builder.store(v, jac_field);
        }
    }
}

impl NaIRGenPass._clib_materialize_c_ptr(jac_ptr: ir.Value, name: str) -> ir.Value {
    if not self._clib_has_nested(name) {
        return jac_ptr;
    }
    ct = self._clib_c_type(name);
    cbuf = self._entry_alloca(ct, "clib.cabi.arg");
    self._clib_copy_jac_to_c(jac_ptr, cbuf, name);
    return cbuf;
}

impl NaIRGenPass._clib_box_c_ptr(c_ptr: ir.Value, name: str) -> ir.Value {
    box = self._clib_alloc_box(name);
    if not self._clib_has_nested(name) {
        val = self.builder.load(c_ptr, name="clib.ret.load");
        self.builder.store(val, box);
    } else {
        self._clib_copy_c_to_jac(c_ptr, box, name);
    }
    self._mark_owned(box);
    return box;
}

impl NaIRGenPass._codegen_clib_call(
    func: ir.Function, func_name: str, args: list[ir.Value]
) -> (ir.Value | None) {
    plan = self.clib_fn_abi[func_name];
    param_plans = plan["params"];
    ret_plan = plan["ret"];
    call_args: list = [];

    arg_attrs: dict = {};
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
        if kind == "scalar" {
            if jac_val is None {
                call_args.append(ir.Constant(pp["type"], 0));
            } else {
                call_args.append(self._coerce_type(jac_val, pp["type"]));
            }
        } elif kind == "struct_mem" {
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
    result = self.builder.call(
        func, call_args, name=f"call.{func_name}", arg_attrs=arg_attrs
    );
    rkind = ret_plan["kind"];
    if rkind == "sret" {
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

    if isinstance(result.type, ir.PointerType) {
        self._mark_owned(result);
    }
    return self._clib_sext_ret(func_name, result);
}

impl NaIRGenPass._clib_sext_ret(func_name: str, result: ir.Value) -> ir.Value {
    if not isinstance(result.type, ir.IntType) or result.type.width >= 64 {
        return result;
    }
    _fd = self._foreign_fns().get(func_name);
    _rname = _fd.get("ret") if _fd is not None else None;
    if _rname in ("i8", "i16", "i32") {
        return self.builder.sext(result, ir.IntType(64), name=f"{func_name}.ret.sext");
    }
    return result;
}
