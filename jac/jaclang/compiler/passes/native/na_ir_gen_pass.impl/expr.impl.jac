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
    if isinstance(nd, uni.CfgExpr) {
        return self._codegen_expr(nd.expr);
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
    # Lambda expressions: emit an anonymous LLVM function and return
    # a function pointer to it.
    if isinstance(nd, uni.LambdaExpr) {
        return self._codegen_lambda(nd);
    }
    return None;
}

"""Collect free variable names referenced in a lambda body that are not
in the lambda's own parameter list. Walks the AST looking for Name nodes.
"""
impl NaIRGenPass._find_free_vars(body: object, param_names: list[str]) -> list[str] {
    free: list[str] = [];
    seen: set[str] = set(param_names);
    stack: list = [body] if not isinstance(body, list) else list(body);
    while stack {
        cur = stack.pop();
        if cur is None {
            continue;
        }
        if isinstance(cur, uni.Name) {
            vname = cur.value;
            if vname not in seen and vname in self.local_vars {
                seen.add(vname);
                free.append(vname);
            }
            continue;
        }
        # Walk children via kid list
        if cur?.kid and cur.kid {
            for child in cur.kid {
                stack.append(child);
            }
        }
    }
    return free;
}

"""Generate IR for a lambda expression.

Emits an anonymous LLVM function from the lambda body and returns a
pointer to it. If the lambda references variables from the enclosing
scope (free variables), those are appended as extra hidden parameters
to the anonymous function, and the call site injects them automatically
via the lambda_captures side table.
"""
impl NaIRGenPass._codegen_lambda(nd: uni.LambdaExpr) -> (ir.Value | None) {
    # --- Resolve parameter types and return type from the signature ---
    sig = nd.signature;
    param_types: list[ir.Type] = [];
    param_names: list[str] = [];
    if sig is not None and sig.params {
        for p in sig.params {
            p_name = p.name.value if p?.name and p.name else f"arg{len(param_names)}";
            p_type = self._resolve_jac_type(p.type_tag)
                if p?.type_tag and p.type_tag
                else ir.IntType(64);
            param_types.append(p_type);
            param_names.append(p_name);
        }
    }
    ret_type = ir.IntType(64);  # default
    if sig is not None and sig.return_type is not None {
        ret_type = self._resolve_jac_type(sig.return_type);
    }
    # --- Detect captured (free) variables from the enclosing scope ---
    captures: list[tuple] = [];  # list of (name, ir.Value, ir.Type)
    free_var_names = self._find_free_vars(nd.body, param_names);
    for fv_name in free_var_names {
        if fv_name in self.local_vars {
            alloca = self.local_vars[fv_name];
            val = self.builder.load(alloca, name=f"cap.{fv_name}");
            captures.append((fv_name, val, val.type));
        }
    }
    # Build the full parameter list: explicit params + captured vars
    all_param_types = list(param_types);
    all_param_names = list(param_names);
    for (cap_name, _cap_val, cap_type) in captures {
        all_param_types.append(cap_type);
        all_param_names.append(cap_name);
    }
    # --- Create the anonymous function ---
    self._str_count += 1;
    anon_name = f"__jac_lambda_{self._str_count}";
    fn_type = ir.FunctionType(ret_type, all_param_types);
    anon_fn = ir.Function(self.llvm_module, fn_type, name=anon_name);
    anon_fn.linkage = "private";
    for (i, arg) in enumerate(anon_fn.args) {
        if i < len(all_param_names) {
            arg.name = all_param_names[i];
        }
    }
    # --- Emit the lambda body ---
    saved_builder = self.builder;
    saved_locals = self.local_vars;
    saved_func_symtab = dict(self.func_symtab);
    entry_bb = anon_fn.append_basic_block("entry");
    self.builder = ir.IRBuilder(entry_bb);
    self.local_vars = {};
    # Allocate ALL parameters (explicit + captured) as local variables
    for (i, arg) in enumerate(anon_fn.args) {
        alloca = self._entry_alloca(arg.type, all_param_names[i]);
        self.builder.store(arg, alloca);
        self.local_vars[all_param_names[i]] = alloca;
    }
    # Codegen the body
    body = nd.body;
    if isinstance(body, list) {
        self._codegen_body(body);
    } else {
        val = self._codegen_expr(body);
        if val is not None {
            self.builder.ret(self._coerce_type(val, ret_type));
        } else {
            self.builder.ret(ir.Constant(ret_type, 0));
        }
    }
    # Ensure every basic block has a terminator
    for bb in anon_fn.basic_blocks {
        if not bb.is_terminated {
            term_builder = ir.IRBuilder(bb);
            if ret_type == ir.VoidType() {
                term_builder.ret_void();
            } else {
                term_builder.ret(ir.Constant(ret_type, 0));
            }
        }
    }
    # --- Restore parent context ---
    self.builder = saved_builder;
    self.local_vars = saved_locals;
    self.func_symtab = saved_func_symtab;
    # --- Record pending captures for the assignment to associate with a var name ---
    if captures {
        capture_info: list[tuple] = [];
        for (cap_name, _cap_val, _cap_type) in captures {
            # Store the alloca (not the loaded value) so it can be loaded at call time
            capture_info.append((cap_name, self.local_vars[cap_name]));
        }
        self._pending_lambda_captures = capture_info;
    } else {
        self._pending_lambda_captures = None;
    }
    return anon_fn;
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
        # Check if right is a list
        for (list_key, helpers) in self.list_helpers.items() {
            list_type = self.list_types.get(list_key);
            if list_type is not None and right.type == list_type.as_pointer() {
                elem_type = helpers["elem_type"];
                left_coerced = self._coerce_type(left, elem_type);
                list_len = self.builder.call(
                    helpers["len"], [right], name="list.in.len"
                );
                i64 = ir.IntType(64);
                func = self.builder.basic_block.function;
                entry_bb = self.builder.basic_block;
                loop_bb = func.append_basic_block(name="list.in.loop");
                check_bb = func.append_basic_block(name="list.in.check");
                found_bb = func.append_basic_block(name="list.in.found");
                done_bb = func.append_basic_block(name="list.in.done");
                self.builder.branch(loop_bb);
                self.builder.position_at_start(loop_bb);
                idx = self.builder.phi(i64, name="list.in.idx");
                idx.add_incoming(ir.Constant(i64, 0), entry_bb);
                at_end = self.builder.icmp_unsigned(
                    ">=", idx, list_len, name="list.in.atend"
                );
                self.builder.cbranch(at_end, done_bb, check_bb);
                self.builder.position_at_start(check_bb);
                elem = self.builder.call(
                    helpers["get"], [right, idx], name="list.in.elem"
                );
                eq = self.builder.icmp_signed(
                    "==", elem, left_coerced, name="list.in.eq"
                );
                next_idx = self.builder.add(
                    idx, ir.Constant(i64, 1), name="list.in.next"
                );
                idx.add_incoming(next_idx, check_bb);
                self.builder.cbranch(eq, found_bb, loop_bb);
                self.builder.position_at_start(found_bb);
                self.builder.branch(done_bb);
                self.builder.position_at_start(done_bb);
                result = self.builder.phi(i64, name="list.in.result");
                result.add_incoming(ir.Constant(i64, 0), loop_bb);
                result.add_incoming(ir.Constant(i64, 1), found_bb);
                if is_not_in {
                    result = self.builder.icmp_signed(
                        "==", result, ir.Constant(i64, 0), name="not.in"
                    );
                    result = self.builder.zext(result, i64, name="notin.i64");
                }
                return result;
            }
        }
        # Check if right is a tuple (value or pointer to LiteralStructType)
        tin_struct: (ir.LiteralStructType | None) = None;
        tin_val: (ir.Value | None) = None;
        if isinstance(right.type, ir.LiteralStructType) {
            tin_struct = right.type;
            tin_val = right;
        } elif isinstance(right.type, ir.PointerType)
        and isinstance(right.type.pointee, ir.LiteralStructType) {
            tin_struct = right.type.pointee;
            tin_val = self.builder.load(right, name="tuple.in.val");
        }
        if tin_struct is not None and tin_val is not None {
            n = len(tin_struct.elements);
            if n > 0 {
                i64 = ir.IntType(64);
                i1_t = ir.IntType(1);
                found = ir.Constant(i1_t, 0);
                for i in range(n) {
                    elem = self.builder.extract_value(tin_val, i, name=f"tuple.in.{i}");
                    left_c = self._coerce_type(left, elem.type);
                    if isinstance(elem.type, ir.IntType) {
                        eq = self.builder.icmp_signed(
                            "==", left_c, elem, name=f"tuple.in.{i}.eq"
                        );
                    } elif isinstance(elem.type, ir.DoubleType) {
                        eq = self.builder.fcmp_ordered(
                            "==", left_c, elem, name=f"tuple.in.{i}.eq"
                        );
                    } else {
                        i8p = ir.IntType(8).as_pointer();
                        strcmp_fn = self._get_or_declare_extern(
                            "strcmp", ir.IntType(32), [i8p, i8p]
                        );
                        cmp = self.builder.call(
                            strcmp_fn, [left_c, elem], name=f"tuple.in.{i}.cmp"
                        );
                        eq = self.builder.icmp_signed(
                            "==",
                            cmp,
                            ir.Constant(ir.IntType(32), 0),
                            name=f"tuple.in.{i}.eq"
                        );
                    }
                    found = self.builder.or_(found, eq, name=f"tuple.in.{i}.found");
                }
                result = self.builder.zext(found, i64, name="tuple.in.result");
                if is_not_in {
                    result = self.builder.icmp_signed(
                        "==", result, ir.Constant(i64, 0), name="tuple.notin"
                    );
                    result = self.builder.zext(result, i64, name="tuple.notin.i64");
                }
                return result;
            }
        }
        # Check if right is a range (JacRange*): val in range(...)
        if right.type == self.range_struct_type.as_pointer() {
            i64 = ir.IntType(64);
            i32 = ir.IntType(32);
            z0 = ir.Constant(i32, 0);
            val = self._coerce_type(left, i64);
            start = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 0)], name="rin.sp"),
                name="rin.start"
            );
            stop = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 1)], name="rin.ep"),
                name="rin.stop"
            );
            step = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 2)], name="rin.tp"),
                name="rin.step"
            );
            # Check: (val - start) % step == 0 and in bounds
            diff = self.builder.sub(val, start, name="rin.diff");
            rem = self.builder.srem(diff, step, name="rin.rem");
            rem_zero = self.builder.icmp_signed(
                "==", rem, ir.Constant(i64, 0), name="rin.remz"
            );
            # Check step > 0: start <= val < stop
            # Check step < 0: stop < val <= start
            step_pos = self.builder.icmp_signed(
                ">", step, ir.Constant(i64, 0), name="rin.spos"
            );
            ge_start = self.builder.icmp_signed(">=", val, start, name="rin.ges");
            lt_stop = self.builder.icmp_signed("<", val, stop, name="rin.lts");
            pos_ok = self.builder.and_(ge_start, lt_stop, name="rin.pok");
            le_start = self.builder.icmp_signed("<=", val, start, name="rin.les");
            gt_stop = self.builder.icmp_signed(">", val, stop, name="rin.gts");
            neg_ok = self.builder.and_(le_start, gt_stop, name="rin.nok");
            bounds = self.builder.select(step_pos, pos_ok, neg_ok, name="rin.bounds");
            found = self.builder.and_(rem_zero, bounds, name="rin.found");
            result = self.builder.zext(found, i64, name="rin.result");
            if is_not_in {
                result = self.builder.icmp_signed(
                    "==", result, ir.Constant(i64, 0), name="rin.notin"
                );
                result = self.builder.zext(result, i64, name="rin.notin.i64");
            }
            return result;
        }
        # Check if right is a string (i8*): left in right → strstr
        if isinstance(right.type, ir.PointerType)
        and isinstance(left.type, ir.PointerType) {
            i8p = ir.IntType(8).as_pointer();
            i64 = ir.IntType(64);
            strstr_fn = self._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
            found = self.builder.call(strstr_fn, [right, left], name="str.in.ptr");
            null_ptr = ir.Constant(i8p, None);
            is_found = self.builder.icmp_unsigned(
                "!=", found, null_ptr, name="str.in.found"
            );
            result = self.builder.zext(is_found, i64, name="str.in.i64");
            if is_not_in {
                result = self.builder.icmp_signed(
                    "==", result, ir.Constant(i64, 0), name="not.in"
                );
                result = self.builder.zext(result, i64, name="notin.i64");
            }
            return result;
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
        # i64 is None: compare against -1 sentinel (for optional enum/int)
        if isinstance(left.type, ir.IntType)
        and isinstance(right.type, ir.PointerType) {
            sentinel = ir.Constant(left.type, -1);
            return self.builder.icmp_signed("==", left, sentinel, name="is.none");
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
        # i64 is not None: compare against -1 sentinel (for optional enum/int)
        if isinstance(left.type, ir.IntType)
        and isinstance(right.type, ir.PointerType) {
            sentinel = ir.Constant(left.type, -1);
            return self.builder.icmp_signed("!=", left, sentinel, name="isnot.none");
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
        } elif operand.type == self.complex_struct_type.as_pointer() {
            # Complex negation: (-real, -imag)
            f64 = ir.DoubleType();
            i64 = ir.IntType(64);
            i32 = ir.IntType(32);
            z0 = ir.Constant(i32, 0);
            z1 = ir.Constant(i32, 1);
            r = self.builder.load(
                self.builder.gep(operand, [z0, z0], name="cneg.rp"), name="cneg.r"
            );
            im = self.builder.load(
                self.builder.gep(operand, [z0, z1], name="cneg.ip"), name="cneg.i"
            );
            nr = self.builder.fneg(r, name="cneg.nr");
            ni = self.builder.fneg(im, name="cneg.ni");
            raw = self.builder.call(
                self.rc_alloc_fn, [ir.Constant(i64, 16)], name="cneg.raw"
            );
            ptr = self.builder.bitcast(
                raw, self.complex_struct_type.as_pointer(), name="cneg.ptr"
            );
            self.builder.store(nr, self.builder.gep(ptr, [z0, z0], name="cneg.srp"));
            self.builder.store(ni, self.builder.gep(ptr, [z0, z1], name="cneg.sip"));
            return ptr;
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
    } elif op == Tok.PLUS {
        # Unary +: identity for numeric types
        if operand.type == self.complex_struct_type.as_pointer() {
            return operand;
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
            } elif isinstance(then_val.type, ir.IntType)
            and isinstance(else_val.type, ir.IntType) {
                # Widen the narrower int to match the wider one
                if then_val.type.width > else_val.type.width {
                    else_val = self.builder.zext(
                        else_val, then_val.type, name="ternary.widen"
                    );
                } else {
                    then_val = self.builder.zext(
                        then_val, else_val.type, name="ternary.widen"
                    );
                }
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
            # Check native stdlib module access: sys.argv, sys.platform
            if (
                target_name == "sys"
                and self?._native_stdlib_modules
                and "sys" in self._native_stdlib_modules
            ) {
                if right_name == "argv" {
                    result = self._emit_sys_argv();
                    if result is not None {
                        # Track as list[str] so indexing/iteration works
                        self.var_list_elem_type["__sys_argv_tmp"] = "ptr";
                    }
                    return result;
                }
                if right_name == "platform" {
                    import platform as _plat;
                    return self._make_global_string(_plat.system().lower());
                }
            }
            # Check enum member access: Color.WHITE
            full_name = f"{target_name}.{right_name}";
            if full_name in self.enum_values {
                return self.enum_values[full_name];
            }
            # Check enum .value / .name attribute: kind.value, kind.name
            if (right_name == "value" or right_name == "name")
            and target_name is not None
            and target_name in self.var_enum_type {
                enum_name = self.var_enum_type[target_name];
                ordinal_val = self._codegen_expr(nd.target);
                if ordinal_val is not None {
                    use_name = right_name == "name";
                    return self._codegen_enum_value_lookup(
                        enum_name, ordinal_val, use_name=use_name
                    );
                }
            }
            # Check chained enum .value / .name: self.kind.value
            if (right_name == "value" or right_name == "name")
            and isinstance(nd.target, uni.AtomTrailer)
            and nd.target.is_attr {
                inner_target = self._get_name(nd.target.target);
                inner_field = self._get_name(nd.target.right);
                if inner_target is not None and inner_field is not None {
                    inner_type = self.type_var_map.get(inner_target);
                    if inner_type is not None
                    and inner_type in self.struct_field_enum_type {
                        enum_name = self.struct_field_enum_type[inner_type].get(
                            inner_field
                        );
                        if enum_name is not None {
                            ordinal_val = self._codegen_expr(nd.target);
                            if ordinal_val is not None {
                                use_name = right_name == "name";
                                return self._codegen_enum_value_lookup(
                                    enum_name, ordinal_val, use_name=use_name
                                );
                            }
                        }
                    }
                }
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
    # Handle slice/range attribute access: sl.start, sl.stop, sl.step
    if nd.is_attr and target_name is not None and right_name is not None {
        _slice_field_map: dict[(str, int)] = {"start": 0, "stop": 1, "step": 2};
        if (target_name in self.var_slice and right_name in _slice_field_map) {
            obj_val = self._codegen_expr(nd.target);
            if obj_val is not None {
                i32 = ir.IntType(32);
                z0 = ir.Constant(i32, 0);
                fidx = ir.Constant(i32, _slice_field_map[right_name]);
                ptr = self.builder.gep(
                    obj_val, [z0, fidx], name=f"slice.{right_name}.ptr"
                );
                return self.builder.load(ptr, name=f"slice.{right_name}");
            }
        }
    }
    # Handle slice access: lst[1:3], s[1:3] (range-based slicing)
    if not nd.is_attr and nd.right?.slices and nd.right.is_range {
        target_name = self._get_name(nd.target);
        slices = nd.right.slices or [];
        if slices {
            s = slices[0];
            # List slicing
            if target_name is not None and target_name in self.var_list_elem_type {
                elem_type_name = self.var_list_elem_type[target_name];
                target_val = self._codegen_expr(nd.target);
                if target_val is not None {
                    result = self._codegen_list_slice(target_val, s, elem_type_name);
                    if result is not None {
                        # Track sliced list as same elem type
                        self.var_list_elem_type[f"__slice_tmp_{id(nd)}"] = elem_type_name;
                        return result;
                    }
                }
            } else {
                # String slicing
                target_val = self._codegen_expr(nd.target);
                if target_val is not None {
                    i8p = ir.IntType(8).as_pointer();
                    if target_val.type == i8p {
                        result = self._codegen_string_slice(target_val, s);
                        if result is not None {
                            return result;
                        }
                    }
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
                        and self._get_list_elem_from_type_node(
                            chain_type_hint
                        ) is not None
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
                # Check for tuple indexing (value or pointer to LiteralStructType)
                tsub_struct: (ir.LiteralStructType | None) = None;
                if isinstance(target_val.type, ir.LiteralStructType) {
                    tsub_struct = target_val.type;
                } elif isinstance(target_val.type, ir.PointerType)
                and isinstance(target_val.type.pointee, ir.LiteralStructType) {
                    tsub_struct = target_val.type.pointee;
                }
                if tsub_struct is not None {
                    slices = nd.right.slices or [];
                    if slices {
                        idx_node = slices[0];
                        idx_val = self._codegen_expr(idx_node);
                        if idx_val is None and idx_node?.start {
                            idx_val = self._codegen_expr(idx_node.start);
                        }
                        if idx_val is not None {
                            return self._codegen_tuple_index(
                                target_val, idx_val, tsub_struct
                            );
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
