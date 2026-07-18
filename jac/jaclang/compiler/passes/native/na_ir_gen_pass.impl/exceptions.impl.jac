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
    i64 = ir.IntType(64);
    exc_state_type = self._get_exception_state_type();
    exc_state_ptr = exc_state_type.as_pointer();

    if self._exc_handler_global is None {
        handler_global = ir.GlobalVariable(
            self.llvm_module, exc_state_ptr, name="__jac_current_handler"
        );
        _is_wasm = "wasm" in (self.llvm_module.triple or "");
        handler_global.linkage = "internal" if _is_wasm else "weak";
        handler_global.initializer = ir.Constant(exc_state_ptr, None);
        self._exc_handler_global = handler_global;
    }

    jmp_buf_ptr = ir.ArrayType(ir.IntType(8), 200).as_pointer();
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
    exc_state_type = self._exc_state_type;
    exc_state_ptr = exc_state_type.as_pointer();
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    fnty = ir.FunctionType(ir.VoidType(), [exc_state_ptr]);
    func = self._define_function("__jac_exc_push", fnty);
    func.linkage = "private";
    func.args[0].name = "state";
    bb = func.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    state = func.args[0];

    prev_handler = b.load(self._exc_handler_global, name="prev");
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

    b.store(state, self._exc_handler_global);
    b.ret_void();
    self._exc_push_fn = func;
}

impl NaIRGenPass._emit_exc_pop_helper -> None {
    exc_state_type = self._exc_state_type;
    exc_state_ptr = exc_state_type.as_pointer();
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    fnty = ir.FunctionType(ir.VoidType(), []);
    func = self._define_function("__jac_exc_pop", fnty);
    func.linkage = "private";
    bb = func.append_basic_block("entry");
    b = ir.IRBuilder(bb);

    cur_handler = b.load(self._exc_handler_global, name="cur");

    prev_ptr = b.gep(
        cur_handler, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="prev.ptr"
    );
    prev_i8p = b.load(prev_ptr, name="prev.i8p");
    prev_handler = b.bitcast(prev_i8p, exc_state_ptr, name="prev.handler");

    b.store(prev_handler, self._exc_handler_global);
    b.ret_void();
    self._exc_pop_fn = func;
}

impl NaIRGenPass._emit_exc_raise_helper -> None {
    exc_state_type = self._exc_state_type;
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
    obj_val = func.args[0];
    type_val = func.args[1];
    msg_val = func.args[2];

    cur_handler = b.load(self._exc_handler_global, name="cur.handler");
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
    if self._exc_raise_fn is None {
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
    self.builder.call(
        self._exc_raise_fn, [msg_val, ir.Constant(i32, exc_type_id), msg_val]
    );
    self.builder.unreachable();

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

    if getattr(self.ir_in.gen, "nogc_enforced", False)
    and not self._raise_has_frame_handler(nd) {
        _abort_fn = self._get_or_declare_extern("abort", ir.VoidType(), []);
        _msg = self._make_global_string(
            "jac: unhandled exception in nogc-enforced module (abort)",
            name_prefix=".nogc.abort"
        );
        _puts_fn = self._get_or_declare_extern("puts", i32, [i8p]);
        _msg_i8 = self.builder.bitcast(_msg, i8p, name="nogc.abort.msg");
        self.builder.call(_puts_fn, [_msg_i8]);
        self.builder.call(_abort_fn, []);
        self.builder.unreachable();
        return;
    }

    if self._exc_raise_fn is None {
        self._declare_exception_runtime();
    }

    exc_payload: (ir.Value | None) = None;
    exc_msg: (ir.Value | None) = None;
    exc_type_name = "Exception";
    exc_type_id = 0;
    if nd.cause is not None {
        if isinstance(nd.cause, uni.FuncCall) {
            exc_type_name = self._get_name(nd.cause.target) or "Exception";
            exc_type_id = self._get_or_register_exc_type(exc_type_name);

            if exc_type_name in self.struct_types {
                exc_payload = self._codegen_expr(nd.cause);
            } else {
                params = nd.cause.params or [];
                if params {
                    exc_msg = self._codegen_expr(params[0]);
                }
            }
        } else {
            exc_msg = self._codegen_expr(nd.cause);
        }
    }

    if exc_msg is None {
        exc_msg = self._make_global_string(exc_type_name, name_prefix=".exc.msg");
    }

    if isinstance(exc_msg.type, ir.PointerType) and exc_msg.type != i8p {
        exc_msg = self.builder.bitcast(exc_msg, i8p, name="exc.msg.cast");
    }
    if exc_payload is None {
        exc_payload = exc_msg;
    } elif isinstance(exc_payload.type, ir.PointerType) and exc_payload.type != i8p {
        exc_payload = self.builder.bitcast(exc_payload, i8p, name="exc.obj.cast");
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
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);

    if self._exc_raise_fn is None {
        self._declare_exception_runtime();
    }
    exc_state_type = self._exc_state_type;
    exc_state_ptr = exc_state_type.as_pointer();
    func = self.builder.function;

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
    exc_state = self.builder.alloca(exc_state_type, name="exc.state");

    self.builder.call(self._exc_push_fn, [exc_state]);

    env_ptr = self.builder.gep(
        exc_state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="env.ptr"
    );
    env_i8p = self.builder.bitcast(env_ptr, i8p, name="env.i8p");
    setjmp_fn = self.extern_funcs["setjmp"];
    setjmp_result = self.builder.call(setjmp_fn, [env_i8p], name="setjmp.result");

    is_exception = self.builder.icmp_signed(
        "!=", setjmp_result, ir.Constant(i32, 0), name="is.exception"
    );
    self.builder.cbranch(is_exception, dispatch_bb, body_bb);

    self.builder.position_at_end(body_bb);
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(success_bb);
    }

    self.builder.position_at_end(success_bb);
    self.builder.call(self._exc_pop_fn, []);

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

    self.builder.position_at_end(dispatch_bb);

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
        self.builder.call(self._exc_pop_fn, []);
        exc_msg_val = self.builder.load(exc_msg_slot, name="exc.msg");
        self.builder.call(self._exc_raise_fn, [exc_obj_val, exc_type_val, exc_msg_val]);
        self.builder.unreachable();
    }

    self.builder.position_at_end(finally_bb);
    if nd.finally_body is not None {
        if isinstance(nd.finally_body.body, (list, tuple)) {
            self._codegen_body(nd.finally_body.body);
        }
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }

    self.builder.position_at_end(merge_bb);
}
