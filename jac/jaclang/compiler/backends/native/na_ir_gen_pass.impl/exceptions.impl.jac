impl NaIRGenPass._emit_runtime_raise(
    is_error: ir.Value,
    exc_type_name: str,
    msg: str,
    release_on_error: list[ir.Value] = []
) -> None {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    func = self.builder.function;
    raise_bb = func.append_basic_block(name=f"raise.{exc_type_name}");
    ok_bb = func.append_basic_block(name=f"ok.{exc_type_name}");

    is_error = self._to_bool(is_error);
    self.builder.cbranch(is_error, raise_bb, ok_bb);

    self.builder.position_at_end(raise_bb);

    for value in release_on_error {
        if self._is_owned(value) {
            self._emit_rc_release_simple(value, op="read_error");
        }
    }
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
    self._codegen_raise_slot(None, exc_type_id, msg_val);

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

    if nd.cause is None {
        for (owner, values) in reversed(self._caught_error_stack) {
            if owner is self.builder.function {
                active = owner.append_basic_block("reraise.active");
                next_error = owner.append_basic_block("reraise.next");
                self.builder.cbranch(
                    self.builder.icmp_signed(
                        "!=", self.builder.load(values[0]), ir.Constant(i32, 0)
                    ),
                    active,
                    next_error
                );
                self.builder.position_at_end(active);
                self._restore_error(values);
                self._emit_err_propagate(loc="reraise");
                self.builder.position_at_end(next_error);
            }
        }
        self._codegen_raise_slot(
            None,
            self._get_or_register_exc_type("RuntimeError"),
            self._make_global_string("No active exception to reraise")
        );
        return;
    }
    exc_payload: (ir.Value | None) = None;
    exc_msg: (ir.Value | None) = None;
    exc_type_name = "Exception";
    exc_type_id = 0;
    if nd.cause is not None {
        if isinstance(nd.cause, uni.FuncCall) {
            exc_type_name = self._get_name(nd.cause.target) or "Exception";
            exc_type_id = self._get_or_register_exc_type(exc_type_name);

            _exc_pos_args: list[uni.Expr] = [];
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
            cause_struct = self._struct_name_of(nd.cause);
            if cause_struct is not None and cause_struct in self.struct_types {
                exc_type_name = cause_struct;
                exc_type_id = self._get_or_register_exc_type(cause_struct);
                exc_payload = self._codegen_expr(nd.cause);
            } else {
                exc_msg = self._codegen_expr(nd.cause);
            }
        }
    }

    if exc_msg is None {
        exc_msg = self._make_global_string(exc_type_name, name_prefix=".exc.msg");
    }
    if exc_msg is None {
        return;
    }

    if isinstance(exc_msg.type, ir.PointerType) and exc_msg.type != i8p {
        exc_msg = self.builder.bitcast(exc_msg, i8p, name="exc.msg.cast");
    }
    self._codegen_raise_slot(exc_payload, exc_type_id, exc_msg);
}

impl NaIRGenPass._get_exception_context_fn -> ir.Function {
    if self._exc_context_fn is not None {
        return self._exc_context_fn;
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    context_type = ir.LiteralStructType([i32, i8p, i8p, i32, ir.IntType(1)]);
    context_ptr = context_type.as_pointer();
    free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
    import from jaclang.compiler.frontend.codeinfo { native_exception_symbol }
    (get_fn, set_fn) = self._emit_tls_slot(
        native_exception_symbol("tls"),
        native_exception_symbol("tls_get"),
        native_exception_symbol("tls_set"),
        free_fn
    );
    func = ir.Function(
        self.llvm_module,
        ir.FunctionType(context_ptr, []),
        name=native_exception_symbol("context")
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

impl NaIRGenPass._error_slots(b: ir.IRBuilder) -> tuple[ir.Value, ir.Value, ir.Value] {
    frame = self._error_frame;
    if frame is not None and frame.function is b.function {
        return frame.slots;
    }
    i32 = ir.IntType(32);
    context = b.call(self._get_exception_context_fn(), []);
    fields = [
        b.gep(context, [ir.Constant(i32, 0), ir.Constant(i32, i)]) for i in range(3)
    ];
    return (fields[0], fields[1], fields[2]);
}

impl NaIRGenPass._spill_error(
    values: tuple[ir.Value, ir.Value, ir.Value]
) -> tuple[ir.Value, ir.Value, ir.Value] {
    slots: list[ir.Value] = [];
    for (index, value) in enumerate(values) {
        name = f"error.saved.{len(self.local_vars)}.{index}";
        if index == 1 {
            value = self.builder.bitcast(
                value, self._get_error_record_type().as_pointer()
            );
        }
        slot = self._entry_alloca(value.type, name);
        if index == 1 {
            owner_slot = slot;
            owned_value = value;
            if self._nogc_headerless() {
                self.builder.store(value, slot);
                owner_slot = self._entry_alloca(value.type, name + ".owner");
                owned_value = self.builder.select(
                    self.builder.load(self._error_owned_slot(self.builder)),
                    value,
                    ir.Constant(value.type, None)
                );
            }
            self.local_vars[name + ".owner" if self._nogc_headerless() else name] = owner_slot;
            old = self.builder.load(owner_slot);
            self.builder.store(owned_value, owner_slot);
            self._emit_rc_release_typed(old, op="scope_exit");
        } else {
            self.builder.store(value, slot);
        }
        slots.append(slot);
    }
    return (slots[0], slots[1], slots[2]);
}

impl NaIRGenPass._restore_error(values: tuple[ir.Value, ir.Value, ir.Value]) -> None {
    record = self.builder.load(values[1]);
    self._emit_rc_retain(record, op="reraise");
    self.builder.store(
        ir.Constant(ir.IntType(1), int(not self._nogc_headerless())),
        self._error_owned_slot(self.builder)
    );
    (kind, owner, msg) = self._error_slots(self.builder);
    self.builder.store(self.builder.load(values[0]), kind);
    self.builder.store(self.builder.bitcast(record, ir.IntType(8).as_pointer()), owner);
    self.builder.store(self.builder.load(values[2]), msg);
}

impl NaIRGenPass._clear_pending_error(b: ir.IRBuilder, release: bool = True) -> None {
    (kind, owner, msg) = self._error_slots(b);
    value = b.load(owner);
    owned = b.load(self._error_owned_slot(b));
    b.store(ir.Constant(ir.IntType(32), 0), kind);
    b.store(ir.Constant(ir.IntType(8).as_pointer(), None), owner);
    b.store(ir.Constant(ir.IntType(8).as_pointer(), None), msg);
    b.store(ir.Constant(ir.IntType(1), 0), self._error_owned_slot(b));
    if release {
        drop = self._get_error_record_drop() if self._nogc_headerless() else None;
        self._emit_rc_helpers();
        released = b.select(
            owned, value, ir.Constant(ir.IntType(8).as_pointer(), None)
        );
        b.call(drop if drop is not None else self.rc_release_simple_fn, [released]);
    }
}

impl NaIRGenPass._emit_err_propagate(loc: str = "") -> None {
    i8p = ir.IntType(8).as_pointer();
    slots = self._error_slots(self.builder);
    pending = [self.builder.load(slot) for slot in slots];
    owns = self.builder.load(self._error_owned_slot(self.builder));
    self._clear_pending_error(self.builder, release=False);
    self._release_temporaries();
    for handler in reversed(self._slot_try_stack) {
        if handler.dispatch.parent is self.builder.function {
            for (slot, value) in zip(slots, pending) {
                self.builder.store(value, slot);
            }
            self.builder.store(owns, self._error_owned_slot(self.builder));
            self.builder.branch(handler.dispatch);
            return;
        }
    }
    func = self.builder.function;
    if self._nogc_headerless() and self._error_record_type is not None {
        for slot in self.local_vars.values() {
            if slot.pointee_type == self._error_record_type.as_pointer() {
                value = self.builder.load(slot);
                carries = self.builder.icmp_unsigned(
                    "==", self.builder.bitcast(value, i8p), pending[1]
                );
                owns = self.builder.or_(owns, carries);
                self.builder.store(
                    self.builder.select(carries, ir.Constant(value.type, None), value),
                    slot
                );
            }
        }
    }
    self._emit_scope_cleanup(loc=loc or "err.propagate");
    for (slot, value) in zip(slots, pending) {
        self.builder.store(value, slot);
    }
    self.builder.store(owns, self._error_owned_slot(self.builder));
    if self._gen_ctx is not None {
        ip = self.builder.bitcast(self._gen_ctx.frame_i8, ir.IntType(64).as_pointer());
        self.builder.store(ir.Constant(ir.IntType(64), -1), ip);
    }
    if self._error_frame is not None and self._error_frame.function is func {
        unhandled = func.append_basic_block("err.unhandled");
        propagate = func.append_basic_block("err.return");
        self.builder.cbranch(
            self.builder.icmp_signed(
                "==",
                self.builder.load(self._error_frame.depth),
                ir.Constant(ir.IntType(32), 1)
            ),
            unhandled,
            propagate
        );
        self.builder.position_at_end(unhandled);
        fmt = self._make_global_string(
            "jac: unhandled exception: %s\n", name_prefix=".err.unhandled"
        );
        self.builder.call(
            self._get_printf(),
            [self.builder.bitcast(fmt, i8p, name="err.fmt"), pending[2]]
        );
        abort_fn = self._get_or_declare_extern("abort", ir.VoidType(), []);
        self.builder.call(abort_fn, []);
        self.builder.unreachable();
        self.builder.position_at_end(propagate);
    }
    rt = func.function_type.return_type;
    if isinstance(rt, ir.VoidType) {
        self.builder.ret_void();
    } else {
        self.builder.ret(self._default_arg_fallback(rt));
    }
}

impl NaIRGenPass._emit_err_check(callee: (uni.Ability | None)) -> None {
    if callee is not None {
        self._emit_pending_error_check();
    }
}

impl NaIRGenPass._emit_pending_error_check -> None {
    if self._builder is None or self.builder.block.is_terminated {
        return;
    }
    i32 = ir.IntType(32);
    (tglob, _og, _mg) = self._error_slots(self.builder);
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
    payload: ir.Value | None, type_id: int, msg: ir.Value
) -> None {
    i32 = ir.IntType(32);
    record = self._new_error_record(payload, msg);
    (tglob, oglob, mglob) = self._error_slots(self.builder);
    self.builder.store(
        ir.Constant(ir.IntType(1), 1), self._error_owned_slot(self.builder)
    );
    self.builder.store(ir.Constant(i32, type_id + 1), tglob);
    self.builder.store(self.builder.bitcast(record, ir.IntType(8).as_pointer()), oglob);
    self.builder.store(
        self.builder.load(
            self.builder.gep(record, [ir.Constant(i32, 0), ir.Constant(i32, 1)])
        ),
        mglob
    );
    self._emit_err_propagate(loc="raise");
}

impl NaIRGenPass._codegen_try(nd: uni.TryStmt) -> None {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    func = self.builder.function;
    (tglob, oglob, mglob) = self._error_slots(self.builder);
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
        self._caught_error_stack.append((func, self._spill_error(caught_values)));
        self._clear_pending_error(self.builder, release=False);
        if except_node.name is not None {
            var_name = except_node.name.value
                if isinstance(except_node.name, uni.Name)
                else str(except_node.name);
            if caught is not None and caught in self.struct_types {
                _exc_sp_ty = self.struct_types[caught].as_pointer();
                typed_obj = self.builder.bitcast(
                    self.builder.load(
                        self.builder.gep(
                            self.builder.bitcast(
                                caught_values[1],
                                self._get_error_record_type().as_pointer()
                            ),
                            [ir.Constant(i32, 0), ir.Constant(i32, 0)]
                        )
                    ),
                    _exc_sp_ty,
                    name="exc.bound.typed"
                );
                alloca = self._entry_alloca(_exc_sp_ty, var_name);
                self._emit_rc_retain(typed_obj, op="except.bind");
                self._emit_rc_release_typed(self.builder.load(alloca), op="scope_exit");
                self.builder.store(typed_obj, alloca);
            } else {
                alloca = self._entry_alloca(i8p, var_name);
                self._emit_rc_retain(caught_values[2], op="except.bind");
                self._emit_rc_release_typed(self.builder.load(alloca), op="scope_exit");
                self.builder.store(caught_values[2], alloca);
            }
        }
        if except_node.name is not None {
            self.local_vars[var_name] = alloca;
            if self._nogc_headerless() {
                self.borrowed_vars.add(var_name);
            }
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
    pending = self._spill_error(
        (self.builder.load(tglob), self.builder.load(oglob), self.builder.load(mglob))
    );
    self._clear_pending_error(self.builder, release=False);
    self._caught_error_stack.append((func, pending));
    if nd.finally_body is not None
        and isinstance(nd.finally_body.body, (list, tuple)) {
        self._codegen_body(nd.finally_body.body);
    }
    self._caught_error_stack.pop();
    if not self.builder.block.is_terminated {
        k = self.builder.load(kind, name="try.kind.v");
        is_prop = self.builder.icmp_signed(
            "!=", k, ir.Constant(i32, 0), name="try.propagating"
        );
        prop_bb = func.append_basic_block("try.propagate");
        self.builder.cbranch(is_prop, prop_bb, merge_bb);
        self.builder.position_at_end(prop_bb);
        self._restore_error(pending);
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
            if frame.context_exit is not None {
                (owner, exit_fn) = frame.context_exit;
                self._emit_context_exit(self.builder.load(owner), exit_fn);
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

impl NaIRGenPass._get_error_record_type -> ir.IdentifiedStructType {
    if self._error_record_type is not None {
        return self._error_record_type;
    }
    i8p = ir.IntType(8).as_pointer();
    import from jaclang.compiler.frontend.codeinfo { native_exception_symbol }
    record = self.llvm_module.context.get_identified_type(
        native_exception_symbol("record")
    );
    record.set_body(i8p, i8p, ir.FunctionType(ir.VoidType(), [i8p]).as_pointer());
    self._error_record_type = record;
    return record;
}

impl NaIRGenPass._new_error_record(
    payload: ir.Value | None, msg: ir.Value
) -> ir.Value {
    self._emit_rc_helpers();
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    record_type = self._get_error_record_type();
    drop_type = ir.FunctionType(ir.VoidType(), [i8p]);
    self._get_error_record_drop();
    payload_drop: ir.Value = ir.Constant(drop_type.as_pointer(), None);
    payload_raw: ir.Value = ir.Constant(i8p, None);
    if payload is not None {
        drop_name = f"__jac_error_payload_drop_{str(payload.type)}";
        try {
            payload_drop = self.llvm_module.get_global(drop_name);
        } except KeyError {
            drop = self._define_function(drop_name, drop_type);
            drop.linkage = "private";
            state = self._enter_function(drop);
            try {
                self._emit_rc_release_typed(
                    self.builder.bitcast(drop.args[0], payload.type), op="scope_exit"
                );
                self.builder.ret_void();
            } finally {
                self._leave_function(state);
            }
            payload_drop = drop;
        }
        self._emit_take_ref(payload, op="raise");
        payload_raw = self.builder.bitcast(payload, i8p);
    }
    view = self._str_view(msg);
    length = self.builder.call(
        self._get_or_declare_extern("strlen", i64, [i8p]), [view]
    );
    size = self.builder.add(length, ir.Constant(i64, 1));
    message = self.builder.call(self.rc_alloc_fn, [size], name="error.message");
    self.builder.call(
        self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]),
        [message, view, size]
    );
    self._release_owned_args([msg], op="call_arg");
    raw = self.builder.call(
        self.rc_alloc_fn,
        [ir.Constant(i64, self._abi_sizeof(record_type))],
        name="error.record"
    );
    record = self.builder.bitcast(raw, record_type.as_pointer());
    for (index, value) in enumerate([payload_raw, message, payload_drop]) {
        self.builder.store(
            value,
            self.builder.gep(record, [ir.Constant(i32, 0), ir.Constant(i32, index)])
        );
    }
    if not self._nogc_headerless() {
        destructor_slot = self.builder.bitcast(
            self.builder.gep(raw, [ir.Constant(i64, HDR_DTOR_OFF)]),
            drop_type.as_pointer().as_pointer()
        );
        self.builder.store(self._error_record_drop, destructor_slot);
    }
    return record;
}

impl NaIRGenPass._get_error_clear_fn -> ir.Function {
    import from jaclang.compiler.frontend.codeinfo { native_exception_symbol }
    func = self._get_or_declare_extern(
        native_exception_symbol("clear"), ir.VoidType(), []
    );
    if not func.basic_blocks {
        func.linkage = "weak";
        b = ir.IRBuilder(func.append_basic_block("entry"));
        self._clear_pending_error(b);
        b.ret_void();
    }
    return func;
}

impl NaIRGenPass._error_owned_slot(b: ir.IRBuilder) -> ir.Value {
    frame = self._error_frame;
    if frame is not None and frame.function is b.function {
        return frame.owns_error;
    }
    context = b.call(self._get_exception_context_fn(), []);
    return b.gep(
        context, [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 4)]
    );
}

impl NaIRGenPass._get_error_record_drop -> ir.Function {
    if self._error_record_drop is not None {
        return self._error_record_drop;
    }
    self._emit_rc_helpers();
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    record_type = self._get_error_record_type();
    drop_type = ir.FunctionType(ir.VoidType(), [i8p]);
    drop = self._define_function("__jac_error_record_drop", drop_type);
    drop.linkage = "private";
    self._error_record_drop = drop;
    b = ir.IRBuilder(drop.append_basic_block("entry"));
    work = drop.append_basic_block("work");
    done = drop.append_basic_block("done");
    b.cbranch(b.icmp_unsigned("==", drop.args[0], ir.Constant(i8p, None)), done, work);
    b.position_at_end(work);
    record = b.bitcast(drop.args[0], record_type.as_pointer());
    payload_drop = b.load(b.gep(record, [ir.Constant(i32, 0), ir.Constant(i32, 2)]));
    release_payload = drop.append_basic_block("payload");
    release_message = drop.append_basic_block("message");
    b.cbranch(
        b.icmp_unsigned("!=", payload_drop, ir.Constant(drop_type.as_pointer(), None)),
        release_payload,
        release_message
    );
    b.position_at_end(release_payload);
    b.call(
        payload_drop,
        [b.load(b.gep(record, [ir.Constant(i32, 0), ir.Constant(i32, 0)]))]
    );
    b.branch(release_message);
    b.position_at_end(release_message);
    b.call(
        self.free_fn if self._nogc_headerless() else self.rc_release_simple_fn,
        [b.load(b.gep(record, [ir.Constant(i32, 0), ir.Constant(i32, 1)]))]
    );
    allocation = drop.args[0]
        if self._nogc_headerless()
        else b.gep(drop.args[0], [ir.Constant(i64, HDR_ALLOC_ID_OFF)]);
    b.call(
        self.free_fn if self._nogc_headerless() else self.rc_safe_free_fn, [allocation]
    );
    b.branch(done);
    b.position_at_end(done);
    b.ret_void();
    return drop;
}
