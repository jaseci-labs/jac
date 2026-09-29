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
        ir.IntType(8).as_pointer(),
        ir.IntType(8).as_pointer()
    );
    self._exc_state_type = exc_state;
    return exc_state;
}

impl NaIRGenPass._declare_exception_runtime -> None {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    (setjmp_name, longjmp_name) = self._exc_jmp_symbols();

    setjmp_fn = self._get_or_declare_extern(setjmp_name, i32, [i8p]);
    setjmp_fn.attributes.add("returns_twice");

    longjmp_fn = self._get_or_declare_extern(longjmp_name, ir.VoidType(), [i8p, i32]);
    longjmp_fn.attributes.add("noreturn");

    self._get_or_declare_extern("abort", ir.VoidType(), []);

    self._emit_exc_push_helper();

    self._emit_exc_pop_helper();

    self._emit_exc_raise_helper();
}

impl NaIRGenPass._exc_jmp_symbols -> tuple[str, str] {
    """The setjmp/longjmp pair every native exception frame arms and unwinds through.

    Plain `setjmp` saves the signal mask: on Darwin it costs a `sigprocmask`
    and a `sigaltstack` syscall per armed frame (and `longjmp` two more per
    raise), on glibc it is `__sigsetjmp(env, 1)` and one `rt_sigprocmask`. Jac
    code never changes the mask between arming a frame and raising into it,
    so that is dead work on every `try`, walker spawn and guarded call.
    `_setjmp`/`_longjmp` leave the mask alone. They only work as a pair --
    Darwin's `longjmp` restores the mask from a buffer slot `_setjmp` never
    writes -- so every frame raises through the matching `_longjmp`. Windows
    and wasm keep the portable names: neither saves a mask, and wasm's SjLj
    lowering matches the names.
    """;
    triple = str(self.llvm_module.triple or "").lower();
    if any(
        os_name in triple for os_name in ("wasm", "windows", "win32", "mingw", "msvc")
    ) {
        return ("setjmp", "longjmp");
    }
    return ("_setjmp", "_longjmp");
}

impl NaIRGenPass._exc_setjmp_fn -> ir.Function {
    """The setjmp of `_exc_jmp_symbols`, once `_declare_exception_runtime` ran.""";
    return self.extern_funcs[self._exc_jmp_symbols()[0]];
}

impl NaIRGenPass._exc_longjmp_fn -> ir.Function {
    """The longjmp of `_exc_jmp_symbols`, the pair of `_exc_setjmp_fn`.""";
    return self.extern_funcs[self._exc_jmp_symbols()[1]];
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

    saved_top = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 5)], name="unwind.saved"
    );
    b.store(b.load(self._unwind_top_slot(b), name="unwind.top"), saved_top);

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

    saved_top = b.load(
        b.gep(cur_handler, [ir.Constant(i32, 0), ir.Constant(i32, 5)]),
        name="unwind.saved"
    );
    top_slot = self._unwind_top_slot(b);
    node_ty = self._unwind_node_type();
    cleanup_ty = ir.FunctionType(ir.VoidType(), [i8p]);
    walk_bb = func.append_basic_block("unwind.walk");
    run_bb = func.append_basic_block("unwind.run");
    jump_bb = func.append_basic_block("unwind.jump");
    b.branch(walk_bb);
    b.position_at_end(walk_bb);
    top = b.load(top_slot, name="unwind.top");
    b.cbranch(
        b.icmp_unsigned("==", top, saved_top, name="unwind.done"), jump_bb, run_bb
    );
    b.position_at_end(run_bb);
    link = b.bitcast(top, node_ty.as_pointer(), name="unwind.node");
    prev = b.load(
        b.gep(link, [ir.Constant(i32, 0), ir.Constant(i32, 0)]), name="unwind.prev"
    );
    b.store(prev, top_slot);
    cleanup = b.load(
        b.gep(link, [ir.Constant(i32, 0), ir.Constant(i32, 1)]), name="unwind.fn"
    );
    env = b.load(
        b.gep(link, [ir.Constant(i32, 0), ir.Constant(i32, 2)]), name="unwind.env"
    );
    b.call(b.bitcast(cleanup, cleanup_ty.as_pointer(), name="unwind.fnp"), [env]);
    b.branch(walk_bb);
    b.position_at_end(jump_bb);
    env_ptr = b.gep(
        cur_handler, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="env.ptr"
    );
    env_i8p = b.bitcast(env_ptr, i8p, name="env.i8p");
    b.call(self._exc_longjmp_fn(), [env_i8p, ir.Constant(i32, 1)]);
    b.unreachable();
    self._exc_raise_fn = func;
}

impl NaIRGenPass._emit_runtime_raise(
    is_error: ir.Value,
    exc_type_name: str,
    msg: str,
    release_on_error: list[ir.Value] = []
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
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    roots = [type_name] + JAC_TYPE_REGISTRY.exception_descendants(type_name);
    descendants = roots[1:];
    for cls in get_layout_registry(self.module, self.prog).mro_order {
        if cls in roots or cls in descendants {
            continue;
        }
        if any(anc in roots for anc in self._mro_of(cls)[1:]) {
            descendants.append(cls);
        }
    }
    for desc_name in descendants {
        self._get_or_register_exc_type(desc_name);
    }
    return descendants;
}

impl NaIRGenPass._exception_member_name(member: uni.UniNode) -> (str | None) {
    name: str | None = None;
    if isinstance(member, uni.Name) {
        name = member.value;
    } elif isinstance(member, uni.AtomTrailer) and isinstance(member.right, uni.Name) {
        name = member.right.value;
    }
    if name is None {
        return None;
    }
    arch_key = self._arch_ref_key(member);
    if arch_key is not None {
        return arch_key;
    }
    import from jaclang.compiler.types.types { ClassType }
    import from jaclang.compiler.passes.layout_pass { class_type_native_name }
    if isinstance(member, uni.Expr) and isinstance(member.type, ClassType) {
        name = class_type_native_name(member.type) or name;
    }
    return name;
}

impl NaIRGenPass._exception_handler_targets(ex: uni.Expr | None) -> (list[str] | None) {
    if ex is None {
        return None;
    }
    members = list(ex.values) if isinstance(ex, uni.TupleVal) else [ex];
    targets: list[str] = [];
    for member in members {
        name = self._exception_member_name(member);
        if name is None {
            self.ctx.emit(
                E5090,
                node_override=member,
                kind="exception handler",
                name="dynamic exception type"
            );
            continue;
        }
        if name in ("Exception", "BaseException") {
            return None;
        }
        for candidate in [name] + self._get_exc_descendants(name) {
            if candidate not in targets {
                targets.append(candidate);
            }
        }
    }
    return targets;
}

impl NaIRGenPass._emit_exception_match(
    type_val: ir.Value,
    obj_val: ir.Value,
    msg_val: ir.Value,
    targets: list[str],
    id_bias: int,
    on_match: ir.Block,
    on_miss: ir.Block
) -> None {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    b = self.builder;
    i32 = ir.IntType(32);
    does_match: ir.Value = ir.Constant(ir.IntType(1), 0);
    for name in targets {
        tid = self._get_or_register_exc_type(name);
        does_match = b.or_(
            does_match,
            b.icmp_signed(
                "==", type_val, ir.Constant(i32, tid + id_bias), name=f"exc.is.{tid}"
            ),
            name="exc.match"
        );
    }
    if targets {
        raised = b.sub(type_val, ir.Constant(i32, id_bias), name="exc.raised")
            if id_bias
            else type_val;
        does_match = b.or_(
            does_match,
            self._emit_exc_lineage_match(
                raised, [self._get_or_register_exc_type(name) for name in targets]
            ),
            name="exc.match.lineage"
        );
    }
    known: set[str] = set();
    for mro in get_layout_registry(self.module, self.prog).mro_order.values() {
        known.update(mro);
    }
    isa_names = [
        name
        for name in targets
        if name in known
    ];
    if not isa_names or self._emit_runtime_class_name_fn() is None {
        b.cbranch(does_match, on_match, on_miss);
        return;
    }
    func = b.function;
    obj_bb = func.append_basic_block("exc.match.obj");
    isa_bb = func.append_basic_block("exc.match.isa");
    b.cbranch(does_match, on_match, obj_bb);
    b.position_at_end(obj_bb);
    is_obj = b.and_(
        b.icmp_unsigned("!=", obj_val, msg_val, name="exc.obj.own"),
        b.icmp_unsigned(
            "!=", obj_val, ir.Constant(obj_val.type, None), name="exc.obj.set"
        ),
        name="exc.obj.is"
    );
    b.cbranch(is_obj, isa_bb, on_miss);
    b.position_at_end(isa_bb);
    hit = self._isinstance_class_name_hit(obj_val, isa_names);
    if hit is None {
        b.branch(on_miss);
    } else {
        b.cbranch(hit, on_match, on_miss);
    }
}

impl NaIRGenPass._exc_message_slot(type_name: str) -> (int | None) {
    import from jaclang.compiler.passes.layout_pass { EXC_MESSAGE_FIELD }
    return self.struct_field_indices.get(type_name, {}).get(EXC_MESSAGE_FIELD);
}

impl NaIRGenPass._ctor_arg_value(
    arg: uni.UniNode, pre: dict[int, ir.Value]
) -> (ir.Value | None) {
    if id(arg) in pre {
        return pre.pop(id(arg));
    }
    return self._codegen_expr(arg);
}

impl NaIRGenPass._store_exc_message(
    obj_ptr: ir.Value,
    type_name: str,
    args: list[uni.Expr],
    pre: dict[int, ir.Value],
    shared: bool
) -> bool {
    import from jaclang.compiler.passes.layout_pass { EXC_MESSAGE_FIELD }
    values: list[ir.Value] = [];
    for arg in args {
        val = self._codegen_expr(arg);
        if val is None {
            return False;
        }
        values.append(val);
        pre[id(arg)] = val;
    }
    moved = len(args) == 1 and not shared and self._type_key_of(args[0]) == "str";
    text: ir.Value | None = None;
    if moved {
        text = pre.pop(id(args[0]));
    } else {
        text = self._exc_args_text(values, args, shared);
    }
    if text is None {
        return False;
    }
    i32 = ir.IntType(32);
    copied = False;
    if self._nogc_headerless() and not self._is_owned(text) {
        i8p = ir.IntType(8).as_pointer();
        text = self._mark_owned(
            self._call_str_dup(
                self.builder,
                self._coerce_type(self._str_norm(text), i8p),
                name="exc.msg.own"
            )
        );
        copied = True;
    }
    text = self._coerce_type(
        text, self.struct_field_types[type_name][EXC_MESSAGE_FIELD]
    );
    self._emit_take_ref(text, op="ctor_field");
    self.builder.store(
        text,
        self.builder.gep(
            obj_ptr,
            [
                ir.Constant(i32, 0),
                ir.Constant(
                    i32, self.struct_field_indices[type_name][EXC_MESSAGE_FIELD]
                )
            ],
            name="field.exc.msg"
        )
    );
    if moved and not copied {
        self._nogc_consume_local(args[0]);
    }
    return True;
}

impl NaIRGenPass._exc_args_text(
    values: list[ir.Value], nodes: list[uni.Expr], shared: bool
) -> (ir.Value | None) {
    i8p = ir.IntType(8).as_pointer();
    if len(values) == 1 {
        if shared and self._type_key_of(nodes[0]) == "str" {
            text = self._coerce_type(self._str_norm(values[0]), i8p);
            return self._mark_owned(
                self._call_str_dup(self.builder, text, name="exc.msg.dup")
            );
        }
        shown = self._dispatch_builtin(
            "str",
            [values[0]],
            type_key=self._type_key_of(nodes[0]) or "",
            arg_nodes=[nodes[0]]
        );
        return self._mark_owned(shown) if shown is not None else None;
    }
    acc = self._entry_alloca(i8p, "exc.args.acc");
    self.builder.store(self._repr_const_str("("), acc);
    for i in range(len(values)) {
        piece = self._dispatch_builtin(
            "repr",
            [values[i]],
            type_key=self._type_key_of(nodes[i]) or "",
            arg_nodes=[nodes[i]]
        );
        if piece is None {
            return None;
        }
        if i > 0 {
            self._repr_acc_concat(acc, self._repr_const_str(", "), False);
        }
        self._repr_acc_concat(acc, self._mark_owned(piece), True);
    }
    self._repr_acc_concat(acc, self._repr_const_str(")"), False);
    return self._mark_owned(self.builder.load(acc, name="exc.args.text"));
}

impl NaIRGenPass._exc_stored_message(obj_val: ir.Value, type_name: str) -> ir.Value {
    import from jaclang.compiler.passes.layout_pass { EXC_MESSAGE_FIELD }
    i8p = ir.IntType(8).as_pointer();
    raw = self._codegen_field_access(obj_val, EXC_MESSAGE_FIELD, type_name);
    if raw is None {
        return ir.Constant(i8p, None);
    }
    return self._coerce_type(self._str_norm(raw), i8p);
}

impl NaIRGenPass._emit_exc_message_str(obj_val: ir.Value, type_name: str) -> ir.Value {
    b = self.builder;
    raw = self._exc_stored_message(obj_val, type_name);
    text = b.select(
        b.icmp_unsigned("==", raw, ir.Constant(raw.type, None), name="exc.str.none"),
        self._make_global_string("", name_prefix=".exc.str.empty"),
        raw,
        name="exc.str"
    );
    if self._nogc_headerless() {
        return self._mark_owned(self._call_str_dup(b, text, name="exc.str.dup"));
    }
    self._emit_rc_retain(text, op="exc_str");
    return self._mark_owned(text);
}

impl NaIRGenPass._exc_state_message(obj_val: ir.Value, type_name: str) -> ir.Value {
    b = self.builder;
    raw = self._exc_stored_message(obj_val, type_name);
    return b.select(
        b.icmp_unsigned("==", raw, ir.Constant(raw.type, None), name="exc.msg.none"),
        self._make_global_string(self._arch_display(type_name), name_prefix=".exc.msg"),
        raw,
        name="exc.state.msg"
    );
}

impl NaIRGenPass._exc_bound_struct(ex: (uni.Expr | None)) -> (str | None) {
    if ex is None or isinstance(ex, uni.TupleVal) {
        return None;
    }
    key = self._exception_member_name(ex);
    if key is None or key not in self.struct_types {
        return None;
    }
    if f"{key}.init" in self.method_funcs
        or f"{key}.__init__" in self.method_funcs
        or self._exc_message_slot(key) is not None {
        return key;
    }
    return key if self.struct_field_order.get(key) else None;
}

impl NaIRGenPass._reraise_caught(values: tuple[ir.Value, ir.Value, ir.Value]) -> None {
    if self._slot_lowering_active() {
        for (slot, value) in zip(self._nogc_err_slot(), values) {
            self.builder.store(value, slot);
        }
        held = self._slot_caught_drops.get(id(values));
        if held is not None {
            (drop_slot, handed_back) = held;
            self.builder.store(handed_back, self._nogc_err_drop_slot());
            self.builder.store(ir.Constant(handed_back.type, None), drop_slot);
        }
        self._emit_err_propagate(loc="reraise");
    } else {
        self.builder.call(self._exc_raise_fn, [values[1], values[0], values[2]]);
        self.builder.unreachable();
    }
}

impl NaIRGenPass._reraise_if_bound(cause: uni.Expr) -> None {
    if not isinstance(cause, uni.Name) {
        return;
    }
    func = self.builder.function;
    for (owner, name, alloca, bound, values) in reversed(self._exc_bindings) {
        if owner is not func or name != cause.value {
            continue;
        }
        if self.local_vars.get(name) is not alloca {
            return;
        }
        i64 = ir.IntType(64);
        current = self.builder.load(alloca, name="reraise.cur");
        same = self.builder.icmp_unsigned(
            "==",
            self.builder.ptrtoint(current, i64),
            self.builder.ptrtoint(bound, i64),
            name="reraise.same"
        );
        caught_bb = func.append_basic_block(name="reraise.caught");
        fresh_bb = func.append_basic_block(name="raise.fresh");
        self.builder.cbranch(same, caught_bb, fresh_bb);
        self.builder.position_at_end(caught_bb);
        self._reraise_caught(values);
        self.builder.position_at_end(fresh_bb);
        return;
    }
}

impl NaIRGenPass._exc_lineage_fns -> tuple[ir.Function, ir.Function] {
    if "__jac_exc_lineage_has" in self.extern_funcs {
        return (
            self.extern_funcs["__jac_exc_lineage_add"],
            self.extern_funcs["__jac_exc_lineage_has"]
        );
    }
    i1 = ir.IntType(1);
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    table_ty = ir.ArrayType(i64, EXC_LINEAGE_SLOTS);
    table = ir.GlobalVariable(self.llvm_module, table_ty, name="__jac_exc_lineage");
    table.linkage = "weak";
    table.initializer = ir.Constant(table_ty, None);
    atomic = "wasm" not in str(self.llvm_module.triple or "");

    has_fn = ir.Function(
        self.llvm_module, ir.FunctionType(i1, [i64]), name="__jac_exc_lineage_has"
    );
    has_fn.linkage = "linkonce_odr";
    has_fn.args[0].name = "key";
    b = ir.IRBuilder(has_fn.append_basic_block("entry"));
    (_slot, _v, found, empty, full) = self._emit_exc_lineage_probe(
        b, table, has_fn.args[0], atomic
    );
    ir.IRBuilder(found).ret(ir.Constant(i1, 1));
    ir.IRBuilder(empty).ret(ir.Constant(i1, 0));
    ir.IRBuilder(full).ret(ir.Constant(i1, 0));

    add_fn = ir.Function(
        self.llvm_module,
        ir.FunctionType(ir.VoidType(), [i64]),
        name="__jac_exc_lineage_add"
    );
    add_fn.linkage = "linkonce_odr";
    add_fn.args[0].name = "key";
    key = add_fn.args[0];
    start_bb = add_fn.append_basic_block("entry");
    insert = add_fn.append_basic_block("insert");
    done = add_fn.append_basic_block("done");
    b = ir.IRBuilder(start_bb);
    b.cbranch(b.call(has_fn, [key], name="known"), done, insert);
    b = ir.IRBuilder(insert);
    lock: (ir.GlobalVariable | None) = None;
    if atomic {
        lock = ir.GlobalVariable(self.llvm_module, i64, name="__jac_exc_lineage_lock");
        lock.linkage = "weak";
        lock.initializer = zero;
        spin = add_fn.append_basic_block("lock");
        held = add_fn.append_basic_block("held");
        b.branch(spin);
        b = ir.IRBuilder(spin);
        old = b.atomic_rmw(
            "xchg", lock, ir.Constant(i64, 1), ordering="acquire", name="lock.old"
        );
        b.cbranch(b.icmp_unsigned("!=", old, zero), spin, held);
        b = ir.IRBuilder(held);
    }
    (slot, _v, found, empty, full) = self._emit_exc_lineage_probe(b, table, key, False);
    unlock = add_fn.append_basic_block("unlock");
    ir.IRBuilder(found).branch(unlock);
    ir.IRBuilder(full).branch(unlock);
    b = ir.IRBuilder(empty);
    if atomic {
        b.store_atomic(key, slot, "release", 8);
    } else {
        b.store(key, slot);
    }
    b.branch(unlock);
    b = ir.IRBuilder(unlock);
    if lock is not None {
        b.store_atomic(zero, lock, "release", 8);
    }
    b.branch(done);
    ir.IRBuilder(done).ret_void();

    self.extern_funcs["__jac_exc_lineage_has"] = has_fn;
    self.extern_funcs["__jac_exc_lineage_add"] = add_fn;
    return (add_fn, has_fn);
}

impl NaIRGenPass._emit_exc_lineage_probe(
    b: ir.IRBuilder, table: ir.GlobalVariable, key: ir.Value, atomic: bool
) -> tuple[ir.Value, ir.Value, ir.Block, ir.Block, ir.Block] {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    func = b.function;
    start = b.block;
    loop = func.append_basic_block("probe");
    step = func.append_basic_block("probe.next");
    miss = func.append_basic_block("probe.miss");
    found = func.append_basic_block("probe.found");
    empty = func.append_basic_block("probe.empty");
    full = func.append_basic_block("probe.full");
    mixed = b.mul(key, ir.Constant(i64, EXC_LINEAGE_MIX), name="probe.mix");
    home = b.lshr(mixed, ir.Constant(i64, 64 - EXC_LINEAGE_BITS), name="probe.home");
    b.branch(loop);
    b = ir.IRBuilder(loop);
    idx = b.phi(i64, name="probe.idx");
    tried = b.phi(i64, name="probe.tried");
    slot = b.gep(table, [ir.Constant(i32, 0), idx], name="probe.slot");
    value = b.load_atomic(slot, "acquire", 8, name="probe.v")
        if atomic
        else b.load(slot, name="probe.v");
    b.cbranch(b.icmp_unsigned("==", value, key), found, miss);
    b = ir.IRBuilder(miss);
    b.cbranch(b.icmp_unsigned("==", value, ir.Constant(i64, 0)), empty, step);
    b = ir.IRBuilder(step);
    nxt = b.and_(
        b.add(idx, ir.Constant(i64, 1)),
        ir.Constant(i64, EXC_LINEAGE_SLOTS - 1),
        name="probe.nxt"
    );
    more = b.add(tried, ir.Constant(i64, 1), name="probe.more");
    b.cbranch(
        b.icmp_unsigned("==", more, ir.Constant(i64, EXC_LINEAGE_SLOTS)), full, loop
    );
    idx.add_incoming(home, start);
    idx.add_incoming(nxt, step);
    tried.add_incoming(ir.Constant(i64, 0), start);
    tried.add_incoming(more, step);
    return (slot, value, found, empty, full);
}

impl NaIRGenPass._emit_exc_lineage_match(
    type_val: ir.Value, bases: list[int]
) -> ir.Value {
    i64 = ir.IntType(64);
    (_add, has_fn) = self._exc_lineage_fns();
    high = self.builder.shl(
        self.builder.zext(type_val, i64), ir.Constant(i64, 32), name="exc.lineage.hi"
    );
    matched: ir.Value = ir.Constant(ir.IntType(1), 0);
    for base in bases {
        key = self.builder.or_(high, ir.Constant(i64, base), name="exc.lineage.key");
        matched = self.builder.or_(
            matched, self.builder.call(has_fn, [key], name="exc.lineage.has")
        );
    }
    return matched;
}

impl NaIRGenPass._register_exc_lineage(cause: (uni.Expr | None), type_id: int) -> None {
    import from jaclang.compiler.types.types { ClassType, TypeBase }
    import from jaclang.compiler.passes.layout_pass { class_type_native_name }
    if type_id == 0 or cause is None {
        return;
    }
    typ = cause.type;
    if not isinstance(typ, ClassType) or typ._shared is None {
        return;
    }
    if not isinstance(typ.shared.symbol_table, uni.Archetype) {
        return;
    }
    ancestors: list[int] = [];
    seen: set[int] = set();
    pending: list[TypeBase] = list(typ.shared.base_classes);
    while pending {
        base = pending.pop(0);
        if not isinstance(base, ClassType) or base._shared is None {
            continue;
        }
        if id(base.shared) in seen {
            continue;
        }
        seen.add(id(base.shared));
        name = class_type_native_name(base) or base.shared.class_name;
        if name not in ("object", "Exception", "BaseException") {
            aid = self._get_or_register_exc_type(name);
            if aid not in (0, type_id) and aid not in ancestors {
                ancestors.append(aid);
            }
        }
        pending.extend(base.shared.base_classes);
    }
    if not ancestors {
        return;
    }
    (add_fn, _has) = self._exc_lineage_fns();
    for aid in ancestors {
        self.builder.call(add_fn, [ir.Constant(ir.IntType(64), (type_id << 32) | aid)]);
    }
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
                self._reraise_caught(values);
                return;
            }
        }
    } elif isinstance(nd.cause, uni.Name) {
        self._reraise_if_bound(nd.cause);
    }
    exc_payload: (ir.Value | None) = None;
    exc_msg: (ir.Value | None) = None;
    exc_type_name = "Exception";
    exc_type_id = 0;
    if nd.cause is not None {
        if isinstance(nd.cause, uni.FuncCall)
            and (
                (self._arch_ref_key(nd.cause.target) or self._get_name(nd.cause.target))
                    in self.struct_types
                or self._struct_name_of(nd.cause) not in self.struct_types
            ) {
            exc_type_name = self._arch_ref_key(nd.cause.target)
                or self._get_name(nd.cause.target)
                or "Exception";
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
            _exc_struct_ok = _exc_has_init
                or self._exc_message_slot(exc_type_name) is not None;
            if (not _exc_struct_ok) and (_exc_order is not None) {
                _exc_struct_ok = len(_exc_pos_args) <= len(_exc_order);
            }
            if (exc_type_name in self.struct_types) and _exc_struct_ok {
                exc_payload = self._codegen_expr(nd.cause);
                if exc_payload is not None
                    and self._exc_message_slot(exc_type_name) is not None {
                    exc_msg = self._exc_state_message(exc_payload, exc_type_name);
                }
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
                if exc_payload is not None {
                    self._emit_take_ref(exc_payload, op="raise");
                    if self._exc_message_slot(cause_struct) is not None {
                        exc_msg = self._exc_state_message(exc_payload, cause_struct);
                    }
                }
            } else {
                exc_msg = self._codegen_expr(nd.cause);
            }
        }
    }

    if exc_msg is None {
        exc_msg = self._make_global_string(
            self._arch_display(exc_type_name), name_prefix=".exc.msg"
        );
    }
    exc_msg = self._str_norm(exc_msg);
    exc_payload = self._str_norm_optional(exc_payload);
    if exc_msg is None {
        return;
    }
    exc_drop: (ir.Value | None) = None;
    if self._slot_lowering_active() and self._nogc_headerless() {
        exc_drop = self._raise_payload_drop(exc_payload, exc_msg, exc_type_name);
    }

    if isinstance(exc_msg.type, ir.PointerType) and exc_msg.type != i8p {
        exc_msg = self.builder.bitcast(exc_msg, i8p, name="exc.msg.cast");
    }
    if exc_payload is None {
        exc_payload = exc_msg;
    } elif isinstance(exc_payload.type, ir.PointerType) and exc_payload.type != i8p {
        exc_payload = self.builder.bitcast(exc_payload, i8p, name="exc.obj.cast");
    }

    self._register_exc_lineage(nd.cause, exc_type_id);
    if self._slot_lowering_active() {
        self._codegen_raise_slot(exc_payload, exc_type_id, exc_msg, exc_drop);
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
    } elif nd.finally_body is not None {
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

    self._mark_setjmp_function(func);

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
            NativeGeneratorHandler(
                state=exc_state, dispatch=dispatch_bb, depth=_rgn_depth_slot
            )
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

            caught_struct = self._exc_bound_struct(except_node.ex_type);
            caught_targets = self._exception_handler_targets(except_node.ex_type);

            if i > 0 {
                self.builder.position_at_end(current_dispatch_bb);

                exc_type_val = self.builder.load(exc_type_ptr, name=f"exc.type.{i}");
                exc_obj_val = self.builder.load(exc_obj_ptr, name=f"exc.obj.{i}");
            }

            if caught_targets is None {
                self.builder.branch(handler_bb);
            } else {
                exc_msg_val = self.builder.load(exc_msg_slot, name=f"exc.msg.{i}");
                if next_dispatch_bb is not None {
                    self._emit_exception_match(
                        exc_type_val,
                        exc_obj_val,
                        exc_msg_val,
                        caught_targets,
                        0,
                        handler_bb,
                        next_dispatch_bb
                    );
                } else {
                    reraise_bb = func.append_basic_block(name="except.reraise");
                    self._emit_exception_match(
                        exc_type_val,
                        exc_obj_val,
                        exc_msg_val,
                        caught_targets,
                        0,
                        handler_bb,
                        reraise_bb
                    );
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

                if caught_struct is not None {
                    handler_exc_obj = self.builder.load(
                        exc_obj_ptr, name="exc.bound.obj"
                    );
                    _exc_sp_ty = self.struct_types[caught_struct].as_pointer();
                    bound_val = self.builder.bitcast(
                        handler_exc_obj, _exc_sp_ty, name="exc.bound.typed"
                    );
                    alloca = self._exc_binding_slot(var_name, _exc_sp_ty);
                } else {
                    bound_val = self.builder.load(exc_msg_slot, name="exc.bound.msg");
                    alloca = self._exc_binding_slot(var_name, i8p);
                }
                _rebind = not self._nogc_headerless() and not _in_gen;
                _bound_old = self.builder.load(alloca, name="exc.bound.old")
                    if _rebind
                    else None;
                self.builder.store(bound_val, alloca);
                if _bound_old is not None {
                    self._emit_rc_release_typed(_bound_old, op="overwrite");
                }
                self.local_vars[var_name] = alloca;
            }

            caught_values = self._exception_values(exc_state);
            self._caught_error_stack.append((func, caught_values));
            if except_node.name is not None {
                self._exc_bindings.append(
                    (func, var_name, alloca, bound_val, caught_values)
                );
            }
            self._finally_stack.append(frame);
            if isinstance(except_node.body, (list, tuple)) {
                self._codegen_body(except_node.body);
            }
            self._finally_stack.pop();
            if except_node.name is not None {
                self._exc_bindings.pop();
            } elif not self.builder.block.is_terminated
                and not _in_gen
                and not self._nogc_headerless() {
                self._emit_rc_release_typed(
                    self.builder.load(
                        self.builder.gep(
                            exc_state, [ir.Constant(i32, 0), ir.Constant(i32, 1)]
                        ),
                        name="exc.unbound.obj"
                    ),
                    op="scope_exit"
                );
            }
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
        bool(getattr(self.module.gen, "nogc_enforced", False))
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
    context_type = ir.LiteralStructType([i32, i8p, i8p, i8p, i8p]);
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

impl NaIRGenPass._exc_binding_slot(var_name: str, slot_type: ir.Type) -> ir.Value {
    """The local an `except ... as name` binds, shared by every handler of the name.

    Each handler used to take a fresh slot for the name, so scope exit (which
    releases the slot the name maps to last) never released what an earlier
    handler bound: one caught exception leaked per function per such handler.
    """;
    existing = self.local_vars.get(var_name);
    if not self._nogc_headerless()
        and self._gen_ctx is None
        and isinstance(existing, ir.AllocaInstr)
        and existing.type == slot_type.as_pointer()
        and existing.parent is self.builder.function.entry_basic_block {
        return existing;
    }
    return self._entry_alloca(slot_type, var_name);
}

impl NaIRGenPass._unwind_top_slot(b: ir.IRBuilder) -> ir.Value {
    """The thread's unwind chain head: the newest frame that owns rc locals.""";
    context = b.call(self._get_exception_context_fn(), []);
    return b.gep(
        context, [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 4)]
    );
}

impl NaIRGenPass._unwind_node_type -> ir.Type {
    """`{prev, cleanup, env}`: one frame's link in the unwind chain.""";
    i8p = ir.IntType(8).as_pointer();
    return ir.LiteralStructType([i8p, i8p, i8p]);
}

impl NaIRGenPass._register_unwind_cleanup -> None {
    """Let a raise that crosses this frame release its owned locals.

    A raise reaches its handler with `longjmp`, which skips every frame in
    between, and with them the scope cleanup each frame would have run on a
    normal return: every rc object those frames held leaked, once per raise.
    A frame that owns such locals now links a node into the thread's unwind
    chain on entry (its local slots and a cleanup function built from the
    same scope cleanup a return runs) and unlinks it on every return. The
    raise walks the chain down to the handler's saved head, releasing each
    crossed frame's locals, before it jumps. A frame whose locals need no
    cleanup (scalars, borrowed values, parameters) links nothing.
    """;
    if self._builder is None or self._gen_ctx is not None {
        return;
    }
    func = self._builder.function;
    if func is None
        or not func.blocks
        or any(not blk.is_terminated for blk in func.blocks)
        or bool(getattr(self.module.gen, "nogc_enforced", False))
        or "wasm" in str(self.llvm_module.triple) {
        return;
    }
    slots: list[tuple[str, ir.Value]] = [];
    for (name, slot) in self.local_vars.items() {
        if isinstance(slot, ir.AllocaInstr)
            and slot.parent is func.entry_basic_block
            and name not in self.param_vars
            and name not in self.borrowed_vars
            and name not in self.closure_cell_handles
            and name not in self.region_handle_vars {
            slots.append((name, slot));
        }
    }
    if not slots {
        return;
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    saved = (
        self._builder,
        self.local_vars,
        self.region_open_stack,
        self.closure_cell_handles
    );
    probe = func.append_basic_block(name="unwind.probe");
    try {
        self._builder = ir.IRBuilder(probe);
        self.local_vars = dict(slots);
        self.region_open_stack = [];
        self.closure_cell_handles = {};
        self._emit_scope_cleanup(skip_var=None, loc="unwind");
        pending = len(probe.instructions) > 0;
    } finally {
        func.blocks.remove(probe);
        (
            self._builder,
            self.local_vars,
            self.region_open_stack,
            self.closure_cell_handles
        ) = saved;
    }
    if not pending {
        return;
    }
    cleanup_ty = ir.FunctionType(ir.VoidType(), [i8p]);
    cleanup = ir.Function(self.llvm_module, cleanup_ty, name=f"{func.name}.__unwind");
    cleanup.linkage = "private";
    env_ty = ir.ArrayType(i8p, len(slots));
    try {
        cb = ir.IRBuilder(cleanup.append_basic_block("entry"));
        env = cb.bitcast(cleanup.args[0], env_ty.as_pointer(), name="env");
        mapped: dict[str, ir.Value] = {};
        for (k, (name, slot)) in enumerate(slots) {
            raw = cb.load(
                cb.gep(env, [ir.Constant(i32, 0), ir.Constant(i32, k)]),
                name=f"unwind.{name}"
            );
            mapped[name] = cb.bitcast(raw, slot.type, name=f"unwind.{name}.slot");
        }
        self._builder = cb;
        self.local_vars = mapped;
        self.region_open_stack = [];
        self.closure_cell_handles = {};
        self._emit_scope_cleanup(skip_var=None, loc="unwind");
        cb.ret_void();
    } finally {
        (
            self._builder,
            self.local_vars,
            self.region_open_stack,
            self.closure_cell_handles
        ) = saved;
    }
    entry_blk = func.entry_basic_block;
    anchor: any = None;
    for inst in entry_blk.instructions {
        if isinstance(inst, ir.AllocaInstr) {
            continue;
        }
        if isinstance(inst, ir.StoreInstr)
            and isinstance(inst.operands[1], ir.AllocaInstr)
            and isinstance(inst.operands[0], ir.Constant) {
            continue;
        }
        anchor = inst;
        break;
    }
    b = ir.IRBuilder(entry_blk);
    if anchor is not None {
        b.position_before(anchor);
    } else {
        b.position_at_end(entry_blk);
    }
    env_slot = b.alloca(env_ty, name="unwind.env");
    for (k, (_name, slot)) in enumerate(slots) {
        b.store(
            b.bitcast(slot, i8p),
            b.gep(env_slot, [ir.Constant(i32, 0), ir.Constant(i32, k)])
        );
    }
    node_ty = self._unwind_node_type();
    link = b.alloca(node_ty, name="unwind.node");
    top_slot = self._unwind_top_slot(b);
    prev = b.load(top_slot, name="unwind.prev");
    b.store(prev, b.gep(link, [ir.Constant(i32, 0), ir.Constant(i32, 0)]));
    b.store(
        b.bitcast(cleanup, i8p), b.gep(link, [ir.Constant(i32, 0), ir.Constant(i32, 1)])
    );
    b.store(
        b.bitcast(env_slot, i8p),
        b.gep(link, [ir.Constant(i32, 0), ir.Constant(i32, 2)])
    );
    b.store(b.bitcast(link, i8p), top_slot);
    for blk in list(func.blocks) {
        term = blk.instructions[-1] if blk.instructions else None;
        if not isinstance(term, ir.Ret) {
            continue;
        }
        at: any = term;
        if len(blk.instructions) >= 2 {
            before = blk.instructions[-2];
            if isinstance(before, ir.CallInstr) and before.tail == "musttail" {
                at = before;
            }
        }
        b.position_before(at);
        b.store(prev, top_slot);
    }
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

impl NaIRGenPass._nogc_err_drop_slot -> ir.Value {
    """The error record's drop slot: how to free the pending payload.

    A raise that hands its payload to the record stores the function that
    frees it here, and null when the payload is not the record's to free (a
    static message, or an object someone else still owns). Whoever takes the
    error off the record takes this with it.
    """;
    i32 = ir.IntType(32);
    context = self.builder.call(self._get_exception_context_fn(), []);
    return self.builder.gep(context, [ir.Constant(i32, 0), ir.Constant(i32, 4)]);
}

impl NaIRGenPass._raise_payload_drop(
    payload: (ir.Value | None), msg: ir.Value, type_name: str
) -> (ir.Value | None) {
    """The drop a raise hands to the error record with its payload, if any.

    Only a value the raise owns outright is handed over: a freshly built
    exception object is dropped through its class's drop (which reads the
    object's own vtable for a subclass), and a freshly built message string
    is freed. A borrowed object or a static message gets no drop.
    """;
    i8p = ir.IntType(8).as_pointer();
    if payload is not None and payload is not msg {
        if not self._is_owned(payload) or type_name not in self.struct_types {
            return None;
        }
        drop_fn = self._emit_struct_drop_fn(type_name);
        if drop_fn is None {
            return None;
        }
        return self.builder.bitcast(drop_fn, i8p, name="exc.drop.obj");
    }
    if msg.type != i8p or not self._is_owned(msg) {
        return None;
    }
    free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
    return self.builder.bitcast(free_fn, i8p, name="exc.drop.msg");
}

impl NaIRGenPass._emit_caught_drop(drop_slot: ir.Value, obj_slot: ir.Value) -> None {
    """Drop the exception a handler took off the error record, then forget it.""";
    i8p = ir.IntType(8).as_pointer();
    func = self.builder.function;
    drop = self.builder.load(drop_slot, name="exc.drop");
    call_bb = func.append_basic_block("exc.drop.call");
    done_bb = func.append_basic_block("exc.drop.done");
    self.builder.cbranch(
        self.builder.icmp_unsigned(
            "!=", drop, ir.Constant(i8p, None), name="exc.drop.set"
        ),
        call_bb,
        done_bb
    );
    self.builder.position_at_end(call_bb);
    drop_ty = ir.FunctionType(ir.VoidType(), [i8p]).as_pointer();
    self.builder.call(
        self.builder.bitcast(drop, drop_ty, name="exc.drop.fn"),
        [self.builder.load(obj_slot, name="exc.drop.obj")]
    );
    self.builder.store(ir.Constant(i8p, None), drop_slot);
    self.builder.branch(done_bb);
    self.builder.position_at_end(done_bb);
}

impl NaIRGenPass._exc_binding_escapes(handler: uni.Except) -> bool {
    """Can the exception bound by `except ... as e` outlive its handler?

    The handler drops the caught exception when it ends, so every use of the
    binding must only read it: an argument to a plain function call, an
    operand of arithmetic, comparison or `not`, an f-string part, a branch
    condition, a statement of its own, or `raise e`, reached directly or
    through attribute, index and method-call chains rooted at `e`. Anything
    else -- storing it, returning it, putting it in a container, handing it to
    a method, capturing it in a closure -- may keep a reference past the
    drop, so the handler leaves such an exception undropped.
    """;
    if not isinstance(handler.name, uni.Name) {
        return False;
    }
    bound = handler.name.value;
    for stmt in handler.body or [] {
        for use in stmt.get_all_sub_nodes(typ=uni.Name) {
            if use.value != bound or use is handler.name {
                continue;
            }
            scope = use.parent;
            while scope is not None and scope is not handler {
                if isinstance(scope, (uni.LambdaExpr, uni.Ability)) {
                    return True;
                }
                scope = scope.parent;
            }
            cur: uni.UniNode = use;
            while (isinstance(cur.parent, uni.AtomTrailer) and cur.parent.target is cur)
                or (
                    isinstance(cur.parent, uni.FuncCall) and cur.parent.target is cur
                ) {
                cur = cur.parent;
            }
            up = cur.parent;
            if isinstance(up, uni.KWPair) {
                cur = up;
                up = up.parent;
            }
            if isinstance(up, uni.FuncCall) {
                if isinstance(up.target, uni.Name) and cur in list(up.params or []) {
                    continue;
                }
                return True;
            }
            if isinstance(
                up, (uni.ExprStmt, uni.FormattedValue, uni.BinaryExpr, uni.CompareExpr)
            ) {
                continue;
            }
            if isinstance(up, uni.UnaryExpr)
                and isinstance(up.op, uni.Token)
                and up.op.name == Tok.NOT {
                continue;
            }
            if isinstance(up, (uni.IfStmt, uni.WhileStmt)) and up.condition is cur {
                continue;
            }
            if isinstance(up, uni.RaiseStmt) and up.cause is cur and cur is use {
                continue;
            }
            if isinstance(up, uni.Assignment) and cur in list(up.target) {
                continue;
            }
            return True;
        }
    }
    return False;
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

impl NaIRGenPass._emit_err_check(
    callee: (uni.Ability | None), site: (uni.UniNode | None) = None
) -> None {
    """Propagate a raise the callee left pending, unless the call is a tail call.

    A `return tail` call returns the callee's result straight to this
    function's caller, which checks the pending error itself; the frame has no
    handler and nothing to clean up (the tail lowering refuses otherwise), so
    propagating here would return the same fallback one frame earlier.
    """;
    if callee is not None and (site is None or site is not self._tail_call_site) {
        self._emit_pending_error_check();
    }
}

impl NaIRGenPass._emit_pending_error_check -> None {
    if not self._slot_lowering_active() {
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
    payload: ir.Value, type_id: int, msg: ir.Value, drop: (ir.Value | None) = None
) -> None {
    i32 = ir.IntType(32);
    (tglob, oglob, mglob) = self._nogc_err_slot();

    self.builder.store(ir.Constant(i32, type_id + 1), tglob);
    self.builder.store(payload, oglob);
    self.builder.store(msg, mglob);
    if self._nogc_headerless() {
        i8p = ir.IntType(8).as_pointer();
        self.builder.store(drop or ir.Constant(i8p, None), self._nogc_err_drop_slot());
    }
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
    exc_drop: (tuple[ir.Value, ir.Value] | None) = None;
    if self._nogc_headerless() {
        exc_drop = (
            self._entry_alloca(i8p, "try.exc.drop"),
            self._entry_alloca(i8p, "try.exc.obj")
        );
        self.builder.store(ir.Constant(i8p, None), exc_drop[0]);
    }
    frame = NativeFinalizer(
        body=nd.finally_body,
        function=func,
        loop_depth=len(self.loop_stack),
        handler_depth=len(self._slot_try_stack),
        exc_drop=exc_drop
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
        caught = self._exc_bound_struct(ex);
        targets = self._exception_handler_targets(ex);
        handler_bb = func.append_basic_block(f"except.handler.{i}");
        next_bb = func.append_basic_block(f"except.dispatch.{i + 1}");
        if targets is None {
            self.builder.branch(handler_bb);
        } else {
            self._emit_exception_match(
                err_type,
                self.builder.load(oglob, name="err.obj"),
                self.builder.load(mglob, name="err.msg"),
                targets,
                1,
                handler_bb,
                next_bb
            );
        }
        self.builder.position_at_end(handler_bb);
        caught_values = (
            self.builder.load(tglob),
            self.builder.load(oglob),
            self.builder.load(mglob)
        );
        self._caught_error_stack.append((func, caught_values));
        self.builder.store(ir.Constant(i32, 0), tglob);
        handler_drops = False;
        if exc_drop is not None {
            drop_field = self._nogc_err_drop_slot();
            taken = self.builder.load(drop_field, name="exc.drop.taken");
            self.builder.store(ir.Constant(i8p, None), drop_field);
            handed_back: ir.Value = ir.Constant(i8p, None);
            if except_node.name is None or not self._exc_binding_escapes(except_node) {
                self.builder.store(taken, exc_drop[0]);
                self.builder.store(caught_values[1], exc_drop[1]);
                handed_back = taken;
                handler_drops = True;
            }
            self._slot_caught_drops[id(caught_values)] = (exc_drop[0], handed_back);
        }
        var_name = "";
        shadowed: (ir.Value | None) = None;
        was_borrowed = False;
        if except_node.name is not None {
            var_name = except_node.name.value
                if isinstance(except_node.name, uni.Name)
                else str(except_node.name);
            shadowed = self.local_vars.get(var_name);
            was_borrowed = var_name in self.borrowed_vars;
            if handler_drops {
                self.borrowed_vars.add(var_name);
            }
            if caught is not None {
                _exc_sp_ty = self.struct_types[caught].as_pointer();
                bound_val = self.builder.bitcast(
                    caught_values[1], _exc_sp_ty, name="exc.bound.typed"
                );
                alloca = self._entry_alloca(_exc_sp_ty, var_name);
            } else {
                bound_val = caught_values[2];
                alloca = self._entry_alloca(i8p, var_name);
            }
            self.builder.store(bound_val, alloca);
            self.local_vars[var_name] = alloca;
            self._exc_bindings.append(
                (func, var_name, alloca, bound_val, caught_values)
            );
        }
        if isinstance(except_node.body, (list, tuple)) {
            self._codegen_body(except_node.body);
        }
        if except_node.name is not None {
            self._exc_bindings.pop();
            if handler_drops {
                if not was_borrowed {
                    self.borrowed_vars.discard(var_name);
                }
                if shadowed is not None {
                    self.local_vars[var_name] = shadowed;
                } else {
                    self.local_vars.pop(var_name, None);
                }
            }
        }
        self._slot_caught_drops.pop(id(caught_values), None);
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
    pending_drop: (ir.Value | None) = None;
    if exc_drop is not None {
        self._emit_caught_drop(exc_drop[0], exc_drop[1]);
        pending_drop = self.builder.load(self._nogc_err_drop_slot(), name="err.drop");
    }
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
        if pending_drop is not None {
            self.builder.store(pending_drop, self._nogc_err_drop_slot());
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
            if frame.exc_drop is not None {
                self._emit_caught_drop(frame.exc_drop[0], frame.exc_drop[1]);
            }
            if frame.context_exit is not None {
                (cm, exit_fn) = frame.context_exit;
                self._emit_context_exit(cm, exit_fn);
            }
            if frame.gen_exit is not None {
                (gen_owner, gen_out) = frame.gen_exit;
                self._emit_gen_context_exit(gen_owner, gen_out);
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
    self._mark_setjmp_function(self.builder.function);
    state = self._stack_entry_alloca(self._get_exception_state_type(), "exc.state");
    depth = self._stack_entry_alloca(ir.IntType(64), "rgn.depth.slot");
    self.builder.call(self._exc_push_fn, [state]);
    self.builder.store(self._region_depth(), depth);
    env = self.builder.gep(state, [ir.Constant(i32, 0), ir.Constant(i32, 0)]);
    result = self.builder.call(self._exc_setjmp_fn(), [self.builder.bitcast(env, i8p)]);
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
    self._mark_setjmp_function(func);
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
    _gc = self._gen_ctx;
    _in_gen = _gc is not None and func is _gc.resume_fn;
    if _in_gen {
        self._gen_try_stack.append(
            NativeGeneratorHandler(state=state, dispatch=dispatch, depth=depth)
        );
    }
    self._finally_stack.append(frame);
    try {
        self._codegen_try_unwind(nd, emit_finally=False);
    } finally {
        self._finally_stack.pop();
        if _in_gen {
            self._gen_try_stack.pop();
        }
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
    _spill: list[ir.Value] = [];
    if _in_gen {
        for (_si, _sv) in enumerate(values) {
            _slot = self._entry_alloca(_sv.type, f"finally.exc.{_si}");
            self.builder.store(_sv, _slot);
            _spill.append(_slot);
        }
    }
    self._caught_error_stack.append((func, values));
    if nd.finally_body is not None
        and isinstance(nd.finally_body.body, (list, tuple)) {
        self._codegen_body(nd.finally_body.body);
    }
    self._caught_error_stack.pop();
    if not self.builder.block.is_terminated {
        if _spill {
            values = (
                self.builder.load(_spill[0], name="finally.exc.type"),
                self.builder.load(_spill[1], name="finally.exc.obj"),
                self.builder.load(_spill[2], name="finally.exc.msg")
            );
        }
        self.builder.call(self._exc_raise_fn, [values[1], values[0], values[2]]);
        self.builder.unreachable();
    }
    self.builder.position_at_end(merge);
}

impl NaIRGenPass._mark_setjmp_function(func: ir.Function) -> None {
    """Record a function that arms a setjmp frame.

    It stays optimizable. What C requires of such a function -- a local
    written between the arming and the longjmp that returns to it must be
    volatile, or the second return may see a stale register copy -- is
    applied before the module is handed on (_volatilize_setjmp_locals). The
    setjmp call keeps returns_twice, so LLVM neither inlines the function
    nor reuses its stack slots across the arming.
    """;
    for known in self._setjmp_functions {
        if known is func {
            return;
        }
    }
    self._setjmp_functions.append(func);
}

impl NaIRGenPass._setjmp_local_base(value: ir.Value) -> (ir.Value | None) {
    """The local (alloca) a pointer addresses through GEPs and casts, or None.""";
    current = value;
    while True {
        if isinstance(current, ir.AllocaInstr) {
            return current;
        }
        if isinstance(current, ir.GEPInstr) or isinstance(current, ir.CastInstr) {
            current = current.operands[0];
            continue;
        }
        return None;
    }
}

impl NaIRGenPass._block_successors(block: ir.Block) -> list[ir.Block] {
    term: any = block.terminator;
    if term is None {
        return [];
    }
    found: list[ir.Block] = [
        op
        for op in term.operands
        if isinstance(op, ir.Block)
    ];
    if isinstance(term, ir.SwitchInstr) {
        found.append(term.default_bb);
        for arm in term.cases {
            found.append(arm[1]);
        }
    }
    return found;
}

impl NaIRGenPass._volatilize_setjmp_locals -> None {
    """Make volatile exactly the locals a setjmp function writes after an arming.

    Every instruction that can run after an arming -- the rest of the arming
    block and every block reachable from it -- is scanned for stores into a
    local; each such local's loads and stores anywhere in the function become
    volatile, so the value a handler, finally clause or re-armed generator
    frame reads after the longjmp is the one last written. Locals only
    written before every arming keep their register and SSA form, and the
    rest of the function is optimized as usual.
    """;
    if not self._setjmp_functions {
        return;
    }
    setjmp_name = self._exc_jmp_symbols()[0];
    for func in self._setjmp_functions {
        after: list[any] = [];
        pending: list[ir.Block] = [];
        for block in func.blocks {
            armed = False;
            for inst in block.instructions {
                if armed {
                    after.append(inst);
                } elif isinstance(inst, ir.CallInstr)
                    and getattr(inst.callee, "name", "") == setjmp_name {
                    armed = True;
                }
            }
            if armed {
                pending.extend(self._block_successors(block));
            }
        }
        seen: set[int] = set();
        while pending {
            block = pending.pop();
            if id(block) in seen {
                continue;
            }
            seen.add(id(block));
            after.extend(block.instructions);
            pending.extend(self._block_successors(block));
        }
        written: set[int] = set();
        for inst in after {
            if isinstance(inst, ir.StoreInstr) {
                base = self._setjmp_local_base(inst.operands[1]);
                if base is not None {
                    written.add(id(base));
                }
            }
        }
        if not written {
            continue;
        }
        for block in func.blocks {
            for inst_value in block.instructions {
                inst: any = inst_value;
                target: (ir.Value | None) = None;
                if isinstance(inst, ir.LoadInstr) {
                    target = inst.operands[0];
                } elif isinstance(inst, ir.StoreInstr) {
                    target = inst.operands[1];
                }
                if target is not None {
                    base = self._setjmp_local_base(target);
                    if base is not None and id(base) in written {
                        setattr(inst, "volatile", True);
                    }
                }
            }
        }
    }
    self._setjmp_functions = [];
}
