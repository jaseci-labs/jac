impl NaIRGenPass._codegen_tuple_val(nd: uni.TupleVal) -> (ir.Value | None) {
    if not nd.values {
        return None;
    }

    elem_vals: list[ir.Value] = [];
    elem_types: list[ir.Type] = [];

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
    for val in nd.values {
        v = self._codegen_expr(val);
        if v is None {
            return None;
        }

        if (
            _in_return and isinstance(v.type, ir.PointerType) and not self._is_owned(v)
        ) {
            is_named_local = isinstance(val, uni.Name)
            and val.sym_name in self.local_vars
            and val.sym_name not in self.param_vars;
            if not is_named_local {
                self._emit_rc_retain(v, op="return_tuple_elem");
                self._mark_owned(v);
            }
        }
        elem_vals.append(v);
        elem_types.append(v.type);
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

    retain_fields = not is_value and not self._is_owned(tuple_val);
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

        rc_field = retain_fields and isinstance(elem_val.type, ir.PointerType);
        if var_name in self.local_vars {
            alloca = self.local_vars[var_name];
            if rc_field and isinstance(alloca.type.pointee, ir.PointerType) {
                self._emit_rc_retain(elem_val, op="unpack", loc="");
                pending_old.append(self.builder.load(alloca, name=f"unpack.{i}.old"));
            }
            self.builder.store(elem_val, alloca);
        } else {
            alloca = self._entry_alloca(elem_val.type, var_name);
            if rc_field {
                _saved_block = self.builder.block;
                self.builder.position_after(alloca);
                self.builder.store(ir.Constant(elem_val.type, None), alloca);
                self.builder.position_at_end(_saved_block);
                self._emit_rc_retain(elem_val, op="unpack", loc="");
            }
            self.builder.store(elem_val, alloca);
            self.local_vars[var_name] = alloca;
        }
    }

    for old_val in pending_old {
        self._emit_rc_release_simple(old_val, op="unpack_old", loc="");
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

impl NaIRGenPass._box_value_tuple(val: ir.Value, loc: str = "") -> ir.Value {
    if not isinstance(val.type, ir.LiteralStructType) {
        return val;
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
