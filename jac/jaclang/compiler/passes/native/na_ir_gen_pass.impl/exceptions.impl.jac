"""Exception handling codegen: try/except/else/finally, raise."""

# ─── Exception State Type ────────────────────────────────────
"""Get or create the JacExceptionState struct type.

Layout:
  [0]: jmp_buf  → [200 x i8]  (platform-specific, 200 bytes is conservative)
  [1]: i8*      → exception message/object pointer
  [2]: i32      → exception type ID (0 = no exception)
  [3]: i8*      → previous handler pointer (for nesting)
"""
impl NaIRGenPass._get_exception_state_type -> ir.Type {
    if self._exc_state_type is not None {
        return self._exc_state_type;
    }
    jmp_buf_type = ir.ArrayType(ir.IntType(8), 200);
    exc_state = self.llvm_module.context.get_identified_type("JacExceptionState");
    exc_state.set_body(
        jmp_buf_type,  # [0] jmp_buf env
        ir.IntType(8).as_pointer(),  # [1] exception_obj (i8*)
        ir.IntType(32),  # [2] exception_type (i32)
        ir.IntType(8).as_pointer()  # [3] prev_handler (i8*)
    );
    self._exc_state_type = exc_state;
    return exc_state;
}

"""Declare setjmp/longjmp and create the global handler pointer + runtime helpers."""
impl NaIRGenPass._declare_exception_runtime -> None {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    exc_state_type = self._get_exception_state_type();
    exc_state_ptr = exc_state_type.as_pointer();
    # Global pointer to current exception handler: @__jac_current_handler
    if self._exc_handler_global is None {
        handler_global = ir.GlobalVariable(
            self.llvm_module, exc_state_ptr, name="__jac_current_handler"
        );
        handler_global.linkage = "internal";
        handler_global.initializer = ir.Constant(exc_state_ptr, None);
        self._exc_handler_global = handler_global;
    }
    # Declare setjmp: i32 setjmp(i8*)  — takes pointer to jmp_buf
    jmp_buf_ptr = ir.ArrayType(ir.IntType(8), 200).as_pointer();
    self._get_or_declare_extern("setjmp", i32, [i8p]);
    # Declare longjmp: void longjmp(i8*, i32)
    self._get_or_declare_extern("longjmp", ir.VoidType(), [i8p, i32]);
    # Declare abort for uncaught exceptions
    self._get_or_declare_extern("abort", ir.VoidType(), []);
    # Emit __jac_exc_push: initialize state and push onto handler stack
    self._emit_exc_push_helper();
    # Emit __jac_exc_pop: restore previous handler
    self._emit_exc_pop_helper();
    # Emit __jac_exc_raise: set exception info and longjmp
    self._emit_exc_raise_helper();
}

# ─── Runtime Helper: __jac_exc_push ──────────────────────────
"""Emit __jac_exc_push(state*): save prev handler, push state as current."""
impl NaIRGenPass._emit_exc_push_helper -> None {
    exc_state_type = self._exc_state_type;
    exc_state_ptr = exc_state_type.as_pointer();
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    fnty = ir.FunctionType(ir.VoidType(), [exc_state_ptr]);
    func = ir.Function(self.llvm_module, fnty, name="__jac_exc_push");
    func.linkage = "private";
    func.args[0].name = "state";
    bb = func.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    state = func.args[0];
    # state.prev_handler = __jac_current_handler
    prev_handler = b.load(self._exc_handler_global, name="prev");
    prev_as_i8p = b.bitcast(prev_handler, i8p, name="prev.i8p");
    prev_ptr = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="prev.ptr"
    );
    b.store(prev_as_i8p, prev_ptr);
    # state.exception_type = 0
    type_ptr = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="type.ptr"
    );
    b.store(ir.Constant(i32, 0), type_ptr);
    # state.exception_obj = null
    obj_ptr = b.gep(state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="obj.ptr");
    b.store(ir.Constant(i8p, None), obj_ptr);
    # __jac_current_handler = state
    b.store(state, self._exc_handler_global);
    b.ret_void();
    self._exc_push_fn = func;
}

# ─── Runtime Helper: __jac_exc_pop ───────────────────────────
"""Emit __jac_exc_pop(): restore previous handler from current state."""
impl NaIRGenPass._emit_exc_pop_helper -> None {
    exc_state_type = self._exc_state_type;
    exc_state_ptr = exc_state_type.as_pointer();
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    fnty = ir.FunctionType(ir.VoidType(), []);
    func = ir.Function(self.llvm_module, fnty, name="__jac_exc_pop");
    func.linkage = "private";
    bb = func.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    # Load current handler
    cur_handler = b.load(self._exc_handler_global, name="cur");
    # Load prev_handler from current state
    prev_ptr = b.gep(
        cur_handler, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="prev.ptr"
    );
    prev_i8p = b.load(prev_ptr, name="prev.i8p");
    prev_handler = b.bitcast(prev_i8p, exc_state_ptr, name="prev.handler");
    # __jac_current_handler = prev_handler
    b.store(prev_handler, self._exc_handler_global);
    b.ret_void();
    self._exc_pop_fn = func;
}

# ─── Runtime Helper: __jac_exc_raise ─────────────────────────
"""Emit __jac_exc_raise(msg*, type_id): store exception info and longjmp.
If no handler, print error and abort."""
impl NaIRGenPass._emit_exc_raise_helper -> None {
    exc_state_type = self._exc_state_type;
    exc_state_ptr = exc_state_type.as_pointer();
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    fnty = ir.FunctionType(ir.VoidType(), [i8p, i32]);
    func = ir.Function(self.llvm_module, fnty, name="__jac_exc_raise");
    func.linkage = "private";
    func.args[0].name = "msg";
    func.args[1].name = "type_id";
    entry_bb = func.append_basic_block("entry");
    has_handler_bb = func.append_basic_block("has.handler");
    no_handler_bb = func.append_basic_block("no.handler");
    b = ir.IRBuilder(entry_bb);
    msg_val = func.args[0];
    type_val = func.args[1];
    # Check if __jac_current_handler is null
    cur_handler = b.load(self._exc_handler_global, name="cur.handler");
    null_ptr = ir.Constant(exc_state_ptr, None);
    is_null = b.icmp_unsigned("==", cur_handler, null_ptr, name="no.handler.check");
    b.cbranch(is_null, no_handler_bb, has_handler_bb);
    # No handler: print error and abort
    b.position_at_end(no_handler_bb);
    printf_fn = self._get_printf();
    err_fmt_str = "Uncaught exception: %s\n\0";
    err_fmt_bytes = bytearray(err_fmt_str.encode("utf8"));
    err_fmt_const = ir.Constant(
        ir.ArrayType(ir.IntType(8), len(err_fmt_bytes)), err_fmt_bytes
    );
    err_fmt_global = ir.GlobalVariable(
        self.llvm_module, err_fmt_const.type, name=".exc.uncaught.fmt"
    );
    err_fmt_global.linkage = "private";
    err_fmt_global.global_constant = True;
    err_fmt_global.initializer = err_fmt_const;
    err_fmt_ptr = b.bitcast(err_fmt_global, i8p);
    b.call(printf_fn, [err_fmt_ptr, msg_val]);
    abort_fn = self.extern_funcs["abort"];
    b.call(abort_fn, []);
    b.unreachable();
    # Has handler: store exception info and longjmp
    b.position_at_end(has_handler_bb);
    # state.exception_obj = msg
    obj_ptr = b.gep(
        cur_handler, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="exc.obj.ptr"
    );
    b.store(msg_val, obj_ptr);
    # state.exception_type = type_id
    type_ptr = b.gep(
        cur_handler, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="exc.type.ptr"
    );
    b.store(type_val, type_ptr);
    # longjmp(state.env, 1)
    env_ptr = b.gep(
        cur_handler, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="env.ptr"
    );
    env_i8p = b.bitcast(env_ptr, i8p, name="env.i8p");
    longjmp_fn = self.extern_funcs["longjmp"];
    b.call(longjmp_fn, [env_i8p, ir.Constant(i32, 1)]);
    b.unreachable();
    self._exc_raise_fn = func;
}

# ─── Conditional Runtime Raise ───────────────────────────────
"""Emit a conditional runtime error check.
If is_error is true, raises the given exception type with the message.
After this call, the builder is positioned in the 'ok' continuation block."""
impl NaIRGenPass._emit_runtime_raise(
    is_error: ir.Value, exc_type_name: str, msg: str
) -> None {
    if self._exc_raise_fn is None {
        self._declare_exception_runtime();
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    func = self.builder.function;
    raise_bb = func.append_basic_block(name=f"raise.{exc_type_name}");
    ok_bb = func.append_basic_block(name=f"ok.{exc_type_name}");
    # Ensure is_error is i1
    is_error = self._to_bool(is_error);
    self.builder.cbranch(is_error, raise_bb, ok_bb);
    # Raise block
    self.builder.position_at_end(raise_bb);
    exc_type_id = self._get_or_register_exc_type(exc_type_name);
    # Deduplicate global error message strings
    if msg in self._rt_error_msgs {
        global_str = self._rt_error_msgs[msg];
    } else {
        str_bytes = bytearray((msg + "\0").encode("utf8"));
        c_str = ir.Constant(ir.ArrayType(ir.IntType(8), len(str_bytes)), str_bytes);
        global_str = ir.GlobalVariable(
            self.llvm_module, c_str.type, name=f".rt.{exc_type_name}.{self._str_count}"
        );
        self._str_count = self._str_count + 1;
        global_str.linkage = "private";
        global_str.global_constant = True;
        global_str.initializer = c_str;
        self._rt_error_msgs[msg] = global_str;
    }
    msg_val = self.builder.bitcast(global_str, i8p, name="rt.msg.cast");
    self.builder.call(self._exc_raise_fn, [msg_val, ir.Constant(i32, exc_type_id)]);
    self.builder.unreachable();
    # Continue on ok path
    self.builder.position_at_end(ok_bb);
}

# ─── Exception Type Registry ────────────────────────────────
"""Get or register an exception type ID for type-based matching."""
impl NaIRGenPass._get_or_register_exc_type(exc_name: str) -> int {
    if exc_name in self._exc_type_registry {
        return self._exc_type_registry[exc_name];
    }
    type_id = self._exc_type_counter;
    self._exc_type_counter = self._exc_type_counter + 1;
    self._exc_type_registry[exc_name] = type_id;
    # Also register common base types if not already registered
    # "Exception" matches everything (catch-all), use type_id 0
    if "Exception" not in self._exc_type_registry {
        self._exc_type_registry["Exception"] = 0;
    }
    return type_id;
}

# ─── Raise Statement Codegen ────────────────────────────────
"""Generate IR for raise statement: raise ExcType('message')."""
impl NaIRGenPass._codegen_raise(nd: uni.RaiseStmt) -> None {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    # Ensure exception runtime is available
    if self._exc_raise_fn is None {
        self._declare_exception_runtime();
    }
    # Default message and type
    exc_msg: (ir.Value | None) = None;
    exc_type_name = "Exception";
    exc_type_id = 0;
    if nd.cause is not None {
        # raise ExcType("message") — handle FuncCall form
        if isinstance(nd.cause, uni.FuncCall) {
            exc_type_name = self._get_name(nd.cause.target) or "Exception";
            exc_type_id = self._get_or_register_exc_type(exc_type_name);
            # Get the message argument if any
            params = nd.cause.params or [];
            if params {
                exc_msg = self._codegen_expr(params[0]);
            }
        } else {
            # raise expr — evaluate the expression as the message
            exc_msg = self._codegen_expr(nd.cause);
        }
    }
    # Default to empty message if none provided
    if exc_msg is None {
        exc_msg = self._make_global_string(exc_type_name, name_prefix=".exc.msg");
    }
    # Ensure it's i8*
    if isinstance(exc_msg.type, ir.PointerType) and exc_msg.type != i8p {
        exc_msg = self.builder.bitcast(exc_msg, i8p, name="exc.msg.cast");
    }
    # Call __jac_exc_raise(msg, type_id)
    self.builder.call(self._exc_raise_fn, [exc_msg, ir.Constant(i32, exc_type_id)]);
    self.builder.unreachable();
}

# ─── Try/Except/Else/Finally Codegen ────────────────────────
"""Generate IR for try/except/else/finally statement.

Control flow:
  try.setup:   alloca exc_state, push handler, setjmp → branch
  try.body:    execute try statements → try.success
  try.success: pop handler → else.bb (or finally.bb)
  except.dispatch: load type → chain of type checks
  except.handlerN: pop handler, bind exc var → handler body → finally.bb
  except.reraise: pop handler → re-raise exception
  finally.bb:  execute finally body → merge.bb
  merge.bb:    continue
"""
impl NaIRGenPass._codegen_try(nd: uni.TryStmt) -> None {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    # Ensure exception runtime is available
    if self._exc_raise_fn is None {
        self._declare_exception_runtime();
    }
    exc_state_type = self._exc_state_type;
    exc_state_ptr = exc_state_type.as_pointer();
    func = self.builder.function;
    # Create basic blocks
    setup_bb = func.append_basic_block(name="try.setup");
    body_bb = func.append_basic_block(name="try.body");
    success_bb = func.append_basic_block(name="try.success");
    dispatch_bb = func.append_basic_block(name="except.dispatch");
    finally_bb = func.append_basic_block(name="finally");
    merge_bb = func.append_basic_block(name="try.merge");
    # Branch to setup
    self.builder.branch(setup_bb);
    # ── try.setup: allocate state, push handler, call setjmp ──
    self.builder.position_at_end(setup_bb);
    exc_state = self.builder.alloca(exc_state_type, name="exc.state");
    # Push handler
    self.builder.call(self._exc_push_fn, [exc_state]);
    # setjmp(state.env) — get pointer to jmp_buf (field 0)
    env_ptr = self.builder.gep(
        exc_state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="env.ptr"
    );
    env_i8p = self.builder.bitcast(env_ptr, i8p, name="env.i8p");
    setjmp_fn = self.extern_funcs["setjmp"];
    setjmp_result = self.builder.call(setjmp_fn, [env_i8p], name="setjmp.result");
    # Branch: 0 = normal path (try body), non-0 = exception caught
    is_exception = self.builder.icmp_signed(
        "!=", setjmp_result, ir.Constant(i32, 0), name="is.exception"
    );
    self.builder.cbranch(is_exception, dispatch_bb, body_bb);
    # ── try.body: execute try block statements ──
    self.builder.position_at_end(body_bb);
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(success_bb);
    }
    # ── try.success: pop handler, go to else or finally ──
    self.builder.position_at_end(success_bb);
    self.builder.call(self._exc_pop_fn, []);
    # If there's an else block, generate it here (executes only when no exception)
    if nd.else_body is not None {
        else_bb = func.append_basic_block(name="try.else");
        self.builder.branch(else_bb);
        self.builder.position_at_end(else_bb);
        if isinstance(nd.else_body, uni.ElseStmt) {
            if isinstance(nd.else_body.body, (list, tuple)) {
                self._codegen_body(nd.else_body.body);
            }
        }
        if not self.builder.block.is_terminated {
            self.builder.branch(finally_bb);
        }
    } else {
        if not self.builder.block.is_terminated {
            self.builder.branch(finally_bb);
        }
    }
    # ── except.dispatch: match exception type against handlers ──
    self.builder.position_at_end(dispatch_bb);
    # Load exception type from state
    exc_type_ptr = self.builder.gep(
        exc_state, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="exc.type.ptr"
    );
    exc_type_val = self.builder.load(exc_type_ptr, name="exc.type");
    # Load exception object from state
    exc_obj_ptr = self.builder.gep(
        exc_state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="exc.obj.ptr"
    );
    exc_obj_val = self.builder.load(exc_obj_ptr, name="exc.obj");
    if nd.excepts {
        # Chain of dispatch blocks for each except clause
        current_dispatch_bb = dispatch_bb;
        for (i, except_node) in enumerate(nd.excepts) {
            handler_bb = func.append_basic_block(name=f"except.handler.{i}");
            is_last = i == len(nd.excepts) - 1;

            if not is_last {
                next_dispatch_bb = func.append_basic_block(
                    name=f"except.dispatch.{i + 1}"
                );
            } else {
                next_dispatch_bb = None;
            }

            # Get the exception type being caught
            caught_type_name = self._get_name(except_node.ex_type) or "Exception";
            caught_type_id = self._get_or_register_exc_type(caught_type_name);

            # Position at current dispatch block (only if not first iteration,
            # since first iteration reuses dispatch_bb which is already positioned)
            if i > 0 {
                self.builder.position_at_end(current_dispatch_bb);
                # Re-load exc_type for this dispatch block
                exc_type_val = self.builder.load(exc_type_ptr, name=f"exc.type.{i}");
                exc_obj_val = self.builder.load(exc_obj_ptr, name=f"exc.obj.{i}");
            }

            # Check match: caught_type_id == 0 means catch-all (Exception)
            if caught_type_id == 0 {
                # Catch-all: always matches
                self.builder.branch(handler_bb);
            } else {
                does_match = self.builder.icmp_signed(
                    "==",
                    exc_type_val,
                    ir.Constant(i32, caught_type_id),
                    name=f"exc.match.{i}"
                );
                if next_dispatch_bb is not None {
                    self.builder.cbranch(does_match, handler_bb, next_dispatch_bb);
                } else {
                    # Last handler — if no match, create reraise block
                    reraise_bb = func.append_basic_block(name="except.reraise");
                    self.builder.cbranch(does_match, handler_bb, reraise_bb);
                    # Reraise block: pop handler and re-raise
                    self.builder.position_at_end(reraise_bb);
                    self.builder.call(self._exc_pop_fn, []);
                    reraise_obj = self.builder.load(exc_obj_ptr, name="reraise.obj");
                    reraise_type = self.builder.load(exc_type_ptr, name="reraise.type");
                    self.builder.call(self._exc_raise_fn, [reraise_obj, reraise_type]);
                    self.builder.unreachable();
                }
            }

            # ── except.handler.N: pop handler, bind var, execute body ──
            self.builder.position_at_end(handler_bb);
            self.builder.call(self._exc_pop_fn, []);

            # Bind exception variable if "except ExcType as e"
            if except_node.name is not None {
                var_name = except_node.name.value
                if isinstance(except_node.name, uni.Name)
                else str(except_node.name);
                # Re-load exc_obj in this block
                handler_exc_obj = self.builder.load(exc_obj_ptr, name="exc.bound.obj");
                alloca = self._entry_alloca(i8p, var_name);
                self.builder.store(handler_exc_obj, alloca);
                self.local_vars[var_name] = alloca;
            }

            # Execute handler body
            if isinstance(except_node.body, (list, tuple)) {
                self._codegen_body(except_node.body);
            }
            if not self.builder.block.is_terminated {
                self.builder.branch(finally_bb);
            }

            if next_dispatch_bb is not None {
                current_dispatch_bb = next_dispatch_bb;
            }
        }
    } else {
        # No except handlers — pop handler and go to finally
        self.builder.call(self._exc_pop_fn, []);
        # Re-raise since no handler matched
        self.builder.call(self._exc_raise_fn, [exc_obj_val, exc_type_val]);
        self.builder.unreachable();
    }
    # ── finally.bb: execute finally body (always runs) ──
    self.builder.position_at_end(finally_bb);
    if nd.finally_body is not None {
        if isinstance(nd.finally_body.body, (list, tuple)) {
            self._codegen_body(nd.finally_body.body);
        }
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }
    # ── merge.bb: continue after try/except/finally ──
    self.builder.position_at_end(merge_bb);
}
