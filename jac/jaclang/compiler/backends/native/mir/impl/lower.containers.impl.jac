impl MirLowering.elem_kind(t: MirType, site: uni.UniNode) -> int {
    if t.kind == MirKind.C_STRUCT {
        return KIND_INT;
    }
    if t.kind == MirKind.NONE {
        return KIND_NULL;
    }
    if t.kind == MirKind.INT and not t.signed and t.width == 64 {
        return KIND_UINT;
    }
    if t.kind
        in (
            MirKind.INT,
            MirKind.ENUM,
            MirKind.CLASS,
            MirKind.C_PTR,
            MirKind.C_FN,
            MirKind.REGION
        ) {
        return KIND_INT;
    }
    if t.kind == MirKind.OPT {
        if t.payload().kind in (MirKind.STR, MirKind.STR_REF) {
            return KIND_STR;
        }
        if t.payload().kind == MirKind.TUPLE {
            self.elem_kind(t.payload(), site);
            return KIND_TUPLE;
        }
        if t.payload().kind
            in (MirKind.INT, MirKind.FLOAT, MirKind.BOOL, MirKind.ENUM) {
            return KIND_ANY;
        }
        if not self.nullable_payload(t.payload()) {
            raise MirRefused(mir_refusal("container element", t.render(), site));
        }
        return KIND_REF;
    }
    if t.kind == MirKind.TUPLE {
        for member in t.args {
            self.elem_kind(member, site);
        }
        return KIND_TUPLE;
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
    if t.kind == MirKind.ANY {
        return KIND_ANY;
    }
    if mir_holds_ref(t) {
        return KIND_REF;
    }
    raise MirRefused(mir_refusal("container element", t.render(), site));
}

impl MirLowering.tuple_box(value: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    held = value;
    box = self.runtime_value(
        "__jac_rt_tuple_new", [b.const_int(len(value.type.args), mir_int())]
    );
    for (index, member) in enumerate(value.type.args) {
        self.runtime(
            "__jac_rt_tuple_set",
            [
                box,
                b.const_int(index, mir_int()),
                self.to_bits(self.tuple_get(held, index), member, site),
                self.creation_kind(member, site)
            ]
        );
    }
    return box;
}

impl MirLowering.refuse_inferred_any_store(
    base: MirValue, value: MirValue, site: uni.UniNode
) {
    holder = base.type.payload() if base.type.kind == MirKind.OPT else base.type;
    if value.type.kind != MirKind.ANY
        or not isinstance(site, uni.AtomTrailer)
        or not isinstance(site.target, uni.Name)
        or holder.kind not in (MirKind.LIST, MirKind.DICT) {
        return;
    }
    elem = holder.args[-1];
    if elem.kind not in (MirKind.INT, MirKind.FLOAT, MirKind.BOOL, MirKind.STR) {
        return;
    }
    sym = site.target.sym;
    decl = sym.decl if sym is not None else None;
    made = decl.parent if decl is not None else None;
    if not isinstance(made, uni.Assignment) or made.type_tag is not None {
        return;
    }
    raise MirRefused(
        mir_refusal(
            "assignment",
            f"an any value into {site.target.value}, inferred as {holder.render()}",
            site,
            f"Native code stores {elem.render()} slots in {site.target.value}, whose type was inferred from its first value, and cannot hold whatever this any value is at run time. Annotate {site.target.value} with the element type it really holds (any, if it is mixed)."
        )
    );
}

impl MirLowering.var_tuple_box(value: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    held = self.spill(value);
    elem = value.type.payload();
    size = self.container_len(held);
    box = self.runtime_value("__jac_rt_tuple_new", [size]);
    cursor = self.temp_slot(mir_int());
    b.store(cursor, b.const_int(0, mir_int()));
    head = fn.new_block("vtuple.head");
    body = fn.new_block("vtuple.body");
    done = fn.new_block("vtuple.done");
    b.branch(head);
    b.position(head);
    at = b.load(cursor, mir_int());
    b.cond_branch(b.compare("lt", at, size), body, done);
    b.position(body);
    self.runtime(
        "__jac_rt_tuple_set",
        [
            box,
            at,
            self.to_bits(self.list_read(held, at), elem, site),
            self.creation_kind(elem, site)
        ]
    );
    self.builder().store(
        cursor, self.builder().binary("add", at, b.const_int(1, mir_int()))
    );
    self.builder().branch(head);
    self.builder().position(done);
    return box;
}

impl MirLowering.tuple_unbox(handle: MirValue, t: MirType) -> MirValue {
    b = self.builder();
    size = len(t.args);
    members: list[MirValue] = [];
    for (index, member) in enumerate(t.args) {
        kind = self.elem_kind(member, self.module);
        if kind in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY) {
            got = self.runtime_value(
                "__jac_rt_tuple_get_ref", [handle, b.const_int(index, mir_int())]
            );
            members.append(self.owned_element(got, member));
            continue;
        }
        slot = b.binary(
            "add",
            self.address_of(handle),
            b.const_int(TUPLE_BOX_MEMBERS + (size + index) * 8, mir_int())
        );
        members.append(
            self.scalar_from_bits(
                self.emit_value(MirOp.MEM_LOAD, mir_int(), [slot]), member
            )
        );
    }
    return self.emit_value(MirOp.TUPLE_MAKE, t, members);
}

impl MirLowering.address_of(value: MirValue) -> MirValue {
    return self.emit_value(MirOp.PTR_INT, mir_int(), [value]);
}

impl MirLowering.to_bits(
    value: MirValue, elem: MirType, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    kind = self.elem_kind(elem, site);
    if kind == KIND_NULL {
        return b.const_int(0, mir_int());
    }
    if elem.kind == MirKind.ANY {
        return self.address_of(self.any_to_box(value, site));
    }
    if elem.kind == MirKind.OPT and elem.payload().kind == MirKind.TUPLE {
        boxed = self.temp_slot(mir_ref());
        (flag_slot, payload, absent, done) = self.opt_begin(
            self.coerce(value, elem, site), mir_bool()
        );
        b.store(boxed, self.tuple_box(payload, site));
        self.opt_switch(flag_slot, b.const_bool(True), absent, done);
        b.store(boxed, b.const_null(mir_ref()));
        self.opt_end(flag_slot, b.const_bool(False), done);
        return self.address_of(b.load(boxed, mir_ref()));
    }
    if elem.kind == MirKind.OPT
        and elem.payload().kind in (MirKind.STR, MirKind.TUPLE) {
        (bits_slot, payload, absent, done) = self.opt_begin(
            self.coerce(value, elem, site), mir_int()
        );
        self.opt_switch(
            bits_slot, self.to_bits(payload, elem.payload(), site), absent, done
        );
        return self.opt_end(bits_slot, b.const_int(0, mir_int()), done);
    }
    if elem.kind == MirKind.OPT and kind == KIND_ANY {
        return self.address_of(self.any_to_box(self.coerce(value, elem, site), site));
    }
    if elem.kind == MirKind.OPT {
        boxed_opt = self.spill(self.coerce(value, elem, site));
        return b.select(
            self.opt_present(boxed_opt),
            self.address_of(self.opt_get(boxed_opt)),
            b.const_int(0, mir_int())
        );
    }
    if elem.kind in (MirKind.CLASS, MirKind.C_PTR, MirKind.C_FN, MirKind.REGION) {
        return self.address_of(self.coerce(value, elem, site));
    }
    if kind == KIND_TUPLE {
        return self.address_of(self.tuple_box(self.coerce(value, elem, site), site));
    }
    if kind == KIND_FLOAT {
        return self.emit_value(
            MirOp.BITCAST, mir_int(), [b.convert(value, mir_float())]
        );
    }
    if kind in (KIND_INT, KIND_BOOL, KIND_UINT) {
        return b.convert(self.coerce(value, elem, site), mir_int());
    }
    if kind == KIND_STR {
        text = self.coerce(value, mir_str(), site);
        held = self.runtime(
            "__jac_rt_str_ref",
            [
                b.str_part(text, "root"),
                b.str_part(text, "data"),
                b.str_part(text, "len")
            ]
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
    if elem.kind == MirKind.NONE {
        return self.none_value();
    }
    if elem.kind in (MirKind.CLASS, MirKind.C_PTR, MirKind.C_FN, MirKind.REGION) {
        return self.emit_value(MirOp.PTR_CAST, elem, [bits]);
    }
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
    if elem.kind == MirKind.OPT
        and elem.payload().kind in (MirKind.STR, MirKind.STR_REF, MirKind.TUPLE) {
        fn = self.st().fn;
        result = self.temp_slot(elem);
        some = fn.new_block("optel.some");
        none_bb = fn.new_block("optel.none");
        done = fn.new_block("optel.done");
        b.cond_branch(
            b.compare("ne", self.address_of(handle), b.const_int(0, mir_int())),
            some,
            none_bb
        );
        b.position(some);
        b.store(
            result,
            self.opt_wrap(
                self.coerce(
                    self.owned_element(handle, elem.payload()),
                    elem.payload(),
                    self.module
                ),
                elem
            )
        );
        b.branch(done);
        b.position(none_bb);
        b.store(result, b.const_null(elem));
        b.branch(done);
        b.position(done);
        return b.load(result, elem);
    }
    if elem.kind == MirKind.OPT and self.elem_kind(elem, self.module) == KIND_ANY {
        return self.any_unbox(self.any_from_box(handle), elem, self.module);
    }
    if elem.kind == MirKind.OPT {
        present = b.compare("ne", self.address_of(handle), b.const_int(0, mir_int()));
        return self.emit_value(
            MirOp.OPT_MAKE, elem, [b.ref_cast(handle, elem.payload(), True), present]
        );
    }
    if elem.kind == MirKind.TUPLE {
        return self.tuple_unbox(handle, elem);
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
        words = self.emit_value(MirOp.MEM_LOAD, mir_int(), [self.address_of(value)]);
        if value.type.payload().kind == MirKind.C_STRUCT {
            return self.builder().binary(
                "floordiv", words, self.struct_words(value.type.payload())
            );
        }
        return words;
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
    if elem.kind == MirKind.C_STRUCT {
        return b.load(self.struct_element(lst, index), elem);
    }
    kind = self.elem_kind(elem, self.module);
    if kind in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY) {
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
    return self.scalar_from_bits(
        self.emit_value(MirOp.MEM_LOAD, mir_int(), [slot]), elem
    );
}

impl MirLowering.new_list(elem: MirType, capacity: int) -> MirValue {
    b = self.builder();
    handle = self.runtime(
        "__jac_rt_list_new",
        [b.const_int(capacity, mir_int()), self.creation_kind(elem, self.module)]
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
            self.creation_kind(key, self.module),
            self.creation_kind(value, self.module)
                if value is not None
                else b.const_int(NO_VALUE_KIND, mir_int())
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
    for item in nd.values {
        if isinstance(item, uni.UnaryExpr) and self.is_spread(item) {
            self.extend_from(made, self.lower_expr(item.operand), item);
        } else {
            self.container_add(made, self.lower_expr(item), item);
        }
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
    for item in list(nd.values or []) {
        if isinstance(item, uni.UnaryExpr) and self.is_spread(item) {
            self.extend_from(made, self.lower_expr(item.operand), item);
        } else {
            self.container_add(made, self.lower_expr(item), item);
        }
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
            self.merge_dict(made, self.lower_expr(pair.value), pair, False);
            continue;
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
    return self.dict_entry_value(d, found, site);
}

impl MirLowering.dict_entry_value(
    d: MirValue, at: MirValue, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    value_type = d.type.args[1];
    kind = self.elem_kind(value_type, site);
    if kind in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY) {
        handle = self.runtime(
            "__jac_rt_dict_val_ref", [d, at, b.const_int(kind, mir_int())]
        );
        if handle is None {
            raise MirRefused(mir_refusal("subscript", value_type.render(), site));
        }
        return self.owned_element(handle, value_type);
    }
    bits = self.runtime("__jac_rt_dict_val_at", [d, at]);
    if bits is None {
        raise MirRefused(mir_refusal("subscript", value_type.render(), site));
    }
    return self.scalar_from_bits(bits, value_type);
}

impl MirLowering.is_spread(item: uni.UniNode) -> bool {
    return isinstance(item, uni.UnaryExpr) and item.op.name == Tok.STAR_MUL;
}

impl MirLowering.each_begin(
    source: MirValue, site: uni.UniNode
) -> tuple[MirValue, MirIterCursor, MirBlock, MirBlock] {
    b = self.builder();
    fn = self.st().fn;
    cursor = self.iter_open(source, site);
    head = fn.new_block("each.head");
    body = fn.new_block("each.body");
    after = fn.new_block("each.exit");
    b.branch(head);
    b.position(head);
    return (self.iter_step(cursor, body, after), cursor, head, after);
}

impl MirLowering.each_end(head: MirBlock, after: MirBlock) {
    b = self.builder();
    if not b.block.terminated() {
        b.branch(head);
    }
    b.position(after);
}

impl MirLowering.container_add(made: MirValue, item: MirValue, site: uni.UniNode) {
    b = self.builder();
    elem = made.type.payload();
    if made.type.kind == MirKind.LIST and elem.kind == MirKind.C_STRUCT {
        self.struct_push(made, item, site);
        return;
    }
    kind = b.const_int(self.elem_kind(elem, site), mir_int());
    bits = self.to_bits(item, elem, site);
    if made.type.kind == MirKind.LIST {
        self.runtime("__jac_rt_list_push", [made, bits, kind]);
        return;
    }
    self.runtime(
        "__jac_rt_dict_set",
        [
            made,
            bits,
            b.const_int(0, mir_int()),
            kind,
            b.const_int(NO_VALUE_KIND, mir_int())
        ]
    );
}

impl MirLowering.extend_from(made: MirValue, source: MirValue, site: uni.UniNode) {
    b = self.builder();
    kind = b.const_int(self.elem_kind(made.type.payload(), site), mir_int());
    if made.type.kind == MirKind.LIST and source.type is made.type {
        self.runtime("__jac_rt_list_extend", [made, source, kind]);
        return;
    }
    if made.type.kind == MirKind.SET and source.type is made.type {
        self.runtime(
            "__jac_rt_dict_update",
            [made, source, kind, b.const_int(NO_VALUE_KIND, mir_int())]
        );
        return;
    }
    (item, _, head, after) = self.each_begin(source, site);
    self.container_add(made, item, site);
    self.each_end(head, after);
}

impl MirLowering.merge_dict(
    made: MirValue, source: MirValue, site: uni.UniNode, unique: bool
) {
    b = self.builder();
    if source.type.kind != MirKind.DICT {
        raise MirRefused(mir_refusal("unpacking", source.type.render(), site));
    }
    (key, value) = (made.type.args[0], made.type.args[1]);
    key_kind = b.const_int(self.elem_kind(key, site), mir_int());
    value_kind = b.const_int(self.elem_kind(value, site), mir_int());
    if source.type is made.type and not unique {
        self.runtime("__jac_rt_dict_update", [made, source, key_kind, value_kind]);
        return;
    }
    (entry_key, cursor, head, after) = self.each_begin(source, site);
    held = cursor.source;
    at = cursor.position;
    if held is None or at is None {
        raise RuntimeError("dict cursor has no source");
    }
    key_bits = self.to_bits(entry_key, key, site);
    if unique {
        fn = self.st().fn;
        clash = fn.new_block("kwsp.dup");
        fresh = fn.new_block("kwsp.fresh");
        seen = self.runtime_value("__jac_rt_dict_find", [made, key_bits, key_kind]);
        b.cond_branch(b.compare("ge", seen, b.const_int(0, mir_int())), clash, fresh);
        b.position(clash);
        b.raise_builtin("TypeError", "got multiple values for keyword argument");
        b.position(fresh);
    }
    value_bits = self.to_bits(
        self.dict_entry_value(held, b.load(at, mir_int()), site), value, site
    );
    self.runtime(
        "__jac_rt_dict_set", [made, key_bits, value_bits, key_kind, value_kind]
    );
    self.each_end(head, after);
}

impl MirLowering.list_bounds(
    lst: MirValue, part: uni.Slice, site: uni.UniNode
) -> tuple[MirValue, MirValue, MirValue] {
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
    for (given, fallback) in (
        (part.start, b.select(upward, low, high)),
        (part.stop, b.select(upward, high, low))
    ) {
        if given is None {
            bounds.append(fallback);
            continue;
        }
        at = self.coerce(self.lower_expr(given), mir_int(), given);
        shifted = b.select(
            b.compare("lt", at, b.const_int(0, mir_int())),
            b.binary("add", at, size),
            at
        );
        clamped_low = b.select(b.compare("lt", shifted, low), low, shifted);
        bounds.append(b.select(b.compare("gt", clamped_low, high), high, clamped_low));
    }
    return (bounds[0], bounds[1], step);
}

impl MirLowering.list_slice(
    lst: MirValue, part: uni.Slice, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    self.view_guard(lst, VIEW_SLICE);
    (start, stop, step) = self.list_bounds(lst, part, site);
    elem = lst.type.payload();
    handle = self.runtime(
        "__jac_rt_list_slice",
        [lst, start, stop, step, b.const_int(self.elem_kind(elem, site), mir_int())]
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
    if base.type.kind == MirKind.OPT and mir_is_container(base.type.payload()) {
        base = self.opt_unwrap_checked(base, "'NoneType' object is not subscriptable");
    }
    part = slice.slices[0];
    if base.type.kind == MirKind.ANY
        and not slice.is_range
        and part.start is not None {
        key = self.any_box(self.lower_expr(part.start), part.start);
        return self.any_from_box(
            self.runtime_value(
                "__jac_rt_any_getitem", self.any_parts(base) + self.any_parts(key)
            )
        );
    }
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
    if base.type.kind == MirKind.DICT
        and not slice.is_range
        and part.start is not None {
        return self.dict_get(base, self.lower_expr(part.start), site);
    }
    raise MirRefused(mir_refusal("subscript", base.type.render(), site));
}

impl MirLowering.container_set(
    base: MirValue, slice: uni.IndexSlice, value: MirValue, site: uni.UniNode
) {
    b = self.builder();
    self.refuse_inferred_any_store(base, value, site);
    if len(slice.slices) == 1 and slice.is_range {
        holder = base;
        if holder.type.kind == MirKind.OPT
            and holder.type.payload().kind == MirKind.LIST {
            holder = self.opt_unwrap_checked(
                holder, "'NoneType' object does not support item assignment"
            );
        }
        if holder.type.kind == MirKind.LIST {
            self.list_replace_range(self.spill(holder), slice.slices[0], value, site);
            return;
        }
    }
    if len(slice.slices) != 1 or slice.is_range or slice.slices[0].start is None {
        raise MirRefused(mir_refusal("subscript assignment", "slice", site));
    }
    key_nd = slice.slices[0].start;
    if base.type.kind == MirKind.OPT and mir_is_container(base.type.payload()) {
        base = self.opt_unwrap_checked(
            base, "'NoneType' object does not support item assignment"
        );
    }
    if base.type.kind == MirKind.LIST {
        elem = base.type.payload();
        index = self.list_index(
            base,
            self.coerce(self.lower_expr(key_nd), mir_int(), key_nd),
            LIST_ASSIGN_MESSAGE
        );
        if elem.kind == MirKind.C_STRUCT {
            b.store(self.struct_element(base, index), self.coerce(value, elem, site));
            return;
        }
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
    if name == "sort" {
        return self.list_sort(lst, nd);
    }
    args = self.call_args(nd);
    elem = lst.type.payload();
    if elem.kind == MirKind.C_STRUCT {
        if name == "append" and len(args) == 1 {
            self.struct_push(lst, self.lower_expr(args[0]), args[0]);
            return b.const_bool(False);
        }
        if name not in ("clear", "copy", "extend") {
            raise MirRefused(
                mir_refusal(
                    "list method",
                    f"{name} on a list of {elem.render()}",
                    nd,
                    "A list of C structs holds each struct inline; it appends, extends, copies, clears, indexes and iterates."
                )
            );
        }
    }
    kind = b.const_int(self.elem_kind(elem, nd), mir_int());
    if name == "append" and len(args) == 1 {
        self.runtime(
            "__jac_rt_list_push",
            [lst, self.to_bits(self.lower_expr(args[0]), elem, args[0]), kind]
        );
        return b.const_bool(False);
    }
    if name == "extend" and len(args) == 1 {
        other = self.lower_expr(args[0]);
        if other.type.kind in (MirKind.ITER, MirKind.SET, MirKind.DICT)
            and other.type.args {
            other = self.coerce(
                self.drain(self.spill(other), other.type.args[0], args[0]),
                lst.type,
                args[0]
            );
        } elif other.type.kind == MirKind.LIST and other.type is not lst.type {
            other = self.coerce(other, lst.type, args[0]);
        }
        if other.type is not lst.type {
            self.extend_from(lst, self.spill(other), args[0]);
            return b.const_bool(False);
        }
        self.runtime("__jac_rt_list_extend", [lst, other, kind]);
        return b.const_bool(False);
    }
    if name == "insert" and len(args) == 2 {
        size = self.container_len(lst);
        at = self.coerce(self.lower_expr(args[0]), mir_int(), args[0]);
        shifted = b.select(
            b.compare("lt", at, b.const_int(0, mir_int())),
            b.binary("add", at, size),
            at
        );
        low = b.select(
            b.compare("lt", shifted, b.const_int(0, mir_int())),
            b.const_int(0, mir_int()),
            shifted
        );
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
            b.compare("eq", size, b.const_int(0, mir_int())),
            "IndexError",
            POP_EMPTY_MESSAGE
        );
        at = b.binary("sub", size, b.const_int(1, mir_int()));
        if args {
            at = self.list_index(
                lst,
                self.coerce(self.lower_expr(args[0]), mir_int(), args[0]),
                "pop index out of range"
            );
        }
        bits = self.runtime("__jac_rt_list_pop", [lst, at]);
        if bits is None {
            return None;
        }
        if self.elem_kind(elem, nd) in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY) {
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
    if name == "remove" and len(args) == 1 {
        self.view_guard(lst, VIEW_REMOVE);
        found = self.list_scan(lst, self.lower_expr(args[0]), "find", args[0])
            if self.structural_elem(elem)
            else self.runtime(
                "__jac_rt_list_index",
                [lst, self.to_bits(self.lower_expr(args[0]), elem, args[0]), kind]
            );
        if found is None {
            return None;
        }
        self.raise_if(
            b.compare("lt", found, b.const_int(0, mir_int())),
            "ValueError",
            "list.remove(x): x not in list"
        );
        bits = self.runtime("__jac_rt_list_pop", [lst, found]);
        if bits is not None
            and self.elem_kind(elem, nd)
                in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY) {
            self.owned_element(b.ref_cast(bits, mir_ref(), True), elem);
        }
        return b.const_bool(False);
    }
    if name in ("index", "count")
        and len(args) == 1
        and (name == "count" or self.structural_elem(elem)) {
        return self.list_scan(lst, self.lower_expr(args[0]), name, args[0]);
    }
    if name == "index" and len(args) == 1 {
        position = self.runtime(
            "__jac_rt_list_index",
            [lst, self.to_bits(self.lower_expr(args[0]), elem, args[0]), kind]
        );
        if position is None {
            return None;
        }
        self.raise_if(
            b.compare("lt", position, b.const_int(0, mir_int())),
            "ValueError",
            LIST_VALUE_MESSAGE
        );
        return position;
    }
    return None;
}

impl MirLowering.list_sort(lst: MirValue, nd: uni.FuncCall) -> (MirValue | None) {
    b = self.builder();
    (args, named) = self.split_args(nd);
    if args or set(named) - {"key", "reverse"} {
        return None;
    }
    elem = lst.type.payload();
    key_fn: (MirValue | None) = None;
    if "key" in named {
        key_fn = self.key_function(named["key"]);
    } elif self.sort_kind(elem, nd) == KIND_REF {
        return None;
    }
    flag = b.const_bool(False);
    order = named.get("reverse");
    if order is not None {
        flag = self.condition(order);
    }
    held = self.spill(lst);
    if key_fn is not None {
        self.keyed_sort(held, key_fn, flag, nd);
    } else {
        self.runtime(
            "__jac_rt_list_sort",
            [held, b.const_int(self.sort_kind(elem, nd), mir_int()), flag]
        );
    }
    return b.const_bool(False);
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
        key = self.lower_expr(args[0]);
        fallback = self.spill(
            self.coerce(self.lower_expr(args[1]), result_type, args[1])
        )
            if len(args) == 2
            else None;
        found = self.runtime(
            "__jac_rt_dict_find", [d, self.to_bits(key, key_type, args[0]), key_kind]
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
        if self.elem_kind(value_type, nd)
            in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY) {
            handle = self.runtime("__jac_rt_dict_val_ref", [d, found, value_kind]);
            if handle is None {
                return None;
            }
            b.store(
                held,
                self.coerce(self.owned_element(handle, value_type), result_type, nd)
            );
        } else {
            bits = self.runtime("__jac_rt_dict_val_at", [d, found]);
            if bits is None {
                return None;
            }
            b.store(
                held,
                self.coerce(self.scalar_from_bits(bits, value_type), result_type, nd)
            );
        }
        b.branch(done);
        b.position(miss);
        if fallback is not None {
            b.store(held, fallback);
        } else {
            b.store(held, self.coerce(self.none_value(), result_type, nd));
        }
        b.branch(done);
        b.position(done);
        return b.load(held, result_type);
    }
    if name == "setdefault" and len(args) in (1, 2) {
        held = self.spill(d);
        key = self.spill(self.lower_expr(args[0]));
        absent = len(args) == 1
            and (value_type.kind == MirKind.STR or self.nullable_payload(value_type));
        fallback = self.spill(
            self.coerce(self.lower_expr(args[1]), value_type, nd)
                if len(args) == 2
                else self.absent_value(value_type, nd)
        );
        fallback_bits = b.const_int(0, mir_int())
            if absent
            else self.to_bits(fallback, value_type, nd);
        found = self.runtime_value(
            "__jac_rt_dict_find", [held, self.to_bits(key, key_type, args[0]), key_kind]
        );
        fn = self.st().fn;
        miss = fn.new_block("setdefault.miss");
        done = fn.new_block("setdefault.done");
        b.cond_branch(b.compare("lt", found, b.const_int(0, mir_int())), miss, done);
        b.position(miss);
        self.runtime(
            "__jac_rt_dict_set",
            [
                held,
                self.to_bits(key, key_type, args[0]),
                fallback_bits,
                key_kind,
                value_kind
            ]
        );
        b.branch(done);
        b.position(done);
        at = self.runtime_value(
            "__jac_rt_dict_find", [held, self.to_bits(key, key_type, args[0]), key_kind]
        );
        if self.elem_kind(value_type, nd)
            in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY) {
            return self.owned_element(
                self.runtime_value("__jac_rt_dict_val_ref", [held, at, value_kind]),
                value_type
            );
        }
        return self.scalar_from_bits(
            self.runtime_value("__jac_rt_dict_val_at", [held, at]), value_type
        );
    }
    if name == "popitem" and not args {
        result_type = self.expr_type(nd);
        if result_type.kind != MirKind.TUPLE or len(result_type.args) != 2 {
            return None;
        }
        key_cell = self.temp_slot(mir_int());
        val_bits = self.runtime_value(
            "__jac_rt_dict_popitem",
            [
                d,
                key_kind,
                value_kind,
                self.emit_value(MirOp.PTR_INT, mir_int(), [key_cell])
            ]
        );
        key_bits = b.load(key_cell, mir_int());
        parts: list[MirValue] = [];
        for (bits, part) in ((key_bits, key_type), (val_bits, value_type)) {
            if self.elem_kind(part, nd) in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY) {
                parts.append(
                    self.owned_element(b.ref_cast(bits, mir_ref(), True), part)
                );
            } else {
                parts.append(self.scalar_from_bits(bits, part));
            }
        }
        return self.emit_value(
            MirOp.TUPLE_MAKE,
            result_type,
            [
                self.coerce(parts[0], result_type.args[0], nd),
                self.coerce(parts[1], result_type.args[1], nd)
            ]
        );
    }
    if name == "pop" and len(args) == 2 {
        result_type = self.expr_type(nd);
        flag = self.temp_slot(mir_int());
        held = self.temp_slot(result_type);
        bits = self.runtime_value(
            "__jac_rt_dict_pop",
            [
                d,
                self.to_bits(self.lower_expr(args[0]), key_type, args[0]),
                key_kind,
                value_kind,
                self.emit_value(MirOp.PTR_INT, mir_int(), [flag])
            ]
        );
        fn = self.st().fn;
        hit = fn.new_block("pop.hit");
        miss = fn.new_block("pop.miss");
        done = fn.new_block("pop.done");
        b.cond_branch(
            b.compare("ne", b.load(flag, mir_int()), b.const_int(0, mir_int())),
            hit,
            miss
        );
        b.position(hit);
        if self.elem_kind(value_type, nd)
            in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY) {
            b.store(
                held,
                self.coerce(
                    self.owned_element(b.ref_cast(bits, mir_ref(), True), value_type),
                    result_type,
                    nd
                )
            );
        } else {
            b.store(
                held,
                self.coerce(self.scalar_from_bits(bits, value_type), result_type, nd)
            );
        }
        b.branch(done);
        b.position(miss);
        b.store(held, self.coerce(self.lower_expr(args[1]), result_type, args[1]));
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
            b.compare("eq", b.load(flag, mir_int()), b.const_int(0, mir_int())),
            "KeyError",
            KEY_MESSAGE
        );
        if self.elem_kind(value_type, nd)
            in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY) {
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
        if other.type.kind == MirKind.ANY {
            other = b.ref_cast(
                self.runtime_value(
                    "__jac_rt_dict_convert",
                    self.any_parts(other)
                        + [
                            self.creation_kind(d.type.args[0], nd),
                            self.creation_kind(d.type.args[1], nd)
                        ]
                ),
                d.type,
                True
            );
        } elif other.type.kind == MirKind.DICT and other.type is not d.type {
            self.merge_dict(d, other, nd, False);
            return b.const_bool(False);
        }
        if other.type is not d.type {
            raise MirRefused(
                mir_refusal("call", f"update with {other.type.render()}", nd)
            );
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
        b.cond_branch(
            b.compare("ge", following, b.const_int(0, mir_int())), body, done
        );
        b.position(body);
        if self.elem_kind(part, nd) == KIND_ANY {
            held = self.runtime_value(
                "__jac_rt_dict_key_ref" if name == "keys" else "__jac_rt_dict_val_ref",
                [d, b.load(cursor, mir_int()), part_kind]
            );
            self.container_add(made, self.owned_element(held, part), nd);
            b.branch(head);
            b.position(done);
            return made;
        }
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
    if name == "items" and not args {
        result_type = self.expr_type(nd);
        if result_type.kind != MirKind.LIST
            or result_type.payload().kind != MirKind.TUPLE {
            return None;
        }
        pair = result_type.payload();
        made = self.spill(self.new_list(pair, 8));
        pair_kind = b.const_int(self.elem_kind(pair, nd), mir_int());
        cursor = self.temp_slot(mir_int());
        b.store(cursor, b.const_int(-1, mir_int()));
        fn = self.st().fn;
        head = fn.new_block("items.head");
        body = fn.new_block("items.body");
        done = fn.new_block("items.done");
        b.branch(head);
        b.position(head);
        following = self.runtime_value(
            "__jac_rt_dict_next", [d, b.load(cursor, mir_int())]
        );
        b.store(cursor, following);
        b.cond_branch(
            b.compare("ge", following, b.const_int(0, mir_int())), body, done
        );
        b.position(body);
        at = b.load(cursor, mir_int());
        key = self.dict_entry(d, at, key_type, True, nd);
        held = self.dict_entry(d, at, value_type, False, nd);
        made_pair = self.emit_value(
            MirOp.TUPLE_MAKE,
            pair,
            [self.coerce(key, pair.args[0], nd), self.coerce(held, pair.args[1], nd)]
        );
        self.runtime(
            "__jac_rt_list_push", [made, self.to_bits(made_pair, pair, nd), pair_kind]
        );
        b.branch(head);
        b.position(done);
        return made;
    }
    return None;
}

impl MirLowering.dict_entry(
    d: MirValue, at: MirValue, part: MirType, is_key: bool, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    kind = self.elem_kind(part, site);
    if kind in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY) {
        handle = self.runtime_value(
            "__jac_rt_dict_key_ref" if is_key else "__jac_rt_dict_val_ref",
            [d, at, b.const_int(kind, mir_int())]
        );
        return self.owned_element(handle, part);
    }
    return self.scalar_from_bits(
        self.runtime_value(
            "__jac_rt_dict_key_at" if is_key else "__jac_rt_dict_val_at", [d, at]
        ),
        part
    );
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
            [
                s,
                self.to_bits(self.lower_expr(args[0]), elem, args[0]),
                b.const_int(0, mir_int()),
                kind,
                none_kind
            ]
        );
        return b.const_bool(False);
    }
    if name in ("discard", "remove") and len(args) == 1 {
        gone = self.runtime(
            "__jac_rt_dict_del",
            [s, self.to_bits(self.lower_expr(args[0]), elem, args[0]), kind, none_kind]
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
            self.extend_from(s, self.spill(other), args[0]);
            return b.const_bool(False);
        }
        self.runtime("__jac_rt_dict_update", [s, other, kind, none_kind]);
        return b.const_bool(False);
    }
    if name == "pop" and not args {
        bits = self.runtime_value(
            "__jac_rt_dict_popitem", [s, kind, none_kind, b.const_int(0, mir_int())]
        );
        if self.elem_kind(elem, nd) in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY) {
            return self.owned_element(b.ref_cast(bits, mir_ref(), True), elem);
        }
        return self.scalar_from_bits(bits, elem);
    }
    if len(args) == 1
        and name
            in (
                "union",
                "intersection",
                "difference",
                "symmetric_difference",
                "issubset",
                "issuperset",
                "isdisjoint",
                "intersection_update",
                "difference_update",
                "symmetric_difference_update"
            ) {
        other = self.lower_expr(args[0]);
        if other.type is not s.type and other.type.kind != MirKind.SET {
            gathered = self.spill(self.new_dict(elem, None, s.type));
            self.extend_from(gathered, self.spill(other), args[0]);
            other = gathered;
        }
        other = self.coerce(other, s.type, args[0]);
        return self.set_algebra(s, other, name, nd);
    }
    return None;
}

impl MirLowering.set_algebra(
    s: MirValue, other: MirValue, name: str, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    elem = s.type.payload();
    kind = b.const_int(self.elem_kind(elem, site), mir_int());
    none_kind = b.const_int(NO_VALUE_KIND, mir_int());
    held = self.spill(other);
    if name == "issubset" {
        return self.runtime_value("__jac_rt_set_within", [s, held, kind]);
    }
    if name == "issuperset" {
        return self.runtime_value("__jac_rt_set_within", [held, s, kind]);
    }
    if name == "isdisjoint" {
        return self.runtime_value("__jac_rt_set_disjoint", [s, held, kind]);
    }
    made: MirValue;
    if name == "union" {
        made = b.ref_cast(
            self.runtime_value("__jac_rt_dict_copy", [s, kind, none_kind]), s.type, True
        );
        self.runtime("__jac_rt_dict_update", [made, held, kind, none_kind]);
        return made;
    }
    if name in ("symmetric_difference", "symmetric_difference_update") {
        made = b.ref_cast(
            self.runtime_value("__jac_rt_set_xor", [s, held, kind]), s.type, True
        );
    } else {
        made = b.ref_cast(
            self.runtime_value(
                "__jac_rt_set_filter",
                [s, held, kind, b.const_bool(name.startswith("intersection"))]
            ),
            s.type,
            True
        );
    }
    if not name.endswith("_update") {
        return made;
    }
    self.runtime("__jac_rt_dict_clear", [s, kind, none_kind]);
    self.runtime("__jac_rt_dict_update", [s, made, kind, none_kind]);
    return b.const_bool(False);
}

impl MirLowering.set_operator(
    op: str, left: MirValue, right: MirValue, in_place: bool, site: uni.UniNode
) -> (MirValue | None) {
    if left.type.kind != MirKind.SET or right.type.kind != MirKind.SET {
        return None;
    }
    names: dict[str, str] = {
        Tok.BW_OR: "union",
        Tok.BW_AND: "intersection",
        Tok.MINUS: "difference",
        Tok.BW_XOR: "symmetric_difference"
    };
    name = names.get(op, "");
    if not name {
        return None;
    }
    other = self.coerce(right, left.type, site);
    if not in_place {
        return self.set_algebra(left, other, name, site);
    }
    if name == "union" {
        b = self.builder();
        elem = left.type.payload();
        self.runtime(
            "__jac_rt_dict_update",
            [
                left,
                other,
                b.const_int(self.elem_kind(elem, site), mir_int()),
                b.const_int(NO_VALUE_KIND, mir_int())
            ]
        );
    } else {
        self.set_algebra(left, other, f"{name}_update", site);
    }
    return left;
}

impl MirLowering.contains(
    item: MirValue, holder: MirValue, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    if holder.type.kind == MirKind.ANY {
        return self.any_contains(item, holder, site);
    }
    if holder.type.kind == MirKind.LIST
        and self.structural_elem(holder.type.payload()) {
        return self.list_scan(holder, item, "in", site);
    }
    if holder.type.kind == MirKind.OPT {
        return self.contains(
            item,
            self.opt_unwrap_checked(
                holder, "argument of type 'NoneType' is not iterable", "TypeError"
            ),
            site
        );
    }
    if holder.type.kind == MirKind.LIST
        and holder.type.payload().kind == MirKind.ENUM
        and self.is_text(item)
        and self.enum_layout_of(holder.type.payload(), site).is_string_enum {
        elem = holder.type.payload();
        ordinal = self.string_enum_ordinal(item, elem, site);
        found = self.runtime(
            "__jac_rt_list_contains",
            [holder, ordinal, b.const_int(self.elem_kind(elem, site), mir_int())]
        );
        if found is not None {
            return found;
        }
    }
    if holder.type.kind == MirKind.LIST {
        elem = holder.type.payload();
        found = self.runtime(
            "__jac_rt_list_contains",
            [
                holder,
                self.to_bits(item, elem, site),
                b.const_int(self.elem_kind(elem, site), mir_int())
            ]
        );
        if found is not None {
            return found;
        }
    }
    if holder.type.kind in (MirKind.DICT, MirKind.SET)
        and holder.type.args[0].kind == MirKind.ENUM
        and self.is_text(item)
        and self.enum_layout_of(holder.type.args[0], site).is_string_enum {
        key = holder.type.args[0];
        at = self.runtime(
            "__jac_rt_dict_find",
            [
                holder,
                self.string_enum_ordinal(item, key, site),
                b.const_int(self.elem_kind(key, site), mir_int())
            ]
        );
        if at is not None {
            return b.compare("ge", at, b.const_int(0, mir_int()));
        }
    }
    if holder.type.kind in (MirKind.DICT, MirKind.SET) {
        key = holder.type.args[0];
        at = self.runtime(
            "__jac_rt_dict_find",
            [
                holder,
                self.to_bits(item, key, site),
                b.const_int(self.elem_kind(key, site), mir_int())
            ]
        );
        if at is not None {
            return b.compare("ge", at, b.const_int(0, mir_int()));
        }
    }
    if holder.type.kind == MirKind.TUPLE {
        held = self.spill(holder);
        probe = self.spill(item);
        matched = b.const_bool(False);
        for index in range(len(holder.type.args)) {
            same = self.compare_values(
                Tok.EE, probe, self.tuple_get(held, index), site
            );
            matched = b.binary("or", matched, same);
        }
        return matched;
    }
    raise MirRefused(mir_refusal("comparison", f"in {holder.type.render()}", site));
}

impl MirLowering.container_eq(left: MirValue, right: MirValue) -> MirValue {
    b = self.builder();
    if left.type.kind == MirKind.LIST
        and right.type.kind == MirKind.LIST
        and (
            self.user_eq_elem(left.type.payload())
            or self.user_eq_elem(right.type.payload())
        ) {
        return self.list_pairwise_eq(left, right);
    }
    if left.type.kind == MirKind.DICT
        and left.type is right.type
        and self.user_eq_elem(left.type.args[1]) {
        return self.dict_pairwise_eq(left, right);
    }
    if any(
        mir_is_container(member)
            or member.kind in (MirKind.BYTES, MirKind.BYTEARRAY, MirKind.TUPLE)
            or (member.kind == MirKind.OPT and mir_is_container(member.payload()))
        for member in list(left.type.args) + list(right.type.args)
    ) {
        return self.any_compare("eq", left, right, self.module);
    }
    if left.type is not right.type {
        if not mir_is_container(right.type)
            and right.type.kind
                not in (MirKind.BYTES, MirKind.BYTEARRAY, MirKind.TUPLE, MirKind.ANY) {
            raise MirRefused(
                mir_refusal(
                    "comparison", f"{left.type.render()} == {right.type.render()}"
                )
            );
        }
        return self.any_compare("eq", left, right, self.module);
    }
    if left.type.kind == MirKind.LIST {
        same = self.runtime(
            "__jac_rt_list_eq",
            [
                left,
                right,
                b.const_int(self.elem_kind(left.type.payload(), self.module), mir_int())
            ]
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
        [
            left,
            right,
            b.const_int(self.elem_kind(key, self.module), mir_int()),
            b.const_int(value_kind, mir_int())
        ]
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
        b.cond_branch(
            b.compare("lt", following, self.container_len(source)), body, otherwise
        );
        b.position(body);
        self.store_name(nd.target, self.list_read(source, b.load(cursor, mir_int())));
    } else {
        upcoming = self.runtime("__jac_rt_dict_next", [source, current]);
        if upcoming is None {
            raise MirRefused(
                mir_refusal("statement", "for over " + source.type.render(), nd)
            );
        }
        b.store(cursor, upcoming);
        b.cond_branch(
            b.compare("ge", upcoming, b.const_int(0, mir_int())), body, otherwise
        );
        b.position(body);
        key = source.type.args[0];
        kind = self.elem_kind(key, nd);
        at = b.load(cursor, mir_int());
        if kind in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY) {
            handle = self.runtime(
                "__jac_rt_dict_key_ref", [source, at, b.const_int(kind, mir_int())]
            );
            if handle is None {
                raise MirRefused(
                    mir_refusal("statement", "for over " + source.type.render(), nd)
                );
            }
            self.store_name(nd.target, self.owned_element(handle, key));
        } else {
            bits = self.runtime("__jac_rt_dict_key_at", [source, at]);
            if bits is None {
                raise MirRefused(
                    mir_refusal("statement", "for over " + source.type.render(), nd)
                );
            }
            self.store_name(nd.target, self.scalar_from_bits(bits, key));
        }
    }
    self.st().loops.append(MirLoopTarget(head=head, after=after, passes=nd));
    self.lower_pass(nd, nd.body);
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
            self.unbind_local(target);
            continue;
        }
        if self.unbind_local(target) {
            continue;
        }
        if isinstance(target, uni.AtomTrailer)
            and target.is_attr
            and self.accessor_delete(target) {
            continue;
        }
        if not isinstance(target, uni.AtomTrailer)
            or target.is_attr
            or not isinstance(target.right, uni.IndexSlice) {
            raise MirRefused(
                mir_refusal("statement", "del of " + type(target).__name__, target)
            );
        }
        environ = self.environ_unit(target.target);
        if environ is not None {
            self.environ_call(
                environ, "delitem", [self.environ_key(target.right, target)], target
            );
            continue;
        }
        holder = self.lower_expr(target.target);
        slice = target.right;
        if holder.type.kind == MirKind.LIST {
            holder = self.spill(holder);
            self.view_guard(holder, VIEW_DELETE);
        }
        if holder.type.kind == MirKind.LIST
            and slice.is_range
            and len(slice.slices) == 1
            and slice.slices[0].step is None {
            self.list_delete_range(holder, slice.slices[0], target);
            continue;
        }
        if len(slice.slices) != 1 or slice.is_range or slice.slices[0].start is None {
            raise MirRefused(mir_refusal("statement", "del of a slice", target));
        }
        key_nd = slice.slices[0].start;
        if holder.type.kind == MirKind.LIST {
            at = self.list_index(
                holder,
                self.coerce(self.lower_expr(key_nd), mir_int(), key_nd),
                "list assignment index out of range"
            );
            bits = self.runtime("__jac_rt_list_pop", [holder, at]);
            if bits is None {
                continue;
            }
            elem = holder.type.payload();
            popped = self.owned_element(b.ref_cast(bits, mir_ref(), True), elem)
                if self.elem_kind(elem, target)
                    in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY)
                else self.scalar_from_bits(bits, elem);
            if self.osp_graph_type(target.type) {
                self.osp_destroy_held(popped, target.type, target);
            }
            continue;
        }
        if holder.type.kind == MirKind.DICT {
            (key_type, value_type) = (holder.type.args[0], holder.type.args[1]);
            key = self.spill(self.lower_expr(key_nd));
            if self.osp_graph_type(target.type) {
                holder = self.spill(holder);
                self.osp_destroy_held(
                    self.dict_get(holder, key, target), target.type, target
                );
            }
            gone = self.runtime(
                "__jac_rt_dict_del",
                [
                    holder,
                    self.to_bits(key, key_type, key_nd),
                    b.const_int(self.elem_kind(key_type, target), mir_int()),
                    b.const_int(self.elem_kind(value_type, target), mir_int())
                ]
            );
            if gone is not None {
                self.raise_if(b.logical_not(gone), "KeyError", KEY_MESSAGE);
            }
            continue;
        }
        raise MirRefused(
            mir_refusal("statement", "del on " + holder.type.render(), target)
        );
    }
}

impl MirLowering.list_delete_range(lst: MirValue, part: uni.Slice, site: uni.UniNode) {
    self.list_replace_range(lst, part, None, site);
}

impl MirLowering.list_replace_range(
    lst: MirValue, part: uni.Slice, values: (MirValue | None), site: uni.UniNode
) {
    b = self.builder();
    if part.step is not None {
        raise MirRefused(mir_refusal("subscript assignment", "extended slice", site));
    }
    fresh: (MirValue | None) = None;
    if values is not None {
        self.view_guard(lst, VIEW_SLICE);
        fresh = self.spill(self.new_list(lst.type.payload(), 0));
        self.extend_from(fresh, self.spill(values), site);
    }
    (start, stop, _) = self.list_bounds(lst, part, site);
    kind = b.const_int(self.elem_kind(lst.type.payload(), site), mir_int());
    self.runtime("__jac_rt_list_delete_range", [lst, start, stop, kind]);
    if fresh is not None {
        one = b.const_int(1, mir_int());
        size = self.container_len(lst);
        tail = self.runtime("__jac_rt_list_slice", [lst, start, size, one, kind]);
        if tail is None {
            raise MirRefused(mir_refusal("subscript assignment", "slice", site));
        }
        kept_tail = self.spill(b.ref_cast(tail, lst.type, True));
        self.runtime("__jac_rt_list_delete_range", [lst, start, size, kind]);
        self.runtime("__jac_rt_list_extend", [lst, fresh, kind]);
        self.runtime("__jac_rt_list_extend", [lst, kept_tail, kind]);
    }
}

impl MirLowering.container_rebuild(
    value: MirValue, to: MirType, site: uni.UniNode
) -> MirValue {
    same_storage = len(value.type.args) == len(to.args)
        and all(
            have is want
                or (
                    have.kind == MirKind.OBJ
                    and want.kind == MirKind.OBJ
                    and self.obj_extends(have.name, want.name)
                ) for (have, want) in zip(value.type.args, to.args)
        );
    if same_storage {
        return self.builder().ref_cast(value, to, False);
    }
    if to.kind == MirKind.LIST {
        made = self.spill(self.new_list(to.payload(), 4));
        self.extend_from(made, value, site);
        return made;
    }
    if to.kind == MirKind.SET {
        made = self.spill(self.new_dict(to.payload(), None, to));
        self.extend_from(made, value, site);
        return made;
    }
    made = self.spill(self.new_dict(to.args[0], to.args[1], to));
    self.merge_dict(made, value, site, False);
    return made;
}

impl MirLowering.nullable_payload(t: MirType) -> bool {
    return t.kind == MirKind.STR_REF
        or (
            mir_holds_ref(t)
            and t.kind not in (MirKind.STR, MirKind.TUPLE, MirKind.ANY, MirKind.OPT)
        );
}

impl MirLowering.sort_kind(t: MirType, site: uni.UniNode) -> int {
    if t.kind == MirKind.INT and not t.signed and t.width == 64 {
        return KIND_UINT;
    }
    kind = self.elem_kind(t, site);
    if kind == KIND_REF
        and t.kind in (MirKind.LIST, MirKind.BYTES, MirKind.BYTEARRAY, MirKind.SET) {
        return SORT_TAGGED_KIND + self.any_tag(t, site);
    }
    return kind;
}

impl MirLowering.unbind_local(target: uni.Expr) -> bool {
    if not isinstance(target, uni.Name) or target.sym is None {
        return False;
    }
    slot = self.st().locals.get(id(target.sym));
    if slot is None or self.cell_of(id(target.sym)) is not None {
        return False;
    }
    if mir_holds_ref(slot.type) {
        b = self.builder();
        b.store(slot, b.const_null(slot.type));
    }
    return True;
}

impl MirLowering.list_extend_in_place(
    op: str, current: MirValue, value: MirValue, site: uni.UniNode
) -> (MirValue | None) {
    if op == Tok.PLUS
        and current.type.kind == MirKind.BYTEARRAY
        and value.type.kind in (MirKind.BYTES, MirKind.BYTEARRAY) {
        source = self.spill(value);
        (data, size) = self.byte_parts(source);
        self.runtime("__jac_rt_bytearray_extend", [current, data, size]);
        return current;
    }
    if op != Tok.PLUS
        or current.type.kind != MirKind.LIST
        or value.type.kind != MirKind.LIST {
        return None;
    }
    other = value
        if value.type is current.type
        else self.coerce(value, current.type, site);
    elem = current.type.payload();
    self.view_guard(current, VIEW_IADD);
    self.runtime(
        "__jac_rt_list_extend",
        [
            current,
            other,
            self.builder().const_int(self.elem_kind(elem, site), mir_int())
        ]
    );
    return current;
}

impl MirLowering.struct_words(elem: MirType) -> MirValue {
    b = self.builder();
    size = self.st().fn.new_value(mir_int());
    b.emit(MirInstr(op=MirOp.SIZEOF, result=size, type_arg=elem));
    return b.binary(
        "floordiv",
        b.binary("add", size, b.const_int(7, mir_int())),
        b.const_int(8, mir_int())
    );
}

impl MirLowering.struct_element(lst: MirValue, index: MirValue) -> MirValue {
    b = self.builder();
    elem = lst.type.payload();
    data = self.emit_value(
        MirOp.MEM_LOAD,
        mir_int(),
        [b.binary("add", self.address_of(lst), b.const_int(16, mir_int()))]
    );
    stride = b.binary("mul", self.struct_words(elem), b.const_int(8, mir_int()));
    return self.emit_value(
        MirOp.PTR_CAST,
        mir_c_ptr(elem),
        [b.binary("add", data, b.binary("mul", b.convert(index, mir_int()), stride))]
    );
}

impl MirLowering.struct_push(lst: MirValue, item: MirValue, site: uni.UniNode) {
    elem = lst.type.payload();
    at = self.call_rt("__jac_rt_list_push_words", [lst, self.struct_words(elem)]);
    self.builder().store(
        self.emit_value(MirOp.PTR_CAST, mir_c_ptr(elem), [at]),
        self.coerce(item, elem, site)
    );
}

impl MirLowering.user_eq_elem(t: MirType) -> bool {
    if t.kind == MirKind.OPT {
        return self.user_eq_elem(t.payload());
    }
    if t.kind == MirKind.OBJ and t.name in self.archetypes {
        return self.find_method(self.archetypes[t.name], "__eq__") is not None;
    }
    if t.kind in (MirKind.LIST, MirKind.SET) {
        return self.user_eq_elem(t.payload());
    }
    if t.kind == MirKind.DICT {
        return self.user_eq_elem(t.args[1]);
    }
    if t.kind == MirKind.TUPLE {
        return any(self.user_eq_elem(member) for member in t.args);
    }
    return False;
}

impl MirLowering.structural_elem(t: MirType) -> bool {
    if self.user_eq_elem(t) {
        return True;
    }
    if t.kind == MirKind.OPT {
        return self.structural_elem(t.payload());
    }
    if mir_is_container(t) or t.kind in (MirKind.BYTES, MirKind.BYTEARRAY) {
        return True;
    }
    if t.kind == MirKind.TUPLE {
        return any(self.structural_elem(member) for member in t.args);
    }
    return False;
}

impl MirLowering.string_enum_ordinal(
    item: MirValue, elem: MirType, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    layout = self.enum_layout_of(elem, site);
    probe = self.spill(item);
    ordinal = b.const_int(-1, mir_int());
    for member in reversed(layout.members) {
        same = self.compare_values(
            Tok.EE, probe, b.const_str(member.str_value or "", mir_str()), site
        );
        ordinal = b.select(
            same, b.const_int(self.enum_payload(layout, member), mir_int()), ordinal
        );
    }
    return ordinal;
}

impl MirLowering.list_scan(
    lst: MirValue, item: MirValue, mode: str, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    held = self.spill(lst);
    probe = self.spill(item);
    cursor = self.temp_slot(mir_int());
    found = self.temp_slot(mir_int());
    b.store(cursor, b.const_int(0, mir_int()));
    b.store(found, b.const_int(-1 if mode != "count" else 0, mir_int()));
    head = fn.new_block("scan.head");
    body = fn.new_block("scan.body");
    hit = fn.new_block("scan.hit");
    step = fn.new_block("scan.step");
    done = fn.new_block("scan.done");
    b.branch(head);
    b.position(head);
    at = b.load(cursor, mir_int());
    b.cond_branch(b.compare("lt", at, self.container_len(held)), body, done);
    b.position(body);
    elem = self.spill(self.list_read(held, b.load(cursor, mir_int())));
    if self.identity_first(elem.type) and self.identity_first(probe.type) {
        equal = fn.new_block("scan.eq");
        b.cond_branch(self.identity(elem, probe, site), hit, equal);
        b.position(equal);
    }
    same = self.truthy(self.compare_values(Tok.EE, elem, probe, site), site);
    b.cond_branch(same, hit, step);
    b.position(hit);
    if mode == "count" {
        b.store(
            found, b.binary("add", b.load(found, mir_int()), b.const_int(1, mir_int()))
        );
        b.branch(step);
    } else {
        b.store(found, b.load(cursor, mir_int()));
        b.branch(done);
    }
    b.position(step);
    b.store(
        cursor, b.binary("add", b.load(cursor, mir_int()), b.const_int(1, mir_int()))
    );
    b.branch(head);
    b.position(done);
    result = b.load(found, mir_int());
    if mode == "in" {
        return b.compare("ge", result, b.const_int(0, mir_int()));
    }
    if mode == "index" {
        self.raise_if(
            b.compare("lt", result, b.const_int(0, mir_int())),
            "ValueError",
            LIST_VALUE_MESSAGE
        );
    }
    return result;
}

impl MirLowering.identity_first(t: MirType) -> bool {
    return t.kind == MirKind.ANY
        or (
            mir_holds_ref(t)
            and t.kind not in (MirKind.STR, MirKind.STR_REF, MirKind.OPT, MirKind.TUPLE)
        );
}

impl MirLowering.list_pairwise_eq(left: MirValue, right: MirValue) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    a = self.spill(left);
    c = self.spill(right);
    verdict = self.temp_slot(mir_bool());
    cursor = self.temp_slot(mir_int());
    b.store(verdict, b.compare("eq", self.container_len(a), self.container_len(c)));
    b.store(cursor, b.const_int(0, mir_int()));
    head = fn.new_block("peq.head");
    body = fn.new_block("peq.body");
    differ = fn.new_block("peq.differ");
    step = fn.new_block("peq.step");
    done = fn.new_block("peq.done");
    b.branch(head);
    b.position(head);
    more = b.binary(
        "and",
        b.load(verdict, mir_bool()),
        b.compare("lt", b.load(cursor, mir_int()), self.container_len(a))
    );
    b.cond_branch(more, body, done);
    b.position(body);
    at = b.load(cursor, mir_int());
    x = self.spill(self.list_read(a, at));
    y = self.spill(self.list_read(c, b.load(cursor, mir_int())));
    same = self.truthy(self.compare_values(Tok.EE, x, y, self.module), self.module);
    b.cond_branch(same, step, differ);
    b.position(differ);
    b.store(verdict, b.const_bool(False));
    b.branch(done);
    b.position(step);
    b.store(
        cursor, b.binary("add", b.load(cursor, mir_int()), b.const_int(1, mir_int()))
    );
    b.branch(head);
    b.position(done);
    return b.load(verdict, mir_bool());
}

impl MirLowering.dict_pairwise_eq(left: MirValue, right: MirValue) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    a = self.spill(left);
    c = self.spill(right);
    key_type = a.type.args[0];
    verdict = self.temp_slot(mir_bool());
    cursor = self.temp_slot(mir_int());
    b.store(verdict, b.compare("eq", self.container_len(a), self.container_len(c)));
    b.store(cursor, b.const_int(-1, mir_int()));
    head = fn.new_block("deq.head");
    body = fn.new_block("deq.body");
    present = fn.new_block("deq.present");
    differ = fn.new_block("deq.differ");
    done = fn.new_block("deq.done");
    b.branch(head);
    b.position(head);
    following = self.runtime_value(
        "__jac_rt_dict_next", [a, b.load(cursor, mir_int())]
    );
    b.store(cursor, following);
    b.cond_branch(
        b.binary(
            "and",
            b.load(verdict, mir_bool()),
            b.compare("ge", following, b.const_int(0, mir_int()))
        ),
        body,
        done
    );
    b.position(body);
    at = b.load(cursor, mir_int());
    key = self.spill(self.dict_part(a, at, key_type, True));
    other_at = self.runtime_value(
        "__jac_rt_dict_find",
        [
            c,
            self.to_bits(key, key_type, self.module),
            b.const_int(self.elem_kind(key_type, self.module), mir_int())
        ]
    );
    b.cond_branch(
        b.compare("ge", other_at, b.const_int(0, mir_int())), present, differ
    );
    b.position(present);
    mine = self.spill(self.dict_entry_value(a, b.load(cursor, mir_int()), self.module));
    theirs = self.spill(self.dict_entry_value(c, other_at, self.module));
    same = self.truthy(
        self.compare_values(Tok.EE, mine, theirs, self.module), self.module
    );
    b.cond_branch(same, head, differ);
    b.position(differ);
    b.store(verdict, b.const_bool(False));
    b.branch(done);
    b.position(done);
    return b.load(verdict, mir_bool());
}

impl MirLowering.absent_value(t: MirType, site: uni.UniNode) -> MirValue {
    if t.kind == MirKind.STR or self.nullable_payload(t) {
        return self.builder().const_null(t);
    }
    return self.coerce(self.none_value(), t, site);
}
