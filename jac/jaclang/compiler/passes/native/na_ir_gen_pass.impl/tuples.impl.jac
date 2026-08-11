impl NaIRGenPass._codegen_tuple_val(nd: uni.TupleVal) -> (ir.Value | None) {
    if not nd.values {
        return None;
    }

    elem_vals: list[ir.Value] = [];
    elem_types: list[ir.Type] = [];
    elem_owned: list[bool] = [];

    _in_return = False;
    _anc = nd.parent;
    while _anc is not None {
        if isinstance(_anc, uni.ReturnStmt) {
            _in_return = True;
            break;
        }
        if not isinstance(_anc, uni.TupleVal) {
            break;
        }
        _anc = _anc.parent;
    }
    _ret_direct = isinstance(nd.parent, uni.ReturnStmt);
    for val in nd.values {
        v = self._codegen_expr(val);
        if v is None {
            return None;
        }
        v = self._str_norm(v);

        _owns = self._is_owned(v);
        if _in_return and isinstance(v.type, ir.PointerType) and not _owns {
            is_named_local = isinstance(val, uni.Name)
                and val.sym_name in self.local_vars
                and val.sym_name not in self.param_vars;
            if not is_named_local {
                self._emit_rc_retain(v, op="return_tuple_elem");
                self._mark_owned(v);
                _owns = True;
            } elif _ret_direct {
                _owns = True;
            }
        }
        elem_vals.append(v);
        elem_types.append(v.type);
        elem_owned.append(_owns);
    }

    n = len(elem_types);
    tuple_key = f"Tuple.{n}." + ".".join([str(t) for t in elem_types]);
    if tuple_key not in self.tuple_types {
        struct_type = ir.LiteralStructType(elem_types);
        self.tuple_types[tuple_key] = struct_type;
    }
    struct_type = self.tuple_types[tuple_key];

    val = ir.Constant(struct_type, ir.Undefined);
    for (i, elem) in enumerate(elem_vals) {
        val = self.builder.insert_value(val, elem, i, name=f"tuple.{i}");
    }
    val.na_tuple_owned = elem_owned;
    return val;
}

impl NaIRGenPass._infer_unpack_struct_ptr(nd: object) -> (ir.Type | None) {
    list_name: (str | None) = None;
    list_expr: (object | None) = None;
    if isinstance(nd, uni.FuncCall) {
        tgt = nd.target;
        if isinstance(tgt, uni.AtomTrailer) and tgt.is_attr {
            list_name = self._get_name(tgt.target);
            list_expr = tgt.target;
        }
    } elif isinstance(nd, uni.AtomTrailer) and not nd.is_attr and nd.right?.slices {
        list_name = self._get_name(nd.target);
        list_expr = nd.target;
    }
    if list_name is None {
        return None;
    }

    cast = self._list_elem_llvm_of(list_expr);
    if cast is not None and isinstance(cast, ir.PointerType) {
        return cast;
    }

    return self.var_list_elem_struct.get(list_name);
}

impl NaIRGenPass._codegen_tuple_unpack(
    targets: list, tuple_val: ir.Value, tuple_node: (object | None)
) -> bool {
    _elem_owned = tuple_val?.na_tuple_owned;
    _tu_opt = self._opt_payload_of(tuple_val.type);
    if _tu_opt is not None {
        tuple_val = self._coerce_type(tuple_val, _tu_opt);
    }
    _orig_tv = tuple_val;
    struct_type: (ir.LiteralStructType | None) = None;
    is_value = False;
    if isinstance(tuple_val.type, ir.LiteralStructType) {
        struct_type = tuple_val.type;
        is_value = True;
    } elif isinstance(tuple_val.type, ir.PointerType)
        and isinstance(tuple_val.type.pointee, ir.LiteralStructType) {
        struct_type = tuple_val.type.pointee;
    }

    if struct_type is None
        and isinstance(tuple_val.type, ir.PointerType)
        and tuple_node is not None {
        cast_ptr_type = self._infer_unpack_struct_ptr(tuple_node);
        if cast_ptr_type is not None
            and isinstance(cast_ptr_type, ir.PointerType)
            and isinstance(cast_ptr_type.pointee, ir.LiteralStructType) {
            tuple_val = self.builder.bitcast(
                tuple_val, cast_ptr_type, name="unpack.cast"
            );
            struct_type = cast_ptr_type.pointee;
        }
    }
    if struct_type is None {
        return False;
    }

    rc_ok = (not is_value) or not self._nogc_headerless();
    pending_old: list = [];
    for (i, target) in enumerate(targets) {
        if i >= len(struct_type.elements) {
            break;
        }
        var_name = self._get_name(target);
        if var_name is None {
            continue;
        }
        if is_value {
            elem_val = self.builder.extract_value(tuple_val, i, name=f"unpack.{i}");
        } else {
            elem_ptr = self.builder.gep(
                tuple_val,
                [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), i)],
                name=f"unpack.{i}.ptr"
            );
            elem_val = self.builder.load(elem_ptr, name=f"unpack.{i}");
        }

        moved = is_value
            and _elem_owned is not None
            and i < len(_elem_owned)
            and _elem_owned[i];
        if var_name in self.local_vars {
            alloca = self.local_vars[var_name];
            stored = self._coerce_type(elem_val, alloca.type.pointee);
            new_ref = self._rc_slot_ref(stored) if rc_ok else None;
            if new_ref is not None {
                if not moved {
                    self._emit_rc_retain(new_ref, op="unpack", loc="");
                }
                old_ref = self._rc_slot_ref(
                    self.builder.load(alloca, name=f"unpack.{i}.old")
                );
                if old_ref is not None {
                    pending_old.append(old_ref);
                }
            }
            self.builder.store(stored, alloca);
        } else {
            alloca = self._entry_alloca(elem_val.type, var_name);
            new_ref = self._rc_slot_ref(elem_val) if rc_ok else None;
            if new_ref is not None {
                _saved_block = self.builder.block;
                self.builder.position_after(alloca);
                self.builder.store(ir.Constant(elem_val.type, None), alloca);
                self.builder.position_at_end(_saved_block);
                if not moved {
                    self._emit_rc_retain(new_ref, op="unpack", loc="");
                }
            }
            self.builder.store(elem_val, alloca);
            self.local_vars[var_name] = alloca;
        }
    }

    for old_val in pending_old {
        self._emit_rc_release_simple(old_val, op="unpack_old", loc="");
    }
    if (not is_value) and self._is_owned(_orig_tv) {
        self._emit_rc_release_simple(_orig_tv, op="unpack_box", loc="");
    }
    return True;
}

impl NaIRGenPass._get_struct_size(struct_type: ir.LiteralStructType) -> int {
    total: int = 0;
    for elem in struct_type.elements {
        if isinstance(elem, ir.IntType) {
            total += elem.width // 8;
        } elif isinstance(elem, ir.DoubleType) {
            total += 8;
        } elif isinstance(elem, ir.PointerType) {
            total += 8;
        } else {
            total += 8;
        }
    }
    return total if total > 0 else 8;
}

impl NaIRGenPass._sizeof_llvm(ty: ir.Type) -> ir.Value {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    null_ptr = ir.Constant(ty.as_pointer(), None);
    size_gep = self.builder.gep(null_ptr, [ir.Constant(i32, 1)], name="sizeof.gep");
    return self.builder.ptrtoint(size_gep, i64, name="sizeof");
}

impl NaIRGenPass._rc_slot_ref(val: ir.Value) -> (ir.Value | None) {
    if self?.jacval_type and val.type == self.jacval_type {
        return None;
    }
    if isinstance(val.type, ir.PointerType) {
        if isinstance(val.type.pointee, ir.FunctionType) {
            return None;
        }
        return val;
    }
    if self._opt_ptr_payload_of(val.type) is not None {
        return self.builder.extract_value(val, 1, name="rc.opt.pv");
    }
    return None;
}

impl NaIRGenPass._tuple_managed_fields(struct_type: ir.LiteralStructType) -> list {
    out: list = [];
    for (i, ety) in enumerate(struct_type.elements) {
        if self?.jacval_type and ety == self.jacval_type {
            continue;
        }
        if isinstance(ety, ir.PointerType) {
            if not isinstance(ety.pointee, ir.FunctionType) {
                out.append((i, False));
            }
        } elif self._opt_ptr_payload_of(ety) is not None {
            out.append((i, True));
        }
    }
    return out;
}

impl NaIRGenPass._box_value_tuple(val: ir.Value, loc: str = "") -> ir.Value {
    if not isinstance(val.type, ir.LiteralStructType) {
        return val;
    }

    _managed = self._tuple_managed_fields(val.type);
    _rc_box = (
        bool(_managed) and not self._nogc_headerless() and self._gc_mode() != "none"
    );
    if _rc_box {
        _owned = val?.na_tuple_owned;
        for (_bi, _b_opt) in _managed {
            if _owned is not None and _bi < len(_owned) and _owned[_bi] {
                continue;
            }
            _bfv = self.builder.extract_value(val, _bi, name=f"box.f{_bi}");
            if _b_opt {
                _bfv = self.builder.extract_value(_bfv, 1, name=f"box.f{_bi}.pv");
            }
            self._emit_rc_retain(_bfv, op="box_field", loc=loc);
        }
    }

    size = self._sizeof_llvm(val.type);

    _box_loc = val?.jac_loc or loc;
    raw = self._rc_call_with_ctx(
        self.rc_alloc_fn, [size], op="box", loc=_box_loc, name="tuple.box"
    );
    ptr = self.builder.bitcast(raw, val.type.as_pointer(), name="tuple.box.ptr");
    self.builder.store(val, ptr);

    self._mark_owned(ptr);

    self._emit_set_type_tag(self.builder, raw, "tuple");
    if _rc_box {
        self._emit_tuple_box_lifecycle(raw, val.type);
    }
    return ptr;
}

impl NaIRGenPass._coerce_tuple_to_struct(
    val: ir.Value, target_struct: ir.Type
) -> ir.Value {
    if not isinstance(val.type, ir.LiteralStructType)
        or not isinstance(target_struct, ir.LiteralStructType) {
        return val;
    }
    if val.type == target_struct
        or len(val.type.elements) != len(target_struct.elements) {
        return val;
    }
    out = ir.Constant(target_struct, ir.Undefined);
    for i in range(len(target_struct.elements)) {
        fld = self.builder.extract_value(val, i, name=f"tcoerce.{i}");
        tgt_ty = target_struct.elements[i];
        if fld.type != tgt_ty {
            fld = self._coerce_type(fld, tgt_ty);
        }
        out = self.builder.insert_value(out, fld, i, name=f"tcoerce.ins.{i}");
    }
    _tc_owned = val?.na_tuple_owned;
    if _tc_owned is not None {
        out.na_tuple_owned = _tc_owned;
    }
    return out;
}

impl NaIRGenPass._codegen_tuple_index(
    tuple_val: ir.Value, idx_val: ir.Value, struct_type: ir.LiteralStructType
) -> (ir.Value | None) {
    idx: (int | None) = None;
    if isinstance(idx_val, ir.Constant) and isinstance(idx_val.type, ir.IntType) {
        idx = idx_val.constant;
    }
    if idx is None {
        return None;
    }
    if idx < 0 or idx >= len(struct_type.elements) {
        return None;
    }

    if isinstance(tuple_val.type, ir.LiteralStructType) {
        return self.builder.extract_value(tuple_val, idx, name=f"tuple.idx.{idx}");
    }

    elem_ptr = self.builder.gep(
        tuple_val,
        [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
        name=f"tuple.idx.{idx}.ptr"
    );
    return self.builder.load(elem_ptr, name=f"tuple.idx.{idx}");
}
