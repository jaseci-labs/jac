import from jaclang.compiler.backends.native.region_abi { REGION_KERNEL_ABI }

glob REGION_TLS_GLOBAL: str = "__jac_region_tls",
     REGION_TLS_GET: str = "__jac_region_tls_get",
     REGION_TLS_SET: str = "__jac_region_tls_set",
     REGION_GBL_GET: str = "__jac_region_gbl_get";

impl NaIRGenPass._register_region_kernel -> None {
    if self._region_kernel_registered {
        return;
    }
    self._region_kernel_registered = True;
    import from jaclang.compiler.frontend.codeinfo {
        REGION_KERNEL_REL,
        kernel_unit_path
    }
    if not self._is_kernel_unit() {
        self._note_native_dep(kernel_unit_path(REGION_KERNEL_REL));
    }
    self._emit_region_tls_slot();
}

impl NaIRGenPass._region_kernel_fn(name: str) -> ir.Function {
    self._register_region_kernel();
    (ret_i64, nargs) = REGION_KERNEL_ABI[name];
    i64 = ir.IntType(64);
    return self._get_or_declare_extern(
        name, i64 if ret_i64 else ir.VoidType(), [i64 for _i in range(nargs)]
    );
}

impl NaIRGenPass._emit_region_tls_slot -> None {
    if REGION_GBL_GET in self.extern_funcs {
        return;
    }
    self._emit_tls_slot(REGION_TLS_GLOBAL, REGION_TLS_GET, REGION_TLS_SET);
    i64 = ir.IntType(64);
    gbl_gv = ir.GlobalVariable(
        self.llvm_module, ir.ArrayType(i64, 8), name=f"{REGION_TLS_GLOBAL}_gbl"
    );
    gbl_gv.linkage = "weak";
    gbl_gv.initializer = ir.Constant(ir.ArrayType(i64, 8), None);
    gbl_fn = ir.Function(
        self.llvm_module, ir.FunctionType(i64, []), name=REGION_GBL_GET
    );
    gbl_fn.linkage = "weak";
    self.extern_funcs[REGION_GBL_GET] = gbl_fn;
    gblb = ir.IRBuilder(gbl_fn.append_basic_block("entry"));
    gblb.ret(gblb.ptrtoint(gbl_gv, i64, name="gbl.i64"));
}

impl NaIRGenPass._region_i64(val: ir.Value, name: str = "rgn.i64") -> ir.Value {
    i64 = ir.IntType(64);
    if self._opt_ptr_payload_of(val.type) is not None {
        val = self.builder.extract_value(val, 1, name=f"{name}.opt");
    }
    if isinstance(val.type, ir.PointerType) {
        return self.builder.ptrtoint(val, i64, name=name);
    }
    return self._coerce_type(val, i64);
}

impl NaIRGenPass._region_ptr(val: ir.Value, name: str = "rgn.p") -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    if self._opt_ptr_payload_of(val.type) is not None {
        val = self.builder.extract_value(val, 1, name=f"{name}.opt");
    }
    if isinstance(val.type, ir.PointerType) {
        if val.type == i8p {
            return val;
        }
        return self.builder.bitcast(val, i8p, name=name);
    }
    return self.builder.inttoptr(val, i8p, name=name);
}

impl NaIRGenPass._region_new_handle -> ir.Value {
    raw = self.builder.call(
        self._region_kernel_fn("__jac_region_new"), [], name="region.new"
    );
    return self._region_ptr(raw, name="region.hdl");
}

impl NaIRGenPass._region_current -> ir.Value {
    raw = self.builder.call(
        self._region_kernel_fn("__jac_region_current"), [], name="region.cur"
    );
    return self._region_ptr(raw, name="region.cur.p");
}

impl NaIRGenPass._region_of_value(val: ir.Value) -> ir.Value {
    raw = self.builder.call(
        self._region_kernel_fn("__jac_region_of"),
        [self._region_i64(val, name="region.of.arg")],
        name="region.of"
    );
    return self._region_ptr(raw, name="region.of.p");
}

impl NaIRGenPass._region_enter(hdl: ir.Value) -> None {
    self.builder.call(
        self._region_kernel_fn("__jac_region_enter"),
        [self._region_i64(hdl, name="region.enter.arg")]
    );
}

impl NaIRGenPass._region_leave -> None {
    self.builder.call(self._region_kernel_fn("__jac_region_leave"), []);
}

impl NaIRGenPass._emit_region_leaves(count: int) -> None {
    if self._builder is None or self.builder.block.is_terminated {
        return;
    }
    for _i in range(count) {
        self._region_leave();
    }
}

impl NaIRGenPass._region_depth -> ir.Value {
    return self.builder.call(
        self._region_kernel_fn("__jac_region_depth"), [], name="region.depth"
    );
}

impl NaIRGenPass._region_unwind(depth: ir.Value) -> None {
    self.builder.call(
        self._region_kernel_fn("__jac_region_unwind"),
        [self._coerce_type(depth, ir.IntType(64))]
    );
}

impl NaIRGenPass._region_alloc_object(
    hdl: ir.Value, size: ir.Value, type_name: (str | None)
) -> ir.Value {
    raw = self.builder.call(
        self._region_kernel_fn("__jac_region_alloc"),
        [
            self._region_i64(hdl, name="region.alloc.hdl"),
            self._coerce_type(size, ir.IntType(64))
        ],
        name="region.alloc"
    );
    o_ptr = self._region_ptr(raw, name="region.o_ptr");
    self.rc_region_allocs += 1;
    if type_name is None {
        return o_ptr;
    }
    if self.rc_set_type_fn is not None {
        self._emit_set_type_tag(self.builder, o_ptr, type_name);
    }
    dtor = self._emit_struct_drop_fields_fn(type_name);
    if dtor is not None {
        self.builder.call(
            self._region_kernel_fn("__jac_region_log_dtor"),
            [
                self._region_i64(hdl, name="region.log.hdl"),
                self._region_i64(o_ptr, name="region.log.o_ptr"),
                self._region_i64(dtor, name="region.log.fn")
            ]
        );
    }
    return o_ptr;
}

impl NaIRGenPass._region_partition(hdl: ir.Value) -> ir.Value {
    raw = self.builder.call(
        self._region_kernel_fn("__jac_region_partition"),
        [self._region_i64(hdl, name="region.part.arg")],
        name="region.partn"
    );
    return self._region_ptr(raw, name="region.child");
}

impl NaIRGenPass._region_owns(ptr: ir.Value) -> ir.Value {
    return self.builder.call(
        self._region_kernel_fn("__jac_region_owns"),
        [self._region_i64(ptr, name="region.owns.arg")],
        name="region.owns"
    );
}

impl NaIRGenPass._emit_region_handle_drop(alloca: ir.Value, var_name: str) -> None {
    hdl = self.builder.load(alloca, name=f"region.drop.{var_name}");
    self.builder.call(
        self._region_kernel_fn("__jac_region_drop"),
        [self._region_i64(hdl, name=f"region.drop.{var_name}.i64")]
    );
    slot_ty = alloca.type;
    assert isinstance(slot_ty, ir.PointerType) , "a region handle slot is always a pointer";
    self.builder.store(ir.Constant(slot_ty.pointee, None), alloca);
}

impl NaIRGenPass._register_region_handle_var(
    nd: uni.Assignment, var_name: str
) -> None {
    _tgt = nd.target[0]
        if (len(nd.target) == 1 and isinstance(nd.target[0], uni.Name))
        else None;
    if _tgt is None or _tgt.sym is None or not _tgt.sym.na_region_handle {
        return;
    }
    self.region_handle_vars.add(var_name);
    if isinstance(nd.value, uni.Name)
        and nd.value.sym is not None
        and nd.value.sym.na_region_handle
        and nd.value.sym_name != var_name {
        self.region_handle_vars.discard(nd.value.sym_name);
    }
}

impl NaIRGenPass._lower_partition_unpack(nd: uni.Assignment) -> bool {
    import from jaclang.compiler.expr_keys { is_builtin_region_type }
    if len(nd.target) != 1 or not isinstance(nd.target[0], uni.TupleVal) {
        return False;
    }
    _call = nd.value;
    if not isinstance(_call, uni.FuncCall) {
        return False;
    }
    _tr = _call.target;
    if not (
        isinstance(_tr, uni.AtomTrailer)
        and isinstance(_tr.right, uni.Name)
        and _tr.right.sym_name == "partition"
        and (_call.params or [])
        and is_builtin_region_type(_tr.target.type)
    ) {
        return False;
    }
    _recv = self._codegen_expr(_tr.target);
    if _recv is None {
        return False;
    }
    _i8p = ir.IntType(8).as_pointer();
    for tgt in nd.target[0].values {
        if not isinstance(tgt, uni.Name) {
            continue;
        }
        _child = self._region_partition(_recv);
        _slot = self.local_vars.get(tgt.sym_name);
        if _slot is None {
            _slot = self._entry_alloca(_i8p, tgt.sym_name);
            self.local_vars[tgt.sym_name] = _slot;
        }
        self.builder.store(_child, _slot);
        self.region_handle_vars.add(tgt.sym_name);
    }
    return True;
}

impl NaIRGenPass._emit_struct_drop_fields_fn(type_name: str) -> (ir.Function | None) {
    if type_name in self.struct_drop_fields_fns {
        return self.struct_drop_fields_fns[type_name];
    }
    struct_type = self.struct_types.get(type_name);
    if struct_type is None {
        return None;
    }
    _hook = self._drop_hook_for(type_name);
    field_types = self.struct_field_types.get(type_name, {});
    field_indices = self.struct_field_indices.get(type_name, {});
    foreign_fields = self.struct_field_foreign.get(type_name, set());
    _ptr_fields = [
        (fname, ftype)
        for (fname, ftype) in field_types.items()
        if fname not in foreign_fields
            and (
                isinstance(ftype, ir.PointerType)
                or self._opt_ptr_payload_of(ftype) is not None
            )
            and field_indices.get(fname, -1) >= 0
    ];
    if _hook is None and not _ptr_fields {
        return None;
    }
    _headerless = self._nogc_headerless();
    if not _headerless and self.rc_release_simple_fn is None {
        self._emit_rc_helpers();
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    fnty = ir.FunctionType(ir.VoidType(), [i8p]);
    fn = ir.Function(self.llvm_module, fnty, name=f"__drop_fields_{type_name}");
    fn.linkage = "private";
    fn.args[0].name = "self";
    self.struct_drop_fields_fns[type_name] = fn;

    entry_bb = fn.append_basic_block("entry");
    body_bb = fn.append_basic_block("body");
    done_bb = fn.append_basic_block("done");
    b = ir.IRBuilder(entry_bb);
    is_null = b.icmp_unsigned(
        "==", fn.args[0], ir.Constant(i8p, None), name="dropf.null"
    );
    b.cbranch(is_null, done_bb, body_bb);

    b.position_at_end(body_bb);
    _dobj = b.bitcast(fn.args[0], struct_type.as_pointer(), name="dropf.obj");
    if _headerless {
        self._emit_nogc_field_drops(b, type_name, _dobj);
        b.branch(done_bb);
        b.position_at_end(done_bb);
        b.ret_void();
        return fn;
    }
    if _hook is not None {
        self.struct_drop_hooks[type_name] = _hook;
        b.call(_hook, [b.bitcast(_dobj, _hook.args[0].type)]);
    }
    for (fname, ftype) in _ptr_fields {
        idx = field_indices.get(fname, -1);
        fp = b.gep(
            _dobj, [ir.Constant(i32, 0), ir.Constant(i32, idx)], name=f"dropf.{fname}.p"
        );
        if self._opt_ptr_payload_of(ftype) is not None {
            fp = b.gep(
                fp,
                [ir.Constant(i32, 0), ir.Constant(i32, 1)],
                name=f"dropf.{fname}.pvp"
            );
            fv = b.load(fp, name=f"dropf.{fname}.pv");
            b.call(
                self.rc_release_simple_fn,
                [b.bitcast(fv, i8p, name=f"dropf.{fname}.pv.i8")]
            );
            continue;
        }
        fv = b.load(fp, name=f"dropf.{fname}");
        _fv_ty = fv.type;
        if isinstance(_fv_ty, ir.PointerType)
            and isinstance(_fv_ty.pointee, ir.FunctionType) {
            continue;
        }
        fv_i8 = b.bitcast(fv, i8p, name=f"dropf.{fname}.i8");
        b.call(self.rc_release_simple_fn, [fv_i8]);
    }
    b.branch(done_bb);

    b.position_at_end(done_bb);
    b.ret_void();
    return fn;
}
