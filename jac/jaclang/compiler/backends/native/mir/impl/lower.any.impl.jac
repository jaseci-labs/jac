impl MirLowering.any_tag(t: MirType, site: uni.UniNode) -> int {
    if t.kind == MirKind.INT {
        return ANY_INT_TAG;
    }
    if t.kind == MirKind.ENUM {
        return ANY_ENUM_TAG;
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
    if t.kind
        in (
            MirKind.OBJ,
            MirKind.OSP,
            MirKind.FN,
            MirKind.BYTES,
            MirKind.BYTEARRAY,
            MirKind.TUPLE,
            MirKind.FILE
        ) {
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
            [
                b.str_part(value, "root"),
                b.str_part(value, "data"),
                b.str_part(value, "len")
            ]
        );
        if made is None {
            raise MirRefused(mir_refusal("conversion", "str to any", site));
        }
        source = made;
    }
    if value.type.kind == MirKind.ENUM {
        return self.emit_value(
            MirOp.ANY_BOX,
            mir_any(),
            [self.enum_box(value, site)],
            int_value=ANY_ENUM_TAG
        );
    }
    if value.type.kind == MirKind.TUPLE {
        source = self.tuple_box(value, site);
        return self.emit_value(
            MirOp.ANY_BOX, mir_any(), [source], int_value=ANY_OBJ_TAG
        );
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
    made = self.any_make(
        b.const_int(ANY_NONE_TAG, mir_int()), b.const_int(0, mir_int())
    );
    made.owned = True;
    return made;
}

impl MirLowering.any_unbox(
    value: MirValue, to: MirType, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    if to.kind == MirKind.ANY {
        return value;
    }
    if to.kind == MirKind.NONE {
        return self.none_value();
    }
    if to.kind == MirKind.ENUM {
        return b.convert(
            self.runtime_value("__jac_rt_enum_value", self.any_parts(value)), to
        );
    }
    if to.kind in (MirKind.INT, MirKind.BOOL, MirKind.FLOAT) {
        bits = self.emit_value(MirOp.ANY_PAYLOAD, mir_int(), [value]);
        if to.kind == MirKind.BOOL {
            return b.compare("ne", bits, b.const_int(0, mir_int()));
        }
        if to.kind == MirKind.FLOAT {
            held_any = self.spill(value);
            raw = self.emit_value(MirOp.ANY_PAYLOAD, mir_int(), [held_any]);
            tag = self.emit_value(MirOp.ANY_TAG, mir_int(), [held_any]);
            integral = b.binary(
                "or",
                b.compare("eq", tag, b.const_int(ANY_INT_TAG, mir_int())),
                b.compare("eq", tag, b.const_int(ANY_BOOL_TAG, mir_int()))
            );
            return b.convert(
                b.select(
                    integral,
                    b.convert(raw, mir_float()),
                    self.emit_value(MirOp.BITCAST, mir_float(), [raw])
                ),
                to
            );
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
        fn = self.st().fn;
        result = self.temp_slot(to);
        some = fn.new_block("unbox.some");
        absent = fn.new_block("unbox.none");
        done = fn.new_block("unbox.done");
        b.cond_branch(present, some, absent);
        b.position(some);
        b.store(result, self.opt_wrap(self.any_unbox(held, to.payload(), site), to));
        b.branch(done);
        b.position(absent);
        b.store(result, b.const_null(to));
        b.branch(done);
        b.position(done);
        return b.load(result, to);
    }
    if to.kind == MirKind.TUPLE {
        return self.tuple_unbox(b.ref_cast(held, mir_ref(), False), to);
    }
    if to.kind in (MirKind.LIST, MirKind.DICT, MirKind.SET) {
        return self.any_bind(held, to, site);
    }
    if mir_holds_ref(to) {
        return b.ref_cast(held, to, False);
    }
    raise MirRefused(mir_refusal("conversion", f"any to {to.render()}", site));
}

impl MirLowering.bind_family(t: MirType, site: uni.UniNode) -> int {
    if t.kind in (MirKind.OBJ, MirKind.OSP) {
        return ANY_OBJ_TAG;
    }
    if t.kind not in (MirKind.LIST, MirKind.DICT, MirKind.SET) {
        return -1;
    }
    kinds = [self.elem_kind(arg, site) for arg in t.args];
    if any(
        kind not in (KIND_ANY, KIND_INT, KIND_FLOAT, KIND_BOOL, KIND_STR)
        for kind in kinds
    ) {
        return -1;
    }
    family = {
        MirKind.LIST: ANY_LIST_TAG,
        MirKind.DICT: ANY_DICT_TAG,
        MirKind.SET: ANY_SET_TAG
    }[t.kind];
    for (index, kind) in enumerate(kinds) {
        family = family | ((kind + 1) << (8 * (index + 1)));
    }
    return family;
}

impl MirLowering.any_bind(held: MirValue, to: MirType, site: uni.UniNode) -> MirValue {
    b = self.builder();
    first = self.elem_kind(to.args[0], site);
    second = self.elem_kind(to.args[1], site) if to.kind == MirKind.DICT else KIND_ANY;
    if first == KIND_ANY and second == KIND_ANY {
        return b.ref_cast(held, to, False);
    }
    want = {
        MirKind.LIST: ANY_LIST_TAG,
        MirKind.DICT: ANY_DICT_TAG,
        MirKind.SET: ANY_SET_TAG
    }[to.kind];
    parts = [to.kind.value] + [arg.render() for arg in to.args];
    label = self.emit_value(
        MirOp.CSTR, mir_c_ptr(mir_int(8, False)), [], str_value="_".join(parts)
    );
    second_family = self.bind_family(to.args[1], site)
        if to.kind == MirKind.DICT
        else -1;
    made = self.runtime_value(
        "__jac_rt_any_bind",
        self.any_parts(held)
            + [
                b.const_int(want, mir_int()),
                b.const_int(first, mir_int()),
                b.const_int(self.bind_family(to.args[0], site), mir_int()),
                b.const_int(second, mir_int()),
                b.const_int(second_family, mir_int()),
                label
            ]
    );
    return b.ref_cast(made, to, True);
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
    self.runtime("__jac_rt_any_box_hold", [handle]);
    address = self.address_of(handle);
    tag = self.emit_value(MirOp.MEM_LOAD, mir_int(), [address]);
    payload = self.emit_value(
        MirOp.MEM_LOAD, mir_int(), [b.binary("add", address, b.const_int(8, mir_int()))]
    );
    made = self.any_make(tag, payload);
    made.owned = True;
    return made;
}

impl MirLowering.identity(
    left: MirValue, right: MirValue, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    if left.type.kind == MirKind.ANY or right.type.kind == MirKind.ANY {
        return self.runtime_value(
            "__jac_rt_any_same",
            self.any_parts(self.any_box(left, site))
                + self.any_parts(self.any_box(right, site))
        );
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
    if MirKind.OPT in (left.type.kind, right.type.kind)
        and all(
            side.type.kind == MirKind.OBJ
                or (
                    side.type.kind == MirKind.OPT
                    and side.type.payload().kind == MirKind.OBJ
                ) for side in (left, right)
        ) {
        words: list[MirValue] = [];
        for side in (left, right) {
            if side.type.kind == MirKind.OPT {
                held = self.spill(side);
                words.append(
                    b.select(
                        self.opt_present(held),
                        self.address_of(self.opt_get(held)),
                        b.const_int(0, mir_int())
                    )
                );
            } else {
                words.append(self.address_of(side));
            }
        }
        return b.compare("eq", words[0], words[1]);
    }
    if (left.type.kind == MirKind.OPT) != (right.type.kind == MirKind.OPT) {
        boxed = left if left.type.kind == MirKind.OPT else right;
        plain = right if left.type.kind == MirKind.OPT else left;
        if boxed.type.payload().is_numeric() and plain.type.is_numeric() {
            (held, payload, absent, done) = self.opt_begin(boxed, mir_bool());
            self.opt_switch(held, self.identity(payload, plain, site), absent, done);
            return self.opt_end(held, b.const_bool(False), done);
        }
    }
    if MirKind.OPT in (left.type.kind, right.type.kind)
        and self.ref_word_side(left)
        and self.ref_word_side(right) {
        return b.compare("eq", self.ref_word(left), self.ref_word(right));
    }
    raise MirRefused(
        mir_refusal(
            "comparison", f"{left.type.render()} is {right.type.render()}", site
        )
    );
}

impl MirLowering.ref_word_side(value: MirValue) -> bool {
    t = value.type.payload() if value.type.kind == MirKind.OPT else value.type;
    return t.kind
        in (MirKind.OBJ, MirKind.OSP, MirKind.LIST, MirKind.DICT, MirKind.SET);
}

impl MirLowering.ref_word(value: MirValue) -> MirValue {
    b = self.builder();
    if value.type.kind != MirKind.OPT {
        return self.address_of(value);
    }
    held = self.spill(value);
    return b.select(
        self.opt_present(held),
        self.address_of(self.opt_get(held)),
        b.const_int(0, mir_int())
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
    if value.type.kind in (MirKind.ENUM, MirKind.CLASS) {
        return b.const_bool(True);
    }
    if value.type.kind == MirKind.OBJ and value.type.name in self.archetypes {
        arch = self.archetypes[value.type.name];
        for hook in ("__bool__", "__len__") {
            found = self.find_method(arch, hook);
            if found is None {
                continue;
            }
            decl = self.method_decl_of(found);
            if decl is None or decl.params {
                return None;
            }
            answer = self.hook_call(value, arch, decl);
            return self.truthy(answer, site);
        }
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
            b.compare(
                "gt", b.load(cursor.stride, mir_int()), b.const_int(0, mir_int())
            ),
            b.compare("lt", now, end),
            b.compare("gt", now, end)
        );
    }
    return None;
}

impl MirLowering.any_to_str(value: MirValue, site: uni.UniNode) -> MirValue {
    return self.any_text("__jac_rt_any_str", value);
}

impl MirLowering.any_text(helper: str, value: MirValue) -> MirValue {
    return self.owned_text(
        self.call_rt(
            helper,
            [
                self.emit_value(MirOp.ANY_TAG, mir_int(), [value]),
                self.emit_value(MirOp.ANY_PAYLOAD, mir_int(), [value])
            ]
        )
    );
}

impl MirLowering.any_parts(value: MirValue) -> list[MirValue] {
    return [
        self.emit_value(MirOp.ANY_TAG, mir_int(), [value]),
        self.emit_value(MirOp.ANY_PAYLOAD, mir_int(), [value])
    ];
}

impl MirLowering.any_compare(
    name: str, left: MirValue, right: MirValue, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    if name in ("eq", "ne") {
        for (mine, other) in ((left, right), (right, left)) {
            arch = self.archetypes.get(mine.type.name)
                if mine.type.kind == MirKind.OBJ
                else None;
            if arch is not None and self.find_method(arch, "__eq__") is not None {
                same = self.object_eq(mine, other, site);
                return same if name == "eq" else b.logical_not(same);
            }
        }
    }
    parts = self.any_parts(self.any_box(left, site))
        + self.any_parts(self.any_box(right, site));
    if name in ("eq", "ne") {
        same = self.runtime_value("__jac_rt_any_equal", parts);
        return same if name == "eq" else b.logical_not(same);
    }
    return self.runtime_value(
        "__jac_rt_any_order", parts + [b.const_int(ANY_ORDER_CODES[name], mir_int())]
    );
}

impl MirLowering.value_comparable(left: MirValue, right: MirValue, name: str) -> bool {
    shaped = (
        MirKind.LIST,
        MirKind.DICT,
        MirKind.SET,
        MirKind.TUPLE,
        MirKind.BYTES,
        MirKind.BYTEARRAY,
        MirKind.STR,
        MirKind.STR_REF,
        MirKind.INT,
        MirKind.FLOAT,
        MirKind.BOOL
    );
    if left.type.kind not in shaped
        or right.type.kind not in shaped
        or (left.type.is_numeric() and right.type.is_numeric()) {
        return False;
    }
    return name in ("eq", "ne")
        or mir_is_container(left.type)
        or mir_is_container(right.type)
        or left.type.kind != right.type.kind;
}

impl MirLowering.any_arith(
    op: str, left: MirValue, right: MirValue, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    parts = self.any_parts(self.any_box(left, site))
        + self.any_parts(self.any_box(right, site));
    return self.any_from_box(
        self.runtime_value(
            "__jac_rt_any_binary", [b.const_int(ANY_ARITH_CODES[op], mir_int())] + parts
        )
    );
}

impl MirLowering.any_contains(
    item: MirValue, holder: MirValue, site: uni.UniNode
) -> MirValue {
    return self.runtime_value(
        "__jac_rt_any_contains",
        self.any_parts(holder) + self.any_parts(self.any_box(item, site))
    );
}

impl MirLowering.any_iter(value: MirValue) -> MirValue {
    made = self.runtime_value("__jac_rt_any_iter", self.any_parts(value));
    return self.builder().ref_cast(made, mir_iter(mir_any()), True);
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

impl MirLowering.target_archetype(target: uni.Expr) -> (uni.Archetype | None) {
    wanted = self.arch_of_type(target.type);
    if wanted is None
        and isinstance(target, uni.Name)
        and isinstance(target.sym, uni.Symbol) {
        decl = target.sym.decl;
        holder = decl.parent if decl is not None else None;
        wanted = holder if isinstance(holder, uni.Archetype) else None;
    }
    return wanted;
}

impl MirLowering.isinstance_value(
    subject: uni.Expr, target: uni.Expr, site: uni.UniNode
) -> MirValue {
    value = self.lower_expr(subject);
    if value.type.kind == MirKind.ANY {
        return self.any_isinstance(value, target, site);
    }
    items = [
        part
        for part in target.values
        if isinstance(part, uni.Expr)
    ]
        if isinstance(target, uni.TupleVal)
        else [target];
    return self.isinstance_test(value, items, site);
}

impl MirLowering.abstract_names(item: uni.Expr) -> list[str] {
    name = item.value
        if isinstance(item, uni.Name)
        else (
            item.right.value
                if isinstance(item, uni.AtomTrailer)
                    and isinstance(item.right, uni.Name)
                else ""
        );
    if name not in ABSTRACT_TYPE_NAMES {
        return [];
    }
    arch = self.target_archetype(item);
    if arch is not None and not arch.loc.mod_path.endswith(".pyi") {
        return [];
    }
    return ABSTRACT_TYPE_NAMES[name];
}

impl MirLowering.isinstance_test(
    value: MirValue, items: list[uni.Expr], site: uni.UniNode
) -> MirValue {
    b = self.builder();
    if value.type.kind == MirKind.OPT {
        none_hit = any(
            isinstance(item, uni.Name) and item.value == "NoneType" for item in items
        );
        (held, payload, absent, done) = self.opt_begin(value, mir_bool());
        self.opt_switch(held, self.isinstance_test(payload, items, site), absent, done);
        return self.opt_end(held, b.const_bool(none_hit), done);
    }
    static_name = STATIC_TYPE_NAMES.get(value.type.kind.value, "");
    if value.type.kind == MirKind.ENUM {
        static_name = "";
    }
    verdict: (MirValue | None) = None;
    hit = False;
    for item in items {
        if self.abstract_names(item) {
            hit = hit
                or static_name in self.abstract_names(item)
                or (
                    value.type.kind in (MirKind.BYTES, MirKind.BYTEARRAY)
                    and value.type.kind.value in self.abstract_names(item)
                );
            continue;
        }
        if isinstance(item, uni.Name)
            and (
                item.value in ANY_TYPE_TAGS or item.value in STATIC_TYPE_NAMES.values()
            ) {
            hit = hit
                or static_name == item.value
                or (static_name == "bool" and item.value == "int");
            continue;
        }
        arch = self.target_archetype(item);
        if arch is not None {
            found = self.isinstance_check(value, arch);
            verdict = found if verdict is None else b.binary("or", verdict, found);
            continue;
        }
        item_type = self.expr_type(item);
        if item_type.kind == MirKind.CLASS {
            found = self.class_isinstance(value, self.lower_expr(item));
            verdict = found if verdict is None else b.binary("or", verdict, found);
            continue;
        }
        if item_type.kind == MirKind.LIST
            and item_type.payload().kind == MirKind.CLASS {
            found = self.class_list_isinstance(value, self.lower_expr(item));
            verdict = found if verdict is None else b.binary("or", verdict, found);
            continue;
        }
        if item_type.kind == MirKind.TUPLE
            and item_type.args
            and all(member.kind == MirKind.CLASS for member in item_type.args) {
            classes = self.spill(self.lower_expr(item));
            for index in range(len(item_type.args)) {
                found = self.class_isinstance(value, self.tuple_get(classes, index));
                verdict = found if verdict is None else b.binary("or", verdict, found);
            }
            continue;
        }
        raise MirRefused(mir_refusal("call", "isinstance of a non-archetype", site));
    }
    if verdict is None or hit {
        return b.const_bool(hit);
    }
    return verdict;
}

impl MirLowering.any_isinstance(
    value: MirValue, target: uni.Expr, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    tag = self.emit_value(MirOp.ANY_TAG, mir_int(), [value]);
    payload = self.emit_value(MirOp.ANY_PAYLOAD, mir_int(), [value]);
    items = [
        part
        for part in target.values
        if isinstance(part, uni.Expr)
    ]
        if isinstance(target, uni.TupleVal)
        else [target];
    verdict = b.const_bool(False);
    for item in items {
        concrete = self.abstract_names(item);
        if concrete {
            for wanted_name in concrete {
                if wanted_name in ANY_TYPE_TAGS {
                    for wanted in ANY_TYPE_TAGS[wanted_name] {
                        verdict = b.binary(
                            "or",
                            verdict,
                            b.compare("eq", tag, b.const_int(wanted, mir_int()))
                        );
                    }
                } elif wanted_name in ("tuple", "bytes", "bytearray") {
                    label = self.emit_value(
                        MirOp.CSTR,
                        mir_c_ptr(mir_int(8, False)),
                        [],
                        str_value=wanted_name
                    );
                    verdict = b.binary(
                        "or",
                        verdict,
                        self.runtime_value("__jac_rt_any_isa", [tag, payload, label])
                    );
                }
            }
            continue;
        }
        if isinstance(item, uni.Name) and item.value in ANY_TYPE_TAGS {
            for wanted in ANY_TYPE_TAGS[item.value] {
                verdict = b.binary(
                    "or", verdict, b.compare("eq", tag, b.const_int(wanted, mir_int()))
                );
            }
            continue;
        }
        if isinstance(item, uni.Name)
            and item.value in ("bytes", "bytearray", "tuple") {
            label = self.emit_value(
                MirOp.CSTR, mir_c_ptr(mir_int(8, False)), [], str_value=item.value
            );
            verdict = b.binary(
                "or",
                verdict,
                self.runtime_value("__jac_rt_any_isa", [tag, payload, label])
            );
            continue;
        }
        if self.is_enum_class(item) and isinstance(item.type, ClassType) {
            enum_type = mir_type_of(
                item.type.clone_as_instance(),
                MirPosition.VALUE,
                site,
                self.type_env or None
            );
            label = self.emit_value(
                MirOp.CSTR, mir_c_ptr(mir_int(8, False)), [], str_value=enum_type.name
            );
            verdict = b.binary(
                "or",
                verdict,
                self.runtime_value("__jac_rt_any_enum_is", [tag, payload, label])
            );
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
                "or",
                verdict,
                self.runtime_value("__jac_rt_any_isa", [tag, payload, label])
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
        "__jac_rt_class_name",
        [self.emit_value(MirOp.PTR_CAST, mir_c_ptr(mir_int(8, False)), [value])]
    );
    return b.str_make(text, text, self.runtime_value("__jac_rt_str_size", [text]));
}

impl MirLowering.hook_call(
    value: MirValue, arch: uni.Archetype, decl: MirDecl
) -> MirValue {
    b = self.builder();
    receiver = value;
    if decl.self_type is not None and value.type is not decl.self_type {
        receiver = b.ref_cast(value, decl.self_type, False);
    }
    obj_def = self.object_def(arch);
    if obj_def.vtable_symbol and decl.symbol in obj_def.vtable_methods {
        i8p = mir_c_ptr(mir_int(8, False));
        slot_place = self.emit_value(
            MirOp.FIELD_ADDR,
            mir_c_ptr(mir_c_ptr(i8p)),
            [value],
            int_value=obj_def.vtable_slot
        );
        table = b.load(slot_place, mir_c_ptr(i8p));
        index = obj_def.vtable_methods.index(decl.symbol) + VTABLE_HEADER_SLOTS;
        entry_place = self.emit_value(
            MirOp.PTR_OFFSET, mir_c_ptr(i8p), [table, b.const_int(index, mir_int())]
        );
        callee = self.emit_value(
            MirOp.PTR_CAST,
            mir_c_fn([receiver.type], decl.ret),
            [b.load(entry_place, i8p)]
        );
        result = self.emit_value(
            MirOp.CALL_FNPTR, decl.ret, [callee, receiver], str_value=decl.symbol
        );
        result.owned = mir_holds_ref(decl.ret);
        return result;
    }
    direct = b.call(decl.symbol, [receiver], decl.ret);
    if direct is None {
        raise MirRefused(mir_refusal("method", decl.symbol));
    }
    return direct;
}

impl MirLowering.enum_box(value: MirValue, site: uni.UniNode) -> MirValue {
    return self.runtime_value(
        "__jac_rt_enum_box",
        [self.enum_desc(value.type, site), self.builder().convert(value, mir_int())]
    );
}

impl MirLowering.enum_desc(t: MirType, site: uni.UniNode) -> MirValue {
    b = self.builder();
    thunk = self.enum_text_thunk(t, site);
    text = b.const_int(0, mir_int());
    if thunk {
        i8p = mir_c_ptr(mir_int(8, False));
        text = self.emit_value(
            MirOp.PTR_INT,
            mir_int(),
            [
                self.emit_value(
                    MirOp.FN_ADDR, mir_c_fn([i8p], mir_none()), [], callee=thunk
                )
            ]
        );
    }
    return self.runtime_value(
        "__jac_rt_enum_desc",
        [
            self.emit_value(
                MirOp.CSTR, mir_c_ptr(mir_int(8, False)), [], str_value=t.name
            ),
            text
        ]
    );
}

impl MirLowering.creation_kind(elem: MirType, site: uni.UniNode) -> MirValue {
    if elem.kind == MirKind.ENUM {
        return self.enum_desc(elem, site);
    }
    return self.builder().const_int(self.elem_kind(elem, site), mir_int());
}

impl MirLowering.enum_text_thunk(t: MirType, site: uni.UniNode) -> str {
    found = self.enum_thunks.get(t.key);
    if found is not None {
        return found;
    }
    i8p = mir_c_ptr(mir_int(8, False));
    symbol = f"{self.mir.prefix}.__enum_text.{len(self.enum_thunks)}";
    fn = MirFunction(
        name=f"__enum_text.{t.render()}",
        symbol=symbol,
        ret=mir_none(),
        linkage="internal"
    );
    first = fn.new_block("entry");
    frame = fn.new_value(i8p, "frame");
    fn.params.append(MirParam(name="frame", value=frame));
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        b = self.builder();
        base = self.address_of(frame);
        member = b.convert(self.emit_value(MirOp.MEM_LOAD, mir_int(), [base]), t);
        mode = self.emit_value(
            MirOp.MEM_LOAD,
            mir_int(),
            [b.binary("add", base, b.const_int(TEXT_THUNK_MODE, mir_int()))]
        );
        repr_bb = fn.new_block("text.repr");
        str_bb = fn.new_block("text.str");
        done = fn.new_block("text.done");
        b.cond_branch(
            b.compare("ne", mode, b.const_int(0, mir_int())), repr_bb, str_bb
        );
        for (block, as_repr) in ((repr_bb, True), (str_bb, False)) {
            b.position(block);
            text = self.repr_of(member, site)
                if as_repr
                else self.str_value(member, site);
            self.store_text_result(base, text);
            b.branch(done);
        }
        b.position(done);
        b.ret(None);
    } except MirRefused as err {
        self.state = saved;
        self.enum_thunks[t.key] = "";
        return "";
    }
    self.state = saved;
    self.enum_thunks[t.key] = symbol;
    self.nested.append(fn);
    return symbol;
}

impl MirLowering.store_text_result(base: MirValue, text: MirValue) {
    b = self.builder();
    held = self.runtime_value(
        "__jac_rt_str_ref",
        [b.str_part(text, "root"), b.str_part(text, "data"), b.str_part(text, "len")]
    );
    self.runtime("__jac_rt_retain", [held]);
    self.emit_value(
        MirOp.MEM_STORE,
        mir_none(),
        [
            b.binary("add", base, b.const_int(TEXT_THUNK_RESULT, mir_int())),
            self.address_of(held)
        ]
    );
}
