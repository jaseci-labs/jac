"""Tuple codegen and unpacking."""
"""Generate tuple value: (a, b, c) -> struct value via insertvalue.

Returns an LLVM struct value (not a pointer). When the tuple needs to be
stored in a pointer-typed field, _coerce_type automatically boxes it via
rc_alloc. This eliminates heap allocation for purely local tuples.
"""
impl NaIRGenPass._codegen_tuple_val(nd: uni.TupleVal) -> (ir.Value | None) {
    if not nd.values {
        return None;
    }
    # Evaluate all elements
    elem_vals: list[ir.Value] = [];
    elem_types: list[ir.Type] = [];
    for val in nd.values {
        v = self._codegen_expr(val);
        if v is None {
            return None;
        }
        elem_vals.append(v);
        elem_types.append(v.type);
    }
    # Create a struct type for this tuple
    n = len(elem_types);
    tuple_key = f"Tuple.{n}." + ".".join([str(t) for t in elem_types]);
    if tuple_key not in self.tuple_types {
        struct_type = ir.LiteralStructType(elem_types);
        self.tuple_types[tuple_key] = struct_type;
    }
    struct_type = self.tuple_types[tuple_key];
    # Build value via insertvalue chain (no heap allocation)
    val = ir.Constant(struct_type, ir.Undefined);
    for (i, elem) in enumerate(elem_vals) {
        val = self.builder.insert_value(val, elem, i, name=f"tuple.{i}");
    }
    return val;
}

"""Unpack a tuple into multiple variables. Handles both value and pointer tuples."""
impl NaIRGenPass._codegen_tuple_unpack(
    targets: list, tuple_val: ir.Value, tuple_node: (object | None)
) -> None {
    # Determine struct type from value or pointer
    struct_type: (ir.LiteralStructType | None) = None;
    is_value = False;
    if isinstance(tuple_val.type, ir.LiteralStructType) {
        struct_type = tuple_val.type;
        is_value = True;
    } elif isinstance(tuple_val.type, ir.PointerType)
    and isinstance(tuple_val.type.pointee, ir.LiteralStructType) {
        struct_type = tuple_val.type.pointee;
    }
    if struct_type is None {
        return;
    }
    # Extract each element and assign to target
    for (i, target) in enumerate(targets) {
        if i >= len(struct_type.elements) {
            break;
        }
        var_name = self._get_name(target);
        if var_name is None {
            continue;
        }
        if is_value {
            # Value tuple: use extractvalue
            elem_val = self.builder.extract_value(tuple_val, i, name=f"unpack.{i}");
        } else {
            # Pointer tuple: GEP + load
            elem_ptr = self.builder.gep(
                tuple_val,
                [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), i)],
                name=f"unpack.{i}.ptr"
            );
            elem_val = self.builder.load(elem_ptr, name=f"unpack.{i}");
        }
        # Store in local variable
        if var_name in self.local_vars {
            alloca = self.local_vars[var_name];
            self.builder.store(elem_val, alloca);
        } else {
            alloca = self._entry_alloca(elem_val.type, var_name);
            self.builder.store(elem_val, alloca);
            self.local_vars[var_name] = alloca;
        }
    }
}

"""Helper: estimate struct size (simple approximation)."""
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
            total += 8;  # Default
        }
    }
    return total if total > 0 else 8;
}

"""Box a value tuple to a heap-allocated pointer (rc_alloc + store).

Returns the value unchanged if it's already a pointer. Use this when
a value tuple needs to be stored in a container or passed to a function
that expects a pointer.
"""
impl NaIRGenPass._box_value_tuple(val: ir.Value) -> ir.Value {
    if not isinstance(val.type, ir.LiteralStructType) {
        return val;
    }
    size = ir.Constant(ir.IntType(64), self._get_struct_size(val.type));
    raw = self.builder.call(self.rc_alloc_fn, [size], name="tuple.box");
    ptr = self.builder.bitcast(raw, val.type.as_pointer(), name="tuple.box.ptr");
    self.builder.store(val, ptr);
    return ptr;
}

"""Index into a tuple: tuple[i] -> element value. Handles both value and pointer tuples."""
impl NaIRGenPass._codegen_tuple_index(
    tuple_val: ir.Value, idx_val: ir.Value, struct_type: ir.LiteralStructType
) -> (ir.Value | None) {
    # Get index as constant integer
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
    # Value tuple: use extractvalue
    if isinstance(tuple_val.type, ir.LiteralStructType) {
        return self.builder.extract_value(tuple_val, idx, name=f"tuple.idx.{idx}");
    }
    # Pointer tuple: GEP + load
    elem_ptr = self.builder.gep(
        tuple_val,
        [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
        name=f"tuple.idx.{idx}.ptr"
    );
    return self.builder.load(elem_ptr, name=f"tuple.idx.{idx}");
}
