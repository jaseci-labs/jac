"""Statement codegen: if, while, for, assignment, control flow."""
"""Generate IR for a sequence of statements."""
impl NaIRGenPass._codegen_body(stmts: (list | tuple)) -> None {
    for stmt in stmts {
        if self.builder.block.is_terminated {
            break;
        }
        # ── Per-statement DWARF location (JAC_NATIVE_DEBUG=1) ──────────────────
        # Snapshot the block count and per-block instruction counts before
        # codegen so we can tag EVERY new instruction — including those in
        # newly created blocks (if/elif/while/for branches) — with a
        # DILocation pointing at the source line.
        _di_blk_count_snap = 0;
        _di_instr_snap = 0;
        _di_line_snap = 0;
        _di_blk_snap = None;
        _di_blk_instr_counts: dict = {};  # block → instruction count before stmt
        if self._di_current_sp is not None and stmt?.loc {
            _di_blk_snap = self.builder.block;
            _di_instr_snap = len(self.builder.block.instructions);
            _di_line_snap = stmt.loc.first_line;
            _di_func = self.builder.function;
            _di_blk_count_snap = len(_di_func.blocks);
            # Record instruction count for every existing block so we can
            # identify instructions added by this statement in pre-existing
            # blocks (rare but possible with builder repositioning).
            for _di_b in _di_func.blocks {
                _di_blk_instr_counts[id(_di_b)] = len(_di_b.instructions);
            }
        }
        self._codegen_stmt(stmt);
        # Attach !dbg metadata to all NEW instructions across ALL blocks that
        # were created or grew during this statement's codegen.
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
            } except Exception {
            # best-effort
            }
        }
    }
}

"""Generate IR for a single statement."""
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
    } elif isinstance(nd, uni.InForStmt) {
        self._codegen_for(nd);
    } elif isinstance(nd, uni.IterForStmt) {
        self._codegen_iter_for(nd);
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
        # AssertionError: evaluate condition, raise if false
        cond = self._codegen_required(nd.condition);
        if cond is not None {
            cond_bool = self._to_bool(cond);
            # assert fires when condition is FALSE
            is_false = self.builder.not_(cond_bool, name="assert.fail");
            # Stamp the source location (and any literal message) into the
            # raise so the failure points at the assert site; messages are
            # deduplicated globals, so unique strings cost one constant each.
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
        # `del e` on an edge: disconnect it from the adjacency (issue #6642).
        # The edge handle (`ptrtoint` of the edge object, as carried by an
        # `[edge ...]` ref) keys the row `osp_disconnect` drops.
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
                self.emit(E5090, node_override=nd, kind="statement", name="DeleteStmt");
            }
        } elif (
            isinstance(target_expr, uni.AtomTrailer)
            and not target_expr.is_attr
            and target_expr.right?.slices
        ) {
            # del d[k]  →  d.remove(k)  (or del list[i] → list.del_at(i))
            slices = target_expr.right.slices or [];
            if slices {
                # Only handle dict-typed targets (checked type, then LLVM shape)
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
                    # del list[i]  →  list.del_at(i)
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
    } elif isinstance(nd, uni.Semi) {
        # Bare `;` — no codegen needed.
    } elif isinstance(nd, uni.GlobalStmt) {
        # `global`/`nonlocal` are declarations fully consumed by the symbol
        # table (bind_global_stmt rebinds the function-scope name to the
        # module symbol); the corresponding Name/Assignment nodes do the
        # actual codegen via Symbol.storage. No backend bookkeeping needed.
    } elif isinstance(nd, uni.PyInlineCode) {
        # ::py:: blocks are intentionally stripped from native output —
        # they target the Python pathway only.
    } elif isinstance(nd, uni.VisitStmt) {
        self._codegen_visit(nd);
    } elif isinstance(nd, uni.DisengageStmt) {
        self._codegen_disengage(nd);
    } elif isinstance(nd, uni.ReportStmt) {
        self._codegen_report(nd);
    } else {
        # Catch-all: any statement node we didn't recognize is a real
        # gap, not a no-op. Emit a structured error so the failure is
        # loud at compile time instead of silently producing an empty
        # function body. Without this, features like match/iter-for/
        # visit/disengage/report/nested-def used to compile clean and
        # then return 0 at runtime.
        self.emit(E5090, node_override=nd, kind="statement", name=type(nd).__name__);
    }
}

"""Generate return statement."""
impl NaIRGenPass._codegen_return(nd: uni.ReturnStmt) -> None {
    func_ret_type = self.builder.function.return_value.type;
    if nd.expr is not None {
        # An empty collection literal in return position types itself: the
        # checker stamps it with the declared return type (bidirectional
        # inference), so no emission-context hints are threaded here.
        # Return-position tuple packing (borrowed elements retained so they
        # outlive scope-exit teardown) is detected by _codegen_tuple_val from
        # the tree, not via an emission flag.
        val = self._codegen_required(nd.expr);
        if val is not None {
            # _coerce_type propagates is_owned across any bitcast/inttoptr it
            # emits, so checking val after coerce is safe — no need to capture
            # ownership pre-coerce.
            val = self._coerce_type(val, func_ret_type);
            # release all locals except the one being returned.
            # * `return x`         → skip_var = "x", cleanup won't release x.
            # * `return func(x,y)` → x,y were handed to the callee; null their
            #   allocas before cleanup so they aren't double-released.
            #
            # NOTE: params are BORROWED refs — the caller owns them, not us.
            # `return param` must NOT set skip_var; it falls through to the
            # borrow-retain path below (retain before returning a borrowed ref).
            skip_var: (str | None) = None;
            if isinstance(nd.expr, uni.Name)
            and nd.expr.sym_name not in self.param_vars {
                skip_var = nd.expr.sym_name;
            } elif isinstance(nd.expr, uni.TupleVal) {
                # Null allocas for any pointer-typed local variables that were
                # packed into the tuple so that _emit_scope_cleanup skips them.
                # The tuple box now owns those references; scope cleanup must not
                # double-release them.
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
            # when returning an expression that is NOT a named local
            # (skip_var is None) and NOT already owned (function-call / constructor
            # result), the value is a borrowed reference — field load, container
            # element read, param, etc.  We must retain it here so the caller
            # receives an owned reference and can safely release it at scope exit.
            #
            # Invariant: every pointer returned by a function is OWNED.
            #   - Named local return (skip_var set): already retained it on
            #     store; scope cleanup nulls the alloca → rc unchanged → owned. ✓
            #   - Function/constructor result (owned_id): rc=1 from alloc/callee → owned. ✓
            #   - Borrowed (field load, list[i], param read, etc.): retain here → owned. ✓
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
    # Fallback: return appropriate default value based on return type
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

"""Generate if/else/elif statement with proper basic blocks."""
impl NaIRGenPass._codegen_if(nd: uni.IfStmt) -> None {
    cond = self._codegen_required(nd.condition);
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
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }
    # Else block
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

"""Generate switch statement as chained comparisons."""
impl NaIRGenPass._codegen_switch(nd: uni.SwitchStmt) -> None {
    target_val = self._codegen_expr(nd.target);
    if target_val is None {
        return;
    }
    func = self.builder.function;
    merge_bb = func.append_basic_block(name="switch.end");
    # Separate default case from value cases
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
    # Build if/elif chain for each value case
    for (i, sc) in enumerate(value_cases) {
        pattern_val = None;
        if isinstance(sc.pattern, uni.MatchValue) {
            pattern_val = self._codegen_expr(sc.pattern.value);
        }
        if pattern_val is None {
            continue;
        }
        # Compare target to pattern
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
        # Case body
        self.builder.position_at_end(case_bb);
        self._codegen_body(sc.body);
        if not self.builder.block.is_terminated {
            self.builder.branch(merge_bb);
        }
        # Continue checking next case
        self.builder.position_at_end(next_bb);
    }
    # Default case (or fall through to merge)
    if default_case is not None {
        self._codegen_body(default_case.body);
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }
    self.builder.position_at_end(merge_bb);
}

"""Generate while loop with proper basic blocks."""
impl NaIRGenPass._codegen_while(nd: uni.WhileStmt) -> None {
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="while.cond");
    body_bb = func.append_basic_block(name="while.body");
    end_bb = func.append_basic_block(name="while.end");
    # Jump to condition check
    self.builder.branch(cond_bb);
    # Condition block
    self.builder.position_at_end(cond_bb);
    cond = self._codegen_required(nd.condition);
    if cond is not None {
        cond = self._to_bool(cond);
        self.builder.cbranch(cond, body_bb, end_bb);
    } else {
        self.builder.branch(end_bb);
    }
    # Body block — push loop context for break/continue
    self.loop_stack.append((cond_bb, end_bb));
    self.builder.position_at_end(body_bb);
    # Snapshot locals before body so we can release loop-body-declared
    # locals at the back-edge (loop semantics: body-locals don't survive
    # across iterations).  Without this, an early `return` in a later
    # iteration that occurs before a body-declared local's source-order
    # declaration would leak the previous iteration's value.
    import from jaclang.compiler.ownership { loop_body_locals }
    _while_body_locals = loop_body_locals(
        nd.body if isinstance(nd.body, (list, tuple)) else None
    );
    # Exclude enclosing-scope vars (e.g. an accumulator mutated in the body) that
    # only look body-local under a misbinding; their storage predates the body
    # and per-iteration release would free them mid-loop (#6943 NA-2).
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
    # Continue after loop
    self.builder.position_at_end(end_bb);
}

"""Generate a C-style iter-for loop.

`for <init> to <cond> by <step> { body }` lowers to:

    <init>                  ; in the current block, runs once
  iterfor.cond:
    if <cond> goto body else goto end
  iterfor.body:
    <body>
    goto step               ; fallthrough back-edge
  iterfor.step:
    <step>
    goto cond
  iterfor.end:

`break` targets end and `continue` targets step (so the counter still
advances), matching the InForStmt loop_stack convention of
(continue_target, break_target).
"""
impl NaIRGenPass._codegen_iter_for(nd: uni.IterForStmt) -> None {
    # init runs once in the current block.
    self._codegen_assignment(nd.iter);
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="iterfor.cond");
    body_bb = func.append_basic_block(name="iterfor.body");
    step_bb = func.append_basic_block(name="iterfor.step");
    end_bb = func.append_basic_block(name="iterfor.end");
    self.builder.branch(cond_bb);
    # Condition block.
    self.builder.position_at_end(cond_bb);
    cond = self._codegen_required(nd.condition);
    if cond is not None {
        cond = self._to_bool(cond);
        self.builder.cbranch(cond, body_bb, end_bb);
    } else {
        self.builder.branch(end_bb);
    }
    # Body block — continue lands on the step block so the counter advances.
    self.loop_stack.append((step_bb, end_bb));
    self.builder.position_at_end(body_bb);
    import from jaclang.compiler.ownership { loop_body_locals }
    _saved_locals = loop_body_locals(
        nd.body if isinstance(nd.body, (list, tuple)) else None
    );
    # Exclude enclosing-scope vars mutated in the body (misbinding guard, #6943
    # NA-2): their storage predates the body, so they are not per-iteration locals.
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
    # Step block — run the count_by update, then re-check the condition.
    self.builder.position_at_end(step_bb);
    if not self.builder.block.is_terminated {
        self._codegen_assignment(nd.count_by);
        self.builder.branch(cond_bb);
    }
    # Continue after the loop.
    self.builder.position_at_end(end_bb);
}

"""Generate a match statement.

The subject is evaluated once into a temp slot, then each case is lowered
to an if/elif chain: test the pattern, optionally bind captures and check
the guard, then run the body and jump to the shared end block. Supported
patterns are literal value, singleton, wildcard, capture (`as`), and OR of
those. Structural patterns (sequence/mapping/class) emit E5090.
"""
impl NaIRGenPass._codegen_match(nd: uni.MatchStmt) -> None {
    subj = self._codegen_expr(nd.target);
    if subj is None {
        return;
    }
    # Evaluate the subject exactly once and read it from a slot per test.
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
            # Unsupported pattern — E5090 already emitted. Keep the IR valid
            # by skipping straight to the next test.
            self.builder.branch(next_bb);
            if next_bb is not end_bb {
                self.builder.position_at_end(next_bb);
            }
            continue;
        }
        if case.guard is not None {
            # Bind captures before the guard so the guard can reference them,
            # then gate the body on the guard result.
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
        # Case body — bind captures (the guard path already did, a repeat
        # store is harmless) then emit the statements.
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

"""Compute an i1 condition for whether `pat` matches `subj`.

Returns None for unsupported pattern kinds (after emitting E5090). Does
not perform capture binding — see _bind_match_pattern.
"""
impl NaIRGenPass._match_pattern_cond(
    pat: uni.MatchPattern, subj: ir.Value
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    if isinstance(pat, uni.MatchWild) {
        return ir.Constant(i1, 1);
    }
    if isinstance(pat, uni.MatchAs) {
        # `case x:` (no sub-pattern) matches anything; `case <p> as x:`
        # matches iff the sub-pattern matches.
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
        # OR is restricted to non-capturing alternatives (value / singleton /
        # wildcard / nested OR) so there is no ambiguity about which names a
        # matched alternative binds. The native capability authority
        # (`native_capability_violations`) rejects any other alternative
        # pre-codegen, so by the time we lower here every sub-pattern is valid.
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
    # MatchSequence / MatchMapping / MatchArch / MatchStar are not yet
    # lowered. The central capability sweep (native_capability_violations)
    # rejects them before emission starts, so this is a safety net for
    # pattern kinds the sweep's table does not list.
    self.emit(E5090, node_override=pat, kind="match pattern", name=type(pat).__name__);
    return None;
}

"""Emit an i1 equality test between `subj` and the value of `value_node`."""
impl NaIRGenPass._match_value_eq(
    subj: ir.Value, value_node: uni.UniNode
) -> (ir.Value | None) {
    pat = self._codegen_expr(value_node);
    if pat is None {
        return None;
    }
    # Reconcile integer widths (e.g. i1 singleton vs i64 subject, enum widths).
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

"""Bind capture names introduced by `pat` to `subj` (Python `case x:` /
`case <p> as x:`). Non-capturing patterns bind nothing."""
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

"""Generate assignment statement."""
impl NaIRGenPass._codegen_assignment(nd: uni.Assignment) -> None {
    # Empty collection literals on the RHS type themselves: the checker
    # stamps them with the expected type (bidirectional inference from the
    # annotation or the target's declared type), and the literal codegen
    # reads its own checked type. No emission-context hints are threaded.
    _rhs_errs_before = len(self.errors_had);
    value = self._codegen_expr(nd.value) if nd.value else None;
    # Handle set() constructor call with type annotation
    if value is None and isinstance(nd.value, uni.FuncCall) {
        func_name = self._get_name(nd.value.target);
        if func_name == "set" and nd.type_tag is not None {
            # set() constructor with type annotation - create the empty set
            # from the target's checker-stamped declared type.
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
                            # Mark as owned so assignment doesn't emit a spurious retain.
                            self._mark_owned(value);
                        }
                        break;
                    }
                }
            }
        }
    }
    if value is None {
        # An RHS that lowered to no value silently dropped the whole assignment
        # (the #6470 class). Make it loud -- unless this is a bare typed
        # declaration (`x: T;`, no initializer) or a deeper diagnostic already
        # pinpointed the cause.
        if nd.value is not None and len(self.errors_had) == _rhs_errs_before {
            self.emit(
                E5090,
                node_override=nd.value,
                kind="expression",
                name=type(nd.value).__name__
            );
        }
        return;
    }
    targets = nd.target if isinstance(nd.target, (list, tuple)) else [(nd.target)];
    for target_expr in targets {
        # Handle tuple unpacking: (a, b) = expr
        if isinstance(target_expr, uni.TupleVal) {
            self._codegen_tuple_unpack(target_expr.values, value, nd.value);
            continue;
        }
        # Handle field assignment: self.x = val or obj.field = val
        if isinstance(target_expr, uni.AtomTrailer) and target_expr.is_attr {
            if nd.aug_op is not None {
                # Augmented assignment on field: self.field += val
                # Load current field value, apply op, then store result
                _faug_errs = len(self.errors_had);
                field_val = self._codegen_field_aug_assign(
                    target_expr, value, nd.aug_op.value
                );
                if field_val is not None {
                    self._codegen_field_assign(target_expr, field_val);
                } elif len(self.errors_had) == _faug_errs {
                    # Field read / op could not be lowered: don't drop it silently.
                    self.emit(
                        E5090,
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
        # Handle index assignment: items[i] = val or expr[i] = val (lists or dicts)
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
                        # Check if this is a dict assignment (checked type first)
                        dict_type_key = self._dict_key_of(target_expr.target);
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
                                _idx_stored = True;
                            }
                        } else {
                            # List assignment: list[idx] = value
                            elem_type_name: (str | None) = (
                                self._infer_list_elem_type(target_val)
                            );
                            if elem_type_name is not None {
                                self._codegen_index_set(
                                    target_val, idx_val, value, elem_type_name
                                );
                                _idx_stored = True;
                            }
                        }
                    }
                }
            }
            if not _idx_stored and len(self.errors_had) == _idx_errs_before {
                # Subscript store dropped: container expr, index, or element/dict
                # type could not be resolved natively. Surface it (#6470 class).
                self.emit(
                    E5090,
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
            # Update existing variable
            alloca = self.local_vars[var_name];
            # If this is a typed re-declaration (x: T = ...) whose declared type
            # differs from the existing alloca's type, allocate a fresh alloca with
            # the correct type rather than silently storing through a wrongly-typed
            # pointer (e.g. x: bool in one branch and x: SomeStruct in another).
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
            is_inplace_set_op = False;  # Track set |= to skip RC release
            # Handle augmented assignment: +=, -=, *=, //=, %=
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
                        # String concatenation for +=
                        # Save RHS before overwriting value; it may be a fresh
                        # fstring / concat buffer that the caller owns (rc=1).
                        _aug_str_rhs = coerced;
                        value = self._emit_binary_op(Tok.PLUS, current, _aug_str_rhs);
                        if value is None {
                            value = current;
                        } else {
                            # Release the RHS temp if we own it (rc=1 fresh alloc).
                            # The concat borrowed it but did not retain it.
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
                        # Set difference_update via emitter
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
                    # Bitwise AND assignment / set intersection_update
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.and_(
                            current, coerced, name=f"{var_name}.and"
                        );
                    } elif isinstance(current.type, ir.PointerType) {
                        # Set intersection_update via emitter
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
                    # Bitwise OR assignment / set union
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.or_(
                            current, coerced, name=f"{var_name}.or"
                        );
                    } elif isinstance(current.type, ir.PointerType) {
                        # Dict |= (update) via emitter (checked type, then shape)
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
                            # Set union: iterate RHS set elements and add to LHS set
                            rhs_set = coerced;
                            lhs_set = current;
                            # Find the matching set helpers by type
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
                                    # Get RHS set len and elems
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
                                    # Loop: for i in range(rhs_len): lhs.add(rhs[i])
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
                                    # Keep the LHS set as the value (no change to pointer)
                                    value = lhs_set;
                                    is_inplace_set_op = True;
                                    # Release the RHS set via __rc_release_simple so the
                                    # refcount is decremented and the dtor_ptr dispatched.
                                    self._emit_rc_release_simple(
                                        rhs_set,
                                        op="op_assign",
                                        loc=f"{os.path.basename(
                                            self.ir_in.loc.mod_path
                                        )}:{nd.loc.first_line if nd.loc else 0}"
                                    );
                                    # RC-|=: The RHS alloca (e.g. `piece_targets`) still
                                    # holds the now-freed pointer.  Null it out so that
                                    # scope_exit / the next overwrite doesn't double-free.
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
                    # Bitwise XOR assignment / set symmetric_difference_update
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.xor(
                            current, coerced, name=f"{var_name}.xor"
                        );
                    } elif isinstance(current.type, ir.PointerType) {
                        # Set symmetric_difference_update via emitter
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
            # retain new value first (handles x=x safely), then release old.
            # Skip for in-place set/dict ops (|=, &=, ^=) — the LHS collection is
            # mutated in-place; releasing it here would be use-after-free.
            # skip retain if value is already owned (freshly returned from a
            # function call or constructor); rc=1 from callee, retaining would give rc=2.
            # skip all RC when assigning int→str (inttoptr cast). Raw C
            # pointers don't have the 16-byte RC header; retain/release would read
            # garbage before the allocation and call garbage addresses as dtors.
            _is_raw_int_ptr = getattr(coerced, 'opname', '') == 'inttoptr';
            if isinstance(alloca.type.pointee, ir.PointerType)
            and not is_inplace_set_op {
                if _is_raw_int_ptr {
                    # Raw pointer — mark exempt from scope cleanup
                    self.param_vars.add(var_name);
                } else {
                    if not self._is_owned(value) {
                        self._emit_rc_retain(
                            coerced,
                            op="assign",
                            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                                if nd.loc
                                else 0}"
                        );
                    }
                    # A rebound borrowed param already owns its slot: the
                    # entry-block +1 was emitted at function setup from the
                    # central analysis fact (compiler/ownership.jac), so the
                    # release-of-old below is balanced on every path.
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
            self.builder.store(coerced, alloca);
        } elif var_name in self.global_vars
        and isinstance(target_expr, uni.NameAtom)
        and target_expr.sym is not None
        and target_expr.sym.storage == uni.SymbolStorage.MODULE_GLOBAL {
            # Store to a module global. The symbol table is the single owner
            # of this fact: module-level code binds names to module symbols,
            # and an explicit `global var;` rebinds the function-scope name to
            # the module symbol (sym_tab_build_pass.bind_global_stmt). A bare
            # function-scope assignment to a glob-named variable binds a
            # shadow LOCAL symbol, so it does NOT land here — it falls through
            # to the `else` branch and allocates a function-local, matching
            # CPython and the sv pathway.
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
                        # Set difference_update
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
                        # Set intersection_update
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
                        # Set union (update)
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
                        # Set symmetric_difference_update
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
            # retain new, release old for pointer-typed globals.
            # skip retain if value is already owned (freshly returned from call).
            # skip RC entirely for raw int→ptr casts (no RC header).
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
            # New variable — allocate and store
            var_type = value.type;
            if nd.type_tag and nd.type_tag.tag {
                tag_node = nd.type_tag.tag;
                # Bare unparameterized collection annotations (list/dict/set/frozenset):
                # infer the variable type from the RHS value rather than defaulting,
                # so `a: list = [1, 2]`, `d: dict = {"k": v}`, `s: set = {1, 2}` all work
                # regardless of element types.
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
                    # Verify value is actually a known collection pointer
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
                    var_type = value.type;  # element type inferred from RHS literal
                } else {
                    var_type = self._resolve_jac_type(tag_node);
                    value = self._coerce_type(value, var_type);
                }
            }
            alloca = self._entry_alloca(var_type, var_name);
            # RC loop-local init: for pointer-typed locals, null-initialize the alloca
            # in the entry block (right after the alloca itself, which _entry_alloca
            # prepends to instructions[0]).  On the first loop iteration old=null so
            # __rc_release_simple is a safe no-op; on subsequent iterations old holds
            # the previous allocation which is then properly freed.
            if isinstance(var_type, ir.PointerType) {
                _func_e = self.builder.function;
                _ebb = _func_e.entry_basic_block;
                _cur_bb = self.builder.block;
                _entry_instrs = list(_ebb.instructions);
                # alloca is at instructions[0]; null-store goes right after it.
                if len(_entry_instrs) >= 2 {
                    self.builder.position_before(_entry_instrs[1]);
                } else {
                    self.builder.position_at_end(_ebb);
                }
                self.builder.store(ir.Constant(var_type, None), alloca);
                self.builder.position_at_end(_cur_bb);
            }
            # retain new, then release old (null on first pass → no-op).
            # Mirrors the existing-variable path so loop-local pointer vars are freed
            # on every iteration, not just when the enclosing scope exits.
            # skip all RC for raw int→str (inttoptr) casts.
            if isinstance(var_type, ir.PointerType) {
                if getattr(value, 'opname', '') == 'inttoptr' {
                    # Raw C pointer — no RC header; exempt from scope cleanup.
                    self.param_vars.add(var_name);
                } else {
                    if not self._is_owned(value) {
                        self._emit_rc_retain(
                            value,
                            op="assign",
                            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                                if nd.loc
                                else 0}"
                        );
                    }
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
            self.builder.store(value, alloca);
            self.local_vars[var_name] = alloca;
        }
        # Associate pending lambda captures with this variable name
        if self._pending_lambda_captures is not None {
            self.lambda_captures[var_name] = self._pending_lambda_captures;
            self._pending_lambda_captures = None;
        }
        # Seed the boxed-tuple element-struct shape from the literal that
        # produced this value (if any), so `(a, b) = var.pop()` on a bare
        # `list` can recover the tuple type later. See #6435.
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

# ─── Expression Codegen ──────────────────────────────────────
"""Generate break or continue statement."""
impl NaIRGenPass._codegen_ctrl(nd: uni.CtrlStmt) -> None {
    ctrl_name = nd.ctrl.name if isinstance(nd.ctrl, uni.Token) else str(nd.ctrl);
    # `skip` is Return-family, not loop control: the py target lowers it to a
    # bare `return` and cl to a ReturnStatement (issue #6206). It must NOT
    # fall under the loop_stack guard below — dropping it turns a
    # `if <seen> { skip; }` visit-once guard into dead code, the silent wrong
    # answer of issue #6636. Statements after it are skipped by the
    # is_terminated check, mirroring disengage.
    #
    # `skip` outside a void (event-ability) body is rejected up front by the
    # capability sweep (`native_capability_violations`), which runs before any
    # codegen on BOTH `jac check` and `jac nacompile`, so a value-returning
    # body never reaches here. The non-void branch below is a defensive
    # backstop: a clean E5090 rather than an invalid `ret void` in a typed fn.
    if ctrl_name == Tok.KW_SKIP {
        if isinstance(self.builder.function.function_type.return_type, ir.VoidType) {
            self.builder.ret_void();
        } else {
            self.emit(
                E5090,
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

# ─── Phase 1: For Loops ──────────────────────────────────────
"""Generate for loop (currently supports range(n) and range(start, stop))."""
impl NaIRGenPass._codegen_for(nd: uni.InForStmt) -> None {
    # Iterator protocol (#6403): map/filter/enumerate/zip/iter collections are
    # driven through first-class JacIter objects. Container collections (plain
    # list/str/dict/range) fall through to the indexed skeleton below.
    if self._try_iter_protocol_for(nd) {
        return;
    }
    # Baseline for the silent-drop guards below: a `for` whose loop var,
    # collection, or element type can't be lowered natively used to drop the
    # entire loop body without a word (the #6470 class). Emit E5090 at each
    # dead-end unless a deeper diagnostic already fired.
    _for_errs0 = len(self.errors_had);
    loop_var_name = self._get_name(nd.target);
    # ── Dict .items() iteration: for (k, v) in d.items() ──
    # Matched structurally (tuple target + .items() on a checked dict);
    # the single-name guard below never applies to this form.
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
                E5090,
                node_override=nd,
                kind="for-loop target",
                name=type(nd.target).__name__
            );
        }
        return;
    }
    # ── range(...) iteration: the loop var IS the index ──
    if isinstance(nd.collection, uni.FuncCall)
    and self._get_name(nd.collection.target) == "range"
    and nd.collection.call_kind == "builtin" {
        params = nd.collection.params or [];
        start_val: (ir.Value | None) = None;
        stop_val: (ir.Value | None) = None;
        if len(params) == 1 {
            start_val = ir.Constant(ir.IntType(64), 0);
            stop_val = self._codegen_expr(params[0]);
        } elif len(params) >= 2 {
            start_val = self._codegen_expr(params[0]);
            stop_val = self._codegen_expr(params[1]);
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
                range_start=self._coerce_type(start_val, ir.IntType(64))
            );
            return;
        }
    }
    # ── Evaluate the collection expression AT MOST ONCE ──
    # Re-calling _codegen_expr(nd.collection) re-emits its side effects: for a
    # call like `for x in obj.method()` each re-eval invokes the method again,
    # doing the work N times AND leaking the unused results.
    coll_name = self._get_name(nd.collection);
    _coll_memo: (ir.Value | None) = self._codegen_expr(nd.collection);
    # ── Dict iteration: for k in dict ── (dict-ness from the checked type,
    # with an LLVM-shape fallback for untracked field access)
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
    # ── Iterate an `any` (boxed JacVal) ── for e in x where x: any ──
    # The value holds a list[any] (the canonical heterogeneous layout that
    # json.loads / the Mechanism-B tier produce); unbox to List.jacval* and
    # drive the standard indexed list loop, yielding `any` (JacVal) elements,
    # so `parsed` from a loads() result is directly walkable. dict/set/str
    # iteration over a bare `any` should narrow first (`d: dict[str, any] = x;`),
    # the form json.dumps uses. (#6943 NA-4)
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
    # ── Bytes iteration: for x in b ── yields i64 byte values (#6749).
    # A distinct struct type, so it precedes the str/list paths cleanly.
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
    # ── String iteration: for c in s ── (before the list path: a raw i8*
    # would otherwise be misclassified as list[ptr])
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
    # ── List iteration: for x in items ──
    if _coll_memo is None {
        if len(self.errors_had) == _for_errs0 {
            self.emit(
                E5090,
                node_override=nd.collection,
                kind="for-loop iterable",
                name=type(nd.collection).__name__ if nd.collection else "<expr>"
            );
        }
        return;
    }
    # Element type: LLVM value shape, then the checked element type, then
    # ptr for unknown non-set pointers.
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
        # Iterable whose native element type / list helpers couldn't be
        # resolved: don't drop the loop body silently (#6470 class).
        if len(self.errors_had) == _for_errs0 {
            self.emit(
                E5090,
                node_override=nd.collection or nd,
                kind="for-loop iterable element type",
                name=(coll_name or "<expr>")
            );
        }
        return;
    }
    # Resolve the inner element type for ptr lists from the checked type.
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
        elem_cast=inner_type
    );
}

"""One indexed-loop skeleton for every native `for` form.

`kind` selects the per-iteration element fetch: "range" (the loop var is
the index itself; `collection_val` is the stop value and `range_start`
the initial value), "list" (helpers.get, optional `elem_cast` to the
checked inner type), "dict" (helpers.get_key), "items" (helpers.get_key
+ get_val into two loop vars), "str" (fresh one-char string per index).
`rc_vars` enables the pointer loop-variable discipline (entry null-init,
pre-loop reset of a reused alloca, release-old/retain-new per iteration)
so scope-exit releases stay balanced. The loop-body locals snapshot and
back-edge release (`_emit_loop_iter_cleanup`), break/continue targets
(`loop_stack`), and the owned-temporary collection release at loop end
all live HERE - one emission home instead of one copy per iteration
form."""
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
    elem_cast: (ir.Type | None) = None
) -> None {
    i64 = ir.IntType(64);
    _for_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.last_line
        if nd.loc
        else 0}";
    _rc_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    # Loop bound and index. For range, the loop variable doubles as the
    # index and counts from range_start to collection_val (the stop).
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
        for (vi, vname) in enumerate(var_names) {
            vtype = var_types[vi];
            # Reuse a prior alloca of the same shape (two consecutive loops
            # over the same name): a fresh one would be orphaned - scope
            # exit only sees local_vars[name], so the reference retained in
            # the old alloca would never be released.
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
                    # Null-init IN THE ENTRY BLOCK so release-old is a no-op
                    # on the first iteration and scope exit is safe when the
                    # body never runs.
                    _saved_block = self.builder.block;
                    self.builder.position_after(alloca);
                    self.builder.store(null_const, alloca);
                    self.builder.position_at_end(_saved_block);
                }
                if rc_vars {
                    # Release whatever the alloca holds from a previous outer
                    # iteration or a previous loop reusing this name, then
                    # reset to null (first run releases null - no-op).
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
    cmp = self.builder.icmp_signed("<", cur_idx, len_val, name="for.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);
    self.loop_stack.append((incr_bb, end_bb));
    self.builder.position_at_end(body_bb);
    # Per-kind element fetch into the loop variable(s).
    if kind != "range" {
        body_idx = self.builder.load(idx_alloca, name="for.body.idx");
        if kind == "items" {
            key_val = self.builder.call(
                helpers["get_key"], [collection_val, body_idx], name="for.key"
            );
            val_val = self.builder.call(
                helpers["get_val"], [collection_val, body_idx], name="for.val"
            );
            # `get_key`/`get_val` hand back BORROWED pointers into the dict's
            # backing arrays. Pointer loop vars land in `local_vars`, so scope
            # exit releases them; without a matching retain the dict's last
            # key/val are over-released and their heap backing is freed under
            # the still-live dict (issue #6688). Mirror the list/dict discipline
            # below: release the prior occupant (null on the first pass) and
            # retain the new borrow so the scope-exit release stays balanced.
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
            # Load the byte at body_idx and zero-extend to the i64 loop var.
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
            # Pointer loop var: release the old value (null on first
            # iteration) and retain the new one so scope-exit's release
            # stays balanced - without this the last element would be
            # double-freed (container destructor + scope cleanup).
            if rc_vars and isinstance(var_types[0], ir.PointerType) {
                old_val = self.builder.load(allocas[0], name="for.old");
                self._emit_rc_release_simple(old_val, op="for_elem", loc=_rc_loc);
                self._emit_rc_retain(elem_val, op="for_elem", loc=_rc_loc);
            }
            self.builder.store(elem_val, allocas[0]);
        } else {
            # Internal contract: every iteration form must be dispatched
            # explicitly - an unknown kind means a dispatcher bug, never a
            # user error.
            self.emit(
                E9002,
                node_override=nd,
                details=f"unknown for-loop iteration kind '{kind}'"
            );
            return;
        }
    }
    import from jaclang.compiler.ownership { loop_body_locals }
    _for_saved = loop_body_locals(
        nd.body if isinstance(nd.body, (list, tuple)) else None
    );
    # Snapshot the locals that already exist before the body so per-iteration
    # cleanup never releases an enclosing-scope accumulator. A variable declared
    # outside the loop but mutated inside it (`out += k`, `out = out + k`) can
    # bind to a symbol whose only `defn` is that in-loop assignment when an
    # enclosing block adds a scope level, so loop_body_locals misclassifies it as
    # a fresh per-iteration local; releasing it then frees the accumulator under
    # the next iteration (use-after-free; #6943 NA-2). Its storage predates the
    # body, so excluding pre-existing names is the robust guard. (#6943 NA-2)
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
    next_idx = self.builder.add(inc_idx, ir.Constant(i64, 1), name="for.next.idx");
    self.builder.store(next_idx, idx_alloca);
    self.builder.branch(cond_bb);
    self.builder.position_at_end(end_bb);
    # An owned temporary collection (call result, literal) was consumed by
    # the loop - release it. A named variable / field load is borrowed and
    # its owner frees it.
    if coll_release_op
    and isinstance(collection_val.type, ir.PointerType)
    and self._is_owned(collection_val) {
        self._emit_rc_release_simple(collection_val, op=coll_release_op, loc=_for_loc);
    }
}
# ─── Phase 1: Ternary If-Else Expression ─────────────────────
