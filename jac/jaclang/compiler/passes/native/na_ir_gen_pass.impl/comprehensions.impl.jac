"""List, set, and dict comprehension codegen."""
"""Generate code for a list comprehension [expr for x in iterable if cond]."""
impl NaIRGenPass._codegen_list_compr(nd: uni.ListCompr) -> (ir.Value | None) {
    if not nd.compr {
        return None;
    }
    # Determine element type from context
    elem_type_name = "i64";
    # 1. Check type hint from assignment context (highest priority)
    if self._list_type_hint is not None {
        elem_type_name = self._list_type_hint;
    } else {
        # 2. Try to infer from first collection's element type
        # For [m for m in items], infer from items' element type
        first_compr = nd.compr[0];
        coll_name = self._get_name(first_compr.collection);
        if coll_name is not None and coll_name in self.var_type_node {
            hint = self._get_list_elem_from_type_node(self.var_type_node[coll_name]);
            if hint is not None {
                elem_type_name = hint;
            }
        }
        # 3. If output is a TupleVal, assume ptr type
        if elem_type_name == "i64" and isinstance(nd.out_expr, uni.TupleVal) {
            elem_type_name = "ptr";
        }
        # 4. If output is a struct instantiation (FuncCall to known struct), use ptr
        if elem_type_name == "i64" and isinstance(nd.out_expr, uni.FuncCall) {
            call_name = self._get_name(nd.out_expr.target);
            if call_name is not None and call_name in self.struct_types {
                elem_type_name = "ptr";
            }
        }
        # 5. If output is a ListCompr (nested list comprehension), use ptr
        if elem_type_name == "i64" and isinstance(nd.out_expr, uni.ListCompr) {
            elem_type_name = "ptr";
        }
        # 6. If output is a ListVal (list literal), use ptr
        if elem_type_name == "i64" and isinstance(nd.out_expr, uni.ListVal) {
            elem_type_name = "ptr";
        }
        # 7. If output is a Null (None), use ptr
        if elem_type_name == "i64" and isinstance(nd.out_expr, uni.Null) {
            elem_type_name = "ptr";
        }
        # 8. If output is a Name that's in a for-loop (same name as loop variable), use inferred type
        if elem_type_name == "i64" and isinstance(nd.out_expr, uni.Name) {
            out_name = nd.out_expr.value;
            # Check if out_name matches any of the comprehension loop variables
            for compr in nd.compr {
                target_name = self._get_name(compr.target);
                if target_name == out_name {
                    # The output is the loop variable itself, infer from collection
                    coll_name = self._get_name(compr.collection);
                    if coll_name is not None and coll_name in self.var_type_node {
                        hint = self._get_list_elem_from_type_node(
                            self.var_type_node[coll_name]
                        );
                        if hint is not None {
                            elem_type_name = hint;
                        }
                    }
                    break;
                }
            }
        }
    }
    # Ensure helpers exist
    if elem_type_name == "ptr" {
        self._emit_list_helpers("ptr", ir.IntType(8).as_pointer());
    } elif elem_type_name == "f64" {
        self._emit_list_helpers("f64", ir.DoubleType());
    } else {
        self._emit_list_helpers("i64", ir.IntType(64));
    }
    helpers = self.list_helpers.get(elem_type_name);
    if helpers is None {
        return None;
    }
    # Create new empty list
    list_val = self.builder.call(helpers["new"], [], name="compr.list");
    # Generate nested loops for each InnerCompr
    self._codegen_compr_loops(nd.compr, 0, list_val, nd.out_expr, elem_type_name);
    return list_val;
}

"""Recursively generate nested loops for comprehension."""
impl NaIRGenPass._codegen_compr_loops(
    comprs: list,
    idx: int,
    list_val: ir.Value,
    out_expr: uni.UniNode,
    elem_type_name: str
) -> None {
    if idx >= len(comprs) {
        # Base case: all loops complete, evaluate and append
        # Clear list type hint before evaluating out_expr to allow nested comprehensions
        # to determine their own element type
        saved_hint = self._list_type_hint;
        self._list_type_hint = None;
        val = self._codegen_expr(out_expr);
        self._list_type_hint = saved_hint;
        if val is not None {
            helpers = self.list_helpers.get(elem_type_name);
            if helpers is not None {
                # Bitcast pointer types to i8* for ptr lists
                if elem_type_name == "ptr" and isinstance(val.type, ir.PointerType) {
                    i8p = ir.IntType(8).as_pointer();
                    val = self.builder.bitcast(val, i8p, name="compr.cast");
                }
                self.builder.call(helpers["append"], [list_val, val]);
            }
        }
        return;
    }
    inner = comprs[idx];
    # Get loop target and collection
    loop_target = inner.target;
    collection = inner.collection;
    conditionals = inner.conditional or [];
    # Check if it's a range() call FIRST (before trying to evaluate as expression)
    # range() is not a real function in native mode, so we handle it specially
    if isinstance(collection, uni.FuncCall) {
        call_name = self._get_name(collection.target);
        if call_name == "range" {
            self._codegen_compr_range_loop(
                inner, comprs, idx, list_val, out_expr, elem_type_name, conditionals
            );
            return;
        }
    }
    # Save original list type hint (for the output list)
    saved_hint = self._list_type_hint;
    # Evaluate collection (may need its own hint for nested lists)
    coll_name = self._get_name(collection);
    coll_val = self._codegen_expr(collection);
    # Restore the output list type hint
    self._list_type_hint = saved_hint;
    if coll_val is None {
        return;
    }
    # List iteration
    coll_elem_type_name = self._infer_list_elem_type(coll_val);
    if coll_elem_type_name is None {
        return;
    }
    coll_helpers = self.list_helpers.get(coll_elem_type_name);
    if coll_helpers is None {
        return;
    }
    loop_var_name = self._get_name(loop_target);
    if loop_var_name is None {
        return;
    }
    # Get list length
    i64 = ir.IntType(64);
    len_val = self.builder.call(coll_helpers["len"], [coll_val], name="compr.len");
    # Allocate loop index
    idx_alloca = self.builder.alloca(i64, name="compr.idx");
    self.builder.store(ir.Constant(i64, 0), idx_alloca);
    # Resolve element type for ptr lists
    actual_elem_type = coll_helpers["elem_type"];
    inner_type: (ir.Type | None) = None;
    if coll_elem_type_name == "ptr" {
        coll_type_node = self.var_type_node.get(coll_name) if coll_name else None;
        if coll_type_node is not None {
            (_, inner_type_resolved, _) = self._peel_list_type(coll_type_node);
            if inner_type_resolved is not None {
                inner_type = inner_type_resolved;
                actual_elem_type = inner_type;
            }
        }
    }
    # Allocate loop variable
    loop_alloca = self.builder.alloca(actual_elem_type, name=loop_var_name);
    self.local_vars[loop_var_name] = loop_alloca;
    # Track type info for loop variable
    if inner_type is not None {
        for (sname, stype) in self.struct_types.items() {
            if inner_type == stype.as_pointer() {
                self.type_var_map[loop_var_name] = sname;
                break;
            }
        }
    }
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="compr.cond");
    body_bb = func.append_basic_block(name="compr.body");
    incr_bb = func.append_basic_block(name="compr.incr");
    end_bb = func.append_basic_block(name="compr.end");
    self.builder.branch(cond_bb);
    # Condition: idx < len
    self.builder.position_at_end(cond_bb);
    cur_idx = self.builder.load(idx_alloca, name="compr.cur.idx");
    cmp = self.builder.icmp_signed("<", cur_idx, len_val, name="compr.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);
    # Body: load element, check conditionals, recurse or append
    self.builder.position_at_end(body_bb);
    body_idx = self.builder.load(idx_alloca, name="compr.body.idx");
    elem_val = self.builder.call(
        coll_helpers["get"], [coll_val, body_idx], name="compr.elem"
    );
    # Bitcast ptr elements to correct inner type
    if inner_type is not None {
        elem_val = self.builder.bitcast(elem_val, inner_type, name="compr.cast");
    }
    self.builder.store(elem_val, loop_alloca);
    # Check conditionals
    if conditionals {
        filter_bb = func.append_basic_block(name="compr.filter");
        skip_bb = func.append_basic_block(name="compr.skip");
        # Evaluate all conditionals with AND
        all_cond = self._codegen_expr(conditionals[0]);
        if all_cond is not None {
            all_cond = self._to_bool(all_cond);
            for i in range(1, len(conditionals)) {
                next_cond = self._codegen_expr(conditionals[i]);
                if next_cond is not None {
                    next_cond = self._to_bool(next_cond);
                    all_cond = self.builder.and_(all_cond, next_cond, name="compr.and");
                }
            }
            self.builder.cbranch(all_cond, filter_bb, skip_bb);
        } else {
            self.builder.branch(filter_bb);
        }
        # Filter passed - recurse to next loop level
        self.builder.position_at_end(filter_bb);
        self._codegen_compr_loops(comprs, idx + 1, list_val, out_expr, elem_type_name);
        if not self.builder.block.is_terminated {
            self.builder.branch(skip_bb);
        }
        # Skip block merges back
        self.builder.position_at_end(skip_bb);
        self.builder.branch(incr_bb);
    } else {
        # No conditionals - recurse directly
        self._codegen_compr_loops(comprs, idx + 1, list_val, out_expr, elem_type_name);
        if not self.builder.block.is_terminated {
            self.builder.branch(incr_bb);
        }
    }
    # Increment
    self.builder.position_at_end(incr_bb);
    inc_idx = self.builder.load(idx_alloca, name="compr.inc.idx");
    next_idx = self.builder.add(inc_idx, ir.Constant(i64, 1), name="compr.next.idx");
    self.builder.store(next_idx, idx_alloca);
    self.builder.branch(cond_bb);
    # Continue after loop
    self.builder.position_at_end(end_bb);
}

"""Generate code for a dict comprehension {k: v for x in iterable if cond}."""
impl NaIRGenPass._codegen_dict_compr(nd: uni.DictCompr) -> (ir.Value | None) {
    if not nd.compr {
        return None;
    }
    # Get key and value expressions from DictCompr's kv_pair
    if nd.kv_pair is None {
        return None;
    }
    key_expr = nd.kv_pair.key;
    val_expr = nd.kv_pair.value;
    if key_expr is None or val_expr is None {
        return None;
    }
    # Determine key and value types (default to i64/i64)
    key_type_name = "i64";
    val_type_name = "i64";
    key_type = ir.IntType(64);
    val_type = ir.IntType(64);
    # Check if key is a tuple
    if isinstance(key_expr, uni.TupleVal) {
        key_type_name = "ptr";
        key_type = ir.IntType(8).as_pointer();
    }
    # Check if value is a struct, tuple, or array access that returns a pointer
    if isinstance(val_expr, uni.TupleVal) {
        val_type_name = "ptr";
        val_type = ir.IntType(8).as_pointer();
    } elif isinstance(val_expr, uni.FuncCall) {
        call_name = self._get_name(val_expr.target);
        if call_name is not None and call_name in self.struct_types {
            val_type_name = "ptr";
            val_type = ir.IntType(8).as_pointer();
        }
    } elif isinstance(val_expr, uni.AtomTrailer) {
        # Array indexing (e.g., self.squares[r][c]) - check if it returns a pointer
        # This catches cases where we're accessing elements from a list that contains objects
        val_type_name = "ptr";
        val_type = ir.IntType(8).as_pointer();
    } elif isinstance(val_expr, uni.Name) {
        # Check if it's a known pointer variable
        var_name = val_expr.value;
        if var_name in self.type_var_map or var_name in self.var_list_elem_type {
            val_type_name = "ptr";
            val_type = ir.IntType(8).as_pointer();
        }
    }
    # Ensure dict helpers exist
    self._emit_dict_helpers(key_type_name, val_type_name, key_type, val_type);
    dict_key = f"{key_type_name}:{val_type_name}";
    helpers = self.dict_helpers.get(dict_key);
    if helpers is None {
        return None;
    }
    # Create new empty dict
    dict_val = self.builder.call(helpers["new"], [], name="dcompr.dict");
    # Generate nested loops for each InnerCompr
    self._codegen_dict_compr_loops(nd.compr, 0, dict_val, key_expr, val_expr, dict_key);
    return dict_val;
}

"""Recursively generate nested loops for dict comprehension."""
impl NaIRGenPass._codegen_dict_compr_loops(
    comprs: list,
    idx: int,
    dict_val: ir.Value,
    key_expr: uni.UniNode,
    val_expr: uni.UniNode,
    dict_key: str
) -> None {
    if idx >= len(comprs) {
        # Base case: all loops complete, evaluate and insert k:v pair
        key_val = self._codegen_expr(key_expr);
        value_val = self._codegen_expr(val_expr);
        if key_val is not None and value_val is not None {
            helpers = self.dict_helpers.get(dict_key);
            if helpers is not None {
                # Coerce to match helper's expected types
                expected_key_type = helpers["key_type"];
                expected_val_type = helpers["val_type"];
                if key_val.type != expected_key_type {
                    key_val = self.builder.bitcast(
                        key_val, expected_key_type, name="dcompr.kcast"
                    );
                }
                if value_val.type != expected_val_type {
                    value_val = self.builder.bitcast(
                        value_val, expected_val_type, name="dcompr.vcast"
                    );
                }
                self.builder.call(helpers["set"], [dict_val, key_val, value_val]);
            }
        }
        return;
    }
    inner = comprs[idx];
    loop_target = inner.target;
    collection = inner.collection;
    conditionals = inner.conditional or [];
    # Check for range() calls
    if isinstance(collection, uni.FuncCall) {
        call_name = self._get_name(collection.target);
        if call_name == "range" {
            self._codegen_dict_compr_range_loop(
                inner,
                comprs,
                idx,
                dict_val,
                key_expr,
                val_expr,
                dict_key,
                conditionals
            );
            return;
        }
    }
    # List iteration
    coll_name = self._get_name(collection);
    coll_val = self._codegen_expr(collection);
    if coll_val is None {
        return;
    }
    coll_elem_type_name = self._infer_list_elem_type(coll_val);
    if coll_elem_type_name is None {
        return;
    }
    coll_helpers = self.list_helpers.get(coll_elem_type_name);
    if coll_helpers is None {
        return;
    }
    loop_var_name = self._get_name(loop_target);
    if loop_var_name is None {
        return;
    }
    i64 = ir.IntType(64);
    len_val = self.builder.call(coll_helpers["len"], [coll_val], name="dcompr.len");
    idx_alloca = self.builder.alloca(i64, name="dcompr.idx");
    self.builder.store(ir.Constant(i64, 0), idx_alloca);
    actual_elem_type = coll_helpers["elem_type"];
    loop_alloca = self.builder.alloca(actual_elem_type, name=loop_var_name);
    self.local_vars[loop_var_name] = loop_alloca;
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="dcompr.cond");
    body_bb = func.append_basic_block(name="dcompr.body");
    incr_bb = func.append_basic_block(name="dcompr.incr");
    end_bb = func.append_basic_block(name="dcompr.end");
    self.builder.branch(cond_bb);
    self.builder.position_at_end(cond_bb);
    cur_idx = self.builder.load(idx_alloca, name="dcompr.cur.idx");
    cmp = self.builder.icmp_signed("<", cur_idx, len_val, name="dcompr.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);
    self.builder.position_at_end(body_bb);
    body_idx = self.builder.load(idx_alloca, name="dcompr.body.idx");
    elem_val = self.builder.call(
        coll_helpers["get"], [coll_val, body_idx], name="dcompr.elem"
    );
    self.builder.store(elem_val, loop_alloca);
    if conditionals {
        filter_bb = func.append_basic_block(name="dcompr.filter");
        skip_bb = func.append_basic_block(name="dcompr.skip");
        all_cond = self._codegen_expr(conditionals[0]);
        if all_cond is not None {
            all_cond = self._to_bool(all_cond);
            for i in range(1, len(conditionals)) {
                next_cond = self._codegen_expr(conditionals[i]);
                if next_cond is not None {
                    next_cond = self._to_bool(next_cond);
                    all_cond = self.builder.and_(
                        all_cond, next_cond, name="dcompr.and"
                    );
                }
            }
            self.builder.cbranch(all_cond, filter_bb, skip_bb);
        } else {
            self.builder.branch(filter_bb);
        }
        self.builder.position_at_end(filter_bb);
        self._codegen_dict_compr_loops(
            comprs, idx + 1, dict_val, key_expr, val_expr, dict_key
        );
        if not self.builder.block.is_terminated {
            self.builder.branch(skip_bb);
        }
        self.builder.position_at_end(skip_bb);
        self.builder.branch(incr_bb);
    } else {
        self._codegen_dict_compr_loops(
            comprs, idx + 1, dict_val, key_expr, val_expr, dict_key
        );
        if not self.builder.block.is_terminated {
            self.builder.branch(incr_bb);
        }
    }
    self.builder.position_at_end(incr_bb);
    inc_idx = self.builder.load(idx_alloca, name="dcompr.inc.idx");
    next_idx = self.builder.add(inc_idx, ir.Constant(i64, 1), name="dcompr.next.idx");
    self.builder.store(next_idx, idx_alloca);
    self.builder.branch(cond_bb);
    self.builder.position_at_end(end_bb);
}

"""Handle range-based dict comprehension loop."""
impl NaIRGenPass._codegen_dict_compr_range_loop(
    inner: uni.InnerCompr,
    comprs: list,
    idx: int,
    dict_val: ir.Value,
    key_expr: uni.UniNode,
    val_expr: uni.UniNode,
    dict_key: str,
    conditionals: list
) -> None {
    collection = inner.collection;
    loop_target = inner.target;
    loop_var_name = self._get_name(loop_target);
    if loop_var_name is None {
        return;
    }
    params = collection.params or [];
    start_val: (ir.Value | None) = None;
    stop_val: (ir.Value | None) = None;
    if len(params) == 1 {
        start_val = ir.Constant(ir.IntType(64), 0);
        stop_val = self._codegen_expr(params[0]);
    } elif len(params) >= 2 {
        start_val = self._codegen_expr(params[0]);
        stop_val = self._codegen_expr(params[1]);
    }
    if start_val is None or stop_val is None {
        return;
    }
    i64 = ir.IntType(64);
    start_val = self._coerce_type(start_val, i64);
    stop_val = self._coerce_type(stop_val, i64);
    loop_alloca = self.builder.alloca(i64, name=loop_var_name);
    self.builder.store(start_val, loop_alloca);
    self.local_vars[loop_var_name] = loop_alloca;
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="dcompr.range.cond");
    body_bb = func.append_basic_block(name="dcompr.range.body");
    incr_bb = func.append_basic_block(name="dcompr.range.incr");
    end_bb = func.append_basic_block(name="dcompr.range.end");
    self.builder.branch(cond_bb);
    self.builder.position_at_end(cond_bb);
    i_val = self.builder.load(loop_alloca, name=loop_var_name);
    cmp = self.builder.icmp_signed("<", i_val, stop_val, name="dcompr.range.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);
    self.builder.position_at_end(body_bb);
    if conditionals {
        filter_bb = func.append_basic_block(name="dcompr.range.filter");
        skip_bb = func.append_basic_block(name="dcompr.range.skip");
        all_cond = self._codegen_expr(conditionals[0]);
        if all_cond is not None {
            all_cond = self._to_bool(all_cond);
            for i in range(1, len(conditionals)) {
                next_cond = self._codegen_expr(conditionals[i]);
                if next_cond is not None {
                    next_cond = self._to_bool(next_cond);
                    all_cond = self.builder.and_(
                        all_cond, next_cond, name="dcompr.and"
                    );
                }
            }
            self.builder.cbranch(all_cond, filter_bb, skip_bb);
        } else {
            self.builder.branch(filter_bb);
        }
        self.builder.position_at_end(filter_bb);
        self._codegen_dict_compr_loops(
            comprs, idx + 1, dict_val, key_expr, val_expr, dict_key
        );
        if not self.builder.block.is_terminated {
            self.builder.branch(skip_bb);
        }
        self.builder.position_at_end(skip_bb);
        self.builder.branch(incr_bb);
    } else {
        self._codegen_dict_compr_loops(
            comprs, idx + 1, dict_val, key_expr, val_expr, dict_key
        );
        if not self.builder.block.is_terminated {
            self.builder.branch(incr_bb);
        }
    }
    self.builder.position_at_end(incr_bb);
    i_cur = self.builder.load(loop_alloca, name="dcompr.range.cur");
    i_next = self.builder.add(i_cur, ir.Constant(i64, 1), name="dcompr.range.next");
    self.builder.store(i_next, loop_alloca);
    self.builder.branch(cond_bb);
    self.builder.position_at_end(end_bb);
}

"""Generate code for a set comprehension {expr for x in iterable if cond}."""
impl NaIRGenPass._codegen_set_compr(nd: uni.SetCompr) -> (ir.Value | None) {
    if not nd.compr {
        return None;
    }
    # Determine element type and size
    elem_type_name = "i64";
    elem_type = ir.IntType(64);
    elem_size = 0;
    out_expr = nd.out_expr;
    # Check if output is a tuple
    if isinstance(out_expr, uni.TupleVal) {
        # Estimate tuple size from number of elements (assume int-sized elements)
        elem_count = len(out_expr.values) if out_expr.values else 0;
        elem_size = elem_count * 8;  # Assume 8 bytes per element
        elem_type_name = f"tuple{elem_size}";
        elem_type = ir.IntType(8).as_pointer();
    } elif isinstance(out_expr, uni.FuncCall) {
        call_name = self._get_name(out_expr.target);
        if call_name is not None and call_name in self.struct_types {
            elem_type_name = "ptr";
            elem_type = ir.IntType(8).as_pointer();
        }
    }
    # Ensure set helpers exist
    self._emit_set_helpers(elem_type_name, elem_type, elem_size);
    helpers = self.set_helpers.get(elem_type_name);
    if helpers is None {
        return None;
    }
    # Create new empty set
    set_val = self.builder.call(helpers["new"], [], name="scompr.set");
    # Generate nested loops
    self._codegen_set_compr_loops(nd.compr, 0, set_val, out_expr, elem_type_name);
    return set_val;
}

"""Recursively generate nested loops for set comprehension."""
impl NaIRGenPass._codegen_set_compr_loops(
    comprs: list,
    idx: int,
    set_val: ir.Value,
    out_expr: uni.UniNode,
    elem_type_name: str
) -> None {
    if idx >= len(comprs) {
        # Base case: evaluate and add element
        val = self._codegen_expr(out_expr);
        if val is not None {
            helpers = self.set_helpers.get(elem_type_name);
            if helpers is not None {
                i8p = ir.IntType(8).as_pointer();
                if elem_type_name == "ptr" and isinstance(val.type, ir.PointerType) {
                    val = self.builder.bitcast(val, i8p, name="scompr.cast");
                }
                self.builder.call(helpers["add"], [set_val, val]);
            }
        }
        return;
    }
    inner = comprs[idx];
    loop_target = inner.target;
    collection = inner.collection;
    conditionals = inner.conditional or [];
    # Check for range() calls
    if isinstance(collection, uni.FuncCall) {
        call_name = self._get_name(collection.target);
        if call_name == "range" {
            self._codegen_set_compr_range_loop(
                inner, comprs, idx, set_val, out_expr, elem_type_name, conditionals
            );
            return;
        }
    }
    # List iteration
    coll_val = self._codegen_expr(collection);
    if coll_val is None {
        return;
    }
    coll_elem_type_name = self._infer_list_elem_type(coll_val);
    if coll_elem_type_name is None {
        return;
    }
    coll_helpers = self.list_helpers.get(coll_elem_type_name);
    if coll_helpers is None {
        return;
    }
    loop_var_name = self._get_name(loop_target);
    if loop_var_name is None {
        return;
    }
    i64 = ir.IntType(64);
    len_val = self.builder.call(coll_helpers["len"], [coll_val], name="scompr.len");
    idx_alloca = self.builder.alloca(i64, name="scompr.idx");
    self.builder.store(ir.Constant(i64, 0), idx_alloca);
    actual_elem_type = coll_helpers["elem_type"];
    loop_alloca = self.builder.alloca(actual_elem_type, name=loop_var_name);
    self.local_vars[loop_var_name] = loop_alloca;
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="scompr.cond");
    body_bb = func.append_basic_block(name="scompr.body");
    incr_bb = func.append_basic_block(name="scompr.incr");
    end_bb = func.append_basic_block(name="scompr.end");
    self.builder.branch(cond_bb);
    self.builder.position_at_end(cond_bb);
    cur_idx = self.builder.load(idx_alloca, name="scompr.cur.idx");
    cmp = self.builder.icmp_signed("<", cur_idx, len_val, name="scompr.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);
    self.builder.position_at_end(body_bb);
    body_idx = self.builder.load(idx_alloca, name="scompr.body.idx");
    elem = self.builder.call(
        coll_helpers["get"], [coll_val, body_idx], name="scompr.elem"
    );
    self.builder.store(elem, loop_alloca);
    if conditionals {
        filter_bb = func.append_basic_block(name="scompr.filter");
        skip_bb = func.append_basic_block(name="scompr.skip");
        all_cond = self._codegen_expr(conditionals[0]);
        if all_cond is not None {
            all_cond = self._to_bool(all_cond);
            for i in range(1, len(conditionals)) {
                next_cond = self._codegen_expr(conditionals[i]);
                if next_cond is not None {
                    next_cond = self._to_bool(next_cond);
                    all_cond = self.builder.and_(
                        all_cond, next_cond, name="scompr.and"
                    );
                }
            }
            self.builder.cbranch(all_cond, filter_bb, skip_bb);
        } else {
            self.builder.branch(filter_bb);
        }
        self.builder.position_at_end(filter_bb);
        self._codegen_set_compr_loops(
            comprs, idx + 1, set_val, out_expr, elem_type_name
        );
        if not self.builder.block.is_terminated {
            self.builder.branch(skip_bb);
        }
        self.builder.position_at_end(skip_bb);
        self.builder.branch(incr_bb);
    } else {
        self._codegen_set_compr_loops(
            comprs, idx + 1, set_val, out_expr, elem_type_name
        );
        if not self.builder.block.is_terminated {
            self.builder.branch(incr_bb);
        }
    }
    self.builder.position_at_end(incr_bb);
    inc_idx = self.builder.load(idx_alloca, name="scompr.inc.idx");
    next_idx = self.builder.add(inc_idx, ir.Constant(i64, 1), name="scompr.next.idx");
    self.builder.store(next_idx, idx_alloca);
    self.builder.branch(cond_bb);
    self.builder.position_at_end(end_bb);
}

"""Handle range-based set comprehension loop."""
impl NaIRGenPass._codegen_set_compr_range_loop(
    inner: uni.InnerCompr,
    comprs: list,
    idx: int,
    set_val: ir.Value,
    out_expr: uni.UniNode,
    elem_type_name: str,
    conditionals: list
) -> None {
    collection = inner.collection;
    loop_target = inner.target;
    loop_var_name = self._get_name(loop_target);
    if loop_var_name is None {
        return;
    }
    params = collection.params or [];
    start_val: (ir.Value | None) = None;
    stop_val: (ir.Value | None) = None;
    if len(params) == 1 {
        start_val = ir.Constant(ir.IntType(64), 0);
        stop_val = self._codegen_expr(params[0]);
    } elif len(params) >= 2 {
        start_val = self._codegen_expr(params[0]);
        stop_val = self._codegen_expr(params[1]);
    }
    if start_val is None or stop_val is None {
        return;
    }
    i64 = ir.IntType(64);
    start_val = self._coerce_type(start_val, i64);
    stop_val = self._coerce_type(stop_val, i64);
    loop_alloca = self.builder.alloca(i64, name=loop_var_name);
    self.builder.store(start_val, loop_alloca);
    self.local_vars[loop_var_name] = loop_alloca;
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="scompr.range.cond");
    body_bb = func.append_basic_block(name="scompr.range.body");
    incr_bb = func.append_basic_block(name="scompr.range.incr");
    end_bb = func.append_basic_block(name="scompr.range.end");
    self.builder.branch(cond_bb);
    self.builder.position_at_end(cond_bb);
    i_val = self.builder.load(loop_alloca, name=loop_var_name);
    cmp = self.builder.icmp_signed("<", i_val, stop_val, name="scompr.range.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);
    self.builder.position_at_end(body_bb);
    if conditionals {
        filter_bb = func.append_basic_block(name="scompr.range.filter");
        skip_bb = func.append_basic_block(name="scompr.range.skip");
        all_cond = self._codegen_expr(conditionals[0]);
        if all_cond is not None {
            all_cond = self._to_bool(all_cond);
            for i in range(1, len(conditionals)) {
                next_cond = self._codegen_expr(conditionals[i]);
                if next_cond is not None {
                    next_cond = self._to_bool(next_cond);
                    all_cond = self.builder.and_(
                        all_cond, next_cond, name="scompr.and"
                    );
                }
            }
            self.builder.cbranch(all_cond, filter_bb, skip_bb);
        } else {
            self.builder.branch(filter_bb);
        }
        self.builder.position_at_end(filter_bb);
        self._codegen_set_compr_loops(
            comprs, idx + 1, set_val, out_expr, elem_type_name
        );
        if not self.builder.block.is_terminated {
            self.builder.branch(skip_bb);
        }
        self.builder.position_at_end(skip_bb);
        self.builder.branch(incr_bb);
    } else {
        self._codegen_set_compr_loops(
            comprs, idx + 1, set_val, out_expr, elem_type_name
        );
        if not self.builder.block.is_terminated {
            self.builder.branch(incr_bb);
        }
    }
    self.builder.position_at_end(incr_bb);
    i_cur = self.builder.load(loop_alloca, name="scompr.range.cur");
    i_next = self.builder.add(i_cur, ir.Constant(i64, 1), name="scompr.range.next");
    self.builder.store(i_next, loop_alloca);
    self.builder.branch(cond_bb);
    self.builder.position_at_end(end_bb);
}

"""Handle range-based comprehension loop."""
impl NaIRGenPass._codegen_compr_range_loop(
    inner: uni.InnerCompr,
    comprs: list,
    idx: int,
    list_val: ir.Value,
    out_expr: uni.UniNode,
    elem_type_name: str,
    conditionals: list
) -> None {
    collection = inner.collection;
    loop_target = inner.target;
    loop_var_name = self._get_name(loop_target);
    if loop_var_name is None {
        return;
    }
    # Parse range parameters
    params = collection.params or [];
    start_val: (ir.Value | None) = None;
    stop_val: (ir.Value | None) = None;
    if len(params) == 1 {
        start_val = ir.Constant(ir.IntType(64), 0);
        stop_val = self._codegen_expr(params[0]);
    } elif len(params) >= 2 {
        start_val = self._codegen_expr(params[0]);
        stop_val = self._codegen_expr(params[1]);
    }
    if start_val is None or stop_val is None {
        return;
    }
    i64 = ir.IntType(64);
    start_val = self._coerce_type(start_val, i64);
    stop_val = self._coerce_type(stop_val, i64);
    # Allocate loop variable
    loop_alloca = self.builder.alloca(i64, name=loop_var_name);
    self.builder.store(start_val, loop_alloca);
    self.local_vars[loop_var_name] = loop_alloca;
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="compr.range.cond");
    body_bb = func.append_basic_block(name="compr.range.body");
    incr_bb = func.append_basic_block(name="compr.range.incr");
    end_bb = func.append_basic_block(name="compr.range.end");
    self.builder.branch(cond_bb);
    # Condition: i < stop
    self.builder.position_at_end(cond_bb);
    i_val = self.builder.load(loop_alloca, name=loop_var_name);
    cmp = self.builder.icmp_signed("<", i_val, stop_val, name="compr.range.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);
    # Body
    self.builder.position_at_end(body_bb);
    # Check conditionals
    if conditionals {
        filter_bb = func.append_basic_block(name="compr.range.filter");
        skip_bb = func.append_basic_block(name="compr.range.skip");
        all_cond = self._codegen_expr(conditionals[0]);
        if all_cond is not None {
            all_cond = self._to_bool(all_cond);
            for i in range(1, len(conditionals)) {
                next_cond = self._codegen_expr(conditionals[i]);
                if next_cond is not None {
                    next_cond = self._to_bool(next_cond);
                    all_cond = self.builder.and_(all_cond, next_cond, name="compr.and");
                }
            }
            self.builder.cbranch(all_cond, filter_bb, skip_bb);
        } else {
            self.builder.branch(filter_bb);
        }
        self.builder.position_at_end(filter_bb);
        self._codegen_compr_loops(comprs, idx + 1, list_val, out_expr, elem_type_name);
        if not self.builder.block.is_terminated {
            self.builder.branch(skip_bb);
        }
        self.builder.position_at_end(skip_bb);
        self.builder.branch(incr_bb);
    } else {
        self._codegen_compr_loops(comprs, idx + 1, list_val, out_expr, elem_type_name);
        if not self.builder.block.is_terminated {
            self.builder.branch(incr_bb);
        }
    }
    # Increment
    self.builder.position_at_end(incr_bb);
    i_cur = self.builder.load(loop_alloca, name="compr.range.cur");
    i_next = self.builder.add(i_cur, ir.Constant(i64, 1), name="compr.range.next");
    self.builder.store(i_next, loop_alloca);
    self.builder.branch(cond_bb);
    # Continue after loop
    self.builder.position_at_end(end_bb);
}
