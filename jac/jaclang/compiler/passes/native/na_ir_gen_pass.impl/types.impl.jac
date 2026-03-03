"""Type resolution and LLVM type helpers."""
"""Resolve a Jac type expression to an LLVM type."""
impl NaIRGenPass._resolve_jac_type(type_expr: (uni.UniNode | None)) -> ir.Type {
    if type_expr is None {
        return ir.IntType(64);
    }
    # Handle Name nodes (type references like `int`, `float`, `Point`)
    if isinstance(type_expr, uni.Name) {
        type_name = type_expr.value;
        if type_name in self.type_map {
            return self.type_map[type_name];
        }
        # Check if it's a known struct type → pointer to struct
        if type_name in self.struct_types {
            return self.struct_types[type_name].as_pointer();
        }
        if type_name == "None" {
            return ir.VoidType();
        }
        if type_name == "any" {
            return self.jacval_type;
        }
        # Bare unparameterized collection types → default to i64-element variants.
        # This handles annotations like `a: list = [1, 2]` where no element type
        # is specified. The default is List[int] / Dict[int, int] / Set[int].
        if type_name == "list" {
            self._emit_list_helpers("i64", ir.IntType(64));
            return self.list_types["i64"].as_pointer();
        }
        if type_name in {"dict"} {
            self._emit_dict_helpers("i64", "i64", ir.IntType(64), ir.IntType(64), 0);
            return self.dict_types["i64:i64"].as_pointer();
        }
        if type_name in {"set","frozenset"} {
            self._emit_set_helpers("i64", ir.IntType(64), 0);
            return self.set_types["i64"].as_pointer();
        }
    }
    # Handle BuiltinType nodes
    if uni?.BuiltinType and isinstance(type_expr, uni.BuiltinType) {
        type_name = type_expr.value;
        if type_name in self.type_map {
            return self.type_map[type_name];
        }
    }
    # Generic fallback: any node with .value matching a known type (handles Tokens)
    if type_expr?.value and isinstance(getattr(type_expr, "value", None), str) {
        type_name = type_expr.value;
        if type_name in self.type_map {
            return self.type_map[type_name];
        }
        if type_name in self.struct_types {
            return self.struct_types[type_name].as_pointer();
        }
        if type_name == "None" {
            return ir.VoidType();
        }
        if type_name == "any" {
            return self.jacval_type;
        }
        # Bare unparameterized collection names (e.g. from Token nodes)
        if type_name == "list" {
            self._emit_list_helpers("i64", ir.IntType(64));
            return self.list_types["i64"].as_pointer();
        }
        if type_name == "dict" {
            self._emit_dict_helpers("i64", "i64", ir.IntType(64), ir.IntType(64), 0);
            return self.dict_types["i64:i64"].as_pointer();
        }
        if type_name in {"set","frozenset"} {
            self._emit_set_helpers("i64", ir.IntType(64), 0);
            return self.set_types["i64"].as_pointer();
        }
    }
    # Handle union types: T | None → resolve T (BinaryExpr with BW_OR op)
    if isinstance(type_expr, uni.BinaryExpr) {
        op_val = getattr(type_expr.op, 'value', '');
        if op_val == "|" {
            # Resolve left side; right is typically None
            right_name = self._get_name(type_expr.right);
            left_type = self._resolve_jac_type(type_expr.left);
            if right_name == "None" {
                # T | None → just use T's type (pointers are nullable)
                return left_type;
            }
            # For non-None unions, use the left type (simplified)
            return left_type;
        }
    }
    # Handle list[T] type annotations (AtomTrailer: list[T])
    if isinstance(type_expr, uni.AtomTrailer) and not type_expr.is_attr {
        target_name = self._get_name(type_expr.target);
        if target_name == "list" {
            if type_expr?.right and type_expr.right?.slices {
                slices = type_expr.right.slices or [];
                if slices {
                    elem_node = slices[0];
                    if elem_node?.start and elem_node.start is not None {
                        elem_type = self._resolve_jac_type(elem_node.start);
                    } else {
                        elem_type = self._resolve_jac_type(elem_node);
                    }
                    elem_type_name = "i64";
                    if isinstance(elem_type, ir.DoubleType) {
                        elem_type_name = "f64";
                    } elif isinstance(elem_type, ir.PointerType) {
                        elem_type_name = "ptr";
                    }
                    self._emit_list_helpers(elem_type_name, elem_type);
                    return self.list_types[elem_type_name].as_pointer();
                }
            }
        }
        # Handle dict[K, V] type annotations
        if target_name == "dict" {
            if type_expr?.right and type_expr.right?.slices {
                slices = type_expr.right.slices or [];
                key_node: (object | None) = None;
                val_node: (object | None) = None;
                # dict[K, V] may parse as one slice with TupleVal, or two separate slices
                if len(slices) == 1
                and slices[0]?.start
                and isinstance(slices[0].start, uni.TupleVal) {
                    # Single slice with TupleVal: dict[(K, V)] → extract K and V from tuple values
                    tuple_val = slices[0].start;
                    if tuple_val.values and len(tuple_val.values) >= 2 {
                        key_node = tuple_val.values[0];
                        val_node = tuple_val.values[1];
                    }
                } elif len(slices) >= 2 {
                    # Two separate slices
                    key_node = slices[0];
                    val_node = slices[1];
                    if key_node?.start and key_node.start is not None {
                        key_node = key_node.start;
                    }
                    if val_node?.start and val_node.start is not None {
                        val_node = val_node.start;
                    }
                }
                if key_node is not None and val_node is not None {
                    key_type = self._resolve_jac_type(key_node);
                    val_type = self._resolve_jac_type(val_node);
                    key_type_name = "i64";
                    key_size = 0;
                    if isinstance(key_type, ir.DoubleType) {
                        key_type_name = "f64";
                    } elif isinstance(key_type, ir.PointerType) {
                        key_type_name = "ptr";
                        # Check if key is a tuple (pointer to LiteralStructType)
                        if isinstance(key_type.pointee, ir.LiteralStructType) {
                            key_size = self._get_struct_size(key_type.pointee);
                            key_type_name = f"tuple{key_size}";
                        }
                    }
                    val_type_name = "i64";
                    if isinstance(val_type, ir.DoubleType) {
                        val_type_name = "f64";
                    } elif isinstance(val_type, ir.PointerType) {
                        val_type_name = "ptr";
                    } elif self?.jacval_type and val_type == self.jacval_type {
                        val_type_name = "jacval";
                    }
                    dict_key = f"{key_type_name}:{val_type_name}";
                    self._emit_dict_helpers(
                        key_type_name, val_type_name, key_type, val_type, key_size
                    );
                    return self.dict_types[dict_key].as_pointer();
                }
            }
        }
        # Handle set[T] type annotations
        if target_name == "set" {
            if type_expr?.right and type_expr.right?.slices {
                slices = type_expr.right.slices or [];
                if slices {
                    elem_node = slices[0];
                    if elem_node?.start and elem_node.start is not None {
                        elem_type = self._resolve_jac_type(elem_node.start);
                    } else {
                        elem_type = self._resolve_jac_type(elem_node);
                    }
                    elem_type_name = "i64";
                    elem_size = 0;
                    if isinstance(elem_type, ir.DoubleType) {
                        elem_type_name = "f64";
                    } elif isinstance(elem_type, ir.PointerType) {
                        elem_type_name = "ptr";
                        # Check if this is a tuple (pointer to LiteralStructType)
                        if isinstance(elem_type.pointee, ir.LiteralStructType) {
                            elem_size = self._get_struct_size(elem_type.pointee);
                            elem_type_name = f"tuple{elem_size}";
                        }
                    }
                    self._emit_set_helpers(elem_type_name, elem_type, elem_size);
                    return self.set_types[elem_type_name].as_pointer();
                }
            }
        }
        # Handle frozenset[T] type annotations -- same underlying type as set[T]
        if target_name == "frozenset" {
            if type_expr?.right and type_expr.right?.slices {
                slices = type_expr.right.slices or [];
                if slices {
                    elem_node = slices[0];
                    if elem_node?.start and elem_node.start is not None {
                        elem_type = self._resolve_jac_type(elem_node.start);
                    } else {
                        elem_type = self._resolve_jac_type(elem_node);
                    }
                    elem_type_name = "i64";
                    elem_size = 0;
                    if isinstance(elem_type, ir.DoubleType) {
                        elem_type_name = "f64";
                    } elif isinstance(elem_type, ir.PointerType) {
                        elem_type_name = "ptr";
                        if isinstance(elem_type.pointee, ir.LiteralStructType) {
                            elem_size = self._get_struct_size(elem_type.pointee);
                            elem_type_name = f"tuple{elem_size}";
                        }
                    }
                    self._emit_set_helpers(elem_type_name, elem_type, elem_size);
                    return self.set_types[elem_type_name].as_pointer();
                }
            }
        }
        # Handle tuple[T1, T2, ...] type annotations
        if target_name == "tuple" {
            if type_expr?.right and type_expr.right?.slices {
                slices = type_expr.right.slices or [];
                elem_types: list[ir.Type] = [];
                for s in slices {
                    # Check if slice.start is a TupleVal (tuple[int, int] parses as tuple[(int, int)])
                    if s?.start and isinstance(s.start, uni.TupleVal) {
                        for tv in s.start.values {
                            et = self._resolve_jac_type(tv);
                            elem_types.append(et);
                        }
                    } elif s?.start and s.start is not None {
                        et = self._resolve_jac_type(s.start);
                        elem_types.append(et);
                    } else {
                        et = self._resolve_jac_type(s);
                        elem_types.append(et);
                    }
                }
                if elem_types {
                    n = len(elem_types);
                    tuple_key = f"Tuple.{n}." + ".".join([str(t) for t in elem_types]);
                    if tuple_key not in self.tuple_types {
                        struct_type = ir.LiteralStructType(elem_types);
                        self.tuple_types[tuple_key] = struct_type;
                    }
                    return self.tuple_types[tuple_key].as_pointer();
                }
            }
        }
    }
    # Try structured type
    if isinstance(type_expr, uni.Expr) and type_expr.type {
        type_str = str(type_expr.type);
        if type_str in self.type_map {
            return self.type_map[type_str];
        }
    }
    return ir.IntType(64);
}

"""Resolve a type for C library declarations -- clib structs use value types, not pointers."""
impl NaIRGenPass._resolve_clib_type(type_expr: (uni.UniNode | None)) -> ir.Type {
    if type_expr is None {
        return ir.IntType(64);
    }
    # Check if this is a clib struct name -- return VALUE type (not pointer)
    type_name: (str | None) = None;
    if isinstance(type_expr, uni.Name) {
        type_name = type_expr.value;
    } elif type_expr?.value and isinstance(getattr(type_expr, "value", None), str) {
        type_name = type_expr.value;
    }
    if type_name is not None and type_name in self.clib_struct_names {
        # Use ABI-coerced integer type for small structs (matches C calling convention)
        if type_name in self.clib_struct_abi_types {
            return self.clib_struct_abi_types[type_name];
        }
        return self.struct_types[type_name];
    }
    # For all other types, delegate to normal resolution
    return self._resolve_jac_type(type_expr);
}

"""Extract name string from a Name or similar node."""
impl NaIRGenPass._get_name(nd: (uni.UniNode | None)) -> (str | None) {
    if nd is None {
        return None;
    }
    if isinstance(nd, uni.Name) {
        return nd.value;
    }
    if nd?.sym_name {
        return nd.sym_name;
    }
    if nd?.value and isinstance(getattr(nd, "value"), str) {
        return nd.value;
    }
    return None;
}

"""Create an alloca in the function entry block (ensures dominance)."""
impl NaIRGenPass._entry_alloca(var_type: ir.Type, name: str) -> ir.Value {
    func = self.builder.function;
    entry_block = func.entry_basic_block;
    # Save current position
    cur_block = self.builder.block;
    # Position at the start of the entry block (before all instructions)
    if entry_block.instructions {
        self.builder.position_before(entry_block.instructions[0]);
    } else {
        self.builder.position_at_start(entry_block);
    }
    alloca = self.builder.alloca(var_type, name=name);
    # Restore position
    self.builder.position_at_end(cur_block);
    return alloca;
}

"""Convert a value to i1 (boolean)."""
impl NaIRGenPass._to_bool(val: ir.Value) -> ir.Value {
    if isinstance(val.type, ir.IntType) and val.type.width == 1 {
        return val;
    }
    if isinstance(val.type, ir.IntType) {
        return self.builder.icmp_unsigned(
            "!=", val, ir.Constant(val.type, 0), name="tobool"
        );
    }
    if isinstance(val.type, ir.DoubleType) {
        return self.builder.fcmp_ordered(
            "!=", val, ir.Constant(val.type, 0.0), name="tobool"
        );
    }
    if isinstance(val.type, ir.PointerType) {
        null_ptr = ir.Constant(val.type, None);
        return self.builder.icmp_unsigned("!=", val, null_ptr, name="tobool");
    }
    return val;
}

"""Coerce a value to the target type if needed."""
impl NaIRGenPass._coerce_type(val: ir.Value, target_type: ir.Type) -> ir.Value {
    if val.type == target_type {
        return val;
    }
    # Int → Double (f64)
    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.DoubleType) {
        return self.builder.sitofp(val, target_type, name="cast");
    }
    # Int → Float (f32)
    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.FloatType) {
        return self.builder.sitofp(val, target_type, name="cast.f32");
    }
    # Double (f64) → Int
    if isinstance(val.type, ir.DoubleType) and isinstance(target_type, ir.IntType) {
        return self.builder.fptosi(val, target_type, name="cast");
    }
    # Float (f32) → Int
    if isinstance(val.type, ir.FloatType) and isinstance(target_type, ir.IntType) {
        return self.builder.fptosi(val, target_type, name="cast.i");
    }
    # Double (f64) → Float (f32)
    if isinstance(val.type, ir.DoubleType) and isinstance(target_type, ir.FloatType) {
        return self.builder.fptrunc(val, target_type, name="fptrunc");
    }
    # Float (f32) → Double (f64)
    if isinstance(val.type, ir.FloatType) and isinstance(target_type, ir.DoubleType) {
        return self.builder.fpext(val, target_type, name="fpext");
    }
    # Pointer-to-pointer bitcast (e.g., different struct pointer types)
    if isinstance(val.type, ir.PointerType)
    and isinstance(target_type, ir.PointerType) {
        return self.builder.bitcast(val, target_type, name="ptrcast");
    }
    # Struct pointer → struct value (Jac pointer → C value at call boundary)
    if isinstance(val.type, ir.PointerType)
    and not isinstance(target_type, ir.PointerType) {
        if val.type?.pointee and val.type.pointee == target_type {
            return self.builder.load(val, name="struct.unbox");
        }
        # Struct pointer → ABI integer (e.g., %Color* → i32 for small C structs)
        if isinstance(target_type, ir.IntType) and val.type?.pointee {
            for (sname, abi_type) in self.clib_struct_abi_types.items() {
                if val.type.pointee == self.struct_types.get(sname)
                and abi_type == target_type {
                    int_ptr = self.builder.bitcast(
                        val, target_type.as_pointer(), name="struct.abi.cast"
                    );
                    return self.builder.load(int_ptr, name="struct.abi.unbox");
                }
            }
        }
    }
    # Struct value → struct pointer (C value → Jac pointer at call boundary)
    if not isinstance(val.type, ir.PointerType)
    and isinstance(target_type, ir.PointerType) {
        if target_type?.pointee and target_type.pointee == val.type {
            null_ptr = ir.Constant(target_type, None);
            size_gep = self.builder.gep(
                null_ptr, [ir.Constant(ir.IntType(32), 1)], name="clib.sizeof.gep"
            );
            size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="clib.sizeof");
            raw_ptr = self.builder.call(self.rc_alloc_fn, [size], name="clib.box.raw");
            typed_ptr = self.builder.bitcast(raw_ptr, target_type, name="clib.box.ptr");
            self.builder.store(val, typed_ptr);
            return typed_ptr;
        }
        # ABI integer → struct pointer (e.g., i32 → %Color* for small C struct returns)
        if isinstance(val.type, ir.IntType) and target_type?.pointee {
            for (sname, abi_type) in self.clib_struct_abi_types.items() {
                if target_type.pointee == self.struct_types.get(sname)
                and abi_type == val.type {
                    null_ptr = ir.Constant(target_type, None);
                    size_gep = self.builder.gep(
                        null_ptr,
                        [ir.Constant(ir.IntType(32), 1)],
                        name="clib.sizeof.gep"
                    );
                    size = self.builder.ptrtoint(
                        size_gep, ir.IntType(64), name="clib.sizeof"
                    );
                    raw_ptr = self.builder.call(
                        self.rc_alloc_fn, [size], name="clib.box.raw"
                    );
                    int_ptr = self.builder.bitcast(
                        raw_ptr, val.type.as_pointer(), name="clib.abi.cast"
                    );
                    self.builder.store(val, int_ptr);
                    typed_ptr = self.builder.bitcast(
                        raw_ptr, target_type, name="clib.box.ptr"
                    );
                    return typed_ptr;
                }
            }
        }
    }
    # Int width coercion (i1 to i64, etc.)
    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.IntType) {
        if val.type.width < target_type.width {
            return self.builder.zext(val, target_type, name="zext");
        } elif val.type.width > target_type.width {
            return self.builder.trunc(val, target_type, name="trunc");
        }
    }
    return val;
}

"""Promote both operands to float if either is float."""
impl NaIRGenPass._promote_to_float(
    left: ir.Value, right: ir.Value
) -> tuple[(ir.Value, ir.Value)] {
    if isinstance(left.type, ir.IntType) {
        left = self.builder.sitofp(left, ir.DoubleType(), name="cast");
    }
    if isinstance(right.type, ir.IntType) {
        right = self.builder.sitofp(right, ir.DoubleType(), name="cast");
    }
    return (left, right);
}

"""Emit a binary operation."""
impl NaIRGenPass._emit_binary_op(
    op: str, left: ir.Value, right: ir.Value
) -> (ir.Value | None) {
    # String concatenation (i8* + i8*) — check before numeric dispatch
    i8p_type = ir.IntType(8).as_pointer();
    if op == Tok.PLUS and left.type == i8p_type and right.type == i8p_type {
        strlen_fn = self._get_or_declare_extern(
            "strlen", ir.IntType(64), [ir.IntType(8).as_pointer()]
        );
        strcpy_fn = self._get_or_declare_extern(
            "strcpy",
            ir.IntType(8).as_pointer(),
            [ir.IntType(8).as_pointer(), ir.IntType(8).as_pointer()]
        );
        strcat_fn = self._get_or_declare_extern(
            "strcat",
            ir.IntType(8).as_pointer(),
            [ir.IntType(8).as_pointer(), ir.IntType(8).as_pointer()]
        );
        len1 = self.builder.call(strlen_fn, [left], name="len1");
        len2 = self.builder.call(strlen_fn, [right], name="len2");
        total = self.builder.add(len1, len2, name="total_len");
        buf_size = self.builder.add(
            total, ir.Constant(ir.IntType(64), 1), name="buf_size"
        );
        buf = self.builder.call(self.rc_alloc_fn, [buf_size], name="concat.buf");
        self.builder.call(strcpy_fn, [buf, left]);
        self.builder.call(strcat_fn, [buf, right]);
        return buf;
    }
    # String repeat (i8* * i64 or i64 * i8*): allocate n*len buffer, loop-copy
    if op == Tok.STAR_MUL {
        str_val: (ir.Value | None) = None;
        int_val: (ir.Value | None) = None;
        if left.type == i8p_type and isinstance(right.type, ir.IntType) {
            str_val = left;
            int_val = right;
        } elif right.type == i8p_type and isinstance(left.type, ir.IntType) {
            str_val = right;
            int_val = left;
        }
        if str_val is not None and int_val is not None {
            i8 = ir.IntType(8);
            i8p = i8.as_pointer();
            i64 = ir.IntType(64);
            strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
            memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
            slen = self.builder.call(strlen_fn, [str_val], name="rep.slen");
            total = self.builder.mul(slen, int_val, name="rep.total");
            alloc = self.builder.add(total, ir.Constant(i64, 1), name="rep.alloc");
            buf = self.builder.call(self.rc_alloc_fn, [alloc], name="rep.buf");
            func = self.builder.basic_block.function;
            entry_bb = self.builder.basic_block;
            loop_bb = func.append_basic_block(name="rep.loop");
            body_bb = func.append_basic_block(name="rep.body");
            done_bb = func.append_basic_block(name="rep.done");
            self.builder.branch(loop_bb);
            self.builder.position_at_start(loop_bb);
            offset = self.builder.phi(i64, name="rep.off");
            count = self.builder.phi(i64, name="rep.cnt");
            offset.add_incoming(ir.Constant(i64, 0), entry_bb);
            count.add_incoming(ir.Constant(i64, 0), entry_bb);
            at_end = self.builder.icmp_unsigned(">=", count, int_val, name="rep.atend");
            self.builder.cbranch(at_end, done_bb, body_bb);
            self.builder.position_at_start(body_bb);
            dst = self.builder.gep(buf, [offset], name="rep.dst");
            self.builder.call(memcpy_fn, [dst, str_val, slen]);
            new_off = self.builder.add(offset, slen, name="rep.newoff");
            new_cnt = self.builder.add(count, ir.Constant(i64, 1), name="rep.newcnt");
            offset.add_incoming(new_off, body_bb);
            count.add_incoming(new_cnt, body_bb);
            self.builder.branch(loop_bb);
            self.builder.position_at_start(done_bb);
            null_ptr = self.builder.gep(buf, [total], name="rep.null");
            self.builder.store(ir.Constant(i8, 0), null_ptr);
            return buf;
        }
    }
    # List multiplication (list * int or int * list): repeat list n times
    if op == Tok.STAR_MUL {
        for (lmul_key, lmul_helpers) in self.list_helpers.items() {
            lmul_type = self.list_types.get(lmul_key);
            if lmul_type is None {
                continue;
            }
            lmul_list: (ir.Value | None) = None;
            lmul_int: (ir.Value | None) = None;
            if left.type == lmul_type.as_pointer()
            and isinstance(right.type, ir.IntType) {
                lmul_list = left;
                lmul_int = right;
            } elif right.type == lmul_type.as_pointer()
            and isinstance(left.type, ir.IntType) {
                lmul_list = right;
                lmul_int = left;
            }
            if lmul_list is not None and lmul_int is not None {
                i64 = ir.IntType(64);
                lmul_new = self.builder.call(lmul_helpers["new"], [], name="lmul.new");
                lmul_len = self.builder.call(
                    lmul_helpers["len"], [lmul_list], name="lmul.len"
                );
                func = self.builder.basic_block.function;
                lmul_entry_bb = self.builder.basic_block;
                lmul_outer_bb = func.append_basic_block(name="lmul.outer");
                lmul_iinit_bb = func.append_basic_block(name="lmul.iinit");
                lmul_inner_bb = func.append_basic_block(name="lmul.inner");
                lmul_ibody_bb = func.append_basic_block(name="lmul.ibody");
                lmul_onext_bb = func.append_basic_block(name="lmul.onext");
                lmul_done_bb = func.append_basic_block(name="lmul.done");
                self.builder.branch(lmul_outer_bb);
                self.builder.position_at_start(lmul_outer_bb);
                lmul_rep = self.builder.phi(i64, name="lmul.rep");
                lmul_rep.add_incoming(ir.Constant(i64, 0), lmul_entry_bb);
                lmul_rend = self.builder.icmp_signed(
                    ">=", lmul_rep, lmul_int, name="lmul.rend"
                );
                self.builder.cbranch(lmul_rend, lmul_done_bb, lmul_iinit_bb);
                self.builder.position_at_start(lmul_iinit_bb);
                self.builder.branch(lmul_inner_bb);
                self.builder.position_at_start(lmul_inner_bb);
                lmul_ei = self.builder.phi(i64, name="lmul.ei");
                lmul_ei.add_incoming(ir.Constant(i64, 0), lmul_iinit_bb);
                lmul_eend = self.builder.icmp_unsigned(
                    ">=", lmul_ei, lmul_len, name="lmul.eend"
                );
                self.builder.cbranch(lmul_eend, lmul_onext_bb, lmul_ibody_bb);
                self.builder.position_at_start(lmul_ibody_bb);
                lmul_elem = self.builder.call(
                    lmul_helpers["get"], [lmul_list, lmul_ei], name="lmul.elem"
                );
                self.builder.call(lmul_helpers["append"], [lmul_new, lmul_elem]);
                lmul_ne = self.builder.add(lmul_ei, ir.Constant(i64, 1), name="lmul.ne");
                lmul_ei.add_incoming(lmul_ne, lmul_ibody_bb);
                self.builder.branch(lmul_inner_bb);
                self.builder.position_at_start(lmul_onext_bb);
                lmul_nr = self.builder.add(
                    lmul_rep, ir.Constant(i64, 1), name="lmul.nr"
                );
                lmul_rep.add_incoming(lmul_nr, lmul_onext_bb);
                self.builder.branch(lmul_outer_bb);
                self.builder.position_at_start(lmul_done_bb);
                return lmul_new;
            }
        }
    }
    # List concatenation (list_ptr + list_ptr): create new list, append all
    if op == Tok.PLUS {
        for (list_key, helpers) in self.list_helpers.items() {
            list_type = self.list_types.get(list_key);
            if list_type is not None
            and left.type == list_type.as_pointer()
            and right.type == list_type.as_pointer() {
                i64 = ir.IntType(64);
                new_list = self.builder.call(helpers["new"], [], name="lcat.new");
                # Append all from left
                left_len = self.builder.call(helpers["len"], [left], name="lcat.llen");
                func = self.builder.basic_block.function;
                entry_bb = self.builder.basic_block;
                loop1_bb = func.append_basic_block(name="lcat.l1");
                body1_bb = func.append_basic_block(name="lcat.b1");
                mid_bb = func.append_basic_block(name="lcat.mid");
                loop2_bb = func.append_basic_block(name="lcat.l2");
                body2_bb = func.append_basic_block(name="lcat.b2");
                done_bb = func.append_basic_block(name="lcat.done");
                self.builder.branch(loop1_bb);
                self.builder.position_at_start(loop1_bb);
                i1 = self.builder.phi(i64, name="lcat.i1");
                i1.add_incoming(ir.Constant(i64, 0), entry_bb);
                end1 = self.builder.icmp_unsigned(">=", i1, left_len, name="lcat.end1");
                self.builder.cbranch(end1, mid_bb, body1_bb);
                self.builder.position_at_start(body1_bb);
                e1 = self.builder.call(helpers["get"], [left, i1], name="lcat.e1");
                self.builder.call(helpers["append"], [new_list, e1]);
                n1 = self.builder.add(i1, ir.Constant(i64, 1), name="lcat.n1");
                i1.add_incoming(n1, body1_bb);
                self.builder.branch(loop1_bb);
                # Append all from right
                self.builder.position_at_start(mid_bb);
                right_len = self.builder.call(helpers["len"], [right], name="lcat.rlen");
                self.builder.branch(loop2_bb);
                self.builder.position_at_start(loop2_bb);
                i2 = self.builder.phi(i64, name="lcat.i2");
                i2.add_incoming(ir.Constant(i64, 0), mid_bb);
                end2 = self.builder.icmp_unsigned(">=", i2, right_len, name="lcat.end2");
                self.builder.cbranch(end2, done_bb, body2_bb);
                self.builder.position_at_start(body2_bb);
                e2 = self.builder.call(helpers["get"], [right, i2], name="lcat.e2");
                self.builder.call(helpers["append"], [new_list, e2]);
                n2 = self.builder.add(i2, ir.Constant(i64, 1), name="lcat.n2");
                i2.add_incoming(n2, body2_bb);
                self.builder.branch(loop2_bb);
                self.builder.position_at_start(done_bb);
                return new_list;
            }
        }
    }
    # Set operators (set_ptr op set_ptr): |, &, -, ^
    for (sk, st) in self.set_types.items() {
        if left.type == st.as_pointer() and right.type == st.as_pointer() {
            self._ensure_emitters();
            _ctx = self._native_emit_ctx_class(pass_ref=self, type_key=sk);
            _se = self._native_emitters.get("set");
            if _se is not None {
                if op == Tok.BW_OR {
                    return _se.emit_union(_ctx, left, [right]);
                }
                if op == Tok.BW_AND {
                    return _se.emit_intersection(_ctx, left, [right]);
                }
                if op == Tok.MINUS {
                    return _se.emit_difference(_ctx, left, [right]);
                }
                if op == Tok.BW_XOR {
                    return _se.emit_symmetric_difference(_ctx, left, [right]);
                }
            }
            break;
        }
    }
    # Complex arithmetic (JacComplex* op JacComplex*)
    ctype_ptr = self.complex_struct_type.as_pointer();
    if left.type == ctype_ptr and right.type == ctype_ptr {
        f64 = ir.DoubleType();
        i64 = ir.IntType(64);
        i32 = ir.IntType(32);
        z0 = ir.Constant(i32, 0);
        z1 = ir.Constant(i32, 1);
        ar = self.builder.load(
            self.builder.gep(left, [z0, z0], name="c.ar.p"), name="c.ar"
        );
        ai = self.builder.load(
            self.builder.gep(left, [z0, z1], name="c.ai.p"), name="c.ai"
        );
        br = self.builder.load(
            self.builder.gep(right, [z0, z0], name="c.br.p"), name="c.br"
        );
        bi = self.builder.load(
            self.builder.gep(right, [z0, z1], name="c.bi.p"), name="c.bi"
        );
        rr: (ir.Value | None) = None;
        ri: (ir.Value | None) = None;
        if op == Tok.PLUS {
            rr = self.builder.fadd(ar, br, name="c.add.r");
            ri = self.builder.fadd(ai, bi, name="c.add.i");
        } elif op == Tok.MINUS {
            rr = self.builder.fsub(ar, br, name="c.sub.r");
            ri = self.builder.fsub(ai, bi, name="c.sub.i");
        } elif op == Tok.STAR_MUL {
            # (ar*br - ai*bi, ar*bi + ai*br)
            rr = self.builder.fsub(
                self.builder.fmul(ar, br, name="c.m1"),
                self.builder.fmul(ai, bi, name="c.m2"),
                name="c.mul.r"
            );
            ri = self.builder.fadd(
                self.builder.fmul(ar, bi, name="c.m3"),
                self.builder.fmul(ai, br, name="c.m4"),
                name="c.mul.i"
            );
        } elif op == Tok.DIV {
            # (ar*br + ai*bi)/(br*br + bi*bi), (ai*br - ar*bi)/(br*br + bi*bi)
            denom = self.builder.fadd(
                self.builder.fmul(br, br, name="c.d1"),
                self.builder.fmul(bi, bi, name="c.d2"),
                name="c.denom"
            );
            rr = self.builder.fdiv(
                self.builder.fadd(
                    self.builder.fmul(ar, br, name="c.d3"),
                    self.builder.fmul(ai, bi, name="c.d4"),
                    name="c.div.rn"
                ),
                denom,
                name="c.div.r"
            );
            ri = self.builder.fdiv(
                self.builder.fsub(
                    self.builder.fmul(ai, br, name="c.d5"),
                    self.builder.fmul(ar, bi, name="c.d6"),
                    name="c.div.in"
                ),
                denom,
                name="c.div.i"
            );
        }
        if rr is not None and ri is not None {
            # Allocate result complex struct
            raw = self.builder.call(
                self.rc_alloc_fn, [ir.Constant(i64, 16)], name="c.res.raw"
            );
            ptr = self.builder.bitcast(raw, ctype_ptr, name="c.res.ptr");
            self.builder.store(rr, self.builder.gep(ptr, [z0, z0], name="c.res.rp"));
            self.builder.store(ri, self.builder.gep(ptr, [z0, z1], name="c.res.ip"));
            return ptr;
        }
    }
    is_float = isinstance(left.type, ir.DoubleType)
    or isinstance(right.type, ir.DoubleType);
    if is_float {
        (left, right) = self._promote_to_float(left, right);
    }
    if is_float {
        if op == Tok.PLUS {
            return self.builder.fadd(left, right, name="fadd");
        } elif op == Tok.MINUS {
            return self.builder.fsub(left, right, name="fsub");
        } elif op == Tok.STAR_MUL {
            return self.builder.fmul(left, right, name="fmul");
        } elif op == Tok.DIV {
            # ZeroDivisionError check for float division
            fzero = ir.Constant(ir.DoubleType(), 0.0);
            is_zero = self.builder.fcmp_ordered(
                "==", right, fzero, name="fdiv.zero.chk"
            );
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "float division by zero"
            );
            return self.builder.fdiv(left, right, name="fdiv");
        } elif op == Tok.MOD {
            # ZeroDivisionError check for float modulo
            fzero = ir.Constant(ir.DoubleType(), 0.0);
            is_zero = self.builder.fcmp_ordered(
                "==", right, fzero, name="fmod.zero.chk"
            );
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "float modulo by zero"
            );
            return self.builder.frem(left, right, name="fmod");
        } elif op == Tok.FLOOR_DIV {
            # Float floor division: fdiv then floor
            fzero = ir.Constant(ir.DoubleType(), 0.0);
            is_zero = self.builder.fcmp_ordered(
                "==", right, fzero, name="ffloordiv.zero.chk"
            );
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "float floor division by zero"
            );
            raw = self.builder.fdiv(left, right, name="ffloordiv.raw");
            floor_fn = self._get_or_declare_extern(
                "floor", ir.DoubleType(), [ir.DoubleType()]
            );
            return self.builder.call(floor_fn, [raw], name="ffloordiv");
        }
    } else {
        i64 = ir.IntType(64);
        i1 = ir.IntType(1);
        if op == Tok.PLUS {
            # OverflowError check via LLVM intrinsic
            overflow_ret = ir.LiteralStructType([i64, i1]);
            intrinsic = self._get_or_declare_extern(
                "llvm.sadd.with.overflow.i64", overflow_ret, [i64, i64]
            );
            result = self.builder.call(intrinsic, [left, right], name="add.ovf");
            val = self.builder.extract_value(result, 0, name="add.val");
            overflow = self.builder.extract_value(result, 1, name="add.overflow");
            self._emit_runtime_raise(overflow, "OverflowError", "integer overflow");
            return val;
        } elif op == Tok.MINUS {
            # OverflowError check via LLVM intrinsic
            overflow_ret = ir.LiteralStructType([i64, i1]);
            intrinsic = self._get_or_declare_extern(
                "llvm.ssub.with.overflow.i64", overflow_ret, [i64, i64]
            );
            result = self.builder.call(intrinsic, [left, right], name="sub.ovf");
            val = self.builder.extract_value(result, 0, name="sub.val");
            overflow = self.builder.extract_value(result, 1, name="sub.overflow");
            self._emit_runtime_raise(overflow, "OverflowError", "integer overflow");
            return val;
        } elif op == Tok.STAR_MUL {
            # OverflowError check via LLVM intrinsic
            overflow_ret = ir.LiteralStructType([i64, i1]);
            intrinsic = self._get_or_declare_extern(
                "llvm.smul.with.overflow.i64", overflow_ret, [i64, i64]
            );
            result = self.builder.call(intrinsic, [left, right], name="mul.ovf");
            val = self.builder.extract_value(result, 0, name="mul.val");
            overflow = self.builder.extract_value(result, 1, name="mul.overflow");
            self._emit_runtime_raise(overflow, "OverflowError", "integer overflow");
            return val;
        } elif op == Tok.DIV {
            # ZeroDivisionError check for integer division
            izero = ir.Constant(i64, 0);
            is_zero = self.builder.icmp_signed("==", right, izero, name="div.zero.chk");
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "integer division or modulo by zero"
            );
            return self.builder.sdiv(left, right, name="div");
        } elif op == Tok.FLOOR_DIV {
            # ZeroDivisionError check for floor division
            izero = ir.Constant(i64, 0);
            is_zero = self.builder.icmp_signed(
                "==", right, izero, name="floordiv.zero.chk"
            );
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "integer division or modulo by zero"
            );
            return self.builder.sdiv(left, right, name="floordiv");
        } elif op == Tok.MOD {
            # ZeroDivisionError check for integer modulo
            izero = ir.Constant(i64, 0);
            is_zero = self.builder.icmp_signed("==", right, izero, name="mod.zero.chk");
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "integer division or modulo by zero"
            );
            return self.builder.srem(left, right, name="mod");
        }
    }
    # Power operator (integer exponentiation via loop, float via pow)
    if op == Tok.STAR_POW {
        if is_float {
            pow_fn = self._get_or_declare_extern(
                "pow", ir.DoubleType(), [ir.DoubleType(), ir.DoubleType()]
            );
            return self.builder.call(pow_fn, [left, right], name="pow");
        } else {
            # Integer power: use loop-based exponentiation
            return self._codegen_int_pow(left, right);
        }
    }
    # Bitwise operators (integer only)
    if op == Tok.BW_AND {
        return self.builder.and_(left, right, name="bwand");
    }
    if op == Tok.BW_OR {
        return self.builder.or_(left, right, name="bwor");
    }
    if op == Tok.BW_XOR {
        return self.builder.xor(left, right, name="bwxor");
    }
    if op == Tok.LSHIFT {
        return self.builder.shl(left, right, name="shl");
    }
    if op == Tok.RSHIFT {
        return self.builder.ashr(left, right, name="ashr");
    }
    # Logical operators
    if op == Tok.KW_AND {
        return self.builder.and_(left, right, name="and");
    }
    if op == Tok.KW_OR {
        return self.builder.or_(left, right, name="or");
    }
    return None;
}

"""Emit a comparison operation."""
impl NaIRGenPass._emit_comparison(
    op: str, left: ir.Value, right: ir.Value, is_float: bool
) -> (ir.Value | None) {
    # Pointer comparisons
    if isinstance(left.type, ir.PointerType)
    and isinstance(right.type, ir.PointerType) {
        i8_ptr = ir.IntType(8).as_pointer();
        # String comparison: both operands must be i8* (char pointers)
        if left.type == i8_ptr and right.type == i8_ptr {
            strcmp_fn = self._get_or_declare_extern(
                "strcmp", ir.IntType(32), [i8_ptr, i8_ptr]
            );
            cmp_result = self.builder.call(strcmp_fn, [left, right], name="strcmp");
            zero = ir.Constant(ir.IntType(32), 0);
            if op == Tok.EE {
                return self.builder.icmp_signed("==", cmp_result, zero, name="streq");
            } elif op == Tok.NE {
                return self.builder.icmp_signed("!=", cmp_result, zero, name="strne");
            } elif op == Tok.LT {
                return self.builder.icmp_signed("<", cmp_result, zero, name="strlt");
            } elif op == Tok.GT {
                return self.builder.icmp_signed(">", cmp_result, zero, name="strgt");
            } elif op == Tok.LTE {
                return self.builder.icmp_signed("<=", cmp_result, zero, name="strle");
            } elif op == Tok.GTE {
                return self.builder.icmp_signed(">=", cmp_result, zero, name="strge");
            }
            return None;
        }
        # List comparison: detect list pointer types
        for (lcmp_key, lcmp_type) in self.list_types.items() {
            if left.type == lcmp_type.as_pointer()
            and right.type == lcmp_type.as_pointer() {
                lcmp_h = self.list_helpers.get(lcmp_key);
                if lcmp_h is None {
                    break;
                }
                i64 = ir.IntType(64);
                i1_t = ir.IntType(1);
                lcmp_la = self.builder.call(lcmp_h["len"], [left], name="lcmp.la");
                lcmp_lb = self.builder.call(lcmp_h["len"], [right], name="lcmp.lb");
                func = self.builder.basic_block.function;
                lcmp_entry_bb = self.builder.basic_block;
                lcmp_et = lcmp_h["elem_type"];
                if op == Tok.EE or op == Tok.NE {
                    # == : lengths equal AND all elements equal
                    lcmp_len_eq = self.builder.icmp_unsigned(
                        "==", lcmp_la, lcmp_lb, name="lcmp.leq"
                    );
                    lcmp_chk_bb = func.append_basic_block(name="lcmp.eq.chk");
                    lcmp_false_bb = func.append_basic_block(name="lcmp.eq.false");
                    lcmp_loop_bb = func.append_basic_block(name="lcmp.eq.loop");
                    lcmp_body_bb = func.append_basic_block(name="lcmp.eq.body");
                    lcmp_ne_bb = func.append_basic_block(name="lcmp.eq.ne");
                    lcmp_next_bb = func.append_basic_block(name="lcmp.eq.next");
                    lcmp_done_bb = func.append_basic_block(name="lcmp.eq.done");
                    self.builder.cbranch(lcmp_len_eq, lcmp_chk_bb, lcmp_false_bb);
                    self.builder.position_at_start(lcmp_chk_bb);
                    self.builder.branch(lcmp_loop_bb);
                    self.builder.position_at_start(lcmp_loop_bb);
                    lcmp_i = self.builder.phi(i64, name="lcmp.eq.i");
                    lcmp_i.add_incoming(ir.Constant(i64, 0), lcmp_chk_bb);
                    lcmp_iend = self.builder.icmp_unsigned(
                        ">=", lcmp_i, lcmp_la, name="lcmp.eq.iend"
                    );
                    self.builder.cbranch(lcmp_iend, lcmp_done_bb, lcmp_body_bb);
                    self.builder.position_at_start(lcmp_body_bb);
                    lcmp_ea = self.builder.call(
                        lcmp_h["get"], [left, lcmp_i], name="lcmp.ea"
                    );
                    lcmp_eb = self.builder.call(
                        lcmp_h["get"], [right, lcmp_i], name="lcmp.eb"
                    );
                    if isinstance(lcmp_et, ir.IntType) {
                        lcmp_elem_ne = self.builder.icmp_signed(
                            "!=", lcmp_ea, lcmp_eb, name="lcmp.ene"
                        );
                    } elif isinstance(lcmp_et, ir.DoubleType) {
                        lcmp_elem_ne = self.builder.fcmp_ordered(
                            "!=", lcmp_ea, lcmp_eb, name="lcmp.ene"
                        );
                    } else {
                        lcmp_strcmp = self._get_or_declare_extern(
                            "strcmp", ir.IntType(32), [i8_ptr, i8_ptr]
                        );
                        lcmp_scmp = self.builder.call(
                            lcmp_strcmp, [lcmp_ea, lcmp_eb], name="lcmp.scmp"
                        );
                        lcmp_elem_ne = self.builder.icmp_signed(
                            "!=",
                            lcmp_scmp,
                            ir.Constant(ir.IntType(32), 0),
                            name="lcmp.ene"
                        );
                    }
                    self.builder.cbranch(lcmp_elem_ne, lcmp_ne_bb, lcmp_next_bb);
                    self.builder.position_at_start(lcmp_ne_bb);
                    self.builder.branch(lcmp_false_bb);
                    self.builder.position_at_start(lcmp_next_bb);
                    lcmp_ni = self.builder.add(
                        lcmp_i, ir.Constant(i64, 1), name="lcmp.ni"
                    );
                    lcmp_i.add_incoming(lcmp_ni, lcmp_next_bb);
                    self.builder.branch(lcmp_loop_bb);
                    self.builder.position_at_start(lcmp_false_bb);
                    self.builder.branch(lcmp_done_bb);
                    self.builder.position_at_start(lcmp_done_bb);
                    lcmp_result = self.builder.phi(i1_t, name="lcmp.eq.result");
                    lcmp_result.add_incoming(ir.Constant(i1_t, 1), lcmp_loop_bb);
                    lcmp_result.add_incoming(ir.Constant(i1_t, 0), lcmp_false_bb);
                    if op == Tok.NE {
                        return self.builder.not_(lcmp_result, name="lcmp.ne");
                    }
                    return lcmp_result;
                }
                # Lexicographic: <, >, <=, >=
                if op in (Tok.LT, Tok.GT, Tok.LTE, Tok.GTE) {
                    # min_len = min(la, lb)
                    lcmp_lt_len = self.builder.icmp_unsigned(
                        "<", lcmp_la, lcmp_lb, name="lcmp.lex.ltl"
                    );
                    lcmp_min = self.builder.select(
                        lcmp_lt_len, lcmp_la, lcmp_lb, name="lcmp.min"
                    );
                    lcmp_lex_loop = func.append_basic_block(name="lcmp.lex.loop");
                    lcmp_lex_body = func.append_basic_block(name="lcmp.lex.body");
                    lcmp_lex_lbody = func.append_basic_block(name="lcmp.lex.lbody");
                    lcmp_lex_next = func.append_basic_block(name="lcmp.lex.next");
                    lcmp_lex_after = func.append_basic_block(name="lcmp.lex.after");
                    lcmp_lex_true = func.append_basic_block(name="lcmp.lex.true");
                    lcmp_lex_false = func.append_basic_block(name="lcmp.lex.false");
                    lcmp_lex_done = func.append_basic_block(name="lcmp.lex.done");
                    self.builder.branch(lcmp_lex_loop);
                    self.builder.position_at_start(lcmp_lex_loop);
                    lcmp_li = self.builder.phi(i64, name="lcmp.lex.i");
                    lcmp_li.add_incoming(ir.Constant(i64, 0), lcmp_entry_bb);
                    lcmp_lend = self.builder.icmp_unsigned(
                        ">=", lcmp_li, lcmp_min, name="lcmp.lex.lend"
                    );
                    self.builder.cbranch(lcmp_lend, lcmp_lex_after, lcmp_lex_body);
                    self.builder.position_at_start(lcmp_lex_body);
                    lcmp_lea = self.builder.call(
                        lcmp_h["get"], [left, lcmp_li], name="lcmp.lex.ea"
                    );
                    lcmp_leb = self.builder.call(
                        lcmp_h["get"], [right, lcmp_li], name="lcmp.lex.eb"
                    );
                    if isinstance(lcmp_et, ir.IntType) {
                        lcmp_lex_lt = self.builder.icmp_signed(
                            "<", lcmp_lea, lcmp_leb, name="lcmp.lex.lt"
                        );
                        lcmp_lex_gt = self.builder.icmp_signed(
                            ">", lcmp_lea, lcmp_leb, name="lcmp.lex.gt"
                        );
                    } elif isinstance(lcmp_et, ir.DoubleType) {
                        lcmp_lex_lt = self.builder.fcmp_ordered(
                            "<", lcmp_lea, lcmp_leb, name="lcmp.lex.lt"
                        );
                        lcmp_lex_gt = self.builder.fcmp_ordered(
                            ">", lcmp_lea, lcmp_leb, name="lcmp.lex.gt"
                        );
                    } else {
                        lcmp_strcmp2 = self._get_or_declare_extern(
                            "strcmp", ir.IntType(32), [i8_ptr, i8_ptr]
                        );
                        lcmp_scmp2 = self.builder.call(
                            lcmp_strcmp2, [lcmp_lea, lcmp_leb], name="lcmp.lex.sc"
                        );
                        lcmp_zero32 = ir.Constant(ir.IntType(32), 0);
                        lcmp_lex_lt = self.builder.icmp_signed(
                            "<", lcmp_scmp2, lcmp_zero32, name="lcmp.lex.lt"
                        );
                        lcmp_lex_gt = self.builder.icmp_signed(
                            ">", lcmp_scmp2, lcmp_zero32, name="lcmp.lex.gt"
                        );
                    }
                    # For < and <=: ea < eb → True, ea > eb → False
                    # For > and >=: ea > eb → True, ea < eb → False
                    if op == Tok.LT or op == Tok.LTE {
                        self.builder.cbranch(lcmp_lex_lt, lcmp_lex_true, lcmp_lex_lbody);
                        self.builder.position_at_start(lcmp_lex_lbody);
                        self.builder.cbranch(
                            lcmp_lex_gt, lcmp_lex_false, lcmp_lex_next
                        );
                    } else {
                        self.builder.cbranch(lcmp_lex_gt, lcmp_lex_true, lcmp_lex_lbody);
                        self.builder.position_at_start(lcmp_lex_lbody);
                        self.builder.cbranch(
                            lcmp_lex_lt, lcmp_lex_false, lcmp_lex_next
                        );
                    }
                    self.builder.position_at_start(lcmp_lex_next);
                    lcmp_lni = self.builder.add(
                        lcmp_li, ir.Constant(i64, 1), name="lcmp.lni"
                    );
                    lcmp_li.add_incoming(lcmp_lni, lcmp_lex_next);
                    self.builder.branch(lcmp_lex_loop);
                    self.builder.position_at_start(lcmp_lex_after);
                    # All common elements equal: compare lengths
                    if op == Tok.LT {
                        lcmp_len_res = self.builder.icmp_unsigned(
                            "<", lcmp_la, lcmp_lb, name="lcmp.llen"
                        );
                    } elif op == Tok.GT {
                        lcmp_len_res = self.builder.icmp_unsigned(
                            ">", lcmp_la, lcmp_lb, name="lcmp.llen"
                        );
                    } elif op == Tok.LTE {
                        lcmp_len_res = self.builder.icmp_unsigned(
                            "<=", lcmp_la, lcmp_lb, name="lcmp.llen"
                        );
                    } else {
                        lcmp_len_res = self.builder.icmp_unsigned(
                            ">=", lcmp_la, lcmp_lb, name="lcmp.llen"
                        );
                    }
                    self.builder.cbranch(lcmp_len_res, lcmp_lex_true, lcmp_lex_false);
                    self.builder.position_at_start(lcmp_lex_true);
                    self.builder.branch(lcmp_lex_done);
                    self.builder.position_at_start(lcmp_lex_false);
                    self.builder.branch(lcmp_lex_done);
                    self.builder.position_at_start(lcmp_lex_done);
                    lcmp_lex_res = self.builder.phi(i1_t, name="lcmp.lex.res");
                    lcmp_lex_res.add_incoming(ir.Constant(i1_t, 1), lcmp_lex_true);
                    lcmp_lex_res.add_incoming(ir.Constant(i1_t, 0), lcmp_lex_false);
                    return lcmp_lex_res;
                }
                break;
            }
        }
        # Set comparison: detect set pointer types
        for (sk, st) in self.set_types.items() {
            if left.type == st.as_pointer() and right.type == st.as_pointer() {
                shelpers = self.set_helpers.get(sk);
                if shelpers is not None {
                    self._ensure_emitters();
                    _ctx = self._native_emit_ctx_class(pass_ref=self, type_key=sk);
                    _se = self._native_emitters.get("set");
                    if _se is not None {
                        i64 = ir.IntType(64);
                        i1_t = ir.IntType(1);
                        if op == Tok.LTE {
                            # a <= b: issubset(a, b)
                            sub_val = _se.emit_issubset(_ctx, left, [right]);
                            return self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="sle"
                            );
                        }
                        if op == Tok.GTE {
                            # a >= b: issubset(b, a)
                            sub_val = _se.emit_issubset(_ctx, right, [left]);
                            return self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="sge"
                            );
                        }
                        # ==, !=, <, > need length check + issubset
                        len_a = self.builder.call(
                            shelpers["len"], [left], name="scmp.la"
                        );
                        len_b = self.builder.call(
                            shelpers["len"], [right], name="scmp.lb"
                        );
                        if op == Tok.EE or op == Tok.NE {
                            # == : len(a)==len(b) and issubset(a,b)
                            len_eq = self.builder.icmp_unsigned(
                                "==", len_a, len_b, name="scmp.leq"
                            );
                            func = self.builder.basic_block.function;
                            check_bb = func.append_basic_block(name="scmp.check");
                            false_bb = func.append_basic_block(name="scmp.false");
                            done_bb = func.append_basic_block(name="scmp.done");
                            self.builder.cbranch(len_eq, check_bb, false_bb);
                            self.builder.position_at_start(check_bb);
                            sub_val = _se.emit_issubset(_ctx, left, [right]);
                            after_bb = self.builder.basic_block;
                            is_sub = self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="scmp.issub"
                            );
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(false_bb);
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(done_bb);
                            result = self.builder.phi(i1_t, name="scmp.result");
                            result.add_incoming(is_sub, after_bb);
                            result.add_incoming(ir.Constant(i1_t, 0), false_bb);
                            if op == Tok.NE {
                                return self.builder.not_(result, name="scmp.ne");
                            }
                            return result;
                        }
                        if op == Tok.LT {
                            # a < b: len(a) < len(b) and issubset(a, b)
                            len_lt = self.builder.icmp_unsigned(
                                "<", len_a, len_b, name="slt.lcmp"
                            );
                            func = self.builder.basic_block.function;
                            check_bb = func.append_basic_block(name="slt.check");
                            false_bb = func.append_basic_block(name="slt.false");
                            done_bb = func.append_basic_block(name="slt.done");
                            self.builder.cbranch(len_lt, check_bb, false_bb);
                            self.builder.position_at_start(check_bb);
                            sub_val = _se.emit_issubset(_ctx, left, [right]);
                            after_bb = self.builder.basic_block;
                            is_sub = self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="slt.issub"
                            );
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(false_bb);
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(done_bb);
                            result = self.builder.phi(i1_t, name="slt.result");
                            result.add_incoming(is_sub, after_bb);
                            result.add_incoming(ir.Constant(i1_t, 0), false_bb);
                            return result;
                        }
                        if op == Tok.GT {
                            # a > b: len(b) < len(a) and issubset(b, a)
                            len_gt = self.builder.icmp_unsigned(
                                "<", len_b, len_a, name="sgt.lcmp"
                            );
                            func = self.builder.basic_block.function;
                            check_bb = func.append_basic_block(name="sgt.check");
                            false_bb = func.append_basic_block(name="sgt.false");
                            done_bb = func.append_basic_block(name="sgt.done");
                            self.builder.cbranch(len_gt, check_bb, false_bb);
                            self.builder.position_at_start(check_bb);
                            sub_val = _se.emit_issubset(_ctx, right, [left]);
                            after_bb = self.builder.basic_block;
                            is_sub = self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="sgt.issub"
                            );
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(false_bb);
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(done_bb);
                            result = self.builder.phi(i1_t, name="sgt.result");
                            result.add_incoming(is_sub, after_bb);
                            result.add_incoming(ir.Constant(i1_t, 0), false_bb);
                            return result;
                        }
                    }
                }
                break;
            }
        }
        # Range comparison: JacRange* == / != JacRange*
        rtype_ptr = self.range_struct_type.as_pointer();
        if left.type == rtype_ptr
        and right.type == rtype_ptr
        and (op == Tok.EE or op == Tok.NE) {
            i1_t = ir.IntType(1);
            i32 = ir.IntType(32);
            z0 = ir.Constant(i32, 0);
            # Compare start, stop, step
            as_ = self.builder.load(
                self.builder.gep(left, [z0, ir.Constant(i32, 0)], name="rcmp.as.p"),
                name="rcmp.as"
            );
            bs_ = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 0)], name="rcmp.bs.p"),
                name="rcmp.bs"
            );
            ae = self.builder.load(
                self.builder.gep(left, [z0, ir.Constant(i32, 1)], name="rcmp.ae.p"),
                name="rcmp.ae"
            );
            be = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 1)], name="rcmp.be.p"),
                name="rcmp.be"
            );
            at = self.builder.load(
                self.builder.gep(left, [z0, ir.Constant(i32, 2)], name="rcmp.at.p"),
                name="rcmp.at"
            );
            bt = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 2)], name="rcmp.bt.p"),
                name="rcmp.bt"
            );
            seq = self.builder.icmp_signed("==", as_, bs_, name="rcmp.seq");
            eeq = self.builder.icmp_signed("==", ae, be, name="rcmp.eeq");
            teq = self.builder.icmp_signed("==", at, bt, name="rcmp.teq");
            result = self.builder.and_(
                seq, self.builder.and_(eeq, teq, name="rcmp.et"), name="rcmp.all"
            );
            if op == Tok.NE {
                return self.builder.not_(result, name="rcmp.ne");
            }
            return result;
        }
        # Complex comparison: JacComplex* == / != JacComplex*
        ctype_ptr = self.complex_struct_type.as_pointer();
        if left.type == ctype_ptr and right.type == ctype_ptr {
            i1_t = ir.IntType(1);
            i32 = ir.IntType(32);
            z0 = ir.Constant(i32, 0);
            z1 = ir.Constant(i32, 1);
            ar = self.builder.load(
                self.builder.gep(left, [z0, z0], name="ceq.ar.p"), name="ceq.ar"
            );
            ai = self.builder.load(
                self.builder.gep(left, [z0, z1], name="ceq.ai.p"), name="ceq.ai"
            );
            br = self.builder.load(
                self.builder.gep(right, [z0, z0], name="ceq.br.p"), name="ceq.br"
            );
            bi = self.builder.load(
                self.builder.gep(right, [z0, z1], name="ceq.bi.p"), name="ceq.bi"
            );
            req = self.builder.fcmp_ordered("==", ar, br, name="ceq.r");
            ieq = self.builder.fcmp_ordered("==", ai, bi, name="ceq.i");
            result = self.builder.and_(req, ieq, name="ceq.both");
            if op == Tok.EE {
                return result;
            } elif op == Tok.NE {
                return self.builder.not_(result, name="ceq.ne");
            }
        }
        # Tuple comparison: pointer to LiteralStructType with same pointee
        if isinstance(left.type.pointee, ir.LiteralStructType)
        and isinstance(right.type.pointee, ir.LiteralStructType)
        and str(left.type.pointee) == str(right.type.pointee) {
            struct_type = left.type.pointee;
            n = len(struct_type.elements);
            i1_t = ir.IntType(1);
            if op == Tok.EE or op == Tok.NE {
                # Element-wise equality: all elements must match
                result = ir.Constant(i1_t, 1);
                for i in range(n) {
                    ea_ptr = self.builder.gep(
                        left,
                        [
                            ir.Constant(ir.IntType(32), 0),
                            ir.Constant(ir.IntType(32), i)
                        ],
                        name=f"tcmp.a.{i}"
                    );
                    eb_ptr = self.builder.gep(
                        right,
                        [
                            ir.Constant(ir.IntType(32), 0),
                            ir.Constant(ir.IntType(32), i)
                        ],
                        name=f"tcmp.b.{i}"
                    );
                    ea = self.builder.load(ea_ptr, name=f"tcmp.ea.{i}");
                    eb = self.builder.load(eb_ptr, name=f"tcmp.eb.{i}");
                    if isinstance(ea.type, ir.IntType) {
                        eq_i = self.builder.icmp_signed(
                            "==", ea, eb, name=f"tcmp.eq.{i}"
                        );
                    } elif isinstance(ea.type, ir.DoubleType) {
                        eq_i = self.builder.fcmp_ordered(
                            "==", ea, eb, name=f"tcmp.eq.{i}"
                        );
                    } else {
                        tcmp_strcmp = self._get_or_declare_extern(
                            "strcmp", ir.IntType(32), [i8_ptr, i8_ptr]
                        );
                        tcmp_sc = self.builder.call(
                            tcmp_strcmp, [ea, eb], name=f"tcmp.sc.{i}"
                        );
                        eq_i = self.builder.icmp_signed(
                            "==",
                            tcmp_sc,
                            ir.Constant(ir.IntType(32), 0),
                            name=f"tcmp.eq.{i}"
                        );
                    }
                    result = self.builder.and_(result, eq_i, name=f"tcmp.all.{i}");
                }
                if op == Tok.NE {
                    return self.builder.not_(result, name="tcmp.ne");
                }
                return result;
            }
            # Lexicographic: <, >, <=, >=
            if op in (Tok.LT, Tok.GT, Tok.LTE, Tok.GTE) and n > 0 {
                # Cascade: check each element pair, return on first difference
                func = self.builder.basic_block.function;
                tcmp_true_bb = func.append_basic_block(name="tcmp.lex.true");
                tcmp_false_bb = func.append_basic_block(name="tcmp.lex.false");
                tcmp_done_bb = func.append_basic_block(name="tcmp.lex.done");
                for i in range(n) {
                    ea_ptr = self.builder.gep(
                        left,
                        [
                            ir.Constant(ir.IntType(32), 0),
                            ir.Constant(ir.IntType(32), i)
                        ],
                        name=f"tcmp.lex.a.{i}"
                    );
                    eb_ptr = self.builder.gep(
                        right,
                        [
                            ir.Constant(ir.IntType(32), 0),
                            ir.Constant(ir.IntType(32), i)
                        ],
                        name=f"tcmp.lex.b.{i}"
                    );
                    ea = self.builder.load(ea_ptr, name=f"tcmp.lex.ea.{i}");
                    eb = self.builder.load(eb_ptr, name=f"tcmp.lex.eb.{i}");
                    if isinstance(ea.type, ir.IntType) {
                        lt_i = self.builder.icmp_signed(
                            "<", ea, eb, name=f"tcmp.lt.{i}"
                        );
                        gt_i = self.builder.icmp_signed(
                            ">", ea, eb, name=f"tcmp.gt.{i}"
                        );
                    } elif isinstance(ea.type, ir.DoubleType) {
                        lt_i = self.builder.fcmp_ordered(
                            "<", ea, eb, name=f"tcmp.lt.{i}"
                        );
                        gt_i = self.builder.fcmp_ordered(
                            ">", ea, eb, name=f"tcmp.gt.{i}"
                        );
                    } else {
                        tcmp_strcmp2 = self._get_or_declare_extern(
                            "strcmp", ir.IntType(32), [i8_ptr, i8_ptr]
                        );
                        tcmp_sc2 = self.builder.call(
                            tcmp_strcmp2, [ea, eb], name=f"tcmp.lex.sc.{i}"
                        );
                        tcmp_z32 = ir.Constant(ir.IntType(32), 0);
                        lt_i = self.builder.icmp_signed(
                            "<", tcmp_sc2, tcmp_z32, name=f"tcmp.lt.{i}"
                        );
                        gt_i = self.builder.icmp_signed(
                            ">", tcmp_sc2, tcmp_z32, name=f"tcmp.gt.{i}"
                        );
                    }
                    next_bb = func.append_basic_block(name=f"tcmp.lex.next.{i}");
                    if op == Tok.LT or op == Tok.LTE {
                        self.builder.cbranch(lt_i, tcmp_true_bb, next_bb);
                        self.builder.position_at_start(next_bb);
                        next2_bb = func.append_basic_block(name=f"tcmp.lex.eq.{i}");
                        self.builder.cbranch(gt_i, tcmp_false_bb, next2_bb);
                        self.builder.position_at_start(next2_bb);
                    } else {
                        self.builder.cbranch(gt_i, tcmp_true_bb, next_bb);
                        self.builder.position_at_start(next_bb);
                        next2_bb = func.append_basic_block(name=f"tcmp.lex.eq.{i}");
                        self.builder.cbranch(lt_i, tcmp_false_bb, next2_bb);
                        self.builder.position_at_start(next2_bb);
                    }
                }
                # All elements equal: <= and >= are true, < and > are false
                if op == Tok.LTE or op == Tok.GTE {
                    self.builder.branch(tcmp_true_bb);
                } else {
                    self.builder.branch(tcmp_false_bb);
                }
                self.builder.position_at_start(tcmp_true_bb);
                self.builder.branch(tcmp_done_bb);
                self.builder.position_at_start(tcmp_false_bb);
                self.builder.branch(tcmp_done_bb);
                self.builder.position_at_start(tcmp_done_bb);
                tcmp_res = self.builder.phi(i1_t, name="tcmp.lex.res");
                tcmp_res.add_incoming(ir.Constant(i1_t, 1), tcmp_true_bb);
                tcmp_res.add_incoming(ir.Constant(i1_t, 0), tcmp_false_bb);
                return tcmp_res;
            }
        }
        # For other pointer types (structs, tuples), use pointer comparison
        if op == Tok.EE {
            return self.builder.icmp_unsigned("==", left, right, name="ptreq");
        } elif op == Tok.NE {
            return self.builder.icmp_unsigned("!=", left, right, name="ptrne");
        }
        return None;
    }
    if is_float {
        fcmp_map: dict[(str, str)] = {
            Tok.EE: "==",
            Tok.NE: "!=",
            Tok.LT: "<",
            Tok.GT: ">",
            Tok.LTE: "<=",
            Tok.GTE: ">="
        };
        if op in fcmp_map {
            return self.builder.fcmp_ordered(fcmp_map[op], left, right, name="fcmp");
        }
    } else {
        icmp_map: dict[(str, str)] = {
            Tok.EE: "==",
            Tok.NE: "!=",
            Tok.LT: "<",
            Tok.GT: ">",
            Tok.LTE: "<=",
            Tok.GTE: ">="
        };
        if op in icmp_map {
            return self.builder.icmp_signed(icmp_map[op], left, right, name="icmp");
        }
    }
    return None;
}

# ─── Phase 1: Enums ──────────────────────────────────────────
"""Infer the struct type name from an LLVM value's type."""
impl NaIRGenPass._infer_type_name(val: ir.Value) -> (str | None) {
    if not isinstance(val.type, ir.PointerType) {
        return None;
    }
    for (sname, stype) in self.struct_types.items() {
        if val.type == stype.as_pointer() {
            return sname;
        }
    }
    return None;
}

"""Infer the list element type name from an LLVM value's type."""
impl NaIRGenPass._infer_list_elem_type(val: ir.Value) -> (str | None) {
    if not isinstance(val.type, ir.PointerType) {
        return None;
    }
    for (ename, ltype) in self.list_types.items() {
        if val.type == ltype.as_pointer() {
            return ename;
        }
    }
    return None;
}

"""Peel one layer from a list type annotation: list[T] → (T_node, T_llvm_type, T_elem_type_name).
For list[list[int]], returns (ast_node_for_list[int], List.i64*, 'ptr').
For list[Piece|None], returns (ast_node_for_Piece|None, Piece*, 'ptr').
For list[int], returns (ast_node_for_int, i64, 'i64').
Returns (None, None, None) if not a list type."""
impl NaIRGenPass._peel_list_type(type_node: (object | None)) -> tuple {
    if type_node is None {
        return (None, None, None);
    }
    # Handle union: T | None → peel T
    if isinstance(type_node, uni.BinaryExpr) {
        op_val = getattr(type_node.op, 'value', '');
        if op_val == "|" {
            return self._peel_list_type(type_node.left);
        }
    }
    # Handle list[T] → return (T_node, resolve(T))
    if isinstance(type_node, uni.AtomTrailer) and not type_node.is_attr {
        target_name = self._get_name(type_node.target);
        if target_name == "list" {
            if type_node?.right and type_node.right?.slices {
                slices = type_node.right.slices or [];
                if slices {
                    elem_node = slices[0];
                    if elem_node?.start and elem_node.start is not None {
                        inner = elem_node.start;
                    } else {
                        inner = elem_node;
                    }
                    inner_type = self._resolve_jac_type(inner);
                    inner_elem_name = "i64";
                    if isinstance(inner_type, ir.DoubleType) {
                        inner_elem_name = "f64";
                    } elif isinstance(inner_type, ir.PointerType) {
                        inner_elem_name = "ptr";
                    }
                    return (inner, inner_type, inner_elem_name);
                }
            }
        }
    }
    return (None, None, None);
}

"""Get the list element type name from a Jac type annotation AST node.
Returns the elem_type_name string ('i64', 'f64', 'ptr') or None."""
impl NaIRGenPass._get_list_elem_from_type_node(
    type_node: (object | None)
) -> (str | None) {
    (inner, inner_type, elem_name) = self._peel_list_type(type_node);
    return elem_name;
}

"""Infer the struct type name of a comprehension loop variable from its collection.
For `for m in piece.raw_moves(self)`, returns 'Move' by looking up the method's
return type in method_ast_sigs and peeling the list type."""
impl NaIRGenPass._infer_compr_elem_struct(compr: object) -> (str | None) {
    collection = compr.collection;
    # Determine target and method name from the collection expression.
    # Two AST shapes for method calls:
    #   1. FuncCall(target=AtomTrailer(target=obj, right=method, is_attr=True), params=[...])
    #   2. AtomTrailer(target=obj, right=FuncCall(target=method, ...), is_attr=False)
    target_name: (str | None) = None;
    method_name: (str | None) = None;
    if isinstance(collection, uni.FuncCall) {
        if isinstance(collection.target, uni.AtomTrailer)
        and collection.target.is_attr {
            target_name = self._get_name(collection.target.target);
            method_name = self._get_name(collection.target.right);
        }
    } elif isinstance(collection, uni.AtomTrailer) and not collection.is_attr {
        target_name = self._get_name(collection.target);
        if isinstance(collection.right, uni.FuncCall) {
            method_name = self._get_name(collection.right.target);
        } else {
            method_name = self._get_name(collection.right);
        }
    }
    if target_name is None or method_name is None {
        # Fallback: if collection is a simple variable (Name node), try to
        # resolve its list element type from the variable's type annotation
        coll_name = self._get_name(collection);
        if coll_name is not None {
            # Check var_type_node for type annotation like list[Move]
            type_node = self.var_type_node.get(coll_name);
            if type_node is not None {
                (inner, _, _) = self._peel_list_type(type_node);
                if inner is not None {
                    inner_name = self._get_name(inner);
                    if inner_name is not None and inner_name in self.struct_types {
                        return inner_name;
                    }
                }
            }
            # Check var_list_elem_type for computed element type name
            elem_type = self.var_list_elem_type.get(coll_name);
            if elem_type is not None and elem_type in self.struct_types {
                return elem_type;
            }
        }
        return None;
    }
    # Look up the struct type for target variable
    type_name = self.type_var_map.get(target_name);
    if type_name is None {
        if target_name in self.local_vars {
            lv = self.local_vars[target_name];
            if isinstance(lv.type, ir.PointerType) {
                pointee = lv.type.pointee;
                for (sname, stype) in self.struct_types.items() {
                    if pointee == stype.as_pointer() {
                        type_name = sname;
                        break;
                    }
                }
            }
        }
    }
    if type_name is None {
        return None;
    }
    # Walk hierarchy to find method signature and extract return element type
    check = type_name;
    while check is not None {
        full = f"{check}.{method_name}";
        if full in self.method_ast_sigs {
            sig = self.method_ast_sigs[full];
            ret_type = getattr(sig, 'return_type', None);
            if ret_type is not None {
                (inner, _, _) = self._peel_list_type(ret_type);
                if inner is not None {
                    inner_name = self._get_name(inner);
                    if inner_name is not None and inner_name in self.struct_types {
                        return inner_name;
                    }
                }
            }
            break;
        }
        check = self.class_hierarchy.get(check);
    }
    return None;
}

"""Resolve the LLVM type of elements in a ptr list for a for-loop variable.
Uses Jac type annotations (var_type_node or field_type_node) to determine
what i8* elements should be bitcast to."""
impl NaIRGenPass._resolve_for_loop_elem_type(
    coll_name: (str | None), coll_node: (object | None)
) -> (ir.Type | None) {
    # Check variable type annotation first
    type_node: (object | None) = None;
    if coll_name is not None and coll_name in self.var_type_node {
        type_node = self.var_type_node[coll_name];
    }
    if type_node is not None {
        (inner, inner_type, inner_elem) = self._peel_list_type(type_node);
        if inner_type is not None {
            return inner_type;
        }
    }
    return None;
}

"""Resolve the LLVM type that ptr list elements should be bitcast to,
given a Jac type AST node for the list variable/field.
For list[list[int]], returns List.i64* (the type of each element).
For list[Piece|None], returns Piece* (the type of each element)."""
impl NaIRGenPass._resolve_ptr_elem_cast_type(
    type_node: (object | None)
) -> (ir.Type | None) {
    if type_node is None {
        return None;
    }
    (inner, inner_type, inner_elem) = self._peel_list_type(type_node);
    if inner_type is not None and isinstance(inner_type, ir.PointerType) {
        return inner_type;
    }
    return None;
}
# ─── Phase 7: String Methods and Builtins ─────────────────────
