"""Tuple codegen and unpacking."""
"""Generate tuple value: (a, b, c) -> struct with fields."""
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
    # Allocate tuple struct on heap using GC_malloc
    i8p = ir.IntType(8).as_pointer();
    gc_malloc = self._get_or_declare_extern("GC_malloc", i8p, [ir.IntType(64)]);
    size = ir.Constant(ir.IntType(64), self._get_struct_size(struct_type));
    raw_ptr = self.builder.call(gc_malloc, [size], name="tuple.raw");
    tuple_ptr = self.builder.bitcast(
        raw_ptr, struct_type.as_pointer(), name="tuple.ptr"
    );
    # Store each element
    for (i, val) in enumerate(elem_vals) {
        field_ptr = self.builder.gep(
            tuple_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), i)],
            name=f"tuple.{i}.ptr"
        );
        self.builder.store(val, field_ptr);
    }
    return tuple_ptr;
}

"""Unpack a tuple into multiple variables."""
impl NaIRGenPass._codegen_tuple_unpack(
    targets: list, tuple_val: ir.Value, tuple_node: (object | None)
) -> None {
    if not isinstance(tuple_val.type, ir.PointerType) {
        return;
    }
    # Get the struct type from the pointer
    struct_type = tuple_val.type.pointee;
    if not isinstance(struct_type, ir.LiteralStructType) {
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
        # GEP to get element pointer
        elem_ptr = self.builder.gep(
            tuple_val,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), i)],
            name=f"unpack.{i}.ptr"
        );
        elem_val = self.builder.load(elem_ptr, name=f"unpack.{i}");
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

"""Index into a tuple struct: tuple[i] -> element value."""
impl NaIRGenPass._codegen_tuple_index(
    tuple_val: ir.Value, idx_val: ir.Value, struct_type: ir.LiteralStructType
) -> (ir.Value | None) {
    # Get index as constant integer
    idx: (int | None) = None;
    if isinstance(idx_val, ir.Constant) and isinstance(idx_val.type, ir.IntType) {
        idx = idx_val.constant;
    }
    if idx is None {
        # Dynamic indexing not supported for tuples - try to extract from name
        return None;
    }
    if idx < 0 or idx >= len(struct_type.elements) {
        return None;
    }
    # GEP to get element pointer
    elem_ptr = self.builder.gep(
        tuple_val,
        [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
        name=f"tuple.idx.{idx}.ptr"
    );
    # Load and return the element
    return self.builder.load(elem_ptr, name=f"tuple.idx.{idx}");
}
