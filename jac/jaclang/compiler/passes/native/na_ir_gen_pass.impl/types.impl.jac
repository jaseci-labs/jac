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
                    if isinstance(key_type, ir.DoubleType) {
                        key_type_name = "f64";
                    } elif isinstance(key_type, ir.PointerType) {
                        key_type_name = "ptr";
                    }
                    val_type_name = "i64";
                    if isinstance(val_type, ir.DoubleType) {
                        val_type_name = "f64";
                    } elif isinstance(val_type, ir.PointerType) {
                        val_type_name = "ptr";
                    }
                    dict_key = f"{key_type_name}:{val_type_name}";
                    self._emit_dict_helpers(
                        key_type_name, val_type_name, key_type, val_type
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
    # Try expr_type string
    if type_expr?.expr_type and type_expr.expr_type in self.type_map {
        return self.type_map[type_expr.expr_type];
    }
    return ir.IntType(64);
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
    return val;
}

"""Coerce a value to the target type if needed."""
impl NaIRGenPass._coerce_type(val: ir.Value, target_type: ir.Type) -> ir.Value {
    if val.type == target_type {
        return val;
    }
    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.DoubleType) {
        return self.builder.sitofp(val, target_type, name="cast");
    }
    if isinstance(val.type, ir.DoubleType) and isinstance(target_type, ir.IntType) {
        return self.builder.fptosi(val, target_type, name="cast");
    }
    # Pointer-to-pointer bitcast (e.g., different struct pointer types)
    if isinstance(val.type, ir.PointerType) and isinstance(target_type, ir.PointerType) {
        return self.builder.bitcast(val, target_type, name="ptrcast");
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
    if op == Tok.PLUS
    and isinstance(left.type, ir.PointerType)
    and isinstance(right.type, ir.PointerType) {
        strlen_fn = self._get_or_declare_extern(
            "strlen", ir.IntType(64), [ir.IntType(8).as_pointer()]
        );
        gc_malloc = self._get_or_declare_extern(
            "GC_malloc", ir.IntType(8).as_pointer(), [ir.IntType(64)]
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
        buf = self.builder.call(gc_malloc, [buf_size], name="concat.buf");
        self.builder.call(strcpy_fn, [buf, left]);
        self.builder.call(strcat_fn, [buf, right]);
        return buf;
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
    if isinstance(left.type, ir.PointerType) and isinstance(right.type, ir.PointerType) {
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
            }
            return None;
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
