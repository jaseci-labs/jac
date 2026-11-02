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
    return self.opt_unwrap_checked(
        value, "'NoneType' object found where a value was required"
    );
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

impl MirLowering.optional_eq(
    left: MirValue, right: MirValue, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    held = self.temp_slot(mir_bool());
    lh = self.spill(left);
    rh = self.spill(right);
    left_some = self.opt_present(lh)
        if lh.type.kind == MirKind.OPT
        else b.const_bool(True);
    right_some = self.opt_present(rh)
        if rh.type.kind == MirKind.OPT
        else b.const_bool(True);
    b.store(held, b.compare("eq", left_some, right_some));
    both = fn.new_block("opt.eq.both");
    done = fn.new_block("opt.eq.done");
    b.cond_branch(b.binary("and", left_some, right_some), both, done);
    b.position(both);
    lv = self.opt_get(lh) if lh.type.kind == MirKind.OPT else lh;
    rv = self.opt_get(rh) if rh.type.kind == MirKind.OPT else rh;
    b.store(held, self.compare_values(Tok.EE, lv, rv, site));
    self.builder().branch(done);
    b.position(done);
    return b.load(held, mir_bool());
}

impl MirLowering.lower_cast(nd: uni.CastExpr) -> MirValue {
    value = self.lower_expr(nd.value);
    if nd.type is None or isinstance(nd.type, (UnionType, AnyType)) {
        return value;
    }
    wanted = self.expr_type(nd);
    if value.type is wanted {
        return value;
    }
    if value.type.kind == MirKind.ANY {
        return self.any_unbox(value, wanted, nd);
    }
    if value.type.kind == MirKind.OPT and wanted.kind != MirKind.OPT {
        return self.narrow_down(
            self.opt_unwrap_checked(value, "'NoneType' object cast to a value"), nd
        );
    }
    return self.narrow_down(value, nd);
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
