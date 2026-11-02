impl MirLowering.exception_name(nd: uni.Expr) -> str {
    target = nd.target if isinstance(nd, uni.FuncCall) else nd;
    if isinstance(target, uni.Name) and JAC_TYPE_REGISTRY.is_exception(target.value) {
        return target.value;
    }
    raise MirRefused(
        mir_refusal(
            "exception",
            type(target).__name__,
            nd,
            "Native code raises and catches builtin exception types so far."
        )
    );
}

impl MirLowering.exception_matches(type_id: MirValue, clause: uni.Expr) -> MirValue {
    b = self.builder();
    names = [
        self.exception_name(item) for item in clause.values if isinstance(item, uni.Expr)
    ]
        if isinstance(clause, uni.TupleVal)
        else [self.exception_name(clause)];
    verdict = b.const_bool(False);
    for name in names {
        for member in [name] + JAC_TYPE_REGISTRY.exception_descendants(name) {
            wanted = b.const_int(JAC_TYPE_REGISTRY.exception_type_id(member), type_id.type);
            verdict = b.binary("or", verdict, b.compare("eq", type_id, wanted));
        }
    }
    return verdict;
}

impl MirLowering.lower_try(nd: uni.TryStmt) {
    b = self.builder();
    fn = self.st().fn;
    if nd.finally_body is not None {
        for found in nd.finally_body.body {
            if isinstance(found, (uni.ReturnStmt, uni.CtrlStmt)) {
                raise MirRefused(mir_refusal("statement", "jump out of finally", found));
            }
        }
    }
    frame = fn.new_value(mir_c_ptr(mir_int(8, False)), "exc.frame");
    fn.blocks[0].instrs.insert(0, MirInstr(op=MirOp.EXC_FRAME, result=frame));
    self.runtime("__jac_rt_exc_push", [frame]);
    buffer = self.runtime("__jac_rt_exc_jmp_buf", [frame]);
    if buffer is None {
        raise MirRefused(mir_refusal("statement", "try", nd));
    }
    armed = self.emit_value(MirOp.SETJMP, mir_int(32, True, True), [buffer]);
    body = fn.new_block("try.body");
    dispatch = fn.new_block("try.caught");
    after = fn.new_block("try.done");
    b.cond_branch(b.compare("eq", armed, b.const_int(0, armed.type)), body, dispatch);
    b.position(body);
    self.lower_body(nd.body);
    if not self.builder().block.terminated() {
        self.runtime("__jac_rt_exc_pop", [frame]);
        self.lower_else(nd.else_body, after);
    }
    b.position(dispatch);
    self.runtime("__jac_rt_exc_pop", [frame]);
    address = self.address_of(frame);
    type_id = self.emit_value(
        MirOp.MEM_LOAD,
        mir_int(32, True, True),
        [b.binary("add", address, b.const_int(EXC_TYPE_OFFSET, mir_int()))]
    );
    message = self.emit_value(
        MirOp.PTR_CAST,
        mir_c_ptr(mir_int(8, False)),
        [self.emit_value(
            MirOp.MEM_LOAD,
            mir_int(),
            [b.binary("add", address, b.const_int(EXC_MESSAGE_OFFSET, mir_int()))]
        )]
    );
    origin = self.emit_value(
        MirOp.PTR_CAST,
        mir_c_ptr(mir_int(8, False)),
        [self.emit_value(MirOp.MEM_LOAD, mir_int(), [address])]
    );
    for clause in nd.excepts {
        handler = fn.new_block("except.body");
        following = fn.new_block("except.next");
        b.cond_branch(self.exception_matches(type_id, clause.ex_type), handler, following);
        b.position(handler);
        if clause.name is not None {
            if clause.name.sym is None {
                raise MirRefused(mir_refusal("exception binding", clause.name.value, clause));
            }
            text = self.runtime("__jac_rt_str_new", [message, self.runtime("__jac_rt_str_size", [b.ref_cast(message, mir_str_ref(), False)]) or b.const_int(0, mir_int())]);
            if text is not None {
                slot = self.local_slot(clause.name.sym, clause.name);
                if slot.type.kind != MirKind.STR {
                    raise MirRefused(
                        mir_refusal(
                            "exception binding",
                            slot.type.render(),
                            clause,
                            "A caught exception binds as its message string so far."
                        )
                    );
                }
                size = self.runtime("__jac_rt_str_size", [text]);
                if size is not None {
                    b.store(slot, b.str_make(text, text, size));
                }
            }
        }
        self.st().caught.append((origin, type_id, message));
        self.lower_body(clause.body);
        self.st().caught.pop();
        if not self.builder().block.terminated() {
            self.builder().branch(after);
        }
        b.position(following);
    }
    if nd.finally_body is not None {
        self.lower_body(nd.finally_body.body);
    }
    self.runtime("__jac_rt_raise", [origin, type_id, message]);
    b.unreachable();
    b.position(after);
    if nd.finally_body is not None {
        self.lower_body(nd.finally_body.body);
    }
}

impl MirLowering.lower_raise(nd: uni.RaiseStmt) {
    b = self.builder();
    if nd.cause is None {
        if not self.st().caught {
            raise MirRefused(mir_refusal("statement", "bare raise outside except", nd));
        }
        (origin, type_id, message) = self.st().caught[-1];
        self.runtime("__jac_rt_raise", [origin, type_id, message]);
        b.unreachable();
        return;
    }
    name = self.exception_name(nd.cause);
    args = self.call_args(nd.cause) if isinstance(nd.cause, uni.FuncCall) else [];
    if not args {
        b.raise_builtin(name, "");
        return;
    }
    if len(args) == 1 and isinstance(args[0], uni.String) and isinstance(args[0].lit_value, str) {
        b.raise_builtin(name, args[0].lit_value);
        return;
    }
    message = self.lower_expr(args[0]);
    if message.type.kind == MirKind.C_PTR {
        self.runtime(
            "__jac_rt_raise_builtin",
            [b.const_int(JAC_TYPE_REGISTRY.exception_type_id(name), mir_int(32, True, True)), message]
        );
        b.unreachable();
        return;
    }
    text = self.to_str(message, args[0]);
    held = self.runtime(
        "__jac_rt_str_ref", [b.str_part(text, "root"), b.str_part(text, "data"), b.str_part(text, "len")]
    );
    if held is None {
        raise MirRefused(mir_refusal("statement", "raise", nd));
    }
    data = self.emit_value(MirOp.PTR_CAST, mir_c_ptr(mir_int(8, False)), [held]);
    self.runtime(
        "__jac_rt_raise",
        [data, b.const_int(JAC_TYPE_REGISTRY.exception_type_id(name), mir_int(32, True, True)), data]
    );
    b.unreachable();
}
