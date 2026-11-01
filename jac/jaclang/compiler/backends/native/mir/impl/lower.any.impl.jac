impl MirLowering.any_tag(t: MirType, site: uni.UniNode) -> int {
    if t.kind in (MirKind.INT, MirKind.ENUM) {
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

impl MirLowering.is_absent(value: MirValue) -> MirValue {
    b = self.builder();
    if value.type.kind == MirKind.OPT {
        return b.logical_not(self.opt_present(value));
    }
    if value.type.kind == MirKind.ANY {
        return b.compare(
            "eq",
            self.emit_value(MirOp.ANY_TAG, mir_int(), [value]),
            b.const_int(ANY_NONE_TAG, mir_int())
        );
    }
    return b.const_bool(value.type.kind == MirKind.NONE);
}

impl MirLowering.value_truthy(value: MirValue, site: uni.UniNode) -> (MirValue | None) {
    b = self.builder();
    if value.type.kind == MirKind.ANY {
        return self.runtime_value(
            "__jac_rt_any_truthy",
            [
                self.emit_value(MirOp.ANY_TAG, mir_int(), [value]),
                self.emit_value(MirOp.ANY_PAYLOAD, mir_int(), [value])
            ]
        );
    }
    if value.type.kind == MirKind.ENUM {
        return b.const_bool(True);
    }
    if value.type.kind == MirKind.RANGE {
        cursor = self.iter_open(value, site);
        if cursor.position is None or cursor.limit is None or cursor.stride is None {
            raise RuntimeError("range cursor without bounds");
        }
        now = b.load(cursor.position, mir_int());
        end = b.load(cursor.limit, mir_int());
        return b.select(
            b.compare("gt", b.load(cursor.stride, mir_int()), b.const_int(0, mir_int())),
            b.compare("lt", now, end),
            b.compare("gt", now, end)
        );
    }
    return None;
}

impl MirLowering.any_to_str(value: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    made = self.spill(
        self.runtime_value(
            "__jac_rt_any_str",
            [
                self.emit_value(MirOp.ANY_TAG, mir_int(), [value]),
                self.emit_value(MirOp.ANY_PAYLOAD, mir_int(), [value])
            ]
        )
    );
    self.raise_if(
        b.compare("eq", self.address_of(made), b.const_int(0, mir_int())),
        "TypeError",
        "str() of this boxed value is not lowered natively"
    );
    return b.str_make(made, made, self.runtime_value("__jac_rt_str_size", [made]));
}

impl MirLowering.narrow(value: MirValue, nd: uni.Name) -> MirValue {
    if nd.type is None or isinstance(nd.type, (UnionType, AnyType)) {
        return value;
    }
    narrowed = self.type_of(nd.type, MirPosition.VALUE, nd);
    if narrowed.kind == MirKind.ANY {
        return value;
    }
    return self.any_unbox(value, narrowed, nd);
}

impl MirLowering.type_names(target: uni.Expr) -> (list[str] | None) {
    items = [part for part in target.values if isinstance(part, uni.Expr)]
        if isinstance(target, uni.TupleVal)
        else [target];
    names: list[str] = [];
    for item in items {
        if not isinstance(item, uni.Name) or item.value not in ANY_TYPE_TAGS {
            return None;
        }
        names.append(item.value);
    }
    return names;
}

impl MirLowering.target_archetype(target: uni.Expr) -> (uni.Archetype | None) {
    wanted = self.arch_of_type(target.type);
    if wanted is None and isinstance(target, uni.Name) and isinstance(target.sym, uni.Symbol) {
        decl = target.sym.decl;
        holder = decl.parent if decl is not None else None;
        wanted = holder if isinstance(holder, uni.Archetype) else None;
    }
    return wanted;
}

impl MirLowering.isinstance_value(
    subject: uni.Expr, target: uni.Expr, site: uni.UniNode
) -> (MirValue | None) {
    names = self.type_names(target);
    subject_type = self.expr_type(subject);
    if subject_type.kind == MirKind.ANY {
        return self.any_isinstance(self.lower_expr(subject), target, site);
    }
    if names is None {
        return None;
    }
    self.lower_expr(subject);
    own = STATIC_TYPE_NAMES.get(subject_type.kind.value, "");
    hit = own in names or (own == "bool" and "int" in names);
    return self.builder().const_bool(hit);
}

impl MirLowering.any_isinstance(
    value: MirValue, target: uni.Expr, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    tag = self.emit_value(MirOp.ANY_TAG, mir_int(), [value]);
    payload = self.emit_value(MirOp.ANY_PAYLOAD, mir_int(), [value]);
    items = [part for part in target.values if isinstance(part, uni.Expr)]
        if isinstance(target, uni.TupleVal)
        else [target];
    verdict = b.const_bool(False);
    for item in items {
        if isinstance(item, uni.Name) and item.value in ANY_TYPE_TAGS {
            for wanted in ANY_TYPE_TAGS[item.value] {
                verdict = b.binary(
                    "or", verdict, b.compare("eq", tag, b.const_int(wanted, mir_int()))
                );
            }
            continue;
        }
        arch = self.target_archetype(item);
        if arch is None {
            raise MirRefused(
                mir_refusal(
                    "call",
                    "isinstance of a boxed value",
                    site,
                    "Native isinstance() on `any` tests builtin types and archetypes."
                )
            );
        }
        name = archetype_native_name(arch);
        owner = arch.find_parent_of_type(uni.Module) or self.module;
        lineage = [name] + get_layout_registry(owner, self.prog).descendants_of([name]);
        for member in lineage {
            label = self.emit_value(
                MirOp.CSTR, mir_c_ptr(mir_int(8, False)), [], str_value=member
            );
            verdict = b.binary(
                "or", verdict, self.runtime_value("__jac_rt_any_isa", [tag, payload, label])
            );
        }
    }
    return verdict;
}

impl MirLowering.value_builtin(nd: uni.FuncCall, name: str) -> (MirValue | None) {
    if name != "type" {
        return None;
    }
    args = self.call_args(nd);
    if len(args) != 1 {
        raise MirRefused(
            mir_refusal(
                "call",
                f"type with {len(args)} arguments",
                nd,
                "Native type() reads the type of one value; building a class is not lowered."
            )
        );
    }
    return self.type_value(self.lower_expr(args[0]), nd);
}

impl MirLowering.type_value(value: MirValue, site: uni.UniNode) -> MirValue {
    t = value.type;
    class_type = mir_class("*");
    if t.kind == MirKind.ANY {
        name = self.runtime_value(
            "__jac_rt_any_type_name",
            [
                self.emit_value(MirOp.ANY_TAG, mir_int(), [value]),
                self.emit_value(MirOp.ANY_PAYLOAD, mir_int(), [value])
            ]
        );
        return self.emit_value(MirOp.PTR_CAST, class_type, [name]);
    }
    if t.kind == MirKind.OBJ {
        name = self.runtime_value("__jac_rt_type_name", [value]);
        return self.emit_value(MirOp.PTR_CAST, class_type, [name]);
    }
    label = STATIC_TYPE_NAMES.get(t.kind.value);
    if t.kind == MirKind.ENUM {
        label = self.enum_layout_of(t, site).name;
    }
    if label is None {
        raise MirRefused(mir_refusal("call", f"type of {t.render()}", site));
    }
    return self.emit_value(MirOp.CSTR, class_type, [], str_value=label);
}

impl MirLowering.class_name_str(value: MirValue) -> MirValue {
    b = self.builder();
    text = self.runtime_value(
        "__jac_rt_str_from_cstr",
        [self.emit_value(MirOp.PTR_CAST, mir_c_ptr(mir_int(8, False)), [value])]
    );
    return b.str_make(text, text, self.runtime_value("__jac_rt_str_size", [text]));
}
