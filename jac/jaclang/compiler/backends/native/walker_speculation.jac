import copy;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.backends.native.llvm { ir }

def walker_speculation_enabled(options: any, triple: str) -> bool {
    return options.aot_mode
        and options.na_gc_mode == "rc"
        and options.walker_speculation == "auto"
        and not options.rc_debug_codegen
        and "linux" in triple
        and (
            triple.startswith("x86_64")
            or triple.startswith("aarch64")
            or triple.startswith("arm64")
        );
}

obj NativeWalkerSpeculation {
    has gen: any,
        clones: dict[any, any] = {},
        wrappers: dict[any, any] = {};

    def raw(name: str, result: any, args: list[any]) -> any {
        module = self.gen.llvm_module;
        if name in module.globals {
            return module.globals[name];
        }
        return ir.Function(module, ir.FunctionType(result, args), name=name);
    }

    def word(b: any, value: any) -> any {
        i64 = ir.IntType(64);
        if isinstance(value.type, ir.PointerType) {
            return b.ptrtoint(value, i64);
        }
        if value.type == i64 {
            return value;
        }
        return b.zext(value, i64);
    }

    def cast(b: any, value: any, typ: any) -> any {
        if value.type == typ {
            return value;
        }
        if isinstance(typ, ir.PointerType) {
            return b.inttoptr(value, typ);
        }
        if value.type.width < typ.width {
            return b.zext(value, typ);
        }
        return b.trunc(value, typ);
    }

    def return_none(b: any) {
        typ = b.function.function_type.return_type;
        if isinstance(typ, ir.VoidType) {
            b.ret_void();
        } else {
            b.ret(ir.Constant(typ, None));
        }
    }

    def field(b: any, value: any, owner: str, name: str) -> any {
        i32 = ir.IntType(32);
        return b.gep(
            value,
            [
                ir.Constant(i32, 0),
                ir.Constant(i32, self.gen.struct_field_indices[owner][name])
            ]
        );
    }

    def memory(b: any, addr: any, offset: int) -> any {
        i64 = ir.IntType(64);
        return b.inttoptr(b.add(addr, ir.Constant(i64, offset)), i64.as_pointer());
    }

    def support {
        i64 = ir.IntType(64);
        i32 = ir.IntType(32);
        void = ir.VoidType();
        module = self.gen.llvm_module;
        if "__jac_spec_tls_get" in module.globals {
            return;
        }
        i8p = ir.IntType(8).as_pointer();
        key = ir.GlobalVariable(module, i32, "__jac_spec_tls_key");
        key.linkage = "weak";
        key.initializer = ir.Constant(i32, 0);
        ready = ir.GlobalVariable(module, ir.IntType(1), "__jac_spec_tls_ready");
        ready.linkage = "weak";
        ready.initializer = ir.Constant(ir.IntType(1), 0);
        init = self.raw("__jac_spec_init", void, []);
        init.linkage = "weak";
        entry_bb = init.append_basic_block("entry");
        create = init.append_basic_block("create");
        failed = init.append_basic_block("failed");
        done = init.append_basic_block("done");
        b = ir.IRBuilder(entry_bb);
        b.cbranch(b.load(ready), done, create);
        b = ir.IRBuilder(create);
        create_key = self.raw("pthread_key_create", i32, [i8p, i8p]);
        status = b.call(create_key, [b.bitcast(key, i8p), ir.Constant(i8p, None)]);
        ok = b.icmp_signed("==", status, ir.Constant(i32, 0));
        b.store(ok, ready);
        b.cbranch(ok, done, failed);
        b = ir.IRBuilder(failed);
        b.call(self.raw("__jac_spec_disable", void, []), []);
        b.branch(done);
        b = ir.IRBuilder(done);
        b.ret_void();
        get = self.raw("__jac_spec_tls_get", i64, []);
        get.linkage = "weak";
        b = ir.IRBuilder(get.append_basic_block("entry"));
        lookup = get.append_basic_block("lookup");
        empty = get.append_basic_block("empty");
        b.cbranch(b.load(ready), lookup, empty);
        b = ir.IRBuilder(empty);
        b.ret(ir.Constant(i64, 0));
        b = ir.IRBuilder(lookup);
        value = b.call(
            self.raw("pthread_getspecific", i8p, [i64]), [b.zext(b.load(key), i64)]
        );
        b.ret(b.ptrtoint(value, i64));
        set = self.raw("__jac_spec_tls_set", void, [i64]);
        set.linkage = "weak";
        b = ir.IRBuilder(set.append_basic_block("entry"));
        bind = set.append_basic_block("bind");
        done = set.append_basic_block("done");
        b.cbranch(b.load(ready), bind, done);
        b = ir.IRBuilder(bind);
        b.call(
            self.raw("pthread_setspecific", i32, [i64, i8p]),
            [b.zext(b.load(key), i64), b.inttoptr(set.args[0], i8p)]
        );
        b.branch(done);
        b = ir.IRBuilder(done);
        b.ret_void();
        stack = self.raw("__jac_spec_stack_addr", i64, []);
        stack.linkage = "weak";
        stack.attributes.add("noinline");
        b = ir.IRBuilder(stack.append_basic_block("entry"));
        b.ret(b.ptrtoint(b.alloca(i64), i64));
        jump = self.raw("__jac_spec_jump", void, [i64]);
        jump.linkage = "weak";
        b = ir.IRBuilder(jump.append_basic_block("entry"));
        lj = self.raw("longjmp", void, [ir.IntType(8).as_pointer(), i32]);
        b.call(lj, [b.inttoptr(jump.args[0], lj.args[0].type), ir.Constant(i32, 1)]);
        b.unreachable();
        apply = self.raw("__jac_spec_apply", void, [i64, i64, i64]);
        apply.linkage = "weak";
        b = ir.IRBuilder(apply.append_basic_block("entry"));
        fn = b.inttoptr(apply.args[0], ir.FunctionType(void, [i64, i64]).as_pointer());
        b.call(fn, [apply.args[1], apply.args[2]]);
        b.ret_void();
        for name in ("active", "peak", "commits", "fallbacks") {
            counter = ir.GlobalVariable(module, i64, "__jac_spec_" + name);
            counter.linkage = "weak";
            counter.initializer = ir.Constant(i64, 0);
            counter_fn = self.raw("__jac_spec_get_" + name, i64, []);
            counter_fn.linkage = "weak";
            b = ir.IRBuilder(counter_fn.append_basic_block("entry"));
            b.ret(b.atomic_rmw("add", counter, ir.Constant(i64, 0), "monotonic"));
        }
    }

    def adapter(fn: any, runtime: str, result: any, types: list[any]) -> any {
        key = (fn.name, runtime);
        if key in self.wrappers {
            return self.wrappers[key];
        }
        wrapper = ir.Function(
            self.gen.llvm_module,
            fn.function_type,
            name=f"__jac_spec_adapter_{len(self.wrappers)}"
        );
        wrapper.linkage = "private";
        self.wrappers[key] = wrapper;
        b = ir.IRBuilder(wrapper.append_basic_block("entry"));
        target = self.raw(runtime, result, types);
        args = [];
        for (value, typ) in zip(wrapper.args, types) {
            args.append(self.cast(b, self.word(b, value), typ));
        }
        value = b.call(target, args);
        if isinstance(fn.function_type.return_type, ir.VoidType) {
            b.ret_void();
        } else {
            b.ret(self.cast(b, value, fn.function_type.return_type));
        }
        return wrapper;
    }

    def effect(fn: any) -> any {
        key = (fn.name, "effect");
        if key in self.wrappers {
            return self.wrappers[key];
        }
        i64 = ir.IntType(64);
        void = ir.VoidType();
        wrapper = ir.Function(
            self.gen.llvm_module,
            fn.function_type,
            name=f"__jac_spec_effect_{len(self.wrappers)}"
        );
        wrapper.linkage = "private";
        self.wrappers[key] = wrapper;
        replay = ir.Function(
            self.gen.llvm_module,
            ir.FunctionType(void, [i64, i64]),
            name=f"__jac_spec_replay_{len(self.wrappers)}"
        );
        replay.linkage = "private";
        b = ir.IRBuilder(replay.append_basic_block("entry"));
        if fn.name == "osp_report" {
            jv: ir.Value = ir.Constant(fn.args[0].type, None);
            jv = b.insert_value(
                jv, self.cast(b, replay.args[0], fn.args[0].type.elements[0]), 0
            );
            jv = b.insert_value(jv, replay.args[1], 1);
            b.call(fn, [jv]);
        } else {
            b.call(
                fn, [self.cast(b, a, t.type) for (a, t) in zip(replay.args, fn.args)]
            );
        }
        b.ret_void();
        b = ir.IRBuilder(wrapper.append_basic_block("entry"));
        args: list[ir.Value] = [ir.Constant(i64, 0), ir.Constant(i64, 0)];
        if fn.name == "osp_report" {
            args = [
                self.word(b, b.extract_value(wrapper.args[0], 0)),
                b.extract_value(wrapper.args[0], 1)
            ];
        } else {
            for (idx, value) in enumerate(wrapper.args) {
                args[idx] = self.word(b, value);
            }
        }
        result = None;
        if fn.name == "osp_visit" {
            possible = self.raw("__jac_spec_visit_possible", ir.IntType(1), [i64, i64]);
            result = b.call(possible, args);
        }
        record = self.raw("__jac_spec_effect", void, [i64, i64, i64]);
        b.call(record, [b.ptrtoint(replay, i64)] + args);
        if result is not None {
            b.ret(self.cast(b, result, fn.function_type.return_type));
        } else {
            self.return_none(b);
        }
        return wrapper;
    }

    def trial_region(fn: any) -> any {
        key = (fn.name, "region");
        if key in self.wrappers {
            return self.wrappers[key];
        }
        wrapper = ir.Function(
            self.gen.llvm_module,
            fn.function_type,
            name=f"__jac_spec_region_{len(self.wrappers)}"
        );
        wrapper.linkage = "private";
        self.wrappers[key] = wrapper;
        b = ir.IRBuilder(wrapper.append_basic_block("entry"));
        self.return_none(b);
        return wrapper;
    }

    def boundary(name: str) -> bool {
        return name.startswith(
            (
                "OspEngine.",
                "osp_spawn",
                "osp_conn",
                "osp_disconn",
                "osp_destroy",
                "osp_node_destroy",
                "osp_drop_node",
                "osp_forget",
                "osp_light_remove",
                "osp_light_detach",
                "osp_light_disconn",
                "osp_region_",
                "osp_register_",
                "__jac_glob_init",
                "__jac_region_",
                "__jac_raise",
                "__jac_throw",
                "__rc_gc_",
                "__rc_debug_"
            )
        )
            or name in ("scope_of", "_current_scope")
            or name.startswith("OspGraph.")
            and name.split(".", 1)[1]
                in (
                    "connect",
                    "connect_light",
                    "light_remove_one",
                    "light_detach",
                    "conn_many",
                    "disconnect",
                    "disconnect_between",
                    "node_destroy",
                    "destroy",
                    "destroy_all",
                    "drop_node",
                    "region_reg",
                    "region_died"
                );
    }

    def local(ptr: any) -> bool {
        seen: set = set();
        while id(ptr) not in seen {
            seen.add(id(ptr));
            op = getattr(ptr, "opname", "");
            if op == "alloca" {
                return True;
            }
            if isinstance(ptr, ir.GlobalVariable) and ptr.global_constant {
                return True;
            }
            if op not in ("getelementptr", "bitcast") {
                return False;
            }
            ptr = ptr.operands[0];
        }
        return False;
    }

    def instrument_function(fn: any) {
        i64 = ir.IntType(64);
        void = ir.VoidType();
        abort = self.raw("__jac_spec_abort", void, []);
        tick = self.raw("__jac_spec_tick", void, []);
        read = self.raw("__jac_spec_read", void, [i64, i64, i64]);
        write = self.raw("__jac_spec_write", void, [i64, i64, i64]);
        resolve = self.raw("__jac_spec_resolve", i64, [i64]);
        name = fn.name.removeprefix("__jac_trial_");
        if self.boundary(name) {
            fn.blocks.clear();
            fn.append_basic_block("entry");
            b = ir.IRBuilder(fn.blocks[0]);
            b.call(abort, []);
            b.unreachable();
            return;
        }
        originals = [(block, list(block.instructions)) for block in fn.blocks];
        for (block, instructions) in originals {
            b = ir.IRBuilder(block);
            first = next(
                (
                    x
                    for x in instructions
                    if x.opname != "phi"
                ),
                None
            );
            if first is not None {
                b.position_before(first);
                b.call(tick, []);
            }
            for inst in instructions {
                b.position_before(inst);
                if inst.opname in ("load", "store") {
                    ptr = inst.operands[0 if inst.opname == "load" else 1];
                    if self.local(ptr) {
                        continue;
                    }
                    typ = inst.type if inst.opname == "load" else inst.operands[0].type;
                    alloc = ir.IRBuilder(fn.blocks[0]);
                    alloc.position_at_start(fn.blocks[0]);
                    temp = alloc.alloca(typ, name="spec.value");
                    b.position_before(inst);
                    size = b.ptrtoint(
                        b.gep(
                            ir.Constant(typ.as_pointer(), None), [ir.Constant(i64, 1)]
                        ),
                        i64
                    );
                    if inst.opname == "load" {
                        b.call(read, [self.word(b, ptr), size, self.word(b, temp)]);
                        inst.operands = [temp];
                        inst._clear_string_cache();
                    } else {
                        b.store(inst.operands[0], temp);
                        b.call(write, [self.word(b, ptr), size, self.word(b, temp)]);
                        block.instructions.remove(inst);
                    }
                } elif inst.opname == "call" {
                    callee = inst.callee;
                    cname = callee.name if isinstance(callee, ir.Function) else "";
                    replacement = None;
                    if cname
                        in (
                            "__rc_retain",
                            "__rc_release",
                            "__rc_release_impl",
                            "__rc_release_simple",
                            "osp_report",
                            "osp_visit",
                            "osp_skip_rest",
                            "osp_disengage"
                        ) {
                        replacement = self.effect(callee);
                    } elif cname
                        in (
                            "__jac_region_of",
                            "__jac_region_enter",
                            "__jac_region_leave",
                            "__jac_region_current",
                            "__jac_region_depth",
                            "__jac_region_unwind",
                            "__jac_region_owns"
                        ) {
                        replacement = self.trial_region(callee);
                    } elif cname in ("__rc_alloc", )
                        or cname.startswith("__jac_spec_") {
                        continue;
                    } elif callee in self.clones {
                        replacement = self.clones[callee];
                    } elif cname
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
                            cname, cname
                        );
                        result = ir.IntType(32)
                            if cname in ("strcmp", "strncmp", "memcmp")
                            else i64;
                        types = [i64 for _ in callee.args];
                        if cname == "memset" {
                            types[1] = ir.IntType(32);
                        }
                        replacement = self.adapter(
                            callee, "__jac_spec_" + runtime, result, types
                        );
                    } elif cname.startswith("llvm.")
                        and not cname.startswith(
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
                    } elif cname.startswith("llvm.")
                        or isinstance(callee, ir.InlineAsm) {
                        b.call(abort, []);
                        continue;
                    } else {
                        address = b.call(resolve, [self.word(b, callee)]);
                        replacement = b.inttoptr(address, callee.type);
                    }
                    inst.operands = [replacement] + list(inst.args);
                    inst._clear_string_cache();
                } elif inst.opname
                    in (
                        "atomicrmw",
                        "cmpxchg",
                        "load atomic",
                        "store atomic",
                        "fence"
                    ) {
                    b.call(abort, []);
                } elif inst.opname in ("sdiv", "udiv", "srem", "urem") {
                    zero = b.icmp_unsigned(
                        "==", inst.operands[1], ir.Constant(inst.operands[1].type, 0)
                    );
                    if inst.opname in ("sdiv", "srem") {
                        typ = inst.operands[0].type;
                        overflow = b.and_(
                            b.icmp_signed(
                                "==",
                                inst.operands[0],
                                ir.Constant(typ, -(1 << (typ.width - 1)))
                            ),
                            b.icmp_signed("==", inst.operands[1], ir.Constant(typ, -1))
                        );
                        zero = b.or_(zero, overflow);
                    }
                    guard = self.raw("__jac_spec_guard", void, [ir.IntType(1)]);
                    b.call(guard, [zero]);
                }
            }
        }
        for block in fn.blocks {
            for inst in block.instructions {
                inst._clear_string_cache();
            }
        }
    }

    def instrument {
        self.support();
        module = self.gen.llvm_module;
        i64 = ir.IntType(64);
        void = ir.VoidType();
        originals = [
            f
            for f in module.functions
            if f.blocks and not f.name.startswith("__jac_spec_")
        ];
        for fn in originals {
            for block in fn.blocks {
                for inst in list(block.instructions) {
                    if inst.opname == "call"
                        and isinstance(inst.callee, ir.Function)
                        and inst.callee.name in ("malloc", "free") {
                        callee = inst.callee;
                        replacement = self.adapter(
                            callee,
                            "__jac_spec_" + callee.name,
                            i64 if callee.name == "malloc" else void,
                            [i64]
                        );
                        inst.operands = [replacement] + list(inst.args);
                        inst._clear_string_cache();
                    }
                }
            }
        }
        globals = list(module.globals.values());
        for fn in originals {
            if fn.name
                in (
                    "__rc_alloc",
                    "__rc_retain",
                    "__rc_release",
                    "__rc_release_impl",
                    "__rc_release_simple"
                ) {
                continue;
            }
            memo = {
                id(g): g
                for g in globals
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
            clone.name = "__jac_trial_" + fn.name;
            clone.linkage = "private";
            for key in list(vars(clone)) {
                if "cached" in key {
                    delattr(clone, key);
                }
            }
            module.globals[clone.name] = clone;
            for block in clone.blocks {
                for inst in block.instructions {
                    inst.replace_usage(clone, fn);
                }
            }
            self.clones[fn] = clone;
        }
        for clone in list(self.clones.values()) {
            self.instrument_function(clone);
        }
        register = self.raw("__jac_spec_register", void, [i64, i64]);
        explicit_memory = bool(self.gen.module.get_all_sub_nodes(uni.OpenStmt))
            or any(
                n.sym_name == "Region"
                    or n.sym_name.startswith(("__mem_", "__atomic_"))
                for n in self.gen.module.get_all_sub_nodes(uni.Name)
            );
        for fn in originals {
            if fn.name.startswith("__jac_glob_init") {
                b = ir.IRBuilder(fn.blocks[0]);
                b.position_at_start(fn.blocks[0]);
                b.call(module.globals["__jac_spec_init"], []);
                if explicit_memory
                    or any(f.name.endswith(".drop") for f in originals) {
                    b.call(self.raw("__jac_spec_disable", void, []), []);
                }
                for (original, trial) in self.clones.items() {
                    b.call(
                        register, [b.ptrtoint(original, i64), b.ptrtoint(trial, i64)]
                    );
                }
            }
        }
    }

    def callbacks -> dict[str, any] {
        self.support();
        i64 = ir.IntType(64);
        i32 = ir.IntType(32);
        i8p = ir.IntType(8).as_pointer();
        void = ir.VoidType();
        zero = ir.Constant(i64, 0);
        one = ir.Constant(i64, 1);
        module = self.gen.llvm_module;
        fields = self.gen.struct_field_types["OspRuntime"];
        task_ty = self.gen.struct_types["OspTask"].as_pointer();
        new = self.raw("__jac_spec_new", i64, [i64]);
        set = module.globals["__jac_spec_tls_set"];
        resolve = self.raw("__jac_spec_resolve", i64, [i64]);
        worker = self.raw("__jac_spec_worker", i8p, [i8p]);
        worker.linkage = "private";
        entry_bb = worker.append_basic_block("entry");
        run = worker.append_basic_block("run");
        trial = worker.append_basic_block("trial");
        done = worker.append_basic_block("done");
        b = ir.IRBuilder(entry_bb);
        task = b.bitcast(worker.args[0], task_ty);
        ctx = b.load(self.field(b, task, "OspTask", "state"));
        b.cbranch(b.icmp_unsigned("!=", ctx, zero), run, done);
        b = ir.IRBuilder(run);
        top = b.ptrtoint(b.alloca(i64), i64);
        b.store(top, self.memory(b, ctx, 64));
        b.store(one, self.memory(b, ctx, 56));
        b.call(set, [ctx]);
        active = b.atomic_rmw(
            "add", module.globals["__jac_spec_active"], one, "monotonic"
        );
        b.atomic_rmw(
            "umax", module.globals["__jac_spec_peak"], b.add(active, one), "monotonic"
        );
        bound = worker.append_basic_block("bound");
        current = b.call(module.globals["__jac_spec_tls_get"], []);
        b.cbranch(b.icmp_unsigned("==", current, ctx), bound, done);
        b = ir.IRBuilder(bound);
        sj = self.raw("_setjmp", i32, [i8p]);
        sj.attributes.add("returns_twice");
        jumped = b.call(sj, [b.inttoptr(b.add(ctx, ir.Constant(i64, 96)), i8p)]);
        b.cbranch(b.icmp_signed("==", jumped, ir.Constant(i32, 0)), trial, done);
        b = ir.IRBuilder(trial);
        slot = b.load(self.field(b, task, "OspTask", "slot"));
        fn = b.load(self.field(b, slot, "Slot", "fn"));
        resolved = b.call(resolve, [b.ptrtoint(fn, i64)]);
        fn = b.inttoptr(resolved, fn.type);
        a = b.load(self.field(b, task, "OspTask", "a"));
        other = b.load(self.field(b, task, "OspTask", "b"));
        b.call(fn, [a, other]);
        b.store(ir.Constant(i64, 2), self.memory(b, ctx, 56));
        b.branch(done);
        b = ir.IRBuilder(done);
        finish = worker.append_basic_block("finish");
        inactive = worker.append_basic_block("inactive");
        b.cbranch(b.icmp_unsigned("!=", ctx, zero), inactive, finish);
        b = ir.IRBuilder(inactive);
        b.atomic_rmw("sub", module.globals["__jac_spec_active"], one, "monotonic");
        b.branch(finish);
        b = ir.IRBuilder(finish);
        b.call(set, [zero]);
        b.ret(ir.Constant(i8p, None));

        run_tasks = ir.Function(
            module, fields["run_tasks"].pointee, name="__jac_spec_run_tasks"
        );
        run_tasks.linkage = "private";
        entry_bb = run_tasks.append_basic_block("entry");
        check = run_tasks.append_basic_block("check");
        launch = run_tasks.append_basic_block("launch");
        sync = run_tasks.append_basic_block("sync");
        advance = run_tasks.append_basic_block("advance");
        join_check = run_tasks.append_basic_block("join.check");
        join_test = run_tasks.append_basic_block("join.test");
        join = run_tasks.append_basic_block("join");
        join_next = run_tasks.append_basic_block("join.next");
        done = run_tasks.append_basic_block("done");
        b = ir.IRBuilder(entry_bb);
        tasks = run_tasks.args[0];
        count = b.load(b.gep(tasks, [ir.Constant(i32, 0), ir.Constant(i32, 0)]));
        data = b.load(b.gep(tasks, [ir.Constant(i32, 0), ir.Constant(i32, 2)]));
        threads = b.alloca(i64, size=count);
        flags = b.alloca(i32, size=count);
        attrs = b.bitcast(b.alloca(ir.ArrayType(i64, 16)), i8p);
        b.call(self.raw("pthread_attr_init", i32, [i8p]), [attrs]);
        b.call(
            self.raw("pthread_attr_setstacksize", i32, [i8p, i64]),
            [attrs, ir.Constant(i64, 8388608)]
        );
        index = b.alloca(i64);
        b.store(zero, index);
        b.branch(check);
        b = ir.IRBuilder(check);
        idx = b.load(index);
        b.cbranch(b.icmp_unsigned("<", idx, count), launch, join_check);
        b = ir.IRBuilder(launch);
        task = b.bitcast(b.load(b.gep(data, [idx])), task_ty);
        ignored = b.load(self.field(b, task, "OspTask", "ignores"));
        ctx = b.call(new, [b.ptrtoint(ignored, i64)]);
        b.store(ctx, self.field(b, task, "OspTask", "state"));
        pthread_create = self.raw(
            "pthread_create", i32, [i64.as_pointer(), i8p, worker.type, i8p]
        );
        rc = b.call(
            pthread_create, [b.gep(threads, [idx]), attrs, worker, b.bitcast(task, i8p)]
        );
        b.store(rc, b.gep(flags, [idx]));
        b.cbranch(b.icmp_signed("==", rc, ir.Constant(i32, 0)), advance, sync);
        b = ir.IRBuilder(sync);
        b.call(worker, [b.bitcast(task, i8p)]);
        b.branch(advance);
        b = ir.IRBuilder(advance);
        b.store(b.add(idx, one), index);
        b.branch(check);
        b = ir.IRBuilder(join_check);
        b.store(zero, index);
        b.branch(join_test);
        b = ir.IRBuilder(join_test);
        ji = b.load(index);
        b.cbranch(b.icmp_unsigned("<", ji, count), join, done);
        b = ir.IRBuilder(join);
        status = b.load(b.gep(flags, [ji]));
        joined = run_tasks.append_basic_block("join.thread");
        b.cbranch(b.icmp_signed("==", status, ir.Constant(i32, 0)), joined, join_next);
        b = ir.IRBuilder(joined);
        pthread_join = self.raw("pthread_join", i32, [i64, i8p]);
        b.call(pthread_join, [b.load(b.gep(threads, [ji])), ir.Constant(i8p, None)]);
        b.branch(join_next);
        b = ir.IRBuilder(join_next);
        b.store(b.add(ji, one), index);
        b.branch(join_test);
        b = ir.IRBuilder(done);
        b.call(self.raw("pthread_attr_destroy", i32, [i8p]), [attrs]);
        self.return_none(b);
        out = {"run_tasks": run_tasks};
        for (name, result) in [("commit_task", ir.IntType(1)), ("drop_task", void)] {
            fn = ir.Function(module, fields[name].pointee, name="__jac_spec_" + name);
            fn.linkage = "private";
            b = ir.IRBuilder(fn.append_basic_block("entry"));
            state = self.field(b, fn.args[0], "OspTask", "state");
            target = self.raw(
                "__jac_spec_" + ("commit" if name == "commit_task" else "drop"),
                result,
                [i64]
            );
            value = b.call(target, [b.load(state)]);
            if name == "commit_task" {
                delta = b.zext(value, i64);
                b.atomic_rmw(
                    "add", module.globals["__jac_spec_commits"], delta, "monotonic"
                );
                b.atomic_rmw(
                    "add",
                    module.globals["__jac_spec_fallbacks"],
                    b.sub(one, delta),
                    "monotonic"
                );
                b.ret(self.cast(b, value, fn.function_type.return_type));
            } else {
                b.store(zero, state);
                self.return_none(b);
            }
            out[name] = fn;
        }
        return out;
    }
}
