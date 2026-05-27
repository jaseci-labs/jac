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
    if self.builder is None or self.builder.block.is_terminated {
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
        cond = self._codegen_expr(nd.condition);
        if cond is not None {
            cond_bool = self._to_bool(cond);
            # assert fires when condition is FALSE
            is_false = self.builder.not_(cond_bool, name="assert.fail");
            self._emit_runtime_raise(is_false, "AssertionError", "assertion failed");
        }
    } elif isinstance(nd, uni.DeleteStmt) {
        # del d[k]  →  d.remove(k)
        target_expr = nd.target;
        if (
            isinstance(target_expr, uni.AtomTrailer)
            and not target_expr.is_attr
            and target_expr.right?.slices
        ) {
            slices = target_expr.right.slices or [];
            if slices {
                idx_target_name = self._get_name(target_expr.target);
                # Only handle known dict variables
                dict_type_key: (str | None) = None;
                if idx_target_name is not None
                and idx_target_name in self.var_dict_type {
                    dict_type_key = self.var_dict_type[idx_target_name];
                }
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
        # `global`/`nonlocal` are declarations consumed by the symbol
        # table; the corresponding Name/Assignment nodes do the actual
        # codegen. We still record the declared names so a later
        # `x = ...` in this function rebinds the module global instead of
        # allocating a function-local (see _codegen_assignment). Without an
        # explicit `global x;`, a function-scope assignment is a local —
        # matching CPython and the sv pathway.
        for _g_target in nd.target {
            _g_name = self._get_name(_g_target);
            if _g_name is not None {
                self._declared_globals.add(_g_name);
            }
        }
    } elif isinstance(nd, uni.PyInlineCode) {
        # ::py:: blocks are intentionally stripped from native output —
        # they target the Python pathway only.
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
        # Set list type hint from function return type for list comprehensions
        self._list_type_hint = None;
        self._dict_val_type_hint = None;
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
            # Check if return type is a dict with JacVal values (dict[str, any])
            if ret_type_name.startswith("%\"Dict.") and "jacval" in ret_type_name {
                self._dict_val_type_hint = "jacval";
            }
        }
        # Flag return-tuple context so borrowed pointer elements are retained
        # as they are packed (the tuple box does not own its elements, and the
        # owning local is torn down at scope exit below).
        self._return_tuple_ctx = isinstance(nd.expr, uni.TupleVal);
        val = self._codegen_expr(nd.expr);
        self._return_tuple_ctx = False;
        self._list_type_hint = None;
        self._dict_val_type_hint = None;
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
    cond = self._codegen_expr(nd.condition);
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
    cond = self._codegen_expr(nd.condition);
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
    _while_saved_locals = set(self.local_vars.keys());
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    if not self.builder.block.is_terminated {
        _while_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.last_line
            if nd.loc
            else 0}";
        self._emit_loop_iter_cleanup(_while_saved_locals, loc=_while_loc);
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
    cond = self._codegen_expr(nd.condition);
    if cond is not None {
        cond = self._to_bool(cond);
        self.builder.cbranch(cond, body_bb, end_bb);
    } else {
        self.builder.branch(end_bb);
    }
    # Body block — continue lands on the step block so the counter advances.
    self.loop_stack.append((step_bb, end_bb));
    self.builder.position_at_end(body_bb);
    _saved_locals = set(self.local_vars.keys());
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    _loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.last_line
        if nd.loc
        else 0}";
    if not self.builder.block.is_terminated {
        self._emit_loop_iter_cleanup(_saved_locals, loc=_loc);
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
        # OR is restricted to non-capturing alternatives so there is no
        # ambiguity about which names a matched alternative binds.
        result: (ir.Value | None) = None;
        for sub in pat.patterns {
            if not isinstance(
                sub, (uni.MatchValue, uni.MatchSingleton, uni.MatchWild, uni.MatchOr)
            ) {
                self.emit(
                    E5090,
                    node_override=sub,
                    kind="match pattern",
                    name=f"{type(sub).__name__} inside OR pattern"
                );
                return None;
            }
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
    # MatchSequence / MatchMapping / MatchArch / MatchStar are not yet lowered.
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
    # Set list type hint from context before evaluating expression
    # This helps _codegen_list_val create the correct empty list type
    self._list_type_hint = None;
    # 1. From explicit type annotation: var: list[T] = []
    if nd.type_tag and nd.type_tag.tag {
        hint = self._get_list_elem_from_type_node(nd.type_tag.tag);
        if hint is not None {
            self._list_type_hint = hint;
        }
    }
    # 2. From field target: self.field = [] where field has known list type
    if self._list_type_hint is None {
        check_targets = nd.target
            if isinstance(nd.target, (list, tuple))
            else [(nd.target)];
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
    # 3. From existing variable's tracked list element type (for reassignment/globals)
    if self._list_type_hint is None {
        check_targets = nd.target
            if isinstance(nd.target, (list, tuple))
            else [(nd.target)];
        for ct in check_targets {
            ct_name = self._get_name(ct);
            if ct_name is not None and ct_name in self.var_list_elem_type {
                self._list_type_hint = self.var_list_elem_type[ct_name];
                break;
            }
        }
    }
    # Set dict val type hint for dict[str, any] support
    self._dict_val_type_hint = None;
    if nd.type_tag and nd.type_tag.tag {
        tag_node = nd.type_tag.tag;
        tag_name = self._get_name(tag_node);
        if tag_name == "dict" and isinstance(tag_node, uni.AtomTrailer) {
            if tag_node?.right and tag_node.right?.slices {
                slices = tag_node.right.slices or [];
                val_node: (object | None) = None;
                if len(slices) == 1
                and slices[0]?.start
                and isinstance(slices[0].start, uni.TupleVal) {
                    tv = slices[0].start;
                    if tv.values and len(tv.values) >= 2 {
                        val_node = tv.values[1];
                    }
                } elif len(slices) >= 2 {
                    val_node = slices[1];
                    if val_node?.start and val_node.start is not None {
                        val_node = val_node.start;
                    }
                }
                if val_node is not None {
                    val_name = self._get_name(val_node);
                    if val_name == "any" {
                        self._dict_val_type_hint = "jacval";
                    }
                }
            }
        }
    }
    value = self._codegen_expr(nd.value) if nd.value else None;
    self._list_type_hint = None;
    self._dict_val_type_hint = None;
    # Handle empty dict literal {} with type annotation
    if value is None and isinstance(nd.value, uni.DictVal) {
        if not nd.value.kv_pairs {
            _edict_type_tag = nd.type_tag.tag
                if nd.type_tag and nd.type_tag.tag
                else None;
            # Fallback: no explicit type annotation but target is obj.field = {} —
            # infer the dict type from field_type_node so we emit __dict_new_*().
            if _edict_type_tag is None {
                _check_targets = nd.target
                    if isinstance(nd.target, (list, tuple))
                    else [(nd.target)];
                for _ct in _check_targets {
                    if isinstance(_ct, uni.AtomTrailer) and _ct.is_attr {
                        _ct_target_name = self._get_name(_ct.target);
                        _ct_field_name = self._get_name(_ct.right);
                        if _ct_target_name is not None and _ct_field_name is not None {
                            _ct_type_name = self.type_var_map.get(_ct_target_name);
                            if _ct_type_name is not None
                            and _ct_type_name in self.field_type_node {
                                _ftn = self.field_type_node[_ct_type_name].get(
                                    _ct_field_name
                                );
                                if _ftn is not None {
                                    _edict_type_tag = _ftn;
                                }
                            }
                        }
                    }
                    if _edict_type_tag is not None {
                        break;
                    }
                }
            }
            if _edict_type_tag is not None {
                # Empty dict with type hint - create empty dict of correct type
                dict_type = self._resolve_jac_type(_edict_type_tag);
                if isinstance(dict_type, ir.PointerType) {
                    # Find the dict helpers for this type
                    for (dict_key, dtype) in self.dict_types.items() {
                        if dict_type == dtype.as_pointer() {
                            helpers = self.dict_helpers.get(dict_key);
                            if helpers is not None {
                                value = self.builder.call(
                                    helpers["new"], [], name="dict.new"
                                );
                                # RC: fresh allocation — caller owns it; skip RETAIN on assign.
                                self._mark_owned(value);
                            }
                            break;
                        }
                    }
                }
            }
        }
    }
    # Handle empty set literal {} that should be a set with type annotation
    if value is None and isinstance(nd.value, uni.SetVal) {
        if not nd.value.values and nd.type_tag and nd.type_tag.tag {
            # Empty set with type hint - create empty set of correct type
            set_type = self._resolve_jac_type(nd.type_tag.tag);
            if isinstance(set_type, ir.PointerType) {
                # Find the set helpers for this type
                for (elem_name, stype) in self.set_types.items() {
                    if set_type == stype.as_pointer() {
                        helpers = self.set_helpers.get(elem_name);
                        if helpers is not None {
                            value = self.builder.call(
                                helpers["new"], [], name="set.new"
                            );
                            # RC: fresh allocation — caller owns it; skip RETAIN on assign.
                            self._mark_owned(value);
                        }
                        break;
                    }
                }
            }
        }
    }
    # Handle set() constructor call with type annotation
    if value is None and isinstance(nd.value, uni.FuncCall) {
        func_name = self._get_name(nd.value.target);
        if func_name == "set" and nd.type_tag and nd.type_tag.tag {
            # set() constructor with type annotation - create empty set
            set_type = self._resolve_jac_type(nd.type_tag.tag);
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
                field_val = self._codegen_field_aug_assign(
                    target_expr, value, nd.aug_op.value
                );
                if field_val is not None {
                    self._codegen_field_assign(target_expr, field_val);
                }
            } else {
                self._codegen_field_assign(target_expr, value);
            }
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
                        # Dict |= (update) via emitter
                        if var_name in self.var_dict_type {
                            dict_type_key = self.var_dict_type[var_name];
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
                    # First reassignment of a borrowed param: emit an entry-block retain
                    # so the alloca becomes owned and the release-of-old below is balanced
                    # (avoids double-free with the caller's own scope-exit release).
                    if var_name in self.param_vars {
                        if var_name not in self._param_promoted {
                            _anchor = self._param_store_instr.get(var_name);
                            if _anchor is not None
                            and isinstance(alloca.type, ir.PointerType)
                            and isinstance(alloca.type.pointee, ir.PointerType) {
                                _saved_block = self.builder.block;
                                self.builder.position_after(_anchor);
                                _borrowed = self.builder.load(
                                    alloca, name=f"{var_name}.borrowed"
                                );
                                self._emit_rc_retain(
                                    _borrowed,
                                    op="param_promote",
                                    loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                                        if nd.loc
                                        else 0}"
                                );
                                self.builder.position_at_end(_saved_block);
                            }
                            self._param_promoted.add(var_name);
                        }
                        self.param_vars.discard(var_name);
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
            self.builder.store(coerced, alloca);
        } elif var_name in self.global_vars
        and (self._in_module_scope or var_name in self._declared_globals) {
            # Store to a module global. Only reached for module-level code
            # (_in_module_scope) or after an explicit `global var;` declared
            # the name in this function (_declared_globals). A bare
            # function-scope assignment to a glob-named variable does NOT land
            # here — it falls through to the `else` branch and allocates a
            # function-local, matching CPython and the sv pathway.
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
        if nd.type_tag and nd.type_tag.tag {
            tag_node = nd.type_tag.tag;
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
            # Track enum type for enum-typed variables
            if tag_name is not None and tag_name in self.enum_types {
                self.var_enum_type[var_name] = tag_name;
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
        # Track tuple type for tuple variables (value or pointer tuples)
        ttrack_struct: (ir.LiteralStructType | None) = None;
        if isinstance(value.type, ir.LiteralStructType) {
            ttrack_struct = value.type;
        } elif isinstance(value.type, ir.PointerType)
        and isinstance(value.type.pointee, ir.LiteralStructType) {
            ttrack_struct = value.type.pointee;
        }
        if ttrack_struct is not None {
            for (tkey, ttype) in self.tuple_types.items() {
                if str(ttrack_struct) == str(ttype) {
                    self.var_tuple_type[var_name] = tkey;
                    break;
                }
            }
        }
        # Track complex variables
        if value.type == self.complex_struct_type.as_pointer() {
            self.var_complex.add(var_name);
        }
        # Track range variables
        if value.type == self.range_struct_type.as_pointer() {
            self.var_range.add(var_name);
        }
        # Track slice variables
        if value.type == self.slice_struct_type.as_pointer() {
            self.var_slice.add(var_name);
        }
    }
}

# ─── Expression Codegen ──────────────────────────────────────
"""Generate break or continue statement."""
impl NaIRGenPass._codegen_ctrl(nd: uni.CtrlStmt) -> None {
    if not self.loop_stack {
        return;
    }
    ctrl_name = nd.ctrl.name if isinstance(nd.ctrl, uni.Token) else str(nd.ctrl);
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
    # Extract loop variable name
    loop_var_name = self._get_name(nd.target);
    if loop_var_name is None {
        return;
    }
    _for_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.last_line
        if nd.loc
        else 0}";
    # Detect range() calls
    start_val: (ir.Value | None) = None;
    stop_val: (ir.Value | None) = None;
    if isinstance(nd.collection, uni.FuncCall) {
        call_name = self._get_name(nd.collection.target);
        if call_name == "range" {
            params = nd.collection.params or [];
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
        alloca = self._entry_alloca(ir.IntType(64), loop_var_name);
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
        _for_saved = set(self.local_vars.keys());
        if isinstance(nd.body, (list, tuple)) {
            self._codegen_body(nd.body);
        }
        if not self.builder.block.is_terminated {
            self._emit_loop_iter_cleanup(_for_saved, loc=_for_loc);
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
    # ── Dict .items() iteration: for (k, v) in d.items() ──
    if isinstance(nd.target, uni.TupleVal)
    and isinstance(nd.collection, uni.FuncCall) {
        coll_call = nd.collection;
        if isinstance(coll_call.target, uni.AtomTrailer) and coll_call.target.is_attr {
            items_method = self._get_name(coll_call.target.right);
            items_base = self._get_name(coll_call.target.target);
            if (
                items_method == "items"
                and items_base is not None
                and items_base in self.var_dict_type
            ) {
                dict_type_key = self.var_dict_type[items_base];
                helpers = self.dict_helpers.get(dict_type_key);
                unpack_targets = nd.target.values or [];
                if helpers is not None and len(unpack_targets) == 2 {
                    key_var_name = self._get_name(unpack_targets[0]);
                    val_var_name = self._get_name(unpack_targets[1]);
                    if key_var_name is not None and val_var_name is not None {
                        collection_val = self._codegen_expr(coll_call.target.target);
                        if collection_val is not None {
                            i64 = ir.IntType(64);
                            key_type = helpers["key_type"];
                            val_type = helpers["val_type"];
                            len_val = self.builder.call(
                                helpers["len"], [collection_val], name="fori.len"
                            );
                            idx_alloca = self._entry_alloca(i64, "fori.idx");
                            self.builder.store(ir.Constant(i64, 0), idx_alloca);
                            key_alloca = self._entry_alloca(key_type, key_var_name);
                            val_alloca = self._entry_alloca(val_type, val_var_name);
                            self.local_vars[key_var_name] = key_alloca;
                            self.local_vars[val_var_name] = val_alloca;
                            func = self.builder.function;
                            cond_bb = func.append_basic_block(name="fori.cond");
                            body_bb = func.append_basic_block(name="fori.body");
                            incr_bb = func.append_basic_block(name="fori.incr");
                            end_bb = func.append_basic_block(name="fori.end");
                            self.builder.branch(cond_bb);
                            self.builder.position_at_end(cond_bb);
                            cur_idx = self.builder.load(
                                idx_alloca, name="fori.cur.idx"
                            );
                            cmp = self.builder.icmp_signed(
                                "<", cur_idx, len_val, name="fori.cmp"
                            );
                            self.builder.cbranch(cmp, body_bb, end_bb);
                            self.loop_stack.append((incr_bb, end_bb));
                            self.builder.position_at_end(body_bb);
                            body_idx = self.builder.load(
                                idx_alloca, name="fori.body.idx"
                            );
                            key_val = self.builder.call(
                                helpers["get_key"],
                                [collection_val, body_idx],
                                name="fori.key"
                            );
                            val_val = self.builder.call(
                                helpers["get_val"],
                                [collection_val, body_idx],
                                name="fori.val"
                            );
                            self.builder.store(key_val, key_alloca);
                            self.builder.store(val_val, val_alloca);
                            _for_saved = set(self.local_vars.keys());
                            if isinstance(nd.body, (list, tuple)) {
                                self._codegen_body(nd.body);
                            }
                            if not self.builder.block.is_terminated {
                                self._emit_loop_iter_cleanup(_for_saved, loc=_for_loc);
                                self.builder.branch(incr_bb);
                            }
                            self.loop_stack.pop();
                            self.builder.position_at_end(incr_bb);
                            inc_idx = self.builder.load(
                                idx_alloca, name="fori.inc.idx"
                            );
                            next_idx = self.builder.add(
                                inc_idx, ir.Constant(i64, 1), name="fori.next.idx"
                            );
                            self.builder.store(next_idx, idx_alloca);
                            self.builder.branch(cond_bb);
                            self.builder.position_at_end(end_bb);
                            return;
                        }
                    }
                }
            }
        }
    }
    # ── Dict iteration: for k in dict ──
    # Only use dict iteration if the collection variable is explicitly tracked as a dict
    # (This avoids premature code generation from type inference)
    coll_name = self._get_name(nd.collection);
    dict_type_key: (str | None) = None;
    if coll_name is not None and coll_name in self.var_dict_type {
        dict_type_key = self.var_dict_type[coll_name];
    }
    # Fallback: for field access (e.g. c.props) where coll_name is None or not
    # tracked, evaluate the expression and infer the dict type from its LLVM type.
    _ford_coll_val: (ir.Value | None) = None;
    if dict_type_key is None {
        _ford_coll_val = self._codegen_expr(nd.collection);
        if _ford_coll_val is not None {
            dict_info = self._infer_dict_type(_ford_coll_val);
            if dict_info is not None {
                dict_type_key = f"{dict_info[0]}:{dict_info[1]}";
            }
        }
    }
    if dict_type_key is not None {
        # This is dict iteration
        helpers = self.dict_helpers.get(dict_type_key);
        if helpers is not None {
            collection_val = (
                _ford_coll_val
                    if _ford_coll_val is not None
                    else self._codegen_expr(nd.collection)
            );
            if collection_val is not None {
                i64 = ir.IntType(64);
                key_type = helpers["key_type"];
                # Get dict length
                len_val = self.builder.call(
                    helpers["len"], [collection_val], name="ford.len"
                );
                # Allocate loop index
                idx_alloca = self._entry_alloca(i64, "ford.idx");
                self.builder.store(ir.Constant(i64, 0), idx_alloca);
                # Allocate loop variable (key)
                loop_alloca = self._entry_alloca(key_type, loop_var_name);
                # Null-initialize so cleanup __rc_release_simple null-check is
                # safe when the loop body never executes (empty dict) and so
                # the old-value release inside the loop body is a no-op on the
                # first iteration.
                if isinstance(key_type, ir.PointerType) {
                    self.builder.store(ir.Constant(key_type, None), loop_alloca);
                }
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
                # For pointer-typed keys: release the old value (null on first
                # iteration → no-op) and retain the new key so that scope
                # cleanup's __rc_release_simple call is balanced.
                # Without this, the last key in the dict would be double-freed:
                # once by the dict's own destructor and once by scope cleanup.
                if isinstance(key_type, ir.PointerType) {
                    old_key_val = self.builder.load(loop_alloca, name="ford.old");
                    self._emit_rc_release_simple(
                        old_key_val,
                        op="ford_key",
                        loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                            if nd.loc
                            else 0}"
                    );
                    self._emit_rc_retain(
                        key_val,
                        op="ford_key",
                        loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                            if nd.loc
                            else 0}"
                    );
                }
                self.builder.store(key_val, loop_alloca);
                _for_saved = set(self.local_vars.keys());
                if isinstance(nd.body, (list, tuple)) {
                    self._codegen_body(nd.body);
                }
                if not self.builder.block.is_terminated {
                    self._emit_loop_iter_cleanup(_for_saved, loc=_for_loc);
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
    # ── String iteration: for c in str ──
    # Must be checked before the list path: a raw `i8*` string would otherwise
    # be misclassified as a `list[ptr]` and hit a type-mismatch when calling
    # the List.ptr helpers.
    coll_name_str = self._get_name(nd.collection);
    is_list_coll = (
        coll_name_str is not None and coll_name_str in self.var_list_elem_type
    );
    is_dict_coll = coll_name_str is not None and coll_name_str in self.var_dict_type;
    if not is_list_coll and not is_dict_coll {
        str_coll_val = self._codegen_expr(nd.collection);
        i8p_s = ir.IntType(8).as_pointer();
        if str_coll_val is not None and str_coll_val.type == i8p_s {
            i64 = ir.IntType(64);
            strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p_s]);
            str_len = self.builder.call(strlen_fn, [str_coll_val], name="fors.len");
            idx_alloca = self._entry_alloca(i64, "fors.idx");
            self.builder.store(ir.Constant(i64, 0), idx_alloca);
            loop_alloca = self._entry_alloca(i8p_s, loop_var_name);
            # Zero-initialize so __rc_release_simple null-check is safe when
            # the loop body never executes (e.g. iterating an empty string).
            self.builder.store(ir.Constant(i8p_s, None), loop_alloca);
            self.local_vars[loop_var_name] = loop_alloca;
            func = self.builder.function;
            cond_bb = func.append_basic_block(name="fors.cond");
            body_bb = func.append_basic_block(name="fors.body");
            incr_bb = func.append_basic_block(name="fors.incr");
            end_bb = func.append_basic_block(name="fors.end");
            self.builder.branch(cond_bb);
            self.builder.position_at_end(cond_bb);
            cur_idx = self.builder.load(idx_alloca, name="fors.cur.idx");
            cmp = self.builder.icmp_signed("<", cur_idx, str_len, name="fors.cmp");
            self.builder.cbranch(cmp, body_bb, end_bb);
            self.loop_stack.append((incr_bb, end_bb));
            self.builder.position_at_end(body_bb);
            body_idx = self.builder.load(idx_alloca, name="fors.body.idx");
            char_str = self._codegen_string_index(str_coll_val, body_idx);
            if char_str is not None {
                self.builder.store(char_str, loop_alloca);
            }
            _for_saved = set(self.local_vars.keys());
            if isinstance(nd.body, (list, tuple)) {
                self._codegen_body(nd.body);
            }
            if not self.builder.block.is_terminated {
                self._emit_loop_iter_cleanup(_for_saved, loc=_for_loc);
                self.builder.branch(incr_bb);
            }
            self.loop_stack.pop();
            self.builder.position_at_end(incr_bb);
            inc_idx = self.builder.load(idx_alloca, name="fors.inc.idx");
            next_idx = self.builder.add(
                inc_idx, ir.Constant(i64, 1), name="fors.next.idx"
            );
            self.builder.store(next_idx, idx_alloca);
            self.builder.branch(cond_bb);
            self.builder.position_at_end(end_bb);
            return;
        }
    }
    # ── List iteration: for x in items ──
    # Set list type hint in case collection is a list literal
    self._list_type_hint = None;
    coll_name = self._get_name(nd.collection);
    # Infer elem type hint from collection variable's type node
    if coll_name is not None and coll_name in self.var_type_node {
        coll_type_node = self.var_type_node[coll_name];
        hint = self._get_list_elem_from_type_node(coll_type_node);
        if hint is not None {
            self._list_type_hint = hint;
        }
    }
    self._last_type_node_hint = None;
    collection_val = self._codegen_expr(nd.collection);
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
    # Fallback: use _last_type_node_hint from method call return type
    if elem_type_name is None and coll_type_hint is not None {
        hint_elem = self._get_list_elem_from_type_node(coll_type_hint);
        if hint_elem is not None {
            elem_type_name = hint_elem;
        }
    }
    # Fallback: if still None and collection is a list ptr, assume ptr elements.
    # Skip if collection is a set type (sets use different helpers).
    if elem_type_name is None and isinstance(collection_val.type, ir.PointerType) {
        is_set = False;
        for (sname, stype) in self.set_types.items() {
            if collection_val.type == stype.as_pointer() {
                is_set = True;
                break;
            }
        }
        if not is_set {
            elem_type_name = "ptr";
        }
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
    idx_alloca = self._entry_alloca(i64, "forl.idx");
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
        inner_type = self._resolve_for_loop_elem_type(coll_name, nd.collection);
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
    # Allocate loop variable with resolved element type.
    # If this variable name was already used by a prior for-loop in the same
    # function (e.g. two consecutive loops both named `m`), reuse the existing
    # alloca instead of creating a new one.  A fresh alloca would be orphaned:
    # scope_exit only sees local_vars["m"] → the new alloca, so the retained
    # reference left in the old alloca would never be released.
    _forl_existing = self.local_vars.get(loop_var_name);
    _forl_reuse = (
        _forl_existing is not None
        and isinstance(_forl_existing.type, ir.PointerType)
        and _forl_existing.type.pointee == actual_elem_type
    );
    if _forl_reuse {
        loop_alloca = _forl_existing;
    } else {
        loop_alloca = self._entry_alloca(actual_elem_type, loop_var_name);
    }
    if isinstance(actual_elem_type, ir.PointerType) {
        null_const = ir.Constant(actual_elem_type, None);
        if not _forl_reuse {
            # Fresh alloca: null-initialize IN THE FUNCTION ENTRY BLOCK so the
            # alloca is always null on the very first call (safe even when the
            # loop is inside a conditional or nested inside an outer loop).
            _forl_saved_block = self.builder.block;
            self.builder.position_after(loop_alloca);
            self.builder.store(null_const, loop_alloca);
            self.builder.position_at_end(_forl_saved_block);
        }
        # At the loop-setup site: release whatever the alloca holds from the
        # previous outer-loop iteration (or previous for-loop using this var),
        # then reset to null.
        # First iteration of first loop: releases null (no-op).
        # Subsequent iterations or reused-variable second loop:
        # releases the last element retained by the previous loop run.
        _forl_pre_old = self.builder.load(loop_alloca, name="forl.pre.old");
        self._emit_rc_release_simple(
            _forl_pre_old,
            op="forl_reset",
            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                if nd.loc
                else 0}"
        );
        self.builder.store(null_const, loop_alloca);
    }
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
    # For pointer-typed loop variables: release the old value (null on first
    # iteration → no-op) and retain the new element so that the scope
    # cleanup's __rc_release_simple call is balanced.
    if isinstance(actual_elem_type, ir.PointerType) {
        old_loop_val = self.builder.load(loop_alloca, name="forl.old");
        self._emit_rc_release_simple(
            old_loop_val,
            op="forl_elem",
            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                if nd.loc
                else 0}"
        );
        self._emit_rc_retain(
            elem_val,
            op="forl_elem",
            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                if nd.loc
                else 0}"
        );
    }
    self.builder.store(elem_val, loop_alloca);
    _for_saved = set(self.local_vars.keys());
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    if not self.builder.block.is_terminated {
        self._emit_loop_iter_cleanup(_for_saved, loc=_for_loc);
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
