"""Expression codegen: binary, unary, comparisons, bool expressions."""
"""Generate IR for an expression, returning the resulting value."""
impl NaIRGenPass._codegen_expr(nd: (uni.UniNode | None)) -> (ir.Value | None) {
    if nd is None {
        return None;
    }
    if isinstance(nd, uni.Int) {
        # Handle hex, octal, binary literals based on name attribute
        tok_name = nd?.name;
        if tok_name == Tok.HEX {
            return ir.Constant(ir.IntType(64), int(nd.value, 16));
        } elif tok_name == Tok.OCT {
            return ir.Constant(ir.IntType(64), int(nd.value, 8));
        } elif tok_name == Tok.BIN {
            return ir.Constant(ir.IntType(64), int(nd.value, 2));
        } else {
            return ir.Constant(ir.IntType(64), int(nd.value, 0));
        }
    }
    if isinstance(nd, uni.Float) {
        return ir.Constant(ir.DoubleType(), float(nd.value));
    }
    if isinstance(nd, uni.Bool) {
        val = 1 if nd.value.lower() in ("true", "1") else 0;
        return ir.Constant(ir.IntType(1), val);
    }
    if isinstance(nd, uni.Null) {
        return ir.Constant(ir.IntType(8).as_pointer(), None);
    }
    if isinstance(nd, uni.Name) {
        return self._codegen_name(nd);
    }
    if isinstance(nd, uni.BinaryExpr) {
        return self._codegen_binary(nd);
    }
    if isinstance(nd, uni.CompareExpr) {
        return self._codegen_compare(nd);
    }
    if isinstance(nd, uni.UnaryExpr) {
        return self._codegen_unary(nd);
    }
    if isinstance(nd, uni.FuncCall) {
        return self._codegen_call(nd);
    }
    if isinstance(nd, uni.AtomTrailer) {
        return self._codegen_atom_trailer(nd);
    }
    if isinstance(nd, uni.BoolExpr) {
        return self._codegen_bool_expr(nd);
    }
    if isinstance(nd, uni.IfElseExpr) {
        return self._codegen_if_else_expr(nd);
    }
    if isinstance(nd, uni.MultiString) {
        return self._codegen_multistring(nd);
    }
    if isinstance(nd, uni.String) {
        return self._codegen_string(nd);
    }
    if isinstance(nd, uni.FString) {
        return self._codegen_fstring(nd);
    }
    if isinstance(nd, uni.ListVal) {
        return self._codegen_list_val(nd);
    }
    # Check dict and set comprehensions BEFORE list comprehension
    # (DictCompr and SetCompr do NOT inherit from ListCompr)
    if isinstance(nd, uni.DictCompr) {
        return self._codegen_dict_compr(nd);
    }
    if isinstance(nd, uni.SetCompr) {
        return self._codegen_set_compr(nd);
    }
    if isinstance(nd, uni.ListCompr) {
        return self._codegen_list_compr(nd);
    }
    if isinstance(nd, uni.TupleVal) {
        return self._codegen_tuple_val(nd);
    }
    if isinstance(nd, uni.DictVal) {
        return self._codegen_dict_val(nd);
    }
    if isinstance(nd, uni.SetVal) {
        return self._codegen_set_val(nd);
    }
    # Handle parenthesized expressions: (expr) → AtomUnit
    if isinstance(nd, uni.AtomUnit) {
        return self._codegen_expr(nd.value);
    }
    return None;
}

"""Load a variable or return a function reference."""
impl NaIRGenPass._codegen_name(nd: uni.Name) -> (ir.Value | None) {
    var_name = nd.value;
    if var_name in self.local_vars {
        alloca = self.local_vars[var_name];
        # Set type node hint for subsequent chained access
        if var_name in self.var_type_node {
            self._last_type_node_hint = self.var_type_node[var_name];
        }
        return self.builder.load(alloca, name=var_name);
    }
    if var_name in self.func_symtab {
        return self.func_symtab[var_name];
    }
    # Check global variables
    if var_name in self.global_vars {
        global_var = self.global_vars[var_name];
        return self.builder.load(global_var, name=f"glob.{var_name}");
    }
    return None;
}

"""Generate binary expression."""
impl NaIRGenPass._codegen_binary(nd: uni.BinaryExpr) -> (ir.Value | None) {
    left = self._codegen_expr(nd.left);
    right = self._codegen_expr(nd.right);
    if left is None or right is None {
        return None;
    }
    op = nd.op.name if isinstance(nd.op, uni.Token) else str(nd.op);
    return self._emit_binary_op(op, left, right);
}

"""Generate comparison expression."""
impl NaIRGenPass._codegen_compare(nd: uni.CompareExpr) -> (ir.Value | None) {
    left = self._codegen_expr(nd.left);
    if left is None or not nd.rights or not nd.ops {
        return None;
    }
    right = self._codegen_expr(nd.rights[0]);
    if right is None {
        return None;
    }
    op = nd.ops[0].name if isinstance(nd.ops[0], uni.Token) else str(nd.ops[0]);
    # Handle "in" operator for dicts and sets: left in right
    if op == Tok.KW_IN or op == Tok.KW_NIN {
        is_not_in = op == Tok.KW_NIN;
        # Check if right is a dict
        for (dict_key, helpers) in self.dict_helpers.items() {
            dict_type = self.dict_types.get(dict_key);
            if dict_type is not None and right.type == dict_type.as_pointer() {
                key_type = helpers["key_type"];
                left_coerced = self._coerce_type(left, key_type);
                result = self.builder.call(
                    helpers["contains"], [right, left_coerced], name="dict.contains"
                );
                # Extend i1 result to i64 for consistency
                result = self.builder.zext(result, ir.IntType(64), name="contains.i64");
                if is_not_in {
                    result = self.builder.icmp_signed(
                        "==", result, ir.Constant(ir.IntType(64), 0), name="not.in"
                    );
                    result = self.builder.zext(
                        result, ir.IntType(64), name="notin.i64"
                    );
                }
                return result;
            }
        }
        # Check if right is a set
        for (set_key, helpers) in self.set_helpers.items() {
            set_type = self.set_types.get(set_key);
            if set_type is not None and right.type == set_type.as_pointer() {
                elem_type = helpers["elem_type"];
                left_coerced = self._coerce_type(left, elem_type);
                result = self.builder.call(
                    helpers["contains"], [right, left_coerced], name="set.contains"
                );
                result = self.builder.zext(result, ir.IntType(64), name="contains.i64");
                if is_not_in {
                    result = self.builder.icmp_signed(
                        "==", result, ir.Constant(ir.IntType(64), 0), name="not.in"
                    );
                    result = self.builder.zext(
                        result, ir.IntType(64), name="notin.i64"
                    );
                }
                return result;
            }
        }
        return None;
    }
    # Handle identity operators: is / is not (pointer comparison)
    if op == Tok.KW_IS {
        # Coerce both to same pointer type for comparison
        if isinstance(left.type, ir.PointerType)
        and isinstance(right.type, ir.PointerType) {
            if left.type != right.type {
                right = self.builder.bitcast(right, left.type);
            }
            return self.builder.icmp_unsigned("==", left, right, name="is.eq");
        }
        return self._to_bool(left);
    }
    if op == Tok.KW_ISN {
        if isinstance(left.type, ir.PointerType)
        and isinstance(right.type, ir.PointerType) {
            if left.type != right.type {
                right = self.builder.bitcast(right, left.type);
            }
            return self.builder.icmp_unsigned("!=", left, right, name="is.ne");
        }
        return self._to_bool(left);
    }
    is_float = isinstance(left.type, ir.DoubleType)
    or isinstance(right.type, ir.DoubleType);
    if is_float {
        (left, right) = self._promote_to_float(left, right);
    }
    return self._emit_comparison(op, left, right, is_float);
}

"""Generate unary expression."""
impl NaIRGenPass._codegen_unary(nd: uni.UnaryExpr) -> (ir.Value | None) {
    operand = self._codegen_expr(nd.operand);
    if operand is None {
        return None;
    }
    op = nd.op.name if isinstance(nd.op, uni.Token) else str(nd.op);
    if op == Tok.MINUS {
        if isinstance(operand.type, ir.DoubleType) {
            return self.builder.fneg(operand, name="fneg");
        } elif isinstance(operand.type, ir.IntType) {
            return self.builder.neg(operand, name="neg");
        }
    } elif op == Tok.NOT {
        if isinstance(operand.type, ir.IntType) and operand.type.width == 1 {
            return self.builder.not_(operand, name="not");
        } elif isinstance(operand.type, ir.IntType) {
            zero = ir.Constant(operand.type, 0);
            return self.builder.icmp_signed("==", operand, zero, name="not");
        }
    } elif op == Tok.BW_NOT {
        # Bitwise NOT: ~x = x XOR -1 (all 1s)
        if isinstance(operand.type, ir.IntType) {
            all_ones = ir.Constant(operand.type, -1);
            return self.builder.xor(operand, all_ones, name="bwnot");
        }
    }
    return None;
}

"""Generate short-circuit boolean and/or expression."""
impl NaIRGenPass._codegen_bool_expr(nd: uni.BoolExpr) -> (ir.Value | None) {
    if not nd.values {
        return None;
    }
    op_name = nd.op.name if isinstance(nd.op, uni.Token) else str(nd.op);
    is_and = op_name == Tok.KW_AND;
    # Evaluate first operand
    result = self._codegen_expr(nd.values[0]);
    if result is None {
        return None;
    }
    result = self._to_bool(result);
    # Short-circuit chain for remaining operands
    for i in range(1, len(nd.values)) {
        func = self.builder.function;
        rhs_bb = func.append_basic_block(name=f"bool.rhs.{i}");
        merge_bb = func.append_basic_block(name=f"bool.merge.{i}");
        entry_bb = self.builder.block;
        if is_and {
            # AND: if first is false, skip rest (result = false)
            self.builder.cbranch(result, rhs_bb, merge_bb);
        } else {
            # OR: if first is true, skip rest (result = true)
            self.builder.cbranch(result, merge_bb, rhs_bb);
        }
        # RHS block
        self.builder.position_at_end(rhs_bb);
        rhs_val = self._codegen_expr(nd.values[i]);
        if rhs_val is None {
            rhs_val = ir.Constant(ir.IntType(1), 0);
        }
        rhs_val = self._to_bool(rhs_val);
        rhs_end_bb = self.builder.block;
        if not self.builder.block.is_terminated {
            self.builder.branch(merge_bb);
        }
        # Merge block with phi
        self.builder.position_at_end(merge_bb);
        phi = self.builder.phi(ir.IntType(1), name="bool.result");
        if is_and {
            phi.add_incoming(ir.Constant(ir.IntType(1), 0), entry_bb);
        } else {
            phi.add_incoming(ir.Constant(ir.IntType(1), 1), entry_bb);
        }
        phi.add_incoming(rhs_val, rhs_end_bb);
        result = phi;
    }
    return result;
}

# ─── Phase 1: Break / Continue ───────────────────────────────
"""Generate ternary expression: value if condition else else_value."""
impl NaIRGenPass._codegen_if_else_expr(nd: uni.IfElseExpr) -> (ir.Value | None) {
    cond = self._codegen_expr(nd.condition);
    if cond is None {
        return None;
    }
    cond = self._to_bool(cond);
    func = self.builder.function;
    then_bb = func.append_basic_block(name="ternary.then");
    else_bb = func.append_basic_block(name="ternary.else");
    merge_bb = func.append_basic_block(name="ternary.end");
    self.builder.cbranch(cond, then_bb, else_bb);
    # Then
    self.builder.position_at_end(then_bb);
    then_val = self._codegen_expr(nd.value);
    then_end_bb = self.builder.block;
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }
    # Else
    self.builder.position_at_end(else_bb);
    else_val = self._codegen_expr(nd.else_value);
    else_end_bb = self.builder.block;
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }
    # Merge with phi
    self.builder.position_at_end(merge_bb);
    if then_val is not None and else_val is not None {
        # Coerce both to same type
        if then_val.type != else_val.type {
            if isinstance(then_val.type, ir.DoubleType)
            or isinstance(else_val.type, ir.DoubleType) {
                (then_val, else_val) = self._promote_to_float(then_val, else_val);
            }
        }
        phi = self.builder.phi(then_val.type, name="ternary.result");
        phi.add_incoming(then_val, then_end_bb);
        phi.add_incoming(else_val, else_end_bb);
        return phi;
    }
    return None;
}

# ─── Phase 2: Strings ────────────────────────────────────────
"""Generate code for attribute/subscript access (e.g. Color.WHITE, self.x)."""
impl NaIRGenPass._codegen_atom_trailer(nd: uni.AtomTrailer) -> (ir.Value | None) {
    if nd.is_attr {
        target_name = self._get_name(nd.target);
        right_name = self._get_name(nd.right);
        if target_name is not None and right_name is not None {
            # Check enum member access: Color.WHITE
            full_name = f"{target_name}.{right_name}";
            if full_name in self.enum_values {
                return self.enum_values[full_name];
            }
            # Check field access on a known-type variable: self.x, p.x
            if target_name in self.type_var_map {
                type_name = self.type_var_map[target_name];
                obj_val = self._codegen_expr(nd.target);
                if obj_val is not None {
                    result = self._codegen_field_access(obj_val, right_name, type_name);
                    # Set type node hint for chained access
                    if type_name in self.field_type_node {
                        self._last_type_node_hint = self.field_type_node[type_name].get(
                            right_name
                        );
                    }
                    return result;
                }
            }
        }
        # Chained field access: expr.field where expr is a complex expression
        if right_name is not None {
            obj_val = self._codegen_expr(nd.target);
            if obj_val is not None {
                type_name = self._infer_type_name(obj_val);
                if type_name is not None {
                    result = self._codegen_field_access(obj_val, right_name, type_name);
                    if type_name in self.field_type_node {
                        self._last_type_node_hint = self.field_type_node[type_name].get(
                            right_name
                        );
                    }
                    return result;
                }
            }
        }
    }
    # Handle index access: items[i] or expr[i]
    if not nd.is_attr and nd.right?.slices {
        target_name = self._get_name(nd.target);
        # Simple name: use tracked list type
        if target_name is not None and target_name in self.var_list_elem_type {
            elem_type_name = self.var_list_elem_type[target_name];
            target_val = self._codegen_expr(nd.target);
            if target_val is not None {
                slices = nd.right.slices or [];
                if slices {
                    idx_node = slices[0];
                    idx_val = self._codegen_expr(idx_node);
                    if idx_val is None and idx_node?.start {
                        idx_val = self._codegen_expr(idx_node.start);
                    }
                    if idx_val is not None {
                        result = self._codegen_index(
                            target_val, idx_val, elem_type_name
                        );
                        # Bitcast ptr list elements to correct inner type
                        if result is not None and elem_type_name == "ptr" {
                            var_tn = self.var_type_node.get(target_name);
                            cast_type = self._resolve_ptr_elem_cast_type(var_tn);
                            if cast_type is not None and result.type != cast_type {
                                result = self.builder.bitcast(
                                    result, cast_type, name="idx.cast"
                                );
                            }
                            # Propagate inner type node for further chaining
                            if var_tn is not None {
                                (inner_node, inner_llvm, inner_elem) = self._peel_list_type(
                                    var_tn
                                );
                                self._last_type_node_hint = inner_node;
                            }
                        }
                        return result;
                    }
                }
            }
        } else {
            # Chained index: evaluate target expression, infer list type or string
            # Capture the type node hint before evaluating (set by field access in chain)
            pre_type_hint = self._last_type_node_hint;
            self._last_type_node_hint = None;
            target_val = self._codegen_expr(nd.target);
            # Grab the hint set during target evaluation (e.g. field access sets it)
            chain_type_hint = self._last_type_node_hint;
            if chain_type_hint is None {
                chain_type_hint = pre_type_hint;
            }
            if target_val is not None {
                # Check for string indexing: s[i] (only real i8* strings, not list ptrs)
                i8p = ir.IntType(8).as_pointer();
                if target_val.type == i8p {
                    # If chain type hint indicates this is a list, don't string-index
                    is_list_from_hint = (
                        chain_type_hint is not None
                        and self._get_list_elem_from_type_node(chain_type_hint) is not None
                    );
                    inner_target_name = self._get_name(nd.target)
                    if isinstance(nd.target, uni.Name)
                    else None;
                    is_known_list = (
                        inner_target_name is not None
                        and inner_target_name in self.var_list_elem_type
                    );
                    if not is_known_list and not is_list_from_hint {
                        slices = nd.right.slices or [];
                        if slices {
                            idx_node = slices[0];
                            idx_val = self._codegen_expr(idx_node);
                            if idx_val is None and idx_node?.start {
                                idx_val = self._codegen_expr(idx_node.start);
                            }
                            if idx_val is not None {
                                return self._codegen_string_index(target_val, idx_val);
                            }
                        }
                    }
                }
                # Check for list indexing (works with properly-typed List.T* pointers)
                elem_type_name = self._infer_list_elem_type(target_val);
                if elem_type_name is not None {
                    slices = nd.right.slices or [];
                    if slices {
                        idx_node = slices[0];
                        idx_val = self._codegen_expr(idx_node);
                        if idx_val is None and idx_node?.start {
                            idx_val = self._codegen_expr(idx_node.start);
                        }
                        if idx_val is not None {
                            result = self._codegen_index(
                                target_val, idx_val, elem_type_name
                            );
                            # Bitcast ptr list elements using chain type hint
                            if result is not None
                            and elem_type_name == "ptr"
                            and chain_type_hint is not None {
                                cast_type = self._resolve_ptr_elem_cast_type(
                                    chain_type_hint
                                );
                                if cast_type is not None and result.type != cast_type {
                                    result = self.builder.bitcast(
                                        result, cast_type, name="chain.idx.cast"
                                    );
                                }
                                # Propagate inner type node for further chaining
                                (inner_node, inner_llvm, inner_elem) = self._peel_list_type(
                                    chain_type_hint
                                );
                                self._last_type_node_hint = inner_node;
                            }
                            return result;
                        }
                    }
                }
                # Check for tuple indexing (pointer to LiteralStructType)
                if isinstance(target_val.type, ir.PointerType) {
                    pointee = target_val.type.pointee;
                    if isinstance(pointee, ir.LiteralStructType) {
                        slices = nd.right.slices or [];
                        if slices {
                            idx_node = slices[0];
                            idx_val = self._codegen_expr(idx_node);
                            if idx_val is None and idx_node?.start {
                                idx_val = self._codegen_expr(idx_node.start);
                            }
                            if idx_val is not None {
                                return self._codegen_tuple_index(
                                    target_val, idx_val, pointee
                                );
                            }
                        }
                    }
                }
                # Check for dict indexing
                dict_type_info = self._infer_dict_type(target_val);
                if dict_type_info is not None {
                    (key_type_name, val_type_name) = dict_type_info;
                    slices = nd.right.slices or [];
                    if slices {
                        idx_node = slices[0];
                        key_val = self._codegen_expr(idx_node);
                        if key_val is None and idx_node?.start {
                            key_val = self._codegen_expr(idx_node.start);
                        }
                        if key_val is not None {
                            return self._codegen_dict_access(
                                target_val, key_val, key_type_name, val_type_name
                            );
                        }
                    }
                }
            }
        }
        # Check for named dict access: d[key] where d is a known dict variable
        if target_name is not None and target_name in self.var_dict_type {
            dict_type_key = self.var_dict_type[target_name];
            parts = dict_type_key.split(":");
            if len(parts) == 2 {
                (key_type_name, val_type_name) = (parts[0], parts[1]);
                target_val = self._codegen_expr(nd.target);
                if target_val is not None {
                    slices = nd.right.slices or [];
                    if slices {
                        idx_node = slices[0];
                        key_val = self._codegen_expr(idx_node);
                        if key_val is None and idx_node?.start {
                            key_val = self._codegen_expr(idx_node.start);
                        }
                        if key_val is not None {
                            return self._codegen_dict_access(
                                target_val, key_val, key_type_name, val_type_name
                            );
                        }
                    }
                }
            }
        }
    }
    return None;
}

"""Infer dict type info from an LLVM value. Returns (key_type_name, val_type_name) or None."""
impl NaIRGenPass._infer_dict_type(val: ir.Value) -> (tuple | None) {
    if not isinstance(val.type, ir.PointerType) {
        return None;
    }
    for (dict_key, dtype) in self.dict_types.items() {
        if val.type == dtype.as_pointer() {
            parts = dict_key.split(":");
            if len(parts) == 2 {
                return (parts[0], parts[1]);
            }
        }
    }
    return None;
}
# ─── Phase 1: Boolean Expressions (short-circuit) ────────────
