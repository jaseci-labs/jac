impl NaIRGenPass._hash_order_extent_ptr(
    b: ir.IRBuilder, order: ir.Value, capacity: ir.Value
) -> ir.Value {
    return b.gep(
        order, [b.mul(capacity, ir.Constant(ir.IntType(64), 2))], name="order.extent.p"
    );
}

impl NaIRGenPass._hash_order_position_ptr(
    b: ir.IRBuilder, order: ir.Value, capacity: ir.Value, slot: ir.Value
) -> ir.Value {
    return b.gep(order, [b.add(capacity, slot)], name="order.position.p");
}

impl NaIRGenPass._hash_order_alloc(b: ir.IRBuilder, capacity: ir.Value) -> ir.Value {
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    malloc_fn = self._get_or_declare_extern("malloc", i8p, [i64]);
    count = b.add(b.mul(capacity, ir.Constant(i64, 2)), ir.Constant(i64, 1));
    raw = b.call(malloc_fn, [b.mul(count, ir.Constant(i64, 8))], name="order.raw");
    order = b.bitcast(raw, i64.as_pointer(), name="order.array");
    b.store(ir.Constant(i64, 0), self._hash_order_extent_ptr(b, order, capacity));
    return order;
}

impl NaIRGenPass._emit_hash_order_compact_fn(
    name: str, container_type: ir.Type, layout: dict
) -> ir.Function {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    fn = ir.Function(
        self.llvm_module, ir.FunctionType(ir.VoidType(), [container_type]), name=name
    );
    fn.linkage = "private";
    b = ir.IRBuilder(fn.append_basic_block("entry"));
    container = fn.args[0];
    capacity = b.load(b.gep(container, [ir.Constant(i32, 0), ir.Constant(i32, 1)]));
    length = b.load(b.gep(container, [ir.Constant(i32, 0), ir.Constant(i32, 0)]));
    order = b.load(
        b.gep(container, [ir.Constant(i32, 0), ir.Constant(i32, layout["order_idx"])])
    );
    extent_ptr = self._hash_order_extent_ptr(b, order, capacity);
    extent = b.load(extent_ptr);
    read_ptr = b.alloca(i64, name="order.read");
    write_ptr = b.alloca(i64, name="order.write");
    b.store(ir.Constant(i64, 0), read_ptr);
    b.store(ir.Constant(i64, 0), write_ptr);
    scan = fn.append_basic_block("scan");
    check = fn.append_basic_block("check");
    copy = fn.append_basic_block("copy");
    advance = fn.append_basic_block("advance");
    finish = fn.append_basic_block("finish");
    done = fn.append_basic_block("done");
    b.cbranch(b.icmp_unsigned("==", extent, length), done, scan);
    bs = ir.IRBuilder(scan);
    read = bs.load(read_ptr);
    bs.cbranch(bs.icmp_unsigned("<", read, extent), check, finish);
    bc = ir.IRBuilder(check);
    slot = bc.load(bc.gep(order, [read]));
    bc.cbranch(bc.icmp_signed(">=", slot, ir.Constant(i64, 0)), copy, advance);
    bw = ir.IRBuilder(copy);
    write = bw.load(write_ptr);
    bw.store(slot, bw.gep(order, [write]));
    bw.store(write, self._hash_order_position_ptr(bw, order, capacity, slot));
    bw.store(bw.add(write, ir.Constant(i64, 1)), write_ptr);
    bw.branch(advance);
    ba = ir.IRBuilder(advance);
    ba.store(ba.add(read, ir.Constant(i64, 1)), read_ptr);
    ba.branch(scan);
    bf = ir.IRBuilder(finish);
    bf.store(bf.load(write_ptr), extent_ptr);
    bf.branch(done);
    ir.IRBuilder(done).ret_void();
    return fn;
}

impl NaIRGenPass._emit_hash_order_remove_fn(
    name: str, container_type: ir.Type, layout: dict
) -> ir.Function {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    fn = ir.Function(
        self.llvm_module,
        ir.FunctionType(ir.VoidType(), [container_type, i64]),
        name=name
    );
    fn.linkage = "private";
    b = ir.IRBuilder(fn.append_basic_block("entry"));
    container = fn.args[0];
    slot = fn.args[1];
    capacity = b.load(b.gep(container, [ir.Constant(i32, 0), ir.Constant(i32, 1)]));
    order = b.load(
        b.gep(container, [ir.Constant(i32, 0), ir.Constant(i32, layout["order_idx"])])
    );
    position = b.load(self._hash_order_position_ptr(b, order, capacity, slot));
    b.store(ir.Constant(i64, -1), b.gep(order, [position]));
    extent_ptr = self._hash_order_extent_ptr(b, order, capacity);
    scan = fn.append_basic_block("trim");
    check = fn.append_basic_block("check");
    shrink = fn.append_basic_block("shrink");
    done = fn.append_basic_block("done");
    b.branch(scan);
    bs = ir.IRBuilder(scan);
    extent = bs.load(extent_ptr);
    bs.cbranch(bs.icmp_unsigned(">", extent, ir.Constant(i64, 0)), check, done);
    bc = ir.IRBuilder(check);
    last = bc.sub(extent, ir.Constant(i64, 1));
    tail = bc.load(bc.gep(order, [last]));
    bc.cbranch(bc.icmp_signed("<", tail, ir.Constant(i64, 0)), shrink, done);
    bh = ir.IRBuilder(shrink);
    bh.store(last, extent_ptr);
    bh.branch(scan);
    ir.IRBuilder(done).ret_void();
    return fn;
}
