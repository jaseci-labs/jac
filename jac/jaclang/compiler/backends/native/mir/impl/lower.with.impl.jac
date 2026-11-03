impl MirLowering.lower_with(nd: uni.WithStmt) {
    if nd.is_async {
        raise MirRefused(mir_refusal("statement", "async with", nd));
    }
    self.with_items(list(nd.exprs), 0, nd.body);
}

impl MirLowering.with_items(
    items: list[uni.ExprAsItem], index: int, body: Sequence[uni.CodeBlockStmt]
) {
    if index >= len(items) {
        self.lower_body(body);
        return;
    }
    item = items[index];
    source = item.expr;
    callee = source.callee_decl if isinstance(source, uni.FuncCall) else None;
    if callee is not None and contextmanager_ability(callee) {
        self.with_generator(items, index, body);
        return;
    }
    b = self.builder();
    fn = self.st().fn;
    manager = self.lower_expr(source);
    if manager.type.kind == MirKind.FILE {
        held_file = self.spill(manager);
        if item.alias is not None {
            self.bind_target(item.alias, held_file);
        }
        self.with_guarded(items, index, body, MirWithExit(site=item, file=held_file));
        return;
    }
    arch = self.arch_of_type(source.type);
    if arch is None or manager.type.kind != MirKind.OBJ {
        raise MirRefused(
            mir_refusal(
                "with",
                manager.type.render(),
                item,
                "A native context manager is an archetype with __enter__ and __exit__, or a @contextmanager generator."
            )
        );
    }
    enter_method = self.find_method(arch, "__enter__");
    leave_method = self.find_method(arch, "__exit__");
    enter_decl = self.method_decl_of(enter_method)
        if enter_method is not None
        else None;
    leave_decl = self.method_decl_of(leave_method)
        if leave_method is not None
        else None;
    if enter_decl is None or leave_decl is None {
        raise MirRefused(
            mir_refusal(
                "with",
                f"{archetype_native_name(arch)} without native __enter__ and __exit__",
                item
            )
        );
    }
    held = self.spill(manager);
    entered = b.call(enter_decl.symbol, [held], enter_decl.ret);
    if item.alias is not None {
        if entered is None {
            raise MirRefused(
                mir_refusal("with", "alias of __enter__ returning nothing", item)
            );
        }
        self.bind_target(item.alias, entered);
    }
    self.with_guarded(
        items, index, body, MirWithExit(site=item, decl=leave_decl, held=held)
    );
}

impl MirLowering.with_guarded(
    items: list[uni.ExprAsItem],
    index: int,
    body: Sequence[uni.CodeBlockStmt],
    exit_action: MirWithExit
) {
    b = self.builder();
    fn = self.st().fn;
    (frame, dispatch) = self.guard_open();
    self.st().tries.append((frame, dispatch, len(self.st().loops)));
    self.st().try_exits[id(frame)] = exit_action;
    self.with_items(items, index + 1, body);
    self.st().tries.pop();
    after = fn.new_block("with.done");
    if not self.builder().block.terminated() {
        self.runtime("__jac_rt_exc_pop", [frame]);
        self.run_with_exit(exit_action);
        self.builder().branch(after);
    }
    b.position(dispatch);
    self.runtime("__jac_rt_exc_pop", [frame]);
    (origin, type_id, message) = self.guard_caught(frame);
    swallowed = self.run_with_exit(exit_action);
    propagate = fn.new_block("with.propagate");
    b.cond_branch(swallowed, after, propagate);
    b.position(propagate);
    self.runtime("__jac_rt_raise", [origin, type_id, message]);
    b.unreachable();
    b.position(after);
}

impl MirLowering.with_generator(
    items: list[uni.ExprAsItem], index: int, body: Sequence[uni.CodeBlockStmt]
) {
    item = items[index];
    b = self.builder();
    fn = self.st().fn;
    self.manager_item = item.expr;
    it = self.spill(self.lower_expr(item.expr));
    self.manager_item = None;
    if it.type.kind != MirKind.ITER {
        raise MirRefused(
            mir_refusal(
                "context manager",
                it.type.render(),
                item,
                "A native @contextmanager generator must declare a generator-family return type with a lowerable element, e.g. `-> Iterator[None]`."
            )
        );
    }
    out = self.temp_slot(mir_int());
    self.raise_if(
        b.logical_not(self.iter_advance(it, out)),
        "RuntimeError",
        "generator didn't yield"
    );
    if item.alias is not None {
        self.bind_target(
            item.alias,
            self.element_from_bits(b.load(out, mir_int()), it.type.payload())
        );
    }
    (frame, dispatch) = self.guard_open();
    self.st().tries.append((frame, dispatch, len(self.st().loops)));
    self.st().try_exits[id(frame)] = MirWithExit(site=item, it=it, out=out);
    self.with_items(items, index + 1, body);
    self.st().tries.pop();
    after = fn.new_block("with.gen.done");
    if not self.builder().block.terminated() {
        self.runtime("__jac_rt_exc_pop", [frame]);
        self.raise_if(
            self.iter_advance(it, out), "RuntimeError", "generator didn't stop"
        );
        self.builder().branch(after);
    }
    b.position(dispatch);
    self.runtime("__jac_rt_exc_pop", [frame]);
    (origin, type_id, message) = self.guard_caught(frame);
    self.runtime("__jac_rt_raise", [origin, type_id, message]);
    b.unreachable();
    b.position(after);
}

impl MirLowering.call_exit(
    decl: MirDecl, held: MirValue, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    args = [held] + [self.none_arg(ptype, site) for ptype in decl.params];
    result = b.call(decl.symbol, args, decl.ret);
    if result is None or decl.ret.kind in (MirKind.NONE, MirKind.VOID) {
        return b.const_bool(False);
    }
    return self.truthy(result, site);
}

impl MirLowering.none_arg(ptype: MirType, site: uni.UniNode) -> MirValue {
    if ptype.kind in (MirKind.OPT, MirKind.ANY) {
        return self.coerce(self.none_value(), ptype, site);
    }
    if ptype.kind == MirKind.NONE {
        return self.none_value();
    }
    if mir_holds_ref(ptype) or ptype.kind in (MirKind.CLASS, MirKind.C_PTR) {
        return self.builder().const_null(ptype);
    }
    raise MirRefused(
        mir_refusal(
            "with",
            f"__exit__ parameter of {ptype.render()}",
            site,
            "Native __exit__ receives None for each exception argument; give its parameters an optional or `any` type."
        )
    );
}

impl MirLowering.guard_open -> tuple[MirValue, MirBlock] {
    b = self.builder();
    fn = self.st().fn;
    frame = fn.new_value(mir_c_ptr(mir_int(8, False)), "exc.frame");
    fn.blocks[0].instrs.insert(0, MirInstr(op=MirOp.EXC_FRAME, result=frame));
    self.runtime("__jac_rt_exc_push", [frame]);
    armed = self.emit_value(
        MirOp.SETJMP,
        mir_int(32, True, True),
        [self.runtime_value("__jac_rt_exc_jmp_buf", [frame])]
    );
    body = fn.new_block("guard.body");
    dispatch = fn.new_block("guard.caught");
    b.cond_branch(b.compare("eq", armed, b.const_int(0, armed.type)), body, dispatch);
    b.position(body);
    return (frame, dispatch);
}

impl MirLowering.guard_caught(frame: MirValue) -> tuple[MirValue, MirValue, MirValue] {
    b = self.builder();
    i8p = mir_c_ptr(mir_int(8, False));
    address = self.address_of(frame);
    type_id = self.emit_value(
        MirOp.MEM_LOAD,
        mir_int(32, True, True),
        [b.binary("add", address, b.const_int(EXC_TYPE_OFFSET, mir_int()))]
    );
    message = self.emit_value(
        MirOp.PTR_CAST,
        i8p,
        [
            self.emit_value(
                MirOp.MEM_LOAD,
                mir_int(),
                [b.binary("add", address, b.const_int(EXC_MESSAGE_OFFSET, mir_int()))]
            )
        ]
    );
    origin = self.emit_value(
        MirOp.PTR_CAST, i8p, [self.emit_value(MirOp.MEM_LOAD, mir_int(), [address])]
    );
    return (origin, type_id, message);
}

impl MirLowering.run_with_exit(exit_action: MirWithExit) -> MirValue {
    if exit_action.decl is not None and exit_action.held is not None {
        return self.call_exit(exit_action.decl, exit_action.held, exit_action.site);
    }
    if exit_action.file is not None {
        self.runtime("__jac_rt_file_close", [exit_action.file]);
    }
    if exit_action.region {
        self.region_extern("__jac_region_leave", [], mir_none());
    }
    if exit_action.region_drop is not None {
        self.region_extern("__jac_region_drop", [exit_action.region_drop], mir_none());
    }
    if exit_action.it is not None and exit_action.out is not None {
        self.raise_if(
            self.iter_advance(exit_action.it, exit_action.out),
            "RuntimeError",
            "generator didn't stop"
        );
    }
    return self.builder().const_bool(False);
}

impl MirLowering.jumps_out(body: Sequence[uni.UniNode]) -> bool {
    pending: list[tuple[uni.UniNode, bool]] = [(stmt, False) for stmt in body];
    while pending {
        (current, in_loop) = pending.pop();
        if isinstance(current, (uni.Ability, uni.LambdaExpr)) {
            continue;
        }
        if isinstance(current, uni.ReturnStmt) {
            return True;
        }
        if isinstance(current, uni.CtrlStmt) and not in_loop {
            return True;
        }
        inner = in_loop
            or isinstance(
                current,
                (uni.WhileStmt, uni.ForeverStmt, uni.InForStmt, uni.IterForStmt)
            );
        for kid in current._children() {
            pending.append((kid, inner));
        }
    }
    return False;
}

impl MirLowering.lower_match(nd: uni.MatchStmt) {
    b = self.builder();
    fn = self.st().fn;
    subject = self.spill(self.lower_expr(nd.target));
    done = fn.new_block("match.done");
    for arm in nd.cases {
        fail = fn.new_block("match.next");
        self.match_test(arm.pattern, subject, fail, arm);
        if arm.guard is not None {
            chosen = fn.new_block("match.body");
            b.cond_branch(self.condition(arm.guard), chosen, fail);
            b.position(chosen);
        }
        self.lower_body(arm.body);
        if not self.builder().block.terminated() {
            self.builder().branch(done);
        }
        b.position(fail);
    }
    b.branch(done);
    b.position(done);
}

impl MirLowering.lower_switch(nd: uni.SwitchStmt) {
    b = self.builder();
    fn = self.st().fn;
    subject = self.spill(self.lower_expr(nd.target));
    done = fn.new_block("switch.done");
    arms = list(nd.cases);
    bodies = [fn.new_block("switch.case") for _ in arms];
    reached = False;
    for (index, arm) in enumerate(arms) {
        if arm.pattern is None {
            b.branch(bodies[index]);
            reached = True;
            break;
        }
        fail = fn.new_block("switch.next");
        self.match_test(arm.pattern, subject, fail, arm);
        b.branch(bodies[index]);
        b.position(fail);
    }
    if not reached {
        b.branch(done);
    }
    resume = self.st().loops[-1].head if self.st().loops else done;
    self.st().loops.append(MirLoopTarget(head=resume, after=done));
    for (index, arm) in enumerate(arms) {
        b.position(bodies[index]);
        self.lower_body(arm.body);
        if not self.builder().block.terminated() {
            self.builder().branch(bodies[index + 1] if index + 1 < len(arms) else done);
        }
    }
    self.st().loops.pop();
    b.position(done);
}

impl MirLowering.branch_unless(cond: MirValue, fail: MirBlock) {
    b = self.builder();
    ok = self.st().fn.new_block("match.ok");
    b.cond_branch(cond, ok, fail);
    b.position(ok);
}

impl MirLowering.match_test(
    pat: uni.MatchPattern, subject: MirValue, fail: MirBlock, site: uni.UniNode
) {
    b = self.builder();
    fn = self.st().fn;
    if isinstance(pat, uni.MatchWild) {
        return;
    }
    if isinstance(pat, uni.MatchAs) {
        if pat.pattern is not None {
            self.match_test(pat.pattern, subject, fail, pat);
        }
        if not isinstance(pat.name, uni.Name) {
            raise MirRefused(mir_refusal("match pattern", "capture", pat));
        }
        self.store_name(pat.name, subject);
        return;
    }
    if isinstance(pat, uni.MatchValue) {
        wanted = self.lower_expr(pat.value);
        self.branch_unless(self.compare_values(Tok.EE, subject, wanted, pat), fail);
        return;
    }
    if isinstance(pat, uni.MatchSingleton) {
        if isinstance(pat.value, uni.Null) {
            self.branch_unless(self.is_absent(subject), fail);
            return;
        }
        self.branch_unless(
            self.compare_values(Tok.EE, subject, self.lower_expr(pat.value), pat), fail
        );
        return;
    }
    if isinstance(pat, uni.MatchOr) {
        matched = fn.new_block("match.or");
        for option in pat.patterns {
            following = fn.new_block("match.alt");
            self.match_test(option, subject, following, option);
            self.builder().branch(matched);
            b.position(following);
        }
        b.branch(fail);
        b.position(matched);
        return;
    }
    if isinstance(pat, uni.MatchSequence) {
        stars = [
            index
            for (index, part) in enumerate(pat.values)
            if isinstance(part, uni.MatchStar)
        ];
        if stars and subject.type.kind == MirKind.LIST and len(stars) == 1 {
            self.match_star_sequence(pat, stars[0], subject, fail);
            return;
        }
        if stars {
            raise MirRefused(mir_refusal("match pattern", "star in a sequence", pat));
        }
        if subject.type.kind == MirKind.TUPLE {
            if len(pat.values) != len(subject.type.args) {
                b.branch(fail);
                b.position(fn.new_block("match.dead"));
                return;
            }
            for (index, part) in enumerate(pat.values) {
                self.match_test(part, self.tuple_get(subject, index), fail, part);
            }
            return;
        }
        if subject.type.kind == MirKind.LIST {
            self.branch_unless(
                b.compare(
                    "eq",
                    self.container_len(subject),
                    b.const_int(len(pat.values), mir_int())
                ),
                fail
            );
            for (index, part) in enumerate(pat.values) {
                element = self.spill(
                    self.list_read(subject, b.const_int(index, mir_int()))
                );
                self.match_test(part, element, fail, part);
            }
            return;
        }
        raise MirRefused(
            mir_refusal("match pattern", f"sequence over {subject.type.render()}", pat)
        );
    }
    if isinstance(pat, uni.MatchMapping) {
        if subject.type.kind != MirKind.DICT {
            raise MirRefused(
                mir_refusal(
                    "match pattern", f"mapping over {subject.type.render()}", pat
                )
            );
        }
        key_type = subject.type.args[0];
        matched_keys: list[MirValue] = [];
        rest: (uni.MatchStar | None) = None;
        for entry_pat in pat.values {
            if isinstance(entry_pat, uni.MatchStar) {
                rest = entry_pat;
                continue;
            }
            if not isinstance(entry_pat, uni.MatchKVPair) {
                raise MirRefused(
                    mir_refusal("match pattern", "** in a mapping", entry_pat)
                );
            }
            key_node: uni.UniNode = entry_pat.key;
            if isinstance(key_node, uni.MatchValue) {
                key_node = key_node.value;
            }
            if not isinstance(key_node, uni.Expr) {
                raise MirRefused(
                    mir_refusal("match pattern", "mapping key", entry_pat)
                );
            }
            key = self.spill(self.lower_expr(key_node));
            matched_keys.append(key);
            found = self.runtime_value(
                "__jac_rt_dict_find",
                [
                    subject,
                    self.to_bits(key, key_type, entry_pat),
                    b.const_int(self.elem_kind(key_type, entry_pat), mir_int())
                ]
            );
            self.branch_unless(b.compare("ge", found, b.const_int(0, mir_int())), fail);
            self.match_test(
                entry_pat.value,
                self.spill(self.dict_get(subject, key, entry_pat)),
                fail,
                entry_pat
            );
        }
        if rest is not None
            and isinstance(rest.name, uni.Name)
            and rest.name.sym is not None {
            value_type = subject.type.args[1];
            key_kind = b.const_int(self.elem_kind(key_type, rest), mir_int());
            value_kind = b.const_int(self.elem_kind(value_type, rest), mir_int());
            copied = self.spill(
                b.ref_cast(
                    self.runtime_value(
                        "__jac_rt_dict_copy", [subject, key_kind, value_kind]
                    ),
                    subject.type,
                    True
                )
            );
            for key in matched_keys {
                self.runtime(
                    "__jac_rt_dict_del",
                    [copied, self.to_bits(key, key_type, rest), key_kind, value_kind]
                );
            }
            self.store_name(rest.name, copied);
        }
        return;
    }
    if isinstance(pat, uni.MatchArch) {
        self.match_arch(pat, subject, fail);
        return;
    }
    raise MirRefused(mir_refusal("match pattern", type(pat).__name__, site));
}

impl MirLowering.match_arch(pat: uni.MatchArch, subject: MirValue, fail: MirBlock) {
    b = self.builder();
    arch = self.target_archetype(pat.name);
    if arch is None {
        raise MirRefused(
            mir_refusal("match pattern", "class pattern of a non-archetype", pat)
        );
    }
    wanted = self.object_type(arch);
    shaped: MirValue;
    if subject.type.kind == MirKind.ANY {
        self.branch_unless(self.any_isinstance(subject, pat.name, pat), fail);
        shaped = self.any_unbox(subject, wanted, pat);
    } elif subject.type.kind == MirKind.OBJ {
        self.branch_unless(self.isinstance_check(subject, arch), fail);
        shaped = b.ref_cast(subject, wanted, False);
    } else {
        raise MirRefused(
            mir_refusal(
                "match pattern", f"class pattern on {subject.type.render()}", pat
            )
        );
    }
    fields = self.object_def(arch).fields;
    checks: list[tuple[str, uni.MatchPattern]] = [];
    for (index, part) in enumerate(list(pat.arg_patterns or [])) {
        if index >= len(fields) {
            raise MirRefused(
                mir_refusal(
                    "match pattern",
                    f"{len(fields)} fields of {archetype_native_name(arch)}",
                    pat
                )
            );
        }
        checks.append((fields[index].name, part));
    }
    for pair in list(pat.kw_patterns or []) {
        key = pair.key;
        if not isinstance(key, uni.Name) {
            raise MirRefused(mir_refusal("match pattern", "keyword pattern", pair));
        }
        checks.append((key.value, pair.value));
    }
    for (field_name, part) in checks {
        place = self.field_place(shaped, arch, field_name, pat);
        self.match_test(
            part, self.spill(b.load(place, self.place_elem(place))), fail, part
        );
    }
}

impl MirLowering.match_star_sequence(
    pat: uni.MatchSequence, at: int, subject: MirValue, fail: MirBlock
) {
    b = self.builder();
    heads = pat.values[:at];
    tails = pat.values[at + 1:];
    size = self.container_len(subject);
    self.branch_unless(
        b.compare("ge", size, b.const_int(len(heads) + len(tails), mir_int())), fail
    );
    for (index, part) in enumerate(heads) {
        element = self.spill(self.list_read(subject, b.const_int(index, mir_int())));
        self.match_test(part, element, fail, part);
    }
    for (index, part) in enumerate(tails) {
        position = b.binary("sub", size, b.const_int(len(tails) - index, mir_int()));
        element = self.spill(self.list_read(subject, position));
        self.match_test(part, element, fail, part);
    }
    star = pat.values[at];
    if isinstance(star, uni.MatchStar)
        and isinstance(star.name, uni.Name)
        and star.name.sym is not None {
        middle = self.runtime_value(
            "__jac_rt_list_slice",
            [
                subject,
                b.const_int(len(heads), mir_int()),
                b.binary("sub", size, b.const_int(len(tails), mir_int())),
                b.const_int(1, mir_int()),
                b.const_int(self.elem_kind(subject.type.payload(), star), mir_int())
            ]
        );
        self.store_name(star.name, self.spill(b.ref_cast(middle, subject.type, True)));
    }
}
