impl NaIRGenStmt._codegen_body(stmts: (list | tuple)) -> None {
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
            } except Exception {}
        }
    }
}

impl NaIRGenStmt._emit_last_use_releases(stmt: uni.UniNode) -> None {
    _map = self.ir_in.rc_last_use;
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
        if (name == "self" and not self._self_owned) or name in self.param_vars {
            continue;
        }
        if name in self.nogc_no_free_vars {
            continue;
        }
        alloca = self.local_vars.get(name);
        if alloca is None {
            continue;
        }
        slot_ty = alloca.type?.pointee;
        _lu_ptr = isinstance(slot_ty, ir.PointerType) and slot_ty?.pointee;
        if not _lu_ptr
            and (
                self._opt_ptr_payload_of(slot_ty) is None
                or not self._nogc_owned_world()
            ) {
            continue;
        }
        if name in self.region_handle_vars {
            continue;
        }
        if name in self.closure_cell_handles {
            continue;
        }
        val = self._rc_unwrap_optional(self.builder.load(alloca, name=f"lu.{name}"));
        self._emit_rc_release_typed(val, op="last_use", loc="");
        self.builder.store(ir.Constant(slot_ty, None), alloca);
    }
}

impl NaIRGenStmt._codegen_stmt(nd: uni.UniNode) -> None {
    if self._builder is None or self._builder.block.is_terminated {
        return;
    }
    if isinstance(nd, (uni.AssertStmt, uni.Ability)) and nd.is_comptime {
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
        } elif (
            _estmt_val is not None
            and self?.jacval_type
            and _estmt_val.type == self.jacval_type
            and self._is_owned(_estmt_val)
        ) {
            self._emit_elem_release(self.builder, self.jacval_type, _estmt_val);
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
        self._codegen_delete(nd);
    } elif isinstance(nd, uni.Semi) {} elif isinstance(nd, uni.Import) {} elif isinstance(
        nd, uni.PyInlineCode
    ) {} elif isinstance(nd, uni.VisitStmt) {
        self._codegen_visit(nd);
    } elif isinstance(nd, uni.DisengageStmt) {
        self._codegen_disengage(nd);
    } elif isinstance(nd, uni.ReportStmt) {
        self._codegen_report(nd);
    } else {
        self.emit(E5092, node_override=nd, kind="statement", name=type(nd).__name__);
    }
}

impl NaIRGenStmt._codegen_delete(nd: uni.DeleteStmt) -> None {
    for target in nd.leaf_targets() {
        if not uni.DeleteStmt.is_location(target) {
            self._codegen_destroy_target(target, nd);
            continue;
        }
        if self._del_target_holds_graph(target) {
            self._codegen_destroy_target(target, nd);
        }
        if isinstance(target, uni.AtomTrailer) {
            self._codegen_delete_location(target, nd);
        }
    }
}

impl NaIRGenStmt._codegen_destroy_target(target: uni.Expr, nd: uni.DeleteStmt) -> None {
    _destroy_fn = self.func_symtab.get("osp_destroy");
    _destroy_all_fn = self.func_symtab.get("osp_destroy_all");
    if _destroy_fn is None or _destroy_all_fn is None {
        self.emit(E5092, node_override=nd, kind="statement", name="DeleteStmt");
        return;
    }
    _val = self._codegen_expr(target);
    if _val is None {
        self.emit(E5092, node_override=nd, kind="statement", name="DeleteStmt");
        return;
    }
    _forget_fn = self.func_symtab.get("osp_forget");
    _forget_all_fn = self.func_symtab.get("osp_forget_all");
    if self._infer_list_elem_type(_val) is not None {
        _all_argtys = _destroy_all_fn.function_type.args;
        _hs = self._coerce_type(_val, _all_argtys[0]);
        self.builder.call(_destroy_all_fn, [_hs]);
        if _forget_all_fn is not None {
            _fa_argtys = _forget_all_fn.function_type.args;
            self.builder.call(_forget_all_fn, [self._coerce_type(_hs, _fa_argtys[0])]);
        }
        return;
    }
    if self._struct_name_of(target) is None {
        self.emit(E5092, node_override=nd, kind="statement", name="DeleteStmt");
        return;
    }
    _argtys = _destroy_fn.function_type.args;
    _h = self._coerce_type(_val, _argtys[0]);
    self.builder.call(_destroy_fn, [_h]);
    if _forget_fn is not None {
        _f_argtys = _forget_fn.function_type.args;
        self.builder.call(_forget_fn, [self._coerce_type(_h, _f_argtys[0])]);
    }
}

impl NaIRGenStmt._del_target_holds_graph(target: uni.Expr) -> bool {
    _model = self.ir_in.gen.osp_model;
    _type_key = self._type_key_of(target);
    if (_model is None) or (_type_key is None) {
        return False;
    }
    _flat = _type_key;
    for _ch in "[](),|" {
        _flat = _flat.replace(_ch, " ");
    }
    for _part in _flat.split() {
        if _model.arch_kind.get(_part) is not None {
            return True;
        }
    }
    return False;
}

impl NaIRGenStmt._codegen_delete_location(
    target: uni.AtomTrailer, nd: uni.DeleteStmt
) -> None {
    if target.is_attr {
        _del_cls = self._struct_name_of(target.target);
        _del_fld = self._get_name(target.right);
        if _del_cls is None or _del_fld is None {
            self.emit(E5092, node_override=nd, kind="statement", name="DeleteStmt");
            return;
        }
        _del_slot = self._accessor_slot_of(_del_cls, _del_fld, "deleter");
        if _del_slot is None {
            self.emit(E5092, node_override=nd, kind="statement", name="DeleteStmt");
            return;
        }
        _del_recv = self._codegen_expr(target.target);
        if _del_recv is None
            or self._codegen_accessor_call(_del_recv, _del_cls, _del_slot, [])
                is None {
            self.emit(E5092, node_override=nd, kind="statement", name="DeleteStmt");
        }
        return;
    }
    _islice = target.right;
    if (not isinstance(_islice, uni.IndexSlice))
        or _islice.is_range
        or len(_islice.slices) != 1 {
        self.emit(E5092, node_override=nd, kind="statement", name="DeleteStmt");
        return;
    }
    _idx_node = _islice.slices[0];
    _idx_direct = self._codegen_expr(_idx_node);
    _idx_val = _idx_direct
        if _idx_direct is not None
        else (self._codegen_expr(_idx_node.start) if _idx_node?.start else None);
    if _idx_val is None {
        self.emit(E5092, node_override=nd, kind="statement", name="DeleteStmt");
        return;
    }
    _dict_type_key = self._dict_key_of(target.target);
    if _dict_type_key is None {
        _dict_probe = self._codegen_expr(target.target);
        _dict_info = self._infer_dict_type(_dict_probe)
            if _dict_probe is not None
            else None;
        if _dict_info is not None {
            _dict_type_key = f"{_dict_info[0]}:{_dict_info[1]}";
        }
    }
    _container = self._codegen_expr(target.target);
    if _container is None {
        self.emit(E5092, node_override=nd, kind="statement", name="DeleteStmt");
        return;
    }
    if _dict_type_key is not None {
        _dict_key = self._dict_key_reconcile(_dict_type_key, _container);
        if _dict_key is None {
            self.emit(E5092, node_override=nd, kind="statement", name="DeleteStmt");
            return;
        }
        self._dispatch_primitive_method(
            "dict", "remove", _container, [_idx_val], _dict_key
        );
        return;
    }
    _elem_type_name = self._infer_list_elem_type(_container);
    if _elem_type_name is None {
        self.emit(E5092, node_override=nd, kind="statement", name="DeleteStmt");
        return;
    }
    self._dispatch_primitive_method(
        "list", "del_at", _container, [_idx_val], _elem_type_name
    );
}

impl NaIRGenStmt._codegen_return(nd: uni.ReturnStmt) -> None {
    _gc = self._gen_ctx;
    if _gc is not None and self.builder.function is _gc["resume_fn"] {
        _gr_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
            if nd.loc
            else 0}";
        if nd.expr is not None {
            _rv = self._codegen_expr(nd.expr);
            if _rv is not None
                and isinstance(_rv.type, ir.PointerType)
                and self._is_owned(_rv) {
                self._emit_rc_release_simple(_rv, op="gen_ret_val", loc=_gr_loc);
            }
        }
        for _entry in self._gen_try_stack {
            self.builder.call(self._exc_pop_fn, []);
        }
        self._emit_scope_cleanup(skip_var=None, loc=_gr_loc);
        _gr_i64 = ir.IntType(64);
        _gr_ip = self.builder.bitcast(
            _gc["frame_i8"], _gr_i64.as_pointer(), name="gen.ret.ip"
        );
        self.builder.store(ir.Constant(_gr_i64, -1), _gr_ip);
        self.builder.ret(ir.Constant(ir.IntType(1), 0));
        return;
    }
    func_ret_type = self.builder.function.return_value.type;
    if nd.expr is not None and isinstance(func_ret_type, ir.VoidType) {
        self._codegen_expr(nd.expr);
        self._emit_scope_cleanup(
            skip_var=None,
            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                if nd.loc
                else 0}"
        );
        self.builder.ret_void();
        return;
    }
    if nd.expr is not None {
        val = self._codegen_required(nd.expr);
        if val is not None {
            val = self._coerce_type(val, func_ret_type);
            _ret_root_local = False;
            if isinstance(nd.expr, uni.AtomTrailer)
                and isinstance(nd.expr.right, uni.IndexSlice) {
                _rr = nd.expr.target;
                while isinstance(_rr, uni.AtomTrailer) {
                    _rr = _rr.target;
                }
                if isinstance(_rr, uni.Name)
                    and _rr.sym_name in self.local_vars
                    and _rr.sym_name not in self.param_vars {
                    _ret_root_local = True;
                }
            }
            if _ret_root_local
                and (
                    isinstance(val.type, ir.PointerType)
                    or (self._str_desc_ty is not None and val.type == self._str_desc_ty)
                )
                and not self._is_owned(val)
                and self._gc_mode() != "none" {
                self._emit_rc_retain(val, op="ret_borrowed", loc="");
                self._mark_owned(val);
            }

            skip_var: (str | None) = None;
            if isinstance(nd.expr, uni.Name)
                and nd.expr.sym_name in self.local_vars
                and nd.expr.sym_name not in self.param_vars
                and nd.expr.sym_name not in self.closure_cell_handles {
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
                            if elem_name in self.closure_cell_handles {
                                _tup_cell_val = self.builder.load(
                                    tup_alloca, name=f"ret.cell.{elem_name}"
                                );
                                self._emit_rc_retain(
                                    _tup_cell_val, op="return", loc=""
                                );
                            } else {
                                self.builder.store(
                                    ir.Constant(tup_alloca.type.pointee, None),
                                    tup_alloca
                                );
                            }
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
            if (
                skip_var is None
                and self._opt_ptr_payload_of(val.type) is not None
                and not self._nogc_headerless()
                and self._gc_mode() != "none"
                and not self._opt_result_owned(val, nd.expr)
            ) {
                self._emit_rc_retain(
                    self.builder.extract_value(val, 1, name="ret.opt.pv"),
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
        _fb = 0 if isinstance(func_ret_type, (ir.IntType, ir.DoubleType)) else None;
        self.builder.ret(ir.Constant(func_ret_type, _fb));
    }
}

impl NaIRGenStmt._codegen_if(nd: uni.IfStmt) -> None {
    if nd.is_comptime {
        taken = nd.ct_taken;
        if taken is None {
            (ok, v) = self._ct_value_with_bindings(nd.condition);
            if not ok {
                self.emit(
                    E5092,
                    node_override=nd.condition,
                    kind="comptime if condition",
                    name="comptime if",
                    help_text="The condition depends on a comptime parameter or loop variable that has no binding in this specialization."
                );
                return;
            }
            taken = bool(v);
        }
        if taken {
            if isinstance(nd.body, (list, tuple)) {
                self._codegen_body(nd.body);
            }
        } elif isinstance(nd.else_body, uni.ElseIf) {
            self._codegen_if(nd.else_body);
        } elif isinstance(nd.else_body, uni.ElseStmt) {
            if isinstance(nd.else_body.body, (list, tuple)) {
                self._codegen_body(nd.else_body.body);
            }
        }
        return;
    }
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

impl NaIRGenStmt._codegen_switch(nd: uni.SwitchStmt) -> None {
    target_val = self._str_norm(self._codegen_expr(nd.target));
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

    for (i, sc) in enumerate(value_cases) {
        pattern_val = None;
        if isinstance(sc.pattern, uni.MatchValue) {
            pattern_val = self._codegen_expr(sc.pattern.value);
        }
        if pattern_val is None {
            continue;
        }

        if is_str {
            pattern_coerced = self._coerce_type(pattern_val, i8p);
            cmp_result = self._call_str_cmp(
                self.builder, target_val, pattern_coerced, name="switch.strcmp"
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

impl NaIRGenStmt._codegen_while(nd: uni.WhileStmt) -> None {
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

    import from jaclang.compiler.passes.rc_facts_pass { loop_body_locals }
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

impl NaIRGenStmt._codegen_open_stmt(nd: uni.OpenStmt) -> None {
    import from jaclang.compiler.passes.rc_facts_pass { loop_body_locals }
    _region_body_locals = loop_body_locals(
        nd.body if isinstance(nd.body, (list, tuple)) else None
    );
    _i8p = ir.IntType(8).as_pointer();
    _hdl = self._codegen_expr(nd.target);
    if _hdl is None {
        if isinstance(nd.body, (list, tuple)) {
            self._codegen_body(nd.body);
        }
        return;
    }
    _hdl = self._region_ptr(_hdl, name="region.hdl");
    _synth: (str | None) = None;
    if not isinstance(nd.target, uni.Name) {
        _synth = f".region.{id(nd)}";
        _slot = self._entry_alloca(_i8p, _synth);
        self.builder.store(_hdl, _slot);
        self.local_vars[_synth] = _slot;
        self.region_handle_vars.add(_synth);
    }
    self._region_enter(_hdl);
    self.region_open_stack.append(len(self.loop_stack));
    _region_prebody = set(self.local_vars.keys());
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    self.region_open_stack.pop();
    if self.builder.block.is_terminated {
        return;
    }
    self._region_leave();
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

impl NaIRGenStmt._codegen_forever(nd: uni.ForeverStmt) -> None {
    func = self.builder.function;
    body_bb = func.append_basic_block(name="forever.body");
    end_bb = func.append_basic_block(name="forever.end");

    self.builder.branch(body_bb);

    self.loop_stack.append((body_bb, end_bb));
    self.builder.position_at_end(body_bb);

    import from jaclang.compiler.passes.rc_facts_pass { loop_body_locals }
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

impl NaIRGenStmt._codegen_iter_for(nd: uni.IterForStmt) -> None {
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
    import from jaclang.compiler.passes.rc_facts_pass { loop_body_locals }
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

impl NaIRGenStmt._codegen_match(nd: uni.MatchStmt) -> None {
    subj = self._codegen_expr(nd.target);
    if subj is None {
        return;
    }

    subj_alloca = self._entry_alloca(subj.type, "match.subj");
    self.builder.store(subj, subj_alloca);
    subj_ty = self._match_subj_ty(nd.target);
    func = self.builder.function;
    end_bb = func.append_basic_block(name="match.end");
    n = len(nd.cases);
    for (ci, `case) in enumerate(nd.cases) {
        subj_val = self.builder.load(subj_alloca, name="match.subj.l");
        cond = self._match_pattern_cond(`case.pattern, subj_val, subj_ty);
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
        if `case.guard is not None {
            bind_bb = func.append_basic_block(name=f"match.c{ci}.bind");
            self.builder.cbranch(cond, bind_bb, next_bb);
            self.builder.position_at_end(bind_bb);
            self._bind_match_pattern(`case.pattern, subj_val, subj_ty);
            gval = self._codegen_expr(`case.guard);
            if gval is not None {
                self.builder.cbranch(self._to_bool(gval), body_bb, next_bb);
            } else {
                self.builder.branch(next_bb);
            }
        } else {
            self.builder.cbranch(cond, body_bb, next_bb);
        }

        self.builder.position_at_end(body_bb);
        if `case.guard is None {
            self._bind_match_pattern(`case.pattern, subj_val, subj_ty);
        }
        if isinstance(`case.body, (list, tuple)) {
            self._codegen_body(`case.body);
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

impl NaIRGenStmt._match_pattern_cond(
    pat: uni.MatchPattern, subj: ir.Value, subj_ty: (object | None) = None
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    if isinstance(pat, uni.MatchWild) {
        return ir.Constant(i1, 1);
    }
    if isinstance(pat, uni.MatchAs) {
        if pat.pattern is None {
            return ir.Constant(i1, 1);
        }
        return self._match_pattern_cond(pat.pattern, subj, subj_ty);
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
            sub_cond = self._match_pattern_cond(sub, subj, subj_ty);
            if sub_cond is None {
                return None;
            }
            result = sub_cond
                if result is None
                else self.builder.or_(result, sub_cond, name="match.or");
        }
        return result;
    }
    if isinstance(pat, uni.MatchSequence) {
        return self._match_seq_cond(pat, subj, subj_ty);
    }
    if isinstance(pat, uni.MatchMapping) {
        return self._match_map_cond(pat, subj, subj_ty);
    }
    if isinstance(pat, uni.MatchArch) {
        return self._match_arch_cond(pat, subj, subj_ty);
    }

    self.emit(E5092, node_override=pat, kind="match pattern", name=type(pat).__name__);
    return None;
}

impl NaIRGenStmt._match_subj_ty(expr: (uni.UniNode | None)) -> (object | None) {
    if not isinstance(expr, uni.Expr) {
        return None;
    }
    if expr.type is not None {
        return expr.type;
    }
    if not isinstance(expr, uni.NameAtom) or expr.sym is None {
        return None;
    }
    decl = expr.sym.decl;
    if decl is None {
        return None;
    }
    holder = decl.find_parent_of_type(uni.Assignment)
        or decl.find_parent_of_type(uni.ParamVar)
        or decl.find_parent_of_type(uni.HasVar);
    tag = holder.type_tag if holder is not None else None;
    tag_expr = tag.tag if tag is not None else None;
    if isinstance(tag_expr, uni.Expr) and tag_expr.type is not None {
        try {
            import from jaclang.compiler.types.type_utils { convert_to_instance }
            return convert_to_instance(tag_expr.type);
        } except ImportError {
            return tag_expr.type;
        }
    }
    return None;
}

impl NaIRGenStmt._match_seq_parts(pat: uni.MatchSequence) -> tuple {
    heads: list = [];
    tails: list = [];
    star: (uni.MatchStar | None) = None;
    for sub in pat.values {
        if isinstance(sub, uni.MatchStar) {
            star = sub;
        } elif star is not None {
            tails.append(sub);
        } else {
            heads.append(sub);
        }
    }
    return (heads, star, tails);
}

impl NaIRGenStmt._match_elem_ty_of(
    subj_ty: (object | None), prefix: str, idx: int
) -> (object | None) {
    if subj_ty is None or not self._mangled_of(subj_ty).startswith(prefix) {
        return None;
    }
    targs = subj_ty.private.type_args or [];
    if idx < len(targs) {
        return targs[idx];
    }
    return None;
}

impl NaIRGenStmt._match_cast_elem(
    elem: ir.Value, elem_ty: (object | None)
) -> ir.Value {
    if elem_ty is None or not isinstance(elem.type, ir.PointerType) {
        return elem;
    }
    lowered = self._lower_type(elem_ty);
    if lowered is not None
        and isinstance(lowered, ir.PointerType)
        and lowered != elem.type {
        return self.builder.bitcast(elem, lowered, name="match.elem.cast");
    }
    return elem;
}

impl NaIRGenStmt._match_seq_cond(
    pat: uni.MatchSequence, subj: ir.Value, subj_ty: (object | None) = None
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i64 = ir.IntType(64);
    (heads, star, tails) = self._match_seq_parts(pat);
    spec = self._infer_list_elem_type(subj);
    if spec is None {
        if isinstance(subj.type, ir.PointerType)
            and isinstance(subj.type.pointee, ir.LiteralStructType) {
            return self._match_tuple_seq_cond(pat, subj, subj_ty);
        }
        self.emit(
            E5092,
            node_override=pat,
            kind="match pattern",
            name="MatchSequence",
            help_text="The match subject could not be resolved to a native list or tuple layout. Annotate the subject with a concrete list[...] type, or move this code to a @sv/Python context."
        );
        return None;
    }
    helpers = self.list_helpers[spec];
    elem_ty = self._match_elem_ty_of(subj_ty, "list[", 0);
    func = self.builder.function;
    res = self._entry_alloca(i1, "match.seq.res");
    self.builder.store(ir.Constant(i1, 0), res);
    merge_bb = func.append_basic_block(name="match.seq.merge");
    len_val = self.builder.call(helpers["len"], [subj], name="match.seq.len");
    n_tails = len(tails);
    min_len = ir.Constant(i64, len(heads) + n_tails);
    len_ok = (
        self.builder.icmp_signed(">=", len_val, min_len, name="match.seq.lenok")
            if star is not None
            else self.builder.icmp_signed(
                "==", len_val, min_len, name="match.seq.lenok"
            )
    );
    chk_bb = func.append_basic_block(name="match.seq.chk");
    self.builder.cbranch(len_ok, chk_bb, merge_bb);
    self.builder.position_at_end(chk_bb);
    for (i, sub_pat) in enumerate(heads) {
        elem = self.builder.call(
            helpers["get"], [subj, ir.Constant(i64, i)], name="match.seq.elem"
        );
        elem = self._match_cast_elem(elem, elem_ty);
        sub_cond = self._match_pattern_cond(sub_pat, elem, elem_ty);
        if sub_cond is None {
            self.builder.branch(merge_bb);
            self.builder.position_at_end(merge_bb);
            return None;
        }
        next_bb = func.append_basic_block(name="match.seq.chk");
        self.builder.cbranch(sub_cond, next_bb, merge_bb);
        self.builder.position_at_end(next_bb);
    }
    for (j, sub_pat) in enumerate(tails) {
        idx = self.builder.sub(
            len_val, ir.Constant(i64, n_tails - j), name="match.seq.tidx"
        );
        elem = self.builder.call(helpers["get"], [subj, idx], name="match.seq.elem");
        elem = self._match_cast_elem(elem, elem_ty);
        sub_cond = self._match_pattern_cond(sub_pat, elem, elem_ty);
        if sub_cond is None {
            self.builder.branch(merge_bb);
            self.builder.position_at_end(merge_bb);
            return None;
        }
        next_bb = func.append_basic_block(name="match.seq.chk");
        self.builder.cbranch(sub_cond, next_bb, merge_bb);
        self.builder.position_at_end(next_bb);
    }
    self.builder.store(ir.Constant(i1, 1), res);
    self.builder.branch(merge_bb);
    self.builder.position_at_end(merge_bb);
    return self.builder.load(res, name="match.seq.ok");
}

impl NaIRGenStmt._match_tuple_seq_cond(
    pat: uni.MatchSequence, subj: ir.Value, subj_ty: (object | None) = None
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    (heads, star, tails) = self._match_seq_parts(pat);
    if star is not None {
        self.emit(
            E5092,
            node_override=pat,
            kind="match pattern",
            name="MatchStar",
            help_text="Star sub-patterns over a tuple-typed match subject are not lowered natively; match a list subject instead."
        );
        return None;
    }
    if len(subj.type.pointee.elements) != len(heads) {
        return ir.Constant(i1, 0);
    }
    loaded = self.builder.load(subj, name="match.tup");
    result: (ir.Value | None) = None;
    for (i, sub_pat) in enumerate(heads) {
        elem = self.builder.extract_value(loaded, i, name="match.tup.elem");
        elem_ty = self._match_elem_ty_of(subj_ty, "tuple[", i);
        elem = self._match_cast_elem(elem, elem_ty);
        sub_cond = self._match_pattern_cond(sub_pat, elem, elem_ty);
        if sub_cond is None {
            return None;
        }
        result = sub_cond
            if result is None
            else self.builder.and_(result, sub_cond, name="match.tup.and");
    }
    return result if result is not None else ir.Constant(i1, 1);
}

impl NaIRGenStmt._match_map_key(
    kv: uni.MatchKVPair, helpers: dict
) -> (ir.Value | None) {
    key_node = kv.key.value if isinstance(kv.key, uni.MatchValue) else kv.key;
    key_val = self._codegen_expr(key_node) if isinstance(key_node, uni.Expr) else None;
    if key_val is None {
        self.emit(
            E5092,
            node_override=kv,
            kind="match pattern",
            name="MatchKVPair",
            help_text="Mapping pattern keys must be int/float/str literals to lower natively."
        );
        return None;
    }
    return self._coerce_type(key_val, helpers["key_type"]);
}

impl NaIRGenStmt._match_map_cond(
    pat: uni.MatchMapping, subj: ir.Value, subj_ty: (object | None) = None
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    dict_info = self._infer_dict_type(subj);
    if dict_info is None {
        self.emit(
            E5092,
            node_override=pat,
            kind="match pattern",
            name="MatchMapping",
            help_text="The match subject could not be resolved to a native dict layout. Annotate the subject with a concrete dict[...] type, or move this code to a @sv/Python context."
        );
        return None;
    }
    (kspec, vspec) = dict_info;
    helpers = self.dict_helpers[f"{kspec}:{vspec}"];
    val_ty = self._match_elem_ty_of(subj_ty, "dict[", 1);
    func = self.builder.function;
    res = self._entry_alloca(i1, "match.map.res");
    self.builder.store(ir.Constant(i1, 0), res);
    merge_bb = func.append_basic_block(name="match.map.merge");
    for kv in pat.values {
        if isinstance(kv, uni.MatchStar) {
            continue;
        }
        key_val = self._match_map_key(kv, helpers);
        if key_val is None {
            self.builder.branch(merge_bb);
            self.builder.position_at_end(merge_bb);
            return None;
        }
        _mk_nd = kv.key.value if isinstance(kv.key, uni.MatchValue) else kv.key;
        (_has_fn, _mkh) = self._static_key_op(helpers, "contains", _mk_nd);
        _has_args = [subj, key_val];
        if _mkh is not None {
            _has_args.append(_mkh);
        }
        has_key = self.builder.call(_has_fn, _has_args, name="match.map.has");
        val_bb = func.append_basic_block(name="match.map.val");
        self.builder.cbranch(has_key, val_bb, merge_bb);
        self.builder.position_at_end(val_bb);
        (_get_fn, _mgh) = self._static_key_op(helpers, "get", _mk_nd);
        _get_args = [subj, key_val];
        if _mgh is not None {
            _get_args.append(_mgh);
        }
        v = self.builder.call(_get_fn, _get_args, name="match.map.get");
        v = self._match_cast_elem(v, val_ty);
        sub_cond = self._match_pattern_cond(kv.value, v, val_ty);
        if sub_cond is None {
            self.builder.branch(merge_bb);
            self.builder.position_at_end(merge_bb);
            return None;
        }
        next_bb = func.append_basic_block(name="match.map.chk");
        self.builder.cbranch(sub_cond, next_bb, merge_bb);
        self.builder.position_at_end(next_bb);
    }
    self.builder.store(ir.Constant(i1, 1), res);
    self.builder.branch(merge_bb);
    self.builder.position_at_end(merge_bb);
    return self.builder.load(res, name="match.map.ok");
}

impl NaIRGenStmt._match_arch_fields(
    pat: uni.MatchArch, arch_name: str
) -> (list | None) {
    out: list = [];
    args = list(pat.arg_patterns) if pat.arg_patterns else [];
    if args {
        order = self.struct_field_order.get(arch_name);
        if order is None or len(args) > len(order) {
            return None;
        }
        for (i, sub_pat) in enumerate(args) {
            out.append((order[i], sub_pat));
        }
    }
    for kv in (list(pat.kw_patterns) if pat.kw_patterns else []) {
        fname = self._get_name(kv.key);
        if fname is None {
            return None;
        }
        out.append((fname, kv.value));
    }
    return out;
}

impl NaIRGenStmt._match_arch_cond(
    pat: uni.MatchArch, subj: ir.Value, subj_ty: (object | None) = None
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    arch_name = self._get_name(pat.name);
    if arch_name is None or arch_name not in self.struct_types {
        self.emit(
            E5092,
            node_override=pat,
            kind="match pattern",
            name="MatchArch",
            help_text="Class patterns lower natively only for archetypes whose native layout is visible to this module, named without dots."
        );
        return None;
    }
    fields = self._match_arch_fields(pat, arch_name);
    if fields is None {
        self.emit(
            E5092,
            node_override=pat,
            kind="match pattern",
            name="MatchArch",
            help_text=f"The class pattern's fields could not be mapped onto the native layout of '{arch_name}' (positional sub-patterns follow declared has-field order)."
        );
        return None;
    }
    static_name = self._struct_ptr_pointee_name(subj);
    if static_name is None
        and subj_ty is not None
        and isinstance(subj.type, ir.PointerType) {
        tk = self._mangled_of(subj_ty);
        cands = [tk] + (tk.split("|") if "|" in tk else []);
        for part in cands {
            if part in self.struct_types {
                subj = self.builder.bitcast(
                    subj, self.struct_types[part].as_pointer(), name="match.arch.subj"
                );
                static_name = part;
                break;
            }
        }
    }
    if static_name is None {
        self.emit(
            E5092,
            node_override=pat,
            kind="match pattern",
            name="MatchArch",
            help_text="The match subject's static type could not be resolved to a native archetype layout. Annotate the subject with a concrete archetype type, or move this code to a @sv/Python context."
        );
        return None;
    }
    vt_mode = False;
    target_vtables: list = [];
    if static_name == arch_name and not self._arch_has_vtable(static_name) {
        vt_mode = False;
    } elif self._arch_has_vtable(static_name) {
        target_vtables = self._vtable_candidates([arch_name]);
        if not target_vtables {
            return ir.Constant(i1, 0);
        }
        vt_mode = True;
    } else {
        return ir.Constant(i1, 0);
    }
    func = self.builder.function;
    res = self._entry_alloca(i1, "match.arch.res");
    self.builder.store(ir.Constant(i1, 0), res);
    merge_bb = func.append_basic_block(name="match.arch.merge");
    null_ptr = ir.Constant(subj.type, None);
    nonnull = self.builder.icmp_unsigned("!=", subj, null_ptr, name="match.arch.nn");
    chk_bb = func.append_basic_block(name="match.arch.chk");
    self.builder.cbranch(nonnull, chk_bb, merge_bb);
    self.builder.position_at_end(chk_bb);
    if vt_mode {
        i8_pp = i8.as_pointer().as_pointer();
        op_as = self.builder.bitcast(subj, i8_pp.as_pointer(), name="match.arch.obj");
        vptr = self.builder.load(op_as, name="match.arch.vptr");
        cmp: (ir.Value | None) = None;
        for vt in target_vtables {
            vt_base = self.builder.gep(
                vt, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="match.arch.vt"
            );
            eq = self.builder.icmp_unsigned("==", vptr, vt_base, name="match.arch.eq");
            cmp = eq
                if cmp is None
                else self.builder.or_(cmp, eq, name="match.arch.or");
        }
        fld_bb = func.append_basic_block(name="match.arch.fld");
        self.builder.cbranch(cmp, fld_bb, merge_bb);
        self.builder.position_at_end(fld_bb);
    }
    for (fname, sub_pat) in fields {
        fv = self._codegen_field_access(subj, fname, arch_name, pat);
        if fv is None {
            self.emit(
                E5092,
                node_override=pat,
                kind="match pattern",
                name="MatchArch",
                help_text=f"'{arch_name}' has no native field '{fname}'."
            );
            self.builder.branch(merge_bb);
            self.builder.position_at_end(merge_bb);
            return None;
        }
        sub_cond = self._match_pattern_cond(sub_pat, fv, None);
        if sub_cond is None {
            self.builder.branch(merge_bb);
            self.builder.position_at_end(merge_bb);
            return None;
        }
        next_bb = func.append_basic_block(name="match.arch.chk");
        self.builder.cbranch(sub_cond, next_bb, merge_bb);
        self.builder.position_at_end(next_bb);
    }
    self.builder.store(ir.Constant(i1, 1), res);
    self.builder.branch(merge_bb);
    self.builder.position_at_end(merge_bb);
    return self.builder.load(res, name="match.arch.ok");
}

impl NaIRGenStmt._match_value_eq(
    subj: ir.Value, value_node: uni.UniNode
) -> (ir.Value | None) {
    _mv = value_node.expr if isinstance(value_node, uni.CfgExpr) else value_node;
    if isinstance(_mv, uni.AtomUnit) {
        _mv = _mv.value;
    }
    if isinstance(_mv, uni.Null)
        and self._opt_payload_of(subj.type) is None
        and not isinstance(subj.type, ir.PointerType)
        and not (bool(self?.jacval_type) and subj.type == self.jacval_type) {
        return ir.Constant(ir.IntType(1), 0);
    }
    pat = self._codegen_expr(value_node);
    if pat is None {
        return None;
    }

    if isinstance(subj.type, ir.IntType)
        and isinstance(pat.type, ir.IntType)
        and subj.type != pat.type {
        pat = self._coerce_type(pat, subj.type);
    }
    is_float = isinstance(subj.type, (ir.DoubleType, ir.FloatType))
        or isinstance(pat.type, (ir.DoubleType, ir.FloatType));
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

impl NaIRGenStmt._bind_match_pattern(
    pat: uni.MatchPattern, subj: ir.Value, subj_ty: (object | None) = None
) -> None {
    if isinstance(pat, uni.MatchAs) {
        cap_name = self._get_name(pat.name) if pat.name else None;
        if cap_name is not None {
            self._bind_match_capture(cap_name, subj);
        }
        if pat.pattern is not None {
            self._bind_match_pattern(pat.pattern, subj, subj_ty);
        }
    } elif isinstance(pat, uni.MatchSequence) {
        self._bind_match_seq(pat, subj, subj_ty);
    } elif isinstance(pat, uni.MatchMapping) {
        self._bind_match_map(pat, subj, subj_ty);
    } elif isinstance(pat, uni.MatchArch) {
        self._bind_match_arch(pat, subj, subj_ty);
    }
}

impl NaIRGenStmt._bind_match_capture(
    cap_name: str, val: ir.Value, owned: bool = False
) -> None {
    alloca = self.local_vars.get(cap_name);
    if alloca is None
        or not isinstance(alloca.type, ir.PointerType)
        or alloca.type.pointee != val.type {
        alloca = self._entry_alloca(val.type, cap_name);
        if isinstance(val.type, ir.PointerType) {
            _func_b = self.builder.function;
            _ebb = _func_b.entry_basic_block;
            _cur_bb = self.builder.block;
            _entry_instrs = list(_ebb.instructions);
            if len(_entry_instrs) >= 2 {
                self.builder.position_before(_entry_instrs[1]);
            } else {
                self.builder.position_at_end(_ebb);
            }
            self.builder.store(ir.Constant(val.type, None), alloca);
            self.builder.position_at_end(_cur_bb);
        }
        self.local_vars[cap_name] = alloca;
    }
    if isinstance(val.type, ir.PointerType) {
        if not owned and not self._is_owned(val) {
            self._emit_rc_retain(val, op="match_bind", loc="");
        }
        old_val = self.builder.load(alloca, name=f"{cap_name}.old");
        self._emit_rc_release_typed(old_val, op="match_bind", loc="");
    }
    self.builder.store(val, alloca);
}

impl NaIRGenStmt._bind_match_seq(
    pat: uni.MatchSequence, subj: ir.Value, subj_ty: (object | None) = None
) -> None {
    i64 = ir.IntType(64);
    (heads, star, tails) = self._match_seq_parts(pat);
    spec = self._infer_list_elem_type(subj);
    if spec is None {
        if isinstance(subj.type, ir.PointerType)
            and isinstance(subj.type.pointee, ir.LiteralStructType)
            and star is None
            and len(subj.type.pointee.elements) == len(heads) {
            loaded = self.builder.load(subj, name="match.tup");
            for (i, sub_pat) in enumerate(heads) {
                elem = self.builder.extract_value(loaded, i, name="match.tup.elem");
                elem_ty = self._match_elem_ty_of(subj_ty, "tuple[", i);
                elem = self._match_cast_elem(elem, elem_ty);
                self._bind_match_pattern(sub_pat, elem, elem_ty);
            }
        }
        return;
    }
    helpers = self.list_helpers[spec];
    elem_ty = self._match_elem_ty_of(subj_ty, "list[", 0);
    len_val = self.builder.call(helpers["len"], [subj], name="match.seq.blen");
    n_tails = len(tails);
    for (i, sub_pat) in enumerate(heads) {
        elem = self.builder.call(
            helpers["get"], [subj, ir.Constant(i64, i)], name="match.seq.belem"
        );
        elem = self._match_cast_elem(elem, elem_ty);
        self._bind_match_pattern(sub_pat, elem, elem_ty);
    }
    for (j, sub_pat) in enumerate(tails) {
        idx = self.builder.sub(
            len_val, ir.Constant(i64, n_tails - j), name="match.seq.btidx"
        );
        elem = self.builder.call(helpers["get"], [subj, idx], name="match.seq.belem");
        elem = self._match_cast_elem(elem, elem_ty);
        self._bind_match_pattern(sub_pat, elem, elem_ty);
    }
    star_name = self._get_name(star.name) if star is not None else None;
    if star is None or star_name is None or star_name == "_" {
        return;
    }
    _loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{star.loc.first_line
        if star.loc
        else 0}";
    rest = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_loc, name="match.star"
    );
    self._mark_owned(rest);
    func = self.builder.function;
    idx_alloca = self._entry_alloca(i64, "match.star.i");
    self.builder.store(ir.Constant(i64, len(heads)), idx_alloca);
    end_idx = self.builder.sub(
        len_val, ir.Constant(i64, n_tails), name="match.star.end"
    );
    cond_bb = func.append_basic_block(name="match.star.cond");
    body_bb = func.append_basic_block(name="match.star.body");
    done_bb = func.append_basic_block(name="match.star.done");
    self.builder.branch(cond_bb);
    self.builder.position_at_end(cond_bb);
    cur = self.builder.load(idx_alloca, name="match.star.cur");
    cont = self.builder.icmp_signed("<", cur, end_idx, name="match.star.lt");
    self.builder.cbranch(cont, body_bb, done_bb);
    self.builder.position_at_end(body_bb);
    elem = self.builder.call(helpers["get"], [subj, cur], name="match.star.elem");
    self.builder.call(helpers["append"], [rest, elem]);
    nxt = self.builder.add(cur, ir.Constant(i64, 1), name="match.star.nxt");
    self.builder.store(nxt, idx_alloca);
    self.builder.branch(cond_bb);
    self.builder.position_at_end(done_bb);
    self._bind_match_capture(star_name, rest, owned=True);
}

impl NaIRGenStmt._bind_match_map(
    pat: uni.MatchMapping, subj: ir.Value, subj_ty: (object | None) = None
) -> None {
    i64 = ir.IntType(64);
    dict_info = self._infer_dict_type(subj);
    if dict_info is None {
        return;
    }
    (kspec, vspec) = dict_info;
    helpers = self.dict_helpers[f"{kspec}:{vspec}"];
    val_ty = self._match_elem_ty_of(subj_ty, "dict[", 1);
    star: (uni.MatchStar | None) = None;
    matched_keys: list = [];
    for kv in pat.values {
        if isinstance(kv, uni.MatchStar) {
            star = kv;
            continue;
        }
        key_val = self._match_map_key(kv, helpers);
        if key_val is None {
            continue;
        }
        matched_keys.append(key_val);
        _mk_nd = kv.key.value if isinstance(kv.key, uni.MatchValue) else kv.key;
        (_get_fn, _mgh) = self._static_key_op(helpers, "get", _mk_nd);
        _get_args = [subj, key_val];
        if _mgh is not None {
            _get_args.append(_mgh);
        }
        v = self.builder.call(_get_fn, _get_args, name="match.map.bget");
        v = self._match_cast_elem(v, val_ty);
        self._bind_match_pattern(kv.value, v, val_ty);
    }
    star_name = self._get_name(star.name) if star is not None else None;
    if star is None or star_name is None or star_name == "_" {
        return;
    }
    _loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{star.loc.first_line
        if star.loc
        else 0}";
    rest = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_loc, name="match.map.rest"
    );
    self._mark_owned(rest);
    func = self.builder.function;
    idx_alloca = self._entry_alloca(i64, "match.map.rest.i");
    self.builder.store(ir.Constant(i64, 0), idx_alloca);
    len_val = self.builder.call(helpers["len"], [subj], name="match.map.blen");
    cond_bb = func.append_basic_block(name="match.rest.cond");
    body_bb = func.append_basic_block(name="match.rest.body");
    copy_bb = func.append_basic_block(name="match.rest.copy");
    incr_bb = func.append_basic_block(name="match.rest.incr");
    done_bb = func.append_basic_block(name="match.rest.done");
    self.builder.branch(cond_bb);
    self.builder.position_at_end(cond_bb);
    cur = self.builder.load(idx_alloca, name="match.rest.cur");
    cont = self.builder.icmp_signed("<", cur, len_val, name="match.rest.lt");
    self.builder.cbranch(cont, body_bb, done_bb);
    self.builder.position_at_end(body_bb);
    k = self.builder.call(helpers["get_key"], [subj, cur], name="match.rest.k");
    skip_cond: (ir.Value | None) = None;
    for mk in matched_keys {
        eqk = self._emit_key_comparison(self.builder, helpers["key_type"], k, mk);
        skip_cond = eqk
            if skip_cond is None
            else self.builder.or_(skip_cond, eqk, name="match.rest.skip");
    }
    if skip_cond is None {
        self.builder.branch(copy_bb);
    } else {
        self.builder.cbranch(skip_cond, incr_bb, copy_bb);
    }
    self.builder.position_at_end(copy_bb);
    v2 = self.builder.call(helpers["get_val"], [subj, cur], name="match.rest.v");
    self.builder.call(helpers["set"], [rest, k, v2]);
    self.builder.branch(incr_bb);
    self.builder.position_at_end(incr_bb);
    nxt = self.builder.add(cur, ir.Constant(i64, 1), name="match.rest.nxt");
    self.builder.store(nxt, idx_alloca);
    self.builder.branch(cond_bb);
    self.builder.position_at_end(done_bb);
    self._bind_match_capture(star_name, rest, owned=True);
}

impl NaIRGenStmt._bind_match_arch(
    pat: uni.MatchArch, subj: ir.Value, subj_ty: (object | None) = None
) -> None {
    arch_name = self._get_name(pat.name);
    if arch_name is None or arch_name not in self.struct_types {
        return;
    }
    fields = self._match_arch_fields(pat, arch_name);
    if fields is None {
        return;
    }
    for (fname, sub_pat) in fields {
        fv = self._codegen_field_access(subj, fname, arch_name, pat);
        if fv is not None {
            self._bind_match_pattern(sub_pat, fv, None);
        }
    }
}

impl NaIRGenStmt._apply_scalar_aug_op(
    current: ir.Value,
    rhs: ir.Value,
    aug_op: str,
    rhs_node: (uni.Expr | None) = None,
    unsigned: bool = False,
    checked: bool = False
) -> (ir.Value | None) {
    current = self._str_norm(current);
    rhs = self._str_norm(rhs);
    if not isinstance(current.type, (ir.IntType, ir.DoubleType, ir.FloatType)) {
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
    if aug_op == "**=" {
        return self._codegen_pow(
            current, rhs, rhs_node, unsigned=unsigned, checked=checked
        );
    }
    coerced = self._coerce_type(rhs, current.type);
    result = self._emit_binary_op(
        op_toks[aug_op], current, coerced, unsigned=unsigned, checked=checked
    );
    if result is not None and result.type != current.type {
        result = self._coerce_type(result, current.type);
    }
    return result;
}

impl NaIRGenStmt._codegen_assignment(nd: uni.Assignment) -> None {
    _rhs_errs_before = len(self.errors_had);
    if self._lower_partition_unpack(nd) {
        return;
    }
    value: (ir.Value | None) = None;
    if (
        isinstance(nd.value, uni.Name)
        and nd.value.value in self.generic_fns
        and nd.type_tag is not None
        and nd.type_tag.tag is not None
    ) {
        value = self._instantiate_generic_for_target(nd.value.value, nd.type_tag.tag);
    }
    if value is None
        and nd.type_tag is not None
        and isinstance(nd.value, uni.ListVal)
        and not (nd.value.values or []) {
        _aos_t = self._aos_elem_of(nd.type_tag);
        if _aos_t is not None {
            self._emit_aos_list_helpers(_aos_t);
            value = self.builder.call(
                self.list_helpers[f"aos.{_aos_t}"]["new"], [], name="aos.new"
            );
            self._mark_owned(value);
        }
    }
    if value is None {
        value = self._codegen_expr(nd.value) if nd.value else None;
    }

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
                            self._nogc_stamp_elem_drops(
                                value, self._nogc_type_arg_mangles(_set_t0)
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
        if nd.value is not None
            and len(self.errors_had) == _rhs_errs_before
            and not self._reads_unlowered_local(nd.value) {
            self.emit(
                E5092,
                node_override=nd.value,
                kind="expression",
                name=type(nd.value).__name__
            );
        }

        _unbound: list = list(nd.target)
            if isinstance(nd.target, (list, tuple))
            else [nd.target];
        while _unbound {
            _t = _unbound.pop();
            if isinstance(_t, uni.Name) {
                self._mark_local_unlowered(_t.value);
            } elif isinstance(_t, uni.TupleVal) {
                _unbound.extend(_t.values or []);
            }
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
                    target_expr, value, nd.aug_op.value, nd.value
                );
                if field_val is not None {
                    self._codegen_field_assign(
                        target_expr,
                        field_val,
                        skip_narrow_coerce=(nd.aug_op.value == "**=")
                    );
                } elif len(self.errors_had) == _faug_errs {
                    self.emit(
                        E5092,
                        node_override=target_expr,
                        kind="augmented field assignment",
                        name=(self._get_name(target_expr.right) or "<field>")
                    );
                }
            } else {
                self._codegen_field_assign(target_expr, value, value_node=nd.value);
            }
            continue;
        }

        if isinstance(target_expr, uni.AtomTrailer) and not target_expr.is_attr {
            _env_sub_t = target_expr.target;
            if (
                isinstance(_env_sub_t, uni.AtomTrailer)
                and _env_sub_t.is_attr
                and self._get_name(_env_sub_t.target) == "os"
                and self._get_name(_env_sub_t.right) == "environ"
                and self?._native_stdlib_modules
                and "os" in self._native_stdlib_modules
                and nd.aug_op is None
                and target_expr.right?.slices
            ) {
                _env_slices = target_expr.right.slices or [];
                _env_key: (ir.Value | None) = None;
                if _env_slices {
                    _env_key = self._codegen_expr(_env_slices[0]);
                    if _env_key is None and _env_slices[0]?.start {
                        _env_key = self._codegen_expr(_env_slices[0].start);
                    }
                }
                _env_val_is_str = isinstance(value.type, ir.PointerType)
                    or (
                        self._str_desc_ty is not None
                        and value.type == self._str_desc_ty
                    );
                if _env_key is not None and _env_val_is_str {
                    _i8p_env = ir.IntType(8).as_pointer();
                    _setenv_fn = self._get_or_declare_extern(
                        "setenv", ir.IntType(32), [_i8p_env, _i8p_env, ir.IntType(32)]
                    );
                    self.builder.call(
                        _setenv_fn,
                        [
                            self._coerce_type(_env_key, _i8p_env),
                            self._coerce_type(value, _i8p_env),
                            ir.Constant(ir.IntType(32), 1)
                        ],
                        name="environ.setitem"
                    );
                    continue;
                }
            }
            _idx_errs_before = len(self.errors_had);
            _idx_stored = False;
            idx_target_name = self._get_name(target_expr.target);
            target_val = self._codegen_expr(target_expr.target);
            if (
                target_val is not None
                and nd.aug_op is None
                and "u8" in self.list_types
                and target_val.type == self.list_types["u8"].as_pointer()
                and target_expr.right?.is_range
                and target_expr.right?.slices
            ) {
                _ba_sl = target_expr.right.slices[0];
                _ba_start = (
                    self._codegen_expr(_ba_sl.start)
                        if _ba_sl?.start is not None
                        else ir.Constant(ir.IntType(64), 0)
                );
                _ba_stop = (
                    self._codegen_expr(_ba_sl.stop)
                        if _ba_sl?.stop is not None
                        else ir.Constant(ir.IntType(64), 9223372036854775807)
                );
                _ba_src = self._bytearray_src_of(value);
                if _ba_start is not None
                    and _ba_stop is not None
                    and _ba_src is not None {
                    _ba_fns = self._bytearray_runtime_fns();
                    _i64_ba = ir.IntType(64);
                    self.builder.call(
                        _ba_fns["setslice"],
                        [
                            target_val,
                            self._coerce_type(_ba_start, _i64_ba),
                            self._coerce_type(_ba_stop, _i64_ba),
                            _ba_src[0],
                            _ba_src[1]
                        ],
                        name=""
                    );
                    if self._is_owned(value) {
                        self._emit_rc_release_simple(value, op="ba_setslice", loc="");
                    }
                    continue;
                }
            }
            if target_val is not None and target_expr.right?.slices {
                slices = target_expr.right.slices or [];
                if slices {
                    idx_node = slices[0];
                    idx_val = self._codegen_expr(idx_node);
                    if idx_val is None and idx_node?.start {
                        idx_val = self._codegen_expr(idx_node.start);
                    }
                    if idx_val is not None {
                        dict_type_key = self._dict_key_reconcile(
                            self._dict_key_of(target_expr.target), target_val
                        );
                        if dict_type_key is not None {
                            parts = dict_type_key.split(":");
                            if len(parts) == 2 {
                                _dk_nd = idx_node.start
                                    if idx_node?.start
                                    else idx_node;
                                store_val: (ir.Value | None) = value;
                                if nd.aug_op is not None {
                                    cur_elem = self._codegen_dict_access(
                                        target_val,
                                        idx_val,
                                        parts[0],
                                        parts[1],
                                        key_node=_dk_nd
                                    );
                                    store_val = None;
                                    if cur_elem is not None {
                                        store_val = self._apply_scalar_aug_op(
                                            cur_elem,
                                            value,
                                            nd.aug_op.value,
                                            nd.value,
                                            checked=self._is_sized_node(nd.target)
                                                or self._is_sized_node(nd.value)
                                        );
                                    }
                                }
                                if store_val is not None {
                                    store_val = self._nogc_elem_prep(
                                        nd.value, store_val
                                    );
                                    self._codegen_dict_set(
                                        target_val,
                                        idx_val,
                                        store_val,
                                        parts[0],
                                        parts[1],
                                        key_node=_dk_nd
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
                                            cur_elem,
                                            value,
                                            nd.aug_op.value,
                                            nd.value,
                                            checked=self._is_sized_node(nd.target)
                                                or self._is_sized_node(nd.value)
                                        );
                                    }
                                }
                                if store_val is not None {
                                    store_val = self._nogc_elem_prep(
                                        nd.value, store_val
                                    );
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
                current = self._str_norm(
                    self.builder.load(alloca, name=f"{var_name}.cur")
                );
                value = self._str_norm(value);
                _scalar_aug: (ir.Value | None) = None;
                if isinstance(current.type, (ir.IntType, ir.FloatType, ir.DoubleType))
                    and isinstance(
                        value.type, (ir.IntType, ir.FloatType, ir.DoubleType)
                    )
                    and aug_op_val != "**=" {
                    _scalar_aug = self._apply_scalar_aug_op(
                        current,
                        value,
                        aug_op_val,
                        nd.value,
                        unsigned=self._is_unsigned_node(target_expr),
                        checked=self._is_sized_node(target_expr)
                            or self._is_sized_node(nd.value)
                    );
                }
                coerced = self._coerce_type(value, current.type);
                if _scalar_aug is not None {
                    value = _scalar_aug;
                } elif aug_op_val == "+=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.add(
                            current, coerced, name=f"{var_name}.add"
                        );
                    } elif isinstance(current.type, ir.DoubleType) {
                        value = self.builder.fadd(
                            current, coerced, name=f"{var_name}.fadd"
                        );
                    } elif (
                        isinstance(current.type, ir.PointerType)
                        and "u8" in self.list_types
                        and current.type == self.list_types["u8"].as_pointer()
                    ) {
                        _ba_aug_src = self._bytearray_src_of(value);
                        if _ba_aug_src is not None {
                            _ba_aug_fns = self._bytearray_runtime_fns();
                            self.builder.call(
                                _ba_aug_fns["extend_raw"],
                                [current, _ba_aug_src[0], _ba_aug_src[1]],
                                name=""
                            );
                            if self._is_owned(value) {
                                self._emit_rc_release_simple(
                                    value, op="ba_aug", loc=""
                                );
                            }
                        }
                        value = current;
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
                        (q, _) = self._codegen_int_floor_divmod(current, coerced);
                        value = q;
                    } else {
                        fzero = ir.Constant(ir.DoubleType(), 0.0);
                        is_zero = self.builder.fcmp_ordered(
                            "==", coerced, fzero, name=f"{var_name}.fdiv.zero.chk"
                        );
                        self._emit_runtime_raise(
                            is_zero, "ZeroDivisionError", "float division by zero"
                        );
                        value = self._codegen_float_floor_div(current, coerced);
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
                        (_, r) = self._codegen_int_floor_divmod(current, coerced);
                        value = r;
                    } else {
                        fzero = ir.Constant(ir.DoubleType(), 0.0);
                        is_zero = self.builder.fcmp_ordered(
                            "==", coerced, fzero, name=f"{var_name}.fmod.zero.chk"
                        );
                        self._emit_runtime_raise(
                            is_zero, "ZeroDivisionError", "float modulo by zero"
                        );
                        value = self._codegen_float_floor_mod(current, coerced);
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
                        dict_type_key = self._dict_key_reconcile(
                            self._dict_key_of(target_expr), current
                        );
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

                                    rhs_cast = self.builder.bitcast(
                                        rhs_set,
                                        self.set_types[set_elem_name].as_pointer(),
                                        name="rhs.set.cast"
                                    );
                                    rhs_len = self.builder.call(
                                        shelpers["len"], [rhs_cast], name="rhs.len"
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
                                    elem_val = self.builder.call(
                                        shelpers["get"],
                                        [rhs_cast, elem_i],
                                        name="union.elem.val"
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
                    pow_res = self._apply_scalar_aug_op(
                        current,
                        value,
                        "**=",
                        nd.value,
                        unsigned=self._is_unsigned_node(target_expr),
                        checked=self._is_sized_node(target_expr)
                            or self._is_sized_node(nd.value)
                    );
                    if pow_res is not None {
                        value = pow_res;
                    }
                }
            }
            if nd.aug_op is not None
                and nd.aug_op.value == "**="
                and value.type != alloca.type.pointee {
                coerced = value;
            } else {
                coerced = self._coerce_type(value, alloca.type.pointee);
            }

            _is_raw_int_ptr = getattr(coerced, 'opname', '') == 'inttoptr';
            self._register_region_handle_var(nd, var_name);
            if isinstance(alloca.type.pointee, ir.PointerType)
                and not is_inplace_set_op {
                if var_name in self.region_handle_vars {
                    _old_hdl = self.builder.load(alloca, name=f"{var_name}.old");
                    self.builder.call(
                        self._region_kernel_fn("__jac_region_drop"),
                        [self._region_i64(_old_hdl, name=f"{var_name}.old.i64")]
                    );
                } elif _is_raw_int_ptr {
                    self.param_vars.add(var_name);
                } else {
                    if self._nogc_headerless()
                        and isinstance(nd.value, uni.Name)
                        and nd.value.sym is not None
                        and nd.value.sym.storage == uni.SymbolStorage.MODULE_GLOBAL {
                        self.nogc_no_free_vars.add(var_name);
                    }
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
                    )
                        and not (
                            self._gc_mode() == "none"
                            and var_name in self.nogc_no_free_vars
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
                self._str_desc_ty is not None
                and alloca.type.pointee == self._str_desc_ty
                and not is_inplace_set_op
                and not _is_raw_int_ptr
            ) {
                import from jaclang.compiler.frontend.constant { OwnershipKind }
                _own_str_re = (
                    self._nogc_headerless()
                    and len(nd.target) == 1
                    and isinstance(nd.target[0], uni.Name)
                    and nd.target[0].sym is not None
                    and nd.target[0].sym.ownership == OwnershipKind.OWN
                );
                _re_moved = False;
                if not self._is_owned(value) {
                    _re_moved = self._can_native_move_lower(nd);
                }
                if _own_str_re {
                    self.nogc_owned_str_vars.add(var_name);
                    if not self._is_owned(value) and not _re_moved {
                        if self.str_new_fn is None {
                            self._emit_str_len_helpers();
                        }
                        _osr_data = self.builder.extract_value(
                            coerced, 0, name="own.re.data"
                        );
                        _osr_len = self.builder.extract_value(
                            coerced, 1, name="own.re.len"
                        );
                        _osr_new = self.builder.call(
                            self.str_new_fn, [_osr_data, _osr_len], name="own.re.copy"
                        );
                        coerced = self.builder.insert_value(
                            self.builder.insert_value(
                                ir.Constant(alloca.type.pointee, None),
                                _osr_new,
                                0,
                                name="own.re.d0"
                            ),
                            _osr_len,
                            1,
                            name="own.re.d1"
                        );
                    }
                    if not (
                        self._nogc_headerless()
                        and getattr(nd, 'na_overwrite_consumed', False)
                    )
                        and var_name not in self.nogc_no_free_vars {
                        _osr_old = self.builder.load(alloca, name=f"{var_name}.old");
                        self._nogc_str_free_owned(_osr_old);
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
            } elif var_name in self.region_handle_vars
                and self._opt_ptr_payload_of(alloca.type.pointee) is not None {
                _old_opt_hdl = self.builder.load(alloca, name=f"{var_name}.old");
                self.builder.call(
                    self._region_kernel_fn("__jac_region_drop"),
                    [self._region_i64(_old_opt_hdl, name=f"{var_name}.old.i64")]
                );
            } elif self._opt_ptr_payload_of(alloca.type.pointee) is not None
                and not self._nogc_headerless()
                and not is_inplace_set_op
                and not _is_raw_int_ptr {
                _opt_re_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                    if nd.loc
                    else 0}";
                _opt_re_owned = self._opt_result_owned(value, nd.value);
                if not _opt_re_owned and not self._can_native_move_lower(nd) {
                    _opt_re_pv = self.builder.extract_value(
                        coerced, 1, name=f"{var_name}.opt.newpv"
                    );
                    self._emit_rc_retain(_opt_re_pv, op="assign", loc=_opt_re_loc);
                } else {
                    self.rc_ops_elided += 1;
                }
                _opt_re_old = self.builder.load(alloca, name=f"{var_name}.opt.old");
                _opt_re_old_pv = self.builder.extract_value(
                    _opt_re_old, 1, name=f"{var_name}.opt.oldpv"
                );
                self._emit_rc_release_simple(
                    _opt_re_old_pv, op="overwrite", loc=_opt_re_loc
                );
            }
            self.builder.store(coerced, alloca);
        } elif var_name in self.global_vars
            and isinstance(target_expr, uni.NameAtom)
            and target_expr.sym is not None
            and target_expr.sym.storage == uni.SymbolStorage.MODULE_GLOBAL {
            global_var = self.global_vars[var_name];
            if nd.aug_op is not None {
                aug_op_val = nd.aug_op.value;
                current = self._str_norm(
                    self.builder.load(global_var, name=f"glob.{var_name}.cur")
                );
                value = self._str_norm(value);
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
            if (
                isinstance(global_var.type.pointee, ir.PointerType)
                or (
                    self._str_desc_ty is not None
                    and global_var.type.pointee == self._str_desc_ty
                )
            )
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
                import from jaclang.compiler.frontend.constant { OwnershipKind }
                _own_str_glob = (
                    self._nogc_headerless()
                    and self._str_desc_ty is not None
                    and global_var.type.pointee == self._str_desc_ty
                    and len(nd.target) == 1
                    and isinstance(nd.target[0], uni.Name)
                    and nd.target[0].sym is not None
                    and nd.target[0].sym.ownership == OwnershipKind.OWN
                );
                if _own_str_glob and not self._is_owned(value) {
                    if self.str_new_fn is None {
                        self._emit_str_len_helpers();
                    }
                    _osg_data = self.builder.extract_value(
                        coerced, 0, name="own.glit.data"
                    );
                    _osg_len = self.builder.extract_value(
                        coerced, 1, name="own.glit.len"
                    );
                    _osg_new = self.builder.call(
                        self.str_new_fn, [_osg_data, _osg_len], name="own.glit.copy"
                    );
                    coerced = self.builder.insert_value(
                        self.builder.insert_value(
                            ir.Constant(global_var.type.pointee, None),
                            _osg_new,
                            0,
                            name="own.glit.d0"
                        ),
                        _osg_len,
                        1,
                        name="own.glit.d1"
                    );
                }
                old_glob = self.builder.load(global_var, name=f"glob.{var_name}.old");
                if _own_str_glob {
                    self._nogc_str_free_owned(old_glob);
                }
                if not self._nogc_headerless() {
                    self._emit_rc_release_typed(
                        old_glob,
                        op="overwrite",
                        loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                            if nd.loc
                            else 0}"
                    );
                }
            }
            self.builder.store(coerced, global_var);
            if self._nogc_headerless()
                and isinstance(nd.value, uni.Name)
                and nd.value.sym_name in self.local_vars
                and nd.value.sym_name not in self.param_vars {
                _gxfer_slot = self.local_vars[nd.value.sym_name];
                if isinstance(_gxfer_slot.type, ir.PointerType)
                    and isinstance(_gxfer_slot.type.pointee, ir.PointerType) {
                    self.builder.store(
                        ir.Constant(_gxfer_slot.type.pointee, None), _gxfer_slot
                    );
                }
            }
        } else {
            var_type = value.type;
            _pre_box_val = value;
            if (
                (not nd.type_tag or not nd.type_tag.tag)
                and isinstance(value.type, ir.PointerType)
                and self._closure_struct_of(value.type) is None
                and isinstance(nd.value, uni.Expr)
                and nd.value.type is not None
            ) {
                try {
                    _clos_hint = self._lower_type(nd.value.type);
                } except Exception {
                    _clos_hint = None;
                }
                if _clos_hint is not None
                    and self._closure_struct_of(_clos_hint) is not None {
                    value = self._coerce_type(value, _clos_hint);
                    var_type = _clos_hint;
                    _pre_box_val = value;
                }
            }
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
            _mk_cell = (
                var_name in self.closure_cell_vars
                and var_name not in self.closure_cell_handles
            );
            if _mk_cell {
                alloca = self._emit_closure_cell(var_name, var_type);
            } else {
                alloca = self._entry_alloca(var_type, var_name);
            }
            _in_gen_frame = (
                self._gen_ctx is not None
                and self.builder.function is self._gen_ctx["resume_fn"]
            );
            if (
                isinstance(var_type, ir.PointerType)
                or (self._str_desc_ty is not None and var_type == self._str_desc_ty)
                or self._opt_ptr_payload_of(var_type) is not None
            )
                and not _mk_cell
                and not _in_gen_frame {
                _func_e = self.builder.function;
                _ebb = _func_e.entry_basic_block;
                _cur_bb = self.builder.block;
                _entry_instrs = list(_ebb.instructions);
                _anchor_idx: (int | None) = None;
                for (_ei, _einstr) in enumerate(_entry_instrs) {
                    if _einstr is alloca {
                        _anchor_idx = _ei;
                        break;
                    }
                }
                if _anchor_idx is not None and _anchor_idx + 1 < len(_entry_instrs) {
                    self.builder.position_before(_entry_instrs[_anchor_idx + 1]);
                } else {
                    self.builder.position_at_end(_ebb);
                }
                self.builder.store(ir.Constant(var_type, None), alloca);
                self.builder.position_at_end(_cur_bb);
            }
            self._register_region_handle_var(nd, var_name);
            if var_name in self.region_handle_vars {} elif isinstance(
                var_type, ir.PointerType
            )
                or (self._str_desc_ty is not None and var_type == self._str_desc_ty) {
                if getattr(value, 'opname', '') == 'inttoptr' {
                    self.param_vars.add(var_name);
                } else {
                    import from jaclang.compiler.frontend.constant { OwnershipKind }
                    _own_str_tgt = (
                        self._nogc_headerless()
                        and self._str_desc_ty is not None
                        and var_type == self._str_desc_ty
                        and not _mk_cell
                        and not _in_gen_frame
                        and len(nd.target) == 1
                        and isinstance(nd.target[0], uni.Name)
                        and nd.target[0].sym is not None
                        and nd.target[0].sym.ownership == OwnershipKind.OWN
                    );
                    if self._nogc_headerless()
                        and isinstance(nd.value, uni.Name)
                        and nd.value.sym is not None
                        and nd.value.sym.storage == uni.SymbolStorage.MODULE_GLOBAL {
                        self.nogc_no_free_vars.add(var_name);
                    }
                    _moved_here = False;
                    if not self._is_owned(value) {
                        _moved_here = self._can_native_move_lower(nd);
                        if not _moved_here {
                            self._emit_rc_retain(
                                value,
                                op="assign",
                                loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                                    if nd.loc
                                    else 0}"
                            );
                        }
                    } else {
                        self.rc_ops_elided += 1;
                    }
                    if _own_str_tgt {
                        self.nogc_owned_str_vars.add(var_name);
                        if not self._is_owned(value) and not _moved_here {
                            if self.str_new_fn is None {
                                self._emit_str_len_helpers();
                            }
                            _osf_data = self.builder.extract_value(
                                value, 0, name="own.lit.data"
                            );
                            _osf_len = self.builder.extract_value(
                                value, 1, name="own.lit.len"
                            );
                            _osf_new = self.builder.call(
                                self.str_new_fn,
                                [_osf_data, _osf_len],
                                name="own.lit.copy"
                            );
                            value = self.builder.insert_value(
                                self.builder.insert_value(
                                    ir.Constant(var_type, None),
                                    _osf_new,
                                    0,
                                    name="own.lit.d0"
                                ),
                                _osf_len,
                                1,
                                name="own.lit.d1"
                            );
                        }
                    }
                    if not (
                        self._nogc_headerless()
                        and getattr(nd, 'na_overwrite_consumed', False)
                    )
                        and not (
                            self._gc_mode() == "none"
                            and var_name in self.nogc_no_free_vars
                        ) {
                        old_val = self.builder.load(alloca, name=f"{var_name}.old");
                        if _own_str_tgt {
                            self._nogc_str_free_owned(old_val);
                        }
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
            } elif self._opt_ptr_payload_of(var_type) is not None
                and not self._nogc_headerless() {
                _opt_asg_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                    if nd.loc
                    else 0}";
                if not self._opt_result_owned(value, nd.value)
                    and not self._can_native_move_lower(nd) {
                    _opt_new_pv = self.builder.extract_value(
                        value, 1, name=f"{var_name}.opt.newpv"
                    );
                    self._emit_rc_retain(_opt_new_pv, op="assign", loc=_opt_asg_loc);
                } else {
                    self.rc_ops_elided += 1;
                }
                if not _mk_cell and not _in_gen_frame {
                    _opt_old = self.builder.load(alloca, name=f"{var_name}.opt.old");
                    _opt_old_pv = self.builder.extract_value(
                        _opt_old, 1, name=f"{var_name}.opt.oldpv"
                    );
                    self._emit_rc_release_simple(
                        _opt_old_pv, op="overwrite", loc=_opt_asg_loc
                    );
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

impl NaIRGenStmt._codegen_ctrl(nd: uni.CtrlStmt) -> None {
    ctrl_name = nd.ctrl.name if isinstance(nd.ctrl, uni.Token) else str(nd.ctrl);

    if ctrl_name == Tok.KW_SKIP {
        if isinstance(self.builder.function.function_type.return_type, ir.VoidType) {
            self._emit_region_leaves(len(self.region_open_stack));
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
    _loop_depth = len(self.loop_stack);
    self._emit_region_leaves(
        len(
            [
                _d
                for _d in self.region_open_stack
                if _d >= _loop_depth
            ]
        )
    );
    if ctrl_name == Tok.KW_BREAK {
        self.builder.branch(break_bb);
    } elif ctrl_name == Tok.KW_CONTINUE {
        self.builder.branch(continue_bb);
    }
}

impl NaIRGenStmt._codegen_for(nd: uni.InForStmt) -> None {
    if nd.is_comptime {
        (ok, items) = self._ct_value_with_bindings(nd.collection);
        if not ok {
            self.emit(
                E5092,
                node_override=nd.collection,
                kind="comptime for collection",
                name="comptime for",
                help_text="The collection depends on a comptime parameter or loop variable that has no binding in this specialization."
            );
            return;
        }
        saved_ct = self._ct_bindings;
        self._ct_bindings = dict(saved_ct);
        try {
            for item in items {
                self._bind_ct_target(nd.target, item);
                if isinstance(nd.body, (list, tuple)) {
                    self._codegen_body(nd.body);
                }
                if self.builder.block.is_terminated {
                    break;
                }
            }
        } finally {
            self._ct_bindings = saved_ct;
        }
        if isinstance(nd.else_body, uni.ElseStmt)
            and isinstance(nd.else_body.body, (list, tuple))
            and not self.builder.block.is_terminated {
            self._codegen_body(nd.else_body.body);
        }
        return;
    }
    if self._try_iter_protocol_for(nd) {
        return;
    }
    if self._try_flow_for_parallel(nd) {
        return;
    }
    if self._try_chunked_for(nd) {
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
        unpack_targets = nd.target.values or [];
        if items_dict_key is not None and len(unpack_targets) == 2 {
            key_var_name = self._get_name(unpack_targets[0]);
            val_var_name = self._get_name(unpack_targets[1]);
            if key_var_name is not None and val_var_name is not None {
                collection_val = self._codegen_expr(nd.collection.target.target);
                items_dict_key = self._dict_key_reconcile(
                    items_dict_key, collection_val
                );
                helpers = self.dict_helpers.get(items_dict_key)
                    if items_dict_key is not None
                    else None;
                if collection_val is not None and helpers is not None {
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
    _coll_memo: (ir.Value | None) = self._opt_unwrap_iterable(
        self._str_norm(self._codegen_expr(nd.collection))
    );

    dict_type_key: (str | None) = self._dict_key_of(nd.collection);
    if _coll_memo is not None {
        dict_type_key = self._dict_key_reconcile(dict_type_key, _coll_memo);
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

    if self._tuple_iter_shape(nd.collection, _coll_memo) {
        _tup_seq = self._tuple_iter_seq(nd.collection, _coll_memo);
        if _tup_seq is None {
            if len(self.errors_had) == _for_errs0 {
                self.emit(
                    E5092,
                    node_override=nd.collection or nd,
                    kind="for-loop iterable",
                    name="tuple with mixed element storage",
                    help_text="Every element of an iterated tuple must share one storage width, because the loop variable is a single slot and the checker types it from the tuple's FIRST element -- boxing the elements instead would answer `isinstance` in the body against the wrong member. Use a list literal, whose element type widens to a union, or bind the elements individually."
                );
            }
            return;
        }
        (_ts_val, _ts_spec, _ts_elem, _ts_cast) = _tup_seq;
        self._codegen_for_indexed(
            nd,
            kind="list",
            collection_val=_ts_val,
            helpers=self.list_helpers[_ts_spec],
            var_names=[loop_var_name],
            var_types=[_ts_elem],
            rc_vars=True,
            coll_release_op="fort_coll",
            elem_cast=_ts_cast,
            unpack_target=_unpack_target
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

    _set_src = self._container_src_info(_coll_memo);
    if _set_src is not None and _set_src["kind"] == "set" {
        _set_helpers = _set_src["helpers"];
        _set_elem = _set_helpers["elem_type"];
        _set_cast: (ir.Type | None) = None;
        if _set_src["spec"] == "ptr" {
            _set_static = self._static_elem_llvm_of(nd.collection);
            if _set_static is not None and isinstance(_set_static, ir.PointerType) {
                _set_elem = _set_static;
                _set_cast = _set_static;
            }
        }
        self._codegen_for_indexed(
            nd,
            kind="set",
            collection_val=_coll_memo,
            helpers=_set_helpers,
            var_names=[loop_var_name],
            var_types=[_set_elem],
            rc_vars=True,
            coll_release_op="forset_coll",
            elem_cast=_set_cast,
            unpack_target=_unpack_target
        );
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

impl NaIRGenStmt._try_flow_for_parallel(nd: uni.InForStmt) -> bool {
    import from jaclang.compiler.frontend.constant { Tokens as Tok }
    _is_flow = False;
    for k in nd.kid {
        if isinstance(k, uni.Token) and k.name == Tok.KW_FLOW {
            _is_flow = True;
            break;
        }
    }
    if not _is_flow {
        return False;
    }
    _par_ok = (self.ir_in.gen.nogc_enforced and self._gc_mode() == "none")
        or (self._gc_mode() == "rc" and not self._rc_debug_codegen);
    if not _par_ok {
        return False;
    }
    if "wasm" in str(self.llvm_module.triple) {
        return False;
    }
    if self._gen_ctx is not None {
        return False;
    }
    if isinstance(nd.target, uni.TupleVal) {
        return False;
    }
    loop_var = self._get_name(nd.target);
    if loop_var is None or not isinstance(nd.collection, uni.UnaryExpr) {
        return False;
    }
    _reds: list = [];
    _red_names: set[str] = set();
    for st in (nd.body or []) {
        _r_asgns = ([st] if isinstance(st, uni.Assignment) else [])
            + list(st.get_all_sub_nodes(uni.Assignment));
        for _ra in _r_asgns {
            if _ra.na_flow_reduce
                and len(_ra.target) == 1
                and isinstance(_ra.target[0], uni.Name) {
                _rn = _ra.target[0].sym_name;
                if _rn not in _red_names
                    and (_rn in self.local_vars or _rn in self.global_vars) {
                    _red_names.add(_rn);
                    _reds.append((_rn, _ra.na_flow_reduce));
                }
            }
        }
    }
    _red_identity = {
        "add": 0,
        "min": 9223372036854775807,
        "max": (-9223372036854775808)
    };
    _chk = self._na_chunks_shape(nd.collection.operand);
    if _chk is not None {
        coll = self._str_norm(self._codegen_expr(_chk[0]));
    } else {
        coll = self._codegen_expr(nd.collection);
    }
    if coll is None {
        return False;
    }
    elem_type_name: (str | None) = self._infer_list_elem_type(coll);
    if elem_type_name is None {
        elem_type_name = self._elem_spec_of(
            _chk[0] if _chk is not None else nd.collection
        );
    }
    if elem_type_name is None and isinstance(coll.type, ir.PointerType) {
        elem_type_name = "ptr";
    }
    helpers = self.list_helpers.get(elem_type_name) if elem_type_name else None;
    if helpers is None {
        return False;
    }
    actual_elem_type = helpers["elem_type"];
    _elem_cast: (ir.Type | None) = None;
    if elem_type_name == "ptr" {
        _inner = self._list_elem_llvm_of(nd.collection);
        if _inner is not None and isinstance(_inner, ir.PointerType) {
            _elem_cast = _inner;
            actual_elem_type = _inner;
        }
    }

    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    i8p = ir.IntType(8).as_pointer();

    _caps: list[str] = [];
    for st in (nd.body or []) {
        for anm in st.get_all_sub_nodes(uni.Name) {
            _nmn = anm.sym_name;
            if _nmn == loop_var
                or _nmn in _caps
                or _nmn in _red_names
                or _nmn not in self.local_vars {
                continue;
            }
            _decl = anm.sym.decl if anm.sym is not None else None;
            _inside = False;
            _cur: (uni.UniNode | None) = _decl;
            while _cur is not None {
                if _cur is nd {
                    _inside = True;
                    break;
                }
                _cur = _cur.parent;
            }
            if not _inside {
                _caps.append(_nmn);
            }
        }
    }
    _cap_vals: list = [];
    for _cn in _caps {
        _cap_vals.append(
            self.builder.load(self.local_vars[_cn], name=f"ffor.cap.{_cn}")
        );
    }

    _chk_n: (ir.Value | None) = None;
    if _chk is not None {
        _chk_n = self._codegen_expr(_chk[1]);
        if _chk_n is None {
            return False;
        }
        _chk_n = self._coerce_type(_chk_n, i64);
        _chk_n = self.builder.select(
            self.builder.icmp_signed(
                "<", _chk_n, ir.Constant(i64, 1), name="ffor.ck.lo"
            ),
            ir.Constant(i64, 1),
            _chk_n,
            name="ffor.ck.n"
        );
    }
    _cap_off = 2 if _chk is not None else 1;
    _ctx_field_types = [coll.type]
        + ([i64] if _chk is not None else [])
        + [v.type for v in _cap_vals];
    _ctx_ty = ir.LiteralStructType(_ctx_field_types);
    _ctx_slot = self.builder.alloca(_ctx_ty, name="ffor.ctx");
    self.builder.store(
        coll,
        self.builder.gep(
            _ctx_slot, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ffor.ctx.coll"
        )
    );
    if _chk_n is not None {
        self.builder.store(
            _chk_n,
            self.builder.gep(
                _ctx_slot, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="ffor.ctx.n"
            )
        );
    }
    for (_ci, _cv) in enumerate(_cap_vals) {
        self.builder.store(
            _cv,
            self.builder.gep(
                _ctx_slot,
                [ir.Constant(i32, 0), ir.Constant(i32, _ci + _cap_off)],
                name=f"ffor.ctx.{_caps[_ci]}"
            )
        );
    }
    _ctx8 = self.builder.bitcast(_ctx_slot, i8p, name="ffor.ctx8");

    self._str_count += 1;
    _fid = self._str_count;
    _body_fn = ir.Function(
        self.llvm_module,
        ir.FunctionType(ir.VoidType(), [i8p, i64, i64, i64.as_pointer()]),
        name=f"__jac_ffor_body_{_fid}"
    );
    _body_fn.linkage = "private";
    _body_fn.args[0].name = "ctx";
    _body_fn.args[1].name = "lo";
    _body_fn.args[2].name = "hi";
    _body_fn.args[3].name = "red";

    saved_builder = self._builder;
    saved_locals = self.local_vars;
    saved_nogc = self.nogc_no_free_vars;
    saved_nogc_owned = self.nogc_owned_str_vars;
    saved_region_handles = self.region_handle_vars;
    saved_cell_vars = self.closure_cell_vars;
    saved_cell_handles = self.closure_cell_handles;
    saved_loop_stack = self.loop_stack;
    saved_region_opens = self.region_open_stack;
    saved_di = self._di_current_sp;

    _b_entry = _body_fn.append_basic_block("entry");
    self._builder = ir.IRBuilder(_b_entry);
    self.local_vars = {};
    self.nogc_no_free_vars = set();
    self.nogc_owned_str_vars = set();
    self.region_handle_vars = set();
    self.closure_cell_vars = set();
    self.closure_cell_handles = {};
    self.loop_stack = [];
    self.region_open_stack = [];
    self._di_current_sp = None;

    _bctx = self.builder.bitcast(_body_fn.args[0], _ctx_ty.as_pointer(), name="ctx.t");
    _bcoll = self.builder.load(
        self.builder.gep(
            _bctx, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ctx.coll.p"
        ),
        name="ctx.coll"
    );
    _b_chk_n: (ir.Value | None) = None;
    if _chk is not None {
        _b_chk_n = self.builder.load(
            self.builder.gep(
                _bctx, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="ctx.n.p"
            ),
            name="ctx.n"
        );
    }
    for (_ci, _cn) in enumerate(_caps) {
        _cval = self.builder.load(
            self.builder.gep(
                _bctx,
                [ir.Constant(i32, 0), ir.Constant(i32, _ci + _cap_off)],
                name=f"ctx.{_cn}.p"
            ),
            name=f"ctx.{_cn}"
        );
        _calloca = self._entry_alloca(_cval.type, _cn);
        self.builder.store(_cval, _calloca);
        self.local_vars[_cn] = _calloca;
    }
    _b_hdr: (ir.Value | None) = None;
    if _chk is not None {
        _lv_alloca = self._entry_alloca(coll.type, loop_var);
        _b_hdr = self._entry_alloca(coll.type.pointee, f"{loop_var}.chunk.hdr");
        self.nogc_no_free_vars.add(loop_var);
    } else {
        _lv_alloca = self._entry_alloca(actual_elem_type, loop_var);
        if isinstance(actual_elem_type, ir.PointerType) {
            self.nogc_no_free_vars.add(loop_var);
        }
    }
    self.local_vars[loop_var] = _lv_alloca;
    _red_slots: list = [];
    for (_ri, _red) in enumerate(_reds) {
        _rslot = self._entry_alloca(i64, _red[0]);
        self.builder.store(ir.Constant(i64, _red_identity[_red[1]]), _rslot);
        self.local_vars[_red[0]] = _rslot;
        _red_slots.append(_rslot);
    }
    _idx_alloca = self._entry_alloca(i64, "ffor.idx");
    self.builder.store(_body_fn.args[1], _idx_alloca);

    _c_cond = _body_fn.append_basic_block("ffor.cond");
    _c_body = _body_fn.append_basic_block("ffor.body");
    _c_incr = _body_fn.append_basic_block("ffor.incr");
    _c_end = _body_fn.append_basic_block("ffor.end");
    self.builder.branch(_c_cond);
    self.builder.position_at_end(_c_cond);
    _ci_cur = self.builder.load(_idx_alloca, name="ffor.cur");
    self.builder.cbranch(
        self.builder.icmp_signed("<", _ci_cur, _body_fn.args[2], name="ffor.cmp"),
        _c_body,
        _c_end
    );
    self.builder.position_at_end(_c_body);
    _bidx = self.builder.load(_idx_alloca, name="ffor.bidx");
    if _chk is not None {
        self._emit_chunk_header(_bcoll, _b_chk_n, _bidx, _b_hdr, helpers["len"]);
        self.builder.store(_b_hdr, _lv_alloca);
    } else {
        _elem = self.builder.call(helpers["get"], [_bcoll, _bidx], name="ffor.elem");
        if _elem_cast is not None {
            _elem = self.builder.bitcast(_elem, _elem_cast, name="ffor.elem.cast");
        }
        self.builder.store(_elem, _lv_alloca);
    }

    import from jaclang.compiler.passes.rc_facts_pass { loop_body_locals }
    _ff_saved = loop_body_locals(
        nd.body if isinstance(nd.body, (list, tuple)) else None
    );
    _ff_prebody = set(self.local_vars.keys());
    self.loop_stack.append((_c_incr, _c_end));
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    self.loop_stack.pop();
    if not self.builder.block.is_terminated {
        self._emit_loop_iter_cleanup(
            [
                _v
                for _v in _ff_saved
                if _v not in _ff_prebody
            ],
            loc="ffor.iter"
        );
        self.builder.branch(_c_incr);
    }
    self.builder.position_at_end(_c_incr);
    self.builder.store(
        self.builder.add(
            self.builder.load(_idx_alloca, name="ffor.inc"),
            ir.Constant(i64, 1),
            name="ffor.next"
        ),
        _idx_alloca
    );
    self.builder.branch(_c_cond);
    self.builder.position_at_end(_c_end);
    for (_ri, _red) in enumerate(_reds) {
        self.builder.store(
            self.builder.load(_red_slots[_ri], name=f"ffor.red.{_red[0]}"),
            self.builder.gep(
                _body_fn.args[3],
                [ir.Constant(i64, _ri)],
                name=f"ffor.red.{_red[0]}.out"
            )
        );
    }
    self.builder.ret_void();
    for bb in _body_fn.basic_blocks {
        if not bb.is_terminated {
            ir.IRBuilder(bb).ret_void();
        }
    }

    _arg_ty = ir.LiteralStructType([i8p, i64, i64, i64.as_pointer()]);
    _thunk_fn = ir.Function(
        self.llvm_module, ir.FunctionType(i8p, [i8p]), name=f"__jac_ffor_thunk_{_fid}"
    );
    _thunk_fn.linkage = "private";
    _tb = ir.IRBuilder(_thunk_fn.append_basic_block("entry"));
    _ta = _tb.bitcast(_thunk_fn.args[0], _arg_ty.as_pointer(), name="arg.t");
    _t_ctx = _tb.load(
        _tb.gep(_ta, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="a.ctx.p"),
        name="a.ctx"
    );
    _t_lo = _tb.load(
        _tb.gep(_ta, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="a.lo.p"),
        name="a.lo"
    );
    _t_hi = _tb.load(
        _tb.gep(_ta, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="a.hi.p"),
        name="a.hi"
    );
    _t_red = _tb.load(
        _tb.gep(_ta, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="a.red.p"),
        name="a.red"
    );
    _tb.call(_body_fn, [_t_ctx, _t_lo, _t_hi, _t_red]);
    _tb.ret(ir.Constant(i8p, None));

    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.nogc_no_free_vars = saved_nogc;
    self.nogc_owned_str_vars = saved_nogc_owned;
    self.region_handle_vars = saved_region_handles;
    self.closure_cell_vars = saved_cell_vars;
    self.closure_cell_handles = saved_cell_handles;
    self.loop_stack = saved_loop_stack;
    self.region_open_stack = saved_region_opens;
    self._di_current_sp = saved_di;

    _len_val = self.builder.call(helpers["len"], [coll], name="ffor.len");
    if _chk_n is not None {
        _len_val = self.builder.sdiv(
            self.builder.sub(
                self.builder.add(_len_val, _chk_n, name="ffor.ck.t"),
                ir.Constant(i64, 1),
                name="ffor.ck.t1"
            ),
            _chk_n,
            name="ffor.ck.ntasks"
        );
    }
    _getenv_fn = self._get_or_declare_extern("getenv", i8p, [i8p]);
    _atoi_fn = self._get_or_declare_extern("atoi", i32, [i8p]);
    _thr_fnty_p = ir.FunctionType(i8p, [i8p]).as_pointer();
    _pcreate = self._get_or_declare_extern(
        "pthread_create", i32, [i64.as_pointer(), i8p, _thr_fnty_p, i8p]
    );
    _pjoin = self._get_or_declare_extern("pthread_join", i32, [i64, i8p]);

    _env_key_gv = self._get_snprintf_fmt("JAC_FLOW_THREADS");
    _env_key = self.builder.gep(
        _env_key_gv, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ffor.env.key"
    );
    _env_val = self.builder.call(_getenv_fn, [_env_key], name="ffor.env");
    _env_null = self.builder.icmp_unsigned(
        "==", _env_val, ir.Constant(i8p, None), name="ffor.env.null"
    );
    _nt_slot = self.builder.alloca(i32, name="ffor.nt.slot");
    self.builder.store(ir.Constant(i32, 4), _nt_slot);
    _envfunc = self.builder.function;
    _env_parse = _envfunc.append_basic_block("ffor.env.parse");
    _env_done = _envfunc.append_basic_block("ffor.env.done");
    self.builder.cbranch(_env_null, _env_done, _env_parse);
    self.builder.position_at_end(_env_parse);
    self.builder.store(
        self.builder.call(_atoi_fn, [_env_val], name="ffor.env.nt"), _nt_slot
    );
    self.builder.branch(_env_done);
    self.builder.position_at_end(_env_done);
    _nt = self.builder.sext(
        self.builder.load(_nt_slot, name="ffor.nt.raw"), i64, name="ffor.nt64"
    );
    _nt = self.builder.select(
        self.builder.icmp_signed("<", _nt, ir.Constant(i64, 1), name="ffor.nt.lo"),
        ir.Constant(i64, 1),
        _nt,
        name="ffor.nt.min"
    );
    _nt = self.builder.select(
        self.builder.icmp_signed(">", _nt, _len_val, name="ffor.nt.hi"),
        _len_val,
        _nt,
        name="ffor.nt.cap"
    );
    _nt = self.builder.select(
        self.builder.icmp_signed("<", _nt, ir.Constant(i64, 1), name="ffor.nt.lo2"),
        ir.Constant(i64, 1),
        _nt,
        name="ffor.nt"
    );
    _chunk = self.builder.sdiv(
        self.builder.sub(
            self.builder.add(_len_val, _nt, name="ffor.ln"),
            ir.Constant(i64, 1),
            name="ffor.ln1"
        ),
        _nt,
        name="ffor.chunk"
    );
    _tid_arr = self.builder.alloca(i64, size=_nt, name="ffor.tids");
    _arg_arr = self.builder.alloca(_arg_ty, size=_nt, name="ffor.args");

    func = self.builder.function;
    _nred = len(_reds);
    _red_arr = ir.Constant(i64.as_pointer(), None);
    if _reds {
        _red_arr = self.builder.alloca(
            i64,
            size=self.builder.mul(_nt, ir.Constant(i64, _nred), name="ffor.red.n"),
            name="ffor.reds"
        );
        _ri_cond = func.append_basic_block("ffor.red.init.cond");
        _ri_body = func.append_basic_block("ffor.red.init.body");
        _ri_done = func.append_basic_block("ffor.red.init.done");
        _ri_slot = self.builder.alloca(i64, name="ffor.red.init.t");
        self.builder.store(ir.Constant(i64, 0), _ri_slot);
        self.builder.branch(_ri_cond);
        self.builder.position_at_end(_ri_cond);
        _ri_t = self.builder.load(_ri_slot, name="ffor.ri.t");
        self.builder.cbranch(
            self.builder.icmp_signed("<", _ri_t, _nt, name="ffor.ri.lt"),
            _ri_body,
            _ri_done
        );
        self.builder.position_at_end(_ri_body);
        _ri_base = self.builder.mul(
            _ri_t, ir.Constant(i64, _nred), name="ffor.ri.base"
        );
        for (_ri, _red) in enumerate(_reds) {
            self.builder.store(
                ir.Constant(i64, _red_identity[_red[1]]),
                self.builder.gep(
                    _red_arr,
                    [
                        self.builder.add(
                            _ri_base, ir.Constant(i64, _ri), name=f"ffor.ri.{_red[0]}"
                        )
                    ],
                    name=f"ffor.ri.{_red[0]}.p"
                )
            );
        }
        self.builder.store(
            self.builder.add(_ri_t, ir.Constant(i64, 1), name="ffor.ri.next"), _ri_slot
        );
        self.builder.branch(_ri_cond);
        self.builder.position_at_end(_ri_done);
    }
    _s_cond = func.append_basic_block("ffor.spawn.cond");
    _s_body = func.append_basic_block("ffor.spawn.body");
    _s_seq = func.append_basic_block("ffor.spawn.seq");
    _s_next = func.append_basic_block("ffor.spawn.next");
    _j_cond = func.append_basic_block("ffor.join.cond");
    _j_body = func.append_basic_block("ffor.join.body");
    _j_do = func.append_basic_block("ffor.join.do");
    _j_next = func.append_basic_block("ffor.join.next");
    _done_bb = func.append_basic_block("ffor.done");

    _t_slot = self.builder.alloca(i64, name="ffor.t");
    self.builder.store(ir.Constant(i64, 0), _t_slot);
    self.builder.branch(_s_cond);

    self.builder.position_at_end(_s_cond);
    _t_cur = self.builder.load(_t_slot, name="ffor.t.cur");
    _t_lo2 = self.builder.mul(_t_cur, _chunk, name="ffor.t.lo");
    _t_in = self.builder.and_(
        self.builder.icmp_signed("<", _t_cur, _nt, name="ffor.t.lt"),
        self.builder.icmp_signed("<", _t_lo2, _len_val, name="ffor.lo.lt"),
        name="ffor.t.in"
    );
    self.builder.cbranch(_t_in, _s_body, _j_cond);

    self.builder.position_at_end(_s_body);
    _hi_raw = self.builder.add(_t_lo2, _chunk, name="ffor.hi.raw");
    _t_hi2 = self.builder.select(
        self.builder.icmp_signed(">", _hi_raw, _len_val, name="ffor.hi.over"),
        _len_val,
        _hi_raw,
        name="ffor.t.hi"
    );
    _ap = self.builder.gep(_arg_arr, [_t_cur], name="ffor.a.p");
    self.builder.store(
        _ctx8,
        self.builder.gep(
            _ap, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ffor.a.ctx"
        )
    );
    self.builder.store(
        _t_lo2,
        self.builder.gep(
            _ap, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="ffor.a.lo"
        )
    );
    self.builder.store(
        _t_hi2,
        self.builder.gep(
            _ap, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="ffor.a.hi"
        )
    );
    _t_row = _red_arr;
    if _reds {
        _t_row = self.builder.gep(
            _red_arr,
            [self.builder.mul(_t_cur, ir.Constant(i64, _nred), name="ffor.row.o")],
            name="ffor.row"
        );
    }
    self.builder.store(
        _t_row,
        self.builder.gep(
            _ap, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="ffor.a.red"
        )
    );
    _tp = self.builder.gep(_tid_arr, [_t_cur], name="ffor.tid.p");
    self.builder.store(ir.Constant(i64, 0), _tp);
    _crc = self.builder.call(
        _pcreate,
        [
            _tp,
            ir.Constant(i8p, None),
            _thunk_fn,
            self.builder.bitcast(_ap, i8p, name="ffor.a8")
        ],
        name="ffor.crc"
    );
    self.builder.cbranch(
        self.builder.icmp_signed("!=", _crc, ir.Constant(i32, 0), name="ffor.crc.bad"),
        _s_seq,
        _s_next
    );
    self.builder.position_at_end(_s_seq);
    self.builder.store(ir.Constant(i64, 0), _tp);
    self.builder.call(_body_fn, [_ctx8, _t_lo2, _t_hi2, _t_row]);
    self.builder.branch(_s_next);

    self.builder.position_at_end(_s_next);
    self.builder.store(
        self.builder.add(_t_cur, ir.Constant(i64, 1), name="ffor.t.next"), _t_slot
    );
    self.builder.branch(_s_cond);

    self.builder.position_at_end(_j_cond);
    self.builder.store(ir.Constant(i64, 0), _t_slot);
    self.builder.branch(_j_body);
    self.builder.position_at_end(_j_body);
    _jt = self.builder.load(_t_slot, name="ffor.j.t");
    _j_lo = self.builder.mul(_jt, _chunk, name="ffor.j.lo");
    _j_in = self.builder.and_(
        self.builder.icmp_signed("<", _jt, _nt, name="ffor.j.lt"),
        self.builder.icmp_signed("<", _j_lo, _len_val, name="ffor.j.lo.lt"),
        name="ffor.j.in"
    );
    self.builder.cbranch(_j_in, _j_do, _done_bb);
    self.builder.position_at_end(_j_do);
    _jtid = self.builder.load(
        self.builder.gep(_tid_arr, [_jt], name="ffor.j.tid.p"), name="ffor.j.tid"
    );
    _j_live = self.builder.icmp_signed(
        "!=", _jtid, ir.Constant(i64, 0), name="ffor.j.live"
    );
    _j_wait = func.append_basic_block("ffor.join.wait");
    self.builder.cbranch(_j_live, _j_wait, _j_next);
    self.builder.position_at_end(_j_wait);
    self.builder.call(_pjoin, [_jtid, ir.Constant(i8p, None)]);
    self.builder.branch(_j_next);
    self.builder.position_at_end(_j_next);
    self.builder.store(
        self.builder.add(_jt, ir.Constant(i64, 1), name="ffor.j.next"), _t_slot
    );
    self.builder.branch(_j_body);

    self.builder.position_at_end(_done_bb);
    for (_ri, _red) in enumerate(_reds) {
        _acc_slot = self.local_vars.get(_red[0]);
        if _acc_slot is None {
            _acc_slot = self.global_vars[_red[0]];
        }
        _cur_slot = self.builder.alloca(i64, name=f"ffor.comb.{_red[0]}");
        self.builder.store(
            self.builder.load(_acc_slot, name=f"ffor.comb.{_red[0]}.0"), _cur_slot
        );
        _ct_slot = self.builder.alloca(i64, name=f"ffor.comb.{_red[0]}.t");
        self.builder.store(ir.Constant(i64, 0), _ct_slot);
        _cb_cond = func.append_basic_block(f"ffor.comb.cond.{_ri}");
        _cb_body = func.append_basic_block(f"ffor.comb.body.{_ri}");
        _cb_done = func.append_basic_block(f"ffor.comb.done.{_ri}");
        self.builder.branch(_cb_cond);
        self.builder.position_at_end(_cb_cond);
        _cb_t = self.builder.load(_ct_slot, name="ffor.cb.t");
        self.builder.cbranch(
            self.builder.icmp_signed("<", _cb_t, _nt, name="ffor.cb.lt"),
            _cb_body,
            _cb_done
        );
        self.builder.position_at_end(_cb_body);
        _cb_v = self.builder.load(
            self.builder.gep(
                _red_arr,
                [
                    self.builder.add(
                        self.builder.mul(
                            _cb_t, ir.Constant(i64, _nred), name="ffor.cb.base"
                        ),
                        ir.Constant(i64, _ri),
                        name="ffor.cb.idx"
                    )
                ],
                name="ffor.cb.p"
            ),
            name="ffor.cb.v"
        );
        _cb_cur = self.builder.load(_cur_slot, name="ffor.cb.cur");
        if _red[1] == "add" {
            _cb_new = self.builder.add(_cb_cur, _cb_v, name="ffor.cb.add");
        } elif _red[1] == "min" {
            _cb_new = self.builder.select(
                self.builder.icmp_signed("<", _cb_v, _cb_cur, name="ffor.cb.sl"),
                _cb_v,
                _cb_cur,
                name="ffor.cb.min"
            );
        } else {
            _cb_new = self.builder.select(
                self.builder.icmp_signed(">", _cb_v, _cb_cur, name="ffor.cb.sg"),
                _cb_v,
                _cb_cur,
                name="ffor.cb.max"
            );
        }
        self.builder.store(_cb_new, _cur_slot);
        self.builder.store(
            self.builder.add(_cb_t, ir.Constant(i64, 1), name="ffor.cb.next"), _ct_slot
        );
        self.builder.branch(_cb_cond);
        self.builder.position_at_end(_cb_done);
        self.builder.store(
            self.builder.load(_cur_slot, name=f"ffor.comb.{_red[0]}.fin"), _acc_slot
        );
    }
    return True;
}

impl NaIRGenStmt._codegen_for_indexed(
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

    _gen_yield_loop = (
        self._gen_ctx is not None
        and self.builder.function is self._gen_ctx["resume_fn"]
        and bool(nd.get_all_sub_nodes(typ=uni.YieldExpr))
    );
    _gen_stop_slot: (ir.Value | None) = None;
    _gen_step_slot: (ir.Value | None) = None;
    _gen_coll_slot: (ir.Value | None) = None;
    if _gen_yield_loop and kind != "range" {
        _gen_coll_slot = self._entry_alloca(collection_val.type, "for.coll.slot");
        if not self._is_owned(collection_val) {
            self._emit_rc_retain(collection_val, op="for_coll_spill", loc=_rc_loc);
        }
        self.builder.store(collection_val, _gen_coll_slot);
    }

    _coll_slot_var: (str | None) = None;
    if _gen_coll_slot is None
        and coll_release_op
        and kind != "range"
        and self._is_owned(collection_val) {
        _coll_slot_var = self._bind_loop_coll_slot(collection_val);
    }

    if kind == "range" {
        len_val = collection_val;
        idx_alloca = self._entry_alloca(i64, var_names[0]);
        self.builder.store(range_start, idx_alloca);
        self.local_vars[var_names[0]] = idx_alloca;
        allocas = [idx_alloca];
        if _gen_yield_loop {
            _gen_stop_slot = self._entry_alloca(i64, "for.stop.slot");
            self.builder.store(len_val, _gen_stop_slot);
            if range_step is not None {
                _gen_step_slot = self._entry_alloca(i64, "for.step.slot");
                self.builder.store(range_step, _gen_step_slot);
            }
        }
    } else {
        if kind == "str" {
            len_val = self._call_str_len(self.builder, collection_val, name="for.len");
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
            _in_resume_fn = (
                self._gen_ctx is not None
                and self.builder.function is self._gen_ctx["resume_fn"]
            );
            if isinstance(vtype, ir.PointerType) and (rc_vars or kind == "str") {
                null_const = ir.Constant(vtype, None);
                if not _reuse and not _in_resume_fn {
                    _saved_block = self.builder.block;
                    self.builder.position_after(alloca);
                    self.builder.store(null_const, alloca);
                    self.builder.position_at_end(_saved_block);
                }
                if rc_vars {
                    if self._gc_mode() != "none" {
                        _pre_old = self.builder.load(alloca, name="for.pre.old");
                        self._emit_rc_release_simple(
                            _pre_old, op="for_reset", loc=_rc_loc
                        );
                    }
                    self.builder.store(null_const, alloca);
                }
            }
            self.local_vars[vname] = alloca;
            if rc_vars
                and isinstance(vtype, ir.PointerType)
                and self._gc_mode() == "none" {
                self.nogc_no_free_vars.add(vname);
            }
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
    if _gen_stop_slot is not None {
        len_val = self.builder.load(_gen_stop_slot, name="for.stop");
    }
    if _gen_step_slot is not None {
        range_step = self.builder.load(_gen_step_slot, name="for.step");
    }
    if _gen_coll_slot is not None {
        collection_val = self._str_norm(
            self.builder.load(_gen_coll_slot, name="for.coll")
        );
        if kind == "str" {
            len_val = self._call_str_len(self.builder, collection_val, name="for.len");
        } elif kind == "bytes" {
            len_val = self._bytes_len_val(collection_val);
        } else {
            len_val = self.builder.call(
                helpers["len"], [collection_val], name="for.len"
            );
        }
    }
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
        if _gen_coll_slot is not None {
            collection_val = self._str_norm(
                self.builder.load(_gen_coll_slot, name="for.coll.body")
            );
        }
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
        } elif kind in ("list", "dict", "set") {
            fetch_fn = helpers["get_key"] if kind == "dict" else helpers["get"];
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
                if rc_vars
                    and isinstance(var_types[0], ir.PointerType)
                    and self._gc_mode() != "none" {
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
    import from jaclang.compiler.passes.rc_facts_pass { loop_body_locals }
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
    if _gen_step_slot is not None {
        range_step = self.builder.load(_gen_step_slot, name="for.step.inc");
    }
    inc_idx = self.builder.load(idx_alloca, name="for.inc.idx");
    _idx_delta = range_step
        if kind == "range" and range_step is not None
        else ir.Constant(i64, 1);
    next_idx = self.builder.add(inc_idx, _idx_delta, name="for.next.idx");
    self.builder.store(next_idx, idx_alloca);
    self.builder.branch(cond_bb);
    self.builder.position_at_end(end_bb);

    if _gen_coll_slot is not None {
        _coll_end = self.builder.load(_gen_coll_slot, name="for.coll.end");
        self._emit_rc_release_simple(
            _coll_end, op=coll_release_op or "for_coll", loc=_for_loc
        );
        self.builder.store(ir.Constant(_coll_end.type, None), _gen_coll_slot);
    } elif _coll_slot_var is not None {
        self._release_loop_coll_slot(_coll_slot_var, op=coll_release_op, loc=_for_loc);
    } elif coll_release_op
        and isinstance(collection_val.type, ir.PointerType)
        and self._is_owned(collection_val) {
        self._emit_rc_release_simple(collection_val, op=coll_release_op, loc=_for_loc);
    }
}

impl NaIRGenStmt._na_chunks_shape(expr: object) -> (tuple | None) {
    if not isinstance(expr, uni.FuncCall) {
        return None;
    }
    _t = expr.target;
    if not (
        isinstance(_t, uni.AtomTrailer)
        and _t.is_attr
        and isinstance(_t.right, uni.Name)
        and _t.right.sym_name == "chunks"
    ) {
        return None;
    }
    _params = [
        (p.value if isinstance(p, uni.KWPair) else p) for p in (expr.params or [])
    ];
    if len(_params) != 1 {
        return None;
    }
    return (_t.target, _params[0]);
}

impl NaIRGenStmt._emit_chunk_header(
    coll: ir.Value, n_val: ir.Value, ci: ir.Value, hdr: ir.Value, len_fn: ir.Function
) -> None {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    _z = ir.Constant(i32, 0);
    _start = self.builder.mul(ci, n_val, name="chunk.start");
    _total = self.builder.call(len_fn, [coll], name="chunk.total");
    _rem = self.builder.sub(_total, _start, name="chunk.rem");
    _clen = self.builder.select(
        self.builder.icmp_signed("<", n_val, _rem, name="chunk.fit"),
        n_val,
        _rem,
        name="chunk.len"
    );
    _clen = self.builder.select(
        self.builder.icmp_signed("<", _clen, ir.Constant(i64, 0), name="chunk.neg"),
        ir.Constant(i64, 0),
        _clen,
        name="chunk.len.c"
    );
    _ebase = self.builder.load(
        self.builder.gep(coll, [_z, ir.Constant(i32, 2)], name="chunk.eb.p"),
        name="chunk.eb"
    );
    _ep = self.builder.gep(_ebase, [_start], name="chunk.ep");
    self.builder.store(
        _clen, self.builder.gep(hdr, [_z, ir.Constant(i32, 0)], name="chunk.hl")
    );
    self.builder.store(
        _clen, self.builder.gep(hdr, [_z, ir.Constant(i32, 1)], name="chunk.hc")
    );
    self.builder.store(
        _ep, self.builder.gep(hdr, [_z, ir.Constant(i32, 2)], name="chunk.he")
    );
}

impl NaIRGenStmt._try_chunked_for(nd: uni.InForStmt) -> bool {
    if not isinstance(nd.collection, uni.UnaryExpr) {
        return False;
    }
    _chk = self._na_chunks_shape(nd.collection.operand);
    if _chk is None {
        return False;
    }
    loop_var = self._get_name(nd.target);
    if loop_var is None {
        return False;
    }
    coll = self._codegen_expr(_chk[0]);
    coll = self._str_norm(coll);
    if coll is None {
        return False;
    }
    elem_type_name: (str | None) = self._infer_list_elem_type(coll);
    if elem_type_name is None {
        elem_type_name = self._elem_spec_of(_chk[0]);
    }
    if elem_type_name is None and isinstance(coll.type, ir.PointerType) {
        elem_type_name = "ptr";
    }
    helpers = self.list_helpers.get(elem_type_name) if elem_type_name else None;
    if helpers is None {
        return False;
    }
    i64 = ir.IntType(64);
    _nv = self._codegen_expr(_chk[1]);
    if _nv is None {
        return False;
    }
    _nv = self._coerce_type(_nv, i64);
    _nv = self.builder.select(
        self.builder.icmp_signed("<", _nv, ir.Constant(i64, 1), name="chunk.n.lo"),
        ir.Constant(i64, 1),
        _nv,
        name="chunk.n"
    );
    _total0 = self.builder.call(helpers["len"], [coll], name="chunk.n.total");
    _ntasks = self.builder.sdiv(
        self.builder.sub(
            self.builder.add(_total0, _nv, name="chunk.tn"),
            ir.Constant(i64, 1),
            name="chunk.tn1"
        ),
        _nv,
        name="chunk.ntasks"
    );
    _hdr = self._entry_alloca(coll.type.pointee, f"{loop_var}.chunk.hdr");
    _lv_alloca = self._entry_alloca(coll.type, loop_var);
    self.local_vars[loop_var] = _lv_alloca;
    self.nogc_no_free_vars.add(loop_var);
    _ci_slot = self._entry_alloca(i64, "chunk.ci");
    self.builder.store(ir.Constant(i64, 0), _ci_slot);

    func = self.builder.function;
    _c_cond = func.append_basic_block("chunk.cond");
    _c_body = func.append_basic_block("chunk.body");
    _c_incr = func.append_basic_block("chunk.incr");
    _c_end = func.append_basic_block("chunk.end");
    self.builder.branch(_c_cond);
    self.builder.position_at_end(_c_cond);
    _ci = self.builder.load(_ci_slot, name="chunk.ci.cur");
    self.builder.cbranch(
        self.builder.icmp_signed("<", _ci, _ntasks, name="chunk.ci.lt"), _c_body, _c_end
    );
    self.builder.position_at_end(_c_body);
    self._emit_chunk_header(coll, _nv, _ci, _hdr, helpers["len"]);
    self.builder.store(_hdr, _lv_alloca);

    import from jaclang.compiler.passes.rc_facts_pass { loop_body_locals }
    _ch_saved = loop_body_locals(
        nd.body if isinstance(nd.body, (list, tuple)) else None
    );
    _ch_prebody = set(self.local_vars.keys());
    self.loop_stack.append((_c_incr, _c_end));
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    self.loop_stack.pop();
    if not self.builder.block.is_terminated {
        self._emit_loop_iter_cleanup(
            [
                _v
                for _v in _ch_saved
                if _v not in _ch_prebody
            ],
            loc="chunk.iter"
        );
        self.builder.branch(_c_incr);
    }
    self.builder.position_at_end(_c_incr);
    self.builder.store(
        self.builder.add(
            self.builder.load(_ci_slot, name="chunk.ci.i"),
            ir.Constant(i64, 1),
            name="chunk.ci.n"
        ),
        _ci_slot
    );
    self.builder.branch(_c_cond);
    self.builder.position_at_end(_c_end);
    return True;
}
