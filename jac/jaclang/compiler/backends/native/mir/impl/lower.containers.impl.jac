impl MirLowering.elem_kind(t: MirType, site: uni.UniNode) -> int {
    if t.kind == MirKind.INT {
        return KIND_INT;
    }
    if t.kind == MirKind.FLOAT {
        return KIND_FLOAT;
    }
    if t.kind == MirKind.BOOL {
        return KIND_BOOL;
    }
    if t.kind in (MirKind.STR, MirKind.STR_REF) {
        return KIND_STR;
    }
    if mir_holds_ref(t) {
        return KIND_REF;
    }
    raise MirRefused(mir_refusal("container element", t.render(), site));
}

impl MirLowering.address_of(value: MirValue) -> MirValue {
    return self.emit_value(MirOp.PTR_INT, mir_int(), [value]);
}

impl MirLowering.to_bits(value: MirValue, elem: MirType, site: uni.UniNode) -> MirValue {
    b = self.builder();
    kind = self.elem_kind(elem, site);
    if elem.kind == MirKind.ANY {
        return self.address_of(self.any_to_box(value, site));
    }
    if kind == KIND_FLOAT {
        return self.emit_value(MirOp.BITCAST, mir_int(), [b.convert(value, mir_float())]);
    }
    if kind in (KIND_INT, KIND_BOOL) {
        return b.convert(self.coerce(value, elem, site), mir_int());
    }
    if kind == KIND_STR {
        text = self.coerce(value, mir_str(), site);
        held = self.runtime(
            "__jac_rt_str_ref",
            [b.str_part(text, "root"), b.str_part(text, "data"), b.str_part(text, "len")]
        );
        if held is None {
            raise MirRefused(mir_refusal("container element", "str", site));
        }
        return self.address_of(held);
    }
    return self.address_of(self.coerce(value, elem, site));
}

impl MirLowering.scalar_from_bits(bits: MirValue, elem: MirType) -> MirValue {
    b = self.builder();
    if elem.kind == MirKind.FLOAT {
        wide = self.emit_value(MirOp.BITCAST, mir_float(), [bits]);
        return b.convert(wide, elem);
    }
    if elem.kind == MirKind.BOOL {
        return b.compare("ne", bits, b.const_int(0, mir_int()));
    }
    return b.convert(bits, elem);
}

impl MirLowering.owned_element(handle: MirValue, elem: MirType) -> MirValue {
    b = self.builder();
    if elem.kind == MirKind.ANY {
        return self.any_from_box(handle);
    }
    if elem.kind in (MirKind.STR, MirKind.STR_REF) {
        text = b.ref_cast(handle, mir_str_ref(), True);
        size = self.runtime("__jac_rt_str_size", [text]);
        if size is None {
            raise MirRefused(mir_refusal("container element", "str"));
        }
        return b.str_make(text, text, size);
    }
    return b.ref_cast(handle, elem, True);
}

impl MirLowering.container_len(value: MirValue) -> MirValue {
    if value.type.kind == MirKind.LIST {
        return self.emit_value(MirOp.MEM_LOAD, mir_int(), [self.address_of(value)]);
    }
    if value.type.kind in (MirKind.DICT, MirKind.SET) {
        counted = self.runtime("__jac_rt_dict_len", [value]);
        if counted is not None {
            return counted;
        }
    }
    raise MirRefused(mir_refusal("call", f"len of {value.type.render()}"));
}

impl MirLowering.list_index(lst: MirValue, index: MirValue, message: str) -> MirValue {
    b = self.builder();
    size = self.container_len(lst);
    at = b.convert(index, mir_int());
    wrapped = b.select(
        b.compare("lt", at, b.const_int(0, mir_int())), b.binary("add", at, size), at
    );
    self.raise_if(
        b.binary(
            "or",
            b.compare("lt", wrapped, b.const_int(0, mir_int())),
            b.compare("ge", wrapped, size)
        ),
        "IndexError",
        message
    );
    return wrapped;
}

impl MirLowering.list_read(lst: MirValue, index: MirValue) -> MirValue {
    b = self.builder();
    elem = lst.type.payload();
    kind = self.elem_kind(elem, self.module);
    if kind in (KIND_STR, KIND_REF) {
        handle = self.runtime(
            "__jac_rt_list_get_ref", [lst, index, b.const_int(kind, mir_int())]
        );
        if handle is None {
            raise MirRefused(mir_refusal("subscript", elem.render()));
        }
        return self.owned_element(handle, elem);
    }
    base = self.address_of(lst);
    data = self.emit_value(
        MirOp.MEM_LOAD, mir_int(), [b.binary("add", base, b.const_int(16, mir_int()))]
    );
    slot = b.binary("add", data, b.binary("mul", index, b.const_int(8, mir_int())));
    return self.scalar_from_bits(self.emit_value(MirOp.MEM_LOAD, mir_int(), [slot]), elem);
}

impl MirLowering.new_list(elem: MirType, capacity: int) -> MirValue {
    b = self.builder();
    handle = self.runtime(
        "__jac_rt_list_new",
        [
            b.const_int(capacity, mir_int()),
            b.const_int(self.elem_kind(elem, self.module), mir_int())
        ]
    );
    if handle is None {
        raise MirRefused(mir_refusal("list", elem.render()));
    }
    return b.ref_cast(handle, mir_list(elem), True);
}

impl MirLowering.new_dict(
    key: MirType, value: (MirType | None), result: MirType
) -> MirValue {
    b = self.builder();
    handle = self.runtime(
        "__jac_rt_dict_new",
        [
            b.const_int(self.elem_kind(key, self.module), mir_int()),
            b.const_int(
                self.elem_kind(value, self.module)
                    if value is not None
                    else NO_VALUE_KIND,
                mir_int()
            )
        ]
    );
    if handle is None {
        raise MirRefused(mir_refusal("dict", result.render()));
    }
    return b.ref_cast(handle, result, True);
}

impl MirLowering.lower_list_literal(nd: uni.ListVal) -> MirValue {
    result_type = self.expr_type(nd);
    if result_type.kind != MirKind.LIST {
        raise MirRefused(mir_refusal("list", result_type.render(), nd));
    }
    elem = result_type.payload();
    made = self.spill(self.new_list(elem, max(len(nd.values), 4)));
    kind = self.builder().const_int(self.elem_kind(elem, nd), mir_int());
    for item in nd.values {
        bits = self.to_bits(self.lower_expr(item), elem, item);
        self.runtime("__jac_rt_list_push", [made, bits, kind]);
    }
    return made;
}

impl MirLowering.lower_set_literal(nd: uni.SetVal) -> MirValue {
    result_type = self.expr_type(nd);
    if result_type.kind != MirKind.SET {
        raise MirRefused(mir_refusal("set", result_type.render(), nd));
    }
    elem = result_type.payload();
    made = self.spill(self.new_dict(elem, None, result_type));
    b = self.builder();
    kind = b.const_int(self.elem_kind(elem, nd), mir_int());
    for item in list(nd.values or []) {
        bits = self.to_bits(self.lower_expr(item), elem, item);
        self.runtime(
            "__jac_rt_dict_set",
            [made, bits, b.const_int(0, mir_int()), kind, b.const_int(NO_VALUE_KIND, mir_int())]
        );
    }
    return made;
}

impl MirLowering.lower_dict_literal(nd: uni.DictVal) -> MirValue {
    result_type = self.expr_type(nd);
    if result_type.kind != MirKind.DICT {
        raise MirRefused(mir_refusal("dict", result_type.render(), nd));
    }
    (key, value) = (result_type.args[0], result_type.args[1]);
    made = self.spill(self.new_dict(key, value, result_type));
    b = self.builder();
    key_kind = b.const_int(self.elem_kind(key, nd), mir_int());
    value_kind = b.const_int(self.elem_kind(value, nd), mir_int());
    for pair in nd.kv_pairs {
        if pair.key is None {
            raise MirRefused(mir_refusal("dict", "unpacking", pair));
        }
        key_bits = self.to_bits(self.lower_expr(pair.key), key, pair.key);
        value_bits = self.to_bits(self.lower_expr(pair.value), value, pair.value);
        self.runtime(
            "__jac_rt_dict_set", [made, key_bits, value_bits, key_kind, value_kind]
        );
    }
    return made;
}

impl MirLowering.dict_get(d: MirValue, key: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    (key_type, value_type) = (d.type.args[0], d.type.args[1]);
    found = self.runtime(
        "__jac_rt_dict_find",
        [
            d,
            self.to_bits(key, key_type, site),
            b.const_int(self.elem_kind(key_type, site), mir_int())
        ]
    );
    if found is None {
        raise MirRefused(mir_refusal("subscript", d.type.render(), site));
    }
    self.raise_if(
        b.compare("lt", found, b.const_int(0, mir_int())), "KeyError", KEY_MESSAGE
    );
    kind = self.elem_kind(value_type, site);
    if kind in (KIND_STR, KIND_REF) {
        handle = self.runtime(
            "__jac_rt_dict_val_ref", [d, found, b.const_int(kind, mir_int())]
        );
        if handle is None {
            raise MirRefused(mir_refusal("subscript", value_type.render(), site));
        }
        return self.owned_element(handle, value_type);
    }
    bits = self.runtime("__jac_rt_dict_val_at", [d, found]);
    if bits is None {
        raise MirRefused(mir_refusal("subscript", value_type.render(), site));
    }
    return self.scalar_from_bits(bits, value_type);
}

impl MirLowering.list_slice(lst: MirValue, part: uni.Slice, site: uni.UniNode) -> MirValue {
    b = self.builder();
    size = self.container_len(lst);
    step = b.const_int(1, mir_int());
    if part.step is not None {
        step = self.coerce(self.lower_expr(part.step), mir_int(), part.step);
        self.raise_if(
            b.compare("eq", step, b.const_int(0, mir_int())),
            "ValueError",
            "slice step cannot be zero"
        );
    }
    upward = b.compare("gt", step, b.const_int(0, mir_int()));
    low = b.select(upward, b.const_int(0, mir_int()), b.const_int(-1, mir_int()));
    high = b.select(upward, size, b.binary("sub", size, b.const_int(1, mir_int())));
    bounds: list[MirValue] = [];
    for (given, fallback) in ((part.start, b.select(upward, low, high)), (part.stop, b.select(upward, high, low))) {
        if given is None {
            bounds.append(fallback);
            continue;
        }
        at = self.coerce(self.lower_expr(given), mir_int(), given);
        shifted = b.select(
            b.compare("lt", at, b.const_int(0, mir_int())), b.binary("add", at, size), at
        );
        clamped_low = b.select(b.compare("lt", shifted, low), low, shifted);
        bounds.append(b.select(b.compare("gt", clamped_low, high), high, clamped_low));
    }
    elem = lst.type.payload();
    handle = self.runtime(
        "__jac_rt_list_slice",
        [lst, bounds[0], bounds[1], step, b.const_int(self.elem_kind(elem, site), mir_int())]
    );
    if handle is None {
        raise MirRefused(mir_refusal("slice", lst.type.render(), site));
    }
    return b.ref_cast(handle, lst.type, True);
}

impl MirLowering.container_get(
    base: MirValue, slice: uni.IndexSlice, site: uni.UniNode
) -> MirValue {
    if len(slice.slices) != 1 {
        raise MirRefused(mir_refusal("subscript", "several indices", site));
    }
    part = slice.slices[0];
    if base.type.kind == MirKind.LIST {
        if slice.is_range {
            return self.list_slice(base, part, site);
        }
        if part.start is None {
            raise MirRefused(mir_refusal("subscript", "missing index", site));
        }
        index = self.coerce(self.lower_expr(part.start), mir_int(), part.start);
        return self.list_read(base, self.list_index(base, index, LIST_INDEX_MESSAGE));
    }
    if base.type.kind == MirKind.DICT and not slice.is_range and part.start is not None {
        return self.dict_get(base, self.lower_expr(part.start), site);
    }
    raise MirRefused(mir_refusal("subscript", base.type.render(), site));
}

impl MirLowering.container_set(
    base: MirValue, slice: uni.IndexSlice, value: MirValue, site: uni.UniNode
) {
    b = self.builder();
    if len(slice.slices) != 1 or slice.is_range or slice.slices[0].start is None {
        raise MirRefused(mir_refusal("subscript assignment", "slice", site));
    }
    key_nd = slice.slices[0].start;
    if base.type.kind == MirKind.LIST {
        elem = base.type.payload();
        index = self.list_index(
            base,
            self.coerce(self.lower_expr(key_nd), mir_int(), key_nd),
            LIST_ASSIGN_MESSAGE
        );
        self.runtime(
            "__jac_rt_list_set",
            [
                base,
                index,
                self.to_bits(value, elem, site),
                b.const_int(self.elem_kind(elem, site), mir_int())
            ]
        );
        return;
    }
    if base.type.kind == MirKind.DICT {
        (key_type, value_type) = (base.type.args[0], base.type.args[1]);
        self.runtime(
            "__jac_rt_dict_set",
            [
                base,
                self.to_bits(self.lower_expr(key_nd), key_type, key_nd),
                self.to_bits(value, value_type, site),
                b.const_int(self.elem_kind(key_type, site), mir_int()),
                b.const_int(self.elem_kind(value_type, site), mir_int())
            ]
        );
        return;
    }
    raise MirRefused(mir_refusal("subscript assignment", base.type.render(), site));
}

impl MirLowering.container_method(
    receiver: MirValue, name: str, nd: uni.FuncCall
) -> (MirValue | None) {
    if receiver.type.kind == MirKind.LIST {
        return self.list_method(receiver, name, nd);
    }
    if receiver.type.kind == MirKind.DICT {
        return self.dict_method(receiver, name, nd);
    }
    if receiver.type.kind == MirKind.SET {
        return self.set_method(receiver, name, nd);
    }
    return None;
}

impl MirLowering.list_method(
    lst: MirValue, name: str, nd: uni.FuncCall
) -> (MirValue | None) {
    b = self.builder();
    args = self.call_args(nd);
    elem = lst.type.payload();
    kind = b.const_int(self.elem_kind(elem, nd), mir_int());
    if name == "append" and len(args) == 1 {
        self.runtime("__jac_rt_list_push", [lst, self.to_bits(self.lower_expr(args[0]), elem, args[0]), kind]);
        return b.const_bool(False);
    }
    if name == "extend" and len(args) == 1 {
        other = self.lower_expr(args[0]);
        if other.type is not lst.type {
            raise MirRefused(mir_refusal("call", f"extend with {other.type.render()}", nd));
        }
        self.runtime("__jac_rt_list_extend", [lst, other, kind]);
        return b.const_bool(False);
    }
    if name == "insert" and len(args) == 2 {
        size = self.container_len(lst);
        at = self.coerce(self.lower_expr(args[0]), mir_int(), args[0]);
        shifted = b.select(
            b.compare("lt", at, b.const_int(0, mir_int())), b.binary("add", at, size), at
        );
        low = b.select(b.compare("lt", shifted, b.const_int(0, mir_int())), b.const_int(0, mir_int()), shifted);
        clamped = b.select(b.compare("gt", low, size), size, low);
        self.runtime(
            "__jac_rt_list_insert",
            [lst, clamped, self.to_bits(self.lower_expr(args[1]), elem, args[1]), kind]
        );
        return b.const_bool(False);
    }
    if name == "pop" and len(args) <= 1 {
        size = self.container_len(lst);
        self.raise_if(
            b.compare("eq", size, b.const_int(0, mir_int())), "IndexError", POP_EMPTY_MESSAGE
        );
        at = b.binary("sub", size, b.const_int(1, mir_int()));
        if args {
            at = self.list_index(
                lst, self.coerce(self.lower_expr(args[0]), mir_int(), args[0]), "pop index out of range"
            );
        }
        bits = self.runtime("__jac_rt_list_pop", [lst, at]);
        if bits is None {
            return None;
        }
        if self.elem_kind(elem, nd) in (KIND_STR, KIND_REF) {
            return self.owned_element(b.ref_cast(bits, mir_ref(), True), elem);
        }
        return self.scalar_from_bits(bits, elem);
    }
    if name == "clear" and not args {
        self.runtime("__jac_rt_list_clear", [lst, kind]);
        return b.const_bool(False);
    }
    if name == "copy" and not args {
        made = self.runtime("__jac_rt_list_copy", [lst, kind]);
        return b.ref_cast(made, lst.type, True) if made is not None else None;
    }
    if name == "reverse" and not args {
        self.runtime("__jac_rt_list_reverse", [lst]);
        return b.const_bool(False);
    }
    if name == "index" and len(args) == 1 {
        position = self.runtime(
            "__jac_rt_list_index", [lst, self.to_bits(self.lower_expr(args[0]), elem, args[0]), kind]
        );
        if position is None {
            return None;
        }
        self.raise_if(
            b.compare("lt", position, b.const_int(0, mir_int())), "ValueError", LIST_VALUE_MESSAGE
        );
        return position;
    }
    if name == "sort" and not args and self.elem_kind(elem, nd) != KIND_REF {
        self.runtime("__jac_rt_list_sort", [lst, kind, b.const_bool(False)]);
        return b.const_bool(False);
    }
    return None;
}

impl MirLowering.dict_method(
    d: MirValue, name: str, nd: uni.FuncCall
) -> (MirValue | None) {
    b = self.builder();
    args = self.call_args(nd);
    (key_type, value_type) = (d.type.args[0], d.type.args[1]);
    key_kind = b.const_int(self.elem_kind(key_type, nd), mir_int());
    value_kind = b.const_int(self.elem_kind(value_type, nd), mir_int());
    if name == "get" and len(args) in (1, 2) {
        result_type = self.expr_type(nd);
        held = self.temp_slot(result_type);
        found = self.runtime(
            "__jac_rt_dict_find",
            [d, self.to_bits(self.lower_expr(args[0]), key_type, args[0]), key_kind]
        );
        if found is None {
            return None;
        }
        fn = self.st().fn;
        hit = fn.new_block("get.hit");
        miss = fn.new_block("get.miss");
        done = fn.new_block("get.done");
        b.cond_branch(b.compare("ge", found, b.const_int(0, mir_int())), hit, miss);
        b.position(hit);
        if self.elem_kind(value_type, nd) in (KIND_STR, KIND_REF) {
            handle = self.runtime("__jac_rt_dict_val_ref", [d, found, value_kind]);
            if handle is None {
                return None;
            }
            b.store(held, self.coerce(self.owned_element(handle, value_type), result_type, nd));
        } else {
            bits = self.runtime("__jac_rt_dict_val_at", [d, found]);
            if bits is None {
                return None;
            }
            b.store(held, self.coerce(self.scalar_from_bits(bits, value_type), result_type, nd));
        }
        b.branch(done);
        b.position(miss);
        if len(args) == 2 {
            b.store(held, self.coerce(self.lower_expr(args[1]), result_type, args[1]));
        } else {
            b.store(held, self.coerce(b.const_null(mir_none()), result_type, nd));
        }
        b.branch(done);
        b.position(done);
        return b.load(held, result_type);
    }
    if name == "pop" and len(args) == 1 {
        flag = self.temp_slot(mir_int());
        bits = self.runtime(
            "__jac_rt_dict_pop",
            [
                d,
                self.to_bits(self.lower_expr(args[0]), key_type, args[0]),
                key_kind,
                value_kind,
                self.emit_value(MirOp.PTR_INT, mir_int(), [flag])
            ]
        );
        if bits is None {
            return None;
        }
        self.raise_if(
            b.compare("eq", b.load(flag, mir_int()), b.const_int(0, mir_int())), "KeyError", KEY_MESSAGE
        );
        if self.elem_kind(value_type, nd) in (KIND_STR, KIND_REF) {
            return self.owned_element(b.ref_cast(bits, mir_ref(), True), value_type);
        }
        return self.scalar_from_bits(bits, value_type);
    }
    if name == "clear" and not args {
        self.runtime("__jac_rt_dict_clear", [d, key_kind, value_kind]);
        return b.const_bool(False);
    }
    if name == "copy" and not args {
        made = self.runtime("__jac_rt_dict_copy", [d, key_kind, value_kind]);
        return b.ref_cast(made, d.type, True) if made is not None else None;
    }
    if name == "update" and len(args) == 1 {
        other = self.lower_expr(args[0]);
        if other.type is not d.type {
            raise MirRefused(mir_refusal("call", f"update with {other.type.render()}", nd));
        }
        self.runtime("__jac_rt_dict_update", [d, other, key_kind, value_kind]);
        return b.const_bool(False);
    }
    if name in ("keys", "values") and not args {
        part = key_type if name == "keys" else value_type;
        made = self.spill(self.new_list(part, 8));
        part_kind = b.const_int(self.elem_kind(part, nd), mir_int());
        cursor = self.temp_slot(mir_int());
        b.store(cursor, b.const_int(-1, mir_int()));
        fn = self.st().fn;
        head = fn.new_block("view.head");
        body = fn.new_block("view.body");
        done = fn.new_block("view.done");
        b.branch(head);
        b.position(head);
        following = self.runtime("__jac_rt_dict_next", [d, b.load(cursor, mir_int())]);
        if following is None {
            return None;
        }
        b.store(cursor, following);
        b.cond_branch(b.compare("ge", following, b.const_int(0, mir_int())), body, done);
        b.position(body);
        bits = self.runtime(
            "__jac_rt_dict_key_at" if name == "keys" else "__jac_rt_dict_val_at",
            [d, b.load(cursor, mir_int())]
        );
        if bits is None {
            return None;
        }
        self.runtime("__jac_rt_list_push", [made, bits, part_kind]);
        b.branch(head);
        b.position(done);
        return made;
    }
    return None;
}

impl MirLowering.set_method(
    s: MirValue, name: str, nd: uni.FuncCall
) -> (MirValue | None) {
    b = self.builder();
    args = self.call_args(nd);
    elem = s.type.payload();
    kind = b.const_int(self.elem_kind(elem, nd), mir_int());
    none_kind = b.const_int(NO_VALUE_KIND, mir_int());
    if name == "add" and len(args) == 1 {
        self.runtime(
            "__jac_rt_dict_set",
            [s, self.to_bits(self.lower_expr(args[0]), elem, args[0]), b.const_int(0, mir_int()), kind, none_kind]
        );
        return b.const_bool(False);
    }
    if name in ("discard", "remove") and len(args) == 1 {
        gone = self.runtime(
            "__jac_rt_dict_del", [s, self.to_bits(self.lower_expr(args[0]), elem, args[0]), kind, none_kind]
        );
        if gone is None {
            return None;
        }
        if name == "remove" {
            self.raise_if(b.logical_not(gone), "KeyError", KEY_MESSAGE);
        }
        return b.const_bool(False);
    }
    if name == "clear" and not args {
        self.runtime("__jac_rt_dict_clear", [s, kind, none_kind]);
        return b.const_bool(False);
    }
    if name == "copy" and not args {
        made = self.runtime("__jac_rt_dict_copy", [s, kind, none_kind]);
        return b.ref_cast(made, s.type, True) if made is not None else None;
    }
    if name == "update" and len(args) == 1 {
        other = self.lower_expr(args[0]);
        if other.type is not s.type {
            raise MirRefused(mir_refusal("call", f"update with {other.type.render()}", nd));
        }
        self.runtime("__jac_rt_dict_update", [s, other, kind, none_kind]);
        return b.const_bool(False);
    }
    return None;
}

impl MirLowering.contains(item: MirValue, holder: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    if holder.type.kind == MirKind.LIST {
        elem = holder.type.payload();
        found = self.runtime(
            "__jac_rt_list_contains",
            [holder, self.to_bits(item, elem, site), b.const_int(self.elem_kind(elem, site), mir_int())]
        );
        if found is not None {
            return found;
        }
    }
    if holder.type.kind in (MirKind.DICT, MirKind.SET) {
        key = holder.type.args[0];
        at = self.runtime(
            "__jac_rt_dict_find",
            [holder, self.to_bits(item, key, site), b.const_int(self.elem_kind(key, site), mir_int())]
        );
        if at is not None {
            return b.compare("ge", at, b.const_int(0, mir_int()));
        }
    }
    raise MirRefused(mir_refusal("comparison", f"in {holder.type.render()}", site));
}

impl MirLowering.container_eq(left: MirValue, right: MirValue) -> MirValue {
    b = self.builder();
    if left.type is not right.type {
        raise MirRefused(
            mir_refusal("comparison", f"{left.type.render()} == {right.type.render()}")
        );
    }
    if left.type.kind == MirKind.LIST {
        same = self.runtime(
            "__jac_rt_list_eq",
            [left, right, b.const_int(self.elem_kind(left.type.payload(), self.module), mir_int())]
        );
        if same is not None {
            return same;
        }
    }
    key = left.type.args[0];
    value_kind = NO_VALUE_KIND;
    if left.type.kind == MirKind.DICT {
        value_kind = self.elem_kind(left.type.args[1], self.module);
    }
    same = self.runtime(
        "__jac_rt_dict_eq",
        [left, right, b.const_int(self.elem_kind(key, self.module), mir_int()), b.const_int(value_kind, mir_int())]
    );
    if same is None {
        raise MirRefused(mir_refusal("comparison", left.type.render()));
    }
    return same;
}

impl MirLowering.lower_for_container(nd: uni.InForStmt, holder: MirValue) {
    b = self.builder();
    fn = self.st().fn;
    if not isinstance(nd.target, uni.Name) {
        raise MirRefused(mir_refusal("statement", "for target", nd.target));
    }
    source = self.spill(holder);
    cursor = self.temp_slot(mir_int());
    b.store(cursor, b.const_int(-1, mir_int()));
    head = fn.new_block("each.head");
    body = fn.new_block("each.body");
    otherwise = fn.new_block("each.else");
    after = fn.new_block("each.exit");
    b.branch(head);
    b.position(head);
    current = b.load(cursor, mir_int());
    if source.type.kind == MirKind.LIST {
        following = b.binary("add", current, b.const_int(1, mir_int()));
        b.store(cursor, following);
        b.cond_branch(b.compare("lt", following, self.container_len(source)), body, otherwise);
        b.position(body);
        self.store_name(nd.target, self.list_read(source, b.load(cursor, mir_int())));
    } else {
        upcoming = self.runtime("__jac_rt_dict_next", [source, current]);
        if upcoming is None {
            raise MirRefused(mir_refusal("statement", "for over " + source.type.render(), nd));
        }
        b.store(cursor, upcoming);
        b.cond_branch(b.compare("ge", upcoming, b.const_int(0, mir_int())), body, otherwise);
        b.position(body);
        key = source.type.args[0];
        kind = self.elem_kind(key, nd);
        at = b.load(cursor, mir_int());
        if kind in (KIND_STR, KIND_REF) {
            handle = self.runtime("__jac_rt_dict_key_ref", [source, at, b.const_int(kind, mir_int())]);
            if handle is None {
                raise MirRefused(mir_refusal("statement", "for over " + source.type.render(), nd));
            }
            self.store_name(nd.target, self.owned_element(handle, key));
        } else {
            bits = self.runtime("__jac_rt_dict_key_at", [source, at]);
            if bits is None {
                raise MirRefused(mir_refusal("statement", "for over " + source.type.render(), nd));
            }
            self.store_name(nd.target, self.scalar_from_bits(bits, key));
        }
    }
    self.st().loops.append(MirLoopTarget(head=head, after=after));
    self.lower_body(nd.body);
    self.st().loops.pop();
    if not self.builder().block.terminated() {
        self.builder().branch(head);
    }
    b.position(otherwise);
    self.lower_else(nd.else_body, after);
    b.position(after);
}

impl MirLowering.lower_delete(nd: uni.DeleteStmt) {
    b = self.builder();
    for target in nd.targets {
        if self.osp_delete(target) {
            continue;
        }
        if not isinstance(target, uni.AtomTrailer)
            or target.is_attr
            or not isinstance(target.right, uni.IndexSlice) {
            raise MirRefused(mir_refusal("statement", "del of " + type(target).__name__, target));
        }
        holder = self.lower_expr(target.target);
        slice = target.right;
        if len(slice.slices) != 1 or slice.is_range or slice.slices[0].start is None {
            raise MirRefused(mir_refusal("statement", "del of a slice", target));
        }
        key_nd = slice.slices[0].start;
        if holder.type.kind == MirKind.LIST {
            at = self.list_index(
                holder, self.coerce(self.lower_expr(key_nd), mir_int(), key_nd), "list assignment index out of range"
            );
            bits = self.runtime("__jac_rt_list_pop", [holder, at]);
            if bits is not None and self.elem_kind(holder.type.payload(), target) in (KIND_STR, KIND_REF) {
                self.owned_element(b.ref_cast(bits, mir_ref(), True), holder.type.payload());
            }
            continue;
        }
        if holder.type.kind == MirKind.DICT {
            (key_type, value_type) = (holder.type.args[0], holder.type.args[1]);
            gone = self.runtime(
                "__jac_rt_dict_del",
                [
                    holder,
                    self.to_bits(self.lower_expr(key_nd), key_type, key_nd),
                    b.const_int(self.elem_kind(key_type, target), mir_int()),
                    b.const_int(self.elem_kind(value_type, target), mir_int())
                ]
            );
            if gone is not None {
                self.raise_if(b.logical_not(gone), "KeyError", KEY_MESSAGE);
            }
            continue;
        }
        raise MirRefused(mir_refusal("statement", "del on " + holder.type.render(), target));
    }
}
