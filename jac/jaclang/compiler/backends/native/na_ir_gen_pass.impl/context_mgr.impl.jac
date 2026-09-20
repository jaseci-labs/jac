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
    self.builder.branch(body_bb);
    frame = NativeFinalizer(
        body=None,
        function=func,
        loop_depth=len(self.loop_stack),
        handler_depth=len(self._slot_try_stack),
        context_exit=(owner, exit_fn)
    );
    self.builder.position_at_end(body_bb);
    self._finally_stack.append(frame);
    self._slot_try_stack.append(NativeErrorHandler(dispatch=error_bb));
    try {
        self._codegen_with_recursive(exprs, idx + 1, body);
    } finally {
        self._finally_stack.pop();
        self._slot_try_stack.pop();
    }
    if not self.builder.block.is_terminated {
        self._emit_context_exit(self.builder.load(owner), exit_fn);
        self.builder.branch(merge_bb);
    }
    self.builder.position_at_end(error_bb);
    (kind, error, message) = self._error_slots(self.builder);
    values = self._spill_error(
        (self.builder.load(kind), self.builder.load(error), self.builder.load(message))
    );
    self._clear_pending_error(self.builder, release=False);
    self._caught_error_stack.append((func, values));
    suppressed = self._emit_context_exit(self.builder.load(owner), exit_fn);
    self._caught_error_stack.pop();
    propagate = func.append_basic_block(name=f"with.propagate.{idx}");
    self.builder.cbranch(
        self._coerce_type(suppressed, ir.IntType(1)), merge_bb, propagate
    );
    self.builder.position_at_end(propagate);
    self._restore_error(values);
    self._emit_err_propagate(loc="with.propagate");
    self.builder.position_at_end(merge_bb);
}

impl NaIRGenPass._emit_context_exit(cm: ir.Value, exit_fn: ir.Function) -> ir.Value {
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
