impl MirLowering.any_tag(t: MirType, site: uni.UniNode) -> int {
    if t.kind == MirKind.INT {
        return ANY_INT_TAG;
    }
    if t.kind == MirKind.FLOAT {
        return ANY_FLOAT_TAG;
    }
    if t.kind == MirKind.BOOL {
        return ANY_BOOL_TAG;
    }
    if t.kind == MirKind.NONE {
        return ANY_NONE_TAG;
    }
    if t.kind in (MirKind.STR, MirKind.STR_REF) {
        return ANY_STR_TAG;
    }
    if t.kind == MirKind.LIST {
        return ANY_LIST_TAG;
    }
    if t.kind == MirKind.DICT {
        return ANY_DICT_TAG;
    }
    if t.kind == MirKind.SET {
        return ANY_SET_TAG;
    }
    if t.kind in (MirKind.OBJ, MirKind.FN) {
        return ANY_OBJ_TAG;
    }
    raise MirRefused(mir_refusal("conversion", f"{t.render()} to any", site));
}

impl MirLowering.any_box(value: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    if value.type.kind == MirKind.ANY {
        return value;
    }
    if value.type.kind == MirKind.NONE {
        return self.any_none();
    }
    if value.type.kind == MirKind.OPT {
        (held, payload, absent, done) = self.opt_begin(value, mir_any());
        self.opt_switch(held, self.any_box(payload, site), absent, done);
        return self.opt_end(held, self.any_none(), done);
    }
    source = value;
    if value.type.kind == MirKind.STR {
        made = self.runtime(
            "__jac_rt_str_ref",
            [b.str_part(value, "root"), b.str_part(value, "data"), b.str_part(value, "len")]
        );
        if made is None {
            raise MirRefused(mir_refusal("conversion", "str to any", site));
        }
        source = made;
    }
    return self.emit_value(
        MirOp.ANY_BOX, mir_any(), [source], int_value=self.any_tag(source.type, site)
    );
}

impl MirLowering.any_make(tag: MirValue, payload: MirValue) -> MirValue {
    return self.emit_value(MirOp.ANY_MAKE, mir_any(), [tag, payload]);
}

impl MirLowering.any_none -> MirValue {
    b = self.builder();
    made = self.any_make(b.const_int(ANY_NONE_TAG, mir_int()), b.const_int(0, mir_int()));
    made.owned = True;
    return made;
}

impl MirLowering.any_unbox(value: MirValue, to: MirType, site: uni.UniNode) -> MirValue {
    b = self.builder();
    if to.kind == MirKind.ANY {
        return value;
    }
    if to.kind == MirKind.NONE {
        return self.none_value();
    }
    if to.kind in (MirKind.INT, MirKind.BOOL, MirKind.FLOAT) {
        bits = self.emit_value(MirOp.ANY_PAYLOAD, mir_int(), [value]);
        if to.kind == MirKind.BOOL {
            return b.compare("ne", bits, b.const_int(0, mir_int()));
        }
        if to.kind == MirKind.FLOAT {
            return b.convert(self.emit_value(MirOp.BITCAST, mir_float(), [bits]), to);
        }
        return b.convert(bits, to);
    }
    held = self.spill(value);
    if to.kind == MirKind.STR {
        text = b.ref_cast(held, mir_str_ref(), False);
        size = self.runtime("__jac_rt_str_size", [text]);
        if size is None {
            raise MirRefused(mir_refusal("conversion", "any to str", site));
        }
        return b.str_make(text, text, size);
    }
    if to.kind == MirKind.OPT {
        tag = self.emit_value(MirOp.ANY_TAG, mir_int(), [held]);
        present = b.compare("ne", tag, b.const_int(ANY_NONE_TAG, mir_int()));
        inner = self.any_unbox(held, to.payload(), site);
        return b.select(present, self.opt_wrap(inner, to), b.const_null(to));
    }
    if mir_holds_ref(to) and to.kind != MirKind.TUPLE {
        return b.ref_cast(held, to, False);
    }
    raise MirRefused(mir_refusal("conversion", f"any to {to.render()}", site));
}

impl MirLowering.any_to_box(value: MirValue, site: uni.UniNode) -> MirValue {
    whole = self.any_box(value, site);
    box = self.runtime(
        "__jac_rt_any_box",
        [
            self.emit_value(MirOp.ANY_TAG, mir_int(), [whole]),
            self.emit_value(MirOp.ANY_PAYLOAD, mir_int(), [whole])
        ]
    );
    if box is None {
        raise MirRefused(mir_refusal("container element", "any", site));
    }
    return box;
}

impl MirLowering.any_from_box(handle: MirValue) -> MirValue {
    b = self.builder();
    address = self.address_of(handle);
    tag = self.emit_value(MirOp.MEM_LOAD, mir_int(), [address]);
    payload = self.emit_value(
        MirOp.MEM_LOAD, mir_int(), [b.binary("add", address, b.const_int(8, mir_int()))]
    );
    self.runtime("__jac_rt_any_retain", [tag, payload]);
    made = self.any_make(tag, payload);
    made.owned = True;
    return made;
}

impl MirLowering.identity(left: MirValue, right: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    if left.type.kind == MirKind.ANY or right.type.kind == MirKind.ANY {
        l = self.any_box(left, site);
        r = self.any_box(right, site);
        same_tag = b.compare(
            "eq",
            self.emit_value(MirOp.ANY_TAG, mir_int(), [l]),
            self.emit_value(MirOp.ANY_TAG, mir_int(), [r])
        );
        same_payload = b.compare(
            "eq",
            self.emit_value(MirOp.ANY_PAYLOAD, mir_int(), [l]),
            self.emit_value(MirOp.ANY_PAYLOAD, mir_int(), [r])
        );
        return b.binary("and", same_tag, same_payload);
    }
    if mir_holds_ref(left.type)
        and mir_holds_ref(right.type)
        and left.type.kind not in (MirKind.STR, MirKind.OPT, MirKind.TUPLE)
        and right.type.kind not in (MirKind.STR, MirKind.OPT, MirKind.TUPLE) {
        return b.compare("eq", self.address_of(left), self.address_of(right));
    }
    if left.type.is_numeric() and right.type.is_numeric() {
        (l, r) = self.unify_numeric(left, right, site);
        return b.compare("eq", l, r);
    }
    raise MirRefused(
        mir_refusal("comparison", f"{left.type.render()} is {right.type.render()}", site)
    );
}
