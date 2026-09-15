impl NaIRGenPass._record_tail_requirement(
    func: ir.Function, decl: uni.Ability
) -> None {
    for stmt in ModuleFacts.unwrap_body(decl) or [] {
        for call in stmt.get_all_sub_nodes(typ=uni.FuncCall) {
            if isinstance(call.target, uni.Name)
                and call.target.sym_name == "__musttail" {
                self._tail_required_functions[func] = call;
                return;
            }
        }
    }
}

impl NaIRGenPass._tail_transfer_requested(nd: uni.FuncCall) -> bool {
    wrapper = nd.parent;
    return isinstance(wrapper, uni.FuncCall)
        and isinstance(wrapper.target, uni.Name)
        and wrapper.target.sym_name == "__musttail"
        and len(wrapper.params or []) == 1
        and isinstance(wrapper.parent, uni.ReturnStmt)
        and wrapper.parent.expr is wrapper;
}

impl NaIRGenPass._tail_slot_was_cleared(slot: ir.Value) -> bool {
    for instruction in reversed(self.builder.block.instructions) {
        if instruction.opname == "store" and instruction.operands[1] is slot {
            stored = instruction.operands[0];
            return isinstance(stored, ir.Constant)
                and str(stored) == str(self._zero_const(stored.type));
        }
    }
    return False;
}

impl NaIRGenPass._emit_intrinsic_musttail(
    nd: uni.FuncCall, intr: IntrinsicEntry, args: list
) -> (ir.Value | None) {
    call = args[0];
    import from jaclang.compiler.foreign_refs { is_foreign_ability }
    reason = "";
    parent = nd.parent;
    while parent is not None
        and not isinstance(
            parent, (uni.Ability, uni.ImplDef, uni.LambdaExpr, uni.Test)
        ) {
        if isinstance(parent, uni.WithStmt) {
            self._emit_intrinsic_misuse(
                nd, intr, "an active context manager must exit after the call"
            );
            return None;
        }
        parent = parent.parent;
    }
    if not isinstance(call, uni.FuncCall) or not self._tail_transfer_requested(call) {
        reason = "use return __musttail(callee(arguments));";
    } elif str(self.llvm_module.triple).split("-")[0]
        not in ("x86_64", "aarch64", "arm64") {
        reason = "checked tail transfers are supported on x86-64 and ARM64 targets";
    } elif not self._slot_lowering_active() {
        reason = "requires native slot exception lowering (--memory nogc)";
    } elif self._gen_ctx is not None {
        reason = "a generator cannot transfer its native frame";
    } elif self._slot_try_stack or self._finally_stack or self._caught_error_stack {
        reason = "an active exception handler or finalizer must run after the call";
    } elif self.region_open_stack or self.region_handle_vars {
        reason = "an active region must be released after the call";
    } elif self.closure_cell_handles {
        reason = "closure cells must be released after the call";
    } elif not isinstance(call.target, (uni.Name, uni.AtomTrailer)) {
        reason = "requires a named native function or a function pointer field";
    } elif is_foreign_ability(self._callee_ability_of(call)) {
        reason = "a foreign call has no checked native exception and lifetime contract";
    }
    if reason {
        self._emit_intrinsic_misuse(nd, intr, reason);
        return None;
    }
    assert isinstance(call, uni.FuncCall);
    func = self.builder.function;
    self._tail_required_functions[func] = nd;
    rt = func.function_type.return_type;
    if not isinstance(rt, (ir.IntType, ir.FloatType, ir.DoubleType, ir.VoidType))
        and self._foreign_resource_kind(rt) is None {
        self._emit_intrinsic_misuse(
            nd, intr, "requires a scalar, void, or foreign resource return ABI"
        );
        return None;
    }

    value = self._codegen_expr(call);
    if not isinstance(value, ir.CallInstr) {
        self._emit_intrinsic_misuse(
            nd, intr, "the operand must lower to one native call"
        );
        return None;
    }
    target = value.callee;
    signature = target.function_type;
    if signature != func.function_type or signature.var_arg {
        self._emit_intrinsic_misuse(
            nd,
            intr,
            "caller and callee must have identical fixed argument and return layouts"
        );
        return None;
    }
    if (value.cconv or "") != (func.calling_convention or "") {
        self._emit_intrinsic_misuse(
            nd, intr, "caller and callee calling conventions differ"
        );
        return None;
    }

    allowed = {"noalias", "readonly"};
    abi_args = list(func.args);
    if isinstance(target, ir.Function) {
        abi_args.extend(target.args);
    }
    if any(set(arg.attributes) - allowed for arg in abi_args)
        or func.return_value.attributes
        or (isinstance(target, ir.Function) and target.return_value.attributes)
        or value.arg_attributes {
        self._emit_intrinsic_misuse(
            nd, intr, "ABI attributes cannot be forwarded by this tail transfer"
        );
        return None;
    }

    self._emit_scope_cleanup(loc="musttail");
    if self.builder.block is not value.parent
        or not self.builder.block.instructions
        or self.builder.block.instructions[-1] is not value {
        self._emit_intrinsic_misuse(
            nd, intr, "pending cleanup or result conversion prevents a tail transfer"
        );
        return None;
    }
    value.tail = "musttail";
    self._tail_transfers[func] = nd;
    if isinstance(rt, ir.VoidType) {
        self.builder.ret_void();
    } else {
        self.builder.ret(value);
    }
    return value;
}

impl NaIRGenPass._validate_tail_frame(func: ir.Function) -> None {
    origin = self._tail_transfers.pop(func, None);
    if origin is None {
        return;
    }

    for block in func.blocks {
        for instruction in block.instructions {
            operands = list(instruction.operands);
            if isinstance(instruction, ir.PhiInstr) {
                operands.extend(value for (value, _) in instruction.incomings);
            }
            for (index, operand) in enumerate(operands) {
                if not isinstance(operand, ir.AllocaInstr) {
                    continue;
                }
                if instruction.opname == "load" and index == 0 {
                    continue;
                }
                if instruction.opname == "store" and index == 1 {
                    continue;
                }
                self.emit(
                    E5109,
                    node_override=origin,
                    name="__musttail",
                    reason="a native frame address escapes its local slot"
                );
                return;
            }
        }
    }
}
