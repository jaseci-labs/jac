impl MirLowering.call_rt(name: str, args: list[MirValue]) -> MirValue {
    made = self.runtime(name, args);
    if made is None {
        raise RuntimeError(f"runtime function {name} returns no value");
    }
    return made;
}

impl MirLowering.text_const(text: str) -> tuple[MirValue, MirValue] {
    b = self.builder();
    made = b.const_str(text, mir_str());
    return (b.str_part(made, "data"), b.str_part(made, "len"));
}

impl MirLowering.as_text(value: MirValue) -> MirValue {
    if value.type.kind != MirKind.STR_REF {
        return value;
    }
    return self.builder().str_make(
        value, value, self.call_rt("__jac_rt_str_size", [value])
    );
}

impl MirLowering.owned_text(handle: MirValue) -> MirValue {
    return self.builder().str_make(
        handle, handle, self.call_rt("__jac_rt_str_size", [handle])
    );
}

impl MirLowering.text_position(value: MirValue, to: MirType) -> (MirValue | None) {
    if value.type.kind == MirKind.STR_REF and to.kind == MirKind.STR {
        return self.as_text(value);
    }
    if value.type.kind == MirKind.STR and to.kind == MirKind.STR_REF {
        b = self.builder();
        return self.call_rt(
            "__jac_rt_str_ref",
            [
                b.str_part(value, "root"),
                b.str_part(value, "data"),
                b.str_part(value, "len")
            ]
        );
    }
    return None;
}

impl MirLowering.text_operands(
    left: MirValue, right: MirValue
) -> tuple[MirValue, MirValue] {
    return (self.as_text(left), self.as_text(right));
}

impl MirLowering.is_text(value: MirValue) -> bool {
    return value.type.kind in (MirKind.STR, MirKind.STR_REF);
}

impl MirLowering.is_byte_seq(value: MirValue) -> bool {
    return value.type.kind in (MirKind.BYTES, MirKind.BYTEARRAY);
}

impl MirLowering.present(arg: (uni.Expr | None)) -> bool {
    return arg is not None and not isinstance(arg, uni.Null);
}

impl MirLowering.bind_args(
    nd: uni.FuncCall, names: list[str]
) -> list[(uni.Expr | None)] {
    bound: list[(uni.Expr | None)] = [None for _ in names];
    at = 0;
    for arg in list(nd.params or []) {
        if isinstance(arg, uni.KWPair) {
            key = arg.key.sym_name if arg.key is not None else "";
            if key not in names {
                raise MirRefused(
                    mir_refusal("call argument", key or "keyword unpacking", arg)
                );
            }
            bound[names.index(key)] = arg.value;
            continue;
        }
        if at >= len(names) {
            raise MirRefused(
                mir_refusal("call", f"{self.call_name(nd)} with {at + 1} arguments", nd)
            );
        }
        bound[at] = arg;
        at += 1;
    }
    return bound;
}

impl MirLowering.text_arg(arg: (uni.Expr | None), site: uni.UniNode) -> MirValue {
    if arg is None {
        raise MirRefused(mir_refusal("call", "missing str argument", site));
    }
    value = self.as_text(self.lower_expr(arg));
    if value.type.kind != MirKind.STR {
        raise MirRefused(mir_refusal("call argument", value.type.render(), arg));
    }
    return self.spill(value);
}

impl MirLowering.int_arg(arg: (uni.Expr | None), fallback: int) -> MirValue {
    if arg is None or not self.present(arg) {
        return self.builder().const_int(fallback, mir_int());
    }
    return self.coerce(self.lower_expr(arg), mir_int(), arg);
}

impl MirLowering.bool_arg(arg: (uni.Expr | None), fallback: bool) -> MirValue {
    if arg is None or not self.present(arg) {
        return self.builder().const_bool(fallback);
    }
    return self.condition(arg);
}

impl MirLowering.codec_arg(
    arg: (uni.Expr | None), table: dict[str, int], site: uni.UniNode
) -> MirValue {
    if not self.present(arg) {
        return self.builder().const_int(0, mir_int());
    }
    name = self.literal_text(arg);
    if name is None and isinstance(arg, uni.Expr) {
        b = self.builder();
        text = self.spill(self.as_text(self.lower_expr(arg)));
        chosen = b.const_int(-1, mir_int());
        for (key, ident) in table.items() {
            for spelled in {
                key,
                key.upper(),
                key.replace("-", "_"),
                key.replace("-", "_").upper()
            } {
                hit = self.str_compare("eq", text, b.const_str(spelled, mir_str()));
                chosen = b.select(hit, b.const_int(ident, mir_int()), chosen);
            }
        }
        self.raise_if(
            b.compare("lt", chosen, b.const_int(0, mir_int())),
            "LookupError",
            "unknown encoding or error handler"
        );
        return chosen;
    }
    if name is None {
        raise MirRefused(
            mir_refusal(
                "codec",
                "not a literal",
                arg,
                "Native code takes the codec name as a string literal."
            )
        );
    }
    found = table.get(name.lower().replace("_", "-"));
    if found is None {
        raise MirRefused(mir_refusal("codec", name, arg));
    }
    return self.builder().const_int(found, mir_int());
}

impl MirLowering.codec_failure(exception: str) -> MirValue {
    return self.builder().const_int(
        JAC_TYPE_REGISTRY.exception_type_id(exception), mir_int(32, True, True)
    );
}

impl MirLowering.literal_text(nd: (uni.UniNode | None)) -> (str | None) {
    if isinstance(nd, uni.String) and isinstance(nd.lit_value, str) {
        return nd.lit_value;
    }
    if isinstance(nd, uni.MultiString) {
        pieces: list[str] = [];
        for part in nd.strings {
            if not isinstance(part, uni.String)
                or not isinstance(part.lit_value, str) {
                return None;
            }
            pieces.append(part.lit_value);
        }
        return "".join(pieces);
    }
    return None;
}

impl MirLowering.typed_handle(handle: MirValue, nd: uni.Expr) -> MirValue {
    return self.builder().ref_cast(handle, self.expr_type(nd), True);
}

impl MirLowering.text_method(
    receiver: MirValue, name: str, nd: uni.FuncCall
) -> (MirValue | None) {
    if self.is_byte_seq(receiver) {
        return self.bytes_method(self.spill(receiver), name, nd);
    }
    b = self.builder();
    text = self.spill(self.as_text(receiver));
    if name in TEXT_CASES or name in TEXT_TESTS {
        self.bind_args(nd, []);
        data = b.str_part(text, "data");
        size = b.str_part(text, "len");
        if name in TEXT_CASES {
            return self.owned_text(
                self.call_rt(
                    "__jac_rt_str_case",
                    [data, size, b.const_int(TEXT_CASES[name], mir_int())]
                )
            );
        }
        return self.call_rt(
            "__jac_rt_str_test", [data, size, b.const_int(TEXT_TESTS[name], mir_int())]
        );
    }
    if name in TEXT_STRIPS {
        chars_nd = self.bind_args(nd, ["chars"])[0];
        (chars_data, chars_len) = self.text_const("");
        supplied = self.present(chars_nd);
        if supplied {
            chars = self.text_arg(chars_nd, nd);
            chars_data = b.str_part(chars, "data");
            chars_len = b.str_part(chars, "len");
        }
        return self.owned_text(
            self.call_rt(
                "__jac_rt_str_strip",
                [
                    b.str_part(text, "data"),
                    b.str_part(text, "len"),
                    chars_data,
                    chars_len,
                    b.const_bool(supplied),
                    b.const_int(TEXT_STRIPS[name], mir_int())
                ]
            )
        );
    }
    if name in ("find", "rfind", "index", "rindex", "count") {
        (sub_nd, start_nd, end_nd) = self.bind_args(nd, ["sub", "start", "end"]);
        sub = self.text_arg(sub_nd, nd);
        start = self.int_arg(start_nd, 0);
        stop = self.int_arg(end_nd, TEXT_STOP);
        parts = [
            b.str_part(text, "root"),
            b.str_part(text, "data"),
            b.str_part(text, "len"),
            b.str_part(sub, "data"),
            b.str_part(sub, "len"),
            start,
            stop
        ];
        if name == "count" {
            return self.call_rt("__jac_rt_str_count", parts);
        }
        at = self.call_rt(
            "__jac_rt_str_find", parts + [b.const_bool(name.startswith("r"))]
        );
        if name.endswith("index") {
            self.raise_if(
                b.compare("lt", at, b.const_int(0, mir_int())),
                "ValueError",
                "substring not found"
            );
        }
        return at;
    }
    if name in ("startswith", "endswith") {
        (affix_nd, start_nd, end_nd) = self.bind_args(
            nd, ["prefix" if name == "startswith" else "suffix", "start", "end"]
        );
        if affix_nd is None {
            raise MirRefused(mir_refusal("call", f"{name} without an argument", nd));
        }
        candidates: list[MirValue] = [];
        if isinstance(affix_nd, uni.TupleVal) {
            for item in affix_nd.values {
                if isinstance(item, uni.Expr) {
                    candidates.append(self.text_arg(item, nd));
                }
            }
        } else {
            given = self.lower_expr(affix_nd);
            if given.type.kind == MirKind.LIST
                and given.type.payload().kind in (MirKind.STR, MirKind.STR_REF) {
                start = self.int_arg(start_nd, 0);
                stop = self.int_arg(end_nd, TEXT_STOP);
                found = self.temp_slot(mir_bool());
                b.store(found, b.const_bool(False));
                (affix_item, _, head, after) = self.each_begin(self.spill(given), nd);
                affix = self.spill(self.as_text(affix_item));
                hit = self.call_rt(
                    "__jac_rt_str_affix",
                    [
                        b.str_part(text, "root"),
                        b.str_part(text, "data"),
                        b.str_part(text, "len"),
                        b.str_part(affix, "data"),
                        b.str_part(affix, "len"),
                        start,
                        stop,
                        b.const_bool(name == "endswith")
                    ]
                );
                b.store(found, b.binary("or", b.load(found, mir_bool()), hit));
                self.each_end(head, after);
                return b.load(found, mir_bool());
            }
            if given.type.kind == MirKind.TUPLE {
                held = self.spill(given);
                for index in range(len(given.type.args)) {
                    candidates.append(
                        self.spill(self.as_text(self.tuple_get(held, index)))
                    );
                }
            } else {
                candidates.append(self.spill(self.as_text(given)));
            }
        }
        start = self.int_arg(start_nd, 0);
        stop = self.int_arg(end_nd, TEXT_STOP);
        verdict = b.const_bool(False);
        for candidate in candidates {
            if candidate.type.kind != MirKind.STR {
                raise MirRefused(
                    mir_refusal("call argument", candidate.type.render(), nd)
                );
            }
            hit = self.call_rt(
                "__jac_rt_str_affix",
                [
                    b.str_part(text, "root"),
                    b.str_part(text, "data"),
                    b.str_part(text, "len"),
                    b.str_part(candidate, "data"),
                    b.str_part(candidate, "len"),
                    start,
                    stop,
                    b.const_bool(name == "endswith")
                ]
            );
            verdict = b.binary("or", verdict, hit);
        }
        return verdict;
    }
    if name == "replace" {
        (old_nd, new_nd, count_nd) = self.bind_args(nd, ["old", "new", "count"]);
        old = self.text_arg(old_nd, nd);
        repl = self.text_arg(new_nd, nd);
        count = self.int_arg(count_nd, -1);
        return self.owned_text(
            self.call_rt(
                "__jac_rt_str_replace",
                [
                    b.str_part(text, "data"),
                    b.str_part(text, "len"),
                    b.str_part(old, "data"),
                    b.str_part(old, "len"),
                    b.str_part(repl, "data"),
                    b.str_part(repl, "len"),
                    count
                ]
            )
        );
    }
    if name in ("split", "rsplit") {
        (sep_nd, max_nd) = self.bind_args(nd, ["sep", "maxsplit"]);
        (sep_data, sep_len) = self.text_const("");
        supplied = self.present(sep_nd);
        if supplied {
            sep = self.text_arg(sep_nd, nd);
            sep_data = b.str_part(sep, "data");
            sep_len = b.str_part(sep, "len");
        }
        handle = self.call_rt(
            "__jac_rt_str_split",
            [
                b.str_part(text, "data"),
                b.str_part(text, "len"),
                sep_data,
                sep_len,
                b.const_bool(supplied),
                self.int_arg(max_nd, -1),
                b.const_bool(name == "rsplit")
            ]
        );
        return self.typed_handle(handle, nd);
    }
    if name == "splitlines" {
        keep_nd = self.bind_args(nd, ["keepends"])[0];
        keep = self.bool_arg(keep_nd, False);
        handle = self.call_rt(
            "__jac_rt_str_splitlines",
            [b.str_part(text, "data"), b.str_part(text, "len"), keep]
        );
        return self.typed_handle(handle, nd);
    }
    if name == "join" {
        items_nd = self.bind_args(nd, ["iterable"])[0];
        if items_nd is None {
            raise MirRefused(mir_refusal("call", "join without an argument", nd));
        }
        items = self.spill(self.lower_expr(items_nd));
        if items.type.kind in (MirKind.ITER, MirKind.SET, MirKind.DICT)
            and items.type.args
            and items.type.args[0].kind in (MirKind.STR, MirKind.STR_REF) {
            items = self.spill(self.drain(items, items.type.args[0], items_nd));
        }
        if items.type.kind != MirKind.LIST
            or items.type.payload().kind not in (MirKind.STR, MirKind.STR_REF) {
            raise MirRefused(
                mir_refusal(
                    "call",
                    f"join of {items.type.render()}",
                    nd,
                    "Native join takes a list[str]."
                )
            );
        }
        return self.owned_text(
            self.call_rt(
                "__jac_rt_str_join",
                [b.str_part(text, "data"), b.str_part(text, "len"), items]
            )
        );
    }
    if name in ("partition", "rpartition") {
        sep_nd = self.bind_args(nd, ["sep"])[0];
        return self.text_partition(
            text, self.text_arg(sep_nd, nd), name == "rpartition"
        );
    }
    if name in ("removeprefix", "removesuffix") {
        affix_nd = self.bind_args(
            nd, ["prefix" if name == "removeprefix" else "suffix"]
        )[0];
        affix = self.text_arg(affix_nd, nd);
        return self.owned_text(
            self.call_rt(
                "__jac_rt_str_remove_affix",
                [
                    b.str_part(text, "data"),
                    b.str_part(text, "len"),
                    b.str_part(affix, "data"),
                    b.str_part(affix, "len"),
                    b.const_bool(name == "removesuffix")
                ]
            )
        );
    }
    if name == "expandtabs" {
        tab_nd = self.bind_args(nd, ["tabsize"])[0];
        tabsize = self.int_arg(tab_nd, 8);
        return self.owned_text(
            self.call_rt(
                "__jac_rt_str_expandtabs",
                [b.str_part(text, "data"), b.str_part(text, "len"), tabsize]
            )
        );
    }
    if name == "zfill" {
        width_nd = self.bind_args(nd, ["width"])[0];
        width = self.int_arg(width_nd, 0);
        return self.owned_text(
            self.call_rt(
                "__jac_rt_str_zfill",
                [b.str_part(text, "data"), b.str_part(text, "len"), width]
            )
        );
    }
    if name in TEXT_JUSTIFY {
        (width_nd, fill_nd) = self.bind_args(nd, ["width", "fillchar"]);
        width = self.int_arg(width_nd, 0);
        (fill_data, fill_len) = self.text_const(" ");
        if self.present(fill_nd) {
            fill = self.text_arg(fill_nd, nd);
            fill_data = b.str_part(fill, "data");
            fill_len = b.str_part(fill, "len");
        }
        return self.owned_text(
            self.call_rt(
                "__jac_rt_str_pad",
                [
                    b.str_part(text, "root"),
                    b.str_part(text, "data"),
                    b.str_part(text, "len"),
                    width,
                    fill_data,
                    fill_len,
                    b.const_int(TEXT_JUSTIFY[name], mir_int())
                ]
            )
        );
    }
    if name == "encode" {
        (codec_nd, errors_nd) = self.bind_args(nd, ["encoding", "errors"]);
        codec = self.codec_arg(codec_nd, TEXT_CODECS, nd);
        errors = self.codec_arg(errors_nd, TEXT_ERRORS, nd);
        handle = self.call_rt(
            "__jac_rt_str_encode",
            [
                b.str_part(text, "data"),
                b.str_part(text, "len"),
                codec,
                errors,
                self.codec_failure("UnicodeEncodeError")
            ]
        );
        return b.ref_cast(handle, mir_bytes(), True);
    }
    return None;
}

impl MirLowering.text_partition(
    text: MirValue, sep: MirValue, reverse: bool
) -> MirValue {
    b = self.builder();
    data = b.str_part(text, "data");
    size = b.str_part(text, "len");
    sep_data = b.str_part(sep, "data");
    sep_len = b.str_part(sep, "len");
    zero = b.const_int(0, mir_int());
    at = self.call_rt(
        "__jac_rt_str_partition", [data, size, sep_data, sep_len, b.const_bool(reverse)]
    );
    missing = b.compare("lt", at, zero);
    after = b.binary("add", at, sep_len);
    head_len = b.select(missing, zero if reverse else size, at);
    mid_len = b.select(missing, zero, sep_len);
    tail_start = b.select(missing, zero if reverse else size, after);
    tail_len = b.binary("sub", size, tail_start);
    head = self.owned_text(self.call_rt("__jac_rt_str_new", [data, head_len]));
    mid = self.owned_text(self.call_rt("__jac_rt_str_new", [sep_data, mid_len]));
    tail = self.owned_text(
        self.call_rt(
            "__jac_rt_str_new",
            [self.emit_value(MirOp.PTR_OFFSET, data.type, [data, tail_start]), tail_len]
        )
    );
    return self.emit_value(
        MirOp.TUPLE_MAKE,
        mir_tuple([mir_str(), mir_str(), mir_str()]),
        [head, mid, tail]
    );
}

impl MirLowering.slice_operands(
    part: uni.Slice
) -> tuple[MirValue, MirValue, MirValue, MirValue] {
    b = self.builder();
    given = 0;
    start = b.const_int(0, mir_int());
    stop = b.const_int(0, mir_int());
    if part.start is not None and self.present(part.start) {
        start = self.coerce(self.lower_expr(part.start), mir_int(), part.start);
        given = given | 1;
    }
    if part.stop is not None and self.present(part.stop) {
        stop = self.coerce(self.lower_expr(part.stop), mir_int(), part.stop);
        given = given | 2;
    }
    step = self.int_arg(part.step, 1);
    return (start, stop, step, b.const_int(given, mir_int()));
}

impl MirLowering.text_subscript(
    holder: MirValue, slice: uni.IndexSlice, site: uni.UniNode
) -> MirValue {
    if len(slice.slices) != 1 {
        raise MirRefused(mir_refusal("subscript", "several indices", site));
    }
    part = slice.slices[0];
    if self.is_byte_seq(holder) {
        return self.bytes_subscript(self.spill(holder), slice, site);
    }
    b = self.builder();
    text = self.spill(self.as_text(holder));
    if not slice.is_range {
        if part.start is None {
            raise MirRefused(mir_refusal("subscript", "missing index", site));
        }
        index = self.coerce(self.lower_expr(part.start), mir_int(), part.start);
        return self.owned_text(
            self.call_rt(
                "__jac_rt_str_index",
                [
                    b.str_part(text, "root"),
                    b.str_part(text, "data"),
                    b.str_part(text, "len"),
                    index
                ]
            )
        );
    }
    (start, stop, step, given) = self.slice_operands(part);
    return self.owned_text(
        self.call_rt(
            "__jac_rt_str_slice",
            [
                b.str_part(text, "root"),
                b.str_part(text, "data"),
                b.str_part(text, "len"),
                start,
                stop,
                step,
                given
            ]
        )
    );
}

impl MirLowering.text_contains(
    item: MirValue, holder: MirValue, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    if self.is_byte_seq(holder) {
        held = self.spill(holder);
        if item.type.kind in (MirKind.INT, MirKind.BOOL) {
            (data, size) = self.byte_parts(held);
            return self.call_rt(
                "__jac_rt_bytes_has", [data, size, b.convert(item, mir_int())]
            );
        }
        if not self.is_byte_seq(item) {
            raise MirRefused(
                mir_refusal("comparison", f"{item.type.render()} in bytes", site)
            );
        }
        needle = self.spill(item);
        (needle_data, needle_len) = self.byte_parts(needle);
        (data, size) = self.byte_parts(held);
        at = self.call_rt(
            "__jac_rt_bytes_find",
            [
                data,
                size,
                needle_data,
                needle_len,
                b.const_int(0, mir_int()),
                b.const_int(TEXT_STOP, mir_int()),
                b.const_bool(False)
            ]
        );
        return b.compare("ge", at, b.const_int(0, mir_int()));
    }
    text = self.spill(self.as_text(holder));
    needle = self.as_text(item);
    if needle.type.kind != MirKind.STR {
        raise MirRefused(
            mir_refusal("comparison", f"{item.type.render()} in str", site)
        );
    }
    return self.call_rt(
        "__jac_rt_str_contains",
        [
            b.str_part(text, "data"),
            b.str_part(text, "len"),
            b.str_part(needle, "data"),
            b.str_part(needle, "len")
        ]
    );
}

impl MirLowering.text_binary(
    op: str, left: MirValue, right: MirValue, site: uni.UniNode
) -> (MirValue | None) {
    b = self.builder();
    if self.is_text(left) or self.is_text(right) {
        if op == Tok.PLUS and self.is_text(left) and self.is_text(right) {
            (l, r) = self.text_operands(left, right);
            return self.str_concat(l, r);
        }
        if op == Tok.STAR_MUL {
            text = self.as_text(left if self.is_text(left) else right);
            times = right if self.is_text(left) else left;
            if times.type.kind not in (MirKind.INT, MirKind.BOOL) {
                return None;
            }
            return self.owned_text(
                self.call_rt(
                    "__jac_rt_str_repeat",
                    [
                        b.str_part(text, "data"),
                        b.str_part(text, "len"),
                        b.convert(times, mir_int())
                    ]
                )
            );
        }
        if op == Tok.MOD and self.is_text(left) {
            template = self.literal_text(site.left)
                if isinstance(site, uni.BinaryExpr)
                else None;
            if template is None {
                raise MirRefused(
                    mir_refusal(
                        "binary operator",
                        "% with a format that is not a literal",
                        site,
                        "Native %-formatting needs the format string as a literal."
                    )
                );
            }
            return self.percent_format(template, right, site);
        }
        return None;
    }
    if self.is_byte_seq(left) and op == Tok.PLUS and self.is_byte_seq(right) {
        first = self.spill(left);
        second = self.spill(right);
        (a_data, a_len) = self.byte_parts(first);
        (b_data, b_len) = self.byte_parts(second);
        joined = b.ref_cast(
            self.call_rt("__jac_rt_bytes_concat", [a_data, a_len, b_data, b_len]),
            mir_bytes(),
            True
        );
        return joined if left.type.kind == MirKind.BYTES else self.to_bytearray(joined);
    }
    if self.is_byte_seq(left)
        and op == Tok.STAR_MUL
        and right.type.kind in (MirKind.INT, MirKind.BOOL) {
        held = self.spill(left);
        (data, size) = self.byte_parts(held);
        repeated = b.ref_cast(
            self.call_rt(
                "__jac_rt_bytes_repeat", [data, size, b.convert(right, mir_int())]
            ),
            mir_bytes(),
            True
        );
        return repeated
            if left.type.kind == MirKind.BYTES
            else self.to_bytearray(repeated);
    }
    return None;
}

impl MirLowering.percent_format(
    template: str, values: MirValue, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    members: list[MirValue] = [];
    if values.type.kind == MirKind.TUPLE {
        held = self.spill(values);
        for index in range(len(values.type.args)) {
            members.append(self.spill(self.tuple_get(held, index)));
        }
    } else {
        members.append(self.spill(values));
    }
    pieces: list[MirValue] = [];
    used = 0;
    i = 0;
    size = len(template);
    while i < size {
        mark = template.find("%", i);
        if mark < 0 {
            pieces.append(b.const_str(template[i:], mir_str()));
            break;
        }
        if mark > i {
            pieces.append(b.const_str(template[i:mark], mir_str()));
        }
        i = mark + 1;
        if i < size and template[i] == "%" {
            pieces.append(b.const_str("%", mir_str()));
            i += 1;
            continue;
        }
        flags = "";
        while i < size and template[i] in "-+ 0#" {
            flags += template[i];
            i += 1;
        }
        width = "";
        while i < size and template[i].isdigit() {
            width += template[i];
            i += 1;
        }
        precision = "";
        if i < size and template[i] == "." {
            i += 1;
            precision = ".";
            while i < size and template[i].isdigit() {
                precision += template[i];
                i += 1;
            }
            if precision == "." {
                precision = ".0";
            }
        }
        if i >= size or template[i] in "(*" {
            raise MirRefused(mir_refusal("%-format", template, site));
        }
        code = template[i];
        i += 1;
        if used >= len(members) {
            b.raise_builtin("TypeError", "not enough arguments for format string");
            b.position(self.st().fn.new_block("dead"));
            return b.const_str("", mir_str());
        }
        value = members[used];
        used += 1;
        align = "<" if "-" in flags else "";
        sign = "+" if "+" in flags else (" " if " " in flags else "");
        zero = "0" if "0" in flags and "-" not in flags else "";
        alt = "#" if "#" in flags else "";
        if code in "sra" {
            text = self.repr_of(value, site)
                if code == "r"
                else (
                    self.ascii_of(value, site)
                        if code == "a"
                        else self.str_value(value, site)
                );
            spec = (align or ">") + width + precision;
            pieces.append(self.format_value(text, b.const_str(spec, mir_str()), site));
        } elif code in "diu" {
            whole = self.coerce(value, mir_int(), site);
            spec = align + sign + zero + width + "d";
            pieces.append(self.format_value(whole, b.const_str(spec, mir_str()), site));
        } elif code in "xXo" {
            if value.type.kind not in (MirKind.INT, MirKind.BOOL) {
                raise MirRefused(
                    mir_refusal("%-format", f"%{code} of {value.type.render()}", site)
                );
            }
            spec = align + sign + alt + zero + width + code;
            pieces.append(
                self.format_value(
                    b.convert(value, mir_int()), b.const_str(spec, mir_str()), site
                )
            );
        } elif code in "eEfFgG" {
            spec = align + sign + alt + zero + width + precision + code;
            pieces.append(
                self.format_value(
                    self.coerce(value, mir_float(), site),
                    b.const_str(spec, mir_str()),
                    site
                )
            );
        } elif code == "c" {
            text = value
                if self.is_text(value)
                else self.owned_text(
                    self.call_rt(
                        "__jac_rt_str_chr", [self.coerce(value, mir_int(), site)]
                    )
                );
            spec = (align or ">") + width;
            pieces.append(
                self.format_value(
                    self.as_text(text), b.const_str(spec, mir_str()), site
                )
            );
        } else {
            raise MirRefused(mir_refusal("%-format", f"conversion %{code}", site));
        }
        pieces[-1] = self.spill(pieces[-1]);
    }
    if used < len(members) {
        b.raise_builtin(
            "TypeError", "not all arguments converted during string formatting"
        );
        b.position(self.st().fn.new_block("dead"));
        return b.const_str("", mir_str());
    }
    result: (MirValue | None) = None;
    for piece in pieces {
        result = piece if result is None else self.str_concat(result, piece);
    }
    return result if result is not None else b.const_str("", mir_str());
}

impl MirLowering.lower_for_text(nd: uni.InForStmt, holder: MirValue) {
    b = self.builder();
    fn = self.st().fn;
    if not isinstance(nd.target, uni.Name) {
        raise MirRefused(mir_refusal("statement", "for target", nd.target));
    }
    source = self.spill(self.as_text(holder) if self.is_text(holder) else holder);
    cursor = self.temp_slot(mir_int());
    b.store(cursor, b.const_int(0, mir_int()));
    head = fn.new_block("text.head");
    body = fn.new_block("text.body");
    otherwise = fn.new_block("text.else");
    after = fn.new_block("text.exit");
    b.branch(head);
    b.position(head);
    at = b.load(cursor, mir_int());
    if source.type.kind == MirKind.STR {
        data = b.str_part(source, "data");
        size = b.str_part(source, "len");
        b.cond_branch(b.compare("lt", at, size), body, otherwise);
        b.position(body);
        width = self.call_rt("__jac_rt_utf8_width", [data, size, at]);
        b.store(cursor, b.binary("add", at, width));
        item = self.owned_text(self.call_rt("__jac_rt_str_unit", [data, size, at]));
        self.store_name(nd.target, item);
    } else {
        (data, size) = self.byte_parts(source);
        b.cond_branch(b.compare("lt", at, size), body, otherwise);
        b.position(body);
        b.store(cursor, b.binary("add", at, b.const_int(1, mir_int())));
        self.store_name(nd.target, self.byte_at(data, at));
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

impl MirLowering.bytes_literal(
    nd: (uni.String | uni.MultiString)
) -> (MirValue | None) {
    parts = nd.strings if isinstance(nd, uni.MultiString) else [nd];
    data = b"";
    for part in parts {
        if not isinstance(part, uni.String) or not isinstance(part.lit_value, bytes) {
            return None;
        }
        data += part.lit_value;
    }
    return self.emit_value(
        MirOp.CONST_BYTES, mir_bytes(), [], str_value=data.decode("latin-1")
    );
}

impl MirLowering.byte_parts(held: MirValue) -> tuple[MirValue, MirValue] {
    b = self.builder();
    u8p = mir_c_ptr(mir_int(8, False));
    address = self.address_of(held);
    size = self.emit_value(MirOp.MEM_LOAD, mir_int(), [address]);
    if held.type.kind == MirKind.BYTES {
        data = self.emit_value(
            MirOp.PTR_CAST, u8p, [b.binary("add", address, b.const_int(8, mir_int()))]
        );
        return (data, size);
    }
    stored = self.emit_value(
        MirOp.MEM_LOAD,
        mir_int(),
        [b.binary("add", address, b.const_int(16, mir_int()))]
    );
    return (self.emit_value(MirOp.PTR_CAST, u8p, [stored]), size);
}

impl MirLowering.byte_at(data: MirValue, index: MirValue) -> MirValue {
    b = self.builder();
    address = b.binary("add", self.emit_value(MirOp.PTR_INT, mir_int(), [data]), index);
    byte = self.emit_value(MirOp.MEM_LOAD, mir_int(8, False), [address]);
    return b.convert(byte, mir_int());
}

impl MirLowering.byte_len(value: MirValue) -> MirValue {
    return self.emit_value(
        MirOp.MEM_LOAD, mir_int(), [self.address_of(self.spill(value))]
    );
}

impl MirLowering.to_bytearray(value: MirValue) -> MirValue {
    held = self.spill(value);
    (data, size) = self.byte_parts(held);
    return self.builder().ref_cast(
        self.call_rt("__jac_rt_bytearray_new", [data, size]), mir_bytearray(), True
    );
}

impl MirLowering.byte_index(
    size: MirValue, index_nd: uni.Expr, message: str
) -> MirValue {
    b = self.builder();
    at = self.coerce(self.lower_expr(index_nd), mir_int(), index_nd);
    zero = b.const_int(0, mir_int());
    wrapped = b.select(b.compare("lt", at, zero), b.binary("add", at, size), at);
    self.raise_if(
        b.binary("or", b.compare("lt", wrapped, zero), b.compare("ge", wrapped, size)),
        "IndexError",
        message
    );
    return wrapped;
}

impl MirLowering.bytes_subscript(
    held: MirValue, slice: uni.IndexSlice, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    part = slice.slices[0];
    if not slice.is_range {
        if part.start is None {
            raise MirRefused(mir_refusal("subscript", "missing index", site));
        }
        message = "index out of range"
            if held.type.kind == MirKind.BYTES
            else "bytearray index out of range";
        (_, size) = self.byte_parts(held);
        at = self.byte_index(size, part.start, message);
        (data, _) = self.byte_parts(held);
        return self.byte_at(data, at);
    }
    (start, stop, step, given) = self.slice_operands(part);
    (data, size) = self.byte_parts(held);
    made = b.ref_cast(
        self.call_rt("__jac_rt_bytes_slice", [data, size, start, stop, step, given]),
        mir_bytes(),
        True
    );
    return made if held.type.kind == MirKind.BYTES else self.to_bytearray(made);
}

impl MirLowering.bytearray_store(
    target: uni.AtomTrailer, value_nd: uni.Expr, site: uni.UniNode
) {
    b = self.builder();
    holder = self.spill(self.lower_expr(target.target));
    slice = target.right;
    if isinstance(slice, uni.IndexSlice)
        and slice.is_range
        and len(slice.slices) == 1
        and slice.slices[0].step is None {
        self.bytearray_splice(holder, slice.slices[0], value_nd, site);
        return;
    }
    if not isinstance(slice, uni.IndexSlice)
        or slice.is_range
        or len(slice.slices) != 1
        or slice.slices[0].start is None {
        raise MirRefused(mir_refusal("subscript assignment", "bytearray slice", site));
    }
    (_, size) = self.byte_parts(holder);
    at = self.byte_index(size, slice.slices[0].start, "bytearray index out of range");
    value = self.coerce(self.lower_expr(value_nd), mir_int(), value_nd);
    self.runtime("__jac_rt_bytearray_set", [holder, at, value]);
}

impl MirLowering.bytearray_splice(
    holder: MirValue, part: uni.Slice, value_nd: uni.Expr, site: uni.UniNode
) {
    b = self.builder();
    zero = b.const_int(0, mir_int());
    (_, size) = self.byte_parts(holder);
    bounds: list[MirValue] = [];
    for (given, fallback) in ((part.start, zero), (part.stop, size)) {
        if given is None {
            bounds.append(fallback);
            continue;
        }
        at = self.coerce(self.lower_expr(given), mir_int(), given);
        shifted = b.select(b.compare("lt", at, zero), b.binary("add", at, size), at);
        low = b.select(b.compare("lt", shifted, zero), zero, shifted);
        bounds.append(b.select(b.compare("gt", low, size), size, low));
    }
    start = bounds[0];
    stop = b.select(b.compare("lt", bounds[1], start), start, bounds[1]);
    value = self.spill(self.lower_expr(value_nd));
    if not self.is_byte_seq(value) {
        raise MirRefused(
            mir_refusal(
                "subscript assignment",
                f"bytearray slice of {value.type.render()}",
                site
            )
        );
    }
    (data, count) = self.byte_parts(value);
    self.runtime("__jac_rt_bytearray_splice", [holder, start, stop, data, count]);
}

impl MirLowering.bytes_arg(
    arg: (uni.Expr | None), site: uni.UniNode
) -> tuple[MirValue, MirValue] {
    if arg is None {
        raise MirRefused(mir_refusal("call", "missing bytes argument", site));
    }
    value = self.lower_expr(arg);
    if not self.is_byte_seq(value) {
        raise MirRefused(mir_refusal("call argument", value.type.render(), arg));
    }
    return self.byte_parts(self.spill(value));
}

impl MirLowering.bytes_method(
    held: MirValue, name: str, nd: uni.FuncCall
) -> (MirValue | None) {
    b = self.builder();
    keep_kind = held.type.kind == MirKind.BYTEARRAY;
    if name == "decode" {
        (codec_nd, errors_nd) = self.bind_args(nd, ["encoding", "errors"]);
        return self.bytes_decode(held, codec_nd, errors_nd, nd);
    }
    if name == "hex" {
        self.bind_args(nd, []);
        (data, size) = self.byte_parts(held);
        return self.owned_text(self.call_rt("__jac_rt_bytes_hex", [data, size]));
    }
    made: (MirValue | None) = None;
    if name in ("upper", "lower") {
        self.bind_args(nd, []);
        (data, size) = self.byte_parts(held);
        made = self.call_rt(
            "__jac_rt_bytes_case",
            [data, size, b.const_int(TEXT_CASES[name], mir_int())]
        );
    } elif name in TEXT_STRIPS {
        chars_nd = self.bind_args(nd, ["chars"])[0];
        (chars_data, chars_len, supplied_flag) = self.optional_bytes_arg(chars_nd, nd);
        (data, size) = self.byte_parts(held);
        made = self.call_rt(
            "__jac_rt_bytes_strip",
            [
                data,
                size,
                chars_data,
                chars_len,
                supplied_flag,
                b.const_int(TEXT_STRIPS[name], mir_int())
            ]
        );
    } elif name == "replace" {
        (old_nd, new_nd, count_nd) = self.bind_args(nd, ["old", "new", "count"]);
        (old_data, old_len) = self.bytes_arg(old_nd, nd);
        (new_data, new_len) = self.bytes_arg(new_nd, nd);
        count = self.int_arg(count_nd, -1);
        (data, size) = self.byte_parts(held);
        made = self.call_rt(
            "__jac_rt_bytes_replace",
            [data, size, old_data, old_len, new_data, new_len, count]
        );
    } elif name == "join" {
        items_nd = self.bind_args(nd, ["iterable_of_bytes"])[0];
        if items_nd is None {
            raise MirRefused(mir_refusal("call", "join without an argument", nd));
        }
        items = self.spill(self.lower_expr(items_nd));
        if items.type.kind != MirKind.LIST
            or items.type.payload().kind != MirKind.BYTES {
            raise MirRefused(mir_refusal("call", f"join of {items.type.render()}", nd));
        }
        (data, size) = self.byte_parts(held);
        made = self.call_rt("__jac_rt_bytes_join", [data, size, items]);
    } elif name == "split" {
        (sep_nd, max_nd) = self.bind_args(nd, ["sep", "maxsplit"]);
        (sep_data, sep_len, supplied_flag) = self.optional_bytes_arg(sep_nd, nd);
        limit = self.int_arg(max_nd, -1);
        (data, size) = self.byte_parts(held);
        return self.typed_handle(
            self.call_rt(
                "__jac_rt_bytes_split",
                [data, size, sep_data, sep_len, supplied_flag, limit]
            ),
            nd
        );
    }
    if made is not None {
        result = b.ref_cast(made, mir_bytes(), True);
        return self.to_bytearray(result) if keep_kind else result;
    }
    if name
        in ("find", "rfind", "index", "rindex", "count", "startswith", "endswith") {
        first = "prefix"
            if name == "startswith"
            else ("suffix" if name == "endswith" else "sub");
        (sub_nd, start_nd, end_nd) = self.bind_args(nd, [first, "start", "end"]);
        if sub_nd is None {
            raise MirRefused(mir_refusal("call", "missing bytes argument", nd));
        }
        needle = self.spill(self.lower_expr(sub_nd));
        if needle.type.kind == MirKind.TUPLE and name in ("startswith", "endswith") {
            start = self.int_arg(start_nd, 0);
            stop = self.int_arg(end_nd, TEXT_STOP);
            (data, size) = self.byte_parts(held);
            verdict = b.const_bool(False);
            for index in range(len(needle.type.args)) {
                member = self.spill(self.tuple_get(needle, index));
                if not self.is_byte_seq(member) {
                    raise MirRefused(
                        mir_refusal("call argument", member.type.render(), sub_nd)
                    );
                }
                (member_data, member_len) = self.byte_parts(member);
                verdict = b.binary(
                    "or",
                    verdict,
                    self.call_rt(
                        "__jac_rt_bytes_affix",
                        [
                            data,
                            size,
                            member_data,
                            member_len,
                            start,
                            stop,
                            b.const_bool(name == "endswith")
                        ]
                    )
                );
            }
            return verdict;
        }
        if needle.type.kind in (MirKind.INT, MirKind.BOOL)
            and name not in ("startswith", "endswith") {
            needle = self.spill(
                b.ref_cast(
                    self.call_rt(
                        "__jac_rt_byte_single", [b.convert(needle, mir_int())]
                    ),
                    mir_bytes(),
                    True
                )
            );
        }
        if not self.is_byte_seq(needle) {
            raise MirRefused(
                mir_refusal("call argument", needle.type.render(), sub_nd)
            );
        }
        (sub_data, sub_len) = self.byte_parts(needle);
        start = self.int_arg(start_nd, 0);
        stop = self.int_arg(end_nd, TEXT_STOP);
        (data, size) = self.byte_parts(held);
        if name == "count" {
            return self.call_rt(
                "__jac_rt_bytes_count", [data, size, sub_data, sub_len, start, stop]
            );
        }
        if name in ("startswith", "endswith") {
            return self.call_rt(
                "__jac_rt_bytes_affix",
                [
                    data,
                    size,
                    sub_data,
                    sub_len,
                    start,
                    stop,
                    b.const_bool(name == "endswith")
                ]
            );
        }
        at = self.call_rt(
            "__jac_rt_bytes_find",
            [
                data,
                size,
                sub_data,
                sub_len,
                start,
                stop,
                b.const_bool(name.startswith("r"))
            ]
        );
        if name.endswith("index") {
            self.raise_if(
                b.compare("lt", at, b.const_int(0, mir_int())),
                "ValueError",
                "subsection not found"
            );
        }
        return at;
    }
    if not keep_kind {
        return None;
    }
    if name == "append" {
        item_nd = self.bind_args(nd, ["item"])[0];
        self.runtime("__jac_rt_bytearray_push", [held, self.int_arg(item_nd, 0)]);
        return b.const_bool(False);
    }
    if name == "extend" {
        other_nd = self.bind_args(nd, ["iterable_of_ints"])[0];
        if other_nd is None {
            raise MirRefused(mir_refusal("call", "missing bytes argument", nd));
        }
        other = self.spill(self.lower_expr(other_nd));
        if not self.is_byte_seq(other) {
            other = self.spill(self.bytes_of_ints(other, other_nd, True));
        }
        (other_data, other_len) = self.byte_parts(other);
        self.runtime("__jac_rt_bytearray_extend", [held, other_data, other_len]);
        return b.const_bool(False);
    }
    if name == "clear" {
        self.bind_args(nd, []);
        self.runtime("__jac_rt_bytearray_clear", [held]);
        return b.const_bool(False);
    }
    if name == "pop" {
        index_nd = self.bind_args(nd, ["index"])[0];
        (_, size) = self.byte_parts(held);
        self.raise_if(
            b.compare("eq", size, b.const_int(0, mir_int())),
            "IndexError",
            "pop from empty bytearray"
        );
        at = b.binary("sub", size, b.const_int(1, mir_int()));
        if index_nd is not None and self.present(index_nd) {
            at = self.byte_index(size, index_nd, "pop index out of range");
        }
        return self.call_rt("__jac_rt_bytearray_pop", [held, at]);
    }
    return None;
}

impl MirLowering.optional_bytes_arg(
    arg: (uni.Expr | None), site: uni.UniNode
) -> tuple[MirValue, MirValue, MirValue] {
    b = self.builder();
    (data, size) = self.text_const("");
    supplied = self.present(arg);
    if not supplied {
        return (data, size, b.const_bool(False));
    }
    if not isinstance(arg, uni.Expr) or self.expr_type(arg).kind != MirKind.OPT {
        (data, size) = self.bytes_arg(arg, site);
        return (data, size, b.const_bool(True));
    }
    given = self.spill(self.lower_expr(arg));
    fn = self.st().fn;
    data_slot = self.temp_slot(data.type);
    len_slot = self.temp_slot(size.type);
    b.store(data_slot, data);
    b.store(len_slot, size);
    some = fn.new_block("bytes.arg");
    done = fn.new_block("bytes.arg.done");
    flag = self.opt_present(given);
    b.cond_branch(flag, some, done);
    b.position(some);
    (got_data, got_len) = self.byte_parts(self.spill(self.opt_get(given)));
    b.store(data_slot, self.coerce(got_data, data.type, site));
    b.store(len_slot, got_len);
    b.branch(done);
    b.position(done);
    return (b.load(data_slot, data.type), b.load(len_slot, size.type), flag);
}

impl MirLowering.bytes_decode(
    held: MirValue,
    codec_nd: (uni.Expr | None),
    errors_nd: (uni.Expr | None),
    site: uni.UniNode
) -> MirValue {
    i8p = mir_c_ptr(mir_int(8, False));
    encoding = self.emit_value(MirOp.CSTR, i8p, [], str_value="utf-8");
    if codec_nd is not None and self.present(codec_nd) {
        name = self.literal_text(codec_nd);
        encoding = self.cstr_of(self.lower_expr(codec_nd))
            if name is None
            else self.emit_value(MirOp.CSTR, i8p, [], str_value=name);
    }
    errors = self.emit_value(MirOp.CSTR, i8p, [], str_value="strict");
    if errors_nd is not None and self.present(errors_nd) {
        spelled = self.literal_text(errors_nd);
        errors = self.cstr_of(self.lower_expr(errors_nd))
            if spelled is None
            else self.emit_value(MirOp.CSTR, i8p, [], str_value=spelled);
    }
    (data, size) = self.byte_parts(held);
    return self.owned_text(
        self.call_rt(
            "__jac_rt_bytes_decode",
            [
                data,
                size,
                encoding,
                errors,
                self.codec_failure("UnicodeDecodeError"),
                self.codec_failure("LookupError"),
                self.codec_failure("TypeError")
            ]
        )
    );
}
