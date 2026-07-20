impl NaIRGenPass._ensure_iter_types -> None {
    if self._iter_structs_registered {
        return;
    }
    self._iter_structs_registered = True;
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    self._register_iter_struct("JacIter", ["next_fn", "state"], [i64, i8p]);
    self._jac_iter_type = self.struct_types["JacIter"];

    self._register_iter_struct("ListIterState", ["coll", "idx"], [i64, i64]);
    self._register_iter_struct("StrIterState", ["s", "idx"], [i64, i64]);
    self._register_iter_struct("DictKeyIterState", ["coll", "idx"], [i64, i64]);
    self._register_iter_struct("SetIterState", ["coll", "idx"], [i64, i64]);

    self._register_iter_struct(
        "RangeIterState", ["cur", "stop", "step"], [i64, i64, i64]
    );

    self._register_iter_struct("MapIterState", ["upstream"], [i8p]);
    self._register_iter_struct("FilterIterState", ["upstream"], [i8p]);
    self._register_iter_struct("EnumerateIterState", ["upstream", "idx"], [i8p, i64]);
    self._register_iter_struct("ZipIterState", ["up_a", "up_b"], [i8p, i8p]);

    self._register_iter_struct("UserIterState", ["obj"], [i8p]);
}

impl NaIRGenPass._register_iter_struct(
    name: str, field_names: list[str], field_types: list[ir.Type]
) -> None {
    st = self.llvm_module.context.get_identified_type(name);
    st.set_body(*field_types);
    self.struct_types[name] = st;
    idx_map: dict[str, int] = {};
    type_map: dict[str, ir.Type] = {};
    i = 0;
    for fname in field_names {
        idx_map[fname] = i;
        type_map[fname] = field_types[i];
        i = i + 1;
    }
    self.struct_field_indices[name] = idx_map;
    self.struct_field_types[name] = type_map;
    self.struct_field_defaults[name] = {};
}

impl NaIRGenPass._alloc_iter_struct(name: str) -> ir.Value {
    self._ensure_iter_types();
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i64p = i64.as_pointer();
    st = self.struct_types[name];
    sptr = st.as_pointer();
    null_ptr = ir.Constant(sptr, None);
    size_gep = self.builder.gep(null_ptr, [ir.Constant(i32, 1)], name="it.sizeof");
    size = self.builder.ptrtoint(size_gep, i64, name="it.size");
    raw = self.builder.call(self.rc_alloc_fn, [size], name="it.raw");
    it_obj = self.builder.bitcast(raw, sptr, name="it.obj");
    self._emit_struct_release_fn(name);
    dtor = self.struct_release_fns.get(name);
    if dtor is not None {
        raw_i8 = self.builder.bitcast(it_obj, i8p, name="it.raw.i8");
        dtor_slot = self.builder.gep(
            raw_i8, [ir.Constant(i64, -8)], name="it.dtor.slot"
        );
        dtor_slot_p = self.builder.bitcast(dtor_slot, i64p, name="it.dtor.p");
        dtor_i64 = self.builder.ptrtoint(dtor, i64, name="it.dtor.i64");
        self.builder.store(dtor_i64, dtor_slot_p);
    }
    return it_obj;
}

impl NaIRGenPass._make_jac_iter(next_fn: ir.Function, state_ptr: ir.Value) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    ji = self._alloc_iter_struct("JacIter");
    nfty = ir.FunctionType(i1, [i8p, i8p]);
    nf_ptr = self.builder.bitcast(next_fn, nfty.as_pointer(), name="ji.nf.ptr");
    nf_i64 = self.builder.ptrtoint(nf_ptr, i64, name="ji.nf.i64");
    nf_slot = self.builder.gep(
        ji, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ji.nf.slot"
    );
    self.builder.store(nf_i64, nf_slot);
    state_i8 = self.builder.bitcast(state_ptr, i8p, name="ji.state.i8");
    st_slot = self.builder.gep(
        ji, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="ji.st.slot"
    );
    self.builder.store(state_i8, st_slot);
    return ji;
}

impl NaIRGenPass._emit_iter_advance(
    b: ir.IRBuilder, iter_val: ir.Value, out_ptr: ir.Value
) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i1 = ir.IntType(1);
    jptr_type = self._jac_iter_type.as_pointer();
    jptr = iter_val;
    if iter_val.type != jptr_type {
        jptr = b.bitcast(iter_val, jptr_type, name="adv.ji");
    }
    nf_slot = b.gep(
        jptr, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="adv.nf.slot"
    );
    nf_i64 = b.load(nf_slot, name="adv.nf.i64");
    nfty = ir.FunctionType(i1, [i8p, i8p]);
    nf_ptr = b.inttoptr(nf_i64, nfty.as_pointer(), name="adv.nf.ptr");
    st_slot = b.gep(
        jptr, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="adv.st.slot"
    );
    state = b.load(st_slot, name="adv.state");
    out_i8 = out_ptr;
    if out_ptr.type != i8p {
        out_i8 = b.bitcast(out_ptr, i8p, name="adv.out.i8");
    }
    return b.call(nf_ptr, [state, out_i8], name="adv.has");
}

impl NaIRGenPass._list_iter_next_fn(
    elem_type_name: str, elem_type: ir.Type
) -> ir.Function {
    key = "list:" + elem_type_name;
    if key in self._iter_next_fns {
        return self._iter_next_fns[key];
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    helpers = self.list_helpers[elem_type_name];
    list_ptr_type = self.list_types[elem_type_name].as_pointer();
    state_ptr_type = self.struct_types["ListIterState"].as_pointer();
    nfty = ir.FunctionType(i1, [i8p, i8p]);
    fn = ir.Function(self.llvm_module, nfty, name="__iter_next_list_" + elem_type_name);
    fn.linkage = "private";
    fn.args[0].name = "state";
    fn.args[1].name = "out";
    entry_bb = fn.append_basic_block("entry");
    cont = fn.append_basic_block("cont");
    stop = fn.append_basic_block("stop");
    b = ir.IRBuilder(entry_bb);
    state = b.bitcast(fn.args[0], state_ptr_type, name="lit.state");
    coll_slot = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="lit.coll.slot"
    );
    coll_i64 = b.load(coll_slot, name="lit.coll.i64");
    list_ptr = b.inttoptr(coll_i64, list_ptr_type, name="lit.list");
    idx_slot = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="lit.idx.slot"
    );
    idx = b.load(idx_slot, name="lit.idx");
    n = b.call(helpers["len"], [list_ptr], name="lit.len");
    ok = b.icmp_signed("<", idx, n, name="lit.ok");
    b.cbranch(ok, cont, stop);
    b.position_at_end(cont);
    v = b.call(helpers["get"], [list_ptr, idx], name="lit.v");
    out_t = b.bitcast(fn.args[1], elem_type.as_pointer(), name="lit.out");
    b.store(v, out_t);
    b.store(b.add(idx, ir.Constant(i64, 1), name="lit.idx.next"), idx_slot);
    b.ret(ir.Constant(i1, 1));
    b.position_at_end(stop);
    b.ret(ir.Constant(i1, 0));
    self._iter_next_fns[key] = fn;
    return fn;
}

impl NaIRGenPass._make_list_iter(
    list_val: ir.Value, elem_type_name: str, elem_type: ir.Type
) -> ir.Value {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    next_fn = self._list_iter_next_fn(elem_type_name, elem_type);
    state = self._alloc_iter_struct("ListIterState");
    coll_i64 = self.builder.ptrtoint(list_val, i64, name="lit.coll.store");
    coll_slot = self.builder.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="lit.coll.field"
    );
    self.builder.store(coll_i64, coll_slot);
    idx_slot = self.builder.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="lit.idx.field"
    );
    self.builder.store(ir.Constant(i64, 0), idx_slot);
    return self._make_jac_iter(next_fn, state);
}

impl NaIRGenPass._str_iter_next_fn -> ir.Function {
    key = "str";
    if key in self._iter_next_fns {
        return self._iter_next_fns[key];
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    state_ptr_type = self.struct_types["StrIterState"].as_pointer();
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    nfty = ir.FunctionType(i1, [i8p, i8p]);
    fn = ir.Function(self.llvm_module, nfty, name="__iter_next_str");
    fn.linkage = "private";
    fn.args[0].name = "state";
    fn.args[1].name = "out";
    entry_bb = fn.append_basic_block("entry");
    cont = fn.append_basic_block("cont");
    stop = fn.append_basic_block("stop");
    b = ir.IRBuilder(entry_bb);
    state = b.bitcast(fn.args[0], state_ptr_type, name="sit.state");
    s_slot = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="sit.s.slot"
    );
    s_i64 = b.load(s_slot, name="sit.s.i64");
    s_ptr = b.inttoptr(s_i64, i8p, name="sit.s");
    idx_slot = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="sit.idx.slot"
    );
    idx = b.load(idx_slot, name="sit.idx");
    n = b.call(strlen_fn, [s_ptr], name="sit.len");
    ok = b.icmp_signed("<", idx, n, name="sit.ok");
    b.cbranch(ok, cont, stop);
    b.position_at_end(cont);

    i8 = ir.IntType(8);
    char_ptr = b.gep(s_ptr, [idx], name="sit.char.ptr");
    char_val = b.load(char_ptr, name="sit.char");
    ch = b.call(self.rc_alloc_fn, [ir.Constant(i64, 2)], name="sit.char.str");
    b.store(char_val, ch);
    b.store(ir.Constant(i8, 0), b.gep(ch, [ir.Constant(i64, 1)], name="sit.null.ptr"));
    out_t = b.bitcast(fn.args[1], i8p.as_pointer(), name="sit.out");
    b.store(ch, out_t);
    b.store(b.add(idx, ir.Constant(i64, 1), name="sit.idx.next"), idx_slot);
    b.ret(ir.Constant(i1, 1));
    b.position_at_end(stop);
    b.ret(ir.Constant(i1, 0));
    self._iter_next_fns[key] = fn;
    return fn;
}

impl NaIRGenPass._make_str_iter(str_val: ir.Value) -> ir.Value {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    next_fn = self._str_iter_next_fn();
    state = self._alloc_iter_struct("StrIterState");
    s_i64 = self.builder.ptrtoint(str_val, i64, name="sit.s.store");
    s_slot = self.builder.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="sit.s.field"
    );
    self.builder.store(s_i64, s_slot);
    idx_slot = self.builder.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="sit.idx.field"
    );
    self.builder.store(ir.Constant(i64, 0), idx_slot);
    return self._make_jac_iter(next_fn, state);
}

impl NaIRGenPass._bytes_iter_next_fn -> ir.Function {
    key = "bytes";
    if key in self._iter_next_fns {
        return self._iter_next_fns[key];
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    state_ptr_type = self.struct_types["StrIterState"].as_pointer();
    bt_ptr = self._get_bytes_struct_type().as_pointer();
    nfty = ir.FunctionType(i1, [i8p, i8p]);
    fn = ir.Function(self.llvm_module, nfty, name="__iter_next_bytes");
    fn.linkage = "private";
    fn.args[0].name = "state";
    fn.args[1].name = "out";
    entry_bb = fn.append_basic_block("entry");
    cont = fn.append_basic_block("cont");
    stop = fn.append_basic_block("stop");
    b = ir.IRBuilder(entry_bb);
    state = b.bitcast(fn.args[0], state_ptr_type, name="bit.state");
    s_slot = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="bit.s.slot"
    );
    bvp = b.inttoptr(b.load(s_slot, name="bit.s.i64"), bt_ptr, name="bit.bv");
    idx_slot = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="bit.idx.slot"
    );
    idx = b.load(idx_slot, name="bit.idx");
    blen = b.load(
        b.gep(bvp, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="bit.len.ptr"),
        name="bit.len"
    );
    b.cbranch(b.icmp_signed("<", idx, blen, name="bit.ok"), cont, stop);
    b.position_at_end(cont);
    data = b.bitcast(
        b.gep(bvp, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="bit.data.ptr"),
        i8p,
        name="bit.data"
    );
    byte = b.load(b.gep(data, [idx], name="bit.byte.ptr"), name="bit.byte");
    out_t = b.bitcast(fn.args[1], i64.as_pointer(), name="bit.out");
    b.store(b.zext(byte, i64, name="bit.val"), out_t);
    b.store(b.add(idx, ir.Constant(i64, 1), name="bit.idx.next"), idx_slot);
    b.ret(ir.Constant(i1, 1));
    b.position_at_end(stop);
    b.ret(ir.Constant(i1, 0));
    self._iter_next_fns[key] = fn;
    return fn;
}

impl NaIRGenPass._make_bytes_iter(bytes_val: ir.Value) -> ir.Value {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    next_fn = self._bytes_iter_next_fn();
    state = self._alloc_iter_struct("StrIterState");
    s_i64 = self.builder.ptrtoint(bytes_val, i64, name="bit.s.store");
    s_slot = self.builder.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="bit.s.field"
    );
    self.builder.store(s_i64, s_slot);
    idx_slot = self.builder.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="bit.idx.field"
    );
    self.builder.store(ir.Constant(i64, 0), idx_slot);
    return self._make_jac_iter(next_fn, state);
}

impl NaIRGenPass._dict_iter_next_fn(dict_key: str) -> ir.Function {
    key = "dict:" + dict_key;
    if key in self._iter_next_fns {
        return self._iter_next_fns[key];
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    helpers = self.dict_helpers[dict_key];
    dict_ptr_type = self.dict_types[dict_key].as_pointer();
    key_type = helpers["key_type"];
    state_ptr_type = self.struct_types["DictKeyIterState"].as_pointer();
    nfty = ir.FunctionType(i1, [i8p, i8p]);
    fn = ir.Function(
        self.llvm_module, nfty, name="__iter_next_dict_" + dict_key.replace(":", "_")
    );
    fn.linkage = "private";
    fn.args[0].name = "state";
    fn.args[1].name = "out";
    entry_bb = fn.append_basic_block("entry");
    cont = fn.append_basic_block("cont");
    stop = fn.append_basic_block("stop");
    b = ir.IRBuilder(entry_bb);
    state = b.bitcast(fn.args[0], state_ptr_type, name="dit.state");
    coll_slot = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="dit.coll.slot"
    );
    coll_i64 = b.load(coll_slot, name="dit.coll.i64");
    dict_ptr = b.inttoptr(coll_i64, dict_ptr_type, name="dit.dict");
    idx_slot = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="dit.idx.slot"
    );
    idx = b.load(idx_slot, name="dit.idx");
    n = b.call(helpers["len"], [dict_ptr], name="dit.len");
    ok = b.icmp_signed("<", idx, n, name="dit.ok");
    b.cbranch(ok, cont, stop);
    b.position_at_end(cont);
    k = b.call(helpers["get_key"], [dict_ptr, idx], name="dit.k");
    out_t = b.bitcast(fn.args[1], key_type.as_pointer(), name="dit.out");
    b.store(k, out_t);
    b.store(b.add(idx, ir.Constant(i64, 1), name="dit.idx.next"), idx_slot);
    b.ret(ir.Constant(i1, 1));
    b.position_at_end(stop);
    b.ret(ir.Constant(i1, 0));
    self._iter_next_fns[key] = fn;
    return fn;
}

impl NaIRGenPass._make_dict_iter(dict_val: ir.Value, dict_key: str) -> ir.Value {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    next_fn = self._dict_iter_next_fn(dict_key);
    state = self._alloc_iter_struct("DictKeyIterState");
    coll_i64 = self.builder.ptrtoint(dict_val, i64, name="dit.coll.store");
    self.builder.store(
        coll_i64,
        self.builder.gep(
            state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="dit.coll.field"
        )
    );
    self.builder.store(
        ir.Constant(i64, 0),
        self.builder.gep(
            state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="dit.idx.field"
        )
    );
    return self._make_jac_iter(next_fn, state);
}

impl NaIRGenPass._set_iter_next_fn(
    elem_type_name: str, elem_type: ir.Type
) -> ir.Function {
    key = "set:" + elem_type_name;
    if key in self._iter_next_fns {
        return self._iter_next_fns[key];
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    set_ptr_type = self.set_types[elem_type_name].as_pointer();
    state_ptr_type = self.struct_types["SetIterState"].as_pointer();
    nfty = ir.FunctionType(i1, [i8p, i8p]);
    fn = ir.Function(self.llvm_module, nfty, name="__iter_next_set_" + elem_type_name);
    fn.linkage = "private";
    fn.args[0].name = "state";
    fn.args[1].name = "out";
    entry_bb = fn.append_basic_block("entry");
    cont = fn.append_basic_block("cont");
    stop = fn.append_basic_block("stop");
    b = ir.IRBuilder(entry_bb);
    state = b.bitcast(fn.args[0], state_ptr_type, name="set.state");
    coll_slot = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="set.coll.slot"
    );
    coll_i64 = b.load(coll_slot, name="set.coll.i64");
    set_ptr = b.inttoptr(coll_i64, set_ptr_type, name="set.set");
    idx_slot = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="set.idx.slot"
    );
    idx = b.load(idx_slot, name="set.idx");

    n = b.load(
        b.gep(set_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="set.len.p"),
        name="set.len"
    );
    ok = b.icmp_signed("<", idx, n, name="set.ok");
    b.cbranch(ok, cont, stop);
    b.position_at_end(cont);
    data = b.load(
        b.gep(set_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="set.data.p"),
        name="set.data"
    );
    v = b.load(b.gep(data, [idx], name="set.elem.p"), name="set.elem");
    out_t = b.bitcast(fn.args[1], elem_type.as_pointer(), name="set.out");
    b.store(v, out_t);
    b.store(b.add(idx, ir.Constant(i64, 1), name="set.idx.next"), idx_slot);
    b.ret(ir.Constant(i1, 1));
    b.position_at_end(stop);
    b.ret(ir.Constant(i1, 0));
    self._iter_next_fns[key] = fn;
    return fn;
}

impl NaIRGenPass._make_set_iter(
    set_val: ir.Value, elem_type_name: str, elem_type: ir.Type
) -> ir.Value {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    next_fn = self._set_iter_next_fn(elem_type_name, elem_type);
    state = self._alloc_iter_struct("SetIterState");
    coll_i64 = self.builder.ptrtoint(set_val, i64, name="set.coll.store");
    self.builder.store(
        coll_i64,
        self.builder.gep(
            state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="set.coll.field"
        )
    );
    self.builder.store(
        ir.Constant(i64, 0),
        self.builder.gep(
            state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="set.idx.field"
        )
    );
    return self._make_jac_iter(next_fn, state);
}

impl NaIRGenPass._range_iter_next_fn -> ir.Function {
    key = "range";
    if key in self._iter_next_fns {
        return self._iter_next_fns[key];
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    state_ptr_type = self.struct_types["RangeIterState"].as_pointer();
    nfty = ir.FunctionType(i1, [i8p, i8p]);
    fn = ir.Function(self.llvm_module, nfty, name="__iter_next_range");
    fn.linkage = "private";
    fn.args[0].name = "state";
    fn.args[1].name = "out";
    entry_bb = fn.append_basic_block("entry");
    cont = fn.append_basic_block("cont");
    stop = fn.append_basic_block("stop");
    b = ir.IRBuilder(entry_bb);
    state = b.bitcast(fn.args[0], state_ptr_type, name="rit.state");
    cur_slot = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="rit.cur.slot"
    );
    cur = b.load(cur_slot, name="rit.cur");
    stop_v = b.load(
        b.gep(state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="rit.stop.slot"),
        name="rit.stop"
    );
    step = b.load(
        b.gep(state, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="rit.step.slot"),
        name="rit.step"
    );

    pos = b.icmp_signed(">", step, ir.Constant(i64, 0), name="rit.pos");
    lt = b.icmp_signed("<", cur, stop_v, name="rit.lt");
    gt = b.icmp_signed(">", cur, stop_v, name="rit.gt");
    ok = b.select(pos, lt, gt, name="rit.ok");
    b.cbranch(ok, cont, stop);
    b.position_at_end(cont);
    out_t = b.bitcast(fn.args[1], i64.as_pointer(), name="rit.out");
    b.store(cur, out_t);
    b.store(b.add(cur, step, name="rit.cur.next"), cur_slot);
    b.ret(ir.Constant(i1, 1));
    b.position_at_end(stop);
    b.ret(ir.Constant(i1, 0));
    self._iter_next_fns[key] = fn;
    return fn;
}

impl NaIRGenPass._make_range_iter(range_val: ir.Value) -> ir.Value {
    i32 = ir.IntType(32);
    next_fn = self._range_iter_next_fn();
    state = self._alloc_iter_struct("RangeIterState");

    rp = range_val;
    rng_ptr_type = self.range_struct_type.as_pointer();
    if range_val.type != rng_ptr_type {
        rp = self.builder.bitcast(range_val, rng_ptr_type, name="rit.range");
    }
    start = self.builder.load(
        self.builder.gep(
            rp, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="rit.r.start.p"
        ),
        name="rit.r.start"
    );
    stop_v = self.builder.load(
        self.builder.gep(
            rp, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="rit.r.stop.p"
        ),
        name="rit.r.stop"
    );
    step = self.builder.load(
        self.builder.gep(
            rp, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="rit.r.step.p"
        ),
        name="rit.r.step"
    );
    self.builder.store(
        start,
        self.builder.gep(
            state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="rit.cur.field"
        )
    );
    self.builder.store(
        stop_v,
        self.builder.gep(
            state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="rit.stop.field"
        )
    );
    self.builder.store(
        step,
        self.builder.gep(
            state, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="rit.step.field"
        )
    );
    return self._make_jac_iter(next_fn, state);
}

impl NaIRGenPass._make_iter_from_value(
    val: ir.Value, expr: uni.UniNode
) -> (tuple | None) {
    i8p = ir.IntType(8).as_pointer();

    _checked_list = self._list_spec_of(expr);
    if _checked_list is not None and _checked_list in self.list_helpers {
        lt = self.list_types.get(_checked_list);
        if lt is not None and val.type == lt.as_pointer() {
            elem_type = self.list_helpers[_checked_list]["elem_type"];
            return (
                self._make_list_iter(val, _checked_list, elem_type),
                _checked_list,
                elem_type,

            );
        }
    }
    for (lk, lt) in self.list_types.items() {
        if val.type == lt.as_pointer() {
            elem_type = self.list_helpers[lk]["elem_type"];
            return (self._make_list_iter(val, lk, elem_type), lk, elem_type);
        }
    }

    if self?.range_struct_type and val.type == self.range_struct_type.as_pointer() {
        return (self._make_range_iter(val), "range", ir.IntType(64));
    }

    for (dk, dt) in self.dict_types.items() {
        if val.type == dt.as_pointer() {
            key_type = self.dict_helpers[dk]["key_type"];
            return (self._make_dict_iter(val, dk), dk, key_type);
        }
    }

    for (sk, st) in self.set_types.items() {
        if val.type == st.as_pointer() {
            elem_type = self.set_helpers[sk]["elem_type"];
            return (self._make_set_iter(val, sk, elem_type), sk, elem_type);
        }
    }

    if self._is_bytes_value(val) {
        return (self._make_bytes_iter(val), "bytes", ir.IntType(64));
    }
    if isinstance(val.type, ir.PointerType) and val.type == i8p {
        return (self._make_str_iter(val), "str", i8p);
    }
    if self._jac_iter_type is not None
    and val.type == self._jac_iter_type.as_pointer() {
        if not self._is_owned(val) {
            self._emit_rc_retain(val, op="iter_alias");
            self._mark_owned(val);
        }
        et = self._iter_elem_llvm_of(expr);
        return (val, "iter", et if et is not None else i8p);
    }

    ustruct = self._struct_name_of(expr);
    if ustruct is not None and self._arch_implements_iter(ustruct) {
        return self._make_user_iter_from_obj(val, ustruct, expr);
    }
    return None;
}

impl NaIRGenPass._adapter_callee_fn(fn_expr: uni.UniNode) -> (ir.Function | None) {
    named = self.func_symtab.get(self._get_name(fn_expr));
    if named is not None and isinstance(named, ir.Function) {
        return named;
    }
    if isinstance(fn_expr, uni.LambdaExpr) {
        _has_local_caps = False;
        for cap_sym in fn_expr.captures {
            if cap_sym.sym_name in self.local_vars {
                _has_local_caps = True;
                break;
            }
        }
        if _has_local_caps {
            self.emit(
                E5092,
                node_override=fn_expr,
                kind="expression",
                name="capturing lambda as a map/filter callback",
                help_text="A lambda passed to map/filter must not capture enclosing locals; bind the value through the element or use a named function."
            );
            return None;
        }
        lv = self._codegen_lambda(fn_expr);
        if self._pending_lambda_captures is not None {
            self._pending_lambda_captures = None;
            self.emit(
                E5092,
                node_override=fn_expr,
                kind="expression",
                name="capturing lambda as a map/filter callback",
                help_text="A lambda passed to map/filter must not capture enclosing locals; bind the value through the element or use a named function."
            );
            return None;
        }
        if isinstance(lv, ir.Function) {
            return lv;
        }
    }
    return None;
}

impl NaIRGenPass._build_iter_from_expr(expr: uni.UniNode) -> (tuple | None) {
    self._ensure_iter_types();
    if isinstance(expr, uni.FuncCall) {
        cname = self._get_name(expr.target);
        params = expr.params or [];

        if cname in ("map", "filter", "enumerate", "zip", "iter")
        and expr.call_kind != "builtin" {
            cname = None;
        }
        if cname == "map" and len(params) == 2 {
            fn = self._adapter_callee_fn(params[0]);
            up = self._build_iter_from_expr(params[1]);
            if fn is None or up is None {
                return None;
            }
            return self._make_map_iter(up, fn);
        }
        if cname == "filter" and len(params) == 2 {
            pred = self._adapter_callee_fn(params[0]);
            up = self._build_iter_from_expr(params[1]);
            if pred is None or up is None {
                return None;
            }
            return self._make_filter_iter(up, pred);
        }
        if cname == "enumerate" and len(params) >= 1 {
            up = self._build_iter_from_expr(params[0]);
            if up is None {
                return None;
            }
            return self._make_enumerate_iter(up);
        }
        if cname == "zip" and len(params) == 2 {
            up_a = self._build_iter_from_expr(params[0]);
            up_b = self._build_iter_from_expr(params[1]);
            if up_a is None or up_b is None {
                return None;
            }
            return self._make_zip_iter(up_a, up_b);
        }
        if cname == "iter" and len(params) == 1 {
            return self._build_iter_from_expr(params[0]);
        }
    }
    val = self._codegen_expr(expr);
    if val is None {
        return None;
    }
    return self._make_iter_from_value(val, expr);
}

impl NaIRGenPass._make_map_iter(up: tuple, fn: ir.Function) -> (tuple | None) {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i1 = ir.IntType(1);
    (up_val, up_name, up_type) = up;
    out_type = fn.function_type.return_type;
    uid = self._iter_uid;
    self._iter_uid = uid + 1;
    state_ptr_type = self.struct_types["MapIterState"].as_pointer();
    nfty = ir.FunctionType(i1, [i8p, i8p]);
    nfn = ir.Function(self.llvm_module, nfty, name="__iter_next_map_" + str(uid));
    nfn.linkage = "private";
    nfn.args[0].name = "state";
    nfn.args[1].name = "out";
    entry_bb = nfn.append_basic_block("entry");
    apply = nfn.append_basic_block("apply");
    stop = nfn.append_basic_block("stop");
    b = ir.IRBuilder(entry_bb);
    state = b.bitcast(nfn.args[0], state_ptr_type, name="map.state");
    up_slot = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="map.up.slot"
    );
    up_iter = b.load(up_slot, name="map.up");
    tmp = b.alloca(up_type, name="map.tmp");
    got = self._emit_iter_advance(b, up_iter, b.bitcast(tmp, i8p, name="map.tmp.i8"));
    b.cbranch(got, apply, stop);
    b.position_at_end(apply);
    tval = b.load(tmp, name="map.tval");
    uval = b.call(fn, [tval], name="map.uval");
    out_t = b.bitcast(nfn.args[1], out_type.as_pointer(), name="map.out");
    b.store(uval, out_t);
    b.ret(ir.Constant(i1, 1));
    b.position_at_end(stop);
    b.ret(ir.Constant(i1, 0));
    st = self._alloc_iter_struct("MapIterState");
    up_i8 = self.builder.bitcast(up_val, i8p, name="map.up.i8");
    st_slot = self.builder.gep(
        st, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="map.up.field"
    );
    self.builder.store(up_i8, st_slot);
    return (self._make_jac_iter(nfn, st), "adapter", out_type);
}

impl NaIRGenPass._make_filter_iter(up: tuple, pred: ir.Function) -> (tuple | None) {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i1 = ir.IntType(1);
    (up_val, up_name, up_type) = up;
    uid = self._iter_uid;
    self._iter_uid = uid + 1;
    state_ptr_type = self.struct_types["FilterIterState"].as_pointer();
    nfty = ir.FunctionType(i1, [i8p, i8p]);
    nfn = ir.Function(self.llvm_module, nfty, name="__iter_next_filter_" + str(uid));
    nfn.linkage = "private";
    nfn.args[0].name = "state";
    nfn.args[1].name = "out";
    entry_bb = nfn.append_basic_block("entry");
    loop_bb = nfn.append_basic_block("loop");
    test_bb = nfn.append_basic_block("test");
    emit = nfn.append_basic_block("emit");
    stop = nfn.append_basic_block("stop");
    b = ir.IRBuilder(entry_bb);
    state = b.bitcast(nfn.args[0], state_ptr_type, name="flt.state");
    up_slot = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="flt.up.slot"
    );
    up_iter = b.load(up_slot, name="flt.up");
    tmp = b.alloca(up_type, name="flt.tmp");
    tmp_i8 = b.bitcast(tmp, i8p, name="flt.tmp.i8");
    b.branch(loop_bb);
    b.position_at_end(loop_bb);
    got = self._emit_iter_advance(b, up_iter, tmp_i8);
    b.cbranch(got, test_bb, stop);
    b.position_at_end(test_bb);
    tval = b.load(tmp, name="flt.tval");
    keep = b.call(pred, [tval], name="flt.keep");
    keepb = b.icmp_unsigned("!=", keep, ir.Constant(keep.type, 0), name="flt.keepb");
    b.cbranch(keepb, emit, loop_bb);
    b.position_at_end(emit);
    out_t = b.bitcast(nfn.args[1], up_type.as_pointer(), name="flt.out");
    b.store(tval, out_t);
    b.ret(ir.Constant(i1, 1));
    b.position_at_end(stop);
    b.ret(ir.Constant(i1, 0));
    st = self._alloc_iter_struct("FilterIterState");
    up_i8 = self.builder.bitcast(up_val, i8p, name="flt.up.i8");
    st_slot = self.builder.gep(
        st, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="flt.up.field"
    );
    self.builder.store(up_i8, st_slot);
    return (self._make_jac_iter(nfn, st), up_name, up_type);
}

impl NaIRGenPass._make_enumerate_iter(up: tuple) -> (tuple | None) {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    (up_val, up_name, up_type) = up;
    tuple_type = ir.LiteralStructType([i64, up_type]);
    uid = self._iter_uid;
    self._iter_uid = uid + 1;
    state_ptr_type = self.struct_types["EnumerateIterState"].as_pointer();
    nfty = ir.FunctionType(i1, [i8p, i8p]);
    nfn = ir.Function(self.llvm_module, nfty, name="__iter_next_enum_" + str(uid));
    nfn.linkage = "private";
    nfn.args[0].name = "state";
    nfn.args[1].name = "out";
    entry_bb = nfn.append_basic_block("entry");
    emit = nfn.append_basic_block("emit");
    stop = nfn.append_basic_block("stop");
    b = ir.IRBuilder(entry_bb);
    state = b.bitcast(nfn.args[0], state_ptr_type, name="enm.state");
    up_slot = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="enm.up.slot"
    );
    up_iter = b.load(up_slot, name="enm.up");
    idx_slot = b.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="enm.idx.slot"
    );
    idx = b.load(idx_slot, name="enm.idx");
    tmp = b.alloca(up_type, name="enm.tmp");
    got = self._emit_iter_advance(b, up_iter, b.bitcast(tmp, i8p, name="enm.tmp.i8"));
    b.cbranch(got, emit, stop);
    b.position_at_end(emit);
    tval = b.load(tmp, name="enm.tval");
    tup = ir.Constant(tuple_type, ir.Undefined);
    tup = b.insert_value(tup, idx, 0, name="enm.tup0");
    tup = b.insert_value(tup, tval, 1, name="enm.tup1");
    out_t = b.bitcast(nfn.args[1], tuple_type.as_pointer(), name="enm.out");
    b.store(tup, out_t);
    b.store(b.add(idx, ir.Constant(i64, 1), name="enm.idx.next"), idx_slot);
    b.ret(ir.Constant(i1, 1));
    b.position_at_end(stop);
    b.ret(ir.Constant(i1, 0));
    st = self._alloc_iter_struct("EnumerateIterState");
    up_i8 = self.builder.bitcast(up_val, i8p, name="enm.up.i8");
    st_slot = self.builder.gep(
        st, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="enm.up.field"
    );
    self.builder.store(up_i8, st_slot);
    idx_field = self.builder.gep(
        st, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="enm.idx.field"
    );
    self.builder.store(ir.Constant(i64, 0), idx_field);
    return (self._make_jac_iter(nfn, st), "tuple", tuple_type);
}

impl NaIRGenPass._make_zip_iter(up_a: tuple, up_b: tuple) -> (tuple | None) {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i1 = ir.IntType(1);
    (a_val, a_name, a_type) = up_a;
    (b_val, b_name, b_type) = up_b;
    tuple_type = ir.LiteralStructType([a_type, b_type]);
    uid = self._iter_uid;
    self._iter_uid = uid + 1;
    state_ptr_type = self.struct_types["ZipIterState"].as_pointer();
    nfty = ir.FunctionType(i1, [i8p, i8p]);
    nfn = ir.Function(self.llvm_module, nfty, name="__iter_next_zip_" + str(uid));
    nfn.linkage = "private";
    nfn.args[0].name = "state";
    nfn.args[1].name = "out";
    entry_bb = nfn.append_basic_block("entry");
    checkb = nfn.append_basic_block("checkb");
    emit = nfn.append_basic_block("emit");
    stop = nfn.append_basic_block("stop");
    bld = ir.IRBuilder(entry_bb);
    state = bld.bitcast(nfn.args[0], state_ptr_type, name="zip.state");
    a_slot = bld.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="zip.a.slot"
    );
    a_iter = bld.load(a_slot, name="zip.a");
    b_slot = bld.gep(
        state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="zip.b.slot"
    );
    b_iter = bld.load(b_slot, name="zip.b");
    ta = bld.alloca(a_type, name="zip.ta");
    tb = bld.alloca(b_type, name="zip.tb");
    ha = self._emit_iter_advance(bld, a_iter, bld.bitcast(ta, i8p, name="zip.ta.i8"));
    bld.cbranch(ha, checkb, stop);
    bld.position_at_end(checkb);
    hb = self._emit_iter_advance(bld, b_iter, bld.bitcast(tb, i8p, name="zip.tb.i8"));
    bld.cbranch(hb, emit, stop);
    bld.position_at_end(emit);
    av = bld.load(ta, name="zip.av");
    bv = bld.load(tb, name="zip.bv");
    tup = ir.Constant(tuple_type, ir.Undefined);
    tup = bld.insert_value(tup, av, 0, name="zip.tup0");
    tup = bld.insert_value(tup, bv, 1, name="zip.tup1");
    out_t = bld.bitcast(nfn.args[1], tuple_type.as_pointer(), name="zip.out");
    bld.store(tup, out_t);
    bld.ret(ir.Constant(i1, 1));
    bld.position_at_end(stop);
    bld.ret(ir.Constant(i1, 0));
    st = self._alloc_iter_struct("ZipIterState");
    a_i8 = self.builder.bitcast(a_val, i8p, name="zip.a.i8");
    self.builder.store(
        a_i8,
        self.builder.gep(
            st, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="zip.a.field"
        )
    );
    b_i8 = self.builder.bitcast(b_val, i8p, name="zip.b.i8");
    self.builder.store(
        b_i8,
        self.builder.gep(
            st, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="zip.b.field"
        )
    );
    return (self._make_jac_iter(nfn, st), "tuple", tuple_type);
}

impl NaIRGenPass._resolve_method_owner(
    arch_name: str, method_name: str
) -> (str | None) {
    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }
    owner = get_layout_registry(self.ir_in, self.prog).resolve_method_owner(
        arch_name, method_name
    );
    if owner is not None {
        return owner;
    }
    _arch = self.arch_ast_map.get(arch_name);
    if isinstance(_arch, uni.Archetype) {
        _mod = _arch.find_parent_of_type(uni.Module);
        if _mod is not None and _mod is not self.ir_in {
            return get_layout_registry(_mod, self.prog).resolve_method_owner(
                arch_name, method_name
            );
        }
    }
    return None;
}

impl NaIRGenPass._resolve_method(
    arch_name: str, method_name: str
) -> (ir.Function | None) {
    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }
    _reg = get_layout_registry(self.ir_in, self.prog);
    cur: (str | None) = arch_name;
    _guard = 0;
    while cur is not None and _guard < 64 {
        fn = self.method_funcs.get(f"{cur}.{method_name}");
        if fn is not None {
            return fn;
        }
        _parents = _reg.class_parents.get(cur, []);
        cur = _parents[0] if _parents else None;
        _guard += 1;
    }
    owner = self._resolve_method_owner(arch_name, method_name);
    if owner is None {
        return None;
    }
    return self.method_funcs.get(f"{owner}.{method_name}");
}

impl NaIRGenPass._arch_implements_iter(arch_name: str) -> bool {
    return self._resolve_method(arch_name, "__next__") is not None
    or self._resolve_method(arch_name, "__iter__") is not None;
}

impl NaIRGenPass._user_iter_next_fn(
    iter_struct: str, next_method_fn: ir.Function, elem_type: ir.Type
) -> ir.Function {
    key = "user:" + iter_struct;
    if key in self._iter_next_fns {
        return self._iter_next_fns[key];
    }
    if self._exc_raise_fn is None {
        self._declare_exception_runtime();
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i1 = ir.IntType(1);
    exc_state_type = self._get_exception_state_type();

    struct_ptr_type = next_method_fn.function_type.args[0];
    state_ptr_type = self.struct_types["UserIterState"].as_pointer();
    nfty = ir.FunctionType(i1, [i8p, i8p]);
    fn = ir.Function(self.llvm_module, nfty, name="__iter_next_user_" + iter_struct);
    fn.linkage = "private";
    fn.attributes.add("optnone");
    fn.attributes.add("noinline");
    fn.args[0].name = "state";
    fn.args[1].name = "out";
    entry_bb = fn.append_basic_block("entry");
    call_bb = fn.append_basic_block("call");
    caught_bb = fn.append_basic_block("caught");
    stop_bb = fn.append_basic_block("stop");
    reraise_bb = fn.append_basic_block("reraise");
    b = ir.IRBuilder(entry_bb);
    state = b.bitcast(fn.args[0], state_ptr_type, name="usr.state");
    obj_i8 = b.load(
        b.gep(state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="usr.obj.slot"),
        name="usr.obj.i8"
    );
    recv = b.bitcast(obj_i8, struct_ptr_type, name="usr.obj");

    exc_state = b.alloca(exc_state_type, name="usr.exc.state");
    b.call(self._exc_push_fn, [exc_state]);
    env_ptr = b.gep(
        exc_state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="usr.env.ptr"
    );
    env_i8p = b.bitcast(env_ptr, i8p, name="usr.env.i8p");
    sj = b.call(self.extern_funcs["setjmp"], [env_i8p], name="usr.sj");
    is_exc = b.icmp_signed("!=", sj, ir.Constant(i32, 0), name="usr.is.exc");
    b.cbranch(is_exc, caught_bb, call_bb);

    b.position_at_end(call_bb);
    v = b.call(next_method_fn, [recv], name="usr.v");
    b.call(self._exc_pop_fn, []);
    out_t = b.bitcast(fn.args[1], elem_type.as_pointer(), name="usr.out");
    b.store(v, out_t);
    b.ret(ir.Constant(i1, 1));

    b.position_at_end(caught_bb);
    b.call(self._exc_pop_fn, []);
    exc_type_ptr = b.gep(
        exc_state, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="usr.exc.type.ptr"
    );
    exc_type_val = b.load(exc_type_ptr, name="usr.exc.type");
    stop_id = self._get_or_register_exc_type("StopIteration");
    is_stop = b.icmp_signed(
        "==", exc_type_val, ir.Constant(i32, stop_id), name="usr.is.stop"
    );
    b.cbranch(is_stop, stop_bb, reraise_bb);
    b.position_at_end(stop_bb);
    b.ret(ir.Constant(i1, 0));
    b.position_at_end(reraise_bb);
    exc_obj_ptr = b.gep(
        exc_state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="usr.exc.obj.ptr"
    );
    reraise_obj = b.load(exc_obj_ptr, name="usr.reraise.obj");
    exc_msg_slot = b.gep(
        exc_state, [ir.Constant(i32, 0), ir.Constant(i32, 4)], name="usr.exc.msg.ptr"
    );
    reraise_msg = b.load(exc_msg_slot, name="usr.reraise.msg");
    b.call(self._exc_raise_fn, [reraise_obj, exc_type_val, reraise_msg]);
    b.unreachable();
    self._iter_next_fns[key] = fn;
    return fn;
}

impl NaIRGenPass._make_user_iter(it_obj: ir.Value, iter_struct: str) -> (tuple | None) {
    next_method_fn = self._resolve_method(iter_struct, "__next__");
    if next_method_fn is None {
        return None;
    }
    elem_type = next_method_fn.function_type.return_type;
    next_fn = self._user_iter_next_fn(iter_struct, next_method_fn, elem_type);
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    st = self._alloc_iter_struct("UserIterState");
    obj_i8 = self.builder.bitcast(it_obj, i8p, name="usr.obj.store");
    self.builder.store(
        obj_i8,
        self.builder.gep(
            st, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="usr.obj.field"
        )
    );
    return (self._make_jac_iter(next_fn, st), "user", elem_type);
}

impl NaIRGenPass._make_user_iter_from_obj(
    obj_val: ir.Value, struct_name: str, expr: uni.UniNode
) -> (tuple | None) {
    if self._resolve_method(struct_name, "__next__") is not None {
        it_obj = obj_val;
        iter_struct = struct_name;
        if not self._is_owned(it_obj) {
            self._emit_rc_retain(it_obj, op="user_iter");
            self._mark_owned(it_obj);
        }
        return self._make_user_iter(it_obj, iter_struct);
    }
    iter_fn = self._resolve_method(struct_name, "__iter__");
    if iter_fn is None {
        return None;
    }
    it_obj = self.builder.call(iter_fn, [obj_val], name="usr.iter");
    self._mark_owned(it_obj);

    iter_struct = self._infer_type_name(it_obj);
    built = self._make_user_iter(it_obj, iter_struct)
        if iter_struct is not None
        else None;
    if built is None {
        self._emit_rc_release_simple(it_obj, op="user_iter_unresolved");
        return None;
    }

    if self._is_owned(obj_val) {
        self._emit_rc_release_simple(obj_val, op="user_iter_src");
    }
    return built;
}

impl NaIRGenPass._codegen_next(nd: uni.FuncCall) -> (ir.Value | None) {
    params = nd.params or [];
    if len(params) != 1 {
        self._emit_unsupported_builtin_call(nd, "next");
        return None;
    }
    arg = params[0];
    elem_type = self._iter_elem_llvm_of(arg);
    iter_val = self._codegen_expr(arg);
    if iter_val is None or elem_type is None {
        self._emit_unsupported_builtin_call(nd, "next");
        return None;
    }
    self._ensure_iter_types();
    i1 = ir.IntType(1);
    i8p = ir.IntType(8).as_pointer();
    out_slot = self._entry_alloca(elem_type, "next.out");
    out_i8 = self.builder.bitcast(out_slot, i8p, name="next.out.i8");
    got = self._emit_iter_advance(self.builder, iter_val, out_i8);
    is_stop = self.builder.icmp_unsigned(
        "==", got, ir.Constant(i1, 0), name="next.stop"
    );
    self._emit_runtime_raise(is_stop, "StopIteration", "");
    return self.builder.load(out_slot, name="next.val");
}

impl NaIRGenPass._try_iter_protocol_for(nd: uni.InForStmt) -> bool {
    coll = nd.collection;
    self._ensure_iter_types();

    is_adapter_call = (
        isinstance(coll, uni.FuncCall)
        and self._get_name(coll.target) in ["map", "filter", "enumerate", "zip", "iter"]
        and coll.call_kind == "builtin"
    );

    _ustruct = self._struct_name_of(coll) if not is_adapter_call else None;
    is_user_iterable = _ustruct is not None and self._arch_implements_iter(_ustruct);
    built: (tuple | None) = None;
    owns_iter = False;
    if is_adapter_call or is_user_iterable {
        built = self._build_iter_from_expr(coll);
        owns_iter = True;
    } else {
        elem_t = self._iter_elem_llvm_of(coll);
        if elem_t is not None {
            iv = self._codegen_expr(coll);
            if iv is not None {
                ename = "tuple" if isinstance(elem_t, ir.LiteralStructType) else "iter";
                built = (iv, ename, elem_t);
                owns_iter = self._is_owned(iv);
            }
        }
    }
    if built is None {
        return False;
    }
    (iter_val, elem_name, elem_type) = built;
    i8p = ir.IntType(8).as_pointer();
    _loc = "iter_for";
    is_tuple_target = isinstance(nd.target, uni.TupleVal);

    _gen_it_spill: (ir.Value | None) = None;
    if self._gen_ctx is not None
    and self.builder.function is self._gen_ctx["resume_fn"] {
        _gen_it_spill = self._entry_alloca(iter_val.type, "iterf.itslot");
        self.builder.store(iter_val, _gen_it_spill);
    }

    elem_slot = self._entry_alloca(elem_type, "iter.elem");
    a0: (ir.Value | None) = None;
    a1: (ir.Value | None) = None;
    if is_tuple_target {
        targets = nd.target.values or [];
        if len(targets) != 2 {
            return False;
        }
        t0_type = elem_type.elements[0];
        t1_type = elem_type.elements[1];
        n0 = self._get_name(targets[0]);
        n1 = self._get_name(targets[1]);
        a0 = self._entry_alloca(t0_type, n0);
        a1 = self._entry_alloca(t1_type, n1);
        self.local_vars[n0] = a0;
        self.local_vars[n1] = a1;
    } else {
        loop_var_name = self._get_name(nd.target);
        self.local_vars[loop_var_name] = elem_slot;
    }
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="iterf.cond");
    body_bb = func.append_basic_block(name="iterf.body");
    end_bb = func.append_basic_block(name="iterf.end");
    self.builder.branch(cond_bb);
    self.builder.position_at_end(cond_bb);
    if _gen_it_spill is not None {
        iter_val = self.builder.load(_gen_it_spill, name="iterf.it");
    }
    out_i8 = self.builder.bitcast(elem_slot, i8p, name="iterf.out");
    got = self._emit_iter_advance(self.builder, iter_val, out_i8);
    self.builder.cbranch(got, body_bb, end_bb);
    self.loop_stack.append((cond_bb, end_bb));
    self.builder.position_at_end(body_bb);
    if is_tuple_target {
        tup = self.builder.load(elem_slot, name="iterf.tup");
        self.builder.store(self.builder.extract_value(tup, 0, name="iterf.t0"), a0);
        self.builder.store(self.builder.extract_value(tup, 1, name="iterf.t1"), a1);
    }
    import from jaclang.compiler.passes.main.rc_facts_pass { loop_body_locals }
    _saved = loop_body_locals(nd.body if isinstance(nd.body, (list, tuple)) else None);

    _iter_prebody = set(self.local_vars.keys());
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    if not self.builder.block.is_terminated {
        self._emit_loop_iter_cleanup(
            [
                _v
                for _v in _saved
                if _v not in _iter_prebody
            ],
            loc=_loc
        );
        self.builder.branch(cond_bb);
    }
    self.loop_stack.pop();
    self.builder.position_at_end(end_bb);

    if _gen_it_spill is not None {
        iter_val = self.builder.load(_gen_it_spill, name="iterf.it.end");
    }
    if owns_iter {
        self._emit_rc_release_simple(iter_val, op="iter_end", loc=_loc);
    }
    return True;
}
