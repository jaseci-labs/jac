import from jaclang.compiler.c_interop {
    c_array_elem,
    c_builtin_kind,
    c_bytes_array_values,
    c_bytes_elem_shape,
    c_bytes_literal,
    c_variadic_param,
    is_va_list_type,
    c_scalar_constant,
    c_string_literal,
    c_type_arg,
    clib_global_of_symbol,
    is_builtin_addressof_call,
    foreign_read_copies,
    foreign_struct_of_type,
    is_builtin_pin_call,
    is_pinned_type,
    is_ptr_type,
    is_ptr_view_type
}

impl NaIRGenPass._foreign_struct_name_of_type(t: any) -> (str | None) {
    arch = foreign_struct_of_type(t);
    if arch is None or arch.name is None {
        return None;
    }
    name = arch.name.value;
    return name if name in self.clib_struct_names else None;
}

impl NaIRGenPass._lower_c_interop_type(t: any) -> (ir.Type | None) {
    kind = c_builtin_kind(t);
    if kind == "ptr" {
        return ir.IntType(64);
    }
    if kind == "PtrView" {
        return self._ptr_view_type();
    }
    if kind == "VaList" {
        return ir.IntType(64);
    }
    if kind == "Pinned" {
        elem = c_type_arg(t);
        sname = self._foreign_struct_name_of_type(elem);
        if sname is None {
            sname = self._pinned_scalar_box(elem);
        }
        if sname is not None and sname in self.struct_types {
            return self.struct_types[sname].as_pointer();
        }
    }
    return None;
}

impl NaIRGenPass._ptr_view_type -> ir.Type {
    ty = self.llvm_module.context.get_identified_type("__jac_ptr_view");
    if ty.is_opaque {
        ty.set_body(ir.IntType(64), ir.IntType(64));
    }
    return ty;
}

impl NaIRGenPass._c_scalar_llvm(t: any) -> (ir.Type | None) {
    import from jaclang.compiler.types.types { ClassType as _CClassType }
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if is_ptr_type(t) {
        return ir.IntType(64);
    }
    if not isinstance(t, _CClassType) or t._shared is None or not t.is_builtin() {
        return None;
    }
    shape_entry = JAC_TYPE_REGISTRY.get(t.shared.class_name);
    if shape_entry is None
        or not shape_entry.is_int_kind()
        and not shape_entry.is_float_kind() {
        return None;
    }
    if t.shared.class_name == "bool" {
        return ir.IntType(8);
    }
    if shape_entry.is_float_kind() {
        return ir.FloatType() if shape_entry.width == 32 else ir.DoubleType();
    }
    return ir.IntType(shape_entry.width);
}

impl NaIRGenPass._c_load_scalar(slot: ir.Value, t: any, name: str) -> ir.Value {
    raw = self.builder.load(slot, name=name);
    if isinstance(t, ClassType) and t.shared.class_name == "bool" {
        return self.builder.icmp_unsigned(
            "!=", raw, ir.Constant(raw.type, 0), name=f"{name}.bool"
        );
    }
    want = self._lower_type(t);
    if want is not None and want != raw.type {
        return self._coerce_type(raw, want);
    }
    return raw;
}

impl NaIRGenPass._c_store_scalar(value: ir.Value, slot: ir.Value, t: any) -> None {
    slot_type = slot.type;
    assert isinstance(slot_type, ir.PointerType);
    want: ir.Type = slot_type.pointee;
    if isinstance(t, ClassType) and t.shared.class_name == "bool" {
        flag = self._to_bool(value);
        self.builder.store(self.builder.zext(flag, want, name="c.bool.byte"), slot);
        return;
    }
    self.builder.store(self._coerce_type(value, want), slot);
}

impl NaIRGenPass._pinned_scalar_box(elem: any) -> (str | None) {
    llt = self._c_scalar_llvm(elem);
    if llt is None {
        return None;
    }
    name = f"__jac_pinned.{str(llt).replace(' ', '')}";
    if name not in self.struct_types {
        box = self.llvm_module.context.get_identified_type(name);
        if box.is_opaque {
            box.set_body(llt);
        }
        self.struct_types[name] = box;
        self.struct_field_indices[name] = {"value": 0};
        self.struct_field_order[name] = ["value"];
        self.struct_field_types[name] = {"value": llt};
        self.struct_field_defaults[name] = {};
        self.struct_field_foreign[name] = set();
        self.clib_struct_names.add(name);
    }
    return name;
}

impl NaIRGenPass._pinned_value_slot(box: ir.Value) -> ir.Value {
    return self.builder.gep(
        box,
        [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)],
        name="pinned.value.slot"
    );
}

impl NaIRGenPass._foreign_copy_box(src_ptr: ir.Value, name: str) -> ir.Value {
    stype = self.struct_types[name];
    if src_ptr.type != stype.as_pointer() {
        src_ptr = self.builder.bitcast(src_ptr, stype.as_pointer(), name="c.copy.src");
    }
    box = self._clib_alloc_box(name);
    self.builder.store(self.builder.load(src_ptr, name="c.copy.bytes"), box);
    self._mark_owned(box);
    return box;
}

impl NaIRGenPass._c_elem_info(elem: any) -> (tuple[ir.Type, (str | None)] | None) {
    sname = self._foreign_struct_name_of_type(elem);
    if sname is not None {
        return (self.struct_types[sname], sname);
    }
    llt = self._c_scalar_llvm(elem);
    if llt is None {
        return None;
    }
    return (llt, None);
}

impl NaIRGenPass._c_view_elem_ptr(
    view_val: ir.Value, idx_val: ir.Value, elem_llt: ir.Type
) -> ir.Value {
    i64 = ir.IntType(64);
    b = self.builder;
    base = b.extract_value(view_val, 0, name="c.view.base");
    count = b.extract_value(view_val, 1, name="c.view.len");
    idx = self._coerce_type(idx_val, i64);
    neg = b.icmp_signed("<", idx, ir.Constant(i64, 0), name="c.view.neg");
    wrapped = b.add(idx, count, name="c.view.wrap");
    real = b.select(neg, wrapped, idx, name="c.view.idx");
    below = b.icmp_signed("<", real, ir.Constant(i64, 0), name="c.view.below");
    above = b.icmp_signed(">=", real, count, name="c.view.above");
    oob = b.or_(below, above, name="c.view.oob");
    self._emit_runtime_raise(oob, "IndexError", "PtrView index out of range");
    typed = self.builder.inttoptr(base, elem_llt.as_pointer(), name="c.view.typed");
    return self.builder.gep(typed, [real], name="c.view.elem");
}

impl NaIRGenPass._c_view_elem_of(
    nd: uni.AtomTrailer
) -> (tuple[ir.Value, any, ir.Type, (str | None)] | None) {
    if nd.is_attr
        or not isinstance(nd.right, uni.IndexSlice)
        or not is_ptr_view_type(nd.target?.type) {
        return None;
    }
    right = nd.right;
    if right.is_range or len(right.slices) != 1 or right.slices[0].start is None {
        self.ctx.emit(
            E5092,
            node_override=nd,
            kind="PtrView access",
            name="slice",
            help_text="A PtrView is indexed one element at a time: `v[i]`."
        );
        return None;
    }
    elem = c_type_arg(nd.target.type);
    info = self._c_elem_info(elem);
    if info is None {
        return None;
    }
    view_val = self._codegen_expr(nd.target);
    idx_val = self._codegen_expr(right.slices[0].start);
    if view_val is None or idx_val is None {
        return None;
    }
    slot = self._c_view_elem_ptr(view_val, idx_val, info[0]);
    return (slot, elem, info[0], info[1]);
}

impl NaIRGenPass._codegen_c_interop_trailer(
    nd: uni.AtomTrailer
) -> tuple[bool, (ir.Value | None)] {
    target_type = nd.target?.type;
    if not nd.is_attr and is_ptr_view_type(target_type) {
        got = self._c_view_elem_of(nd);
        if got is None {
            return (True, None);
        }
        (slot, elem, _llt, sname) = got;
        if sname is None {
            return (True, self._c_load_scalar(slot, elem, "c.view.get"));
        }
        if foreign_read_copies(nd) {
            return (True, self._foreign_copy_box(slot, sname));
        }
        return (True, slot);
    }
    if nd.is_attr
        and is_pinned_type(target_type)
        and self._get_name(nd.right) == "value" {
        box = self._codegen_expr(nd.target);
        if box is None {
            return (True, None);
        }
        elem = c_type_arg(target_type);
        if self._foreign_struct_name_of_type(elem) is not None {
            return (True, box);
        }
        return (
            True,
            self._c_load_scalar(self._pinned_value_slot(box), elem, "pinned.value")
        );
    }
    return (False, None);
}

impl NaIRGenPass._c_interop_store(
    target: uni.AtomTrailer, value: ir.Value, nd: uni.Assignment
) -> bool {
    target_type = target.target?.type;
    slot: (ir.Value | None) = None;
    elem: any = None;
    sname: (str | None) = None;
    if not target.is_attr and is_ptr_view_type(target_type) {
        got = self._c_view_elem_of(target);
        if got is None {
            return True;
        }
        (slot, elem, _llt, sname) = got;
    } elif target.is_attr
        and is_pinned_type(target_type)
        and self._get_name(target.right) == "value" {
        box = self._codegen_expr(target.target);
        if box is None {
            return True;
        }
        elem = c_type_arg(target_type);
        sname = self._foreign_struct_name_of_type(elem);
        slot = box if sname is not None else self._pinned_value_slot(box);
    } else {
        return False;
    }
    if sname is not None {
        if nd.aug_op is not None {
            self.ctx.emit(
                E5092,
                node_override=target,
                kind="augmented assignment",
                name="foreign struct element"
            );
            return True;
        }
        self._foreign_store_bytes(slot, value, sname);
        return True;
    }
    if nd.aug_op is not None {
        current = self._c_load_scalar(slot, elem, "c.aug.cur");
        updated = self._apply_scalar_aug_op(
            current,
            value,
            nd.aug_op.value,
            nd.value,
            target_type=target.type,
            unsigned=self._is_unsigned_node(target),
            checked=self._is_sized_node(target) or self._is_sized_node(nd.value)
        );
        if updated is None {
            self.ctx.emit(
                E5092,
                node_override=target,
                kind="augmented assignment",
                name=nd.aug_op.value
            );
            return True;
        }
        value = updated;
    }
    self._c_store_scalar(value, slot, elem);
    return True;
}

impl NaIRGenPass._foreign_store_bytes(
    slot: ir.Value, value: ir.Value, sname: str
) -> None {
    stype = self.struct_types[sname];
    src = value;
    if src.type != stype.as_pointer() {
        src = self.builder.bitcast(src, stype.as_pointer(), name="c.store.src");
    }
    if slot.type != stype.as_pointer() {
        slot = self.builder.bitcast(slot, stype.as_pointer(), name="c.store.dst");
    }
    self.builder.store(self.builder.load(src, name="c.store.bytes"), slot);
    self._c_release_temp(value);
}

impl NaIRGenPass._c_release_temp(val: ir.Value) -> None {
    if not self._is_owned(val) or not isinstance(val.type, ir.PointerType) {
        return;
    }
    if self._nogc_headerless() {
        self._nogc_emit_drop(val, op="c_temp");
    } else {
        self._release_owned_args([val], op="c_temp");
    }
    val.is_owned = False;
}

impl NaIRGenPass._codegen_c_interop_call(
    nd: uni.FuncCall
) -> tuple[bool, (ir.Value | None)] {
    i64 = ir.IntType(64);
    params: list[uni.Expr | uni.KWPair] = list(nd.params or []);
    callee_type = nd.target?.type;
    if is_builtin_pin_call(nd) {
        if len(params) != 1 or isinstance(params[0], uni.KWPair) {
            self.ctx.emit(E5092, node_override=nd, kind="call", name="pin(value)");
            return (True, None);
        }
        return (True, self._codegen_pin(params[0]));
    }
    if is_builtin_addressof_call(nd) {
        symbol = params[0] if len(params) == 1 else None;
        symbol_slot = self._clib_global_of(symbol)
            if isinstance(symbol, uni.Name)
            else None;
        if symbol_slot is None {
            self.ctx.emit(
                E5092, node_override=nd, kind="call", name="addressof(C data symbol)"
            );
            return (True, None);
        }
        return (True, self.builder.ptrtoint(symbol_slot[0], i64, name="c.addr"));
    }
    if is_ptr_type(callee_type)
        and callee_type is not None
        and not callee_type.is_instance() {
        if not params {
            return (True, ir.Constant(i64, 0));
        }
        if len(params) != 1 or isinstance(params[0], uni.KWPair) {
            self.ctx.emit(
                E5092, node_override=nd, kind="pointer cast", name="ptr(...)"
            );
            return (True, None);
        }
        text = c_string_literal(params[0]);
        if text is not None {
            return (True, self._c_string_global(text).ptrtoint(i64) as ir.Value);
        }
        return (True, self._codegen_expr(params[0]));
    }
    if isinstance(nd.target, uni.Name)
        and nd.target.value == "bool"
        and len(params) == 1
        and not isinstance(params[0], uni.KWPair)
        and is_ptr_type(params[0]?.type) {
        addr = self._codegen_expr(params[0]);
        if addr is None {
            return (True, None);
        }
        return (
            True,
            self.builder.icmp_unsigned("!=", addr, ir.Constant(i64, 0), name="ptr.bool")
        );
    }
    if isinstance(nd.target, uni.Name)
        and nd.target.value == "len"
        and len(params) == 1
        and not isinstance(params[0], uni.KWPair)
        and is_ptr_view_type(params[0]?.type) {
        view_val = self._codegen_expr(params[0]);
        if view_val is None {
            return (True, None);
        }
        return (True, self.builder.extract_value(view_val, 1, name="c.view.len"));
    }
    if not (isinstance(nd.target, uni.AtomTrailer) and nd.target.is_attr) {
        return (False, None);
    }
    recv = nd.target.target;
    method = self._get_name(nd.target.right);
    if is_va_list_type(recv?.type) and method == "arg" {
        return (True, self._c_va_arg(nd, recv));
    }
    if not is_ptr_type(recv?.type) {
        return (False, None);
    }
    if method == "is_null" {
        addr = self._codegen_expr(recv);
        if addr is None {
            return (True, None);
        }
        return (
            True,
            self.builder.icmp_unsigned("==", addr, ir.Constant(i64, 0), name="ptr.null")
        );
    }
    if method == "view" {
        if len(params) != 1 or isinstance(params[0], uni.KWPair) {
            self.ctx.emit(E5092, node_override=nd, kind="call", name="ptr.view(n)");
            return (True, None);
        }
        addr = self._codegen_expr(recv);
        count = self._codegen_expr(params[0]);
        if addr is None or count is None {
            return (True, None);
        }
        count = self._coerce_type(count, i64);
        b = self.builder;
        negative = b.icmp_signed("<", count, ir.Constant(i64, 0), name="c.view.nneg");
        self._emit_runtime_raise(
            negative, "ValueError", "PtrView length must not be negative"
        );
        is_null = b.icmp_unsigned("==", addr, ir.Constant(i64, 0), name="c.view.null");
        some = b.icmp_signed(">", count, ir.Constant(i64, 0), name="c.view.some");
        self._emit_runtime_raise(
            b.and_(is_null, some, name="c.view.nullsome"),
            "ValueError",
            "cannot view elements of a null pointer"
        );
        empty: ir.Value = ir.Constant(self._ptr_view_type(), None);
        with_addr = b.insert_value(empty, addr, 0, name="c.view.addr");
        return (True, b.insert_value(with_addr, count, 1, name="c.view.n"));
    }
    return (False, None);
}

impl NaIRGenPass._codegen_pin(arg: uni.Expr) -> (ir.Value | None) {
    elem = arg?.type;
    sname = self._foreign_struct_name_of_type(elem);
    val = self._codegen_expr(arg);
    if val is None {
        return None;
    }
    if sname is not None {
        box = self._clib_alloc_box(sname);
        self._foreign_store_bytes(box, val, sname);
        self._mark_owned(box);
        return box;
    }
    box_name = self._pinned_scalar_box(elem);
    if box_name is None {
        return None;
    }
    box = self._clib_alloc_box(box_name);
    self._c_store_scalar(val, self._pinned_value_slot(box), elem);
    self._mark_owned(box);
    return box;
}

impl NaIRGenPass._clib_param_info(p: uni.ParamVar) -> dict[str, any] {
    import from jaclang.compiler.frontend.constant { is_borrow_kind }
    ptype = p.type;
    optional = False;
    if isinstance(ptype, UnionType) {
        members = [
            m
            for m in (ptype.types or [])
            if not (
                isinstance(m, ClassType) and m.shared.class_name in ("NoneType", "None")
            )
        ];
        if len(members) == 1 and len(members) < len(ptype.types or []) {
            ptype = members[0];
            optional = True;
        }
    }
    borrowed = p.type_tag is not None and is_borrow_kind(p.type_tag.ownership);
    if is_pinned_type(ptype) {
        return {"borrow": "pinned", "optional": optional};
    }
    if is_ptr_type(ptype) {
        if borrowed {
            return {
                "borrow": "scalar",
                "elem": ptype,
                "llt": ir.IntType(64),
                "optional": optional
            };
        }
        return {"cptr": True, "optional": optional};
    }
    if not borrowed {
        return {};
    }
    if self._foreign_struct_name_of_type(ptype) is not None {
        return {"borrow": "struct", "optional": optional};
    }
    llt = self._c_scalar_llvm(ptype);
    if llt is None {
        return {};
    }
    return {"borrow": "scalar", "elem": ptype, "llt": llt, "optional": optional};
}

impl NaIRGenPass._clib_ret_is_cptr(sig: uni.FuncSignature) -> bool {
    ret = sig.return_type;
    return ret is not None and is_ptr_type(self._c_decl_type_of(ret));
}

impl NaIRGenPass._c_decl_type_of(type_expr: uni.UniNode) -> any {
    t = type_expr?.type;
    if isinstance(t, ClassType) and not t.is_instance() {
        return t.clone_as_instance();
    }
    return t;
}

impl NaIRGenPass._clib_place_ptr(expr: uni.Expr) -> (ir.Value | None) {
    import from jaclang.compiler.frontend.constant { is_borrow_kind }
    if isinstance(expr, uni.UnaryExpr) and is_borrow_kind(expr.ownership) {
        expr = expr.operand;
    }
    while isinstance(expr, uni.AtomUnit) and isinstance(expr.value, uni.Expr) {
        expr = expr.value;
    }
    if isinstance(expr, uni.Name) {
        slot = self.local_vars.get(expr.sym_name);
        if slot is None {
            slot = self.global_vars.get(expr.sym_name);
        }
        return slot;
    }
    if isinstance(expr, uni.AtomTrailer) {
        got = self._c_view_elem_of(expr);
        if got is not None {
            return got[0];
        }
        if expr.is_attr
            and is_pinned_type(expr.target?.type)
            and self._get_name(expr.right) == "value" {
            box = self._codegen_expr(expr.target);
            return self._pinned_value_slot(box) if box is not None else None;
        }
        return self._codegen_place_ptr(expr, allow_inline=True);
    }
    return None;
}

impl NaIRGenPass._codegen_clib_args(
    nd: uni.FuncCall, func_name: str, copybacks: list[tuple[ir.Value, ir.Value, any]]
) -> (list[ir.Value] | None) {
    plan = self.clib_fn_abi.get(func_name);
    if plan is None {
        return None;
    }
    params: list[uni.Expr | uni.KWPair] = list(nd.params or []);
    param_plans = plan["params"];
    variadic = self.clib_extern_fns[func_name].function_type.var_arg;
    if len(params) < len(param_plans)
        or (len(params) > len(param_plans) and not variadic) {
        return None;
    }
    for arg in params {
        if isinstance(arg, uni.KWPair)
            or (
                isinstance(arg, uni.UnaryExpr)
                and isinstance(arg.op, uni.Token)
                and arg.op.name in (Tok.STAR_MUL, Tok.STAR_POW)
            ) {
            return None;
        }
    }
    i8p = ir.IntType(8).as_pointer();
    out: list[ir.Value] = [];
    for (i, pp) in enumerate(param_plans) {
        arg = params[i];
        info = pp.get("c_arg") or {};
        if isinstance(arg, uni.Null) and (info.get("optional") or info.get("cptr")) {
            out.append(ir.Constant(i8p, None));
            continue;
        }
        if info.get("borrow") != "scalar" {
            val = self._codegen_expr(arg);
            if val is None {
                return out;
            }
            out.append(val);
            continue;
        }
        c_llt: ir.Type = info["llt"];
        if not isinstance(arg, uni.Expr) {
            return out;
        }
        slot = self._clib_place_ptr(arg);
        if slot is not None
            and isinstance(slot.type, ir.PointerType)
            and slot.type.pointee == c_llt {
            out.append(self.builder.bitcast(slot, i8p, name=f"clib.borrow.{i}"));
            continue;
        }
        tmp = self._entry_alloca(c_llt, f"clib.spill.{i}");
        if slot is not None and isinstance(slot.type, ir.PointerType) {
            self._c_store_scalar(
                self.builder.load(slot, name=f"clib.spill.in.{i}"), tmp, info["elem"]
            );
            copybacks.append((tmp, slot, info["elem"]));
        } else {
            val = self._codegen_expr(arg);
            if val is None {
                return out;
            }
            self._c_store_scalar(val, tmp, info["elem"]);
        }
        out.append(self.builder.bitcast(tmp, i8p, name=f"clib.spill.arg.{i}"));
    }
    for arg in params[len(param_plans):] {
        extra = self._c_vararg(arg) if isinstance(arg, uni.Expr) else None;
        if extra is None {
            return None;
        }
        out.append(extra);
    }
    return out;
}

impl NaIRGenPass._c_vararg(arg: uni.Expr) -> (ir.Value | None) {
    import from jaclang.compiler.frontend.constant { is_borrow_kind }
    if isinstance(arg, uni.UnaryExpr) and is_borrow_kind(arg.ownership) {
        return self._c_vararg_address(arg);
    }
    val = self._codegen_expr(arg);
    return self._c_vararg_value(val, arg) if val is not None else None;
}

impl NaIRGenPass._c_vararg_address(arg: uni.UnaryExpr) -> (ir.Value | None) {
    slot = self._clib_place_ptr(arg);
    if slot is not None and isinstance(slot.type, ir.PointerType) {
        pointee = slot.type.pointee;
        if (isinstance(pointee, ir.IntType) and pointee.width in (8, 16, 32, 64))
            or isinstance(pointee, (ir.FloatType, ir.DoubleType, ir.PointerType)) {
            return self.builder.bitcast(
                slot, ir.IntType(8).as_pointer(), name="c.va.borrow"
            );
        }
    }
    self.ctx.emit(
        E5092,
        node_override=arg,
        kind="C variadic argument",
        name=str(arg.type),
        help_text="A borrowed C variadic argument (`&mut x`) is a variable of a C scalar or pointer type; the callee receives its address."
    );
    return None;
}

impl NaIRGenPass._c_vararg_value(val: ir.Value, arg: uni.Expr) -> (ir.Value | None) {
    import from jaclang.compiler.frontend.constant { is_borrow_kind }
    if isinstance(arg, uni.UnaryExpr) and is_borrow_kind(arg.ownership) {
        return self._c_vararg_address(arg);
    }
    b = self.builder;
    i32 = ir.IntType(32);
    if isinstance(val.type, ir.IntType) {
        if val.type.width >= 32 {
            return val;
        }
        if val.type.width == 1 or self._is_unsigned_node(arg) {
            return b.zext(val, i32, name="c.va.zext");
        }
        return b.sext(val, i32, name="c.va.sext");
    }
    if isinstance(val.type, ir.FloatType) {
        return b.fpext(val, ir.DoubleType(), name="c.va.fpext");
    }
    if isinstance(val.type, ir.DoubleType) {
        return val;
    }
    if self._type_key_of(arg) == "str" {
        return self._membrane_str_out(b, self._str_norm(val));
    }
    if self._is_bytes_value(val) {
        return self._bytes_data_ptr(val);
    }
    self.ctx.emit(
        E5092,
        node_override=arg,
        kind="C variadic argument",
        name=str(arg.type),
        help_text="A C variadic argument is a C scalar, `ptr`, `str` or `bytes`; a Jac object has no C representation to pass."
    );
    return None;
}

impl NaIRGenPass._clib_pointer_arg(val: ir.Value) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    b = self.builder;
    if val.type == i8p {
        return val;
    }
    payload = self._opt_payload_of(val.type);
    if payload is not None {
        tag = b.extract_value(val, 0, name="clib.opt.tag");
        inner = b.extract_value(val, 1, name="clib.opt.val");
        present = b.icmp_unsigned(
            "!=", tag, ir.Constant(tag.type, 0), name="clib.opt.some"
        );
        addr = self._clib_pointer_arg(inner);
        return b.select(present, addr, ir.Constant(i8p, None), name="clib.opt.addr");
    }
    if isinstance(val.type, ir.IntType) {
        return b.inttoptr(val, i8p, name="clib.cptr");
    }
    if isinstance(val.type, ir.PointerType) {
        return b.bitcast(val, i8p, name="clib.addr");
    }
    return self._clib_reinterpret(val, i8p, name="clib.addr");
}

impl NaIRGenPass._c_ptr_elem_llvm(ptr_type: any) -> (ir.Type | None) {
    info = self._c_elem_info(c_type_arg(ptr_type));
    if info is None {
        return None;
    }
    elem = info[0];
    if isinstance(elem, ir.IdentifiedStructType) and elem.is_opaque {
        return None;
    }
    return elem;
}

impl NaIRGenPass._c_ptr_step(
    addr: ir.Value, delta: ir.Value, ptr_type: any, backward: bool
) -> ir.Value {
    i64 = ir.IntType(64);
    b = self.builder;
    count = self._coerce_type(delta, i64);
    if backward {
        count = b.neg(count, name="c.ptr.back");
    }
    elem = self._c_ptr_elem_llvm(ptr_type) or ir.IntType(8);
    typed = b.inttoptr(addr, elem.as_pointer(), name="c.ptr.typed");
    return b.ptrtoint(b.gep(typed, [count], name="c.ptr.step"), i64, name="c.ptr");
}

impl NaIRGenPass._codegen_c_ptr_arith(
    nd: uni.BinaryExpr, op: str
) -> tuple[bool, (ir.Value | None)] {
    if op not in (Tok.PLUS, Tok.MINUS) or not is_ptr_type(nd.left?.type) {
        return (False, None);
    }
    left = self._codegen_expr(nd.left);
    right = self._codegen_expr(nd.right);
    if left is None or right is None {
        return (True, None);
    }
    if not (op == Tok.MINUS and is_ptr_type(nd.right?.type)) {
        return (True, self._c_ptr_step(left, right, nd.left.type, op == Tok.MINUS));
    }
    b = self.builder;
    span = b.sub(left, right, name="c.ptr.span");
    elem = self._c_ptr_elem_llvm(nd.left.type);
    if elem is None {
        return (True, span);
    }
    return (True, b.sdiv(span, self._sizeof_llvm(elem), name="c.ptr.dist"));
}

impl NaIRGenPass._c_ptr_aug(
    current: ir.Value, rhs: ir.Value, aug_op: str, target_type: any
) -> tuple[bool, (ir.Value | None)] {
    if not is_ptr_type(target_type) {
        return (False, None);
    }
    if aug_op not in ("+=", "-=") {
        return (True, None);
    }
    return (True, self._c_ptr_step(current, rhs, target_type, aug_op == "-="));
}

impl NaIRGenPass._declare_clib_global(
    assign: uni.Assignment, lib: (str | None), owner: uni.Module
) -> None {
    target = assign.target[0] if assign.target else None;
    if not isinstance(target, uni.Name) or target.sym_name in self.clib_globals {
        return;
    }
    name = target.sym_name;
    ctype = self._c_decl_type_of(target);
    sname = self._foreign_struct_name_of_type(ctype);
    llt = self._c_scalar_llvm(ctype);
    elem = c_array_elem(ctype);
    elem_info = self._c_elem_info(elem) if elem is not None else None;
    if elem_info is not None {
        count = 0;
        if owner is self.module and isinstance(assign.value, uni.ListVal) {
            count = len(assign.value.values);
        } elif owner is self.module
            and (data := c_bytes_literal(assign.value)) is not None
            and (shape := c_bytes_elem_shape(elem)) is not None {
            count = len(data) // shape[0];
        }
        llt = ir.ArrayType(elem_info[0], count);
    } elif llt is None {
        llt = self.struct_types[sname] if sname is not None else ir.IntType(8);
    }
    gv = self.llvm_module.globals.get(name);
    if not isinstance(gv, ir.GlobalVariable) {
        gv = ir.GlobalVariable(self.llvm_module, llt, name=name);
        gv.linkage = "external";
    }
    if assign.value is not None and owner is self.module {
        decl = assign.parent;
        private = isinstance(decl, uni.GlobalVars)
            and decl.access is not None
            and decl.access.tag.name == Tok.KW_PRIV;
        gv.linkage = "internal" if private else "";
        gv.initializer = ir.Constant(llt, None);
        self._clib_data_inits.append((gv, assign.value, ctype));
        if not private {
            self._record_export(name, name, "global", True);
            if self.module?.gen and name not in self.module.gen._exported_symbols {
                self.module.gen._exported_symbols.append(name);
            }
        }
    }
    self.clib_globals[name] = (gv, ctype);
    if lib is not None {
        self._clib_symbol_lib[name] = lib;
    }
    self.has_native_code = True;
}

impl NaIRGenPass._emit_clib_data_inits -> None {
    pending = self._clib_data_inits;
    self._clib_data_inits = [];
    for (gv, value, ctype) in pending {
        initializer = self._c_const_init(value, ctype, gv.value_type);
        if initializer is None {
            self.ctx.emit(
                E5092,
                node_override=value,
                kind="C data definition",
                name=gv.name,
                help_text="A C data definition is laid out at link time, so its initializer is a C constant: literals, `ptr[T]()`, `ptr[u8](\"text\")`, `addressof(symbol)`, named functions for callback fields, constructors of foreign structs made of these, and for an integer array a bytes literal of its little-endian elements."
            );
            continue;
        }
        gv.initializer = initializer;
    }
}

impl NaIRGenPass._c_string_global(text: str) -> ir.GlobalVariable {
    found = self._c_strings.get(text);
    if found is not None {
        return found;
    }
    data = (text + "\0").encode("utf-8");
    array_type = ir.ArrayType(ir.IntType(8), len(data));
    gv = ir.GlobalVariable(
        self.llvm_module, array_type, name=f".cstr.{len(self._c_strings)}"
    );
    gv.linkage = "private";
    gv.global_constant = True;
    gv.initializer = ir.Constant(array_type, bytearray(data));
    self._c_strings[text] = gv;
    return gv;
}

impl NaIRGenPass._c_const_init(
    expr: uni.Expr, ctype: any, llt: ir.Type
) -> (ir.Constant | None) {
    while isinstance(expr, uni.AtomUnit) and isinstance(expr.value, uni.Expr) {
        expr = expr.value;
    }
    if isinstance(expr, uni.Null) {
        return ir.Constant(llt, None);
    }
    elem = c_array_elem(ctype);
    if elem is not None and isinstance(llt, ir.ArrayType) {
        data = c_bytes_literal(expr);
        if data is not None {
            shape = c_bytes_elem_shape(elem);
            if shape is None or len(data) != shape[0] * llt.count {
                return None;
            }
            if shape[0] == 1 {
                return ir.Constant(llt, bytearray(data));
            }
            return ir.Constant(llt, c_bytes_array_values(data, shape[0], shape[1]));
        }
        if not isinstance(expr, uni.ListVal) {
            return None;
        }
        items: list[ir.Constant] = [];
        for item in expr.values {
            value = self._c_const_init(item, elem, llt.element)
                if isinstance(item, uni.Expr)
                else None;
            if value is None {
                return None;
            }
            items.append(value);
        }
        return ir.Constant(llt, items);
    }
    sname = self._foreign_struct_name_of_type(ctype);
    if sname is not None {
        return self._c_const_struct(expr, sname);
    }
    if isinstance(llt, ir.PointerType) and isinstance(llt.pointee, ir.FunctionType) {
        target = self.func_symtab.get(expr.sym_name)
            if isinstance(expr, uni.Name)
            else None;
        if not isinstance(target, ir.Function) {
            return None;
        }
        if isinstance(expr, uni.Name) and expr.sym_name in self._clib_exports {
            return self._clib_exports[expr.sym_name].bitcast(llt) as ir.Constant;
        }
        if target.function_type != llt.pointee or not self._is_kernel_unit() {
            target = self._emit_clib_c_trampoline(target, llt);
        }
        return target.bitcast(llt) as ir.Constant;
    }
    if is_ptr_type(ctype) {
        return self._c_const_address(expr);
    }
    return self._c_const_scalar(expr, llt);
}

impl NaIRGenPass._c_const_scalar(expr: uni.Expr, llt: ir.Type) -> (ir.Constant | None) {
    (ok, value) = c_scalar_constant(expr);
    if not ok or not isinstance(value, (bool, int, float)) {
        return None;
    }
    if isinstance(llt, ir.IntType) {
        return ir.Constant(llt, int(value));
    }
    return ir.Constant(llt, float(value));
}

impl NaIRGenPass._c_const_struct(expr: uni.Expr, sname: str) -> (ir.Constant | None) {
    if not isinstance(expr, uni.FuncCall) {
        return None;
    }
    arch = foreign_struct_of_type(expr.type);
    if arch is None or arch.name is None or arch.name.value != sname {
        return None;
    }
    fields: list[uni.HasVar] = arch.get_has_vars();
    given: dict[str, uni.Expr] = {};
    for (i, param) in enumerate(expr.params or []) {
        if isinstance(param, uni.KWPair) {
            if isinstance(param.key, uni.Name) {
                given[param.key.sym_name] = param.value;
            }
        } elif i < len(fields) {
            given[fields[i].name.sym_name] = param;
        }
    }
    struct_type = self.struct_types[sname];
    values: list[ir.Constant] = [];
    for (i, field) in enumerate(fields) {
        elem = struct_type.elements[i];
        arg = given.get(field.name.sym_name);
        if arg is None {
            values.append(ir.Constant(elem, None));
            continue;
        }
        value = self._c_const_init(arg, self._c_decl_type_of(field), elem);
        if value is None {
            return None;
        }
        values.append(value);
    }
    return ir.Constant(struct_type, values);
}

impl NaIRGenPass._c_const_address(expr: uni.Expr) -> (ir.Constant | None) {
    i64 = ir.IntType(64);
    if isinstance(expr, uni.FuncCall) {
        params = list(expr.params or []);
        if is_builtin_addressof_call(expr) {
            symbol = params[0] if len(params) == 1 else None;
            found = self.clib_globals.get(symbol.sym_name)
                if isinstance(symbol, uni.Name)
                    and clib_global_of_symbol(symbol.sym) is not None
                else None;
            return found[0].ptrtoint(i64) as ir.Constant if found is not None else None;
        }
        callee_type = expr.target.type;
        if is_ptr_type(callee_type)
            and callee_type is not None
            and not callee_type.is_instance() {
            if not params {
                return ir.Constant(i64, 0);
            }
            arg = params[0];
            text = c_string_literal(arg) if len(params) == 1 else None;
            if text is not None {
                return self._c_string_global(text).ptrtoint(i64) as ir.Constant;
            }
            return self._c_const_scalar(arg, i64) if len(params) == 1 else None;
        }
        return None;
    }
    return self._c_const_scalar(expr, i64);
}

impl NaIRGenPass._clib_global_of(
    nd: uni.Name
) -> (tuple[ir.GlobalVariable, any] | None) {
    c_global = self.clib_globals.get(nd.sym_name);
    if c_global is None or nd.sym_name in self.local_vars {
        return None;
    }
    if clib_global_of_symbol(nd.sym) is None {
        return None;
    }
    return c_global;
}

impl NaIRGenPass._c_global_store(
    target: uni.Name, value: ir.Value, nd: uni.Assignment
) -> None {
    c_global = self._clib_global_of(target);
    if c_global is None {
        return;
    }
    (slot, ctype) = c_global;
    if self._c_scalar_llvm(ctype) is None {
        self.ctx.emit(
            E5092, node_override=target, kind="assignment", name="C data object"
        );
        return;
    }
    if nd.aug_op is not None {
        current = self._c_load_scalar(slot, ctype, f"c.glob.{target.sym_name}.cur");
        updated = self._apply_scalar_aug_op(
            current,
            value,
            nd.aug_op.value,
            nd.value,
            unsigned=self._is_unsigned_node(target),
            checked=self._is_sized_node(target) or self._is_sized_node(nd.value),
            target_type=ctype
        );
        if updated is None {
            self.ctx.emit(
                E5092,
                node_override=target,
                kind="augmented assignment",
                name="C data symbol"
            );
            return;
        }
        value = updated;
    }
    self._c_store_scalar(value, slot, ctype);
}

impl NaIRGenPass._va_abi -> str {
    triple = str(self.llvm_module.triple or "");
    if "x86_64" in triple {
        return "slots" if "windows" in triple else "sysv64";
    }
    if "aarch64" in triple or "arm64" in triple {
        return "slots"
            if ("apple" in triple or "darwin" in triple or "windows" in triple)
            else "aapcs64";
    }
    return "";
}

impl NaIRGenPass._va_storage_type(abi: str) -> ir.Type {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    if abi == "sysv64" {
        return ir.LiteralStructType([i32, i32, i8p, i8p]);
    }
    if abi == "aapcs64" {
        return ir.LiteralStructType([i8p, i8p, i8p, i32, i32]);
    }
    return i8p;
}

impl NaIRGenPass._c_va_start(nd: uni.UniNode) -> (ir.Value | None) {
    abi = self._va_abi();
    if not abi {
        self.ctx.emit(
            E5092,
            node_override=nd,
            kind="C variadic function",
            name=str(self.llvm_module.triple),
            help_text="C variadic functions are defined for x86_64 and aarch64 targets."
        );
        return None;
    }
    i8p = ir.IntType(8).as_pointer();
    storage = self._entry_alloca(self._va_storage_type(abi), "c.va.storage");
    start = self.llvm_module.globals.get("llvm.va_start");
    if not isinstance(start, ir.Function) {
        start = ir.Function(
            self.llvm_module,
            ir.FunctionType(ir.VoidType(), [i8p]),
            name="llvm.va_start"
        );
    }
    self.builder.call(start, [self.builder.bitcast(storage, i8p, name="c.va.raw")]);
    if abi == "slots" {
        return self.builder.ptrtoint(
            self.builder.load(storage, name="c.va.cursor"), ir.IntType(64), name="c.va"
        );
    }
    return self.builder.ptrtoint(storage, ir.IntType(64), name="c.va");
}

impl NaIRGenPass._c_va_arg(nd: uni.FuncCall, recv: uni.Expr) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    b = self.builder;
    want = self._c_scalar_llvm(nd.type);
    slot = self._clib_place_ptr(recv);
    abi = self._va_abi();
    if want is None or slot is None or not abi {
        self.ctx.emit(
            E5092,
            node_override=nd,
            kind="call",
            name="VaList.arg(T)",
            help_text="`args.arg(T)` reads the next C variadic argument into a local VaList variable; T is a sized scalar, `int`, `float`, `bool` or a `ptr`."
        );
        return None;
    }
    floating = isinstance(want, (ir.FloatType, ir.DoubleType));
    word: ir.Type = ir.DoubleType() if floating else i64;
    value = b.load(slot, name="c.va.value");
    addr: ir.Value;
    if abi == "slots" {
        cursor = b.inttoptr(value, i8.as_pointer(), name="c.va.cursor");
        addr = cursor;
        b.store(
            b.ptrtoint(b.gep(cursor, [ir.Constant(i64, 8)]), i64, name="c.va.next"),
            slot
        );
    } else {
        state = b.inttoptr(
            value, self._va_storage_type(abi).as_pointer(), name="c.va.state"
        );
        zero = ir.Constant(i32, 0);
        if abi == "sysv64" {
            limit = 160 if floating else 40;
            step = 16 if floating else 8;
            offset_slot = b.gep(state, [zero, ir.Constant(i32, 1 if floating else 0)]);
            overflow_slot = b.gep(state, [zero, ir.Constant(i32, 2)]);
            saved = b.load(b.gep(state, [zero, ir.Constant(i32, 3)]), name="c.va.save");
            offset = b.load(offset_slot, name="c.va.offs");
            in_reg = b.icmp_signed(
                "<=", offset, ir.Constant(i32, limit), name="c.va.inreg"
            );
            reg_addr = b.gep(saved, [b.sext(offset, i64)]);
            b.store(
                b.select(in_reg, b.add(offset, ir.Constant(i32, step)), offset),
                offset_slot
            );
        } else {
            step = 16 if floating else 8;
            offset_slot = b.gep(state, [zero, ir.Constant(i32, 4 if floating else 3)]);
            overflow_slot = b.gep(state, [zero, ir.Constant(i32, 0)]);
            top = b.load(
                b.gep(state, [zero, ir.Constant(i32, 2 if floating else 1)]),
                name="c.va.top"
            );
            offset = b.load(offset_slot, name="c.va.offs");
            spilled = b.icmp_signed(
                ">=", offset, ir.Constant(i32, 0), name="c.va.spilled"
            );
            advanced = b.add(offset, ir.Constant(i32, step), name="c.va.adv");
            b.store(b.select(spilled, offset, advanced), offset_slot);
            fits = b.icmp_signed("<=", advanced, ir.Constant(i32, 0), name="c.va.fits");
            in_reg = b.and_(b.not_(spilled), fits, name="c.va.inreg");
            reg_addr = b.gep(top, [b.sext(offset, i64)]);
        }
        overflow = b.load(overflow_slot, name="c.va.stack");
        b.store(
            b.select(in_reg, overflow, b.gep(overflow, [ir.Constant(i64, 8)])),
            overflow_slot
        );
        addr = b.select(in_reg, reg_addr, overflow, name="c.va.addr");
    }
    raw = b.load(b.bitcast(addr, word.as_pointer()), name="c.va.raw");
    if floating {
        return raw if want == word else b.fptrunc(raw, want, name="c.va.float");
    }
    if isinstance(want, ir.IntType) and want.width < 64 {
        raw = b.trunc(raw, want, name="c.va.narrow");
    }
    if isinstance(nd.type, ClassType) and nd.type.shared.class_name == "bool" {
        return b.icmp_unsigned("!=", raw, ir.Constant(raw.type, 0), name="c.va.bool");
    }
    lowered = self._lower_type(nd.type);
    return self._coerce_type(raw, lowered)
        if lowered is not None and lowered != raw.type
        else raw;
}
