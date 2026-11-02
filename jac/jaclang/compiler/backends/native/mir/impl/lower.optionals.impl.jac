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
    seen = nd.narrowed_type if nd.narrowed_type is not None else nd.type;
    if value.type.kind != MirKind.OPT
        or seen is None
        or isinstance(seen, (UnionType, AnyType)) {
        return value;
    }
    if self.type_of(seen, MirPosition.VALUE, nd).kind == MirKind.OPT {
        return value;
    }
    return self.opt_unwrap_checked(
        value, "'NoneType' object found where a value was required"
    );
}

impl MirLowering.narrow_down(value: MirValue, nd: uni.Expr) -> MirValue {
    seen = nd.narrowed_type if nd.narrowed_type is not None else nd.type;
    if value.type.kind != MirKind.OBJ
        or seen is None
        or isinstance(seen, (UnionType, AnyType)) {
        return value;
    }
    narrowed = self.type_of(seen, MirPosition.VALUE, nd);
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
    if value.type.kind in (MirKind.OPT, MirKind.NONE)
        and wanted.kind not in (MirKind.OPT, MirKind.NONE) {
        exception = "TypeError";
        message = "'NoneType' object cast to a value";
        user: (uni.UniNode | None) = nd;
        while isinstance(user.parent, uni.AtomUnit) {
            user = user.parent;
        }
        access = user.parent;
        if isinstance(access, uni.AtomTrailer)
            and access.is_attr
            and access.target is user
            and isinstance(access.right, uni.Name) {
            exception = "AttributeError";
            message = f"'NoneType' object has no attribute '{access.right.value}'";
        }
        b = self.builder();
        if value.type.kind == MirKind.NONE {
            b.raise_builtin(exception, message);
            b.position(self.st().fn.new_block("cast.dead"));
            return b.const_null(wanted);
        }
        held = self.spill(value);
        self.raise_if(b.logical_not(self.opt_present(held)), exception, message);
        return self.narrow_down(self.opt_get(held), nd);
    }
    narrowed = self.narrow_down(value, nd);
    have = narrowed.type;
    if have is not wanted
        and have.kind == wanted.kind
        and wanted.kind in (MirKind.OBJ, MirKind.LIST, MirKind.SET, MirKind.DICT)
        and len(have.args) == len(wanted.args)
        and all(
            mine is theirs or (mine.kind == MirKind.OBJ and theirs.kind == MirKind.OBJ)
            for (mine, theirs) in zip(have.args, wanted.args)
        ) {
        return self.builder().ref_cast(narrowed, wanted, False);
    }
    return narrowed;
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

impl MirLowering.opt_recast(
    value: MirValue, to: MirType, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    source = self.spill(value);
    held = self.temp_slot(to);
    some = fn.new_block("opt.recast.some");
    none = fn.new_block("opt.recast.none");
    done = fn.new_block("opt.recast.done");
    b.cond_branch(self.opt_present(source), some, none);
    b.position(some);
    b.store(
        held, self.opt_wrap(self.coerce(self.opt_get(source), to.payload(), site), to)
    );
    b.branch(done);
    b.position(none);
    b.store(held, b.const_null(to));
    b.branch(done);
    b.position(done);
    return b.load(held, to);
}
