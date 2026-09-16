import copy;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.backends.native.llvm { ir }

obj NativeDependencyInspection {
    has host: any,
        originals: list[any],
        clones: dict[any, any] = {},
        effects: dict[any, bool] = {},
        externals: dict[any, any] = {},
        known: dict[any, dict[any, int]] = {},
        user_types: set[any] = set(),
        building: set[any] = set();

    def postinit {
        gen = self.host.gen;
        if gen?.module is not None and not gen.prog.options.kernel_unit {
            for arch in gen.module.get_all_sub_nodes(uni.Archetype) {
                if arch.name is not None and arch.name.value in gen.struct_types {
                    self.user_types.add(gen.struct_types[arch.name.value]);
                }
            }
        }
    }

    def user_field(ptr: any) -> bool {
        while getattr(ptr, "opname", "") in ("getelementptr", "bitcast") {
            source = ptr.operands[0];
            if source.type.pointee in self.user_types {
                return True;
            }
            ptr = source;
        }
        return False;
    }

    def callbacks -> dict[str, any] {
        host = self.host;
        gen = host.gen;
        gen._emit_list_helpers("i64", ir.IntType(64));
        module = gen.llvm_module;
        i64 = ir.IntType(64);
        i32 = ir.IntType(32);
        i8p = ir.IntType(8).as_pointer();
        void = ir.VoidType();
        zero = ir.Constant(i64, 0);
        one = ir.Constant(i64, 1);
        fields = gen.struct_field_types["OspRuntime"];
        fn = ir.Function(
            module, fields["inspect_task"].pointee, name="__jac_spec_inspect_task"
        );
        fn.linkage = "private";
        b = ir.IRBuilder(fn.append_basic_block("entry"));
        run = fn.append_basic_block("run");
        trial = fn.append_basic_block("trial");
        collect = fn.append_basic_block("collect");
        check = fn.append_basic_block("check");
        item_bb = fn.append_basic_block("item");
        read_bb = fn.append_basic_block("read");
        write_check = fn.append_basic_block("write.check");
        write_bb = fn.append_basic_block("write");
        advance = fn.append_basic_block("advance");
        cleanup = fn.append_basic_block("cleanup");
        done = fn.append_basic_block("done");
        task = fn.args[0];
        clock = host.raw("clock_gettime", i32, [i32, i8p]);
        stamp = b.alloca(ir.ArrayType(i64, 2));
        b.call(clock, [ir.Constant(i32, 1), b.bitcast(stamp, i8p)]);
        seconds = b.gep(stamp, [ir.Constant(i32, 0), ir.Constant(i32, 0)]);
        nanos = b.gep(stamp, [ir.Constant(i32, 0), ir.Constant(i32, 1)]);
        started = b.add(
            b.mul(b.load(seconds), ir.Constant(i64, 1000000000)), b.load(nanos)
        );
        b.call(gen.func_symtab["osp_access_reset"], [task]);
        access = b.load(host.field(b, task, "OspTask", "access"));
        if not isinstance(access.type, ir.PointerType) {
            access = b.extract_value(access, 1);
        }
        access = b.bitcast(access, gen.struct_types["OspAccess"].as_pointer());
        ignored = b.load(host.field(b, task, "OspTask", "ignores"));
        ctx = b.call(
            host.raw("__jac_spec_new", i64, [i64]), [b.ptrtoint(ignored, i64)]
        );
        current_item = b.alloca(i64);
        top = b.ptrtoint(b.alloca(i64), i64);
        b.atomic_rmw("add", module.globals["__jac_spec_inspections"], one, "monotonic");
        b.cbranch(b.icmp_unsigned("!=", ctx, zero), run, done);
        b = ir.IRBuilder(run);
        b.store(top, host.memory(b, ctx, 64));
        b.store(ir.Constant(i64, 5), host.memory(b, ctx, 56));
        b.call(module.globals["__jac_spec_tls_set"], [ctx]);
        bound = fn.append_basic_block("bound");
        current = b.call(module.globals["__jac_spec_tls_get"], []);
        b.cbranch(b.icmp_unsigned("==", current, ctx), bound, cleanup);
        b = ir.IRBuilder(bound);
        sj = host.raw("_setjmp", i32, [i8p]);
        sj.attributes.add("returns_twice");
        jumped = b.call(sj, [b.inttoptr(b.add(ctx, ir.Constant(i64, 96)), i8p)]);
        b.cbranch(b.icmp_signed("==", jumped, ir.Constant(i32, 0)), trial, collect);
        b = ir.IRBuilder(trial);
        slot = b.load(host.field(b, task, "OspTask", "slot"));
        addr = b.load(host.field(b, slot, "Slot", "inspect"));
        invoke = fn.append_basic_block("invoke");
        missing = fn.append_basic_block("missing");
        b.cbranch(b.icmp_unsigned("!=", addr, zero), invoke, missing);
        b = ir.IRBuilder(missing);
        b.call(host.raw("__jac_inspect_unknown", void, []), []);
        b.branch(collect);
        b = ir.IRBuilder(invoke);
        typ = gen.struct_field_types["Slot"]["fn"];
        b.call(
            b.inttoptr(addr, typ),
            [
                b.load(host.field(b, task, "OspTask", "a")),
                b.load(host.field(b, task, "OspTask", "b"))
            ]
        );
        b.branch(collect);
        b = ir.IRBuilder(collect);
        b.call(module.globals["__jac_spec_tls_set"], [zero]);
        for (field, offset) in [("unknown", 1136), ("serial", 1144)] {
            value = b.icmp_unsigned("!=", b.load(host.memory(b, ctx, offset)), zero);
            ptr = host.field(b, access, "OspAccess", field);
            b.store(host.cast(b, value, ptr.type.pointee), ptr);
        }
        b.atomic_rmw(
            "add",
            module.globals["__jac_spec_inspection_steps"],
            b.load(host.memory(b, ctx, 48)),
            "monotonic"
        );
        b.store(b.load(host.memory(b, ctx, 1128)), current_item);
        b.branch(check);
        b = ir.IRBuilder(check);
        item = b.load(current_item);
        b.cbranch(b.icmp_unsigned("!=", item, zero), item_bb, cleanup);
        b = ir.IRBuilder(item_bb);
        flags = b.load(host.memory(b, item, 8));
        owner = b.load(host.memory(b, item, 0));
        b.cbranch(
            b.icmp_unsigned("!=", b.and_(flags, one), zero), read_bb, write_check
        );
        b = ir.IRBuilder(read_bb);
        reads = b.load(host.field(b, access, "OspAccess", "reads"));
        append = gen.list_helpers["i64"]["append"];
        b.call(append, [reads, owner]);
        b.branch(write_check);
        b = ir.IRBuilder(write_check);
        b.cbranch(
            b.icmp_unsigned("!=", b.and_(flags, ir.Constant(i64, 2)), zero),
            write_bb,
            advance
        );
        b = ir.IRBuilder(write_bb);
        writes = b.load(host.field(b, access, "OspAccess", "writes"));
        b.call(append, [writes, owner]);
        b.branch(advance);
        b = ir.IRBuilder(advance);
        b.store(b.load(host.memory(b, item, 16)), current_item);
        b.branch(check);
        b = ir.IRBuilder(cleanup);
        b.call(module.globals["__jac_spec_tls_set"], [zero]);
        b.call(host.raw("__jac_spec_drop", void, [i64]), [ctx]);
        b.branch(done);
        b = ir.IRBuilder(done);
        b.call(clock, [ir.Constant(i32, 1), b.bitcast(stamp, i8p)]);
        elapsed = b.sub(
            b.add(b.mul(b.load(seconds), ir.Constant(i64, 1000000000)), b.load(nanos)),
            started
        );
        b.atomic_rmw(
            "add", module.globals["__jac_spec_inspection_ns"], elapsed, "monotonic"
        );
        unknown = b.load(host.field(b, access, "OspAccess", "unknown"));
        b.atomic_rmw(
            "add",
            module.globals["__jac_spec_unknown"],
            host.word(b, unknown),
            "monotonic"
        );
        host.return_none(b);
        defer = ir.Function(
            module, fields["defer_tasks"].pointee, name="__jac_spec_defer_tasks"
        );
        defer.linkage = "private";
        b = ir.IRBuilder(defer.append_basic_block("entry"));
        b.atomic_rmw(
            "add", module.globals["__jac_spec_deferrals"], defer.args[0], "monotonic"
        );
        host.return_none(b);
        return {"inspect_task": fn, "defer_tasks": defer};
    }

    def ignored(name: str) -> bool {
        return name
            in (
                "__rc_retain",
                "__rc_release",
                "__rc_release_impl",
                "__rc_release_simple",
                "osp_report",
                "osp_skip_rest",
                "osp_disengage"
            )
            or name.startswith("__jac_region_");
    }

    def base(value: any) -> any {
        seen: set[any] = set();
        while value not in seen {
            seen.add(value);
            if getattr(value, "opname", "") not in ("getelementptr", "bitcast") {
                break;
            }
            value = value.operands[0];
        }
        return value;
    }

    def shared(value: any, stores: dict[any, list[any]], seen: set[any]) -> bool {
        value = self.base(value);
        if value in seen {
            return False;
        }
        seen = seen | {value};
        if isinstance(value, ir.Argument) {
            return True;
        }
        op = getattr(value, "opname", "");
        if op in ("inttoptr", "ptrtoint", "extractvalue") {
            return self.shared(value.operands[0], stores, seen);
        }
        if op == "load" {
            ptr = self.base(value.operands[0]);
            if ptr in stores {
                return all(
                    self.shared(s.operands[0], stores, seen) for s in stores[ptr]
                );
            }
            return self.shared(ptr, stores, seen);
        }
        if op == "phi" {
            return all(self.shared(v, stores, seen) for (v, block) in value.incomings);
        }
        return False;
    }

    def has_effects(fn: any, active: set[any]) -> bool {
        if fn in self.effects {
            return self.effects[fn];
        }
        if fn in active or fn not in self.originals or not fn.blocks {
            return True;
        }
        active = active | {fn};
        for block in fn.blocks {
            for inst in block.instructions {
                if inst.opname in ("load", "store") {
                    ptr = inst.operands[0 if inst.opname == "load" else 1];
                    if not self.host.local(ptr) {
                        self.effects[fn] = True;
                        return True;
                    }
                } elif inst.opname == "call" {
                    callee = inst.callee;
                    name = callee.name if isinstance(callee, ir.Function) else "";
                    if self.ignored(name)
                        or name.startswith(
                            ("llvm.", "__jac_exc_", "__jac_raise", "__jac_throw")
                        ) {
                        continue;
                    }
                    if self.has_effects(callee, active) {
                        self.effects[fn] = True;
                        return True;
                    }
                }
            }
        }
        self.effects[fn] = False;
        return False;
    }

    def duplicate(fn: any, name: str) -> any {
        module = self.host.gen.llvm_module;
        memo = {
            id(g): g
            for g in module.globals.values()
            if g is not fn
        };
        memo[id(module)] = module;
        memo[id(module.context)] = module.context;
        memo[id(fn.function_type)] = fn.function_type;
        for block in fn.blocks {
            for inst in block.instructions {
                memo[id(inst.type)] = inst.type;
            }
        }
        clone = copy.deepcopy(fn, memo);
        prior = module.globals.get(name);
        if prior is not None {
            clone._name = name;
        } else {
            clone.name = name;
        }
        clone.linkage = "private";
        for key in list(vars(clone)) {
            if "cached" in key {
                delattr(clone, key);
            }
        }
        if prior is not None {
            for f in list(module.functions) {
                for block in f.blocks {
                    for inst in block.instructions {
                        inst.replace_usage(prior, clone);
                    }
                }
            }
        }
        module.globals[name] = clone;
        for block in clone.blocks {
            for inst in block.instructions {
                inst.replace_usage(clone, fn);
            }
        }
        return clone;
    }

    def unknown(b: any, required: bool) {
        b.call(self.host.raw("__jac_inspect_unknown", ir.VoidType(), []), []);
        if required {
            for (owner, flags) in self.known.get(b.block.parent, {}).items() {
                b.call(
                    self.host.raw(
                        "__jac_inspect_access",
                        ir.IntType(64),
                        [ir.IntType(64), ir.IntType(64)]
                    ),
                    [self.host.word(b, owner), ir.Constant(ir.IntType(64), flags)]
                );
            }
            b.call(self.host.raw("__jac_spec_abort", ir.VoidType(), []), []);
        }
    }

    def argument_owners(
        value: any, stores: dict[any, list[any]], seen: set[any]
    ) -> set[any] {
        value = self.base(value);
        if value in seen {
            return set();
        }
        seen = seen | {value};
        if isinstance(value, ir.Argument) {
            return {value};
        }
        op = getattr(value, "opname", "");
        if op in ("inttoptr", "ptrtoint") {
            return self.argument_owners(value.operands[0], stores, seen);
        }
        sources: list[any] = [];
        if op == "load" and self.host.local(value.operands[0]) {
            sources = [
                store.operands[0]
                for store in stores.get(self.base(value.operands[0]), [])
            ];
        } elif op == "phi" {
            sources = [source for (source, block) in value.incomings];
        }
        owners: set[any] = set();
        for source in sources {
            owners.update(self.argument_owners(source, stores, seen));
        }
        return owners;
    }

    def external(callee: any, required: bool) -> any {
        key = (callee, required);
        if key in self.externals {
            return self.externals[key];
        }
        host = self.host;
        i64 = ir.IntType(64);
        wrapper = ir.Function(
            host.gen.llvm_module,
            callee.function_type,
            name=f"__jac_inspect_external_{len(self.externals)}"
        );
        wrapper.linkage = "private";
        self.externals[key] = wrapper;
        b = ir.IRBuilder(wrapper.append_basic_block("entry"));
        found = wrapper.append_basic_block("found");
        missing = wrapper.append_basic_block("missing");
        address = b.call(
            host.raw("__jac_inspect_resolve", i64, [i64]), [host.word(b, callee)]
        );
        b.cbranch(b.icmp_unsigned("!=", address, ir.Constant(i64, 0)), found, missing);
        b = ir.IRBuilder(missing);
        self.unknown(b, required);
        host.return_none(b);
        b = ir.IRBuilder(found);
        result = b.call(b.inttoptr(address, callee.type), list(wrapper.args));
        if isinstance(result.type, ir.VoidType) {
            b.ret_void();
        } else {
            b.ret(result);
        }
        return wrapper;
    }

    def generate(fn: any, result_needed: bool = True) -> any {
        key = (fn, result_needed);
        if key in self.clones {
            return self.clones[key];
        }
        name = ("__jac_inspect_" if result_needed else "__jac_inspect_access_")
            + fn.name;
        clone = self.duplicate(fn, name);
        self.clones[key] = clone;
        self.building.add(fn);
        try {
            self.transform(fn, clone, result_needed);
        } except Exception {
            clone.blocks.clear();
            b = ir.IRBuilder(clone.append_basic_block("unknown"));
            self.unknown(b, True);
            self.host.return_none(b);
        } finally {
            self.building.remove(fn);
        }
        return clone;
    }

    def transform(original: any, fn: any, result_needed: bool) {
        host = self.host;
        i64 = ir.IntType(64);
        void = ir.VoidType();
        if host.boundary(original.name) {
            fn.blocks.clear();
            b = ir.IRBuilder(fn.append_basic_block("entry"));
            if host.topology(original.name) {
                b.call(host.raw("__jac_spec_topology", void, []), []);
            }
            self.unknown(b, True);
            host.return_none(b);
            return;
        }
        if not result_needed and not self.has_effects(original, set()) {
            fn.blocks.clear();
            host.return_none(ir.IRBuilder(fn.append_basic_block("entry")));
            return;
        }
        instructions = [inst for block in fn.blocks for inst in block.instructions];
        needed: set[any] = set();
        roots: set[any] = set();
        local_stores: dict[any, list[any]] = {};
        is_entry = original.name in host.gen.osp_thunk_funcs;
        omitted: set[any] = set();
        for inst in instructions {
            if inst.opname == "store" and host.local(inst.operands[1]) {
                base = self.base(inst.operands[1]);
                if base not in local_stores {
                    local_stores[base] = [];
                }
                local_stores[base].append(inst);
            }
        }
        self.known[fn] = {};
        for inst in instructions {
            if inst.opname in ("load", "store") {
                ptr = inst.operands[0 if inst.opname == "load" else 1];
                if not host.local(ptr) {
                    for owner in self.argument_owners(ptr, local_stores, set()) {
                        self.known[fn][owner] = self.known[fn].get(owner, 0)
                            | (1 if inst.opname == "load" else 2);
                    }
                }
            }
        }
        for inst in instructions {
            op = inst.opname;
            if op == "store" {
                ptr = inst.operands[1];
                base = self.base(ptr);
                if host.local(ptr) {
                    continue;
                } else {
                    roots.add(inst);
                    needed.add(ptr);
                    if (is_entry and self.shared(ptr, local_stores, set()))
                        or self.user_field(ptr) {
                        omitted.add(inst);
                    } else {
                        needed.add(inst.operands[0]);
                    }
                }
            } elif op == "load" and not host.local(inst.operands[0]) {
                roots.add(inst);
                needed.add(inst.operands[0]);
            } elif op == "call" {
                callee = inst.callee;
                name = callee.name if isinstance(callee, ir.Function) else "";
                if not self.ignored(name)
                    and name != "osp_visit"
                    and self.has_effects(callee, set()) {
                    roots.add(inst);
                    needed.add(callee);
                    needed.update(inst.args);
                }
            } elif op in ("br", "switch", "indirectbr") {
                roots.add(inst);
                needed.update(inst.operands);
            } elif op in ("ret", "ret void") {
                roots.add(inst);
                if result_needed {
                    needed.update(inst.operands);
                }
            } elif op == "unreachable" {
                roots.add(inst);
            } elif op
                in ("atomicrmw", "cmpxchg", "load atomic", "store atomic", "fence") {
                roots.add(inst);
                needed.update(inst.operands);
            }
        }
        pending = list(needed);
        while pending {
            value = pending.pop();
            if not isinstance(value, ir.Instruction) {
                continue;
            }
            operands = list(value.operands);
            if isinstance(value, ir.PhiInstr) {
                operands += [v for (v, block) in value.incomings];
            }
            if value.opname == "load" and host.local(value.operands[0]) {
                for store in local_stores.get(self.base(value.operands[0]), []) {
                    roots.add(store);
                    operands.extend(store.operands);
                }
            }
            if isinstance(value.type, ir.PointerType) {
                for store in local_stores.get(self.base(value), []) {
                    roots.add(store);
                    operands.extend(store.operands);
                }
            }
            for operand in operands {
                if operand not in needed {
                    needed.add(operand);
                    pending.append(operand);
                }
            }
        }
        for block in fn.blocks {
            for inst in list(block.instructions) {
                b = ir.IRBuilder(block);
                b.position_before(inst);
                if inst not in roots and inst not in needed {
                    block.instructions.remove(inst);
                    continue;
                }
                op = inst.opname;
                if op in ("load", "store") {
                    ptr = inst.operands[0 if op == "load" else 1];
                    if host.local(ptr) {
                        continue;
                    }
                    owner = host.word(b, self.base(ptr));
                    if (op == "load" and inst not in needed) or inst in omitted {
                        b.call(
                            host.raw("__jac_inspect_access", i64, [i64, i64]),
                            [owner, ir.Constant(i64, 1 if op == "load" else 6)]
                        );
                        block.instructions.remove(inst);
                        continue;
                    }
                    typ = inst.type if op == "load" else inst.operands[0].type;
                    alloc = ir.IRBuilder(fn.blocks[0]);
                    alloc.position_at_start(fn.blocks[0]);
                    temp = alloc.alloca(typ, name="inspect.value");
                    b.position_before(inst);
                    size = b.ptrtoint(
                        b.gep(
                            ir.Constant(typ.as_pointer(), None), [ir.Constant(i64, 1)]
                        ),
                        i64
                    );
                    if op == "store" {
                        b.store(inst.operands[0], temp);
                    }
                    target = host.raw(
                        "__jac_inspect_" + ("read" if op == "load" else "write"),
                        void,
                        [i64, i64, i64, i64]
                    );
                    b.call(
                        target, [owner, host.word(b, ptr), size, host.word(b, temp)]
                    );
                    if op == "load" {
                        inst.operands = [temp];
                    } else {
                        block.instructions.remove(inst);
                    }
                } elif op == "call" {
                    callee = inst.callee;
                    name = callee.name if isinstance(callee, ir.Function) else "";
                    replacement = None;
                    required = inst in needed;
                    if self.ignored(name) {
                        replacement = host.trial_region(callee);
                    } elif name == "osp_visit" {
                        replacement = host.adapter(
                            callee,
                            "__jac_spec_visit_possible",
                            ir.IntType(1),
                            [i64, i64]
                        );
                    } elif name == "__rc_alloc"
                        or name.startswith("__jac_spec_adapter_") {
                        continue;
                    } elif name
                        in (
                            "memcpy",
                            "memmove",
                            "memset",
                            "strlen",
                            "strcmp",
                            "strncmp",
                            "memcmp",
                            "calloc"
                        ) {
                        runtime = {
                            "memcpy": "copy",
                            "memmove": "copy",
                            "memset": "set"
                        }.get(
                            name, name
                        );
                        types = [i64 for _ in callee.args];
                        if name == "memset" {
                            types[1] = ir.IntType(32);
                        }
                        result = ir.IntType(32)
                            if name in ("strcmp", "strncmp", "memcmp")
                            else i64;
                        replacement = host.adapter(
                            callee, "__jac_inspect_" + runtime, result, types
                        );
                    } elif callee in self.originals
                        and callee.blocks
                        and callee not in self.building {
                        replacement = self.generate(callee, required);
                    } elif name.startswith("llvm.")
                        and not name.startswith(
                            (
                                "llvm.mem",
                                "llvm.va",
                                "llvm.stack",
                                "llvm.read",
                                "llvm.write",
                                "llvm.trap",
                                "llvm.debugtrap"
                            )
                        ) {
                        continue;
                    } elif isinstance(callee, ir.Function) and not callee.blocks {
                        if required {
                            for (owner, flags) in self.known[fn].items() {
                                b.call(
                                    host.raw("__jac_inspect_access", i64, [i64, i64]),
                                    [host.word(b, owner), ir.Constant(i64, flags)]
                                );
                            }
                        }
                        replacement = self.external(callee, required);
                    } elif not isinstance(callee, (ir.Function, ir.InlineAsm)) {
                        if original.name != "OspGraph.filter_handles" {
                            self.unknown(b, False);
                        }
                        address = b.call(
                            host.raw("__jac_inspect_resolve", i64, [i64]),
                            [host.word(b, callee)]
                        );
                        missing = b.icmp_unsigned("==", address, ir.Constant(i64, 0));
                        b.call(
                            host.raw("__jac_spec_guard", void, [ir.IntType(1)]),
                            [missing]
                        );
                        replacement = b.inttoptr(address, callee.type);
                    } else {
                        self.unknown(b, required);
                        if required {
                            for user in instructions {
                                user.replace_usage(inst, ir.Constant(inst.type, None));
                            }
                        }
                        block.instructions.remove(inst);
                        continue;
                    }
                    inst.operands = [replacement] + list(inst.args);
                } elif op == "ret" and not result_needed and inst.operands {
                    inst.operands = [ir.Constant(inst.operands[0].type, None)];
                } elif op in ("sdiv", "udiv", "srem", "urem") {
                    bad = b.icmp_unsigned(
                        "==", inst.operands[1], ir.Constant(inst.operands[1].type, 0)
                    );
                    if op in ("sdiv", "srem") {
                        typ = inst.operands[0].type;
                        bad = b.or_(
                            bad,
                            b.and_(
                                b.icmp_signed(
                                    "==",
                                    inst.operands[0],
                                    ir.Constant(typ, -(1 << (typ.width - 1)))
                                ),
                                b.icmp_signed(
                                    "==", inst.operands[1], ir.Constant(typ, -1)
                                )
                            )
                        );
                    }
                    b.call(host.raw("__jac_spec_guard", void, [ir.IntType(1)]), [bad]);
                } elif op
                    in (
                        "atomicrmw",
                        "cmpxchg",
                        "load atomic",
                        "store atomic",
                        "fence",
                        "indirectbr"
                    ) {
                    self.unknown(b, True);
                }
            }
            first = next(
                (
                    x
                    for x in block.instructions
                    if x.opname != "phi"
                ),
                None
            );
            if first is not None {
                b = ir.IRBuilder(block);
                b.position_before(first);
                b.call(host.raw("__jac_spec_tick", void, []), []);
            }
        }
        for block in fn.blocks {
            for inst in block.instructions {
                inst._clear_string_cache();
            }
        }
    }
}
