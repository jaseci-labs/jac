"""Statement codegen: if, while, for, assignment, control flow."""
"""Generate IR for a sequence of statements."""
impl NaIRGenPass._codegen_body(stmts: (list | tuple)) -> None {
    for stmt in stmts {
        if self.builder.block.is_terminated {
            break;
        }
        self._codegen_stmt(stmt);
    }
}

"""Generate IR for a single statement."""
impl NaIRGenPass._codegen_stmt(node: uni.UniNode) -> None {
    if self.builder is None or self.builder.block.is_terminated {
        return;
    }
    if isinstance(node, uni.ReturnStmt) {
        self._codegen_return(node);
    } elif isinstance(node, uni.IfStmt) {
        self._codegen_if(node);
    } elif isinstance(node, uni.WhileStmt) {
        self._codegen_while(node);
    } elif isinstance(node, uni.InForStmt) {
        self._codegen_for(node);
    } elif isinstance(node, uni.Assignment) {
        self._codegen_assignment(node);
    } elif isinstance(node, uni.CtrlStmt) {
        self._codegen_ctrl(node);
    } elif isinstance(node, uni.ExprStmt) {
        self._codegen_expr(node.expr);
    } elif isinstance(node, uni.TryStmt) {
        self._codegen_try(node);
    } elif isinstance(node, uni.RaiseStmt) {
        self._codegen_raise(node);
    } elif isinstance(node, uni.WithStmt) {
        self._codegen_with(node);
    } elif isinstance(node, uni.AssertStmt) {
        # AssertionError: evaluate condition, raise if false
        cond = self._codegen_expr(node.condition);
        if cond is not None {
            cond_bool = self._to_bool(cond);
            # assert fires when condition is FALSE
            is_false = self.builder.not_(cond_bool, name="assert.fail");
            self._emit_runtime_raise(is_false, "AssertionError", "assertion failed");
        }
    }
}

"""Generate return statement."""
impl NaIRGenPass._codegen_return(node: uni.ReturnStmt) -> None {
    func_ret_type = self.builder.function.return_value.type;
    if node.expr is not None {
        # Set list type hint from function return type for list comprehensions
        self._list_type_hint = None;
        if isinstance(func_ret_type, ir.PointerType) {
            # Check if return type is a list type
            ret_type_name = str(func_ret_type.pointee);
            if ret_type_name.startswith("%\"List.") {
                # Extract element type from list type name
                # e.g., %"List.ptr" -> "ptr", %"List.i64" -> "i64"
                elem_type = ret_type_name[7:-1]
                if ret_type_name.endswith("\"")
                else ret_type_name[7:];
                self._list_type_hint = elem_type;
            }
        }
        val = self._codegen_expr(node.expr);
        self._list_type_hint = None;
        if val is not None {
            val = self._coerce_type(val, func_ret_type);
            self.builder.ret(val);
            return;
        }
    }
    # Fallback: return appropriate default value based on return type
    if isinstance(func_ret_type, ir.VoidType) {
        self.builder.ret_void();
    } elif isinstance(func_ret_type, ir.PointerType) {
        self.builder.ret(ir.Constant(func_ret_type, None));
    } else {
        self.builder.ret(ir.Constant(func_ret_type, 0));
    }
}

"""Generate if/else/elif statement with proper basic blocks."""
impl NaIRGenPass._codegen_if(node: uni.IfStmt) -> None {
    cond = self._codegen_expr(node.condition);
    if cond is None {
        return;
    }
    # Ensure condition is i1 (bool)
    cond = self._to_bool(cond);
    func = self.builder.function;
    then_bb = func.append_basic_block(name="if.then");
    else_bb = func.append_basic_block(name="if.else");
    merge_bb = func.append_basic_block(name="if.end");
    self.builder.cbranch(cond, then_bb, else_bb);
    # Then block
    self.builder.position_at_end(then_bb);
    if isinstance(node.body, (<>list, <>tuple)) {
        self._codegen_body(node.body);
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }
    # Else block
    self.builder.position_at_end(else_bb);
    if node.else_body is not None {
        if isinstance(node.else_body, uni.ElseIf) {
            self._codegen_if(node.else_body);
        } elif isinstance(node.else_body, uni.ElseStmt) {
            if isinstance(node.else_body.body, (<>list, <>tuple)) {
                self._codegen_body(node.else_body.body);
            }
        }
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }
    self.builder.position_at_end(merge_bb);
}

"""Generate while loop with proper basic blocks."""
impl NaIRGenPass._codegen_while(node: uni.WhileStmt) -> None {
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="while.cond");
    body_bb = func.append_basic_block(name="while.body");
    end_bb = func.append_basic_block(name="while.end");
    # Jump to condition check
    self.builder.branch(cond_bb);
    # Condition block
    self.builder.position_at_end(cond_bb);
    cond = self._codegen_expr(node.condition);
    if cond is not None {
        cond = self._to_bool(cond);
        self.builder.cbranch(cond, body_bb, end_bb);
    } else {
        self.builder.branch(end_bb);
    }
    # Body block — push loop context for break/continue
    self.loop_stack.append((cond_bb, end_bb));
    self.builder.position_at_end(body_bb);
    if isinstance(node.body, (<>list, <>tuple)) {
        self._codegen_body(node.body);
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(cond_bb);
    }
    self.loop_stack.pop();
    # Continue after loop
    self.builder.position_at_end(end_bb);
}

"""Generate assignment statement."""
impl NaIRGenPass._codegen_assignment(node: uni.Assignment) -> None {
    # Set list type hint from context before evaluating expression
    # This helps _codegen_list_val create the correct empty list type
    self._list_type_hint = None;
    # 1. From explicit type annotation: var: list[T] = []
    if node.type_tag and node.type_tag.tag {
        hint = self._get_list_elem_from_type_node(node.type_tag.tag);
        if hint is not None {
            self._list_type_hint = hint;
        }
    }
    # 2. From field target: self.field = [] where field has known list type
    if self._list_type_hint is None {
        check_targets = node.target
        if isinstance(node.target, (<>list, <>tuple))
        else [(node.target)];
        for ct in check_targets {
            if isinstance(ct, uni.AtomTrailer) and ct.is_attr {
                ct_target_name = self._get_name(ct.target);
                ct_field_name = self._get_name(ct.right);
                if ct_target_name is not None and ct_field_name is not None {
                    ct_type_name = self.type_var_map.get(ct_target_name);
                    if ct_type_name is not None
                    and ct_type_name in self.field_type_node {
                        ftn = self.field_type_node[ct_type_name].get(ct_field_name);
                        if ftn is not None {
                            hint = self._get_list_elem_from_type_node(ftn);
                            if hint is not None {
                                self._list_type_hint = hint;
                            }
                        }
                    }
                }
            }
        }
    }
    value = self._codegen_expr(node.value) if node.value else None;
    self._list_type_hint = None;
    # Handle empty dict literal {} with type annotation
    if value is None and isinstance(node.value, uni.DictVal) {
        if not node.value.kv_pairs and node.type_tag and node.type_tag.tag {
            # Empty dict with type hint - create empty dict of correct type
            dict_type = self._resolve_jac_type(node.type_tag.tag);
            if isinstance(dict_type, ir.PointerType) {
                # Find the dict helpers for this type
                for (dict_key, dtype) in self.dict_types.items() {
                    if dict_type == dtype.as_pointer() {
                        helpers = self.dict_helpers.get(dict_key);
                        if helpers is not None {
                            value = self.builder.call(
                                helpers["new"], [], name="dict.new"
                            );
                        }
                        break;
                    }
                }
            }
        }
    }
    # Handle empty set literal {} that should be a set with type annotation
    if value is None and isinstance(node.value, uni.SetVal) {
        if not node.value.values and node.type_tag and node.type_tag.tag {
            # Empty set with type hint - create empty set of correct type
            set_type = self._resolve_jac_type(node.type_tag.tag);
            if isinstance(set_type, ir.PointerType) {
                # Find the set helpers for this type
                for (elem_name, stype) in self.set_types.items() {
                    if set_type == stype.as_pointer() {
                        helpers = self.set_helpers.get(elem_name);
                        if helpers is not None {
                            value = self.builder.call(
                                helpers["new"], [], name="set.new"
                            );
                        }
                        break;
                    }
                }
            }
        }
    }
    # Handle set() constructor call with type annotation
    if value is None and isinstance(node.value, uni.FuncCall) {
        func_name = self._get_name(node.value.target);
        if func_name == "set" and node.type_tag and node.type_tag.tag {
            # set() constructor with type annotation - create empty set
            set_type = self._resolve_jac_type(node.type_tag.tag);
            if isinstance(set_type, ir.PointerType) {
                for (elem_name, stype) in self.set_types.items() {
                    if set_type == stype.as_pointer() {
                        helpers = self.set_helpers.get(elem_name);
                        if helpers is not None {
                            value = self.builder.call(
                                helpers["new"], [], name="set.new"
                            );
                        }
                        break;
                    }
                }
            }
        }
    }
    if value is None {
        return;
    }
    targets = node.target
    if isinstance(node.target, (<>list, <>tuple))
    else [(node.target)];
    for target_expr in targets {
        # Handle tuple unpacking: (a, b) = expr
        if isinstance(target_expr, uni.TupleVal) {
            self._codegen_tuple_unpack(target_expr.values, value, node.value);
            continue;
        }
        # Handle field assignment: self.x = val or obj.field = val
        if isinstance(target_expr, uni.AtomTrailer) and target_expr.is_attr {
            self._codegen_field_assign(target_expr, value);
            continue;
        }
        # Handle index assignment: items[i] = val or expr[i] = val (lists or dicts)
        if isinstance(target_expr, uni.AtomTrailer) and not target_expr.is_attr {
            idx_target_name = self._get_name(target_expr.target);
            target_val = self._codegen_expr(target_expr.target);
            if target_val is not None and target_expr.right?.slices {
                slices = target_expr.right.slices or [];
                if slices {
                    idx_node = slices[0];
                    idx_val = self._codegen_expr(idx_node);
                    if idx_val is None and idx_node?.start {
                        idx_val = self._codegen_expr(idx_node.start);
                    }
                    if idx_val is not None {
                        # Check if this is a dict assignment
                        dict_type_key: (str | None) = None;
                        if idx_target_name is not None
                        and idx_target_name in self.var_dict_type {
                            dict_type_key = self.var_dict_type[idx_target_name];
                        }
                        if dict_type_key is None {
                            dict_info = self._infer_dict_type(target_val);
                            if dict_info is not None {
                                dict_type_key = f"{dict_info[0]}:{dict_info[1]}";
                            }
                        }
                        if dict_type_key is not None {
                            # Dict assignment: dict[key] = value
                            parts = dict_type_key.split(":");
                            if len(parts) == 2 {
                                self._codegen_dict_set(
                                    target_val, idx_val, value, parts[0], parts[1]
                                );
                            }
                        } else {
                            # List assignment: list[idx] = value
                            elem_type_name: (str | None) = None;
                            if idx_target_name is not None
                            and idx_target_name in self.var_list_elem_type {
                                elem_type_name = self.var_list_elem_type[
                                    idx_target_name
                                ];
                            }
                            if elem_type_name is None {
                                elem_type_name = self._infer_list_elem_type(target_val);
                            }
                            if elem_type_name is not None {
                                self._codegen_index_set(
                                    target_val, idx_val, value, elem_type_name
                                );
                            }
                        }
                    }
                }
            }
            continue;
        }
        var_name = self._get_name(target_expr);
        if var_name is None {
            continue;
        }

        if var_name in self.local_vars {
            # Update existing variable
            alloca = self.local_vars[var_name];
            # Handle augmented assignment: +=, -=, *=, //=, %=
            if node.aug_op is not None {
                aug_op_val = node.aug_op.value;
                current = self.builder.load(alloca, name=f"{var_name}.cur");
                coerced = self._coerce_type(value, current.type);
                if aug_op_val == "+=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.add(
                            current, coerced, name=f"{var_name}.add"
                        );
                    } elif isinstance(current.type, ir.DoubleType) {
                        value = self.builder.fadd(
                            current, coerced, name=f"{var_name}.fadd"
                        );
                    } elif isinstance(current.type, ir.PointerType) {
                        # String concatenation for +=
                        value = self._emit_binary_op(Tok.PLUS, current, coerced);
                        if value is None {
                            value = current;
                        }
                    } else {
                        value = self.builder.fadd(
                            current, coerced, name=f"{var_name}.fadd"
                        );
                    }
                } elif aug_op_val == "-=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.sub(
                            current, coerced, name=f"{var_name}.sub"
                        );
                    } else {
                        value = self.builder.fsub(
                            current, coerced, name=f"{var_name}.fsub"
                        );
                    }
                } elif aug_op_val == "*=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.mul(
                            current, coerced, name=f"{var_name}.mul"
                        );
                    } else {
                        value = self.builder.fmul(
                            current, coerced, name=f"{var_name}.fmul"
                        );
                    }
                } elif aug_op_val == "//=" {
                    if isinstance(current.type, ir.IntType) {
                        # ZeroDivisionError check
                        izero = ir.Constant(current.type, 0);
                        is_zero = self.builder.icmp_signed(
                            "==", coerced, izero, name=f"{var_name}.div.zero.chk"
                        );
                        self._emit_runtime_raise(
                            is_zero,
                            "ZeroDivisionError",
                            "integer division or modulo by zero"
                        );
                        value = self.builder.sdiv(
                            current, coerced, name=f"{var_name}.div"
                        );
                    } else {
                        # ZeroDivisionError check for float
                        fzero = ir.Constant(ir.DoubleType(), 0.0);
                        is_zero = self.builder.fcmp_ordered(
                            "==", coerced, fzero, name=f"{var_name}.fdiv.zero.chk"
                        );
                        self._emit_runtime_raise(
                            is_zero, "ZeroDivisionError", "float division by zero"
                        );
                        value = self.builder.fdiv(
                            current, coerced, name=f"{var_name}.fdiv"
                        );
                    }
                } elif aug_op_val == "%=" {
                    if isinstance(current.type, ir.IntType) {
                        # ZeroDivisionError check
                        izero = ir.Constant(current.type, 0);
                        is_zero = self.builder.icmp_signed(
                            "==", coerced, izero, name=f"{var_name}.mod.zero.chk"
                        );
                        self._emit_runtime_raise(
                            is_zero,
                            "ZeroDivisionError",
                            "integer division or modulo by zero"
                        );
                        value = self.builder.srem(
                            current, coerced, name=f"{var_name}.mod"
                        );
                    } else {
                        # ZeroDivisionError check for float
                        fzero = ir.Constant(ir.DoubleType(), 0.0);
                        is_zero = self.builder.fcmp_ordered(
                            "==", coerced, fzero, name=f"{var_name}.fmod.zero.chk"
                        );
                        self._emit_runtime_raise(
                            is_zero, "ZeroDivisionError", "float modulo by zero"
                        );
                        value = self.builder.frem(
                            current, coerced, name=f"{var_name}.fmod"
                        );
                    }
                } elif aug_op_val == "&=" {
                    # Bitwise AND assignment
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.and_(
                            current, coerced, name=f"{var_name}.and"
                        );
                    }
                } elif aug_op_val == "|=" {
                    # Bitwise OR assignment
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.or_(
                            current, coerced, name=f"{var_name}.or"
                        );
                    }
                } elif aug_op_val == "^=" {
                    # Bitwise XOR assignment
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.xor(
                            current, coerced, name=f"{var_name}.xor"
                        );
                    }
                } elif aug_op_val == "<<=" {
                    # Left shift assignment
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.shl(
                            current, coerced, name=f"{var_name}.shl"
                        );
                    }
                } elif aug_op_val == ">>=" {
                    # Right shift assignment (arithmetic)
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.ashr(
                            current, coerced, name=f"{var_name}.ashr"
                        );
                    }
                } elif aug_op_val == "**=" {
                    # Power assignment
                    if isinstance(current.type, ir.IntType) {
                        value = self._codegen_int_pow(current, coerced);
                    }
                }
            }
            coerced = self._coerce_type(value, alloca.type.pointee);
            self.builder.store(coerced, alloca);
        } else {
            # New variable — allocate and store
            var_type = value.type;
            if node.type_tag and node.type_tag.tag {
                var_type = self._resolve_jac_type(node.type_tag.tag);
                value = self._coerce_type(value, var_type);
            }
            alloca = self._entry_alloca(var_type, var_name);
            self.builder.store(value, alloca);
            self.local_vars[var_name] = alloca;
        }
        # Track type info for variables pointing to structs
        if isinstance(value.type, ir.PointerType) {
            # Check if it's a known struct pointer type
            for (sname, stype) in self.struct_types.items() {
                if value.type == stype.as_pointer() {
                    self.type_var_map[var_name] = sname;
                    break;
                }
            }
        }
        # Track from type_tag annotation (supports T and T | None union types)
        if node.type_tag and node.type_tag.tag {
            tag_node = node.type_tag.tag;
            tag_name = self._get_name(tag_node);
            # Handle union type: T | None → extract T
            if tag_name is None and isinstance(tag_node, uni.BinaryExpr) {
                op_val = getattr(tag_node.op, 'value', '');
                if op_val == "|" {
                    tag_name = self._get_name(tag_node.left);
                }
            }
            if tag_name is not None and tag_name in self.struct_types {
                self.type_var_map[var_name] = tag_name;
            }
            # Store the full type AST node for nested type resolution
            self.var_type_node[var_name] = tag_node;
        }
        # Track list element type for list variables
        for (ename, ltype) in self.list_types.items() {
            if value.type == ltype.as_pointer() {
                self.var_list_elem_type[var_name] = ename;
                break;
            }
        }
        # Track dict type for dict variables
        for (dkey, dtype) in self.dict_types.items() {
            if value.type == dtype.as_pointer() {
                self.var_dict_type[var_name] = dkey;
                break;
            }
        }
        # Track set element type for set variables
        for (ename, stype) in self.set_types.items() {
            if value.type == stype.as_pointer() {
                self.var_set_elem_type[var_name] = ename;
                break;
            }
        }
    }
}

# ─── Expression Codegen ──────────────────────────────────────
"""Generate break or continue statement."""
impl NaIRGenPass._codegen_ctrl(node: uni.CtrlStmt) -> None {
    if not self.loop_stack {
        return;
    }
    ctrl_name = node.ctrl.name if isinstance(node.ctrl, uni.Token) else str(node.ctrl);
    (continue_bb, break_bb) = self.loop_stack[-1];
    if ctrl_name == Tok.KW_BREAK {
        self.builder.branch(break_bb);
    } elif ctrl_name == Tok.KW_CONTINUE {
        self.builder.branch(continue_bb);
    }
}

# ─── Phase 1: For Loops ──────────────────────────────────────
"""Generate for loop (currently supports range(n) and range(start, stop))."""
impl NaIRGenPass._codegen_for(node: uni.InForStmt) -> None {
    # Extract loop variable name
    loop_var_name = self._get_name(node.target);
    if loop_var_name is None {
        return;
    }
    # Detect range() calls
    start_val: (ir.Value | None) = None;
    stop_val: (ir.Value | None) = None;
    if isinstance(node.collection, uni.FuncCall) {
        call_name = self._get_name(node.collection.target);
        if call_name == "range" {
            params = node.collection.params or [];
            if len(params) == 1 {
                start_val = ir.Constant(ir.IntType(64), 0);
                stop_val = self._codegen_expr(params[0]);
            } elif len(params) >= 2 {
                start_val = self._codegen_expr(params[0]);
                stop_val = self._codegen_expr(params[1]);
            }
        }
    }
    if start_val is not None and stop_val is not None {
        # Range-based for loop
        start_val = self._coerce_type(start_val, ir.IntType(64));
        stop_val = self._coerce_type(stop_val, ir.IntType(64));
        alloca = self.builder.alloca(ir.IntType(64), name=loop_var_name);
        self.builder.store(start_val, alloca);
        self.local_vars[loop_var_name] = alloca;
        func = self.builder.function;
        cond_bb = func.append_basic_block(name="for.cond");
        body_bb = func.append_basic_block(name="for.body");
        incr_bb = func.append_basic_block(name="for.incr");
        end_bb = func.append_basic_block(name="for.end");
        self.builder.branch(cond_bb);
        self.builder.position_at_end(cond_bb);
        i_val = self.builder.load(alloca, name=loop_var_name);
        cmp = self.builder.icmp_signed("<", i_val, stop_val, name="for.cmp");
        self.builder.cbranch(cmp, body_bb, end_bb);
        self.loop_stack.append((incr_bb, end_bb));
        self.builder.position_at_end(body_bb);
        if isinstance(node.body, (<>list, <>tuple)) {
            self._codegen_body(node.body);
        }
        if not self.builder.block.is_terminated {
            self.builder.branch(incr_bb);
        }
        self.loop_stack.pop();
        self.builder.position_at_end(incr_bb);
        i_cur = self.builder.load(alloca, name="for.cur");
        i_next = self.builder.add(
            i_cur, ir.Constant(ir.IntType(64), 1), name="for.next"
        );
        self.builder.store(i_next, alloca);
        self.builder.branch(cond_bb);
        self.builder.position_at_end(end_bb);
        return;
    }
    # ── Dict iteration: for k in dict ──
    # Only use dict iteration if the collection variable is explicitly tracked as a dict
    # (This avoids premature code generation from type inference)
    coll_name = self._get_name(node.collection);
    dict_type_key: (str | None) = None;
    if coll_name is not None and coll_name in self.var_dict_type {
        dict_type_key = self.var_dict_type[coll_name];
    }
    if dict_type_key is not None {
        # This is dict iteration
        helpers = self.dict_helpers.get(dict_type_key);
        if helpers is not None {
            collection_val = self._codegen_expr(node.collection);
            if collection_val is not None {
                i64 = ir.IntType(64);
                key_type = helpers["key_type"];
                # Get dict length
                len_val = self.builder.call(
                    helpers["len"], [collection_val], name="ford.len"
                );
                # Allocate loop index
                idx_alloca = self.builder.alloca(i64, name="ford.idx");
                self.builder.store(ir.Constant(i64, 0), idx_alloca);
                # Allocate loop variable (key)
                loop_alloca = self.builder.alloca(key_type, name=loop_var_name);
                self.local_vars[loop_var_name] = loop_alloca;
                func = self.builder.function;
                cond_bb = func.append_basic_block(name="ford.cond");
                body_bb = func.append_basic_block(name="ford.body");
                incr_bb = func.append_basic_block(name="ford.incr");
                end_bb = func.append_basic_block(name="ford.end");
                self.builder.branch(cond_bb);
                # Condition: idx < len
                self.builder.position_at_end(cond_bb);
                cur_idx = self.builder.load(idx_alloca, name="ford.cur.idx");
                cmp = self.builder.icmp_signed("<", cur_idx, len_val, name="ford.cmp");
                self.builder.cbranch(cmp, body_bb, end_bb);
                # Body: load key at index, store in loop var, execute body
                self.loop_stack.append((incr_bb, end_bb));
                self.builder.position_at_end(body_bb);
                body_idx = self.builder.load(idx_alloca, name="ford.body.idx");
                key_val = self.builder.call(
                    helpers["get_key"], [collection_val, body_idx], name="ford.key"
                );
                self.builder.store(key_val, loop_alloca);
                if isinstance(node.body, (<>list, <>tuple)) {
                    self._codegen_body(node.body);
                }
                if not self.builder.block.is_terminated {
                    self.builder.branch(incr_bb);
                }
                self.loop_stack.pop();
                # Increment: idx = idx + 1
                self.builder.position_at_end(incr_bb);
                inc_idx = self.builder.load(idx_alloca, name="ford.inc.idx");
                next_idx = self.builder.add(
                    inc_idx, ir.Constant(i64, 1), name="ford.next.idx"
                );
                self.builder.store(next_idx, idx_alloca);
                self.builder.branch(cond_bb);
                # Continue after loop
                self.builder.position_at_end(end_bb);
                return;
            }
        }
    }
    # ── List iteration: for x in items ──
    # Set list type hint in case collection is a list literal
    self._list_type_hint = None;
    coll_name = self._get_name(node.collection);
    # Infer elem type hint from collection variable's type node
    if coll_name is not None and coll_name in self.var_type_node {
        coll_type_node = self.var_type_node[coll_name];
        hint = self._get_list_elem_from_type_node(coll_type_node);
        if hint is not None {
            self._list_type_hint = hint;
        }
    }
    self._last_type_node_hint = None;
    collection_val = self._codegen_expr(node.collection);
    coll_type_hint = self._last_type_node_hint;
    self._list_type_hint = None;
    if collection_val is None {
        return;
    }
    # Determine element type of the list
    elem_type_name: (str | None) = None;
    if coll_name is not None and coll_name in self.var_list_elem_type {
        elem_type_name = self.var_list_elem_type[coll_name];
    } else {
        elem_type_name = self._infer_list_elem_type(collection_val);
    }
    if elem_type_name is None {
        return;
    }
    helpers = self.list_helpers.get(elem_type_name);
    if helpers is None {
        return;
    }
    i64 = ir.IntType(64);
    # Get list length
    len_val = self.builder.call(helpers["len"], [collection_val], name="forl.len");
    # Allocate loop index
    idx_alloca = self.builder.alloca(i64, name="forl.idx");
    self.builder.store(ir.Constant(i64, 0), idx_alloca);
    # Resolve actual element type for ptr lists (before allocating loop var)
    actual_elem_type = helpers["elem_type"];
    inner_type: (ir.Type | None) = None;
    # Get the type node for the collection (from variable or from field access hint)
    coll_type_node: (object | None) = None;
    if coll_name is not None and coll_name in self.var_type_node {
        coll_type_node = self.var_type_node[coll_name];
    } elif coll_type_hint is not None {
        coll_type_node = coll_type_hint;
    }
    if elem_type_name == "ptr" {
        inner_type = self._resolve_for_loop_elem_type(coll_name, node.collection);
        # Fallback: use coll_type_hint from field access
        if inner_type is None and coll_type_node is not None {
            (_, inner_type_from_hint, _) = self._peel_list_type(coll_type_node);
            if inner_type_from_hint is not None {
                inner_type = inner_type_from_hint;
            }
        }
        if inner_type is not None {
            actual_elem_type = inner_type;
            # Track inner type info on loop var
            for (sname, stype) in self.struct_types.items() {
                if inner_type == stype.as_pointer() {
                    self.type_var_map[loop_var_name] = sname;
                    break;
                }
            }
            for (ename, ltype) in self.list_types.items() {
                if inner_type == ltype.as_pointer() {
                    self.var_list_elem_type[loop_var_name] = ename;
                    break;
                }
            }
            # Propagate inner type node for nested access
            if coll_type_node is not None {
                (inner_node, _, _) = self._peel_list_type(coll_type_node);
                if inner_node is not None {
                    self.var_type_node[loop_var_name] = inner_node;
                }
            }
        }
    }
    # Allocate loop variable with resolved element type
    loop_alloca = self.builder.alloca(actual_elem_type, name=loop_var_name);
    self.local_vars[loop_var_name] = loop_alloca;
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="forl.cond");
    body_bb = func.append_basic_block(name="forl.body");
    incr_bb = func.append_basic_block(name="forl.incr");
    end_bb = func.append_basic_block(name="forl.end");
    self.builder.branch(cond_bb);
    # Condition: idx < len
    self.builder.position_at_end(cond_bb);
    cur_idx = self.builder.load(idx_alloca, name="forl.cur.idx");
    cmp = self.builder.icmp_signed("<", cur_idx, len_val, name="forl.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);
    # Body: load element, store in loop var, execute body
    self.loop_stack.append((incr_bb, end_bb));
    self.builder.position_at_end(body_bb);
    body_idx = self.builder.load(idx_alloca, name="forl.body.idx");
    elem_val = self.builder.call(
        helpers["get"], [collection_val, body_idx], name="forl.elem"
    );
    # Bitcast ptr elements to the correct inner type if resolved
    if inner_type is not None {
        elem_val = self.builder.bitcast(elem_val, inner_type, name="forl.cast");
    }
    self.builder.store(elem_val, loop_alloca);
    if isinstance(node.body, (<>list, <>tuple)) {
        self._codegen_body(node.body);
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(incr_bb);
    }
    self.loop_stack.pop();
    # Increment: idx = idx + 1
    self.builder.position_at_end(incr_bb);
    inc_idx = self.builder.load(idx_alloca, name="forl.inc.idx");
    next_idx = self.builder.add(inc_idx, ir.Constant(i64, 1), name="forl.next.idx");
    self.builder.store(next_idx, idx_alloca);
    self.builder.branch(cond_bb);
    # Continue after loop
    self.builder.position_at_end(end_bb);
}
# ─── Phase 1: Ternary If-Else Expression ─────────────────────
