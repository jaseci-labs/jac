"""Iterator protocol codegen (#6403).

A first-class iterator is a boxed `JacIter` { i64 next_fn, i8* state }:
  - next_fn: ptrtoint of a uniform `i1 (i8* state, i8* out)` function
  - state:   pointer to a per-kind RC state struct

`next(state, out)` writes the next element through `out` and returns 1, or
returns 0 at exhaustion (no exception in the hot path). The for-loop drives
any JacIter; adapters (map/filter/enumerate/zip) wrap an upstream JacIter and
pull from it, so they compose and stay lazy with no generator machinery.

Ownership: building an iterator yields a +1 reference. Wrapping transfers that
reference to the parent (no retain); the bottom container is *borrowed* (stored
as an i64, never released). The for-loop releases the outermost iterator once,
and the generic struct destructor cascades the release down the chain.
"""

# ─── Struct registration ─────────────────────────────────────
"""Register the JacIter box and the per-kind state structs (once)."""
impl NaIRGenPass._ensure_iter_types -> None {
    if self._iter_structs_registered {
        return;
    }
    self._iter_structs_registered = True;
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    self._register_iter_struct("JacIter", ["next_fn", "state"], [i64, i8p]);
    self._jac_iter_type = self.struct_types["JacIter"];
    # coll/s stored as i64 (ptrtoint) so the generic dtor BORROWS them.
    self._register_iter_struct("ListIterState", ["coll", "idx"], [i64, i64]);
    self._register_iter_struct("StrIterState", ["s", "idx"], [i64, i64]);
    # upstream stored as i8* so the generic dtor OWNS (releases) it.
    self._register_iter_struct("MapIterState", ["upstream"], [i8p]);
    self._register_iter_struct("FilterIterState", ["upstream"], [i8p]);
    self._register_iter_struct("EnumerateIterState", ["upstream", "idx"], [i8p, i64]);
    self._register_iter_struct("ZipIterState", ["up_a", "up_b"], [i8p, i8p]);
}

"""Register an identified struct + its field index/type maps."""
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

"""rc_alloc a registered struct and install its destructor pointer."""
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

# ─── JacIter box + advance ───────────────────────────────────
"""Box a next-fn + state pointer into a fresh JacIter (transfers state ref)."""
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

"""Emit a call to iter_val.next(state, out) using the given builder."""
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

# ─── Container iterators ─────────────────────────────────────
"""Monomorphic next-fn for a list[T]: yield data[idx], idx++."""
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

"""Build a ListIter over list_val (borrows the list)."""
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

"""Monomorphic next-fn for a string: yield the 1-char string at idx."""
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
    # Extract the 1-char string at idx (inline; builder-local).
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

"""Build a StrIter over str_val (borrows the string)."""
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

# ─── Iterator construction from an expression ────────────────
"""Make an iterator from an already-codegen'd value (list/str/JacIter)."""
impl NaIRGenPass._make_iter_from_value(
    val: ir.Value, expr: uni.UniNode
) -> (tuple | None) {
    i8p = ir.IntType(8).as_pointer();
    for (lk, lt) in self.list_types.items() {
        if val.type == lt.as_pointer() {
            elem_type = self.list_helpers[lk]["elem_type"];
            return (self._make_list_iter(val, lk, elem_type), lk, elem_type);
        }
    }
    if isinstance(val.type, ir.PointerType) and val.type == i8p {
        return (self._make_str_iter(val), "str", i8p);
    }
    if self._jac_iter_type is not None
    and val.type == self._jac_iter_type.as_pointer() {
        # Already an iterator value; element type unknown from the value alone.
        # Returned with i8* placeholder — only valid where elem type is tracked.
        return (val, "iter", i8p);
    }
    return None;
}

"""Recursively build a JacIter from an AST expr (handles adapter nesting)."""
impl NaIRGenPass._build_iter_from_expr(expr: uni.UniNode) -> (tuple | None) {
    self._ensure_iter_types();
    if isinstance(expr, uni.FuncCall) {
        cname = self._get_name(expr.target);
        params = expr.params or [];
        if cname == "map" and len(params) == 2 {
            fn = self.func_symtab.get(self._get_name(params[0]));
            up = self._build_iter_from_expr(params[1]);
            if fn is None or up is None {
                return None;
            }
            return self._make_map_iter(up, fn);
        }
        if cname == "filter" and len(params) == 2 {
            pred = self.func_symtab.get(self._get_name(params[0]));
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

# ─── Adapter iterators ───────────────────────────────────────
"""map(fn, upstream): yield fn(x) for x in upstream."""
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

"""filter(pred, upstream): yield x for x in upstream if pred(x)."""
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

"""enumerate(upstream): yield (i, x) tuples with a running index."""
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

"""zip(a, b): yield (a_i, b_i) until either upstream is exhausted."""
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

# ─── Generalized for-loop drive ──────────────────────────────
"""Drive `for x in <iterator-producing expr>` via the protocol.

Returns True if it handled the loop_bb (collection is map/filter/enumerate/zip/
iter). Container collections (plain list/str/dict/range) fall through to the
existing fast paths.
"""
impl NaIRGenPass._try_iter_protocol_for(nd: uni.InForStmt) -> bool {
    coll = nd.collection;
    if not isinstance(coll, uni.FuncCall) {
        return False;
    }
    self._ensure_iter_types();
    cname = self._get_name(coll.target);
    if cname not in ["map", "filter", "enumerate", "zip", "iter"] {
        return False;
    }
    built = self._build_iter_from_expr(coll);
    if built is None {
        return False;
    }
    (iter_val, elem_name, elem_type) = built;
    i8p = ir.IntType(8).as_pointer();
    _loc = "iter_for";
    is_tuple_target = isinstance(nd.target, uni.TupleVal);
    # Element slot the next-fn writes into.
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
    _saved = set(self.local_vars.keys());
    if isinstance(nd.body, (list, tuple)) {
        self._codegen_body(nd.body);
    }
    if not self.builder.block.is_terminated {
        self._emit_loop_iter_cleanup(_saved, loc=_loc);
        self.builder.branch(cond_bb);
    }
    self.loop_stack.pop();
    self.builder.position_at_end(end_bb);
    self._emit_rc_release_simple(iter_val, op="iter_end", loc=_loc);
    return True;
}
