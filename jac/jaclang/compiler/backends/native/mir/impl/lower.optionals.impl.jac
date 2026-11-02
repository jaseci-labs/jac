impl MirLowering.none_value -> MirValue {
    return self.st().fn.new_value(mir_none(), "none");
}

impl MirLowering.opt_wrap(value: MirValue, to: MirType) -> MirValue {
    return self.emit_value(MirOp.OPT_MAKE, to, [value]);
}

impl MirLowering.opt_present(value: MirValue) -> MirValue {
    return self.emit_value(MirOp.OPT_PRESENT, mir_bool(), [value]);
}

impl MirLowering.opt_get(value: MirValue) -> MirValue {
    return self.emit_value(MirOp.OPT_GET, value.type.payload(), [value]);
}

impl MirLowering.opt_unwrap_checked(value: MirValue, message: str) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    held = self.spill(value);
    absent = fn.new_block("opt.isnone");
    present = fn.new_block("opt.some");
    b.cond_branch(self.opt_present(held), present, absent);
    b.position(absent);
    b.raise_builtin("TypeError", message);
    b.position(present);
    return self.opt_get(held);
}

impl MirLowering.narrowed_load(value: MirValue, nd: uni.Expr) -> MirValue {
    if value.type.kind != MirKind.OPT
        or nd.type is None
        or isinstance(nd.type, (UnionType, AnyType)) {
        return value;
    }
    if self.expr_type(nd).kind == MirKind.OPT {
        return value;
    }
    return self.opt_unwrap_checked(value, "'NoneType' object found where a value was required");
}

impl MirLowering.narrow_down(value: MirValue, nd: uni.Expr) -> MirValue {
    if value.type.kind != MirKind.OBJ
        or nd.type is None
        or isinstance(nd.type, (UnionType, AnyType)) {
        return value;
    }
    narrowed = self.expr_type(nd);
    if narrowed.kind == MirKind.OBJ
        and narrowed is not value.type
        and self.obj_extends(narrowed.name, value.type.name) {
        return self.builder().ref_cast(value, narrowed, False);
    }
    return value;
}

impl MirLowering.opt_begin(
    value: MirValue, result: MirType
) -> tuple[MirValue, MirValue, MirBlock, MirBlock] {
    b = self.builder();
    fn = self.st().fn;
    held = self.temp_slot(result);
    source = self.spill(value);
    present = fn.new_block("opt.some");
    absent = fn.new_block("opt.none");
    done = fn.new_block("opt.done");
    b.cond_branch(self.opt_present(source), present, absent);
    b.position(present);
    return (held, self.opt_get(source), absent, done);
}

impl MirLowering.opt_switch(
    held: MirValue, present_value: MirValue, absent: MirBlock, done: MirBlock
) {
    b = self.builder();
    b.store(held, self.coerce(present_value, held.type, self.module));
    b.branch(done);
    b.position(absent);
}

impl MirLowering.opt_end(
    held: MirValue, absent_value: MirValue, done: MirBlock
) -> MirValue {
    b = self.builder();
    b.store(held, self.coerce(absent_value, held.type, self.module));
    b.branch(done);
    b.position(done);
    return b.load(held, held.type);
}
