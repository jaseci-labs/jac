impl MirLowering.exception_name(nd: uni.Expr) -> str {
    return self.exception_target(nd)[0];
}

impl MirLowering.exception_target(nd: uni.Expr) -> tuple[str, (uni.Archetype | None)] {
    target = nd.target if isinstance(nd, uni.FuncCall) else nd;
    arch = self.target_archetype(target) if isinstance(target, uni.Expr) else None;
    if arch is not None and not stub_archetype(arch) and self.is_exception_arch(arch) {
        return (archetype_native_name(arch), arch);
    }
    if isinstance(target, uni.Name) and JAC_TYPE_REGISTRY.is_exception(target.value) {
        return (target.value, None);
    }
    raise MirRefused(
        mir_refusal(
            "exception",
            type(target).__name__,
            nd,
            "Native code raises and catches builtin exception types and archetypes that derive from them."
        )
    );
}

impl MirLowering.is_exception_arch(arch: uni.Archetype) -> bool {
    sym = arch.name.sym if arch.name is not None else None;
    made = self.prog.get_type_evaluator().get_type_of_symbol(sym)
        if sym is not None
        else None;
    if not isinstance(made, ClassType) or made._shared is None {
        return False;
    }
    for ancestor in made.shared.mro {
        if ancestor._shared is None {
            continue;
        }
        scope = ancestor.shared.symbol_table;
        if isinstance(scope, uni.Archetype) and not stub_archetype(scope) {
            continue;
        }
        if JAC_TYPE_REGISTRY.is_exception(ancestor.shared.class_name) {
            return True;
        }
    }
    return False;
}

impl MirLowering.exception_ancestors(arch: uni.Archetype) -> list[int] {
    sym = arch.name.sym if arch.name is not None else None;
    made = self.prog.get_type_evaluator().get_type_of_symbol(sym)
        if sym is not None
        else None;
    tid = JAC_TYPE_REGISTRY.exception_type_id(archetype_native_name(arch));
    found: list[int] = [];
    if not isinstance(made, ClassType) or made._shared is None {
        return found;
    }
    for ancestor in list(made.shared.mro)[1:] {
        if ancestor._shared is None {
            continue;
        }
        scope = ancestor.shared.symbol_table;
        name = "";
        if isinstance(scope, uni.Archetype) and not stub_archetype(scope) {
            name = archetype_native_name(scope);
        } elif JAC_TYPE_REGISTRY.is_exception(ancestor.shared.class_name) {
            name = ancestor.shared.class_name;
        }
        if not name or name in ("Exception", "BaseException") {
            continue;
        }
        wanted = JAC_TYPE_REGISTRY.exception_type_id(name);
        if wanted != tid and wanted not in found {
            found.append(wanted);
        }
    }
    return found;
}

impl MirLowering.exception_matches(type_id: MirValue, clause: uni.Expr) -> MirValue {
    b = self.builder();
    items = [
        item
        for item in clause.values
        if isinstance(item, uni.Expr)
    ]
        if isinstance(clause, uni.TupleVal)
        else [clause];
    verdict = b.const_bool(False);
    for item in items {
        (name, arch) = self.exception_target(item);
        if arch is None and name in ("Exception", "BaseException") {
            return b.const_bool(True);
        }
        if arch is None {
            for member in [name] + JAC_TYPE_REGISTRY.exception_descendants(name) {
                wanted = b.const_int(
                    JAC_TYPE_REGISTRY.exception_type_id(member), type_id.type
                );
                verdict = b.binary("or", verdict, b.compare("eq", type_id, wanted));
            }
        }
        lineage = self.runtime(
            "__jac_rt_exc_isa",
            [
                b.convert(type_id, mir_int()),
                b.const_int(JAC_TYPE_REGISTRY.exception_type_id(name), mir_int())
            ]
        );
        if lineage is not None {
            verdict = b.binary("or", verdict, lineage);
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
                raise MirRefused(
                    mir_refusal("statement", "jump out of finally", found)
                );
            }
        }
    }
    if nd.finally_body is not None {
        self.st().finals.append(
            (list(nd.finally_body.body), len(self.st().loops), len(self.st().tries))
        );
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
    self.st().tries.append((frame, dispatch, len(self.st().loops)));
    self.lower_body(nd.body);
    self.st().tries.pop();
    if not self.builder().block.terminated() {
        self.runtime("__jac_rt_exc_pop", [frame]);
        self.lower_else(nd.else_body, after);
    }
    b.position(dispatch);
    self.runtime("__jac_rt_exc_pop", [frame]);
    (origin, type_id, message) = self.caught_state(frame);
    guard: (MirValue | None) = None;
    if nd.finally_body is not None and nd.excepts {
        guard = fn.new_value(mir_c_ptr(mir_int(8, False)), "exc.guard");
        fn.blocks[0].instrs.insert(0, MirInstr(op=MirOp.EXC_FRAME, result=guard));
        self.runtime("__jac_rt_exc_push", [guard]);
        guard_armed = self.emit_value(
            MirOp.SETJMP,
            mir_int(32, True, True),
            [self.runtime_value("__jac_rt_exc_jmp_buf", [guard])]
        );
        handlers = fn.new_block("except.guarded");
        escaped = fn.new_block("except.escaped");
        b.cond_branch(
            b.compare("eq", guard_armed, b.const_int(0, guard_armed.type)),
            handlers,
            escaped
        );
        b.position(escaped);
        self.runtime("__jac_rt_exc_pop", [guard]);
        (g_origin, g_type, g_message) = self.caught_state(guard);
        self.st().finals.pop();
        self.lower_body(nd.finally_body.body);
        self.st().finals.append(
            (list(nd.finally_body.body), len(self.st().loops), len(self.st().tries))
        );
        if not self.builder().block.terminated() {
            self.runtime("__jac_rt_raise", [g_origin, g_type, g_message]);
            self.builder().unreachable();
        }
        b.position(handlers);
        self.st().tries.append((guard, escaped, len(self.st().loops)));
    }
    for clause in nd.excepts {
        handler = fn.new_block("except.body");
        following = fn.new_block("except.next");
        b.cond_branch(
            self.exception_matches(type_id, clause.ex_type), handler, following
        );
        b.position(handler);
        bound_sym = clause.name.sym if clause.name is not None else None;
        binds = bound_sym is None
            or any(
                name.sym is bound_sym for stmt in clause.body
                for name in self.names_within(stmt)
            );
        bound_arch: (uni.Archetype | None) = None;
        bound_name = clause.name;
        if binds and bound_name is not None and bound_name.sym is not None {
            bound_type = self.symbol_type(bound_name.sym, bound_name);
            if bound_type.kind == MirKind.OBJ {
                bound_arch = self.archetypes.get(bound_type.name);
            }
        }
        handler_arch = self.target_archetype(clause.ex_type)
            if isinstance(clause.ex_type, uni.Expr)
            else None;
        rebound_key = 0;
        rebound_prior: (MirValue | None) = None;
        if binds
            and bound_name is not None
            and bound_name.sym is not None
            and handler_arch is not None
            and bound_arch is not None
            and handler_arch is not bound_arch {
            rebound_key = id(bound_name.sym);
            rebound_prior = self.st().locals.get(rebound_key);
            self.st().locals[rebound_key] = self.temp_slot(
                self.object_type(handler_arch)
            );
            bound_arch = handler_arch;
        }
        if bound_arch is not None and bound_name is not None {
            slot = self.local_slot(bound_name.sym, bound_name);
            b.store(slot, b.ref_cast(origin, slot.type, True));
        } elif clause.name is not None and binds {
            if clause.name.sym is None {
                raise MirRefused(
                    mir_refusal("exception binding", clause.name.value, clause)
                );
            }
            text = self.runtime(
                "__jac_rt_str_new",
                [
                    message,
                    self.runtime(
                        "__jac_rt_str_size", [b.ref_cast(message, mir_str_ref(), False)]
                    )
                        or b.const_int(0, mir_int())
                ]
            );
            if text is not None {
                slot = self.local_slot(clause.name.sym, clause.name);
                if slot.type.kind not in (MirKind.STR, MirKind.ANY) {
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
                    b.store(
                        slot,
                        self.coerce(b.str_make(text, text, size), slot.type, clause)
                    );
                }
            }
        }
        self.st().caught.append((origin, type_id, message));
        bound_key = id(clause.name.sym)
            if clause.name is not None and clause.name.sym is not None
            else 0;
        if bound_key {
            self.st().bound_caught[bound_key] = (origin, type_id, message);
        }
        self.lower_body(clause.body);
        if bound_key {
            self.st().bound_caught.pop(bound_key, None);
        }
        if rebound_key {
            if rebound_prior is None {
                self.st().locals.pop(rebound_key, None);
            } else {
                self.st().locals[rebound_key] = rebound_prior;
            }
        }
        self.st().caught.pop();
        if not self.builder().block.terminated() {
            if guard is not None {
                self.runtime("__jac_rt_exc_pop", [guard]);
            }
            self.builder().branch(after);
        }
        b.position(following);
    }
    if guard is not None {
        self.st().tries.pop();
        self.runtime("__jac_rt_exc_pop", [guard]);
    }
    if nd.finally_body is not None {
        self.st().finals.pop();
        self.lower_body(nd.finally_body.body);
    }
    self.runtime("__jac_rt_raise", [origin, type_id, message]);
    b.unreachable();
    b.position(after);
    if nd.finally_body is not None {
        self.lower_body(nd.finally_body.body);
    }
}

impl MirLowering.caught_state(frame: MirValue) -> tuple[MirValue, MirValue, MirValue] {
    b = self.builder();
    address = self.address_of(frame);
    type_id = self.emit_value(
        MirOp.MEM_LOAD,
        mir_int(32, True, True),
        [b.binary("add", address, b.const_int(EXC_TYPE_OFFSET, mir_int()))]
    );
    message = self.emit_value(
        MirOp.PTR_CAST,
        mir_c_ptr(mir_int(8, False)),
        [
            self.emit_value(
                MirOp.MEM_LOAD,
                mir_int(),
                [b.binary("add", address, b.const_int(EXC_MESSAGE_OFFSET, mir_int()))]
            )
        ]
    );
    origin = self.emit_value(
        MirOp.PTR_CAST,
        mir_c_ptr(mir_int(8, False)),
        [self.emit_value(MirOp.MEM_LOAD, mir_int(), [address])]
    );
    return (origin, type_id, message);
}

impl MirLowering.leave_tries(loop_depth: int, run_finals: bool = True) {
    tries = list(self.st().tries);
    finals = list(self.st().finals) if run_finals else [];
    at_final = len(finals) - 1;
    at_try = len(tries) - 1;
    while at_final >= 0 or at_try >= 0 {
        if at_final >= 0 and (at_try < 0 or finals[at_final][2] > at_try) {
            (body, depth, _) = finals[at_final];
            if depth >= loop_depth {
                self.st().finals = finals[:at_final];
                self.st().tries = tries[:at_try + 1];
                self.lower_body(body);
                self.st().finals = finals;
                self.st().tries = tries;
            }
            at_final -= 1;
        } else {
            (frame, _, depth) = tries[at_try];
            if depth >= loop_depth {
                self.runtime("__jac_rt_exc_pop", [frame]);
                exit_action = self.st().try_exits.get(id(frame));
                if exit_action is not None and run_finals {
                    held_finals = list(self.st().finals);
                    self.st().tries = tries[:at_try];
                    self.st().finals = [
                        pending
                        for pending in held_finals
                        if pending[2] <= at_try
                    ];
                    self.run_with_exit(exit_action);
                    self.st().tries = tries;
                    self.st().finals = held_finals;
                }
            }
            at_try -= 1;
        }
    }
}

impl MirLowering.rearm_tries {
    b = self.builder();
    fn = self.st().fn;
    for (frame, dispatch, _) in self.st().tries {
        self.runtime("__jac_rt_exc_push", [frame]);
        armed = self.emit_value(
            MirOp.SETJMP,
            mir_int(32, True, True),
            [self.runtime_value("__jac_rt_exc_jmp_buf", [frame])]
        );
        resumed = fn.new_block("try.resume");
        b.cond_branch(
            b.compare("eq", armed, b.const_int(0, armed.type)), resumed, dispatch
        );
        b.position(resumed);
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
    cause = nd.cause;
    if isinstance(cause, uni.Name)
        and cause.sym is not None
        and id(cause.sym) in self.st().bound_caught {
        (origin, type_id, message) = self.st().bound_caught[id(cause.sym)];
        self.runtime("__jac_rt_raise", [origin, type_id, message]);
        b.unreachable();
        return;
    }
    callee_class = isinstance(cause, uni.FuncCall)
        and isinstance(cause.target, uni.Expr)
        and (
            (
                isinstance(cause.target, uni.Name)
                and JAC_TYPE_REGISTRY.is_exception(cause.target.value)
            )
            or (
                self.target_archetype(cause.target) is not None
                and isinstance(cause.target.type, ClassType)
                and not cause.target.type.is_instance()
            )
        );
    if isinstance(cause, uni.Name)
        and JAC_TYPE_REGISTRY.is_exception(cause.value)
        and isinstance(cause.type, ClassType)
        and not cause.type.is_instance() {
        self.raise_named(cause.value, None, nd);
        return;
    }
    if isinstance(cause, uni.FuncCall) and callee_class {
        (name, arch) = self.exception_target(cause);
        if arch is not None {
            self.raise_object(self.exception_object(cause, arch), arch, nd);
            return;
        }
        args = self.call_args(cause);
        self.raise_named(name, args[0] if args else None, nd);
        return;
    }
    held_type = self.expr_type(cause);
    if held_type.kind == MirKind.OBJ {
        arch = self.archetypes.get(held_type.name);
        if arch is not None and self.is_exception_arch(arch) {
            self.raise_object(self.lower_expr(cause), arch, nd, True);
            return;
        }
    }
    if held_type.kind == MirKind.STR
        and isinstance(cause.type, ClassType)
        and JAC_TYPE_REGISTRY.is_exception(cause.type.shared.class_name) {
        self.raise_named(cause.type.shared.class_name, cause, nd);
        return;
    }
    (name, arch) = self.exception_target(cause);
    if arch is not None {
        self.raise_object(self.exception_object(None, arch), arch, nd);
        return;
    }
    self.raise_named(name, None, nd);
}

impl MirLowering.exception_message(value: MirValue, arch: uni.Archetype) -> MirValue {
    b = self.builder();
    obj_def = self.object_def(arch);
    if obj_def.field(EXC_MESSAGE_FIELD) is None {
        return b.const_int(0, mir_int());
    }
    place = self.field_place(value, arch, EXC_MESSAGE_FIELD, arch);
    return self.emit_value(MirOp.MEM_LOAD, mir_int(), [self.address_of(place)]);
}

impl MirLowering.exception_text(value: MirValue, arch: uni.Archetype) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    stored = self.exception_message(value, arch);
    held = self.temp_slot(mir_str());
    some = fn.new_block("exc.text");
    none = fn.new_block("exc.empty");
    done = fn.new_block("exc.text.done");
    b.cond_branch(b.compare("ne", stored, b.const_int(0, mir_int())), some, none);
    b.position(some);
    text = b.ref_cast(stored, mir_str_ref(), False);
    self.runtime("__jac_rt_retain", [text]);
    size = self.runtime("__jac_rt_str_size", [text]);
    if size is None {
        raise MirRefused(mir_refusal("conversion", "exception text", arch));
    }
    made = b.str_make(b.ref_cast(stored, mir_str_ref(), True), text, size);
    b.store(held, made);
    b.branch(done);
    b.position(none);
    b.store(held, b.const_str("", mir_str()));
    b.branch(done);
    b.position(done);
    return b.load(held, mir_str());
}

impl MirLowering.exception_object(
    nd: (uni.FuncCall | None), arch: uni.Archetype
) -> MirValue {
    b = self.builder();
    obj_def = self.object_def(arch);
    params = self.constructor_params(arch);
    positional: list[uni.Expr] = [];
    named: dict[str, uni.Expr] = {};
    for arg in list(nd.params or []) if nd is not None else [] {
        if isinstance(arg, uni.KWPair) {
            if arg.key is None {
                raise MirRefused(
                    mir_refusal("call argument", "keyword unpacking", arg)
                );
            }
            named[arg.key.sym_name] = arg.value;
        } else {
            positional.append(arg);
        }
    }
    if nd is None {
        raise MirRefused(
            mir_refusal(
                "exception",
                f"{obj_def.name} raised without a call",
                arch,
                "Raise an instance: `raise E()`."
            )
        );
    }
    has_init = (self.find_method(arch, "init") or self.find_method(arch, "__init__"))
        is not None;
    if has_init or obj_def.field(EXC_MESSAGE_FIELD) is None {
        return self.object_call(nd, arch);
    }
    lowered = [self.spill(self.lower_expr(arg)) for arg in positional];
    values: list[MirValue] = [];
    mask = 0;
    site = nd;
    for (index, (pname, ptype, fallback)) in enumerate(params) {
        if index < len(lowered) {
            values.append(self.coerce(lowered[index], ptype, positional[index]));
            if fallback is not None {
                mask = mask | (1 << index);
            }
            continue;
        }
        source = named.get(pname);
        if source is None and fallback is not None {
            values.append(self.placeholder(ptype));
            continue;
        }
        if source is None {
            raise MirRefused(
                mir_refusal("call", f"{obj_def.name} missing {pname}", site)
            );
        }
        if fallback is not None {
            mask = mask | (1 << index);
        }
        values.append(self.coerce(self.lower_expr(source), ptype, source));
    }
    if self.ctor_takes_mask(params) {
        values.append(b.const_int(mask, mir_int()));
    }
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    symbol = native_symbol_name(
        native_unit_prefix(owner.loc.mod_path), f"{obj_def.name}.__ctor"
    );
    made = self.spill(self.construct(symbol, obj_def, owner, params, values, site));
    self.register_exception(arch);
    if not lowered {
        return made;
    }
    text: MirValue;
    if len(lowered) == 1 {
        text = self.to_str(lowered[0], positional[0]);
    } else {
        text = b.const_str("(", mir_str());
        for (index, value) in enumerate(lowered) {
            if index > 0 {
                text = self.str_concat(text, b.const_str(", ", mir_str()));
            }
            text = self.str_concat(text, self.repr_of(value, positional[index]));
        }
        text = self.str_concat(text, b.const_str(")", mir_str()));
    }
    place = self.field_place(made, arch, EXC_MESSAGE_FIELD, site);
    b.store(place, self.coerce(text, self.place_elem(place), site));
    return made;
}

impl MirLowering.register_exception(arch: uni.Archetype) {
    b = self.builder();
    tid = JAC_TYPE_REGISTRY.exception_type_id(archetype_native_name(arch));
    for ancestor in self.exception_ancestors(arch) {
        self.runtime(
            "__jac_rt_exc_lineage_add",
            [b.const_int(tid, mir_int()), b.const_int(ancestor, mir_int())]
        );
    }
    self.runtime(
        "__jac_rt_exc_class_add",
        [
            self.emit_value(
                MirOp.CSTR,
                mir_c_ptr(mir_int(8, False)),
                [],
                str_value=self.object_def(arch).name
            ),
            b.const_int(tid, mir_int())
        ]
    );
}

impl MirLowering.raise_object(
    value: MirValue, arch: uni.Archetype, site: uni.UniNode, dynamic: bool = False
) {
    b = self.builder();
    i8p = mir_c_ptr(mir_int(8, False));
    held = value;
    if not value.owned {
        self.runtime("__jac_rt_retain", [held]);
    }
    tid = JAC_TYPE_REGISTRY.exception_type_id(archetype_native_name(arch));
    self.register_exception(arch);
    raised: MirValue = b.const_int(tid, mir_int(32, True, True));
    if dynamic {
        found = self.runtime(
            "__jac_rt_exc_class_of",
            [self.address_of(held), b.const_int(tid, mir_int())]
        );
        if found is not None {
            raised = b.convert(found, mir_int(32, True, True));
        }
    }
    stored = self.exception_message(held, arch);
    fallback = self.address_of(b.const_str(arch.name.value, mir_str_ref()));
    message = b.select(
        b.compare("ne", stored, b.const_int(0, mir_int())), stored, fallback
    );
    self.runtime(
        "__jac_rt_raise",
        [
            self.emit_value(MirOp.PTR_CAST, i8p, [held]),
            raised,
            self.emit_value(MirOp.PTR_CAST, i8p, [message])
        ]
    );
    b.unreachable();
}

impl MirLowering.lower_assert(nd: uni.AssertStmt) {
    if nd.is_comptime {
        return;
    }
    b = self.builder();
    fn = self.st().fn;
    failed = fn.new_block("assert.fail");
    passed = fn.new_block("assert.ok");
    b.cond_branch(self.condition(nd.condition), passed, failed);
    b.position(failed);
    message = nd.error_msg;
    if self.st().in_test
        and (
            message is None
            or (isinstance(message, uni.String) and isinstance(message.lit_value, str))
        ) {
        said = message.lit_value
            if isinstance(message, uni.String)
            else "assertion failed";
        path = self.module.loc.mod_path if self.module.loc else "";
        b.raise_builtin("AssertionError", f"{said} at {path}:{nd.loc.first_line}");
    } else {
        self.raise_named("AssertionError", message, nd);
    }
    b.position(passed);
}

impl MirLowering.raise_named(
    name: str, message_nd: (uni.UniNode | None), nd: uni.UniNode
) {
    b = self.builder();
    if message_nd is None {
        b.raise_builtin(name, "");
        return;
    }
    if isinstance(message_nd, uni.String) and isinstance(message_nd.lit_value, str) {
        b.raise_builtin(name, message_nd.lit_value);
        return;
    }
    message = self.lower_expr(message_nd);
    if message.type.kind == MirKind.C_PTR {
        self.runtime(
            "__jac_rt_raise_builtin",
            [
                b.const_int(
                    JAC_TYPE_REGISTRY.exception_type_id(name), mir_int(32, True, True)
                ),
                message
            ]
        );
        b.unreachable();
        return;
    }
    text = self.to_str(message, message_nd);
    held = self.runtime(
        "__jac_rt_str_ref",
        [b.str_part(text, "root"), b.str_part(text, "data"), b.str_part(text, "len")]
    );
    if held is None {
        raise MirRefused(mir_refusal("statement", "raise", nd));
    }
    data = self.emit_value(MirOp.PTR_CAST, mir_c_ptr(mir_int(8, False)), [held]);
    self.runtime(
        "__jac_rt_raise",
        [
            data,
            b.const_int(
                JAC_TYPE_REGISTRY.exception_type_id(name), mir_int(32, True, True)
            ),
            data
        ]
    );
    b.unreachable();
}

impl MirLowering.lower_test(nd: uni.Test) -> (MirFunction | None) {
    line = nd.loc.first_line if nd.loc else 0;
    name = native_test_symbol(nd.name.sym_name, line);
    i8p = mir_c_ptr(mir_int(8, False));
    fn = MirFunction(
        name=name,
        symbol=native_test_symbol(nd.name.sym_name, line, self.mir.prefix),
        ret=i8p
    );
    self.state = MirFnState(
        fn=fn, b=MirBuilder(fn=fn, block=fn.new_block("entry")), in_test=True
    );
    try {
        b = self.builder();
        frame = fn.new_value(i8p, "exc.frame");
        fn.blocks[0].instrs.insert(0, MirInstr(op=MirOp.EXC_FRAME, result=frame));
        self.runtime("__jac_rt_exc_push", [frame]);
        buffer = self.runtime("__jac_rt_exc_jmp_buf", [frame]);
        if buffer is None {
            raise MirRefused(mir_refusal("test", nd.name.sym_name, nd));
        }
        armed = self.emit_value(MirOp.SETJMP, mir_int(32, True, True), [buffer]);
        body = fn.new_block("test.body");
        failed = fn.new_block("test.fail");
        b.cond_branch(b.compare("eq", armed, b.const_int(0, armed.type)), body, failed);
        b.position(body);
        self.st().tries.append((frame, failed, 0));
        self.prepare_cells(nd, list(nd.body or []));
        self.lower_body(list(nd.body or []));
        self.st().tries.pop();
        if not self.builder().block.terminated() {
            self.runtime("__jac_rt_exc_pop", [frame]);
            self.flush_stdio();
            self.builder().ret(self.emit_value(MirOp.PTR_NULL, i8p, []));
        }
        self.builder().position(failed);
        self.runtime("__jac_rt_exc_pop", [frame]);
        self.flush_stdio();
        address = self.address_of(frame);
        message = self.emit_value(
            MirOp.PTR_CAST,
            i8p,
            [
                self.emit_value(
                    MirOp.MEM_LOAD,
                    mir_int(),
                    [
                        self.builder().binary(
                            "add",
                            address,
                            self.builder().const_int(EXC_MESSAGE_OFFSET, mir_int())
                        )
                    ]
                )
            ]
        );
        self.builder().ret(message);
        for blk in fn.blocks {
            if not blk.terminated() {
                self.builder().position(blk);
                self.builder().unreachable();
            }
        }
    } except MirRefused as err {
        self.refusals.setdefault(name, []).append(refusal_of(err));
        self.state = None;
        return None;
    }
    self.state = None;
    self.tests.append(
        (
            nd.name.sym_name,
            fn.symbol,
            str(nd.description.lit_value) if nd.description else "",
            line
        )
    );
    return fn;
}
