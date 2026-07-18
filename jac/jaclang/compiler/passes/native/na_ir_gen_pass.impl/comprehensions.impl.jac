impl NaIRGenPass._codegen_list_compr(nd: uni.ListCompr) -> (ir.Value | None) {
    if not nd.compr {
        return None;
    }

    elem_type_name = "i64";
    _own_spec = self._elem_spec_of(nd);
    if _own_spec == "i64" and isinstance(nd.out_expr, uni.Null) {
        _own_spec = "ptr";
    }
    if _own_spec is not None {
        elem_type_name = _own_spec;
    } else {
        first_compr = nd.compr[0];
        hint = self._elem_spec_of(first_compr.collection);
        if hint is not None {
            elem_type_name = hint;
        }
        if elem_type_name == "i64" and isinstance(nd.out_expr, uni.TupleVal) {
            elem_type_name = "ptr";
        }
        if elem_type_name == "i64" and isinstance(nd.out_expr, uni.FuncCall) {
            call_name = self._get_name(nd.out_expr.target);
            if call_name is not None and call_name in self.struct_types {
                elem_type_name = "ptr";
            }
        }
        if elem_type_name == "i64" and isinstance(nd.out_expr, uni.ListCompr) {
            elem_type_name = "ptr";
        }
        if elem_type_name == "i64" and isinstance(nd.out_expr, uni.ListVal) {
            elem_type_name = "ptr";
        }
        if elem_type_name == "i64" and isinstance(nd.out_expr, uni.Null) {
            elem_type_name = "ptr";
        }
        if elem_type_name == "i64" and isinstance(nd.out_expr, uni.Name) {
            out_name = nd.out_expr.value;

            for compr in nd.compr {
                target_name = self._get_name(compr.target);
                if target_name == out_name {
                    hint = self._elem_spec_of(compr.collection);
                    if hint is not None {
                        elem_type_name = hint;
                    }
                    break;
                }
            }
        }
    }

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

    _lcompr_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    list_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_lcompr_loc, name="compr.list"
    );

    self._codegen_compr_walk(
        nd.compr, 0, "list", list_val, nd.out_expr, None, elem_type_name
    );

    return list_val;
}

impl NaIRGenPass._codegen_dict_compr(nd: uni.DictCompr) -> (ir.Value | None) {
    if not nd.compr {
        return None;
    }

    if nd.kv_pair is None {
        return None;
    }
    key_expr = nd.kv_pair.key;
    val_expr = nd.kv_pair.value;
    if key_expr is None or val_expr is None {
        return None;
    }

    key_type_name = "i64";
    val_type_name = "i64";
    key_type = ir.IntType(64);
    val_type = ir.IntType(64);
    key_size = 0;

    if isinstance(key_expr, uni.TupleVal) {
        elem_types: list[ir.Type] = [];
        for v in key_expr.values {
            elem_types.append(ir.IntType(64));
        }
        n = len(elem_types);
        tuple_key_str = f"Tuple.{n}." + ".".join([str(t) for t in elem_types]);
        if tuple_key_str not in self.tuple_types {
            struct_type = ir.LiteralStructType(elem_types);
            self.tuple_types[tuple_key_str] = struct_type;
        }
        struct_type = self.tuple_types[tuple_key_str];
        key_type = struct_type.as_pointer();
        key_size = self._get_struct_size(struct_type);
        key_type_name = f"tuple{key_size}";
    }

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
        val_type_name = "ptr";
        val_type = ir.IntType(8).as_pointer();
    } elif isinstance(val_expr, uni.Name) {
        if (
            self._struct_name_of(val_expr) is not None
            or self._list_spec_of(val_expr) is not None
        ) {
            val_type_name = "ptr";
            val_type = ir.IntType(8).as_pointer();
        }
    }

    self._emit_dict_helpers(key_type_name, val_type_name, key_type, val_type, key_size);
    dict_key = f"{key_type_name}:{val_type_name}";
    helpers = self.dict_helpers.get(dict_key);
    if helpers is None {
        return None;
    }

    _dcompr_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    dict_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_dcompr_loc, name="dcompr.dict"
    );

    self._codegen_compr_walk(
        nd.compr, 0, "dict", dict_val, key_expr, val_expr, dict_key
    );

    return dict_val;
}

impl NaIRGenPass._codegen_set_compr(nd: uni.SetCompr) -> (ir.Value | None) {
    if not nd.compr {
        return None;
    }

    elem_type_name = "i64";
    elem_type = ir.IntType(64);
    elem_size = 0;
    out_expr = nd.out_expr;

    if isinstance(out_expr, uni.TupleVal) {
        elem_count = len(out_expr.values) if out_expr.values else 0;
        elem_size = elem_count * 8;
        elem_type_name = f"tuple{elem_size}";
        elem_type = ir.IntType(8).as_pointer();
    } elif isinstance(out_expr, uni.FuncCall) {
        call_name = self._get_name(out_expr.target);
        if call_name is not None and call_name in self.struct_types {
            elem_type_name = "ptr";
            elem_type = ir.IntType(8).as_pointer();
        }
    } elif isinstance(out_expr, uni.AtomTrailer) and out_expr.is_attr {
        field_name = self._get_name(out_expr.right);
        target_name = self._get_name(out_expr.target);
        if field_name is not None and target_name is not None and nd.compr {
            loop_var = self._get_name(nd.compr[0].target);
            if loop_var == target_name {
                loop_struct = self._infer_compr_elem_struct(nd.compr[0]);
                if loop_struct is not None and loop_struct in self.struct_field_types {
                    ftype = self.struct_field_types[loop_struct].get(field_name);
                    if ftype is not None and isinstance(ftype, ir.PointerType) {
                        pointee = ftype.pointee;
                        if isinstance(pointee, ir.LiteralStructType) {
                            total = 0;
                            for el in pointee.elements {
                                total += el.width // 8 if el?.width else 8;
                            }
                            elem_size = total;
                            elem_type_name = f"tuple{elem_size}";
                            elem_type = ir.IntType(8).as_pointer();
                        } else {
                            elem_type_name = "ptr";
                            elem_type = ir.IntType(8).as_pointer();
                        }
                    } elif ftype is not None and isinstance(ftype, ir.IntType) {
                        elem_type_name = "i64";
                        elem_type = ftype;
                    }
                }
            }
        }
    }

    self._emit_set_helpers(elem_type_name, elem_type, elem_size);
    helpers = self.set_helpers.get(elem_type_name);
    if helpers is None {
        return None;
    }

    _scompr_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    set_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_scompr_loc, name="scompr.set"
    );

    self._codegen_compr_walk(
        nd.compr, 0, "set", set_val, out_expr, None, elem_type_name
    );

    return set_val;
}


impl NaIRGenPass._emit_compr_element(
    kind: str,
    acc: ir.Value,
    key_expr: uni.UniNode,
    val_expr: (uni.UniNode | None),
    spec: str
) -> None {
    if kind == "dict" {
        key_val = self._codegen_expr(key_expr);
        value_val = self._codegen_expr(val_expr);
        if key_val is not None and value_val is not None {
            helpers = self.dict_helpers.get(spec);
            if helpers is not None {
                expected_key_type = helpers["key_type"];
                expected_val_type = helpers["val_type"];
                key_val = self._box_value_tuple(key_val);
                _boxed_key = key_val;
                key_val = self._coerce_type(key_val, expected_key_type);
                value_val = self._box_value_tuple(value_val);
                _boxed_val_compr = value_val;
                value_val = self._coerce_type(value_val, expected_val_type);
                self.builder.call(helpers["set"], [acc, key_val, value_val]);

                if isinstance(_boxed_key.type, ir.PointerType)
                and self._is_owned(_boxed_key) {
                    self._emit_rc_release_simple(_boxed_key, op="dcompr_key", loc="");
                }
                if isinstance(_boxed_val_compr.type, ir.PointerType)
                and self._is_owned(_boxed_val_compr) {
                    self._emit_rc_release_simple(
                        _boxed_val_compr, op="dcompr_val", loc=""
                    );
                }
            }
        }
        return;
    }
    if kind == "set" {
        val = self._codegen_expr(key_expr);
        if val is not None {
            helpers = self.set_helpers.get(spec);
            if helpers is not None {
                val = self._box_value_tuple(val);
                _scompr_boxed = val;
                expected_type = helpers["elem_type"];
                if val.type != expected_type {
                    if isinstance(val.type, ir.PointerType)
                    and isinstance(expected_type, ir.PointerType) {
                        val = self.builder.bitcast(
                            val, expected_type, name="scompr.cast"
                        );
                    } else {
                        val = self._coerce_type(val, expected_type);
                    }
                }
                self.builder.call(helpers["add"], [acc, val]);

                if isinstance(_scompr_boxed.type, ir.PointerType)
                and self._is_owned(_scompr_boxed) {
                    self._emit_rc_release_simple(
                        _scompr_boxed, op="scompr_elem", loc=""
                    );
                }
            }
        }
        return;
    }

    val = self._codegen_expr(key_expr);
    if val is not None {
        helpers = self.list_helpers.get(spec);
        if helpers is not None {
            _compr_append_orig = val;
            val = self._box_value_tuple(val);
            _compr_boxed_val = val;
            if spec == "ptr" and isinstance(val.type, ir.PointerType) {
                i8p = ir.IntType(8).as_pointer();
                val = self.builder.bitcast(val, i8p, name="compr.cast");
            }
            val = self._coerce_type(val, helpers["elem_type"]);
            _compr_loc_raw = getattr(_compr_append_orig, 'jac_loc', key_expr?.loc);
            _compr_loc: str = "";
            if isinstance(_compr_loc_raw, str) {
                _compr_loc = _compr_loc_raw;
            } elif _compr_loc_raw is not None {
                _compr_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{_compr_loc_raw.first_line}";
            }
            if not _compr_loc {
                _compr_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:0";
            }
            self._rc_call_with_ctx(
                helpers["append"], [acc, val], op="compr_elem", loc=_compr_loc
            );

            if isinstance(_compr_boxed_val.type, ir.PointerType)
            and self._is_owned(_compr_boxed_val) {
                self._emit_rc_release_simple(
                    _compr_boxed_val, op="compr_elem", loc=_compr_loc
                );
            }
        }
    }
}

impl NaIRGenPass._codegen_compr_walk(
    comprs: list,
    idx: int,
    kind: str,
    acc: ir.Value,
    key_expr: uni.UniNode,
    val_expr: (uni.UniNode | None),
    spec: str
) -> None {
    if idx >= len(comprs) {
        self._emit_compr_element(kind, acc, key_expr, val_expr, spec);
        return;
    }
    inner = comprs[idx];
    loop_target = inner.target;
    collection = inner.collection;
    conditionals = inner.conditional or [];

    if isinstance(collection, uni.FuncCall) {
        call_name = self._get_name(collection.target);

        if call_name == "range" and collection.call_kind == "builtin" {
            self._codegen_compr_range_walk(
                inner, comprs, idx, kind, acc, key_expr, val_expr, spec, conditionals
            );
            return;
        }
    }

    coll_val = self._codegen_expr(collection);
    if coll_val is None {
        return;
    }

    coll_elem_type_name = self._infer_list_elem_type(coll_val);
    if coll_elem_type_name is None {
        coll_elem_type_name = self._elem_spec_of(collection);
    }
    if coll_elem_type_name is None and isinstance(coll_val.type, ir.PointerType) {
        coll_elem_type_name = "ptr";
    }
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
    len_val = self.builder.call(coll_helpers["len"], [coll_val], name="compr.len");
    idx_alloca = self._entry_alloca(i64, "compr.idx");
    self.builder.store(ir.Constant(i64, 0), idx_alloca);

    actual_elem_type = coll_helpers["elem_type"];
    inner_type: (ir.Type | None) = None;
    if coll_elem_type_name == "ptr" {
        inner_type = self._list_elem_llvm_of(collection);
        if inner_type is not None and not isinstance(inner_type, ir.PointerType) {
            inner_type = None;
        }
        if inner_type is not None {
            actual_elem_type = inner_type;
        }
    }
    loop_alloca = self._entry_alloca(actual_elem_type, loop_var_name);

    if isinstance(actual_elem_type, ir.PointerType) {
        _compr_saved_block = self.builder.block;
        self.builder.position_after(loop_alloca);
        self.builder.store(ir.Constant(actual_elem_type, None), loop_alloca);
        self.builder.position_at_end(_compr_saved_block);
    }
    self.local_vars[loop_var_name] = loop_alloca;
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="compr.cond");
    body_bb = func.append_basic_block(name="compr.body");
    incr_bb = func.append_basic_block(name="compr.incr");
    end_bb = func.append_basic_block(name="compr.end");
    self.builder.branch(cond_bb);
    self.builder.position_at_end(cond_bb);
    cur_idx = self.builder.load(idx_alloca, name="compr.cur.idx");
    cmp = self.builder.icmp_signed("<", cur_idx, len_val, name="compr.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);
    self.builder.position_at_end(body_bb);
    body_idx = self.builder.load(idx_alloca, name="compr.body.idx");
    elem_val = self.builder.call(
        coll_helpers["get"], [coll_val, body_idx], name="compr.elem"
    );

    if elem_val.type != actual_elem_type {
        if isinstance(elem_val.type, ir.PointerType)
        and isinstance(actual_elem_type, ir.PointerType) {
            elem_val = self.builder.bitcast(
                elem_val, actual_elem_type, name="compr.elem.cast"
            );
        }
    }

    if isinstance(actual_elem_type, ir.PointerType) {
        _compr_old = self.builder.load(loop_alloca, name="compr.old");
        self._emit_rc_release_simple(_compr_old, op="compr_elem", loc="");
        self._emit_rc_retain(elem_val, op="compr_elem", loc="");
    }
    self.builder.store(elem_val, loop_alloca);
    if conditionals {
        filter_bb = func.append_basic_block(name="compr.filter");
        skip_bb = func.append_basic_block(name="compr.skip");
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
        self._codegen_compr_walk(comprs, idx + 1, kind, acc, key_expr, val_expr, spec);
        if not self.builder.block.is_terminated {
            self.builder.branch(skip_bb);
        }
        self.builder.position_at_end(skip_bb);
        self.builder.branch(incr_bb);
    } else {
        self._codegen_compr_walk(comprs, idx + 1, kind, acc, key_expr, val_expr, spec);
        if not self.builder.block.is_terminated {
            self.builder.branch(incr_bb);
        }
    }
    self.builder.position_at_end(incr_bb);
    inc_idx = self.builder.load(idx_alloca, name="compr.inc.idx");
    next_idx = self.builder.add(inc_idx, ir.Constant(i64, 1), name="compr.next.idx");
    self.builder.store(next_idx, idx_alloca);
    self.builder.branch(cond_bb);
    self.builder.position_at_end(end_bb);

    if isinstance(coll_val.type, ir.PointerType) and self._is_owned(coll_val) {
        _coll_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:0";
        self._emit_rc_release_simple(coll_val, op="compr_coll", loc=_coll_loc);
    }
}

impl NaIRGenPass._codegen_compr_range_walk(
    inner: uni.InnerCompr,
    comprs: list,
    idx: int,
    kind: str,
    acc: ir.Value,
    key_expr: uni.UniNode,
    val_expr: (uni.UniNode | None),
    spec: str,
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
    loop_alloca = self._entry_alloca(i64, loop_var_name);
    self.builder.store(start_val, loop_alloca);
    self.local_vars[loop_var_name] = loop_alloca;
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="compr.range.cond");
    body_bb = func.append_basic_block(name="compr.range.body");
    incr_bb = func.append_basic_block(name="compr.range.incr");
    end_bb = func.append_basic_block(name="compr.range.end");
    self.builder.branch(cond_bb);
    self.builder.position_at_end(cond_bb);
    i_val = self.builder.load(loop_alloca, name=loop_var_name);
    cmp = self.builder.icmp_signed("<", i_val, stop_val, name="compr.range.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);
    self.builder.position_at_end(body_bb);
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
        self._codegen_compr_walk(comprs, idx + 1, kind, acc, key_expr, val_expr, spec);
        if not self.builder.block.is_terminated {
            self.builder.branch(skip_bb);
        }
        self.builder.position_at_end(skip_bb);
        self.builder.branch(incr_bb);
    } else {
        self._codegen_compr_walk(comprs, idx + 1, kind, acc, key_expr, val_expr, spec);
        if not self.builder.block.is_terminated {
            self.builder.branch(incr_bb);
        }
    }
    self.builder.position_at_end(incr_bb);
    i_cur = self.builder.load(loop_alloca, name="compr.range.cur");
    i_next = self.builder.add(i_cur, ir.Constant(i64, 1), name="compr.range.next");
    self.builder.store(i_next, loop_alloca);
    self.builder.branch(cond_bb);
    self.builder.position_at_end(end_bb);
}
