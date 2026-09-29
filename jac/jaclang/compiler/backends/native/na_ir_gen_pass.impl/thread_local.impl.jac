impl NaIRGenPass._emit_tls_slot(
    slot_name: str, get_name: str, set_name: str, destructor: ir.Function | None = None
) -> tuple[ir.Function, ir.Function] {
    """A per-thread pointer slot with lock-free accessors.

    Every unit that touches the slot emits these same accessors, so no unit
    resolves another's copy: linkonce_odr lets the optimizer inline the fast
    path into each caller, while the key, state and lock stay weak so one
    process-wide slot serves every unit. Until the first thread publishes the
    key, an accessor takes the cold initializer, which serializes on the spin
    lock, re-checks under it, creates the key and publishes it with a release
    store; the accessors' acquire load pairs with that store.
    """;
    if get_name in self.extern_funcs {
        return (self.extern_funcs[get_name], self.extern_funcs[set_name]);
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    one = ir.Constant(i64, 1);
    zero = ir.Constant(i64, 0);
    get_fn = ir.Function(self.llvm_module, ir.FunctionType(i64, []), name=get_name);
    get_fn.linkage = "linkonce_odr";
    set_fn = ir.Function(
        self.llvm_module, ir.FunctionType(ir.VoidType(), [i64]), name=set_name
    );
    set_fn.linkage = "linkonce_odr";
    set_fn.args[0].name = "v";
    self.extern_funcs[get_name] = get_fn;
    self.extern_funcs[set_name] = set_fn;
    if "wasm" in str(self.llvm_module.triple or "") {
        slot = ir.GlobalVariable(self.llvm_module, i8p, name=slot_name);
        slot.linkage = "weak";
        slot.initializer = ir.Constant(i8p, None);
        gb = ir.IRBuilder(get_fn.append_basic_block("entry"));
        gb.ret(gb.ptrtoint(gb.load(slot, name="tls.v"), i64, name="tls.i64"));
        sb = ir.IRBuilder(set_fn.append_basic_block("entry"));
        sb.store(sb.inttoptr(set_fn.args[0], i8p, name="tls.p"), slot);
        sb.ret_void();
        return (get_fn, set_fn);
    }

    key_gv = ir.GlobalVariable(self.llvm_module, i64, name=f"{slot_name}_key");
    key_gv.linkage = "weak";
    key_gv.initializer = zero;
    state_gv = ir.GlobalVariable(self.llvm_module, i64, name=f"{slot_name}_state");
    state_gv.linkage = "weak";
    state_gv.initializer = zero;
    lock_gv = ir.GlobalVariable(self.llvm_module, i64, name=f"{slot_name}_lock");
    lock_gv.linkage = "weak";
    lock_gv.initializer = zero;
    key_create = self._get_or_declare_extern("pthread_key_create", i32, [i8p, i8p]);
    get_specific = self._get_or_declare_extern("pthread_getspecific", i8p, [i64]);
    set_specific = self._get_or_declare_extern("pthread_setspecific", i32, [i64, i8p]);

    init_fn = ir.Function(
        self.llvm_module, ir.FunctionType(ir.VoidType(), []), name=f"{slot_name}_init"
    );
    init_fn.linkage = "weak";
    init_fn.attributes.add("noinline");
    init_fn.attributes.add("cold");
    _i_entry = init_fn.append_basic_block("entry");
    _i_lock = init_fn.append_basic_block("lock");
    _i_check = init_fn.append_basic_block("check");
    _i_create = init_fn.append_basic_block("create");
    _i_unlock = init_fn.append_basic_block("unlock");
    ir.IRBuilder(_i_entry).branch(_i_lock);
    ib = ir.IRBuilder(_i_lock);
    _held = ib.atomic_rmw(
        "xchg", lock_gv, one, ordering="acquire", name="tls.lock.old"
    );
    ib.cbranch(
        ib.icmp_unsigned("!=", _held, zero, name="tls.lock.busy"), _i_lock, _i_check
    );
    ib = ir.IRBuilder(_i_check);
    _published = ib.load_atomic(state_gv, "acquire", 8, name="tls.state.locked");
    ib.cbranch(
        ib.icmp_unsigned("==", _published, one, name="tls.ready.locked"),
        _i_unlock,
        _i_create
    );
    ib = ir.IRBuilder(_i_create);
    ib.call(
        key_create,
        [
            ib.bitcast(key_gv, i8p, name="tls.key.p"),
            ib.bitcast(destructor, i8p)
                if destructor is not None
                else ir.Constant(i8p, None)
        ]
    );
    ib.store_atomic(one, state_gv, "release", 8);
    ib.branch(_i_unlock);
    ib = ir.IRBuilder(_i_unlock);
    ib.store_atomic(zero, lock_gv, "release", 8);
    ib.ret_void();

    get_key = self._emit_tls_ready_key(get_fn, state_gv, key_gv, init_fn);
    gb = ir.IRBuilder(get_fn.blocks[-1]);
    _gp = gb.call(get_specific, [get_key], name="tls.v");
    gb.ret(gb.ptrtoint(_gp, i64, name="tls.i64"));

    set_key = self._emit_tls_ready_key(set_fn, state_gv, key_gv, init_fn);
    sb = ir.IRBuilder(set_fn.blocks[-1]);
    sb.call(set_specific, [set_key, sb.inttoptr(set_fn.args[0], i8p, name="tls.p")]);
    sb.ret_void();
    return (get_fn, set_fn);
}

impl NaIRGenPass._emit_tls_ready_key(
    accessor: ir.Function,
    state_gv: ir.GlobalVariable,
    key_gv: ir.GlobalVariable,
    init_fn: ir.Function
) -> ir.Value {
    """Open `accessor` with the slot's readiness check and return its key.

    Once the key is published the check is one acquire load, which compiles to
    a plain load on x86-64 and AArch64; only a thread that finds the slot
    unpublished calls the cold initializer. The builder is left positioned in
    the block that holds the key, for the accessor to finish.
    """;
    i64 = ir.IntType(64);
    check_bb = accessor.append_basic_block("entry");
    cold = accessor.append_basic_block("init");
    ready = accessor.append_basic_block("ready");
    b = ir.IRBuilder(check_bb);
    _state = b.load_atomic(state_gv, "acquire", 8, name="tls.state");
    b.cbranch(
        b.icmp_unsigned("==", _state, ir.Constant(i64, 1), name="tls.ready"),
        ready,
        cold
    );
    b = ir.IRBuilder(cold);
    b.call(init_fn, []);
    b.branch(ready);
    return ir.IRBuilder(ready).load(key_gv, name="tls.key");
}
