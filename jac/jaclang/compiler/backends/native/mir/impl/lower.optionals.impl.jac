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

impl MirLowering.opt_end(held: MirValue, absent_value: MirValue, done: MirBlock) -> MirValue {
    b = self.builder();
    b.store(held, self.coerce(absent_value, held.type, self.module));
    b.branch(done);
    b.position(done);
    return b.load(held, held.type);
}
