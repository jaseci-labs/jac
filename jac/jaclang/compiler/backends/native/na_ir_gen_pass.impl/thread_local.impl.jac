impl NaIRGenPass._emit_tls_slot(
    slot_name: str, get_name: str, set_name: str, destructor: ir.Function | None = None
) -> tuple[ir.Function, ir.Function] {
    if get_name in self.extern_funcs {
        return (self.extern_funcs[get_name], self.extern_funcs[set_name]);
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    get_fn = ir.Function(self.llvm_module, ir.FunctionType(i64, []), name=get_name);
    get_fn.linkage = "weak";
    set_fn = ir.Function(
        self.llvm_module, ir.FunctionType(ir.VoidType(), [i64]), name=set_name
    );
    set_fn.linkage = "weak";
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

    # An imported target header can provide a narrower pthread_key_t than the
    # runtime's opaque fallback. Allocate and load that exact storage type.
    key_type: ir.Type = i64;
    for symbol in ["pthread_key_create", "pthread_getspecific", "pthread_setspecific"] {
        declaration = self.llvm_module.globals.get(symbol);
        if not isinstance(declaration, ir.Function) or not declaration.function_type.args { continue; }
        candidate = declaration.function_type.args[0];
        if symbol == "pthread_key_create" {
            if not isinstance(candidate, ir.PointerType) { continue; }
            candidate = candidate.pointee;
        }
        if isinstance(candidate, ir.IntType) and candidate.width in [16, 32, 64] {
            key_type = candidate; break;
        }
    }
    get_specific = self._get_or_declare_extern("pthread_getspecific", i8p, [key_type]);
    key_create = self._get_or_declare_extern("pthread_key_create", i32, [i8p, i8p]);
    set_specific = self._get_or_declare_extern("pthread_setspecific", i32, [key_type, i8p]);
    key_gv = ir.GlobalVariable(self.llvm_module, key_type, name=f"{slot_name}_key");
    key_gv.linkage = "weak";
    key_gv.initializer = ir.Constant(key_type, 0);
    state_gv = ir.GlobalVariable(self.llvm_module, i64, name=f"{slot_name}_state");
    state_gv.linkage = "weak";
    state_gv.initializer = ir.Constant(i64, 0);

    lock_gv = ir.GlobalVariable(self.llvm_module, i64, name=f"{slot_name}_lock");
    lock_gv.linkage = "weak";
    lock_gv.initializer = ir.Constant(i64, 0);
    init_fn = ir.Function(
        self.llvm_module, ir.FunctionType(ir.VoidType(), []), name=f"{slot_name}_init"
    );
    init_fn.linkage = "weak";
    _i_entry = init_fn.append_basic_block("entry");
    _i_lock = init_fn.append_basic_block("lock");
    _i_check = init_fn.append_basic_block("check");
    _i_create = init_fn.append_basic_block("create");
    _i_unlock = init_fn.append_basic_block("unlock");
    _i_done = init_fn.append_basic_block("done");
    ib = ir.IRBuilder(_i_entry);
    _st = ib.atomic_rmw(
        "add", state_gv, ir.Constant(i64, 0), ordering="acquire", name="tls.state"
    );
    ib.cbranch(
        ib.icmp_unsigned("==", _st, ir.Constant(i64, 1), name="tls.ready"),
        _i_done,
        _i_lock
    );
    ib = ir.IRBuilder(_i_lock);
    _held = ib.atomic_rmw(
        "xchg", lock_gv, ir.Constant(i64, 1), ordering="acquire", name="tls.lock.old"
    );
    ib.cbranch(
        ib.icmp_unsigned("!=", _held, ir.Constant(i64, 0), name="tls.lock.busy"),
        _i_lock,
        _i_check
    );
    ib = ir.IRBuilder(_i_check);
    _st2 = ib.atomic_rmw(
        "add",
        state_gv,
        ir.Constant(i64, 0),
        ordering="acquire",
        name="tls.state.locked"
    );
    ib.cbranch(
        ib.icmp_unsigned("==", _st2, ir.Constant(i64, 1), name="tls.ready.locked"),
        _i_unlock,
        _i_create
    );
    ib = ir.IRBuilder(_i_create);
    ib.call(
        key_create,
        [
            ib.bitcast(key_gv, key_create.function_type.args[0], name="tls.key.p"),
            ib.bitcast(destructor, key_create.function_type.args[1])
                if destructor is not None
                else ir.Constant(key_create.function_type.args[1], None)
        ]
    );
    ib.atomic_rmw(
        "xchg", state_gv, ir.Constant(i64, 1), ordering="release", name="tls.mark"
    );
    ib.branch(_i_unlock);
    ib = ir.IRBuilder(_i_unlock);
    ib.atomic_rmw(
        "xchg", lock_gv, ir.Constant(i64, 0), ordering="release", name="tls.unlock"
    );
    ib.branch(_i_done);
    ib = ir.IRBuilder(_i_done);
    ib.ret_void();

    gb = ir.IRBuilder(get_fn.append_basic_block("entry"));
    gb.call(init_fn, []);
    _gk = gb.load(key_gv, name="tls.key");
    get_key_type = get_specific.function_type.args[0];
    if isinstance(_gk.type, ir.IntType) and isinstance(get_key_type, ir.IntType) and _gk.type != get_key_type {
        _gk = gb.zext(_gk, get_key_type) if _gk.type.width < get_key_type.width else gb.trunc(_gk, get_key_type);
    }
    _gp = gb.call(get_specific, [_gk], name="tls.v");
    gb.ret(gb.ptrtoint(_gp, i64, name="tls.i64"));

    sb = ir.IRBuilder(set_fn.append_basic_block("entry"));
    sb.call(init_fn, []);
    _sk = sb.load(key_gv, name="tls.key");
    set_key_type = set_specific.function_type.args[0];
    if isinstance(_sk.type, ir.IntType) and isinstance(set_key_type, ir.IntType) and _sk.type != set_key_type {
        _sk = sb.zext(_sk, set_key_type) if _sk.type.width < set_key_type.width else sb.trunc(_sk, set_key_type);
    }
    sb.call(set_specific, [_sk, sb.inttoptr(set_fn.args[0], set_specific.function_type.args[1], name="tls.p")]);
    sb.ret_void();
    return (get_fn, set_fn);
}
