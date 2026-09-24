import from jaclang.compiler.c_interop {
    c_builtin_kind,
    c_type_arg,
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
            return {"borrow": "scalar", "elem": ptype, "llt": ir.IntType(64)};
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
    return {"borrow": "scalar", "elem": ptype, "llt": llt};
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
    if len(params) != len(param_plans) {
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
    return out;
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
