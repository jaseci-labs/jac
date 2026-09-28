import from jaclang.compiler.expr_keys { type_tag_borrows }

impl NaIRGenPass._codegen_with(nd: uni.WithStmt) -> None {
    if not nd.exprs {
        if isinstance(nd.body, (list, tuple)) {
            self._codegen_body(nd.body);
        }
        return;
    }

    self._codegen_with_recursive(nd.exprs, 0, nd.body);
}

impl NaIRGenPass._codegen_with_recursive(
    exprs: Sequence[uni.ExprAsItem], idx: int, body: Sequence[uni.CodeBlockStmt]
) -> None {
    if idx >= len(exprs) {
        if isinstance(body, (list, tuple)) {
            self._codegen_body(body);
        }
        return;
    }
    expr_item = exprs[idx];
    i32 = ir.IntType(32);
    func = self.builder.function;

    _cm_callee = self._ctxmgr_callee(expr_item.expr);
    if _cm_callee is not None {
        self._codegen_with_ctxmgr(exprs, idx, body, _cm_callee);
        return;
    }

    cm_val = self._codegen_expr(expr_item.expr);
    if cm_val is None {
        self._codegen_with_recursive(exprs, idx + 1, body);
        return;
    }

    type_name: (str | None) = None;

    if isinstance(cm_val.type, ir.PointerType) {
        for (sname, stype) in self.struct_types.items() {
            if cm_val.type == stype.as_pointer() {
                type_name = sname;
                break;
            }
        }
    }
    if type_name is None {
        type_name = self._infer_type_name(cm_val);
    }
    if type_name is None {
        self._codegen_with_recursive(exprs, idx + 1, body);
        return;
    }

    enter_fn = self._resolve_method(type_name, "__enter__");
    exit_fn = self._resolve_method(type_name, "__exit__");
    if enter_fn is None or exit_fn is None {
        self._codegen_with_recursive(exprs, idx + 1, body);
        return;
    }

    owner_name = f"__with_owner.{len(self.local_vars)}";
    owner = self._entry_alloca(cm_val.type, owner_name);
    self._emit_slot_rebind(owner, cm_val, owned=self._is_owned(cm_val), op="ctx_owner");
    self.builder.store(cm_val, owner);
    self.local_vars[owner_name] = owner;
    if self._nogc_headerless() and not self._is_owned(cm_val) {
        self.borrowed_vars.add(owner_name);
    }

    enter_args: list[ir.Value] = [cm_val];

    if len(enter_fn.args) > 0 {
        enter_args[0] = self._coerce_type(cm_val, enter_fn.args[0].type);
    }
    enter_owned = type_name not in ("File", "BinaryFile");
    linked = self._linked_fn_decls.get(id(enter_fn));
    if self._nogc_headerless() and linked is not None {
        signature = linked[1].signature;
        if isinstance(signature, uni.FuncSignature) {
            enter_owned = not type_tag_borrows(signature.return_type);
        }
    }
    enter_result = self.builder.call(enter_fn, enter_args, name="cm.enter");
    if enter_owned {
        self._mark_reference_owned(enter_result);
    }
    self._emit_pending_error_check();
    alias_name = self._get_name(expr_item.alias)
        if expr_item.alias is not None
        else None;
    if alias_name is not None {
        alloca = self._entry_alloca(enter_result.type, alias_name);
        if self._is_reference_type(enter_result.type) {
            self._emit_slot_rebind(
                alloca, enter_result, owned=enter_owned, op="ctx_enter"
            );
        }
        self.builder.store(enter_result, alloca);
        self.local_vars[alias_name] = alloca;
        if self._nogc_headerless() and not enter_owned {
            self.borrowed_vars.add(alias_name);
        }
    } else {
        self._release_owned_args([enter_result], op="ctx_enter");
    }

    body_bb = func.append_basic_block(name=f"with.body.{idx}");
    error_bb = func.append_basic_block(name=f"with.error.{idx}");
    merge_bb = func.append_basic_block(name=f"with.merge.{idx}");
    slot_mode = self._slot_lowering_active();
    state: ir.Value | None = None;
    depth: ir.Value | None = None;
    if slot_mode {
        self.builder.branch(body_bb);
    } else {
        if self._exc_raise_fn is None {
            self._declare_exception_runtime();
        }
        func.attributes.add("optnone");
        func.attributes.add("noinline");
        (state, depth) = self._push_exception_handler(error_bb, body_bb);
    }
    frame = NativeFinalizer(
        body=None,
        function=func,
        loop_depth=len(self.loop_stack),
        handler_depth=len(self._slot_try_stack),
        pop_handler=not slot_mode,
        context_exit=(owner, exit_fn)
    );
    self.builder.position_at_end(body_bb);
    self._finally_stack.append(frame);
    _gc = self._gen_ctx;
    _in_gen = not slot_mode and _gc is not None and func is _gc.resume_fn;
    if slot_mode {
        self._slot_try_stack.append(NativeErrorHandler(dispatch=error_bb));
    } elif _in_gen {
        assert state is not None and depth is not None;
        self._gen_try_stack.append(
            NativeGeneratorHandler(state=state, dispatch=error_bb, depth=depth)
        );
    }
    try {
        self._codegen_with_recursive(exprs, idx + 1, body);
    } finally {
        self._finally_stack.pop();
        if slot_mode {
            self._slot_try_stack.pop();
        } elif _in_gen {
            self._gen_try_stack.pop();
        }
    }
    if not self.builder.block.is_terminated {
        if not slot_mode {
            self.builder.call(self._exc_pop_fn, []);
        }
        self._emit_context_exit(owner, exit_fn);
        self.builder.branch(merge_bb);
    }
    self.builder.position_at_end(error_bb);
    values: tuple[ir.Value, ir.Value, ir.Value];
    if slot_mode {
        (tg, og, mg) = self._nogc_err_slot();
        values = (self.builder.load(tg), self.builder.load(og), self.builder.load(mg));
        self.builder.store(ir.Constant(i32, 0), tg);
    } else {
        assert state is not None and depth is not None;
        self._region_unwind(self.builder.load(depth));
        values = self._exception_values(state);
        self.builder.call(self._exc_pop_fn, []);
    }
    self._caught_error_stack.append((func, values));
    suppressed = self._emit_context_exit(owner, exit_fn);
    self._caught_error_stack.pop();
    propagate = func.append_basic_block(name=f"with.propagate.{idx}");
    self.builder.cbranch(
        self._coerce_type(suppressed, ir.IntType(1)), merge_bb, propagate
    );
    self.builder.position_at_end(propagate);
    if slot_mode {
        for (slot, value) in zip(self._nogc_err_slot(), values) {
            self.builder.store(value, slot);
        }
        self._emit_err_propagate(loc="with.propagate");
    } else {
        self.builder.call(self._exc_raise_fn, [values[1], values[0], values[2]]);
        self.builder.unreachable();
    }
    self.builder.position_at_end(merge_bb);
}

impl NaIRGenPass._emit_context_exit(cm: ir.Value, exit_fn: ir.Function) -> ir.Value {
    """Call `__exit__` on the manager a `with` holds in its owner slot.

    The manager is reloaded from the slot rather than reused as the value the
    entry computed: inside a generator the body can suspend, and a resumed
    frame reaches the exit without passing through the entry that defined it.
    """;
    if isinstance(cm.type, ir.PointerType)
        and isinstance(cm.type.pointee, ir.PointerType) {
        cm = self.builder.load(cm, name="cm.owner");
    }
    null_ptr = ir.Constant(ir.IntType(8).as_pointer(), None);
    args: list[ir.Value] = [self._coerce_type(cm, exit_fn.args[0].type)];
    for i in range(1, len(exit_fn.args)) {
        args.append(self._coerce_type(null_ptr, exit_fn.args[i].type));
    }
    result = self.builder.call(exit_fn, args, name="cm.exit");
    self._emit_pending_error_check();
    if isinstance(result.type, ir.VoidType) {
        return ir.Constant(ir.IntType(1), 0);
    }
    truthy = self._to_bool(result);
    self._release_owned_args([self._mark_reference_owned(result)], op="ctx_exit");
    return truthy;
}

impl NaIRGenPass._ctxmgr_callee(expr: (uni.UniNode | None)) -> (uni.Ability | None) {
    """The `@contextmanager` ability a `with` item calls, if it calls one.""";
    if not isinstance(expr, uni.FuncCall) {
        return None;
    }
    import from jaclang.compiler.erased_imports { contextmanager_ability }
    _callee = self._callee_ability_of(expr);
    return _callee if contextmanager_ability(_callee) else None;
}

impl NaIRGenPass._codegen_with_ctxmgr(
    exprs: Sequence[uni.ExprAsItem],
    idx: int,
    body: Sequence[uni.CodeBlockStmt],
    callee: uni.Ability
) -> None {
    """Lower `with f(...) as x` where `f` is a `@contextlib.contextmanager`.

    The decorated function is compiled as the plain generator it is, so the
    manager is its iterator and `contextlib`'s protocol is spelled here, in
    the caller: enter advances it to its first `yield` (binding the yielded
    value to `as`), a normal exit advances it once more expecting it to
    finish, and an exception from the body is thrown into it at the `yield`
    -- the frame's pending-exception record, raised on resume -- so its
    `finally` runs and its `except` may swallow the exception. A generator
    that finishes after the throw suppresses the exception; one that lets it
    (or another) escape propagates it; one that yields again is a
    `RuntimeError`, as are a generator that never yields and one that yields
    twice. Early exits from the body (`return`, `break`, `continue`) run the
    normal exit through the finalizer stack.
    """;
    expr_item = exprs[idx];
    call = expr_item.expr;
    func = self.builder.function;
    i1 = ir.IntType(1);
    i8p = ir.IntType(8).as_pointer();
    _name = callee.name_ref.sym_name if callee.name_ref else "contextmanager";
    if self._slot_lowering_active() {
        self.emit(
            E5092,
            node_override=call,
            kind="context manager",
            name=f"@contextmanager {_name}",
            help_text="A generator-based context manager needs the setjmp exception runtime to throw into its generator; the enforced no-GC error-slot lowering has none. Write the manager as an archetype with __enter__/__exit__ instead."
        );
        return;
    }
    elem_type = self._generator_elem_type(callee);
    if elem_type is None {
        self.emit(
            E5092,
            node_override=call,
            kind="context manager",
            name=f"@contextmanager {_name}",
            help_text="A native @contextmanager generator must declare a generator-family return type with a lowerable element, e.g. `-> Iterator[None]`."
        );
        return;
    }
    _prev_ok = self._ctxmgr_call_ok;
    self._ctxmgr_call_ok = id(call);
    try {
        it_val = self._codegen_expr(call);
    } finally {
        self._ctxmgr_call_ok = _prev_ok;
    }
    if it_val is None {
        return;
    }
    if self._exc_raise_fn is None {
        self._declare_exception_runtime();
    }
    _out_is_desc = self._str_desc_ty is not None and elem_type == self._str_desc_ty;
    out_type = i8p if _out_is_desc else elem_type;

    owner_name = f"__with_gen.{len(self.local_vars)}";
    owner = self._entry_alloca(it_val.type, owner_name);
    self._emit_slot_rebind(owner, it_val, owned=self._is_owned(it_val), op="ctx_owner");
    self.builder.store(it_val, owner);
    self.local_vars[owner_name] = owner;

    out_slot = self._entry_alloca(out_type, f"{owner_name}.out");
    got = self._emit_iter_advance(
        self.builder, it_val, self.builder.bitcast(out_slot, i8p, name="cm.gen.out")
    );
    self._emit_runtime_raise(
        self.builder.icmp_unsigned("==", got, ir.Constant(i1, 0), name="cm.gen.none"),
        "RuntimeError",
        "generator didn't yield"
    );
    alias_name = self._get_name(expr_item.alias)
        if expr_item.alias is not None
        else None;
    if alias_name is not None {
        entered = self.builder.load(out_slot, name="cm.gen.value");
        if _out_is_desc {
            entered = self._coerce_type(entered, elem_type);
        }
        alloca = self._entry_alloca(entered.type, alias_name);
        if self._is_reference_type(entered.type) {
            self._emit_slot_rebind(alloca, entered, owned=False, op="ctx_enter");
        }
        self.builder.store(entered, alloca);
        self.local_vars[alias_name] = alloca;
    }

    body_bb = func.append_basic_block(name=f"with.gen.body.{idx}");
    error_bb = func.append_basic_block(name=f"with.gen.error.{idx}");
    merge_bb = func.append_basic_block(name=f"with.gen.merge.{idx}");
    func.attributes.add("optnone");
    func.attributes.add("noinline");
    (state, depth) = self._push_exception_handler(error_bb, body_bb);
    frame = NativeFinalizer(
        body=None,
        function=func,
        loop_depth=len(self.loop_stack),
        handler_depth=len(self._slot_try_stack),
        pop_handler=True,
        gen_exit=(owner, out_type)
    );
    self.builder.position_at_end(body_bb);
    self._finally_stack.append(frame);
    _gc = self._gen_ctx;
    _in_gen = _gc is not None and func is _gc.resume_fn;
    if _in_gen {
        self._gen_try_stack.append(
            NativeGeneratorHandler(state=state, dispatch=error_bb, depth=depth)
        );
    }
    try {
        self._codegen_with_recursive(exprs, idx + 1, body);
    } finally {
        self._finally_stack.pop();
        if _in_gen {
            self._gen_try_stack.pop();
        }
    }
    if not self.builder.block.is_terminated {
        self.builder.call(self._exc_pop_fn, []);
        self._emit_gen_context_exit(owner, out_type);
        self.builder.branch(merge_bb);
    }

    self.builder.position_at_end(error_bb);
    self._region_unwind(self.builder.load(depth));
    values = self._exception_values(state);
    self.builder.call(self._exc_pop_fn, []);
    again = self._emit_gen_throw(owner, out_type, values);
    self._emit_runtime_raise(
        again, "RuntimeError", "generator didn't stop after throw()"
    );
    self.builder.branch(merge_bb);
    self.builder.position_at_end(merge_bb);
}

impl NaIRGenPass._emit_gen_context_exit(owner: ir.Value, out_type: ir.Type) -> None {
    """Finish a generator-based manager after its body completed normally.""";
    i8p = ir.IntType(8).as_pointer();
    it_val = self.builder.load(owner, name="cm.gen.it");
    scratch = self._stack_entry_alloca(out_type, "cm.gen.exit.out");
    got = self._emit_iter_advance(
        self.builder, it_val, self.builder.bitcast(scratch, i8p, name="cm.gen.exit.i8")
    );
    self._emit_runtime_raise(got, "RuntimeError", "generator didn't stop");
}

impl NaIRGenPass._emit_gen_throw(
    owner: ir.Value, out_type: ir.Type, values: tuple[ir.Value, ir.Value, ir.Value]
) -> ir.Value {
    """Throw `values` (type id, object, message) into a suspended generator.

    Fills the frame's pending-exception record and resumes it; the resume
    point raises it inside the generator. Answers whether the generator
    yielded again. An exception the generator does not handle -- the thrown
    one or a new one -- leaves through the resume call to the enclosing
    handler, which is the propagation `contextlib` performs.
    """;
    b = self.builder;
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    self._ensure_iter_types();
    it_val = b.load(owner, name="cm.gen.throw.it");
    jptr = b.bitcast(
        it_val, self.struct_types["JacIter"].as_pointer(), name="cm.gen.ji"
    );
    frame_i8 = b.load(
        b.gep(jptr, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cm.gen.st.slot"),
        name="cm.gen.frame"
    );
    def _put(off: int, value: ir.Value, label: str) {
        b.store(
            value,
            b.bitcast(
                b.gep(frame_i8, [ir.Constant(i64, off)], name=f"cm.gen.{label}.raw"),
                value.type.as_pointer(),
                name=f"cm.gen.{label}"
            )
        );
    }
    (exc_type, exc_obj, exc_msg) = values;
    _put(GEN_PENDING_TYPE_OFF, b.sext(exc_type, i64, name="cm.gen.type64"), "type");
    _put(
        GEN_PENDING_OBJ_OFF,
        b.bitcast(exc_obj, i8p) if exc_obj.type != i8p else exc_obj,
        "obj"
    );
    _put(
        GEN_PENDING_MSG_OFF,
        b.bitcast(exc_msg, i8p) if exc_msg.type != i8p else exc_msg,
        "msg"
    );
    _put(GEN_PENDING_FLAG_OFF, ir.Constant(i64, 1), "flag");
    scratch = self._stack_entry_alloca(out_type, "cm.gen.throw.out");
    return self._emit_iter_advance(
        b, it_val, b.bitcast(scratch, i8p, name="cm.gen.throw.i8")
    );
}
