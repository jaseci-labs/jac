impl NaIRGenPass._codegen_list_compr(nd: uni.ListCompr) -> (ir.Value | None) {
    if not nd.compr {
        return None;
    }

    elem_type_name = "i64";
    _own_spec = self._elem_spec_of(nd);
    if _own_spec == "i64" and isinstance(nd.out_expr, uni.Null) {
        _own_spec = "ptr";
    }

    if _own_spec is None
        and isinstance(nd.out_expr, uni.Expr)
        and nd.out_expr.type is not None {
        _out_low = self._lower_type(nd.out_expr.type);
        if _out_low is not None {
            if isinstance(_out_low, ir.DoubleType) {
                _own_spec = "f64";
            } elif isinstance(_out_low, ir.PointerType) {
                _own_spec = "ptr";
            } elif self?.jacval_type and _out_low == self.jacval_type {
                _own_spec = "jacval";
            } elif isinstance(_out_low, ir.IntType) {
                _own_spec = "i64";
            }
        }
    }

    if _own_spec is None and self._is_boolean_result_expr(nd.out_expr) {
        _own_spec = "i64";
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
            call_name = self._arch_ref_key(nd.out_expr.target)
                or self._get_name(nd.out_expr.target);
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
    } elif elem_type_name == "jacval" and self?.jacval_type {
        self._emit_list_helpers("jacval", self.jacval_type);
    } else {
        self._emit_list_helpers("i64", ir.IntType(64));
    }
    helpers = self.list_helpers.get(elem_type_name);
    if helpers is None {
        return None;
    }

    _lcompr_loc = f"{os.path.basename(self.module.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    list_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_lcompr_loc, name="compr.list"
    );
    self._nogc_stamp_elem_drops(list_val, self._nogc_type_arg_mangles(nd));

    self._codegen_compr_walk(
        NativeComprehension(
            comprs=nd.compr,
            kind="list",
            acc=list_val,
            key_expr=nd.out_expr,
            spec=elem_type_name
        ),
        0
    );

    return list_val;
}

impl NaIRGenPass._is_boolean_result_expr(nd: (uni.UniNode | None)) -> bool {
    import from jaclang.compiler.types.type_utils { primitive_type_name_of }
    while isinstance(nd, (uni.CfgExpr, uni.AtomUnit)) {
        nd = nd.expr if isinstance(nd, uni.CfgExpr) else nd.value;
    }
    if isinstance(nd, (uni.CompareExpr, uni.Bool)) {
        return True;
    }
    if isinstance(nd, uni.UnaryExpr) {
        return nd.op.name == Tok.NOT;
    }
    if isinstance(nd, uni.BoolExpr) {
        if not nd.values {
            return False;
        }
        for _operand in nd.values {
            if not self._is_boolean_result_expr(_operand) {
                return False;
            }
        }
        return True;
    }
    if isinstance(nd, uni.Expr) {
        return primitive_type_name_of(nd.type) == "bool";
    }
    return False;
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
    key_type: ir.Type = ir.IntType(64);
    val_type: ir.Type = ir.IntType(64);
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
        key_type_name = self._tuple_spec_name(struct_type);
    }

    if isinstance(val_expr, uni.TupleVal) {
        val_type_name = "ptr";
        val_type = ir.IntType(8).as_pointer();
    } elif isinstance(val_expr, uni.FuncCall) {
        call_name = self._arch_ref_key(val_expr.target)
            or self._get_name(val_expr.target);
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

    if val_type_name == "i64" and self._struct_name_of(val_expr) is not None {
        val_type_name = "ptr";
        val_type = ir.IntType(8).as_pointer();
    }

    resolved_key = self._elem_storage_llvm(key_expr.type);
    if resolved_key is not None {
        key_type = ir.IntType(8).as_pointer()
            if self._str_desc_ty is not None and resolved_key == self._str_desc_ty
            else resolved_key;
        (key_type_name, key_size) = self._hash_key_spec(key_type);
    }
    resolved_value = self._elem_storage_llvm(val_expr.type);
    if resolved_value is not None {
        val_type = ir.IntType(8).as_pointer()
            if self._str_desc_ty is not None and resolved_value == self._str_desc_ty
            else resolved_value;
        val_type_name = self._dict_val_spec(val_type);
    }

    self._emit_dict_helpers(key_type_name, val_type_name, key_type, val_type, key_size);
    dict_key = f"{key_type_name}:{val_type_name}";
    helpers = self.dict_helpers.get(dict_key);
    if helpers is None {
        return None;
    }

    _dcompr_loc = f"{os.path.basename(self.module.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    dict_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_dcompr_loc, name="dcompr.dict"
    );
    self._nogc_stamp_elem_drops(dict_val, self._nogc_type_arg_mangles(nd));

    self._codegen_compr_walk(
        NativeComprehension(
            comprs=nd.compr,
            kind="dict",
            acc=dict_val,
            key_expr=key_expr,
            val_expr=val_expr,
            spec=dict_key
        ),
        0
    );

    return dict_val;
}

impl NaIRGenPass._codegen_set_compr(nd: uni.SetCompr) -> (ir.Value | None) {
    if not nd.compr {
        return None;
    }

    elem_type_name = "i64";
    elem_type: ir.Type = ir.IntType(64);
    elem_size = 0;
    out_expr = nd.out_expr;

    if isinstance(out_expr, uni.TupleVal) {
        elem_count = len(out_expr.values) if out_expr.values else 0;
        elem_size = elem_count * 8;
        elem_type_name = f"tuple{elem_size}";
        elem_type = ir.IntType(8).as_pointer();
    } elif isinstance(out_expr, uni.FuncCall) {
        call_name = self._arch_ref_key(out_expr.target)
            or self._get_name(out_expr.target);
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

    if elem_type_name == "i64" and self._struct_name_of(out_expr) is not None {
        elem_type_name = "ptr";
        elem_type = ir.IntType(8).as_pointer();
    }

    if isinstance(out_expr, uni.Expr) and out_expr.type is not None {
        resolved = self._elem_storage_llvm(out_expr.type);
        if resolved is not None {
            elem_type = ir.IntType(8).as_pointer()
                if self._str_desc_ty is not None and resolved == self._str_desc_ty
                else resolved;
            (elem_type_name, elem_size) = self._hash_key_spec(elem_type);
        }
    }

    self._emit_set_helpers(elem_type_name, elem_type, elem_size);
    helpers = self.set_helpers.get(elem_type_name);
    if helpers is None {
        return None;
    }

    _scompr_loc = f"{os.path.basename(self.module.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    set_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_scompr_loc, name="scompr.set"
    );
    self._nogc_stamp_elem_drops(set_val, self._nogc_type_arg_mangles(nd));

    self._codegen_compr_walk(
        NativeComprehension(
            comprs=nd.compr,
            kind="set",
            acc=set_val,
            key_expr=out_expr,
            spec=elem_type_name
        ),
        0
    );

    return set_val;
}

impl NaIRGenPass._emit_compr_element(compr: NativeComprehension) -> None {
    kind = compr.kind;
    acc = compr.acc;
    key_expr = compr.key_expr;
    val_expr = compr.val_expr;
    spec = compr.spec;
    if kind == "dict" {
        key_val = self._str_norm_optional(self._codegen_expr(key_expr));
        value_val = self._str_norm_optional(self._codegen_expr(val_expr));
        value_val = self._nogc_elem_prep(val_expr, value_val);
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
        val = self._str_norm_optional(self._codegen_expr(key_expr));
        val = self._nogc_elem_prep(key_expr, val);
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

    val = self._str_norm_optional(self._codegen_expr(key_expr));
    val = self._nogc_elem_prep(key_expr, val);
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
                _compr_loc = f"{os.path.basename(self.module.loc.mod_path)}:{_compr_loc_raw.first_line}";
            }
            if not _compr_loc {
                _compr_loc = f"{os.path.basename(self.module.loc.mod_path)}:0";
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

impl NaIRGenPass._codegen_compr_walk(compr: NativeComprehension, idx: int) -> None {
    if idx >= len(compr.comprs) {
        self._emit_compr_element(compr);
        return;
    }
    state = self._enter_bindings(inherit=True);
    try {
        self._codegen_compr_walk_body(compr, idx);
    } finally {
        self._leave_bindings(state, release=True);
    }
}

impl NaIRGenPass._codegen_compr_step(
    compr: NativeComprehension, idx: int, next_bb: ir.Block
) -> None {
    func = self.builder.function;
    for cond in (compr.comprs[idx].conditional or []) {
        cond_val = self._codegen_expr(cond);
        if cond_val is None {
            continue;
        }
        pass_bb = func.append_basic_block(name="compr.pass");
        self.builder.cbranch(self._consume_bool(cond_val), pass_bb, next_bb);
        self.builder.position_at_end(pass_bb);
    }
    self._codegen_compr_walk(compr, idx + 1);
    if not self.builder.block.is_terminated {
        self.builder.branch(next_bb);
    }
}

impl NaIRGenPass._codegen_compr_walk_body(
    compr: NativeComprehension, idx: int
) -> None {
    inner = compr.comprs[idx];
    loop_target = inner.target;
    collection = inner.collection;

    if isinstance(collection, uni.FuncCall)
        and self._get_name(collection.target) == "range"
        and collection.call_kind == "builtin"
        and len(collection.params or []) <= 2 {
        self._codegen_compr_range_walk(compr, idx);
        return;
    }

    source = self._iter_source(collection);
    if source is not None {
        self._codegen_compr_iter_walk(compr, idx, source);
        return;
    }
    coll_val = self._opt_unwrap_iterable(self._codegen_expr(collection));
    if coll_val is None {
        return;
    }

    coll_elem_type_name: str | None = None;
    dict_key = self._dict_key_reconcile(self._dict_key_of(collection), coll_val);
    if dict_key is not None {
        coll_helpers = self.dict_helpers.get(dict_key);
        if coll_helpers is None {
            return;
        }
        coll_get = coll_helpers["get_key"];
        actual_elem_type = coll_helpers["key_type"];
        coll_elem_type_name = dict_key.split(":")[0];
    } else {
        coll_elem_type_name = self._infer_list_elem_type(coll_val);
        if coll_elem_type_name is None {
            built = self._make_iter_from_value(self._str_norm(coll_val), collection);
            if built is not None {
                self._codegen_compr_iter_walk(compr, idx, (built[0], built[2], True));
            } else {
                self.emit(
                    E5092,
                    node_override=collection,
                    kind="expression",
                    name="comprehension over a value with no native iterator",
                    help_text="Native code iterates lists, dicts, sets, strings, bytes, ranges, iterators and archetypes that implement the iterator protocol."
                );
            }
            return;
        }
        coll_helpers = self.list_helpers.get(coll_elem_type_name);
        if coll_helpers is None {
            return;
        }
        coll_get = coll_helpers["get"];
        actual_elem_type = coll_helpers["elem_type"];
    }
    unpack_target = loop_target if isinstance(loop_target, uni.TupleVal) else None;
    loop_var_name = self._get_name(loop_target);
    if loop_var_name is None and unpack_target is None {
        return;
    }
    targets = unpack_target.values if unpack_target is not None else [loop_target];
    names: list[str] = [];
    for target in targets {
        name = self._get_name(target);
        if name is not None {
            names.append(name);
        }
    }
    self._shadow_bindings(names);
    i64 = ir.IntType(64);
    len_val = self.builder.call(coll_helpers["len"], [coll_val], name="compr.len");
    idx_alloca = self._entry_alloca(i64, "compr.idx");
    self.builder.store(ir.Constant(i64, 0), idx_alloca);

    inner_type: (ir.Type | None) = None;
    if dict_key is None and coll_elem_type_name == "ptr" {
        inner_type = self._list_elem_llvm_of(collection);
        if inner_type is None {
            inner_type = self._elem_storage_llvm(
                self._flow_narrowed_type_of(loop_target)
            );
        }
        if inner_type is not None and not isinstance(inner_type, ir.PointerType) {
            inner_type = None;
        }
        if inner_type is not None {
            actual_elem_type = inner_type;
        }
    }
    loop_alloca: ir.Value | None = None;
    if unpack_target is None and loop_var_name is not None {
        loop_alloca = self._entry_alloca(actual_elem_type, loop_var_name);

        if isinstance(actual_elem_type, ir.PointerType) {
            _compr_saved_block = self.builder.block;
            self.builder.position_after(loop_alloca);
            self.builder.store(ir.Constant(actual_elem_type, None), loop_alloca);
            self.builder.position_at_end(_compr_saved_block);
        }
        self.local_vars[loop_var_name] = loop_alloca;
    }
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
    elem_val: ir.Value = self.builder.call(
        coll_get, [coll_val, body_idx], name="compr.elem"
    );

    if elem_val.type != actual_elem_type {
        if isinstance(elem_val.type, ir.PointerType)
            and isinstance(actual_elem_type, ir.PointerType) {
            elem_val = self.builder.bitcast(
                elem_val, actual_elem_type, name="compr.elem.cast"
            );
        }
    }

    if unpack_target is not None {
        if not self._codegen_tuple_unpack(unpack_target.values, elem_val, None) {
            self.emit(
                E5092,
                node_override=unpack_target,
                kind="comprehension target",
                name="tuple unpacking"
            );
            return;
        }
    } elif loop_alloca is not None {
        if isinstance(actual_elem_type, ir.PointerType) {
            _compr_old = self.builder.load(loop_alloca, name="compr.old");
            self._emit_rc_release_simple(_compr_old, op="compr_elem", loc="");
            self._emit_rc_retain(elem_val, op="compr_elem", loc="");
        } elif actual_elem_type == self.jacval_type {
            self._emit_slot_rebind(loop_alloca, elem_val, owned=False, op="compr_elem");
        }
        self.builder.store(elem_val, loop_alloca);
    }
    self._codegen_compr_step(compr, idx, incr_bb);
    self.builder.position_at_end(incr_bb);
    inc_idx = self.builder.load(idx_alloca, name="compr.inc.idx");
    next_idx = self.builder.add(inc_idx, ir.Constant(i64, 1), name="compr.next.idx");
    self.builder.store(next_idx, idx_alloca);
    self.builder.branch(cond_bb);
    self.builder.position_at_end(end_bb);

    if isinstance(coll_val.type, ir.PointerType) and self._is_owned(coll_val) {
        _coll_loc = f"{os.path.basename(self.module.loc.mod_path)}:0";
        self._emit_rc_release_simple(coll_val, op="compr_coll", loc=_coll_loc);
    }
}

impl NaIRGenPass._codegen_compr_iter_walk(
    compr: NativeComprehension, idx: int, source: tuple[ir.Value, ir.Type, bool]
) -> None {
    inner = compr.comprs[idx];
    (iter_val, elem_type, owns_iter) = source;
    unpack_target = inner.target if isinstance(inner.target, uni.TupleVal) else None;
    targets: list[uni.Expr] = list(unpack_target.values or [])
        if unpack_target is not None
        else [inner.target];
    names: list[str] = [];
    for target in targets {
        name = self._get_name(target);
        if name is not None {
            names.append(name);
        }
    }
    self._shadow_bindings(names);
    i8p = ir.IntType(8).as_pointer();
    elem_slot = self._entry_alloca(elem_type, "compr.iter.elem");
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="compr.iter.cond");
    body_bb = func.append_basic_block(name="compr.iter.body");
    end_bb = func.append_basic_block(name="compr.iter.end");
    self.builder.branch(cond_bb);
    self.builder.position_at_end(cond_bb);
    got = self._emit_iter_advance(
        self.builder,
        iter_val,
        self.builder.bitcast(elem_slot, i8p, name="compr.iter.out")
    );
    self.builder.cbranch(got, body_bb, end_bb);
    self.builder.position_at_end(body_bb);
    yielded = self.builder.load(elem_slot, name="compr.iter.value");
    if unpack_target is None {
        yielded = self.builder.insert_value(
            ir.Constant(ir.LiteralStructType([elem_type]), None),
            yielded,
            0,
            name="compr.iter.binding"
        );
    }
    if not self._codegen_tuple_unpack(targets, yielded, None) {
        self.emit(
            E5092,
            node_override=inner.target,
            kind="comprehension target",
            name="tuple unpacking"
        );
        return;
    }
    self._codegen_compr_step(compr, idx, cond_bb);
    self.builder.position_at_end(end_bb);
    if owns_iter {
        self._emit_rc_release_simple(iter_val, op="compr_iter", loc="");
    }
}

impl NaIRGenPass._codegen_compr_range_walk(
    compr: NativeComprehension, idx: int
) -> None {
    inner = compr.comprs[idx];
    collection = inner.collection;
    loop_target = inner.target;
    loop_var_name = self._get_name(loop_target);
    if loop_var_name is None {
        return;
    }
    if not isinstance(collection, uni.FuncCall) {
        return;
    }
    params: Sequence[any] = collection.params or [];
    start_val: (ir.Value | None) = None;
    stop_val: (ir.Value | None) = None;
    if len(params) == 1 {
        start_val = ir.Constant(ir.IntType(64), 0);
        stop_val = self._codegen_expr(params[0]);
    } elif len(params) == 2 {
        start_val = self._codegen_expr(params[0]);
        stop_val = self._codegen_expr(params[1]);
    }
    if start_val is None or stop_val is None {
        return;
    }
    i64 = ir.IntType(64);
    start_val = self._coerce_type(start_val, i64);
    stop_val = self._coerce_type(stop_val, i64);
    self._shadow_bindings([loop_var_name]);
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
    self._codegen_compr_step(compr, idx, incr_bb);
    self.builder.position_at_end(incr_bb);
    i_cur = self.builder.load(loop_alloca, name="compr.range.cur");
    i_next = self.builder.add(i_cur, ir.Constant(i64, 1), name="compr.range.next");
    self.builder.store(i_next, loop_alloca);
    self.builder.branch(cond_bb);
    self.builder.position_at_end(end_bb);
}
