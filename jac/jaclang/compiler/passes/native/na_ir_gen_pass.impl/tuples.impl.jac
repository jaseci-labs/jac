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
        # In a `return (...)` context, a borrowed pointer element (a field load
        # such as `obj.field`, a container read, etc.) is owned by some local
        # that scope-exit will tear down — and the tuple box does not own its
        # elements. Retain it so it survives into the returned tuple. Named
        # locals are skipped: the return path nulls their alloca to transfer
        # their single ref into the tuple, and owned temporaries already hold a
        # ref that scope cleanup leaves alone.
        if (
            self._return_tuple_ctx
            and isinstance(v.type, ir.PointerType)
            and not self._is_owned(v)
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

"""Infer the pointer-to-struct LLVM type of a boxed tuple read from a list.

`nd` is the RHS of a tuple-unpack assignment — typically `lst.pop()`,
`lst.pop(i)`, or `lst[i]`. Returns the element pointer type (e.g. `{i64,i64}*`)
recovered from the source list's declared annotation (`list[tuple[...]]`) or,
for a bare `list`, from the element-struct shape tracked at literal/append time.
Returns None when the source isn't an identifiable list. See #6435.
"""
impl NaIRGenPass._infer_unpack_struct_ptr(nd: object) -> (ir.Type | None) {
    list_name: (str | None) = None;
    if isinstance(nd, uni.FuncCall) {
        tgt = nd.target;
        if isinstance(tgt, uni.AtomTrailer) and tgt.is_attr {
            list_name = self._get_name(tgt.target);
        }
    } elif isinstance(nd, uni.AtomTrailer) and not nd.is_attr and nd.right?.slices {
        list_name = self._get_name(nd.target);
    }
    if list_name is None {
        return None;
    }
    # 1. Typed `list[tuple[...]]` — recover from the declared annotation.
    cast = self._resolve_ptr_elem_cast_type(self.var_type_node.get(list_name));
    if cast is not None {
        return cast;
    }
    # 2. Bare `list` — recover the boxed-tuple struct tracked at literal time.
    return self.var_list_elem_struct.get(list_name);
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
    # A boxed tuple read from a list (`(a, b) = lst.pop()` / `lst[i]`) arrives as
    # an opaque `i8*` — recover its struct shape from the source list and bitcast
    # so the pointer-extract path below can destructure it (see #6435).
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

"""Exact ABI byte size of an LLVM type as a runtime i64.

Uses the classic `getelementptr (T* null, i32 1)` then `ptrtoint` idiom, so the
target data layout (alignment, padding, nested-struct sizes) decides the size
rather than a hand-rolled per-field sum. Use this whenever a heap allocation
must exactly fit a value of `ty` (e.g. boxing a tuple that contains a JacVal).
"""
impl NaIRGenPass._sizeof_llvm(ty: ir.Type) -> ir.Value {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    null_ptr = ir.Constant(ty.as_pointer(), None);
    size_gep = self.builder.gep(null_ptr, [ir.Constant(i32, 1)], name="sizeof.gep");
    return self.builder.ptrtoint(size_gep, i64, name="sizeof");
}

"""Box a value tuple to a heap-allocated pointer (rc_alloc + store).

Returns the value unchanged if it's already a pointer. Use this when
a value tuple needs to be stored in a container or passed to a function
that expects a pointer.
"""
impl NaIRGenPass._box_value_tuple(val: ir.Value, loc: str = "") -> ir.Value {
    if not isinstance(val.type, ir.LiteralStructType) {
        return val;
    }
    # Use LLVM's exact ABI sizeof (accounts for alignment and nested-struct
    # members such as a 16-byte JacVal) instead of the flat per-field estimate,
    # which undercounts a tuple holding an `any` element and would heap-overflow
    # the box on store and corrupt it on reload. See #6449.
    size = self._sizeof_llvm(val.type);
    # Prefer the jac_loc stamped on the value (set by _codegen_tuple_val) over
    # the caller-supplied loc so attribution is always as specific as possible.
    _box_loc = val?.jac_loc or loc;
    raw = self._rc_call_with_ctx(
        self.rc_alloc_fn, [size], op="box", loc=_box_loc, name="tuple.box"
    );
    ptr = self.builder.bitcast(raw, val.type.as_pointer(), name="tuple.box.ptr");
    self.builder.store(val, ptr);
    # RC: fresh __rc_alloc result is owned (RC=1). Mark it so callers that
    # check is_owned (field stores, list appends, etc.) skip the extra retain
    # that would push RC to 2 and create a permanent leak.
    self._mark_owned(ptr);
    # Set type tag so RC debug log shows "tuple" instead of "raw".
    self._emit_set_type_tag(self.builder, raw, "tuple");
    return ptr;
}

"""Coerce a value tuple to a target struct layout, boxing/unboxing each field
as needed (e.g. a concrete `int` field into an `any`/`JacVal` slot).

A bare `list` erases its elements to `any`, so a tuple stored in it has a fixed
physical layout (recovered by the unpack side from the list's element-struct).
A tuple literal built from concrete values (`(7, 0)` -> `{i64, i64}`) does not
match a layout whose slot is `any` (`{JacVal, i64}`) unless its scalar fields
are boxed first. This reconciles the two so producer and consumer agree on the
in-list layout.

Returns the value unchanged when it is not a struct, the target is not a struct,
the layouts already match, or the arities differ. See #6511."""
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
