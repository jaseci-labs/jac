impl MirLowering.flow_marked(nd: uni.InForStmt) -> bool {
    return any(
        isinstance(k, uni.Token) and k.name == Tok.KW_FLOW for k in nd._children()
    );
}

impl MirLowering.chunk_shape(source: uni.Expr) -> (tuple[uni.Expr, uni.Expr] | None) {
    inner: uni.UniNode = source;
    if isinstance(source, uni.UnaryExpr) and is_borrow_kind(source.ownership) {
        inner = source.operand;
    }
    if not isinstance(inner, uni.FuncCall)
        or not isinstance(inner.target, uni.AtomTrailer)
        or not inner.target.is_attr
        or not isinstance(inner.target.right, uni.Name)
        or inner.target.right.value != "chunks"
        or not isinstance(inner.target.target, uni.Expr) {
        return None;
    }
    args = self.call_args(inner);
    if len(args) != 1 or self.expr_type(inner.target.target).kind != MirKind.LIST {
        return None;
    }
    return (inner.target.target, args[0]);
}

impl MirLowering.view_block -> MirValue {
    fn = self.st().fn;
    made = fn.new_value(mir_c_ptr(mir_int(64)));
    fn.blocks[0].instrs.insert(
        0, MirInstr(op=MirOp.ALLOCA, result=made, int_value=LIST_VIEW_WORDS)
    );
    return self.emit_value(MirOp.PTR_INT, mir_int(), [made]);
}

impl MirLowering.chunk_view(
    block: MirValue, lst: MirValue, index: MirValue, width: MirValue
) -> MirValue {
    b = self.builder();
    view = self.runtime_value(
        "__jac_rt_list_view", [block, lst, b.binary("mul", index, width), width]
    );
    return b.ref_cast(view, lst.type, False);
}

impl MirLowering.chunk_width(n_nd: uni.Expr) -> MirValue {
    b = self.builder();
    width = self.coerce(self.lower_expr(n_nd), mir_int(), n_nd);
    one = b.const_int(1, mir_int());
    return b.select(b.compare("lt", width, one), one, width);
}

impl MirLowering.chunk_count(lst: MirValue, width: MirValue) -> MirValue {
    b = self.builder();
    total = self.container_len(lst);
    return b.binary(
        "floordiv",
        b.binary("sub", b.binary("add", total, width), b.const_int(1, mir_int())),
        width
    );
}

impl MirLowering.lower_chunk_for(nd: uni.InForStmt, lst_nd: uni.Expr, n_nd: uni.Expr) {
    b = self.builder();
    fn = self.st().fn;
    if not isinstance(nd.target, uni.Name) {
        raise MirRefused(mir_refusal("statement", "for target", nd.target));
    }
    lst = self.spill(self.lower_expr(lst_nd));
    if lst.type.payload().kind == MirKind.C_STRUCT {
        raise MirRefused(mir_refusal("statement", "chunks of a struct list", nd));
    }
    width = self.temp_slot(mir_int());
    b.store(width, self.chunk_width(n_nd));
    count = self.temp_slot(mir_int());
    b.store(count, self.chunk_count(lst, b.load(width, mir_int())));
    block = self.view_block();
    current = self.temp_slot(mir_int());
    b.store(current, b.const_int(0, mir_int()));
    head = fn.new_block("chunk.head");
    body = fn.new_block("chunk.body");
    advance = fn.new_block("chunk.step");
    otherwise = fn.new_block("chunk.else");
    after = fn.new_block("chunk.exit");
    b.branch(head);
    b.position(head);
    b.cond_branch(
        b.compare("lt", b.load(current, mir_int()), b.load(count, mir_int())),
        body,
        otherwise
    );
    b.position(body);
    self.store_name(
        nd.target,
        self.chunk_view(
            block, lst, b.load(current, mir_int()), b.load(width, mir_int())
        )
    );
    self.st().loops.append(MirLoopTarget(head=advance, after=after));
    self.lower_body(nd.body);
    self.st().loops.pop();
    if not self.builder().block.terminated() {
        self.builder().branch(advance);
    }
    b.position(advance);
    b.store(
        current, b.binary("add", b.load(current, mir_int()), b.const_int(1, mir_int()))
    );
    b.branch(head);
    b.position(otherwise);
    self.lower_else(nd.else_body, after);
    b.position(after);
}

impl MirLowering.flow_parallel_ok -> bool {
    mode = self.prog.options.na_gc_mode or "cycles";
    if mode == "rc" {
        return True;
    }
    return self.owned_world;
}

impl MirLowering.flow_reductions(nd: uni.InForStmt) -> list[tuple[uni.Name, str]] {
    found: list[tuple[uni.Name, str]] = [];
    for stmt in nd.body {
        assigns = ([stmt] if isinstance(stmt, uni.Assignment) else [])
            + list(stmt.get_all_sub_nodes(uni.Assignment));
        for assign in assigns {
            if not assign.na_flow_reduce
                or len(assign.target) != 1
                or not isinstance(assign.target[0], uni.Name) {
                continue;
            }
            target = assign.target[0];
            sym = target.sym;
            if sym is None or any(held.sym is sym for (held, _) in found) {
                continue;
            }
            found.append((target, assign.na_flow_reduce));
        }
    }
    return found;
}

impl MirLowering.flow_captures(
    nd: uni.InForStmt, excluded: list[uni.Symbol]
) -> list[uni.Name] {
    found: list[uni.Name] = [];
    seen: set[int] = {id(sym) for sym in excluded};
    for stmt in nd.body {
        for name in self.names_within(stmt) {
            sym = name.sym;
            if sym is None or id(sym) in seen {
                continue;
            }
            if name.value == "self" and self.st().self_value is not None {
                seen.add(id(sym));
                found.append(name);
                continue;
            }
            if id(sym) not in self.st().locals and self.cell_of(id(sym)) is None {
                continue;
            }
            decl = sym.decl;
            if decl is not None and (decl is nd or decl.is_within(nd)) {
                continue;
            }
            seen.add(id(sym));
            found.append(name);
        }
    }
    return found;
}

impl MirLowering.lower_flow_for(nd: uni.InForStmt) -> bool {
    if not self.flow_marked(nd)
        or not self.flow_parallel_ok()
        or nd.else_body is not None
        or self.st().generator is not None
        or not isinstance(nd.collection, uni.UnaryExpr)
        or "wasm" in self.prog.options.effective_triple().lower() {
        return False;
    }
    loop_target = nd.target;
    if not isinstance(loop_target, uni.Name) or loop_target.sym is None {
        return False;
    }
    for stmt in nd.body {
        if isinstance(stmt, (uni.ReturnStmt, uni.YieldExpr))
            or stmt.get_all_sub_nodes(uni.ReturnStmt)
            or stmt.get_all_sub_nodes(uni.YieldExpr) {
            return False;
        }
    }
    chunked = self.chunk_shape(nd.collection);
    source_nd = chunked[0] if chunked is not None else nd.collection.operand;
    if not isinstance(source_nd, uni.Expr)
        or self.expr_type(source_nd).kind != MirKind.LIST
        or self.expr_type(source_nd).payload().kind == MirKind.C_STRUCT {
        return False;
    }
    reductions = self.flow_reductions(nd);
    for (name, _) in reductions {
        if self.symbol_type(name.sym, name).kind != MirKind.INT {
            return False;
        }
    }
    excluded: list[uni.Symbol] = [loop_target.sym];
    for (name, _) in reductions {
        if name.sym is not None {
            excluded.append(name.sym);
        }
    }
    captures = self.flow_captures(nd, excluded);
    b = self.builder();
    i8p = mir_c_ptr(mir_int(8, False));
    lst = self.spill(self.lower_expr(source_nd));
    list_type = lst.type;
    width: (MirValue | None) = None;
    if chunked is not None {
        width = self.temp_slot(mir_int());
        b.store(width, self.chunk_width(chunked[1]));
    }
    capture_types: list[MirType] = [];
    capture_values: list[MirValue] = [];
    for name in captures {
        receiver = self.st().self_value;
        if name.value == "self" and receiver is not None {
            capture_types.append(receiver.type);
            capture_values.append(receiver);
            continue;
        }
        declared = self.symbol_type(name.sym, name);
        capture_types.append(declared);
        capture_values.append(self.coerce(self.lower_name(name), declared, name));
    }
    ctx = self.spill(
        b.ref_cast(
            self.runtime_value(
                "__jac_rt_task_new",
                [b.const_int(FLOW_CTX_CAPTURES + len(captures), mir_int())]
            ),
            mir_ref(),
            True
        )
    );
    self.runtime("__jac_rt_retain", [ctx]);
    ctx_base = self.address_of(ctx);
    list_kind = self.elem_kind(list_type, nd);
    self.task_store(
        ctx_base,
        TASK_ARGS,
        self.runtime_value(
            "__jac_rt_elem_share",
            [self.to_bits(lst, list_type, nd), b.const_int(list_kind, mir_int())]
        )
    );
    if width is not None {
        self.task_store(ctx_base, TASK_ARGS + 8, b.load(width, mir_int()));
    }
    for (index, (value, value_type)) in enumerate(zip(capture_values, capture_types)) {
        kind = self.elem_kind(value_type, nd);
        self.task_store(
            ctx_base,
            TASK_ARGS + (FLOW_CTX_CAPTURES + index) * 8,
            self.runtime_value(
                "__jac_rt_elem_share",
                [self.to_bits(value, value_type, nd), b.const_int(kind, mir_int())]
            )
        );
    }
    body_symbol = self.flow_body(
        nd, list_type, chunked is not None, captures, capture_types, reductions
    );
    items = self.temp_slot(mir_int());
    b.store(
        items,
        self.chunk_count(lst, b.load(width, mir_int()))
            if width is not None
            else self.container_len(lst)
    );
    fn = self.st().fn;
    for (symbol, ret, params) in (
        ("pthread_create", mir_int(32, True, True), [i8p, i8p, i8p, i8p]),
        ("pthread_join", mir_int(32, True, True), [mir_int(), i8p]),
        ("getenv", i8p, [i8p]),
        ("atoi", mir_int(32, True, True), [i8p]),
        ("malloc", i8p, [mir_int()]),
        ("free", mir_none(), [i8p])
    ) {
        if symbol not in self.mir.externs {
            self.mir.externs[symbol] = MirExtern(symbol=symbol, ret=ret, params=params);
        }
    }
    threads = self.temp_slot(mir_int());
    b.store(
        threads, b.const_int(int(self.prog.options.native_threads or 4), mir_int())
    );
    setting = b.call(
        "getenv",
        [self.emit_value(MirOp.CSTR, i8p, [], str_value="JAC_FLOW_THREADS")],
        i8p
    );
    if setting is None {
        raise MirRefused(mir_refusal("statement", "flow for width", nd));
    }
    parse = fn.new_block("ffor.env");
    sized = fn.new_block("ffor.sized");
    b.cond_branch(
        b.compare(
            "eq",
            self.emit_value(MirOp.PTR_INT, mir_int(), [setting]),
            b.const_int(0, mir_int())
        ),
        sized,
        parse
    );
    b.position(parse);
    parsed = b.call("atoi", [setting], mir_int(32, True, True));
    if parsed is None {
        raise MirRefused(mir_refusal("statement", "flow for width", nd));
    }
    b.store(threads, b.convert(parsed, mir_int()));
    b.branch(sized);
    b.position(sized);
    one = b.const_int(1, mir_int());
    count = b.load(items, mir_int());
    wanted = b.load(threads, mir_int());
    wanted = b.select(b.compare("lt", wanted, one), one, wanted);
    wanted = b.select(b.compare("gt", wanted, count), count, wanted);
    b.store(threads, wanted);
    span = self.temp_slot(mir_int());
    b.store(
        span,
        b.binary(
            "floordiv",
            b.binary("sub", b.binary("add", count, wanted), one),
            b.select(b.compare("lt", wanted, one), one, wanted)
        )
    );
    table = b.call(
        "malloc",
        [b.binary("mul", b.binary("add", wanted, one), b.const_int(8, mir_int()))],
        i8p
    );
    if table is None {
        raise MirRefused(mir_refusal("statement", "flow for tasks", nd));
    }
    slots = self.temp_slot(mir_int());
    b.store(slots, self.emit_value(MirOp.PTR_INT, mir_int(), [table]));
    self.mark_threaded();
    index = self.temp_slot(mir_int());
    b.store(index, b.const_int(0, mir_int()));
    spawn_head = fn.new_block("ffor.spawn");
    spawn_body = fn.new_block("ffor.spawn.body");
    spawn_inline = fn.new_block("ffor.spawn.inline");
    spawn_next = fn.new_block("ffor.spawn.next");
    join_start = fn.new_block("ffor.join");
    b.branch(spawn_head);
    b.position(spawn_head);
    at = b.load(index, mir_int());
    b.cond_branch(
        b.compare("lt", at, b.load(threads, mir_int())), spawn_body, join_start
    );
    b.position(spawn_body);
    at = b.load(index, mir_int());
    low = b.binary("mul", at, b.load(span, mir_int()));
    high = b.binary("add", low, b.load(span, mir_int()));
    high = b.select(b.compare("gt", high, count), count, high);
    task = self.spill(
        b.ref_cast(
            self.runtime_value(
                "__jac_rt_task_new",
                [b.const_int(FLOW_TASK_PARTIALS + len(reductions), mir_int())]
            ),
            mir_ref(),
            True
        )
    );
    self.runtime("__jac_rt_retain", [task]);
    self.runtime("__jac_rt_retain", [task]);
    base = self.address_of(task);
    self.task_store(base, TASK_ARGS, ctx_base);
    self.task_store(base, TASK_ARGS + 8, low);
    self.task_store(base, TASK_ARGS + 16, high);
    self.emit_value(
        MirOp.MEM_STORE,
        mir_none(),
        [
            b.binary(
                "add",
                b.load(slots, mir_int()),
                b.binary("mul", at, b.const_int(8, mir_int()))
            ),
            base
        ]
    );
    launcher = self.emit_value(
        MirOp.FN_ADDR, mir_c_fn([i8p], i8p), [], callee=body_symbol
    );
    handle = self.emit_value(MirOp.PTR_CAST, i8p, [task]);
    self.task_store(base, TASK_STATE, b.const_int(1, mir_int()));
    created = b.call(
        "pthread_create",
        [
            self.emit_value(
                MirOp.PTR_CAST,
                i8p,
                [b.binary("add", base, b.const_int(TASK_THREAD, mir_int()))]
            ),
            self.emit_value(MirOp.PTR_NULL, i8p, []),
            self.emit_value(MirOp.PTR_CAST, i8p, [launcher]),
            handle
        ],
        mir_int(32, True, True)
    );
    if created is None {
        raise MirRefused(mir_refusal("statement", "flow for spawn", nd));
    }
    b.cond_branch(
        b.compare("eq", created, b.const_int(0, created.type)), spawn_next, spawn_inline
    );
    b.position(spawn_inline);
    self.task_store(base, TASK_STATE, b.const_int(0, mir_int()));
    b.call(body_symbol, [handle], i8p);
    b.branch(spawn_next);
    b.position(spawn_next);
    b.store(index, b.binary("add", b.load(index, mir_int()), one));
    b.branch(spawn_head);
    b.position(join_start);
    b.store(index, b.const_int(0, mir_int()));
    join_head = fn.new_block("ffor.join.head");
    join_body = fn.new_block("ffor.join.body");
    join_wait = fn.new_block("ffor.join.wait");
    join_next = fn.new_block("ffor.join.next");
    settle_start = fn.new_block("ffor.settle");
    b.branch(join_head);
    b.position(join_head);
    b.cond_branch(
        b.compare("lt", b.load(index, mir_int()), b.load(threads, mir_int())),
        join_body,
        settle_start
    );
    b.position(join_body);
    held = self.emit_value(
        MirOp.MEM_LOAD,
        mir_int(),
        [
            b.binary(
                "add",
                b.load(slots, mir_int()),
                b.binary("mul", b.load(index, mir_int()), b.const_int(8, mir_int()))
            )
        ]
    );
    b.cond_branch(
        b.compare(
            "eq",
            self.emit_value(
                MirOp.MEM_LOAD,
                mir_int(),
                [b.binary("add", held, b.const_int(TASK_STATE, mir_int()))]
            ),
            one
        ),
        join_wait,
        join_next
    );
    b.position(join_wait);
    b.call(
        "pthread_join",
        [
            self.emit_value(
                MirOp.MEM_LOAD,
                mir_int(),
                [b.binary("add", held, b.const_int(TASK_THREAD, mir_int()))]
            ),
            self.emit_value(MirOp.PTR_NULL, i8p, [])
        ],
        mir_int(32, True, True)
    );
    b.branch(join_next);
    b.position(join_next);
    b.store(index, b.binary("add", b.load(index, mir_int()), one));
    b.branch(join_head);
    b.position(settle_start);
    partials: list[MirValue] = [];
    for (name, op) in reductions {
        acc = self.temp_slot(mir_int());
        b.store(acc, self.coerce(self.lower_name(name), mir_int(), name));
        partials.append(acc);
    }
    b.store(index, b.const_int(0, mir_int()));
    settle_head = fn.new_block("ffor.settle.head");
    settle_body = fn.new_block("ffor.settle.body");
    done = fn.new_block("ffor.done");
    b.branch(settle_head);
    b.position(settle_head);
    b.cond_branch(
        b.compare("lt", b.load(index, mir_int()), b.load(threads, mir_int())),
        settle_body,
        done
    );
    b.position(settle_body);
    held = self.emit_value(
        MirOp.MEM_LOAD,
        mir_int(),
        [
            b.binary(
                "add",
                b.load(slots, mir_int()),
                b.binary("mul", b.load(index, mir_int()), b.const_int(8, mir_int()))
            )
        ]
    );
    for (position, ((_, op), acc)) in enumerate(zip(reductions, partials)) {
        part = self.emit_value(
            MirOp.MEM_LOAD,
            mir_int(),
            [
                b.binary(
                    "add",
                    held,
                    b.const_int(
                        TASK_ARGS + (FLOW_TASK_PARTIALS + position) * 8, mir_int()
                    )
                )
            ]
        );
        current = b.load(acc, mir_int());
        if op == "min" {
            b.store(acc, b.select(b.compare("lt", part, current), part, current));
        } elif op == "max" {
            b.store(acc, b.select(b.compare("gt", part, current), part, current));
        } else {
            b.store(acc, self.arith("PLUS", current, part, nd));
        }
    }
    self.runtime_value("__jac_rt_task_result", [b.ref_cast(held, mir_ref(), False)]);
    self.runtime("__jac_rt_release", [b.ref_cast(held, mir_ref(), False)]);
    b.store(index, b.binary("add", b.load(index, mir_int()), one));
    b.branch(settle_head);
    b.position(done);
    for ((name, _), acc) in zip(reductions, partials) {
        self.store_name(name, b.load(acc, mir_int()));
    }
    b.call(
        "free",
        [self.emit_value(MirOp.PTR_CAST, i8p, [b.load(slots, mir_int())])],
        mir_none()
    );
    self.runtime(
        "__jac_rt_elem_release",
        [
            self.emit_value(
                MirOp.MEM_LOAD,
                mir_int(),
                [b.binary("add", ctx_base, b.const_int(TASK_ARGS, mir_int()))]
            ),
            b.const_int(list_kind, mir_int())
        ]
    );
    for (index_at, value_type) in enumerate(capture_types) {
        self.runtime(
            "__jac_rt_elem_release",
            [
                self.emit_value(
                    MirOp.MEM_LOAD,
                    mir_int(),
                    [
                        b.binary(
                            "add",
                            ctx_base,
                            b.const_int(
                                TASK_ARGS + (FLOW_CTX_CAPTURES + index_at) * 8,
                                mir_int()
                            )
                        )
                    ]
                ),
                b.const_int(self.elem_kind(value_type, nd), mir_int())
            ]
        );
    }
    self.runtime("__jac_rt_release", [b.ref_cast(ctx_base, mir_ref(), False)]);
    return True;
}

impl MirLowering.flow_body(
    nd: uni.InForStmt,
    list_type: MirType,
    chunked: bool,
    captures: list[uni.Name],
    capture_types: list[MirType],
    reductions: list[tuple[uni.Name, str]]
) -> str {
    i8p = mir_c_ptr(mir_int(8, False));
    self.flow_sites += 1;
    symbol = f"{self.mir.prefix}.__flow_for{self.flow_sites}";
    fn = MirFunction(
        name=f"__flow_for{self.flow_sites}", symbol=symbol, ret=i8p, linkage="internal"
    );
    param = fn.new_value(i8p, "task");
    fn.params.append(MirParam(name="task", value=param));
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=fn.new_block("entry")));
    try {
        b = self.builder();
        base = self.emit_value(MirOp.PTR_INT, mir_int(), [param]);
        ctx = self.emit_value(
            MirOp.MEM_LOAD,
            mir_int(),
            [b.binary("add", base, b.const_int(TASK_ARGS, mir_int()))]
        );
        (frame, dispatch) = self.guard_open();
        list_kind = self.elem_kind(list_type, nd);
        lst = self.spill(
            self.element_from_bits(
                self.runtime_value(
                    "__jac_rt_elem_share",
                    [
                        self.emit_value(
                            MirOp.MEM_LOAD,
                            mir_int(),
                            [b.binary("add", ctx, b.const_int(TASK_ARGS, mir_int()))]
                        ),
                        b.const_int(list_kind, mir_int())
                    ]
                ),
                list_type
            )
        );
        width = self.emit_value(
            MirOp.MEM_LOAD,
            mir_int(),
            [b.binary("add", ctx, b.const_int(TASK_ARGS + 8, mir_int()))]
        );
        for (index, (name, value_type)) in enumerate(zip(captures, capture_types)) {
            kind = self.elem_kind(value_type, nd);
            value = self.element_from_bits(
                self.runtime_value(
                    "__jac_rt_elem_share",
                    [
                        self.emit_value(
                            MirOp.MEM_LOAD,
                            mir_int(),
                            [
                                b.binary(
                                    "add",
                                    ctx,
                                    b.const_int(
                                        TASK_ARGS + (FLOW_CTX_CAPTURES + index) * 8,
                                        mir_int()
                                    )
                                )
                            ]
                        ),
                        b.const_int(kind, mir_int())
                    ]
                ),
                value_type
            );
            if name.value == "self"
                and saved is not None
                and saved.self_value is not None {
                self.st().self_value = self.spill(value);
                continue;
            }
            b.store(self.local_slot(name.sym, name), value);
        }
        for (name, op) in reductions {
            identity = 0;
            if op == "min" {
                identity = 9223372036854775807;
            } elif op == "max" {
                identity = -9223372036854775808;
            }
            b.store(self.local_slot(name.sym, name), b.const_int(identity, mir_int()));
        }
        loop_target = nd.target;
        if not isinstance(loop_target, uni.Name) {
            raise MirRefused(mir_refusal("statement", "flow for target", nd));
        }
        self.local_slot(loop_target.sym, loop_target);
        for stmt in nd.body {
            for inner in self.names_within(stmt) {
                held = inner.sym;
                if held is not None
                    and held.decl is not None
                    and held.decl.is_within(nd)
                    and id(held) not in self.st().locals {
                    self.local_slot(held, inner);
                }
            }
        }
        block = self.view_block() if chunked else None;
        current = self.temp_slot(mir_int());
        b.store(
            current,
            self.emit_value(
                MirOp.MEM_LOAD,
                mir_int(),
                [b.binary("add", base, b.const_int(TASK_ARGS + 8, mir_int()))]
            )
        );
        limit = self.emit_value(
            MirOp.MEM_LOAD,
            mir_int(),
            [b.binary("add", base, b.const_int(TASK_ARGS + 16, mir_int()))]
        );
        head = fn.new_block("ffor.head");
        body = fn.new_block("ffor.body");
        advance = fn.new_block("ffor.step");
        after = fn.new_block("ffor.exit");
        b.branch(head);
        b.position(head);
        b.cond_branch(b.compare("lt", b.load(current, mir_int()), limit), body, after);
        b.position(body);
        at = b.load(current, mir_int());
        if block is not None {
            self.store_name(loop_target, self.chunk_view(block, lst, at, width));
        } else {
            self.store_name(loop_target, self.list_read(lst, at));
        }
        self.st().loops.append(MirLoopTarget(head=advance, after=after));
        self.lower_body(nd.body);
        self.st().loops.pop();
        if not self.builder().block.terminated() {
            self.builder().branch(advance);
        }
        b.position(advance);
        b.store(
            current,
            b.binary("add", b.load(current, mir_int()), b.const_int(1, mir_int()))
        );
        b.branch(head);
        b.position(after);
        for (position, (name, _)) in enumerate(reductions) {
            self.task_store(
                base,
                TASK_ARGS + (FLOW_TASK_PARTIALS + position) * 8,
                b.load(self.st().locals[id(name.sym)], mir_int())
            );
        }
        self.runtime("__jac_rt_exc_pop", [frame]);
        self.runtime("__jac_rt_release", [b.ref_cast(param, mir_ref(), False)]);
        b.ret(self.emit_value(MirOp.PTR_NULL, i8p, []));
        b.position(dispatch);
        self.runtime("__jac_rt_exc_pop", [frame]);
        (origin, type_id, message) = self.guard_caught(frame);
        self.task_store(base, TASK_ERROR, b.convert(type_id, mir_int()));
        self.task_store(
            base, TASK_MESSAGE, self.emit_value(MirOp.PTR_INT, mir_int(), [message])
        );
        self.task_store(
            base, TASK_ORIGIN, self.emit_value(MirOp.PTR_INT, mir_int(), [origin])
        );
        self.runtime("__jac_rt_release", [b.ref_cast(param, mir_ref(), False)]);
        b.ret(self.emit_value(MirOp.PTR_NULL, i8p, []));
        for blk in fn.blocks {
            if not blk.terminated() {
                self.builder().position(blk);
                self.builder().unreachable();
            }
        }
    } finally {
        self.state = saved;
    }
    self.nested.append(fn);
    return symbol;
}
