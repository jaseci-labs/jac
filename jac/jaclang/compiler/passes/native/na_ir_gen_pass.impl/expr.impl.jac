import os;

impl NaIRGenPass._codegen_expr(nd: (uni.UniNode | None)) -> (ir.Value | None) {
    if nd is None {
        return None;
    }
    _jac_loc: str = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    if isinstance(nd, uni.Int) {
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

    if isinstance(nd, uni.CfgExpr) {
        return self._codegen_expr(nd.expr);
    }
    _result: (ir.Value | None) = None;
    if isinstance(nd, uni.Name) {
        _result = self._codegen_name(nd);
    } elif isinstance(nd, uni.BinaryExpr) {
        _result = self._codegen_binary(nd);
    } elif isinstance(nd, uni.CompareExpr) {
        _result = self._codegen_compare(nd);
    } elif isinstance(nd, uni.UnaryExpr) {
        _result = self._codegen_unary(nd);
    } elif isinstance(nd, uni.FuncCall) {
        _result = self._codegen_call(nd);
    } elif isinstance(nd, uni.AtomTrailer) {
        _result = self._codegen_atom_trailer(nd);
    } elif isinstance(nd, uni.BoolExpr) {
        _result = self._codegen_bool_expr(nd);
    } elif isinstance(nd, uni.IfElseExpr) {
        _result = self._codegen_if_else_expr(nd);
    } elif isinstance(nd, uni.MultiString) {
        _result = self._codegen_multistring(nd);
    } elif isinstance(nd, uni.String) {
        _result = self._codegen_string(nd);
    } elif isinstance(nd, uni.FString) {
        _result = self._codegen_fstring(nd);
    } elif isinstance(nd, uni.ListVal) {
        _result = self._codegen_list_val(nd);
    } elif isinstance(nd, uni.DictCompr) {
        _result = self._codegen_dict_compr(nd);
    } elif isinstance(nd, uni.SetCompr) {
        _result = self._codegen_set_compr(nd);
    } elif isinstance(nd, uni.ListCompr) {
        _result = self._codegen_list_compr(nd);
    } elif isinstance(nd, uni.TupleVal) {
        _result = self._codegen_tuple_val(nd);
    } elif isinstance(nd, uni.DictVal) {
        _result = self._codegen_dict_val(nd);
    } elif isinstance(nd, uni.SetVal) {
        _result = self._codegen_set_val(nd);
    } elif isinstance(nd, uni.AtomUnit) {
        _result = self._codegen_expr(nd.value);
    } elif isinstance(nd, uni.CastExpr) {
        _result = self._codegen_expr(nd.value);
    } elif isinstance(nd, uni.LambdaExpr) {
        _result = self._codegen_lambda(nd);
    } elif isinstance(nd, uni.AwaitExpr) {
        _result = self._codegen_expr(nd.target);
    } elif isinstance(nd, uni.ConcurrentExpr) {
        _result = self._codegen_expr(nd.target);
    } elif isinstance(nd, uni.EdgeRefTrailer) {
        _result = self._codegen_edge_ref_trailer(nd);
    } elif (
        isinstance(nd, uni.Slice)
        or isinstance(nd, uni.IndexSlice)
        or isinstance(nd, uni.KVPair)
        or isinstance(nd, uni.KWPair)
        or isinstance(nd, uni.InnerCompr)
        or isinstance(nd, uni.FormattedValue)
    ) { } else {
        self.emit(E5090, node_override=nd, kind="expression", name=type(nd).__name__);
    }

    if _result is not None {
        _result.jac_loc = _jac_loc;

        if isinstance(_result.type, ir.PointerType) {
            import from jaclang.compiler.ownership { Ownership, result_ownership }
            if result_ownership(nd) == Ownership.OWNED {
                self._mark_owned(_result);
            }
        }
    }
    return _result;
}

impl NaIRGenPass._codegen_required(nd: (uni.UniNode | None)) -> (ir.Value | None) {
    if nd is None {
        return None;
    }
    _errs_before = len(self.errors_had);
    val = self._codegen_expr(nd);
    if val is None and len(self.errors_had) == _errs_before {
        self.emit(E5090, node_override=nd, kind="expression", name=type(nd).__name__);
    }
    return val;
}

impl NaIRGenPass._codegen_lambda(nd: uni.LambdaExpr) -> (ir.Value | None) {
    sig = nd.signature;
    param_types: list[ir.Type] = [];
    param_names: list[str] = [];
    if sig is not None and sig.params {
        for p in sig.params {
            p_name = p.name.value if p?.name and p.name else f"arg{len(param_names)}";

            p_type = self._resolve_jac_type(p)
                if p?.type_tag and p.type_tag is not None
                else ir.IntType(64);
            param_types.append(p_type);
            param_names.append(p_name);
        }
    }
    ret_type = ir.IntType(64);
    if sig is not None and sig.return_type is not None {
        ret_type = self._resolve_jac_type(sig.return_type);
    }

    captures: list[tuple] = [];
    free_var_names: list[str] = [];
    for cap_sym in nd.captures {
        if cap_sym.sym_name not in free_var_names {
            free_var_names.append(cap_sym.sym_name);
        }
    }
    for fv_name in free_var_names {
        if fv_name in self.local_vars {
            alloca = self.local_vars[fv_name];
            val = self.builder.load(alloca, name=f"cap.{fv_name}");
            captures.append((fv_name, val, val.type));
        }
    }

    all_param_types = list(param_types);
    all_param_names = list(param_names);
    for (cap_name, _cap_val, cap_type) in captures {
        all_param_types.append(cap_type);
        all_param_names.append(cap_name);
    }

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

    saved_builder = self._builder;
    saved_locals = self.local_vars;
    saved_func_symtab = dict(self.func_symtab);
    entry_bb = anon_fn.append_basic_block("entry");
    self._builder = ir.IRBuilder(entry_bb);
    self.local_vars = {};

    for (i, arg) in enumerate(anon_fn.args) {
        alloca = self._entry_alloca(arg.type, all_param_names[i]);
        self.builder.store(arg, alloca);
        self.local_vars[all_param_names[i]] = alloca;
    }

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

    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.func_symtab = saved_func_symtab;

    if captures {
        capture_info: list[tuple] = [];
        for (cap_name, _cap_val, _cap_type) in captures {
            capture_info.append((cap_name, self.local_vars[cap_name]));
        }
        self._pending_lambda_captures = capture_info;
    } else {
        self._pending_lambda_captures = None;
    }
    return anon_fn;
}

impl NaIRGenPass._codegen_name(nd: uni.Name) -> (ir.Value | None) {
    var_name = nd.value;
    if var_name in self.local_vars {
        alloca = self.local_vars[var_name];
        return self.builder.load(alloca, name=var_name);
    }
    if var_name in self.func_symtab {
        return self.func_symtab[var_name];
    }

    if var_name in self.global_vars {
        global_var = self.global_vars[var_name];
        return self.builder.load(global_var, name=f"glob.{var_name}");
    }
    return None;
}

impl NaIRGenPass._codegen_pipe_fwd(nd: uni.BinaryExpr) -> (ir.Value | None) {
    if isinstance(nd.left, uni.TupleVal) and nd.left.values {
        call_params = list(nd.left.values);
    } else {
        call_params = [nd.left];
    }
    call = uni.FuncCall(
        target=nd.right,
        params=call_params,
        genai_call=None,
        kid=[nd.right, *call_params]
    );
    call.parent = nd.parent;
    return self._codegen_expr(call);
}

impl NaIRGenPass._codegen_walrus(nd: uni.BinaryExpr) -> (ir.Value | None) {
    var_name = self._get_name(nd.left);
    if var_name is None {
        self.emit(E5090, node_override=nd, kind="binary operator", name="WALRUS_EQ");
        return None;
    }
    value = self._codegen_expr(nd.right);
    if value is None {
        return None;
    }
    _loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    if var_name in self.local_vars {
        alloca = self.local_vars[var_name];
        slot_type = alloca.type.pointee;
        value = self._coerce_type(value, slot_type);
        if isinstance(slot_type, ir.PointerType) {
            if not self._is_owned(value) {
                self._emit_rc_retain(value, op="walrus", loc=_loc);
            }
            old_val = self.builder.load(alloca, name=f"{var_name}.old");
            self._emit_rc_release_typed(old_val, op="overwrite", loc=_loc);
        }
        self.builder.store(value, alloca);
    } else {
        var_type = value.type;
        alloca = self._entry_alloca(var_type, var_name);
        if isinstance(var_type, ir.PointerType) and not self._is_owned(value) {
            self._emit_rc_retain(value, op="walrus", loc=_loc);
        }
        self.builder.store(value, alloca);
        self.local_vars[var_name] = alloca;
    }

    return self.builder.load(alloca, name=var_name);
}

impl NaIRGenPass._codegen_binary(nd: uni.BinaryExpr) -> (ir.Value | None) {
    if isinstance(nd.op, uni.ConnectOp) {
        return self._codegen_connect(nd);
    }
    op = nd.op.name if isinstance(nd.op, uni.Token) else str(nd.op);

    if op == Tok.WALRUS_EQ {
        return self._codegen_walrus(nd);
    }
    if op == Tok.PIPE_FWD {
        return self._codegen_pipe_fwd(nd);
    }
    if op == Tok.KW_SPAWN {
        return self._codegen_spawn(nd);
    }
    left = self._codegen_expr(nd.left);
    right = self._codegen_expr(nd.right);
    if left is None or right is None {
        return None;
    }
    result = self._emit_binary_op(op, left, right);

    if result is not None {
        i8p = ir.IntType(8).as_pointer();
        if op == Tok.PLUS and left.type == i8p and right.type == i8p {
            if self._is_owned(left) {
                self._emit_rc_release_typed(
                    left, op="binop_lhs", loc=getattr(left, 'jac_loc', '')
                );
            }
            if self._is_owned(right) {
                self._emit_rc_release_typed(
                    right, op="binop_rhs", loc=getattr(right, 'jac_loc', '')
                );
            }
        }
    }
    return result;
}

impl NaIRGenPass._codegen_spawn(nd: uni.BinaryExpr) -> (ir.Value | None) {
    left_val = self._codegen_expr(nd.left);
    right_val = self._codegen_expr(nd.right);
    if left_val is None or right_val is None {
        return None;
    }

    left_name = self._spawn_operand_name(nd.left);
    right_name = self._spawn_operand_name(nd.right);
    left_is_walker = left_name is not None and self._is_walker_arch(left_name);
    right_is_walker = right_name is not None and self._is_walker_arch(right_name);
    (walker_name, walker_val, loc_val) = (None, None, None);
    if left_is_walker {
        (walker_name, walker_val, loc_val) = (left_name, left_val, right_val);
    } elif right_is_walker {
        (walker_name, walker_val, loc_val) = (right_name, right_val, left_val);
    } else {
        self.emit(
            E5090,
            node_override=nd,
            kind="binary operator",
            name="KW_SPAWN",
            help_text=self._xmod_osp_help([left_name, right_name])
        );
        return left_val;
    }

    _loc_name = right_name if left_is_walker else left_name;
    _xhelp = self._xmod_osp_help([_loc_name]);
    if _xhelp is not None {
        self.emit(
            E5090,
            node_override=nd,
            kind="binary operator",
            name="KW_SPAWN",
            help_text=_xhelp
        );
        return walker_val;
    }

    _spawn_model = self.ir_in.gen.osp_model;
    if (_spawn_model is not None)
    and (walker_name in _spawn_model.tags)
    and (self._osp_rt_global is not None)
    and ("osp_spawn" in self.func_symtab) {
        return self._codegen_kernel_spawn(walker_name, walker_val, loc_val);
    }

    self.emit(E5090, node_override=nd, kind="binary operator", name="KW_SPAWN");
    return walker_val;
}

impl NaIRGenPass._codegen_kernel_spawn(
    walker_name: str, walker_val: ir.Value, loc_val: ir.Value
) -> (ir.Value | None) {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);

    if self._osp_ensure_fn is not None {
        self.builder.call(self._osp_ensure_fn, []);
    }
    osp_spawn_fn = self.func_symtab.get("osp_spawn");
    if osp_spawn_fn is None {
        return walker_val;
    }
    _argtys = osp_spawn_fn.function_type.args;

    _h = self.list_helpers.get("i64");
    _starts = self._rc_call_with_ctx(
        _h["new"], [], op="new", loc="", name="spawn.starts"
    );
    self._rc_call_with_ctx(
        _h["append"], [_starts, self._coerce_type(loc_val, i64)], op="append", loc=""
    );

    _ks_model = self.ir_in.gen.osp_model;
    _wtag = _ks_model.local_index(walker_name) if (_ks_model is not None) else -1;
    if _wtag < 0 {
        _wtag = 0;
    }
    _descp = self.builder.load(
        self.builder.gep(
            self._osp_desc_global,
            [ir.Constant(i32, 0), ir.Constant(i32, _wtag)],
            name="spawn.descp"
        ),
        name="spawn.desc.i8"
    );
    _rt = self.builder.load(self._osp_rt_global, name="spawn.rt");
    self.builder.call(
        osp_spawn_fn,
        [
            self._coerce_type(_rt, _argtys[0]),
            self._coerce_type(walker_val, _argtys[1]),
            self._coerce_type(_descp, _argtys[2]),
            self._coerce_type(_starts, _argtys[3])
        ]
    );
    return walker_val;
}

impl NaIRGenPass._spawn_operand_name(nd: uni.UniNode) -> (str | None) {
    if isinstance(nd, uni.FuncCall) {
        return self._get_name(nd.target);
    }
    if isinstance(nd, uni.Name) {
        return self._struct_name_of(nd);
    }
    return None;
}

impl NaIRGenPass._is_walker_arch(name: str) -> bool {
    _model = self.ir_in.gen.osp_model;
    return (_model is not None) and (_model.arch_kind.get(name) == "walker");
}

impl NaIRGenPass._codegen_compare(nd: uni.CompareExpr) -> (ir.Value | None) {
    left = self._codegen_expr(nd.left);
    if left is None or not nd.rights or not nd.ops {
        return None;
    }
    right = self._codegen_expr(nd.rights[0]);
    if right is None {
        return None;
    }

    _cmp_left_orig = left;
    _cmp_right_orig = right;
    op = nd.ops[0].name if isinstance(nd.ops[0], uni.Token) else str(nd.ops[0]);

    if op == Tok.KW_IN or op == Tok.KW_NIN {
        is_not_in = op == Tok.KW_NIN;

        for (dict_key, helpers) in self.dict_helpers.items() {
            dict_type = self.dict_types.get(dict_key);
            if dict_type is not None and right.type == dict_type.as_pointer() {
                key_type = helpers["key_type"];
                left_coerced = self._coerce_type(left, key_type);
                result = self.builder.call(
                    helpers["contains"], [right, left_coerced], name="dict.contains"
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

                self._release_owned_operands(
                    left_coerced, _cmp_right_orig, op="cmp_in_dict"
                );
                return result;
            }
        }

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

                self._release_owned_operands(
                    left_coerced, _cmp_right_orig, op="cmp_in_set"
                );
                return result;
            }
        }

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

                self._release_owned_operands(
                    left_coerced, _cmp_right_orig, op="cmp_in_list"
                );
                return result;
            }
        }

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

            diff = self.builder.sub(val, start, name="rin.diff");
            rem = self.builder.srem(diff, step, name="rin.rem");
            rem_zero = self.builder.icmp_signed(
                "==", rem, ir.Constant(i64, 0), name="rin.remz"
            );

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

        if self._is_bytes_value(left) and self._is_bytes_value(right) {
            i64 = ir.IntType(64);
            is_found = self._emit_bytes_contains(left, right);
            result = self.builder.zext(is_found, i64, name="by.in.i64");
            if is_not_in {
                result = self.builder.icmp_signed(
                    "==", result, ir.Constant(i64, 0), name="by.notin"
                );
                result = self.builder.zext(result, i64, name="by.notin.i64");
            }
            return result;
        }

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

    if op == Tok.KW_IS {
        if isinstance(left.type, ir.PointerType)
        and isinstance(right.type, ir.PointerType) {
            if left.type != right.type {
                right = self.builder.bitcast(right, left.type);
            }
            _is_result = self.builder.icmp_unsigned("==", left, right, name="is.eq");
            if isinstance(_cmp_left_orig.type, ir.PointerType)
            and self._is_owned(_cmp_left_orig) {
                self._emit_rc_release_simple(
                    _cmp_left_orig,
                    op="cmp_is",
                    loc=getattr(_cmp_left_orig, 'jac_loc', '')
                );
            }
            if isinstance(_cmp_right_orig.type, ir.PointerType)
            and self._is_owned(_cmp_right_orig) {
                self._emit_rc_release_simple(
                    _cmp_right_orig,
                    op="cmp_is",
                    loc=getattr(_cmp_right_orig, 'jac_loc', '')
                );
            }
            return _is_result;
        }

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
            _isn_result = self.builder.icmp_unsigned("!=", left, right, name="is.ne");
            if isinstance(_cmp_left_orig.type, ir.PointerType)
            and self._is_owned(_cmp_left_orig) {
                self._emit_rc_release_simple(
                    _cmp_left_orig,
                    op="cmp_isn",
                    loc=getattr(_cmp_left_orig, 'jac_loc', '')
                );
            }
            if isinstance(_cmp_right_orig.type, ir.PointerType)
            and self._is_owned(_cmp_right_orig) {
                self._emit_rc_release_simple(
                    _cmp_right_orig,
                    op="cmp_isn",
                    loc=getattr(_cmp_right_orig, 'jac_loc', '')
                );
            }
            return _isn_result;
        }

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
    _cmp_result = self._emit_comparison(op, left, right, is_float);
    if isinstance(_cmp_left_orig.type, ir.PointerType)
    and self._is_owned(_cmp_left_orig) {
        self._emit_rc_release_simple(
            _cmp_left_orig, op="cmp_op", loc=getattr(_cmp_left_orig, 'jac_loc', '')
        );
    }
    if isinstance(_cmp_right_orig.type, ir.PointerType)
    and self._is_owned(_cmp_right_orig) {
        self._emit_rc_release_simple(
            _cmp_right_orig, op="cmp_op", loc=getattr(_cmp_right_orig, 'jac_loc', '')
        );
    }
    return _cmp_result;
}

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
        return self.builder.not_(self._to_bool(operand), name="not");
    } elif op == Tok.BW_NOT {
        if isinstance(operand.type, ir.IntType) {
            all_ones = ir.Constant(operand.type, -1);
            return self.builder.xor(operand, all_ones, name="bwnot");
        }
    } elif op == Tok.PLUS {
        if operand.type == self.complex_struct_type.as_pointer() {
            return operand;
        }
    }
    return None;
}

impl NaIRGenPass._codegen_bool_expr(nd: uni.BoolExpr) -> (ir.Value | None) {
    if not nd.values {
        return None;
    }
    op_name = nd.op.name if isinstance(nd.op, uni.Token) else str(nd.op);
    is_and = op_name == Tok.KW_AND;

    result = self._codegen_expr(nd.values[0]);
    if result is None {
        return None;
    }
    result = self._to_bool(result);

    for i in range(1, len(nd.values)) {
        func = self.builder.function;
        rhs_bb = func.append_basic_block(name=f"bool.rhs.{i}");
        merge_bb = func.append_basic_block(name=f"bool.merge.{i}");
        entry_bb = self.builder.block;
        if is_and {
            self.builder.cbranch(result, rhs_bb, merge_bb);
        } else {
            self.builder.cbranch(result, merge_bb, rhs_bb);
        }

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

    self.builder.position_at_end(then_bb);
    then_val = self._codegen_expr(nd.value);
    then_end_bb = self.builder.block;
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }

    self.builder.position_at_end(else_bb);
    else_val = self._codegen_expr(nd.else_value);
    else_end_bb = self.builder.block;
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }

    if then_val is not None and else_val is not None {
        if then_val.type != else_val.type {
            if isinstance(then_val.type, ir.DoubleType)
            or isinstance(else_val.type, ir.DoubleType) {
                if isinstance(then_val.type, ir.IntType) {
                    self.builder.position_before(then_end_bb.terminator);
                    then_val = self.builder.sitofp(
                        then_val, ir.DoubleType(), name="ternary.cast"
                    );
                }
                if isinstance(else_val.type, ir.IntType) {
                    self.builder.position_before(else_end_bb.terminator);
                    else_val = self.builder.sitofp(
                        else_val, ir.DoubleType(), name="ternary.cast"
                    );
                }
            } elif isinstance(then_val.type, ir.IntType)
            and isinstance(else_val.type, ir.IntType) {
                if then_val.type.width > else_val.type.width {
                    self.builder.position_before(else_end_bb.terminator);
                    else_val = self.builder.zext(
                        else_val, then_val.type, name="ternary.widen"
                    );
                } else {
                    self.builder.position_before(then_end_bb.terminator);
                    then_val = self.builder.zext(
                        then_val, else_val.type, name="ternary.widen"
                    );
                }
            }
        }
        self.builder.position_at_end(merge_bb);
        phi = self.builder.phi(then_val.type, name="ternary.result");
        phi.add_incoming(then_val, then_end_bb);
        phi.add_incoming(else_val, else_end_bb);
        return phi;
    }
    return None;
}

impl NaIRGenPass._codegen_atom_trailer(nd: uni.AtomTrailer) -> (ir.Value | None) {
    if nd.is_attr {
        target_name = self._get_name(nd.target);
        right_name = self._get_name(nd.right);

        _cls_name = self._codegen_class_name(nd);
        if _cls_name is not None {
            return _cls_name;
        }

        if (right_name == "value" or right_name == "name")
        and isinstance(nd.target, uni.AtomTrailer)
        and nd.target.is_attr {
            mem_enum = self._get_name(nd.target.target);
            mem_name = self._get_name(nd.target.right);
            if mem_enum is not None
            and mem_name is not None
            and f"{mem_enum}.{mem_name}" in self.enum_values {
                member_val = self.enum_values[f"{mem_enum}.{mem_name}"];
                if mem_enum in self.enum_string_values {
                    return self._codegen_enum_value_lookup(
                        mem_enum, member_val, use_name=(right_name == "name")
                    );
                }

                if right_name == "value" {
                    return member_val;
                }

                ordinal = self.enum_member_ordinal.get(f"{mem_enum}.{mem_name}");
                if ordinal is not None {
                    return self._codegen_enum_value_lookup(
                        mem_enum, ir.Constant(ir.IntType(64), ordinal), use_name=True
                    );
                }
            }
        }
        if target_name is not None and right_name is not None {
            if (
                target_name == "sys"
                and self?._native_stdlib_modules
                and "sys" in self._native_stdlib_modules
            ) {
                if right_name == "argv" {
                    return self._emit_sys_argv();
                }
                if right_name == "platform" {
                    import platform as _plat;
                    return self._make_global_string(_plat.system().lower());
                }
                if right_name == "maxsize" {
                    return ir.Constant(ir.IntType(64), 0x7FFFFFFFFFFFFFFF);
                }
                if right_name == "byteorder" {
                    import sys as _sys;
                    return self._make_global_string(_sys.byteorder);
                }
            }

            if (
                target_name == "math"
                and self?._native_stdlib_modules
                and "math" in self._native_stdlib_modules
            ) {
                _mc = self._emit_math_const(right_name);
                if _mc is not None {
                    return _mc;
                }
            }

            full_name = f"{target_name}.{right_name}";
            if full_name in self.enum_values {
                return self.enum_values[full_name];
            }

            if (
                target_name in self.struct_types and target_name not in self.local_vars
            ) {
                for _cn in self._mro_of(target_name) {
                    _sf = f"{_cn}.{right_name}";
                    if _sf in self.static_fields {
                        return self.builder.load(
                            self.static_fields[_sf], name=f"sfld.{right_name}"
                        );
                    }
                }
            }

            if (right_name == "value" or right_name == "name") {
                enum_name = self._enum_name_of(nd.target);
                if enum_name is not None and enum_name in self.enum_types {
                    ordinal_val = self._codegen_expr(nd.target);
                    if ordinal_val is not None {
                        use_name = right_name == "name";
                        return self._codegen_enum_value_lookup(
                            enum_name, ordinal_val, use_name=use_name
                        );
                    }
                }
            }

            _fa_type_name = self._struct_name_of(nd.target);
            if _fa_type_name is not None {
                type_name = _fa_type_name;
                obj_val = self._codegen_expr(nd.target);
                if obj_val is not None {
                    return self._codegen_field_access(obj_val, right_name, type_name);
                }
            }
        }

        if right_name is not None {
            obj_val = self._codegen_expr(nd.target);
            if obj_val is not None {
                type_name = self._struct_name_of(nd.target);
                if type_name is None {
                    type_name = self._infer_type_name(obj_val);
                }
                if type_name is not None {
                    return self._codegen_field_access(obj_val, right_name, type_name);
                }
            }
        }
    }

    if nd.is_attr and target_name is not None and right_name is not None {
        _slice_field_map: dict[(str, int)] = {"start": 0, "stop": 1, "step": 2};
        if (
            self._type_key_of(nd.target) == "slice" and right_name in _slice_field_map
        ) {
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

    if not nd.is_attr and nd.right?.slices and nd.right.is_range {
        target_name = self._get_name(nd.target);
        slices = nd.right.slices or [];
        if slices {
            s = slices[0];

            _slice_list_spec = self._list_spec_of(nd.target);
            if _slice_list_spec is not None {
                target_val = self._codegen_expr(nd.target);
                if target_val is not None {
                    _shape = self._infer_list_elem_type(target_val);
                    elem_type_name = _shape if _shape is not None else _slice_list_spec;
                    result = self._codegen_list_slice(target_val, s, elem_type_name);
                    if result is not None {
                        return result;
                    }
                }
            } else {
                target_val = self._codegen_expr(nd.target);
                if target_val is not None {
                    i8p = ir.IntType(8).as_pointer();
                    if self._is_bytes_value(target_val) {
                        result = self._codegen_bytes_slice(target_val, s);
                        if result is not None {
                            return result;
                        }
                    } elif target_val.type == i8p {
                        result = self._codegen_string_slice(target_val, s);
                        if result is not None {
                            return result;
                        }
                    } else {
                        elem_type_name = self._infer_list_elem_type(target_val);
                        if elem_type_name is not None {
                            result = self._codegen_list_slice(
                                target_val, s, elem_type_name
                            );
                            if result is not None {
                                return result;
                            }
                        }
                    }
                }
            }
        }
    }

    if not nd.is_attr and nd.right?.slices {
        target_name = self._get_name(nd.target);

        _idx_list_spec = self._list_spec_of(nd.target)
            if target_name is not None
            else None;
        if _idx_list_spec is not None {
            target_val = self._codegen_expr(nd.target);
            if target_val is not None {
                _shape = self._infer_list_elem_type(target_val);
                elem_type_name = _shape if _shape is not None else _idx_list_spec;
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

                        if result is not None and elem_type_name == "ptr" {
                            cast_type = self._list_elem_llvm_of(nd.target);
                            if (
                                isinstance(cast_type, ir.PointerType)
                                and result.type != cast_type
                            ) {
                                result = self.builder.bitcast(
                                    result, cast_type, name="idx.cast"
                                );
                            }
                        }
                        return result;
                    }
                }
            }
        } else {
            target_val = self._codegen_expr(nd.target);
            if target_val is not None {
                if self?.jacval_type and target_val.type == self.jacval_type {
                    _any_slices = nd.right.slices or [];
                    if _any_slices {
                        _any_idx_node = _any_slices[0];
                        _any_key = self._codegen_expr(_any_idx_node);
                        if _any_key is None and _any_idx_node?.start {
                            _any_key = self._codegen_expr(_any_idx_node.start);
                        }
                        if _any_key is not None {
                            _any_res = self._codegen_any_subscript(
                                target_val, _any_key
                            );
                            if _any_res is not None {
                                return _any_res;
                            }
                        }
                    }
                }

                if self._is_bytes_value(target_val) {
                    slices = nd.right.slices or [];
                    if slices {
                        idx_node = slices[0];
                        idx_val = self._codegen_expr(idx_node);
                        if idx_val is None and idx_node?.start {
                            idx_val = self._codegen_expr(idx_node.start);
                        }
                        if idx_val is not None {
                            return self._codegen_bytes_index(target_val, idx_val);
                        }
                    }
                }

                i8p = ir.IntType(8).as_pointer();
                if target_val.type == i8p {
                    is_known_list = self._list_spec_of(nd.target) is not None;
                    if not is_known_list {
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

                            if result is not None and elem_type_name == "ptr" {
                                cast_type = self._list_elem_llvm_of(nd.target);
                                if (
                                    isinstance(cast_type, ir.PointerType)
                                    and result.type != cast_type
                                ) {
                                    result = self.builder.bitcast(
                                        result, cast_type, name="chain.idx.cast"
                                    );
                                }
                            }
                            return result;
                        }
                    }
                }

                _rd_sname: (str | None) = self._struct_ptr_pointee_name(target_val);
                if _rd_sname is not None {
                    slices = nd.right.slices or [];
                    if slices {
                        idx_node = slices[0];
                        idx_val = self._codegen_expr(idx_node);
                        if idx_val is None and idx_node?.start {
                            idx_val = self._codegen_expr(idx_node.start);
                        }
                        if idx_val is not None {
                            return self._struct_array_elem_ptr(target_val, idx_val);
                        }
                    }
                }

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

        dict_type_key = self._dict_key_of(nd.target);
        if dict_type_key is not None {
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

    self.emit(
        E5090,
        node_override=nd,
        kind="attribute access" if nd.is_attr else "subscript/index access",
        name=(self._get_name(nd.right) or "<expr>")
            if nd.is_attr
            else (self._get_name(nd.target) or "<expr>"),
        help_text="The receiver's type could not be resolved to a native struct/container layout, so the access lowered to no code. Give the value a concrete native type, or move this code to a @sv/Python context."
    );
    return None;
}

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
