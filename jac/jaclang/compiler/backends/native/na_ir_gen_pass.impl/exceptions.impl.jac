impl NaIRGenPass._get_exception_state_type -> ir.Type {
    if self._exc_state_type is not None {
        return self._exc_state_type;
    }
    jmp_buf_type = ir.ArrayType(ir.IntType(8), 200);
    exc_state = self.llvm_module.context.get_identified_type("JacExceptionState");

    exc_state.set_body(
        jmp_buf_type,
        ir.IntType(8).as_pointer(),
        ir.IntType(32),
        ir.IntType(8).as_pointer(),
        ir.IntType(8).as_pointer()
    );
    self._exc_state_type = exc_state;
    return exc_state;
}

impl NaIRGenPass._declare_exception_runtime -> None {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);

    setjmp_fn = self._get_or_declare_extern("setjmp", i32, [i8p]);
    setjmp_fn.attributes.add("returns_twice");

    longjmp_fn = self._get_or_declare_extern("longjmp", ir.VoidType(), [i8p, i32]);
    longjmp_fn.attributes.add("noreturn");

    self._get_or_declare_extern("abort", ir.VoidType(), []);

    self._emit_exc_push_helper();

    self._emit_exc_pop_helper();

    self._emit_exc_raise_helper();
}

impl NaIRGenPass._emit_exc_push_helper -> None {
    exc_state_type = self._get_exception_state_type();
    exc_state_ptr = exc_state_type.as_pointer();
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    fnty = ir.FunctionType(ir.VoidType(), [exc_state_ptr]);
    func = self._define_function("__jac_exc_push", fnty);
    func.linkage = "private";
    func.args[0].name = "state";
    bb = func.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    handler_slot = self._exception_handler_slot(b);
    state = func.args[0];

    prev_handler = b.load(handler_slot, name="prev");
    prev_as_i8p = b.bitcast(prev_handler, i8p, name="prev.i8p");
    prev_ptr = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="prev.ptr"
    );
    b.store(prev_as_i8p, prev_ptr);

    type_ptr = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="type.ptr"
    );
    b.store(ir.Constant(i32, 0), type_ptr);

    obj_ptr = b.gep(state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="obj.ptr");
    b.store(ir.Constant(i8p, None), obj_ptr);

    msg_ptr = b.gep(state, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="msg.ptr");
    b.store(ir.Constant(i8p, None), msg_ptr);

    b.store(state, handler_slot);
    b.ret_void();
    self._exc_push_fn = func;
}

impl NaIRGenPass._emit_exc_pop_helper -> None {
    exc_state_type = self._get_exception_state_type();
    exc_state_ptr = exc_state_type.as_pointer();
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    fnty = ir.FunctionType(ir.VoidType(), []);
    func = self._define_function("__jac_exc_pop", fnty);
    func.linkage = "private";
    bb = func.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    handler_slot = self._exception_handler_slot(b);

    cur_handler = b.load(handler_slot, name="cur");

    prev_ptr = b.gep(
        cur_handler, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="prev.ptr"
    );
    prev_i8p = b.load(prev_ptr, name="prev.i8p");
    prev_handler = b.bitcast(prev_i8p, exc_state_ptr, name="prev.handler");

    b.store(prev_handler, handler_slot);
    b.ret_void();
    self._exc_pop_fn = func;
}

impl NaIRGenPass._emit_exc_raise_helper -> None {
    exc_state_type = self._get_exception_state_type();
    exc_state_ptr = exc_state_type.as_pointer();
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    fnty = ir.FunctionType(ir.VoidType(), [i8p, i32, i8p]);
    func = self._define_function("__jac_exc_raise", fnty);
    func.linkage = "private";
    func.args[0].name = "obj";
    func.args[1].name = "type_id";
    func.args[2].name = "msg";
    entry_bb = func.append_basic_block("entry");
    has_handler_bb = func.append_basic_block("has.handler");
    no_handler_bb = func.append_basic_block("no.handler");
    b = ir.IRBuilder(entry_bb);
    handler_slot = self._exception_handler_slot(b);
    obj_val = func.args[0];
    type_val = func.args[1];
    msg_val = func.args[2];

    cur_handler = b.load(handler_slot, name="cur.handler");
    null_ptr = ir.Constant(exc_state_ptr, None);
    is_null = b.icmp_unsigned("==", cur_handler, null_ptr, name="no.handler.check");
    b.cbranch(is_null, no_handler_bb, has_handler_bb);

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

    _fflush = self._get_or_declare_extern("fflush", ir.IntType(32), [i8p]);
    b.call(_fflush, [ir.Constant(i8p, None)]);
    abort_fn = self.extern_funcs["abort"];
    b.call(abort_fn, []);
    b.unreachable();

    b.position_at_end(has_handler_bb);

    obj_ptr = b.gep(
        cur_handler, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="exc.obj.ptr"
    );
    b.store(obj_val, obj_ptr);

    type_ptr = b.gep(
        cur_handler, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="exc.type.ptr"
    );
    b.store(type_val, type_ptr);

    msg_slot = b.gep(
        cur_handler, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="exc.msg.ptr"
    );
    b.store(msg_val, msg_slot);

    env_ptr = b.gep(
        cur_handler, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="env.ptr"
    );
    env_i8p = b.bitcast(env_ptr, i8p, name="env.i8p");
    longjmp_fn = self.extern_funcs["longjmp"];
    b.call(longjmp_fn, [env_i8p, ir.Constant(i32, 1)]);
    b.unreachable();
    self._exc_raise_fn = func;
}

impl NaIRGenPass._emit_runtime_raise(
    is_error: ir.Value, exc_type_name: str, msg: str
) -> None {
    if not self._slot_lowering_active() and self._exc_raise_fn is None {
        self._declare_exception_runtime();
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    func = self.builder.function;
    raise_bb = func.append_basic_block(name=f"raise.{exc_type_name}");
    ok_bb = func.append_basic_block(name=f"ok.{exc_type_name}");

    is_error = self._to_bool(is_error);
    self.builder.cbranch(is_error, raise_bb, ok_bb);

    self.builder.position_at_end(raise_bb);
    exc_type_id = self._get_or_register_exc_type(exc_type_name);

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
    if self._slot_lowering_active() {
        self._codegen_raise_slot(msg_val, exc_type_id, msg_val);
    } else {
        self.builder.call(
            self._exc_raise_fn, [msg_val, ir.Constant(i32, exc_type_id), msg_val]
        );
        self.builder.unreachable();
    }

    self.builder.position_at_end(ok_bb);
}

impl NaIRGenPass._get_or_register_exc_type(exc_name: str) -> int {
    if exc_name in self._exc_type_registry {
        return self._exc_type_registry[exc_name];
    }
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    type_id = JAC_TYPE_REGISTRY.exception_type_id(exc_name);
    self._exc_type_registry[exc_name] = type_id;
    return type_id;
}

impl NaIRGenPass._get_exc_descendants(type_name: str) -> list[str] {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    descendants = JAC_TYPE_REGISTRY.exception_descendants(type_name);
    for desc_name in descendants {
        self._get_or_register_exc_type(desc_name);
    }
    return descendants;
}

impl NaIRGenPass._codegen_raise(nd: uni.RaiseStmt) -> None {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);

    if not self._slot_lowering_active() and self._exc_raise_fn is None {
        self._declare_exception_runtime();
    }

    if nd.cause is None {
        for (owner, values) in reversed(self._caught_error_stack) {
            if owner is self.builder.function {
                if self._slot_lowering_active() {
                    for (slot, value) in zip(self._nogc_err_slot(), values) {
                        self.builder.store(value, slot);
                    }
                    self._emit_err_propagate(loc="reraise");
                } else {
                    self.builder.call(
                        self._exc_raise_fn, [values[1], values[0], values[2]]
                    );
                    self.builder.unreachable();
                }
                return;
            }
        }
    }
    exc_payload: (ir.Value | None) = None;
    exc_msg: (ir.Value | None) = None;
    exc_type_name = "Exception";
    exc_type_id = 0;
    if nd.cause is not None {
        if isinstance(nd.cause, uni.FuncCall) {
            exc_type_name = self._get_name(nd.cause.target) or "Exception";
            exc_type_id = self._get_or_register_exc_type(exc_type_name);

            _exc_pos_args = [];
            for _p in (nd.cause.params or []) {
                if not isinstance(_p, uni.KWPair) {
                    _exc_pos_args.append(_p);
                }
            }
            _exc_has_init = f"{exc_type_name}.init" in self.method_funcs;
            if f"{exc_type_name}.__init__" in self.method_funcs {
                _exc_has_init = True;
            }
            _exc_order = self.struct_field_order.get(exc_type_name);
            _exc_struct_ok = _exc_has_init;
            if (not _exc_struct_ok) and (_exc_order is not None) {
                _exc_struct_ok = len(_exc_pos_args) <= len(_exc_order);
            }
            if (exc_type_name in self.struct_types) and _exc_struct_ok {
                exc_payload = self._codegen_expr(nd.cause);
            } elif _exc_pos_args {
                exc_msg = self._codegen_expr(_exc_pos_args[0]);
            } elif nd.cause.params {
                exc_msg = self._codegen_expr(nd.cause.params[0]);
            }
        } else {
            exc_msg = self._codegen_expr(nd.cause);
        }
    }

    if exc_msg is None {
        exc_msg = self._make_global_string(exc_type_name, name_prefix=".exc.msg");
    }
    exc_msg = self._str_norm(exc_msg);
    exc_payload = self._str_norm_optional(exc_payload);
    if exc_msg is None {
        return;
    }

    if isinstance(exc_msg.type, ir.PointerType) and exc_msg.type != i8p {
        exc_msg = self.builder.bitcast(exc_msg, i8p, name="exc.msg.cast");
    }
    if exc_payload is None {
        exc_payload = exc_msg;
    } elif isinstance(exc_payload.type, ir.PointerType) and exc_payload.type != i8p {
        exc_payload = self.builder.bitcast(exc_payload, i8p, name="exc.obj.cast");
    }

    if self._slot_lowering_active() {
        self._codegen_raise_slot(exc_payload, exc_type_id, exc_msg);
        return;
    }
    self.builder.call(
        self._exc_raise_fn, [exc_payload, ir.Constant(i32, exc_type_id), exc_msg]
    );
    self.builder.unreachable();
}

impl NaIRGenPass._raise_has_frame_handler(nd: uni.RaiseStmt) -> bool {
    _child: uni.UniNode = nd;
    _cur = nd.parent;
    while _cur is not None {
        if isinstance(_cur, uni.TryStmt) and _child in list(_cur.body) {
            return True;
        }
        if isinstance(_cur, (uni.Ability, uni.LambdaExpr, uni.Module)) {
            return False;
        }
        _child = _cur;
        _cur = _cur.parent;
    }
    return False;
}

impl NaIRGenPass._codegen_try(nd: uni.TryStmt) -> None {
    if self._slot_lowering_active() {
        self._codegen_try_slot(nd);
    } elif nd.finally_body is not None and self._gen_ctx is None {
        self._codegen_finally_guard(nd);
    } else {
        self._codegen_try_unwind(nd);
    }
}

impl NaIRGenPass._codegen_try_unwind(
    nd: uni.TryStmt, emit_finally: bool = True
) -> None {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);

    if self._exc_raise_fn is None {
        self._declare_exception_runtime();
    }
    exc_state_type = self._get_exception_state_type();
    exc_state_ptr = exc_state_type.as_pointer();
    func = self.builder.function;
    _gc = self._gen_ctx;
    _in_gen = _gc is not None and func is _gc.resume_fn;

    func.attributes.add("optnone");
    func.attributes.add("noinline");

    setup_bb = func.append_basic_block(name="try.setup");
    body_bb = func.append_basic_block(name="try.body");
    success_bb = func.append_basic_block(name="try.success");
    dispatch_bb = func.append_basic_block(name="except.dispatch");
    finally_bb = func.append_basic_block(name="finally");
    merge_bb = func.append_basic_block(name="try.merge");

    self.builder.branch(setup_bb);

    self.builder.position_at_end(setup_bb);
    (exc_state, _rgn_depth_slot) = self._push_exception_handler(dispatch_bb, body_bb);

    self.builder.position_at_end(body_bb);
    if _in_gen {
        self._gen_try_stack.append(
            NativeGeneratorHandler(state=exc_state, dispatch=dispatch_bb)
        );
    }
    frame = NativeFinalizer(
        body=nd.finally_body if emit_finally else None,
        function=func,
        loop_depth=len(self.loop_stack),
        handler_depth=len(self._slot_try_stack),
        pop_handler=True
    );
    self._finally_stack.append(frame);
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    self._finally_stack.pop();
    if _in_gen {
        self._gen_try_stack.pop();
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(success_bb);
    }

    self.builder.position_at_end(success_bb);
    self.builder.call(self._exc_pop_fn, []);

    frame.pop_handler = False;
    self._finally_stack.append(frame);
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
    } elif not self.builder.block.is_terminated {
        self.builder.branch(finally_bb);
    }

    self._finally_stack.pop();
    self.builder.position_at_end(dispatch_bb);
    self._region_unwind(self.builder.load(_rgn_depth_slot, name="rgn.depth"));

    exc_type_ptr = self.builder.gep(
        exc_state, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="exc.type.ptr"
    );
    exc_type_val = self.builder.load(exc_type_ptr, name="exc.type");

    exc_obj_ptr = self.builder.gep(
        exc_state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="exc.obj.ptr"
    );
    exc_obj_val = self.builder.load(exc_obj_ptr, name="exc.obj");
    exc_msg_slot = self.builder.gep(
        exc_state, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="exc.msg.slot"
    );
    if nd.excepts {
        current_dispatch_bb = dispatch_bb;
        for (i, except_node) in enumerate(nd.excepts) {
            handler_bb = func.append_basic_block(name=f"except.handler.{i}");
            is_last = i == len(nd.excepts) - 1;

            next_dispatch_bb: ir.Block | None = None;
            if not is_last {
                next_dispatch_bb = func.append_basic_block(
                    name=f"except.dispatch.{i + 1}"
                );
            } else {
                next_dispatch_bb = None;
            }

            caught_type_name = self._get_name(except_node.ex_type) or "Exception";
            caught_type_id = self._get_or_register_exc_type(caught_type_name);

            if i > 0 {
                self.builder.position_at_end(current_dispatch_bb);

                exc_type_val = self.builder.load(exc_type_ptr, name=f"exc.type.{i}");
                exc_obj_val = self.builder.load(exc_obj_ptr, name=f"exc.obj.{i}");
            }

            if caught_type_id == 0 {
                self.builder.branch(handler_bb);
            } else {
                descendants = self._get_exc_descendants(caught_type_name);
                does_match = self.builder.icmp_signed(
                    "==",
                    exc_type_val,
                    ir.Constant(i32, caught_type_id),
                    name=f"exc.match.{i}"
                );
                for desc_name in descendants {
                    desc_id = self._get_or_register_exc_type(desc_name);
                    desc_match = self.builder.icmp_signed(
                        "==",
                        exc_type_val,
                        ir.Constant(i32, desc_id),
                        name=f"exc.match.{i}.{desc_name}"
                    );
                    does_match = self.builder.or_(
                        does_match, desc_match, name=f"exc.or.{i}.{desc_name}"
                    );
                }
                if next_dispatch_bb is not None {
                    self.builder.cbranch(does_match, handler_bb, next_dispatch_bb);
                } else {
                    reraise_bb = func.append_basic_block(name="except.reraise");
                    self.builder.cbranch(does_match, handler_bb, reraise_bb);
                    self.builder.position_at_end(reraise_bb);
                    self.builder.call(self._exc_pop_fn, []);
                    reraise_obj = self.builder.load(exc_obj_ptr, name="reraise.obj");
                    reraise_type = self.builder.load(exc_type_ptr, name="reraise.type");
                    reraise_msg = self.builder.load(exc_msg_slot, name="reraise.msg");
                    self.builder.call(
                        self._exc_raise_fn, [reraise_obj, reraise_type, reraise_msg]
                    );
                    self.builder.unreachable();
                }
            }

            self.builder.position_at_end(handler_bb);
            self.builder.call(self._exc_pop_fn, []);

            if except_node.name is not None {
                var_name = except_node.name.value
                    if isinstance(except_node.name, uni.Name)
                    else str(except_node.name);

                if caught_type_name in self.struct_types {
                    handler_exc_obj = self.builder.load(
                        exc_obj_ptr, name="exc.bound.obj"
                    );
                    _exc_sp_ty = self.struct_types[caught_type_name].as_pointer();
                    typed_obj = self.builder.bitcast(
                        handler_exc_obj, _exc_sp_ty, name="exc.bound.typed"
                    );
                    alloca = self._entry_alloca(_exc_sp_ty, var_name);
                    self.builder.store(typed_obj, alloca);
                } else {
                    handler_exc_msg = self.builder.load(
                        exc_msg_slot, name="exc.bound.msg"
                    );
                    alloca = self._entry_alloca(i8p, var_name);
                    self.builder.store(handler_exc_msg, alloca);
                }
                self.local_vars[var_name] = alloca;
            }

            self._caught_error_stack.append((func, self._exception_values(exc_state)));
            self._finally_stack.append(frame);
            if isinstance(except_node.body, (list, tuple)) {
                self._codegen_body(except_node.body);
            }
            self._finally_stack.pop();
            self._caught_error_stack.pop();
            if not self.builder.block.is_terminated {
                self.builder.branch(finally_bb);
            }

            if next_dispatch_bb is not None {
                current_dispatch_bb = next_dispatch_bb;
            }
        }
    } else {
        self.builder.call(self._exc_pop_fn, []);
        exc_msg_val = self.builder.load(exc_msg_slot, name="exc.msg");
        self.builder.call(self._exc_raise_fn, [exc_obj_val, exc_type_val, exc_msg_val]);
        self.builder.unreachable();
    }

    self.builder.position_at_end(finally_bb);
    if emit_finally and nd.finally_body is not None {
        if isinstance(nd.finally_body.body, (list, tuple)) {
            self._codegen_body(nd.finally_body.body);
        }
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }

    self.builder.position_at_end(merge_bb);
}

impl NaIRGenPass._slot_lowering_active -> bool {
    return (
        bool(getattr(self.ir_in.gen, "nogc_enforced", False))
        or "wasm" in str(self.llvm_module.triple)
    )
        and self._gen_ctx is None;
}

impl NaIRGenPass._get_exception_context_fn -> ir.Function {
    if self._exc_context_fn is not None {
        return self._exc_context_fn;
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    context_type = ir.LiteralStructType([i32, i8p, i8p, i8p]);
    context_ptr = context_type.as_pointer();
    free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
    (get_fn, set_fn) = self._emit_tls_slot(
        "__jac_exception_tls",
        "__jac_exception_tls_get",
        "__jac_exception_tls_set",
        free_fn
    );
    func = ir.Function(
        self.llvm_module,
        ir.FunctionType(context_ptr, []),
        name="__jac_exception_context"
    );
    func.linkage = "weak";
    self._exc_context_fn = func;
    entry_bb = func.append_basic_block("entry");
    create = func.append_basic_block("create");
    ready = func.append_basic_block("ready");
    b = ir.IRBuilder(entry_bb);
    value = b.call(get_fn, []);
    b.cbranch(b.icmp_unsigned("==", value, ir.Constant(i64, 0)), create, ready);
    b = ir.IRBuilder(ready);
    b.ret(b.inttoptr(value, context_ptr));
    b = ir.IRBuilder(create);
    size = b.ptrtoint(
        b.gep(ir.Constant(context_ptr, None), [ir.Constant(i32, 1)]), i64
    );
    calloc_fn = self._get_or_declare_extern("calloc", i8p, [i64, i64]);
    allocated = b.call(calloc_fn, [ir.Constant(i64, 1), size]);
    b.call(set_fn, [b.ptrtoint(allocated, i64)]);
    b.ret(b.bitcast(allocated, context_ptr));
    return func;
}

impl NaIRGenPass._exception_handler_slot(b: ir.IRBuilder) -> ir.Value {
    context = b.call(self._get_exception_context_fn(), []);
    slot = b.gep(
        context, [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 3)]
    );
    return b.bitcast(slot, self._get_exception_state_type().as_pointer().as_pointer());
}

impl NaIRGenPass._nogc_err_slot -> tuple[ir.Value, ir.Value, ir.Value] {
    i32 = ir.IntType(32);
    context = self.builder.call(self._get_exception_context_fn(), []);
    fields = [
        self.builder.gep(context, [ir.Constant(i32, 0), ir.Constant(i32, i)])
        for i in range(3)
    ];
    return (fields[0], fields[1], fields[2]);
}

impl NaIRGenPass._emit_err_propagate(loc: str = "") -> None {
    i8p = ir.IntType(8).as_pointer();
    for handler in reversed(self._slot_try_stack) {
        if handler.dispatch.parent is self.builder.function {
            self.builder.branch(handler.dispatch);
            return;
        }
    }
    func = self.builder.function;
    if func is self.func_symtab.get("jac_entry") {
        (_tg, _og, mglob) = self._nogc_err_slot();
        msg = self.builder.load(mglob, name="err.msg");
        fmt = self._make_global_string(
            "jac: unhandled exception: %s\n", name_prefix=".err.unhandled"
        );
        self.builder.call(
            self._get_printf(), [self.builder.bitcast(fmt, i8p, name="err.fmt"), msg]
        );
        flush_fn = self._get_or_declare_extern("fflush", ir.IntType(32), [i8p]);
        self.builder.call(flush_fn, [ir.Constant(i8p, None)]);
        abort_fn = self._get_or_declare_extern("abort", ir.VoidType(), []);
        self.builder.call(abort_fn, []);
        self.builder.unreachable();
        return;
    }
    self._emit_scope_cleanup(loc=loc or "err.propagate");
    rt = func.function_type.return_type;
    if isinstance(rt, ir.VoidType) {
        self.builder.ret_void();
    } else {
        self.builder.ret(self._default_arg_fallback(rt));
    }
}

impl NaIRGenPass._emit_err_check(callee: (uni.Ability | None)) -> None {
    if callee is None or not self._slot_lowering_active() {
        return;
    }
    if self._builder is None or self.builder.block.is_terminated {
        return;
    }
    i32 = ir.IntType(32);
    (tglob, _og, _mg) = self._nogc_err_slot();
    t = self.builder.load(tglob, name="err.type");
    is_err = self.builder.icmp_signed("!=", t, ir.Constant(i32, 0), name="err.set");
    func = self.builder.function;
    err_bb = func.append_basic_block("err.propagate");
    cont_bb = func.append_basic_block("err.cont");
    self.builder.cbranch(is_err, err_bb, cont_bb);
    self.builder.position_at_end(err_bb);
    self._emit_err_propagate(loc="err.check");
    self.builder.position_at_end(cont_bb);
}

impl NaIRGenPass._codegen_raise_slot(
    payload: ir.Value, type_id: int, msg: ir.Value
) -> None {
    i32 = ir.IntType(32);
    (tglob, oglob, mglob) = self._nogc_err_slot();

    self.builder.store(ir.Constant(i32, type_id + 1), tglob);
    self.builder.store(payload, oglob);
    self.builder.store(msg, mglob);
    self._emit_err_propagate(loc="raise");
}

impl NaIRGenPass._codegen_try_slot(nd: uni.TryStmt) -> None {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    func = self.builder.function;
    (tglob, oglob, mglob) = self._nogc_err_slot();
    body_bb = func.append_basic_block("try.body");
    dispatch_bb = func.append_basic_block("except.dispatch");
    finally_bb = func.append_basic_block("finally");
    merge_bb = func.append_basic_block("try.merge");
    error_bb = func.append_basic_block("finally.error");
    frame = NativeFinalizer(
        body=nd.finally_body,
        function=func,
        loop_depth=len(self.loop_stack),
        handler_depth=len(self._slot_try_stack)
    );
    self._finally_stack.append(frame);
    kind = self._entry_alloca(i32, "try.kind");
    self.builder.store(ir.Constant(i32, 0), kind);
    self.builder.branch(body_bb);
    self.builder.position_at_end(body_bb);
    self._slot_try_stack.append(NativeErrorHandler(dispatch=dispatch_bb));
    try {
        if isinstance(nd.body, (list, tuple)) {
            self._codegen_body(nd.body);
        }
    } finally {
        self._slot_try_stack.pop();
    }
    self._slot_try_stack.append(NativeErrorHandler(dispatch=error_bb));
    if not self.builder.block.is_terminated {
        if isinstance(nd.else_body, uni.ElseStmt)
            and isinstance(nd.else_body.body, (list, tuple)) {
            self._codegen_body(nd.else_body.body);
        }
        if not self.builder.block.is_terminated {
            self.builder.store(ir.Constant(i32, 0), kind);
            self.builder.branch(finally_bb);
        }
    }
    self.builder.position_at_end(dispatch_bb);
    err_type = self.builder.load(tglob, name="err.type");
    for (i, except_node) in enumerate(nd.excepts or []) {
        ex = except_node.ex_type;
        caught: (str | None) = None;
        if isinstance(ex, uni.Name) {
            caught = ex.value;
        } elif isinstance(ex, uni.AtomTrailer) and isinstance(ex.right, uni.Name) {
            caught = ex.right.value;
        }
        handler_bb = func.append_basic_block(f"except.handler.{i}");
        next_bb = func.append_basic_block(f"except.dispatch.{i + 1}");
        if caught is None or caught in ("Exception", "BaseException") {
            self.builder.branch(handler_bb);
        } else {
            ids = [self._get_or_register_exc_type(caught)];
            for desc in self._get_exc_descendants(caught) {
                ids.append(self._get_or_register_exc_type(desc));
            }
            does_match: (ir.Value | None) = None;
            for tid in ids {
                cmp = self.builder.icmp_signed(
                    "==", err_type, ir.Constant(i32, tid + 1), name=f"exc.is.{tid}"
                );
                does_match = cmp
                    if does_match is None
                    else self.builder.or_(does_match, cmp, name="exc.match");
            }
            self.builder.cbranch(does_match, handler_bb, next_bb);
        }
        self.builder.position_at_end(handler_bb);
        caught_values = (
            self.builder.load(tglob),
            self.builder.load(oglob),
            self.builder.load(mglob)
        );
        self._caught_error_stack.append((func, caught_values));
        self.builder.store(ir.Constant(i32, 0), tglob);
        if except_node.name is not None {
            var_name = except_node.name.value
                if isinstance(except_node.name, uni.Name)
                else str(except_node.name);
            if caught is not None and caught in self.struct_types {
                _exc_sp_ty = self.struct_types[caught].as_pointer();
                typed_obj = self.builder.bitcast(
                    self.builder.load(oglob, name="exc.bound.obj"),
                    _exc_sp_ty,
                    name="exc.bound.typed"
                );
                alloca = self._entry_alloca(_exc_sp_ty, var_name);
                self.builder.store(typed_obj, alloca);
            } else {
                alloca = self._entry_alloca(i8p, var_name);
                self.builder.store(
                    self.builder.load(mglob, name="exc.bound.msg"), alloca
                );
            }
        }
        if except_node.name is not None {
            self.local_vars[var_name] = alloca;
        }
        if isinstance(except_node.body, (list, tuple)) {
            self._codegen_body(except_node.body);
        }
        self._caught_error_stack.pop();
        if not self.builder.block.is_terminated {
            self.builder.store(ir.Constant(i32, 0), kind);
            self.builder.branch(finally_bb);
        }
        self.builder.position_at_end(next_bb);
    }
    self.builder.branch(error_bb);
    self._slot_try_stack.pop();
    self._finally_stack.pop();
    self.builder.position_at_end(error_bb);
    self.builder.store(ir.Constant(i32, 1), kind);
    self.builder.branch(finally_bb);
    self.builder.position_at_end(finally_bb);
    pending = (
        self.builder.load(tglob),
        self.builder.load(oglob),
        self.builder.load(mglob)
    );
    self.builder.store(ir.Constant(i32, 0), tglob);
    if nd.finally_body is not None
        and isinstance(nd.finally_body.body, (list, tuple)) {
        self._codegen_body(nd.finally_body.body);
    }
    if not self.builder.block.is_terminated {
        k = self.builder.load(kind, name="try.kind.v");
        is_prop = self.builder.icmp_signed(
            "!=", k, ir.Constant(i32, 0), name="try.propagating"
        );
        prop_bb = func.append_basic_block("try.propagate");
        self.builder.cbranch(is_prop, prop_bb, merge_bb);
        self.builder.position_at_end(prop_bb);
        for (slot, value) in zip(self._nogc_err_slot(), pending) {
            self.builder.store(value, slot);
        }
        self._emit_err_propagate(loc="try.propagate");
    }
    self.builder.position_at_end(merge_bb);
}


impl NaIRGenPass._emit_finalizers(loop_depth: int = 0) -> bool {
    saved_finalizers = self._finally_stack;
    saved_handlers = self._slot_try_stack;
    try {
        for index in range(len(saved_finalizers) - 1, -1, -1) {
            frame = saved_finalizers[index];
            if frame.function is not self.builder.function
                or frame.loop_depth < loop_depth {
                continue;
            }
            self._finally_stack = saved_finalizers[:index];
            self._slot_try_stack = saved_handlers[:frame.handler_depth];
            if frame.pop_handler {
                self.builder.call(self._exc_pop_fn, []);
            }
            if frame.body is not None and isinstance(frame.body.body, (list, tuple)) {
                self._codegen_body(frame.body.body);
            }
            if self.builder.block.is_terminated {
                return True;
            }
        }
        return False;
    } finally {
        self._finally_stack = saved_finalizers;
        self._slot_try_stack = saved_handlers;
    }
}


impl NaIRGenPass._push_exception_handler(
    dispatch: ir.Block, body: ir.Block
) -> tuple[ir.Value, ir.Value] {
    i32 = ir.IntType(32);
    i8p = ir.IntType(8).as_pointer();
    state = self._stack_entry_alloca(self._get_exception_state_type(), "exc.state");
    depth = self._stack_entry_alloca(ir.IntType(64), "rgn.depth.slot");
    self.builder.call(self._exc_push_fn, [state]);
    self.builder.store(self._region_depth(), depth);
    env = self.builder.gep(state, [ir.Constant(i32, 0), ir.Constant(i32, 0)]);
    result = self.builder.call(
        self.extern_funcs["setjmp"], [self.builder.bitcast(env, i8p)]
    );
    self.builder.cbranch(
        self.builder.icmp_signed("!=", result, ir.Constant(i32, 0)), dispatch, body
    );
    return (state, depth);
}

impl NaIRGenPass._exception_values(
    state: ir.Value
) -> tuple[ir.Value, ir.Value, ir.Value] {
    i32 = ir.IntType(32);
    values: list[ir.Value] = [];
    for index in (2, 1, 4) {
        slot = self.builder.gep(state, [ir.Constant(i32, 0), ir.Constant(i32, index)]);
        values.append(self.builder.load(slot));
    }
    return (values[0], values[1], values[2]);
}

impl NaIRGenPass._codegen_finally_guard(nd: uni.TryStmt) -> None {
    if self._exc_raise_fn is None {
        self._declare_exception_runtime();
    }
    func = self.builder.function;
    func.attributes.add("optnone");
    func.attributes.add("noinline");
    dispatch = func.append_basic_block("finally.error");
    body = func.append_basic_block("finally.guard");
    merge = func.append_basic_block("finally.merge");
    (state, depth) = self._push_exception_handler(dispatch, body);
    self.builder.position_at_end(body);
    frame = NativeFinalizer(
        body=nd.finally_body,
        function=func,
        loop_depth=len(self.loop_stack),
        handler_depth=len(self._slot_try_stack),
        pop_handler=True
    );
    self._finally_stack.append(frame);
    try {
        self._codegen_try_unwind(nd, emit_finally=False);
    } finally {
        self._finally_stack.pop();
    }
    if not self.builder.block.is_terminated {
        self.builder.call(self._exc_pop_fn, []);
        if nd.finally_body is not None
            and isinstance(nd.finally_body.body, (list, tuple)) {
            self._codegen_body(nd.finally_body.body);
        }
        if not self.builder.block.is_terminated {
            self.builder.branch(merge);
        }
    }
    self.builder.position_at_end(dispatch);
    self._region_unwind(self.builder.load(depth));
    values = self._exception_values(state);
    self.builder.call(self._exc_pop_fn, []);
    self._caught_error_stack.append((func, values));
    if nd.finally_body is not None
        and isinstance(nd.finally_body.body, (list, tuple)) {
        self._codegen_body(nd.finally_body.body);
    }
    self._caught_error_stack.pop();
    if not self.builder.block.is_terminated {
        self.builder.call(self._exc_raise_fn, [values[1], values[0], values[2]]);
        self.builder.unreachable();
    }
    self.builder.position_at_end(merge);
}
