impl NaIRGenPass._codegen_body(stmts: (list | tuple)) -> None {
    for stmt in stmts {
        if self.builder.block.is_terminated {
            break;
        }

        _di_blk_count_snap = 0;
        _di_instr_snap = 0;
        _di_line_snap = 0;
        _di_blk_snap = None;
        _di_blk_instr_counts: dict = {};
        if self._di_current_sp is not None and stmt?.loc {
            _di_blk_snap = self.builder.block;
            _di_instr_snap = len(self.builder.block.instructions);
            _di_line_snap = stmt.loc.first_line;
            _di_func = self.builder.function;
            _di_blk_count_snap = len(_di_func.blocks);

            for _di_b in _di_func.blocks {
                _di_blk_instr_counts[id(_di_b)] = len(_di_b.instructions);
            }
        }
        self._codegen_stmt(stmt);
        self._emit_last_use_releases(stmt);

        if _di_blk_snap is not None and _di_line_snap > 0 {
            try {
                _di_loc = self.llvm_module.add_debug_info(
                    "DILocation",
                    {"line": _di_line_snap, "column": 0, "scope": self._di_current_sp}
                );
                _di_func2 = self.builder.function;
                for _di_blk2 in _di_func2.blocks {
                    _prev_count = _di_blk_instr_counts.get(id(_di_blk2), 0);
                    _all_instrs = _di_blk2.instructions;
                    if len(_all_instrs) > _prev_count {
                        _new_instrs = _all_instrs[_prev_count:];
                        for _instr in _new_instrs {
                            if "dbg" not in getattr(_instr, "metadata", {}) {
                                _instr.set_metadata("dbg", _di_loc);
                            }
                        }
                    }
                }
            } except Exception { }
        }
    }
}

impl NaIRGenPass._emit_last_use_releases(stmt: uni.UniNode) -> None {
    _map = self.ir_in.gen.rc_last_use;
    if not _map {
        return;
    }
    names = _map.get(id(stmt));
    if not names {
        return;
    }
    if self._builder is None or self.builder.block.is_terminated {
        return;
    }
    for name in names {
        if name == "self" or name in self.param_vars {
            continue;
        }
        if name in self.nogc_stack_vars {
            continue;
        }
        alloca = self.local_vars.get(name);
        if alloca is None {
            continue;
        }
        slot_ty = alloca.type?.pointee;
        if not (isinstance(slot_ty, ir.PointerType) and slot_ty?.pointee) {
            continue;
        }
        if name in self.region_handle_vars {
            continue;
        }
        val = self.builder.load(alloca, name=f"lu.{name}");
        self._emit_rc_release_typed(val, op="last_use", loc="");
        self.builder.store(ir.Constant(slot_ty, None), alloca);
    }
}

impl NaIRGenPass._codegen_stmt(nd: uni.UniNode) -> None {
    if self._builder is None or self._builder.block.is_terminated {
        return;
    }
    if isinstance(nd, uni.ReturnStmt) {
        self._codegen_return(nd);
    } elif isinstance(nd, uni.IfStmt) {
        self._codegen_if(nd);
    } elif isinstance(nd, uni.WhileStmt) {
        self._codegen_while(nd);
    } elif isinstance(nd, uni.ForeverStmt) {
        self._codegen_forever(nd);
    } elif isinstance(nd, uni.InForStmt) {
        self._codegen_for(nd);
    } elif isinstance(nd, uni.IterForStmt) {
        self._codegen_iter_for(nd);
    } elif isinstance(nd, uni.OpenStmt) {
        self._codegen_open_stmt(nd);
    } elif isinstance(nd, uni.MatchStmt) {
        self._codegen_match(nd);
    } elif isinstance(nd, uni.Ability) {
        self._codegen_nested_ability(nd);
    } elif isinstance(nd, uni.Assignment) {
        self._codegen_assignment(nd);
    } elif isinstance(nd, uni.CtrlStmt) {
        self._codegen_ctrl(nd);
    } elif isinstance(nd, uni.ExprStmt) {
        _estmt_val = self._codegen_expr(nd.expr);
        if (
            _estmt_val is not None
            and isinstance(_estmt_val.type, ir.PointerType)
            and self._is_owned(_estmt_val)
        ) {
            self._emit_rc_release_simple(_estmt_val, op="discarded_call", loc="");
        }
    } elif isinstance(nd, uni.TryStmt) {
        self._codegen_try(nd);
    } elif isinstance(nd, uni.RaiseStmt) {
        self._codegen_raise(nd);
    } elif isinstance(nd, uni.SwitchStmt) {
        self._codegen_switch(nd);
    } elif isinstance(nd, uni.WithStmt) {
        self._codegen_with(nd);
    } elif isinstance(nd, uni.AssertStmt) {
        cond = self._codegen_required(nd.condition);
        if cond is not None {
            cond_bool = self._to_bool(cond);

            is_false = self.builder.not_(cond_bool, name="assert.fail");

            _a_path = self.ir_in.loc.mod_path if self.ir_in.loc else "";
            _a_line = nd.loc.first_line if nd.loc else 0;
            _a_text = "assertion failed";
            if isinstance(nd.error_msg, uni.String) {
                _a_text = nd.error_msg.lit_value;
            }
            self._emit_runtime_raise(
                is_false, "AssertionError", f"{_a_text} at {_a_path}:{_a_line}"
            );
        }
    } elif isinstance(nd, uni.DeleteStmt) {
        target_expr = nd.target;
        _del_arch = self._struct_name_of(target_expr);
        _del_model = self.ir_in.gen.osp_model;
        if (_del_arch is not None)
        and (_del_model is not None)
        and (_del_model.arch_kind.get(_del_arch) == "edge") {
            _disc_fn = self.func_symtab.get("osp_disconnect");
            _edge_h = self._codegen_expr(target_expr);
            if (_disc_fn is not None) and (_edge_h is not None) {
                _disc_argtys = _disc_fn.function_type.args;
                self.builder.call(
                    _disc_fn, [self._coerce_type(_edge_h, _disc_argtys[0])]
                );
            } elif _disc_fn is None {
                self.emit(E5092, node_override=nd, kind="statement", name="DeleteStmt");
            }
        } elif (
            isinstance(target_expr, uni.AtomTrailer)
            and not target_expr.is_attr
            and target_expr.right?.slices
        ) {
            slices = target_expr.right.slices or [];
            if slices {
                dict_type_key = self._dict_key_of(target_expr.target);
                if dict_type_key is None {
                    dict_val_tmp = self._codegen_expr(target_expr.target);
                    if dict_val_tmp is not None {
                        dict_info = self._infer_dict_type(dict_val_tmp);
                        if dict_info is not None {
                            dict_type_key = f"{dict_info[0]}:{dict_info[1]}";
                        }
                    }
                }
                if dict_type_key is not None {
                    dict_val = self._codegen_expr(target_expr.target);
                    idx_node = slices[0];
                    idx_val = self._codegen_expr(idx_node);
                    if idx_val is None and idx_node?.start {
                        idx_val = self._codegen_expr(idx_node.start);
                    }
                    if dict_val is not None and idx_val is not None {
                        self._dispatch_primitive_method(
                            "dict", "remove", dict_val, [idx_val], dict_type_key
                        );
                    }
                } else {
                    list_val_tmp = self._codegen_expr(target_expr.target);
                    if list_val_tmp is not None {
                        elem_type_name = self._infer_list_elem_type(list_val_tmp);
                        if elem_type_name is not None {
                            list_val = self._codegen_expr(target_expr.target);
                            idx_node = slices[0];
                            idx_val = self._codegen_expr(idx_node);
                            if idx_val is None and idx_node?.start {
                                idx_val = self._codegen_expr(idx_node.start);
                            }
                            if list_val is not None and idx_val is not None {
                                self._dispatch_primitive_method(
                                    "list",
                                    "del_at",
                                    list_val,
                                    [idx_val],
                                    elem_type_name
                                );
                            }
                        }
                    }
                }
            }
        }
    } elif isinstance(nd, uni.Semi) { } elif isinstance(nd, uni.PyInlineCode) { } elif isinstance(
        nd, uni.VisitStmt
    ) {
        self._codegen_visit(nd);
    } elif isinstance(nd, uni.DisengageStmt) {
        self._codegen_disengage(nd);
    } elif isinstance(nd, uni.ReportStmt) {
        self._codegen_report(nd);
    } else {
        self.emit(E5092, node_override=nd, kind="statement", name=type(nd).__name__);
    }
}

impl NaIRGenPass._codegen_return(nd: uni.ReturnStmt) -> None {
    func_ret_type = self.builder.function.return_value.type;
    if nd.expr is not None {
        val = self._codegen_required(nd.expr);
        if val is not None {
            val = self._coerce_type(val, func_ret_type);

            skip_var: (str | None) = None;
            if isinstance(nd.expr, uni.Name)
            and nd.expr.sym_name in self.local_vars
            and nd.expr.sym_name not in self.param_vars {
                skip_var = nd.expr.sym_name;
            } elif isinstance(nd.expr, uni.TupleVal) {
                tup_elems = nd.expr.values or [];
                for tup_elem in tup_elems {
                    elem_name: (str | None) = None;
                    if isinstance(tup_elem, uni.Name) {
                        elem_name = tup_elem.sym_name;
                    }
                    if (
                        elem_name is not None
                        and elem_name in self.local_vars
                        and elem_name not in self.param_vars
                    ) {
                        tup_alloca = self.local_vars[elem_name];
                        if (
                            isinstance(tup_alloca.type, ir.PointerType)
                            and isinstance(tup_alloca.type.pointee, ir.PointerType)
                        ) {
                            self.builder.store(
                                ir.Constant(tup_alloca.type.pointee, None), tup_alloca
                            );
                        }
                    }
                }
            }

            if (
                skip_var is None
                and isinstance(val.type, ir.PointerType)
                and not self._is_owned(val)
            ) {
                self._emit_rc_retain(
                    val,
                    op="return",
                    loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                        if nd.loc
                        else 0}"
                );
                self._mark_owned(val);
            }
            self._emit_scope_cleanup(
                skip_var=skip_var,
                ret_val=val,
                loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                    if nd.loc
                    else 0}"
            );
            self.builder.ret(val);
            return;
        }
    }

    self._emit_scope_cleanup(
        skip_var=None,
        loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
            if nd.loc
            else 0}"
    );
    if isinstance(func_ret_type, ir.VoidType) {
        self.builder.ret_void();
    } elif isinstance(func_ret_type, ir.PointerType) {
        self.builder.ret(ir.Constant(func_ret_type, None));
    } else {
        self.builder.ret(ir.Constant(func_ret_type, 0));
    }
}

impl NaIRGenPass._codegen_if(nd: uni.IfStmt) -> None {
    cond = self._codegen_required(nd.condition);
    if cond is None {
        return;
    }

    cond = self._to_bool(cond);
    func = self.builder.function;
    then_bb = func.append_basic_block(name="if.then");
    else_bb = func.append_basic_block(name="if.else");
    merge_bb = func.append_basic_block(name="if.end");
    self.builder.cbranch(cond, then_bb, else_bb);

    self.builder.position_at_end(then_bb);
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }

    self.builder.position_at_end(else_bb);
    if nd.else_body is not None {
        if isinstance(nd.else_body, uni.ElseIf) {
            self._codegen_if(nd.else_body);
        } elif isinstance(nd.else_body, uni.ElseStmt) {
            if isinstance(nd.else_body.body, (list, tuple)) {
                self._codegen_body(nd.else_body.body);
            }
        }
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }
    self.builder.position_at_end(merge_bb);
}

impl NaIRGenPass._codegen_switch(nd: uni.SwitchStmt) -> None {
    target_val = self._codegen_expr(nd.target);
    if target_val is None {
        return;
    }
    func = self.builder.function;
    merge_bb = func.append_basic_block(name="switch.end");

    default_case: (uni.SwitchCase | None) = None;
    value_cases: list = [];
    for sc in nd.cases {
        if sc.pattern is None {
            default_case = sc;
        } else {
            value_cases.append(sc);
        }
    }
    i8p = ir.IntType(8).as_pointer();
    is_str = target_val.type == i8p;
    strcmp_fn = None;
    if is_str {
        strcmp_fn = self._get_or_declare_extern("strcmp", ir.IntType(32), [i8p, i8p]);
    }

    for (i, sc) in enumerate(value_cases) {
        pattern_val = None;
        if isinstance(sc.pattern, uni.MatchValue) {
            pattern_val = self._codegen_expr(sc.pattern.value);
        }
        if pattern_val is None {
            continue;
        }

        if is_str and strcmp_fn is not None {
            pattern_coerced = self._coerce_type(pattern_val, i8p);
            cmp_result = self.builder.call(
                strcmp_fn, [target_val, pattern_coerced], name="switch.strcmp"
            );
            cond = self.builder.icmp_signed(
                "==", cmp_result, ir.Constant(ir.IntType(32), 0), name="switch.eq"
            );
        } else {
            pattern_coerced = self._coerce_type(pattern_val, target_val.type);
            cond = self.builder.icmp_signed(
                "==", target_val, pattern_coerced, name="switch.eq"
            );
        }
        case_bb = func.append_basic_block(name=f"switch.case.{i}");
        next_bb = func.append_basic_block(name=f"switch.next.{i}");
        self.builder.cbranch(cond, case_bb, next_bb);

        self.builder.position_at_end(case_bb);
        self._codegen_body(sc.body);
        if not self.builder.block.is_terminated {
            self.builder.branch(merge_bb);
        }

        self.builder.position_at_end(next_bb);
    }

    if default_case is not None {
        self._codegen_body(default_case.body);
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }
    self.builder.position_at_end(merge_bb);
}

impl NaIRGenPass._codegen_while(nd: uni.WhileStmt) -> None {
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="while.cond");
    body_bb = func.append_basic_block(name="while.body");
    end_bb = func.append_basic_block(name="while.end");

    self.builder.branch(cond_bb);

    self.builder.position_at_end(cond_bb);
    cond = self._codegen_required(nd.condition);
    if cond is not None {
        cond = self._to_bool(cond);
        self.builder.cbranch(cond, body_bb, end_bb);
    } else {
        self.builder.branch(end_bb);
    }

    self.loop_stack.append((cond_bb, end_bb));
    self.builder.position_at_end(body_bb);

    import from jaclang.compiler.passes.main.rc_facts_pass { loop_body_locals }
    _while_body_locals = loop_body_locals(
        nd.body if isinstance(nd.body, (list, tuple)) else None
    );

    _while_prebody = set(self.local_vars.keys());
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    if not self.builder.block.is_terminated {
        _while_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.last_line
            if nd.loc
            else 0}";
        self._emit_loop_iter_cleanup(
            [
                _v
                for _v in _while_body_locals
                if _v not in _while_prebody
            ],
            loc=_while_loc
        );
        self.builder.branch(cond_bb);
    }
    self.loop_stack.pop();

    self.builder.position_at_end(end_bb);
}

impl NaIRGenPass._codegen_open_stmt(nd: uni.OpenStmt) -> None {
    import from jaclang.compiler.passes.main.rc_facts_pass { loop_body_locals }
    _region_body_locals = loop_body_locals(
        nd.body if isinstance(nd.body, (list, tuple)) else None
    );

    self._emit_arena_helpers();
    _i8p = ir.IntType(8).as_pointer();
    import from jaclang.compiler.symbol_utils { is_builtin_region_name }
    _anon_region = (
        isinstance(nd.target, uni.FuncCall) and is_builtin_region_name(nd.target.target)
    );
    _synth: (str | None) = None;
    if _anon_region {
        _arena = self.builder.call(self.region_new_fn, [], name="region.anon");
        _synth = f".region.{self.region_anon_count}";
        self.region_anon_count += 1;
        _slot = self._entry_alloca(_i8p, _synth);
        self.builder.store(_arena, _slot);
        self.local_vars[_synth] = _slot;
        self.region_handle_vars.add(_synth);
    } else {
        _arena = self._codegen_expr(nd.target);
        if _arena is not None and _arena.type != _i8p {
            _arena = self.builder.bitcast(_arena, _i8p, name="region.hdl");
        }
    }
    _pushed = _arena is not None;
    if _pushed {
        self.region_stack.append(_arena);
    }

    _region_prebody = set(self.local_vars.keys());
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    if _pushed {
        self.region_stack.pop();
    }
    if not self.builder.block.is_terminated {
        _region_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.last_line
            if nd.loc
            else 0}";
        self._emit_loop_iter_cleanup(
            [
                _v
                for _v in _region_body_locals
                if _v not in _region_prebody
            ],
            loc=_region_loc
        );
        if _synth is not None {
            self._emit_region_handle_drop(self.local_vars[_synth], _synth);
        }
    }
}

impl NaIRGenPass._codegen_forever(nd: uni.ForeverStmt) -> None {
    func = self.builder.function;
    body_bb = func.append_basic_block(name="forever.body");
    end_bb = func.append_basic_block(name="forever.end");

    self.builder.branch(body_bb);

    self.loop_stack.append((body_bb, end_bb));
    self.builder.position_at_end(body_bb);

    import from jaclang.compiler.passes.main.rc_facts_pass { loop_body_locals }
    _forever_body_locals = loop_body_locals(
        nd.body if isinstance(nd.body, (list, tuple)) else None
    );

    _forever_prebody = set(self.local_vars.keys());
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    if not self.builder.block.is_terminated {
        _forever_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.last_line
            if nd.loc
            else 0}";
        self._emit_loop_iter_cleanup(
            [
                _v
                for _v in _forever_body_locals
                if _v not in _forever_prebody
            ],
            loc=_forever_loc
        );
        self.builder.branch(body_bb);
    }
    self.loop_stack.pop();

    self.builder.position_at_end(end_bb);
}

impl NaIRGenPass._codegen_iter_for(nd: uni.IterForStmt) -> None {
    self._codegen_assignment(nd.iter);
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="iterfor.cond");
    body_bb = func.append_basic_block(name="iterfor.body");
    step_bb = func.append_basic_block(name="iterfor.step");
    end_bb = func.append_basic_block(name="iterfor.end");
    self.builder.branch(cond_bb);

    self.builder.position_at_end(cond_bb);
    cond = self._codegen_required(nd.condition);
    if cond is not None {
        cond = self._to_bool(cond);
        self.builder.cbranch(cond, body_bb, end_bb);
    } else {
        self.builder.branch(end_bb);
    }

    self.loop_stack.append((step_bb, end_bb));
    self.builder.position_at_end(body_bb);
    import from jaclang.compiler.passes.main.rc_facts_pass { loop_body_locals }
    _saved_locals = loop_body_locals(
        nd.body if isinstance(nd.body, (list, tuple)) else None
    );

    _iterfor_prebody = set(self.local_vars.keys());
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    _loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.last_line
        if nd.loc
        else 0}";
    if not self.builder.block.is_terminated {
        self._emit_loop_iter_cleanup(
            [
                _v
                for _v in _saved_locals
                if _v not in _iterfor_prebody
            ],
            loc=_loc
        );
        self.builder.branch(step_bb);
    }
    self.loop_stack.pop();

    self.builder.position_at_end(step_bb);
    if not self.builder.block.is_terminated {
        self._codegen_assignment(nd.count_by);
        self.builder.branch(cond_bb);
    }

    self.builder.position_at_end(end_bb);
}

impl NaIRGenPass._codegen_match(nd: uni.MatchStmt) -> None {
    subj = self._codegen_expr(nd.target);
    if subj is None {
        return;
    }

    subj_alloca = self._entry_alloca(subj.type, "match.subj");
    self.builder.store(subj, subj_alloca);
    func = self.builder.function;
    end_bb = func.append_basic_block(name="match.end");
    n = len(nd.cases);
    for (ci, case) in enumerate(nd.cases) {
        subj_val = self.builder.load(subj_alloca, name="match.subj.l");
        cond = self._match_pattern_cond(case.pattern, subj_val);
        body_bb = func.append_basic_block(name=f"match.c{ci}.body");
        next_bb = func.append_basic_block(name=f"match.c{ci}.next")
            if ci < n - 1
            else end_bb;
        if cond is None {
            self.builder.branch(next_bb);
            if next_bb is not end_bb {
                self.builder.position_at_end(next_bb);
            }
            continue;
        }
        if case.guard is not None {
            bind_bb = func.append_basic_block(name=f"match.c{ci}.bind");
            self.builder.cbranch(cond, bind_bb, next_bb);
            self.builder.position_at_end(bind_bb);
            self._bind_match_pattern(case.pattern, subj_val);
            gval = self._codegen_expr(case.guard);
            if gval is not None {
                self.builder.cbranch(self._to_bool(gval), body_bb, next_bb);
            } else {
                self.builder.branch(next_bb);
            }
        } else {
            self.builder.cbranch(cond, body_bb, next_bb);
        }

        self.builder.position_at_end(body_bb);
        self._bind_match_pattern(case.pattern, subj_val);
        if isinstance(case.body, (list, tuple)) {
            self._codegen_body(case.body);
        }
        if not self.builder.block.is_terminated {
            self.builder.branch(end_bb);
        }
        if next_bb is not end_bb {
            self.builder.position_at_end(next_bb);
        }
    }
    self.builder.position_at_end(end_bb);
}

impl NaIRGenPass._match_pattern_cond(
    pat: uni.MatchPattern, subj: ir.Value
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    if isinstance(pat, uni.MatchWild) {
        return ir.Constant(i1, 1);
    }
    if isinstance(pat, uni.MatchAs) {
        if pat.pattern is None {
            return ir.Constant(i1, 1);
        }
        return self._match_pattern_cond(pat.pattern, subj);
    }
    if isinstance(pat, uni.MatchValue) {
        return self._match_value_eq(subj, pat.value);
    }
    if isinstance(pat, uni.MatchSingleton) {
        return self._match_value_eq(subj, pat.value);
    }
    if isinstance(pat, uni.MatchOr) {
        result: (ir.Value | None) = None;
        for sub in pat.patterns {
            sub_cond = self._match_pattern_cond(sub, subj);
            if sub_cond is None {
                return None;
            }
            result = sub_cond
                if result is None
                else self.builder.or_(result, sub_cond, name="match.or");
        }
        return result;
    }

    self.emit(E5092, node_override=pat, kind="match pattern", name=type(pat).__name__);
    return None;
}

impl NaIRGenPass._match_value_eq(
    subj: ir.Value, value_node: uni.UniNode
) -> (ir.Value | None) {
    pat = self._codegen_expr(value_node);
    if pat is None {
        return None;
    }

    if isinstance(subj.type, ir.IntType)
    and isinstance(pat.type, ir.IntType)
    and subj.type != pat.type {
        pat = self._coerce_type(pat, subj.type);
    }
    is_float = isinstance(subj.type, ir.DoubleType)
    or isinstance(pat.type, ir.DoubleType);
    (lhs, rhs) = (subj, pat);
    if is_float {
        (lhs, rhs) = self._promote_to_float(subj, pat);
    }
    cmp = self._emit_comparison(Tok.EE, lhs, rhs, is_float);
    if cmp is None {
        return None;
    }
    return self._to_bool(cmp);
}

impl NaIRGenPass._bind_match_pattern(pat: uni.MatchPattern, subj: ir.Value) -> None {
    if isinstance(pat, uni.MatchAs) {
        cap_name = self._get_name(pat.name) if pat.name else None;
        if cap_name is not None {
            alloca = self._entry_alloca(subj.type, cap_name);
            self.builder.store(subj, alloca);
            self.local_vars[cap_name] = alloca;
        }
        if pat.pattern is not None {
            self._bind_match_pattern(pat.pattern, subj);
        }
    }
}

impl NaIRGenPass._apply_scalar_aug_op(
    current: ir.Value, rhs: ir.Value, aug_op: str
) -> (ir.Value | None) {
    if not isinstance(current.type, (ir.IntType, ir.DoubleType)) {
        return None;
    }
    op_toks = {
        "+=": Tok.PLUS,
        "-=": Tok.MINUS,
        "*=": Tok.STAR_MUL,
        "/=": Tok.DIV,
        "//=": Tok.FLOOR_DIV,
        "%=": Tok.MOD,
        "**=": Tok.STAR_POW,
        "&=": Tok.BW_AND,
        "|=": Tok.BW_OR,
        "^=": Tok.BW_XOR,
        "<<=": Tok.LSHIFT,
        ">>=": Tok.RSHIFT
    };
    if aug_op not in op_toks {
        return None;
    }
    if aug_op == "/=" and isinstance(current.type, ir.IntType) {
        return None;
    }
    coerced = self._coerce_type(rhs, current.type);
    result = self._emit_binary_op(op_toks[aug_op], current, coerced);
    if result is not None and result.type != current.type {
        result = self._coerce_type(result, current.type);
    }
    return result;
}

impl NaIRGenPass._codegen_assignment(nd: uni.Assignment) -> None {
    _rhs_errs_before = len(self.errors_had);
    value = self._codegen_expr(nd.value) if nd.value else None;

    if value is None and isinstance(nd.value, uni.FuncCall) {
        func_name = self._get_name(nd.value.target);
        if func_name == "set" and nd.type_tag is not None {
            _set_t0 = nd.target[0]
                if isinstance(nd.target, (list, tuple))
                else nd.target;
            set_type = self._resolve_jac_type(_set_t0);
            if isinstance(set_type, ir.PointerType) {
                for (elem_name, stype) in self.set_types.items() {
                    if set_type == stype.as_pointer() {
                        helpers = self.set_helpers.get(elem_name);
                        if helpers is not None {
                            value = self.builder.call(
                                helpers["new"], [], name="set.new"
                            );

                            self._mark_owned(value);
                        }
                        break;
                    }
                }
            }
        }
    }
    if value is None {
        if nd.value is not None and len(self.errors_had) == _rhs_errs_before {
            self.emit(
                E5092,
                node_override=nd.value,
                kind="expression",
                name=type(nd.value).__name__
            );
        }
        return;
    }
    targets = nd.target if isinstance(nd.target, (list, tuple)) else [(nd.target)];
    for target_expr in targets {
        if isinstance(target_expr, uni.TupleVal) {
            self._codegen_tuple_unpack(target_expr.values, value, nd.value);
            continue;
        }

        if isinstance(target_expr, uni.AtomTrailer) and target_expr.is_attr {
            if nd.aug_op is not None {
                _faug_errs = len(self.errors_had);
                field_val = self._codegen_field_aug_assign(
                    target_expr, value, nd.aug_op.value
                );
                if field_val is not None {
                    self._codegen_field_assign(target_expr, field_val);
                } elif len(self.errors_had) == _faug_errs {
                    self.emit(
                        E5092,
                        node_override=target_expr,
                        kind="augmented field assignment",
                        name=(self._get_name(target_expr.right) or "<field>")
                    );
                }
            } else {
                self._codegen_field_assign(target_expr, value);
            }
            continue;
        }

        if isinstance(target_expr, uni.AtomTrailer) and not target_expr.is_attr {
            _idx_errs_before = len(self.errors_had);
            _idx_stored = False;
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
                        dict_type_key = self._dict_key_of(target_expr.target);
                        if dict_type_key is None {
                            dict_info = self._infer_dict_type(target_val);
                            if dict_info is not None {
                                dict_type_key = f"{dict_info[0]}:{dict_info[1]}";
                            }
                        }
                        if dict_type_key is not None {
                            parts = dict_type_key.split(":");
                            if len(parts) == 2 {
                                store_val: (ir.Value | None) = value;
                                if nd.aug_op is not None {
                                    cur_elem = self._codegen_dict_access(
                                        target_val, idx_val, parts[0], parts[1]
                                    );
                                    store_val = None;
                                    if cur_elem is not None {
                                        store_val = self._apply_scalar_aug_op(
                                            cur_elem, value, nd.aug_op.value
                                        );
                                    }
                                }
                                if store_val is not None {
                                    self._codegen_dict_set(
                                        target_val,
                                        idx_val,
                                        store_val,
                                        parts[0],
                                        parts[1]
                                    );
                                    _idx_stored = True;
                                }
                            }
                        } else {
                            elem_type_name: (str | None) = (
                                self._infer_list_elem_type(target_val)
                            );
                            _wr_sname: (str | None) = (
                                self._struct_ptr_pointee_name(target_val)
                            );
                            if elem_type_name is not None {
                                store_val: (ir.Value | None) = value;
                                if nd.aug_op is not None {
                                    cur_elem = self._codegen_index(
                                        target_val, idx_val, elem_type_name
                                    );
                                    store_val = None;
                                    if cur_elem is not None {
                                        store_val = self._apply_scalar_aug_op(
                                            cur_elem, value, nd.aug_op.value
                                        );
                                    }
                                }
                                if store_val is not None {
                                    self._codegen_index_set(
                                        target_val, idx_val, store_val, elem_type_name
                                    );
                                    _idx_stored = True;
                                }
                            } elif _wr_sname is not None and nd.aug_op is None {
                                _struct_t = self.struct_types[_wr_sname];
                                elem_ptr = self._struct_array_elem_ptr(
                                    target_val, idx_val
                                );
                                if isinstance(value.type, ir.IdentifiedStructType)
                                and value.type == _struct_t {
                                    self.builder.store(value, elem_ptr);
                                    _idx_stored = True;
                                } elif (
                                    isinstance(value.type, ir.PointerType)
                                    and value.type.pointee == _struct_t
                                ) {
                                    self.builder.store(
                                        self.builder.load(value, name="arr.val.struct"),
                                        elem_ptr
                                    );
                                    _idx_stored = True;
                                }
                            }
                        }
                    }
                }
            }
            if not _idx_stored and len(self.errors_had) == _idx_errs_before {
                self.emit(
                    E5092,
                    node_override=target_expr,
                    kind="subscript assignment",
                    name=(idx_target_name or "<expr>")
                );
            }
            continue;
        }
        var_name = self._get_name(target_expr);
        if var_name is None {
            continue;
        }

        if var_name in self.local_vars {
            alloca = self.local_vars[var_name];

            if nd.type_tag and nd.type_tag.tag and nd.aug_op is None {
                _redecl_tag = nd.type_tag.tag;
                bare_redecl: (str | None) = None;
                if isinstance(_redecl_tag, uni.Name) {
                    bare_redecl = _redecl_tag.value;
                } elif uni?.BuiltinType and isinstance(_redecl_tag, uni.BuiltinType) {
                    bare_redecl = _redecl_tag.value;
                }
                _skip_redecl = bare_redecl in {"list", "dict", "set", "frozenset"};
                if not _skip_redecl {
                    _declared_type = self._resolve_jac_type(_redecl_tag);
                    if _declared_type is not None
                    and _declared_type != alloca.type.pointee {
                        alloca = self._entry_alloca(_declared_type, var_name);
                        self.local_vars[var_name] = alloca;
                    }
                }
            }
            is_inplace_set_op = False;

            if nd.aug_op is not None {
                aug_op_val = nd.aug_op.value;
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
                        _aug_str_rhs = coerced;
                        value = self._emit_binary_op(Tok.PLUS, current, _aug_str_rhs);
                        if value is None {
                            value = current;
                        } else {
                            if self._is_owned(_aug_str_rhs) {
                                _aug_rhs_loc = f"{os.path.basename(
                                    self.ir_in.loc.mod_path
                                )}:{nd.loc.first_line if nd.loc else 0}";
                                self._emit_rc_release_typed(
                                    _aug_str_rhs, op="str_rhs", loc=_aug_rhs_loc
                                );
                            }
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
                    } elif isinstance(current.type, ir.PointerType) {
                        self._ensure_emitters();
                        _se = self._native_emitters.get("set");
                        for (sname, stype) in self.set_types.items() {
                            if current.type == stype.as_pointer() {
                                _ctx = self._native_emit_ctx_class(
                                    pass_ref=self, type_key=sname
                                );
                                if _se is not None {
                                    _se.emit_difference_update(
                                        _ctx, current, [coerced]
                                    );
                                }
                                value = current;
                                is_inplace_set_op = True;
                                break;
                            }
                        }
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
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.and_(
                            current, coerced, name=f"{var_name}.and"
                        );
                    } elif isinstance(current.type, ir.PointerType) {
                        self._ensure_emitters();
                        _se = self._native_emitters.get("set");
                        for (sname, stype) in self.set_types.items() {
                            if current.type == stype.as_pointer() {
                                _ctx = self._native_emit_ctx_class(
                                    pass_ref=self, type_key=sname
                                );
                                if _se is not None {
                                    _se.emit_intersection_update(
                                        _ctx, current, [coerced]
                                    );
                                }
                                value = current;
                                is_inplace_set_op = True;
                                break;
                            }
                        }
                    }
                } elif aug_op_val == "|=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.or_(
                            current, coerced, name=f"{var_name}.or"
                        );
                    } elif isinstance(current.type, ir.PointerType) {
                        dict_type_key = self._dict_key_of(target_expr);
                        if dict_type_key is None {
                            dict_info = self._infer_dict_type(current);
                            if dict_info is not None {
                                dict_type_key = f"{dict_info[0]}:{dict_info[1]}";
                            }
                        }
                        if dict_type_key is not None {
                            self._ensure_emitters();
                            _de = self._native_emitters.get("dict");
                            if _de is not None {
                                _ctx = self._native_emit_ctx_class(
                                    pass_ref=self, type_key=dict_type_key
                                );
                                _de.emit_update(_ctx, current, [coerced]);
                            }
                            value = current;
                            is_inplace_set_op = True;
                        } else {
                            rhs_set = coerced;
                            lhs_set = current;
                            set_elem_name: (str | None) = None;
                            for (sname, stype) in self.set_types.items() {
                                if current.type == stype.as_pointer()
                                or rhs_set.type == stype.as_pointer() {
                                    set_elem_name = sname;
                                    break;
                                }
                            }
                            if set_elem_name is not None {
                                shelpers = self.set_helpers.get(set_elem_name);
                                if shelpers is not None {
                                    i64 = ir.IntType(64);
                                    i32 = ir.IntType(32);

                                    rhs_cast = self.builder.bitcast(
                                        rhs_set,
                                        self.set_types[set_elem_name].as_pointer(),
                                        name="rhs.set.cast"
                                    );
                                    rhs_len_ptr = self.builder.gep(
                                        rhs_cast,
                                        [ir.Constant(i32, 0), ir.Constant(i32, 0)],
                                        name="rhs.len.ptr"
                                    );
                                    rhs_len = self.builder.load(
                                        rhs_len_ptr, name="rhs.len"
                                    );
                                    rhs_elems_ptr = self.builder.gep(
                                        rhs_cast,
                                        [ir.Constant(i32, 0), ir.Constant(i32, 2)],
                                        name="rhs.elems.ptr"
                                    );
                                    rhs_elems = self.builder.load(
                                        rhs_elems_ptr, name="rhs.elems"
                                    );

                                    loop_idx = self._entry_alloca(i64, "union.idx");
                                    self.builder.store(ir.Constant(i64, 0), loop_idx);
                                    func = self.builder.function;
                                    cond_bb = func.append_basic_block(
                                        name="union.cond"
                                    );
                                    body_bb = func.append_basic_block(
                                        name="union.body"
                                    );
                                    end_bb = func.append_basic_block(name="union.end");
                                    self.builder.branch(cond_bb);
                                    self.builder.position_at_end(cond_bb);
                                    cur_i = self.builder.load(loop_idx, name="union.i");
                                    cmp = self.builder.icmp_signed(
                                        "<", cur_i, rhs_len, name="union.cmp"
                                    );
                                    self.builder.cbranch(cmp, body_bb, end_bb);
                                    self.builder.position_at_end(body_bb);
                                    elem_i = self.builder.load(
                                        loop_idx, name="union.elem.i"
                                    );
                                    elem_ptr = self.builder.gep(
                                        rhs_elems, [elem_i], name="union.elem.ptr"
                                    );
                                    elem_val = self.builder.load(
                                        elem_ptr, name="union.elem.val"
                                    );
                                    lhs_cast = self.builder.bitcast(
                                        lhs_set,
                                        self.set_types[set_elem_name].as_pointer(),
                                        name="lhs.set.cast"
                                    );
                                    self.builder.call(
                                        shelpers["add"], [lhs_cast, elem_val]
                                    );
                                    next_i = self.builder.add(
                                        elem_i, ir.Constant(i64, 1), name="union.next.i"
                                    );
                                    self.builder.store(next_i, loop_idx);
                                    self.builder.branch(cond_bb);
                                    self.builder.position_at_end(end_bb);

                                    value = lhs_set;
                                    is_inplace_set_op = True;

                                    self._emit_rc_release_simple(
                                        rhs_set,
                                        op="op_assign",
                                        loc=f"{os.path.basename(
                                            self.ir_in.loc.mod_path
                                        )}:{nd.loc.first_line if nd.loc else 0}"
                                    );

                                    _rhs_var_ior = self._get_name(nd.value)
                                        if nd.value is not None
                                        else None;
                                    if _rhs_var_ior is not None
                                    and _rhs_var_ior in self.local_vars {
                                        _rhs_alloca_ior = self.local_vars[_rhs_var_ior];
                                        self.builder.store(
                                            ir.Constant(
                                                _rhs_alloca_ior.type.pointee, None
                                            ),
                                            _rhs_alloca_ior
                                        );
                                    }
                                }
                            }
                        }
                    }
                } elif aug_op_val == "^=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.xor(
                            current, coerced, name=f"{var_name}.xor"
                        );
                    } elif isinstance(current.type, ir.PointerType) {
                        self._ensure_emitters();
                        _se = self._native_emitters.get("set");
                        for (sname, stype) in self.set_types.items() {
                            if current.type == stype.as_pointer() {
                                _ctx = self._native_emit_ctx_class(
                                    pass_ref=self, type_key=sname
                                );
                                if _se is not None {
                                    _se.emit_symmetric_difference_update(
                                        _ctx, current, [coerced]
                                    );
                                }
                                value = current;
                                is_inplace_set_op = True;
                                break;
                            }
                        }
                    }
                } elif aug_op_val == "<<=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.shl(
                            current, coerced, name=f"{var_name}.shl"
                        );
                    }
                } elif aug_op_val == ">>=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.ashr(
                            current, coerced, name=f"{var_name}.ashr"
                        );
                    }
                } elif aug_op_val == "**=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self._codegen_int_pow(current, coerced);
                    }
                }
            }
            coerced = self._coerce_type(value, alloca.type.pointee);

            _is_raw_int_ptr = getattr(coerced, 'opname', '') == 'inttoptr';
            self._register_region_handle_var(nd, var_name);
            if isinstance(alloca.type.pointee, ir.PointerType)
            and not is_inplace_set_op {
                if _is_raw_int_ptr {
                    self.param_vars.add(var_name);
                } elif var_name in self.region_handle_vars {
                    self._emit_arena_helpers();
                    _old_hdl = self.builder.load(alloca, name=f"{var_name}.old");
                    _old_i8 = self.builder.bitcast(
                        _old_hdl, ir.IntType(8).as_pointer(), name=f"{var_name}.old.i8"
                    );
                    self.builder.call(self.region_drop_fn, [_old_i8]);
                } else {
                    if not self._is_owned(value)
                    and not self._can_native_move_lower(nd) {
                        self._emit_rc_retain(
                            coerced,
                            op="assign",
                            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                                if nd.loc
                                else 0}"
                        );
                    } elif self._is_owned(value) {
                        self.rc_ops_elided += 1;
                    }
                    if not (
                        self._nogc_headerless()
                        and getattr(nd, 'na_overwrite_consumed', False)
                    ) {
                        old_val = self.builder.load(alloca, name=f"{var_name}.old");
                        self._emit_rc_release_typed(
                            old_val,
                            op="overwrite",
                            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                                if nd.loc
                                else 0}"
                        );
                    }
                }
            } elif (
                self?.jacval_type
                and alloca.type.pointee == self.jacval_type
                and isinstance(value.type, ir.PointerType)
                and getattr(value, 'opname', '') != 'inttoptr'
                and not is_inplace_set_op
            ) {
                if not self._is_owned(value) and not self._can_native_move_lower(nd) {
                    self._emit_rc_retain(
                        value,
                        op="assign_box",
                        loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                            if nd.loc
                            else 0}"
                    );
                } elif self._is_owned(value) {
                    self.rc_ops_elided += 1;
                }
            }
            self.builder.store(coerced, alloca);
        } elif var_name in self.global_vars
        and isinstance(target_expr, uni.NameAtom)
        and target_expr.sym is not None
        and target_expr.sym.storage == uni.SymbolStorage.MODULE_GLOBAL {
            global_var = self.global_vars[var_name];
            if nd.aug_op is not None {
                aug_op_val = nd.aug_op.value;
                current = self.builder.load(global_var, name=f"glob.{var_name}.cur");
                coerced = self._coerce_type(value, current.type);
                if aug_op_val == "+=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.add(
                            current, coerced, name=f"glob.{var_name}.add"
                        );
                    } elif isinstance(current.type, ir.DoubleType) {
                        value = self.builder.fadd(
                            current, coerced, name=f"glob.{var_name}.fadd"
                        );
                    } elif isinstance(current.type, ir.PointerType) {
                        _aug_gstr_rhs = coerced;
                        value = self._emit_binary_op(Tok.PLUS, current, _aug_gstr_rhs);
                        if value is None {
                            value = current;
                        } else {
                            if self._is_owned(_aug_gstr_rhs) {
                                _aug_grhs_loc = f"{os.path.basename(
                                    self.ir_in.loc.mod_path
                                )}:{nd.loc.first_line if nd.loc else 0}";
                                self._emit_rc_release_typed(
                                    _aug_gstr_rhs, op="str_rhs", loc=_aug_grhs_loc
                                );
                            }
                        }
                    }
                } elif aug_op_val == "-=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.sub(
                            current, coerced, name=f"glob.{var_name}.sub"
                        );
                    } elif isinstance(current.type, ir.DoubleType) {
                        value = self.builder.fsub(
                            current, coerced, name=f"glob.{var_name}.fsub"
                        );
                    } elif isinstance(current.type, ir.PointerType) {
                        self._ensure_emitters();
                        _se = self._native_emitters.get("set");
                        for (sname, stype) in self.set_types.items() {
                            if current.type == stype.as_pointer() {
                                _ctx = self._native_emit_ctx_class(
                                    pass_ref=self, type_key=sname
                                );
                                if _se is not None {
                                    _se.emit_difference_update(
                                        _ctx, current, [coerced]
                                    );
                                }
                                value = current;
                                break;
                            }
                        }
                    }
                } elif aug_op_val == "*=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.mul(
                            current, coerced, name=f"glob.{var_name}.mul"
                        );
                    } elif isinstance(current.type, ir.DoubleType) {
                        value = self.builder.fmul(
                            current, coerced, name=f"glob.{var_name}.fmul"
                        );
                    }
                } elif aug_op_val == "%=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.srem(
                            current, coerced, name=f"glob.{var_name}.mod"
                        );
                    }
                } elif aug_op_val == "&=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.and_(
                            current, coerced, name=f"glob.{var_name}.and"
                        );
                    } elif isinstance(current.type, ir.PointerType) {
                        self._ensure_emitters();
                        _se = self._native_emitters.get("set");
                        for (sname, stype) in self.set_types.items() {
                            if current.type == stype.as_pointer() {
                                _ctx = self._native_emit_ctx_class(
                                    pass_ref=self, type_key=sname
                                );
                                if _se is not None {
                                    _se.emit_intersection_update(
                                        _ctx, current, [coerced]
                                    );
                                }
                                value = current;
                                break;
                            }
                        }
                    }
                } elif aug_op_val == "|=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.or_(
                            current, coerced, name=f"glob.{var_name}.or"
                        );
                    } elif isinstance(current.type, ir.PointerType) {
                        self._ensure_emitters();
                        _se = self._native_emitters.get("set");
                        for (sname, stype) in self.set_types.items() {
                            if current.type == stype.as_pointer() {
                                _ctx = self._native_emit_ctx_class(
                                    pass_ref=self, type_key=sname
                                );
                                if _se is not None {
                                    _se.emit_update(_ctx, current, [coerced]);
                                }
                                value = current;
                                break;
                            }
                        }
                    }
                } elif aug_op_val == "^=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.xor(
                            current, coerced, name=f"glob.{var_name}.xor"
                        );
                    } elif isinstance(current.type, ir.PointerType) {
                        self._ensure_emitters();
                        _se = self._native_emitters.get("set");
                        for (sname, stype) in self.set_types.items() {
                            if current.type == stype.as_pointer() {
                                _ctx = self._native_emit_ctx_class(
                                    pass_ref=self, type_key=sname
                                );
                                if _se is not None {
                                    _se.emit_symmetric_difference_update(
                                        _ctx, current, [coerced]
                                    );
                                }
                                value = current;
                                break;
                            }
                        }
                    }
                }
            }
            coerced = self._coerce_type(value, global_var.type.pointee);
            _is_raw_int_ptr_g = getattr(coerced, 'opname', '') == 'inttoptr';
            if isinstance(global_var.type.pointee, ir.PointerType)
            and not _is_raw_int_ptr_g {
                if not self._is_owned(value) {
                    self._emit_rc_retain(
                        coerced,
                        op="assign",
                        loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                            if nd.loc
                            else 0}"
                    );
                } else {
                    self.rc_ops_elided += 1;
                }
                old_glob = self.builder.load(global_var, name=f"glob.{var_name}.old");
                self._emit_rc_release_typed(
                    old_glob,
                    op="overwrite",
                    loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                        if nd.loc
                        else 0}"
                );
            }
            self.builder.store(coerced, global_var);
        } else {
            var_type = value.type;
            _pre_box_val = value;
            if nd.type_tag and nd.type_tag.tag {
                tag_node = nd.type_tag.tag;

                bare_name: (str | None) = None;
                if isinstance(tag_node, uni.Name) {
                    bare_name = tag_node.value;
                } elif uni?.BuiltinType and isinstance(tag_node, uni.BuiltinType) {
                    bare_name = tag_node.value;
                }
                infer_from_val = (
                    bare_name in {"list", "dict", "set", "frozenset"}
                    and isinstance(value.type, ir.PointerType)
                );
                if infer_from_val {
                    is_coll = False;
                    for (_, _ltype) in self.list_types.items() {
                        if value.type == _ltype.as_pointer() {
                            is_coll = True;
                            break;
                        }
                    }
                    if not is_coll {
                        for (_, _dtype) in self.dict_types.items() {
                            if value.type == _dtype.as_pointer() {
                                is_coll = True;
                                break;
                            }
                        }
                    }
                    if not is_coll {
                        for (_, _stype) in self.set_types.items() {
                            if value.type == _stype.as_pointer() {
                                is_coll = True;
                                break;
                            }
                        }
                    }
                    if not is_coll {
                        infer_from_val = False;
                    }
                }
                if infer_from_val {
                    var_type = value.type;
                } else {
                    var_type = self._resolve_jac_type(tag_node);
                    _pre_box_val = value;
                    value = self._coerce_type(value, var_type);
                }
            }
            if isinstance(var_type, ir.VoidType) {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="binding a void-typed value to variable",
                    name=var_name
                );
                return;
            }
            alloca = self._entry_alloca(var_type, var_name);
            if isinstance(var_type, ir.PointerType) {
                _func_e = self.builder.function;
                _ebb = _func_e.entry_basic_block;
                _cur_bb = self.builder.block;
                _entry_instrs = list(_ebb.instructions);

                if len(_entry_instrs) >= 2 {
                    self.builder.position_before(_entry_instrs[1]);
                } else {
                    self.builder.position_at_end(_ebb);
                }
                self.builder.store(ir.Constant(var_type, None), alloca);
                self.builder.position_at_end(_cur_bb);
            }
            self._register_region_handle_var(nd, var_name);
            if isinstance(var_type, ir.PointerType)
            and var_name in self.region_handle_vars {
                ;
            } elif isinstance(var_type, ir.PointerType) {
                if getattr(value, 'opname', '') == 'inttoptr' {
                    self.param_vars.add(var_name);
                } else {
                    if not self._is_owned(value)
                    and not self._can_native_move_lower(nd) {
                        self._emit_rc_retain(
                            value,
                            op="assign",
                            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                                if nd.loc
                                else 0}"
                        );
                    } elif self._is_owned(value) {
                        self.rc_ops_elided += 1;
                    }
                    if not (
                        self._nogc_headerless()
                        and getattr(nd, 'na_overwrite_consumed', False)
                    ) {
                        old_val = self.builder.load(alloca, name=f"{var_name}.old");
                        self._emit_rc_release_typed(
                            old_val,
                            op="overwrite",
                            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                                if nd.loc
                                else 0}"
                        );
                    }
                }
            } elif (
                self?.jacval_type
                and var_type == self.jacval_type
                and isinstance(_pre_box_val.type, ir.PointerType)
                and getattr(_pre_box_val, 'opname', '') != 'inttoptr'
            ) {
                if not self._is_owned(_pre_box_val)
                and not self._can_native_move_lower(nd) {
                    self._emit_rc_retain(
                        _pre_box_val,
                        op="assign_box",
                        loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                            if nd.loc
                            else 0}"
                    );
                } elif self._is_owned(_pre_box_val) {
                    self.rc_ops_elided += 1;
                }
            }
            self.builder.store(value, alloca);
            self.local_vars[var_name] = alloca;
        }

        if self._pending_lambda_captures is not None {
            self.lambda_captures[var_name] = self._pending_lambda_captures;
            self._pending_lambda_captures = None;
        }

        if self._pending_list_elem_struct is not None {
            for (ename, ltype) in self.list_types.items() {
                if value.type == ltype.as_pointer() {
                    self.var_list_elem_struct[var_name] = self._pending_list_elem_struct;
                    break;
                }
            }
        }
    }
}

impl NaIRGenPass._codegen_ctrl(nd: uni.CtrlStmt) -> None {
    ctrl_name = nd.ctrl.name if isinstance(nd.ctrl, uni.Token) else str(nd.ctrl);

    if ctrl_name == Tok.KW_SKIP {
        if isinstance(self.builder.function.function_type.return_type, ir.VoidType) {
            self.builder.ret_void();
        } else {
            self.emit(
                E5092,
                node_override=nd,
                kind="statement",
                name="SkipStmt",
                help_text=(
                    "`skip` ends an event ability (a void body); in a "
                    "value-returning function use an explicit `return`."
                )
            );
        }
        return;
    }
    if not self.loop_stack {
        return;
    }
    (continue_bb, break_bb) = self.loop_stack[-1];
    if ctrl_name == Tok.KW_BREAK {
        self.builder.branch(break_bb);
    } elif ctrl_name == Tok.KW_CONTINUE {
        self.builder.branch(continue_bb);
    }
}

impl NaIRGenPass._codegen_for(nd: uni.InForStmt) -> None {
    if self._try_iter_protocol_for(nd) {
        return;
    }

    _for_errs0 = len(self.errors_had);
    _unpack_target = nd.target if isinstance(nd.target, uni.TupleVal) else None;
    loop_var_name = "for.unpack"
        if _unpack_target is not None
        else self._get_name(nd.target);

    if isinstance(nd.target, uni.TupleVal)
    and isinstance(nd.collection, uni.FuncCall)
    and isinstance(nd.collection.target, uni.AtomTrailer)
    and nd.collection.target.is_attr
    and self._get_name(nd.collection.target.right) == "items" {
        items_dict_key = self._dict_key_of(nd.collection.target.target);
        helpers = self.dict_helpers.get(items_dict_key)
            if items_dict_key is not None
            else None;
        unpack_targets = nd.target.values or [];
        if helpers is not None and len(unpack_targets) == 2 {
            key_var_name = self._get_name(unpack_targets[0]);
            val_var_name = self._get_name(unpack_targets[1]);
            if key_var_name is not None and val_var_name is not None {
                collection_val = self._codegen_expr(nd.collection.target.target);
                if collection_val is not None {
                    self._codegen_for_indexed(
                        nd,
                        kind="items",
                        collection_val=collection_val,
                        helpers=helpers,
                        var_names=[key_var_name, val_var_name],
                        var_types=[helpers["key_type"], helpers["val_type"]],
                        rc_vars=True,
                        coll_release_op="fori_coll"
                    );
                    return;
                }
            }
        }
    }
    if loop_var_name is None {
        if len(self.errors_had) == _for_errs0 {
            self.emit(
                E5092,
                node_override=nd,
                kind="for-loop target",
                name=type(nd.target).__name__
            );
        }
        return;
    }

    if isinstance(nd.collection, uni.FuncCall)
    and self._get_name(nd.collection.target) == "range"
    and nd.collection.call_kind == "builtin" {
        params = nd.collection.params or [];
        start_val: (ir.Value | None) = None;
        stop_val: (ir.Value | None) = None;
        step_val: (ir.Value | None) = None;
        if len(params) == 1 {
            start_val = ir.Constant(ir.IntType(64), 0);
            stop_val = self._codegen_expr(params[0]);
        } elif len(params) >= 2 {
            start_val = self._codegen_expr(params[0]);
            stop_val = self._codegen_expr(params[1]);
            if len(params) >= 3 {
                step_val = self._codegen_expr(params[2]);
                if step_val is None {
                    return;
                }
                step_val = self._coerce_type(step_val, ir.IntType(64));
                _step_is_zero = self.builder.icmp_signed(
                    "==",
                    step_val,
                    ir.Constant(ir.IntType(64), 0),
                    name="range.step.zero"
                );
                self._emit_runtime_raise(
                    _step_is_zero, "ValueError", "range() arg 3 must not be zero"
                );
            }
        }
        if start_val is not None and stop_val is not None {
            self._codegen_for_indexed(
                nd,
                kind="range",
                collection_val=self._coerce_type(stop_val, ir.IntType(64)),
                helpers=None,
                var_names=[loop_var_name],
                var_types=[ir.IntType(64)],
                rc_vars=False,
                coll_release_op="",
                range_start=self._coerce_type(start_val, ir.IntType(64)),
                range_step=self._coerce_type(step_val, ir.IntType(64))
                    if step_val is not None
                    else None
            );
            return;
        }
    }

    coll_name = self._get_name(nd.collection);
    _coll_memo: (ir.Value | None) = self._codegen_expr(nd.collection);

    dict_type_key: (str | None) = self._dict_key_of(nd.collection);
    if dict_type_key is None and _coll_memo is not None {
        dict_info = self._infer_dict_type(_coll_memo);
        if dict_info is not None {
            dict_type_key = f"{dict_info[0]}:{dict_info[1]}";
        }
    }
    if dict_type_key is not None {
        helpers = self.dict_helpers.get(dict_type_key);
        if helpers is not None and _coll_memo is not None {
            self._codegen_for_indexed(
                nd,
                kind="dict",
                collection_val=_coll_memo,
                helpers=helpers,
                var_names=[loop_var_name],
                var_types=[helpers["key_type"]],
                rc_vars=True,
                coll_release_op="ford_coll"
            );
            return;
        }
    }

    if _coll_memo is not None
    and self?.jacval_type
    and _coll_memo.type == self.jacval_type {
        self._emit_list_helpers("jacval", self.jacval_type);
        _any_list_helpers = self.list_helpers.get("jacval");
        if _any_list_helpers is not None {
            _any_list = self._unbox_from_jacval(
                _coll_memo, self.list_types["jacval"].as_pointer()
            );
            self._codegen_for_indexed(
                nd,
                kind="list",
                collection_val=_any_list,
                helpers=_any_list_helpers,
                var_names=[loop_var_name],
                var_types=[self.jacval_type],
                rc_vars=False,
                coll_release_op=""
            );
            return;
        }
    }

    if _coll_memo is not None and self._is_bytes_value(_coll_memo) {
        self._codegen_for_indexed(
            nd,
            kind="bytes",
            collection_val=_coll_memo,
            helpers=None,
            var_names=[loop_var_name],
            var_types=[ir.IntType(64)],
            rc_vars=False,
            coll_release_op="forby_coll"
        );
        return;
    }

    if self._list_spec_of(nd.collection) is None
    and self._dict_key_of(nd.collection) is None
    and _coll_memo is not None
    and _coll_memo.type == ir.IntType(8).as_pointer() {
        self._codegen_for_indexed(
            nd,
            kind="str",
            collection_val=_coll_memo,
            helpers=None,
            var_names=[loop_var_name],
            var_types=[ir.IntType(8).as_pointer()],
            rc_vars=False,
            coll_release_op="fors_coll"
        );
        return;
    }

    if _coll_memo is None {
        if len(self.errors_had) == _for_errs0 {
            self.emit(
                E5092,
                node_override=nd.collection,
                kind="for-loop iterable",
                name=type(nd.collection).__name__ if nd.collection else "<expr>"
            );
        }
        return;
    }

    elem_type_name: (str | None) = self._infer_list_elem_type(_coll_memo);
    if elem_type_name is None {
        elem_type_name = self._elem_spec_of(nd.collection);
    }
    if elem_type_name is None and isinstance(_coll_memo.type, ir.PointerType) {
        is_set = False;
        for (sname, stype) in self.set_types.items() {
            if _coll_memo.type == stype.as_pointer() {
                is_set = True;
                break;
            }
        }
        if not is_set {
            elem_type_name = "ptr";
        }
    }
    helpers = self.list_helpers.get(elem_type_name) if elem_type_name else None;
    if helpers is None {
        if len(self.errors_had) == _for_errs0 {
            self.emit(
                E5092,
                node_override=nd.collection or nd,
                kind="for-loop iterable element type",
                name=(coll_name or "<expr>")
            );
        }
        return;
    }

    actual_elem_type = helpers["elem_type"];
    inner_type: (ir.Type | None) = None;
    if elem_type_name == "ptr" {
        inner_type = self._list_elem_llvm_of(nd.collection);
        if inner_type is not None and not isinstance(inner_type, ir.PointerType) {
            inner_type = None;
        }
        if inner_type is not None {
            actual_elem_type = inner_type;
        }
    }
    self._codegen_for_indexed(
        nd,
        kind="list",
        collection_val=_coll_memo,
        helpers=helpers,
        var_names=[loop_var_name],
        var_types=[actual_elem_type],
        rc_vars=True,
        coll_release_op="forl_coll",
        elem_cast=inner_type,
        unpack_target=_unpack_target
    );
}

impl NaIRGenPass._codegen_for_indexed(
    nd: uni.InForStmt,
    kind: str,
    collection_val: ir.Value,
    helpers: (dict | None),
    var_names: list,
    var_types: list,
    rc_vars: bool,
    coll_release_op: str,
    range_start: (ir.Value | None) = None,
    elem_cast: (ir.Type | None) = None,
    unpack_target: (uni.TupleVal | None) = None,
    range_step: (ir.Value | None) = None
) -> None {
    i64 = ir.IntType(64);
    _for_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.last_line
        if nd.loc
        else 0}";
    _rc_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";

    if kind == "range" {
        len_val = collection_val;
        idx_alloca = self._entry_alloca(i64, var_names[0]);
        self.builder.store(range_start, idx_alloca);
        self.local_vars[var_names[0]] = idx_alloca;
        allocas = [idx_alloca];
    } else {
        if kind == "str" {
            strlen_fn = self._get_or_declare_extern(
                "strlen", i64, [ir.IntType(8).as_pointer()]
            );
            len_val = self.builder.call(strlen_fn, [collection_val], name="for.len");
        } elif kind == "bytes" {
            len_val = self._bytes_len_val(collection_val);
        } else {
            len_val = self.builder.call(
                helpers["len"], [collection_val], name="for.len"
            );
        }
        idx_alloca = self._entry_alloca(i64, "for.idx");
        self.builder.store(ir.Constant(i64, 0), idx_alloca);
        allocas = [];
        _setup_names = [] if unpack_target is not None else var_names;
        for (vi, vname) in enumerate(_setup_names) {
            vtype = var_types[vi];

            _existing = self.local_vars.get(vname);
            _reuse = (
                _existing is not None
                and isinstance(_existing.type, ir.PointerType)
                and _existing.type.pointee == vtype
            );
            alloca = _existing if _reuse else self._entry_alloca(vtype, vname);
            if isinstance(vtype, ir.PointerType) and (rc_vars or kind == "str") {
                null_const = ir.Constant(vtype, None);
                if not _reuse {
                    _saved_block = self.builder.block;
                    self.builder.position_after(alloca);
                    self.builder.store(null_const, alloca);
                    self.builder.position_at_end(_saved_block);
                }
                if rc_vars {
                    _pre_old = self.builder.load(alloca, name="for.pre.old");
                    self._emit_rc_release_simple(_pre_old, op="for_reset", loc=_rc_loc);
                    self.builder.store(null_const, alloca);
                }
            }
            self.local_vars[vname] = alloca;
            allocas.append(alloca);
        }
    }
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="for.cond");
    body_bb = func.append_basic_block(name="for.body");
    incr_bb = func.append_basic_block(name="for.incr");
    end_bb = func.append_basic_block(name="for.end");
    self.builder.branch(cond_bb);
    self.builder.position_at_end(cond_bb);
    cur_idx = self.builder.load(idx_alloca, name="for.cur.idx");
    if kind == "range" and range_step is not None {
        _step_pos = self.builder.icmp_signed(
            ">", range_step, ir.Constant(i64, 0), name="for.step.pos"
        );
        _lt_stop = self.builder.icmp_signed("<", cur_idx, len_val, name="for.lt.stop");
        _gt_stop = self.builder.icmp_signed(">", cur_idx, len_val, name="for.gt.stop");
        cmp = self.builder.select(_step_pos, _lt_stop, _gt_stop, name="for.cmp");
    } else {
        cmp = self.builder.icmp_signed("<", cur_idx, len_val, name="for.cmp");
    }
    self.builder.cbranch(cmp, body_bb, end_bb);
    self.loop_stack.append((incr_bb, end_bb));
    self.builder.position_at_end(body_bb);

    if kind != "range" {
        body_idx = self.builder.load(idx_alloca, name="for.body.idx");
        if kind == "items" {
            key_val = self.builder.call(
                helpers["get_key"], [collection_val, body_idx], name="for.key"
            );
            val_val = self.builder.call(
                helpers["get_val"], [collection_val, body_idx], name="for.val"
            );

            if rc_vars and isinstance(var_types[0], ir.PointerType) {
                _old_k = self.builder.load(allocas[0], name="for.key.old");
                self._emit_rc_release_simple(_old_k, op="for_items_key", loc=_rc_loc);
                self._emit_rc_retain(key_val, op="for_items_key", loc=_rc_loc);
            }
            if rc_vars and isinstance(var_types[1], ir.PointerType) {
                _old_v = self.builder.load(allocas[1], name="for.val.old");
                self._emit_rc_release_simple(_old_v, op="for_items_val", loc=_rc_loc);
                self._emit_rc_retain(val_val, op="for_items_val", loc=_rc_loc);
            }
            self.builder.store(key_val, allocas[0]);
            self.builder.store(val_val, allocas[1]);
        } elif kind == "str" {
            char_str = self._codegen_string_index(collection_val, body_idx);
            if char_str is not None {
                self.builder.store(char_str, allocas[0]);
            }
        } elif kind == "bytes" {
            _by_ptr = self.builder.gep(
                self._bytes_data_ptr(collection_val), [body_idx], name="for.by.ptr"
            );
            _by = self.builder.load(_by_ptr, name="for.by.byte");
            self.builder.store(
                self.builder.zext(_by, i64, name="for.by.val"), allocas[0]
            );
        } elif kind in ("list", "dict") {
            fetch_fn = helpers["get"] if kind == "list" else helpers["get_key"];
            elem_val = self.builder.call(
                fetch_fn, [collection_val, body_idx], name="for.elem"
            );
            if elem_cast is not None {
                elem_val = self.builder.bitcast(elem_val, elem_cast, name="for.cast");
            }
            if unpack_target is not None {
                if not self._codegen_tuple_unpack(
                    unpack_target.values, elem_val, None
                ) {
                    self.emit(
                        E5092,
                        node_override=unpack_target,
                        kind="for-loop target",
                        name=type(unpack_target).__name__
                    );
                }
            } else {
                if rc_vars and isinstance(var_types[0], ir.PointerType) {
                    old_val = self.builder.load(allocas[0], name="for.old");
                    self._emit_rc_release_simple(old_val, op="for_elem", loc=_rc_loc);
                    self._emit_rc_retain(elem_val, op="for_elem", loc=_rc_loc);
                }
                self.builder.store(elem_val, allocas[0]);
            }
        } else {
            self.emit(
                E9002,
                node_override=nd,
                details=f"unknown for-loop iteration kind '{kind}'"
            );
            return;
        }
    }
    import from jaclang.compiler.passes.main.rc_facts_pass { loop_body_locals }
    _for_saved = loop_body_locals(
        nd.body if isinstance(nd.body, (list, tuple)) else None
    );

    _for_prebody = set(self.local_vars.keys());
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    if not self.builder.block.is_terminated {
        self._emit_loop_iter_cleanup(
            [
                _v
                for _v in _for_saved
                if _v not in _for_prebody
            ],
            loc=_for_loc
        );
        self.builder.branch(incr_bb);
    }
    self.loop_stack.pop();
    self.builder.position_at_end(incr_bb);
    inc_idx = self.builder.load(idx_alloca, name="for.inc.idx");
    _idx_delta = range_step
        if kind == "range" and range_step is not None
        else ir.Constant(i64, 1);
    next_idx = self.builder.add(inc_idx, _idx_delta, name="for.next.idx");
    self.builder.store(next_idx, idx_alloca);
    self.builder.branch(cond_bb);
    self.builder.position_at_end(end_bb);

    if coll_release_op
    and isinstance(collection_val.type, ir.PointerType)
    and self._is_owned(collection_val) {
        self._emit_rc_release_simple(collection_val, op=coll_release_op, loc=_for_loc);
    }
}
