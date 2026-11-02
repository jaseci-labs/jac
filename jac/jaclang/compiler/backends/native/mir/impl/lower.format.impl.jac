impl MirLowering.str_value(value: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    kind = value.type.kind;
    if kind == MirKind.ANY {
        return self.any_to_str(value, site);
    }
    if kind == MirKind.ENUM {
        return self.enum_str(value, site);
    }
    if kind in (MirKind.STR, MirKind.STR_REF) {
        return self.as_text(value);
    }
    if kind == MirKind.BOOL {
        return b.select(
            value, b.const_str("True", mir_str()), b.const_str("False", mir_str())
        );
    }
    if kind == MirKind.NONE {
        return b.const_str("None", mir_str());
    }
    if kind == MirKind.INT {
        made = self.call_rt(
            "__jac_rt_str_from_uint"
                if not value.type.signed and value.type.width == 64
                else "__jac_rt_str_from_int",
            [b.convert(value, mir_int())]
        );
        return b.str_make(made, made, self.call_rt("__jac_rt_str_size", [made]));
    }
    if kind == MirKind.FLOAT {
        return self.owned_text(
            self.call_rt("__jac_rt_float_repr", [b.convert(value, mir_float())])
        );
    }
    if kind == MirKind.OPT {
        (held, payload, absent, done) = self.opt_begin(value, mir_str());
        self.opt_switch(held, self.str_value(payload, site), absent, done);
        return self.opt_end(held, b.const_str("None", mir_str()), done);
    }
    if kind == MirKind.OBJ {
        return self.object_text(value, "__str__", site);
    }
    return self.repr_of(value, site);
}

impl MirLowering.repr_of(value: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    kind = value.type.kind;
    if kind in (MirKind.STR, MirKind.STR_REF) {
        text = self.as_text(value);
        return self.owned_text(
            self.call_rt(
                "__jac_rt_str_repr", [b.str_part(text, "data"), b.str_part(text, "len")]
            )
        );
    }
    if kind in (MirKind.INT, MirKind.BOOL, MirKind.NONE, MirKind.FLOAT) {
        return self.str_value(value, site);
    }
    if kind == MirKind.OPT {
        (held, payload, absent, done) = self.opt_begin(value, mir_str());
        self.opt_switch(held, self.repr_of(payload, site), absent, done);
        return self.opt_end(held, b.const_str("None", mir_str()), done);
    }
    if kind == MirKind.TUPLE {
        held = self.spill(value);
        count = len(value.type.args);
        texts: list[MirValue] = [];
        for index in range(count) {
            texts.append(self.spill(self.repr_of(self.tuple_get(held, index), site)));
        }
        result = b.const_str("(", mir_str());
        for (index, text) in enumerate(texts) {
            if index > 0 {
                result = self.str_concat(result, b.const_str(", ", mir_str()));
            }
            result = self.str_concat(result, text);
        }
        return self.str_concat(
            result, b.const_str(",)" if count == 1 else ")", mir_str())
        );
    }
    if kind in (MirKind.BYTES, MirKind.BYTEARRAY) {
        held = self.spill(value);
        (data, size) = self.byte_parts(held);
        text = self.owned_text(self.call_rt("__jac_rt_bytes_repr", [data, size]));
        if kind == MirKind.BYTES {
            return text;
        }
        return self.str_concat(
            self.str_concat(b.const_str("bytearray(", mir_str()), text),
            b.const_str(")", mir_str())
        );
    }
    if mir_is_container(value.type) {
        rendered = b.call(self.text_fn(value.type, site), [value], mir_str());
        if rendered is None {
            raise RuntimeError("a generated repr function returns no value");
        }
        return rendered;
    }
    if kind == MirKind.OBJ {
        return self.object_text(value, "__repr__", site);
    }
    raise MirRefused(mir_refusal("conversion", f"repr of {value.type.render()}", site));
}

impl MirLowering.ascii_of(value: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    text = self.repr_of(value, site);
    return self.owned_text(
        self.call_rt(
            "__jac_rt_str_ascii", [b.str_part(text, "data"), b.str_part(text, "len")]
        )
    );
}

impl MirLowering.object_text(
    value: MirValue, method: str, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    arch = self.archetypes.get(value.type.name);
    if arch is None {
        raise MirRefused(
            mir_refusal("conversion", f"{method} of {value.type.render()}", site)
        );
    }
    found = self.find_method(arch, method);
    if found is not None {
        decl = self.decls.get(id(found));
        if decl is None
            or decl.params
            or decl.ret.kind not in (MirKind.STR, MirKind.STR_REF) {
            raise MirRefused(
                mir_refusal("method", f"{arch.name.value}.{method}", site)
            );
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
                mir_c_fn([value.type], decl.ret),
                [b.load(entry_place, i8p)]
            );
            result = self.emit_value(
                MirOp.CALL_FNPTR, decl.ret, [callee, value], str_value=decl.symbol
            );
            result.owned = True;
            return self.as_text(result);
        }
        direct = b.call(decl.symbol, [value], decl.ret);
        if direct is None {
            raise RuntimeError(f"{decl.symbol} returns no value");
        }
        return self.as_text(direct);
    }
    if method == "__str__" and self.is_exception_arch(arch) {
        return self.exception_text(value, arch);
    }
    if method == "__str__" {
        return self.object_text(value, "__repr__", site);
    }
    if arch.arch_type.name == Tok.KW_CLASS {
        return self.owned_text(
            self.call_rt(
                "__jac_rt_obj_text",
                [
                    self.emit_value(
                        MirOp.CSTR,
                        mir_c_ptr(mir_int(8, False)),
                        [],
                        str_value=arch.name.value
                    ),
                    self.address_of(value)
                ]
            )
        );
    }
    rendered = b.call(self.text_fn(value.type, site), [value], mir_str());
    if rendered is None {
        raise RuntimeError("a generated repr function returns no value");
    }
    return rendered;
}

impl MirLowering.text_fn(value_type: MirType, site: uni.UniNode) -> str {
    found = self.text_fns.get(value_type.key);
    if found is not None {
        return found;
    }
    symbol = f"{self.mir.prefix}.__repr.{len(self.text_fns)}";
    self.text_fns[value_type.key] = symbol;
    fn = MirFunction(
        name=f"__repr.{value_type.render()}",
        symbol=symbol,
        ret=mir_str(),
        linkage="internal"
    );
    first = fn.new_block("entry");
    param = fn.new_value(value_type, "value");
    fn.params.append(MirParam(name="value", value=param));
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        if value_type.kind == MirKind.OBJ {
            self.object_repr_body(param, site);
        } else {
            self.container_repr_body(param, site);
        }
    } except MirRefused as err {
        self.text_fns.pop(value_type.key, None);
        self.state = saved;
        raise err;
    }
    self.state = saved;
    self.nested.append(fn);
    return symbol;
}

impl MirLowering.sb_text(sb: MirValue, text: str) {
    (data, size) = self.text_const(text);
    self.runtime("__jac_rt_sb_add", [sb, data, size]);
}

impl MirLowering.sb_value(sb: MirValue, text: MirValue) {
    b = self.builder();
    self.runtime(
        "__jac_rt_sb_add", [sb, b.str_part(text, "data"), b.str_part(text, "len")]
    );
}

impl MirLowering.dict_part(
    d: MirValue, at: MirValue, part: MirType, is_key: bool
) -> MirValue {
    b = self.builder();
    kind = self.elem_kind(part, self.module);
    if kind in (KIND_STR, KIND_REF, KIND_TUPLE, KIND_ANY) {
        handle = self.call_rt(
            "__jac_rt_dict_key_ref" if is_key else "__jac_rt_dict_val_ref",
            [d, at, b.const_int(kind, mir_int())]
        );
        return self.owned_element(handle, part);
    }
    bits = self.call_rt(
        "__jac_rt_dict_key_at" if is_key else "__jac_rt_dict_val_at", [d, at]
    );
    return self.scalar_from_bits(bits, part);
}

impl MirLowering.container_repr_body(param: MirValue, site: uni.UniNode) {
    b = self.builder();
    fn = self.st().fn;
    kind = param.type.kind;
    zero = b.const_int(0, mir_int());
    if kind in (MirKind.SET, MirKind.DICT) {
        empty = fn.new_block("repr.empty");
        filled = fn.new_block("repr.filled");
        b.cond_branch(b.compare("eq", self.container_len(param), zero), empty, filled);
        b.position(empty);
        b.ret(b.const_str("set()" if kind == MirKind.SET else "{}", mir_str()));
        b.position(filled);
    }
    sb = self.call_rt("__jac_rt_sb_new", [b.const_int(32, mir_int())]);
    self.sb_text(sb, "[" if kind == MirKind.LIST else "{");
    cursor = self.temp_slot(mir_int());
    seen = self.temp_slot(mir_int());
    b.store(cursor, b.const_int(0 if kind == MirKind.LIST else -1, mir_int()));
    b.store(seen, zero);
    head = fn.new_block("repr.head");
    body = fn.new_block("repr.body");
    done = fn.new_block("repr.done");
    b.branch(head);
    b.position(head);
    at = b.load(cursor, mir_int());
    if kind == MirKind.LIST {
        b.cond_branch(b.compare("lt", at, self.container_len(param)), body, done);
        b.position(body);
        b.store(cursor, b.binary("add", at, b.const_int(1, mir_int())));
    } else {
        following = self.call_rt("__jac_rt_dict_next", [param, at]);
        b.store(cursor, following);
        b.cond_branch(b.compare("ge", following, zero), body, done);
        b.position(body);
        at = b.load(cursor, mir_int());
    }
    count = b.load(seen, mir_int());
    (comma, comma_len) = self.text_const(", ");
    self.runtime(
        "__jac_rt_sb_add",
        [sb, comma, b.select(b.compare("gt", count, zero), comma_len, zero)]
    );
    b.store(seen, b.binary("add", count, b.const_int(1, mir_int())));
    if kind == MirKind.LIST {
        item = self.spill(self.list_read(param, at));
        self.sb_value(sb, self.repr_of(item, site));
    } else {
        key = self.spill(self.dict_part(param, at, param.type.args[0], True));
        self.sb_value(sb, self.repr_of(key, site));
        if kind == MirKind.DICT {
            self.sb_text(sb, ": ");
            entry_at = self.builder().load(cursor, mir_int());
            item = self.spill(
                self.dict_part(param, entry_at, param.type.args[1], False)
            );
            self.sb_value(sb, self.repr_of(item, site));
        }
    }
    self.builder().branch(head);
    b.position(done);
    self.sb_text(sb, "]" if kind == MirKind.LIST else "}");
    b.ret(self.owned_text(self.call_rt("__jac_rt_sb_finish", [sb])));
}

impl MirLowering.object_repr_body(param: MirValue, site: uni.UniNode) {
    b = self.builder();
    fn = self.st().fn;
    obj_def = self.mir.objects[param.type.name];
    arch = self.archetypes[param.type.name];
    depth = self.call_rt("__jac_rt_repr_enter", [self.address_of(param)]);
    again = fn.new_block("repr.again");
    fresh = fn.new_block("repr.fresh");
    b.cond_branch(b.compare("lt", depth, b.const_int(0, mir_int())), again, fresh);
    b.position(again);
    b.ret(b.const_str("...", mir_str()));
    b.position(fresh);
    sb = self.call_rt("__jac_rt_sb_new", [b.const_int(32, mir_int())]);
    self.sb_text(sb, arch.name.value + "(");
    for (index, member) in enumerate(obj_def.fields) {
        self.sb_text(sb, (", " if index > 0 else "") + member.name + "=");
        place = self.emit_value(
            MirOp.FIELD_ADDR, mir_c_ptr(member.type), [param], int_value=member.index
        );
        field = self.spill(self.builder().load(place, member.type));
        self.sb_value(sb, self.repr_of(field, site));
    }
    self.sb_text(sb, ")");
    self.runtime("__jac_rt_repr_leave", [depth]);
    self.builder().ret(self.owned_text(self.call_rt("__jac_rt_sb_finish", [sb])));
}

impl MirLowering.fstring_value(nd: uni.FString) -> MirValue {
    b = self.builder();
    pieces: list[MirValue] = [];
    for part in nd.parts {
        if isinstance(part, uni.String) {
            if not isinstance(part.lit_value, str) {
                raise MirRefused(mir_refusal("expression", "bytes in f-string", part));
            }
            pieces.append(b.const_str(part.lit_value, mir_str()));
            continue;
        }
        if not isinstance(part, uni.FormattedValue) {
            raise MirRefused(mir_refusal("expression", type(part).__name__, part));
        }
        value = self.lower_expr(part.format_part);
        if part.conversion == FSTRING_REPR {
            value = self.repr_of(value, part);
        } elif part.conversion == FSTRING_ASCII {
            value = self.ascii_of(value, part);
        } elif part.conversion == FSTRING_STR {
            value = self.str_value(value, part);
        } elif part.conversion != -1 {
            raise MirRefused(
                mir_refusal("f-string", f"conversion {part.conversion}", part)
            );
        }
        spec = self.spill(self.as_text(self.lower_expr(part.format_spec)))
            if part.format_spec is not None
            else None;
        pieces.append(self.spill(self.format_value(self.spill(value), spec, part)));
    }
    result: (MirValue | None) = None;
    for piece in pieces {
        result = piece if result is None else self.str_concat(result, piece);
    }
    return result if result is not None else b.const_str("", mir_str());
}

impl MirLowering.format_value(
    value: MirValue, spec: (MirValue | None), site: uni.UniNode
) -> MirValue {
    b = self.builder();
    if spec is None {
        return self.str_value(value, site);
    }
    if spec.type.kind != MirKind.STR {
        raise MirRefused(mir_refusal("format spec", spec.type.render(), site));
    }
    data = b.str_part(spec, "data");
    size = b.str_part(spec, "len");
    kind = value.type.kind;
    if kind == MirKind.INT {
        return self.owned_text(
            self.call_rt(
                "__jac_rt_format_int", [b.convert(value, mir_int()), data, size]
            )
        );
    }
    if kind == MirKind.BOOL {
        return self.owned_text(
            self.call_rt("__jac_rt_format_bool", [value, data, size])
        );
    }
    if kind == MirKind.FLOAT {
        return self.owned_text(
            self.call_rt(
                "__jac_rt_format_float", [b.convert(value, mir_float()), data, size]
            )
        );
    }
    if kind in (MirKind.STR, MirKind.STR_REF) {
        text = self.as_text(value);
        return self.owned_text(
            self.call_rt(
                "__jac_rt_format_str",
                [b.str_part(text, "data"), b.str_part(text, "len"), data, size]
            )
        );
    }
    self.raise_if(
        b.compare("ne", size, b.const_int(0, mir_int())),
        "TypeError",
        f"unsupported format string passed to {self.type_label(value.type)}.__format__"
    );
    return self.str_value(value, site);
}

impl MirLowering.type_label(t: MirType) -> str {
    if t.kind == MirKind.OBJ {
        arch = self.archetypes.get(t.name);
        return arch.name.value if arch is not None else t.name;
    }
    if t.kind == MirKind.OPT {
        return "NoneType";
    }
    return t.kind.value.split(".")[0];
}

impl MirLowering.print_call(nd: uni.FuncCall) -> MirValue {
    b = self.builder();
    values: list[MirValue] = [];
    sep: (MirValue | None) = None;
    end: (MirValue | None) = None;
    fd = 1;
    flush = False;
    for arg in list(nd.params or []) {
        if not isinstance(arg, uni.KWPair) {
            values.append(self.spill(self.lower_expr(arg)));
            continue;
        }
        key = arg.key.sym_name if arg.key is not None else "";
        if key in ("sep", "end") {
            text = None
                if isinstance(arg.value, uni.Null)
                else self.spill(self.as_text(self.lower_expr(arg.value)));
            if text is not None and text.type.kind != MirKind.STR {
                raise MirRefused(
                    mir_refusal("print", f"{key} of {text.type.render()}", arg)
                );
            }
            if key == "sep" {
                sep = text;
            } else {
                end = text;
            }
        } elif key == "file" {
            fd = self.stream_fd(arg.value);
        } elif key == "flush" {
            folded = arg.value.ct_value;
            if not isinstance(folded, CtBool) {
                raise MirRefused(
                    mir_refusal("print", "flush that is not a constant", arg)
                );
            }
            flush = folded.value;
        } else {
            raise MirRefused(mir_refusal("print", f"keyword {key}", arg));
        }
    }
    for (index, value) in enumerate(values) {
        if index > 0 {
            self.write_value(
                sep if sep is not None else b.const_str(" ", mir_str()), fd, nd
            );
        }
        self.write_value(value, fd, nd);
    }
    self.write_value(end if end is not None else b.const_str("\n", mir_str()), fd, nd);
    if flush {
        self.runtime("__jac_rt_flush", [b.const_int(fd, mir_int())]);
    }
    return b.const_bool(False);
}

impl MirLowering.stream_fd(nd: uni.Expr) -> int {
    if isinstance(nd, uni.AtomTrailer)
        and nd.is_attr
        and isinstance(nd.target, uni.Name)
        and nd.target.value == "sys"
        and isinstance(nd.right, uni.Name)
        and nd.right.value in ("stdout", "stderr") {
        return 1 if nd.right.value == "stdout" else 2;
    }
    raise MirRefused(
        mir_refusal(
            "print", "file", nd, "Native print writes to sys.stdout or sys.stderr."
        )
    );
}

impl MirLowering.write_value(value: MirValue, fd: int, site: uni.UniNode) {
    b = self.builder();
    out = b.const_int(fd, mir_int());
    if value.type.kind == MirKind.INT {
        self.runtime("__jac_rt_write_int", [out, b.convert(value, mir_int())]);
        return;
    }
    text = self.str_value(value, site);
    self.runtime(
        "__jac_rt_write", [out, b.str_part(text, "data"), b.str_part(text, "len")]
    );
}

impl MirLowering.text_builtin(nd: uni.FuncCall, name: str) -> (MirValue | None) {
    b = self.builder();
    params = list(nd.params or []);
    if name not in TEXT_BUILTINS
        or any(isinstance(arg, uni.KWPair) for arg in params) {
        return None;
    }
    args: list[uni.Expr] = [
        arg
        for arg in params
        if isinstance(arg, uni.Expr)
    ];
    if name == "str" {
        if not args {
            return b.const_str("", mir_str());
        }
        if len(args) == 1 {
            return self.str_value(self.lower_expr(args[0]), nd);
        }
        held = self.spill(self.lower_expr(args[0]));
        if not self.is_byte_seq(held) {
            raise MirRefused(
                mir_refusal("call", f"str of {held.type.render()} with an encoding", nd)
            );
        }
        codec = self.codec_arg(args[1], TEXT_CODECS, nd);
        errors = self.codec_arg(args[2] if len(args) > 2 else None, TEXT_ERRORS, nd);
        (data, size) = self.byte_parts(held);
        return self.owned_text(
            self.call_rt(
                "__jac_rt_bytes_decode",
                [data, size, codec, errors, self.codec_failure("UnicodeDecodeError")]
            )
        );
    }
    if name == "len" {
        if len(args) == 1
            and self.expr_type(args[0]).kind in (MirKind.BYTES, MirKind.BYTEARRAY) {
            return self.byte_len(self.lower_expr(args[0]));
        }
        return None;
    }
    if name in ("int", "float") {
        if not args {
            return b.const_int(0, mir_int())
                if name == "int"
                else b.const_float(0.0, mir_float());
        }
        source_kind = self.expr_type(args[0]).kind;
        if source_kind
            not in (MirKind.STR, MirKind.STR_REF, MirKind.BYTES, MirKind.BYTEARRAY) {
            return None;
        }
        source = self.spill(self.lower_expr(args[0]));
        (data, size) = self.text_bytes(source);
        if name == "float" {
            return self.call_rt("__jac_rt_float_parse", [data, size]);
        }
        base = self.int_arg(args[1] if len(args) > 1 else None, 10);
        return self.call_rt("__jac_rt_int_parse", [data, size, base]);
    }
    if name == "bool" {
        if not args {
            return b.const_bool(False);
        }
        if self.expr_type(args[0]).is_numeric() {
            return None;
        }
        return self.truthy(self.lower_expr(args[0]), args[0]);
    }
    if len(args) == 0 and name in ("bytes", "bytearray") {
        empty = b.ref_cast(
            self.call_rt("__jac_rt_bytes_zero", [b.const_int(0, mir_int())]),
            mir_bytes(),
            True
        );
        return empty if name == "bytes" else self.to_bytearray(empty);
    }
    if not args {
        return None;
    }
    if name in ("bytes", "bytearray") {
        made = self.bytes_from(args, nd);
        return made if name == "bytes" else self.to_bytearray(made);
    }
    first = self.lower_expr(args[0]);
    if name == "repr" {
        return self.repr_of(first, nd);
    }
    if name == "ascii" {
        return self.ascii_of(first, nd);
    }
    if name == "format" {
        spec = self.spill(self.as_text(self.lower_expr(args[1])))
            if len(args) > 1
            else None;
        if spec is None {
            return self.str_value(first, nd);
        }
        return self.format_value(self.spill(first), spec, nd);
    }
    if name == "hash" {
        return self.hash_value(first, nd);
    }
    if name == "ord" {
        text = self.as_text(first);
        if text.type.kind != MirKind.STR {
            raise MirRefused(mir_refusal("call", f"ord of {first.type.render()}", nd));
        }
        return self.call_rt(
            "__jac_rt_str_ord",
            [
                b.str_part(text, "root"),
                b.str_part(text, "data"),
                b.str_part(text, "len")
            ]
        );
    }
    if name == "chr" {
        return self.owned_text(
            self.call_rt("__jac_rt_str_chr", [self.coerce(first, mir_int(), nd)])
        );
    }
    if name in ("hex", "oct", "bin") {
        radix = 16 if name == "hex" else (8 if name == "oct" else 2);
        return self.owned_text(
            self.call_rt(
                "__jac_rt_int_text",
                [self.coerce(first, mir_int(), nd), b.const_int(radix, mir_int())]
            )
        );
    }
    if name == "abs" {
        return self.absolute(first, nd);
    }
    if name in ("min", "max") {
        return self.extreme(first, args[1:], name, nd);
    }
    if name == "round" {
        return self.rounded(first, args[1] if len(args) > 1 else None, nd);
    }
    if name == "divmod" and len(args) == 2 {
        return self.divmod_value(self.spill(first), self.lower_expr(args[1]), nd);
    }
    if name == "pow" and len(args) == 2 {
        return self.power(first, self.lower_expr(args[1]), nd);
    }
    raise MirRefused(mir_refusal("call", f"{name} with {len(args)} arguments", nd));
}

impl MirLowering.text_bytes(value: MirValue) -> tuple[MirValue, MirValue] {
    if self.is_byte_seq(value) {
        return self.byte_parts(value);
    }
    b = self.builder();
    text = self.as_text(value);
    return (b.str_part(text, "data"), b.str_part(text, "len"));
}

impl MirLowering.bytes_from(args: list[uni.Expr], nd: uni.FuncCall) -> MirValue {
    b = self.builder();
    source = self.spill(self.lower_expr(args[0]));
    kind = source.type.kind;
    handle: MirValue;
    if kind in (MirKind.STR, MirKind.STR_REF) {
        if len(args) < 2 {
            raise MirRefused(
                mir_refusal("call", "bytes of str without an encoding", nd)
            );
        }
        text = self.as_text(source);
        codec = self.codec_arg(args[1], TEXT_CODECS, nd);
        errors = self.codec_arg(args[2] if len(args) > 2 else None, TEXT_ERRORS, nd);
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
    } elif kind in (MirKind.INT, MirKind.BOOL) {
        handle = self.call_rt("__jac_rt_bytes_zero", [b.convert(source, mir_int())]);
    } elif self.is_byte_seq(source) {
        (data, size) = self.byte_parts(source);
        handle = self.call_rt("__jac_rt_bytes_new", [data, size]);
    } elif kind == MirKind.LIST
        and source.type.payload().kind in (MirKind.INT, MirKind.BOOL) {
        handle = self.call_rt("__jac_rt_bytes_from_list", [source]);
    } elif kind in (MirKind.RANGE, MirKind.ITER, MirKind.TUPLE, MirKind.SET) {
        handle = self.call_rt(
            "__jac_rt_bytes_from_list", [self.spill(self.drain(source, mir_int(), nd))]
        );
    } else {
        raise MirRefused(mir_refusal("call", f"bytes of {source.type.render()}", nd));
    }
    return b.ref_cast(handle, mir_bytes(), True);
}

impl MirLowering.absolute(value: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    if value.type.kind == MirKind.FLOAT {
        bits = self.emit_value(
            MirOp.BITCAST, mir_int(value.type.width, True, True), [value]
        );
        mask = b.const_int((1 << (value.type.width - 1)) - 1, bits.type);
        return self.emit_value(
            MirOp.BITCAST, value.type, [b.binary("and", bits, mask)]
        );
    }
    if value.type.kind not in (MirKind.INT, MirKind.BOOL) {
        raise MirRefused(mir_refusal("call", f"abs of {value.type.render()}", site));
    }
    whole = b.convert(value, mir_int()) if value.type.kind == MirKind.BOOL else value;
    if not whole.type.signed {
        return whole;
    }
    zero = b.const_int(0, whole.type);
    negative = b.compare("lt", whole, zero);
    self.raise_if(
        b.binary("and", negative, b.overflows("sub", zero, whole)),
        "OverflowError",
        OVERFLOW_MESSAGE
    );
    return b.select(negative, b.binary("sub", zero, whole), whole);
}

impl MirLowering.extreme(
    first: MirValue, rest: list[uni.Expr], name: str, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    order = "gt" if name == "max" else "lt";
    if not rest {
        if first.type.kind != MirKind.LIST or not first.type.payload().is_numeric() {
            raise MirRefused(
                mir_refusal("call", f"{name} of {first.type.render()}", site)
            );
        }
        items = self.spill(first);
        size = self.container_len(items);
        self.raise_if(
            b.compare("eq", size, b.const_int(0, mir_int())),
            "ValueError",
            f"{name}() iterable argument is empty"
        );
        elem = items.type.payload();
        best = self.temp_slot(elem);
        cursor = self.temp_slot(mir_int());
        b.store(best, self.list_read(items, b.const_int(0, mir_int())));
        b.store(cursor, b.const_int(1, mir_int()));
        fn = self.st().fn;
        head = fn.new_block("extreme.head");
        body = fn.new_block("extreme.body");
        done = fn.new_block("extreme.done");
        b.branch(head);
        b.position(head);
        at = b.load(cursor, mir_int());
        b.cond_branch(b.compare("lt", at, self.container_len(items)), body, done);
        b.position(body);
        candidate = self.list_read(items, at);
        current = b.load(best, elem);
        b.store(
            best, b.select(b.compare(order, candidate, current), candidate, current)
        );
        b.store(cursor, b.binary("add", at, b.const_int(1, mir_int())));
        b.branch(head);
        b.position(done);
        return b.load(best, elem);
    }
    values = [first] + [self.lower_expr(arg) for arg in rest];
    if not all(value.type.is_numeric() for value in values) {
        raise MirRefused(mir_refusal("call", f"{name} of non-numbers", site));
    }
    best = values[0];
    for value in values[1:] {
        (candidate, current) = self.unify_numeric(value, best, site);
        best = b.select(b.compare(order, candidate, current), candidate, current);
    }
    return best;
}

impl MirLowering.rounded(
    value: MirValue, digits_nd: (uni.Expr | None), site: uni.UniNode
) -> MirValue {
    b = self.builder();
    if value.type.kind not in (MirKind.INT, MirKind.BOOL, MirKind.FLOAT) {
        raise MirRefused(mir_refusal("call", f"round of {value.type.render()}", site));
    }
    if digits_nd is None or not self.present(digits_nd) {
        if value.type.kind == MirKind.FLOAT {
            return self.call_rt(
                "__jac_rt_float_round_int", [b.convert(value, mir_float())]
            );
        }
        return b.convert(value, mir_int());
    }
    digits = self.coerce(self.lower_expr(digits_nd), mir_int(), digits_nd);
    if value.type.kind == MirKind.FLOAT {
        return self.call_rt(
            "__jac_rt_float_round", [b.convert(value, mir_float()), digits]
        );
    }
    return self.call_rt("__jac_rt_int_round", [b.convert(value, mir_int()), digits]);
}

impl MirLowering.divmod_value(
    left: MirValue, right: MirValue, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    if not left.type.is_numeric() or not right.type.is_numeric() {
        raise MirRefused(mir_refusal("call", f"divmod of {left.type.render()}", site));
    }
    if left.type.kind == MirKind.FLOAT or right.type.kind == MirKind.FLOAT {
        (l, r) = self.unify_numeric(left, right, site);
        self.raise_if(
            b.compare("eq", r, b.const_float(0.0, r.type)),
            "ZeroDivisionError",
            "float divmod()"
        );
        quotient = self.arith(Tok.FLOOR_DIV, l, r, site);
        remainder = self.arith(Tok.MOD, l, r, site);
        return self.emit_value(
            MirOp.TUPLE_MAKE,
            mir_tuple([quotient.type, remainder.type]),
            [quotient, remainder]
        );
    }
    quotient = self.arith(Tok.FLOOR_DIV, left, right, site);
    remainder = self.arith(Tok.MOD, left, right, site);
    return self.emit_value(
        MirOp.TUPLE_MAKE,
        mir_tuple([quotient.type, remainder.type]),
        [quotient, remainder]
    );
}

impl MirLowering.power(left: MirValue, right: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    if not left.type.is_numeric() or not right.type.is_numeric() {
        raise MirRefused(
            mir_refusal("binary operator", f"** on {left.type.render()}", site)
        );
    }
    if (left.type.is_sized() or right.type.is_sized())
        and left.type.kind != MirKind.FLOAT
        and right.type.kind != MirKind.FLOAT
        and max(left.type.width, right.type.width) < 64 {
        sized = left.type if left.type.is_sized() else right.type;
        raw = self.call_rt(
            "__jac_rt_int_pow",
            [b.convert(left, mir_int()), b.convert(right, mir_int())]
        );
        return self.checked_cast(raw, sized, site);
    }
    if left.type.is_sized() or right.type.is_sized() {
        raise MirRefused(
            mir_refusal(
                "binary operator",
                "** on a fixed-width int",
                site,
                "Convert the operands to int first."
            )
        );
    }
    if left.type.kind == MirKind.FLOAT or right.type.kind == MirKind.FLOAT {
        return self.call_rt(
            "__jac_rt_float_pow",
            [b.convert(left, mir_float()), b.convert(right, mir_float())]
        );
    }
    base = b.convert(left, mir_int());
    exponent = b.convert(right, mir_int());
    if self.pow_result(site).kind == MirKind.FLOAT {
        return self.call_rt("__jac_rt_int_pow_float", [base, exponent]);
    }
    return self.call_rt("__jac_rt_int_pow", [base, exponent]);
}

impl MirLowering.pow_result(site: uni.UniNode) -> MirType {
    if isinstance(site, uni.Assignment) {
        targets = list(site.target);
        return self.expr_type(targets[0]) if len(targets) == 1 else mir_int();
    }
    if isinstance(site, uni.Expr) {
        return self.expr_type(site);
    }
    return mir_int();
}

impl MirLowering.hash_value(value: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    kind = value.type.kind;
    if kind in (MirKind.INT, MirKind.BOOL) {
        return self.call_rt("__jac_rt_hash_int", [b.convert(value, mir_int())]);
    }
    if kind == MirKind.FLOAT {
        return self.call_rt("__jac_rt_hash_float", [b.convert(value, mir_float())]);
    }
    if kind in (MirKind.STR, MirKind.STR_REF) {
        text = self.as_text(value);
        return self.call_rt(
            "__jac_rt_hash_bytes", [b.str_part(text, "data"), b.str_part(text, "len")]
        );
    }
    if kind == MirKind.BYTES {
        (data, size) = self.byte_parts(self.spill(value));
        return self.call_rt("__jac_rt_hash_bytes", [data, size]);
    }
    if kind == MirKind.TUPLE {
        held = self.spill(value);
        acc = self.spill(self.call_rt("__jac_rt_hash_tuple_start", []));
        for index in range(len(value.type.args)) {
            lane = self.hash_value(self.tuple_get(held, index), site);
            acc = self.call_rt("__jac_rt_hash_tuple_add", [acc, lane]);
        }
        return self.call_rt(
            "__jac_rt_hash_tuple_end",
            [acc, b.const_int(len(value.type.args), mir_int())]
        );
    }
    if kind == MirKind.OBJ {
        arch = self.archetypes.get(value.type.name);
        method = self.find_method(arch, "__hash__") if arch is not None else None;
        if method is not None {
            decl = self.decls.get(id(method));
            if decl is None or decl.params {
                raise MirRefused(
                    mir_refusal("method", f"{value.type.name}.__hash__", site)
                );
            }
            hashed = b.call(decl.symbol, [value], decl.ret);
            if hashed is None {
                raise RuntimeError(f"{decl.symbol} returns no value");
            }
            return self.coerce(hashed, mir_int(), site);
        }
        return self.call_rt("__jac_rt_hash_pointer", [self.address_of(value)]);
    }
    if kind in (MirKind.BYTEARRAY, MirKind.LIST, MirKind.DICT, MirKind.SET) {
        b.raise_builtin(
            "TypeError", f"unhashable type: '{self.type_label(value.type)}'"
        );
        b.position(self.st().fn.new_block("dead"));
        return b.const_int(0, mir_int());
    }
    raise MirRefused(mir_refusal("call", f"hash of {value.type.render()}", site));
}

impl MirLowering.extreme_named(nd: uni.FuncCall, name: str) -> (MirValue | None) {
    b = self.builder();
    fn = self.st().fn;
    (args, named) = self.split_args(nd);
    if len(args) != 1 or set(named) - {"key", "default"} {
        return None;
    }
    items = self.spill(self.lower_expr(args[0]));
    if items.type.kind != MirKind.LIST {
        raise MirRefused(
            mir_refusal("call", f"{name} of {items.type.render()} with keywords", nd)
        );
    }
    result_type = self.expr_type(nd);
    key_fn: (MirValue | None) = None;
    if "key" in named {
        key_fn = self.key_function(named["key"]);
    }
    fallback: (MirValue | None) = None;
    if "default" in named {
        fallback = self.spill(self.lower_expr(named["default"]));
    }
    held = self.temp_slot(result_type);
    size = self.container_len(items);
    empty = b.compare("eq", size, b.const_int(0, mir_int()));
    filled = fn.new_block("extreme.filled");
    finished = fn.new_block("extreme.finished");
    if fallback is None {
        self.raise_if(empty, "ValueError", f"{name}() iterable argument is empty");
        b.branch(filled);
    } else {
        vacant = fn.new_block("extreme.empty");
        b.cond_branch(empty, vacant, filled);
        b.position(vacant);
        b.store(held, self.coerce(fallback, result_type, nd));
        b.branch(finished);
    }
    b.position(filled);
    order = Tok.GT if name == "max" else Tok.LT;
    best_at = self.temp_slot(mir_int());
    b.store(best_at, b.const_int(0, mir_int()));
    best_key: (MirValue | None) = None;
    key_type = mir_void();
    if key_fn is not None {
        key_type = key_fn.type.args[0];
        best_key = self.temp_slot(key_type);
        b.store(
            best_key,
            self.call_closure(
                key_fn, [self.list_read(items, b.const_int(0, mir_int()))], nd
            )
        );
    }
    cursor = self.temp_slot(mir_int());
    b.store(cursor, b.const_int(1, mir_int()));
    head = fn.new_block("extreme.head");
    body = fn.new_block("extreme.body");
    take = fn.new_block("extreme.take");
    step = fn.new_block("extreme.step");
    done = fn.new_block("extreme.done");
    b.branch(head);
    b.position(head);
    at = b.load(cursor, mir_int());
    b.cond_branch(b.compare("lt", at, self.container_len(items)), body, done);
    b.position(body);
    candidate = self.list_read(items, at);
    computed: (MirValue | None) = None;
    better: MirValue;
    if key_fn is not None and best_key is not None {
        computed = self.spill(self.call_closure(key_fn, [candidate], nd));
        better = self.compare_values(order, computed, b.load(best_key, key_type), nd);
    } else {
        better = self.compare_values(
            order, candidate, self.list_read(items, b.load(best_at, mir_int())), nd
        );
    }
    b.cond_branch(better, take, step);
    b.position(take);
    b.store(best_at, at);
    if computed is not None and best_key is not None {
        b.store(best_key, computed);
    }
    b.branch(step);
    b.position(step);
    b.store(cursor, b.binary("add", at, b.const_int(1, mir_int())));
    b.branch(head);
    b.position(done);
    b.store(
        held,
        self.coerce(self.list_read(items, b.load(best_at, mir_int())), result_type, nd)
    );
    b.branch(finished);
    b.position(finished);
    return b.load(held, result_type);
}

impl MirLowering.sized_type_name(nd: uni.UniNode) -> (str | None) {
    if not isinstance(nd, uni.Name) {
        return None;
    }
    if nd.sym is not None and id(nd.sym) in self.st().locals {
        return None;
    }
    shape = shape_of(nd.value);
    if shape is None or shape.is_float or not shape.sized {
        return None;
    }
    return nd.value;
}

impl MirLowering.int_bounds(t: MirType) -> tuple[int, int] {
    if t.signed {
        return (-(1 << (t.width - 1)), (1 << (t.width - 1)) - 1);
    }
    return (0, (1 << t.width) - 1);
}

impl MirLowering.int_bits(value: int, t: MirType) -> int {
    if value >= (1 << 63) {
        return value - (1 << 64);
    }
    return value;
}

impl MirLowering.sized_bound(nd: uni.AtomTrailer) -> (MirValue | None) {
    if not nd.is_attr
        or not isinstance(nd.right, uni.Name)
        or nd.right.value not in ("MIN", "MAX") {
        return None;
    }
    name = self.sized_type_name(nd.target);
    if name is None {
        return None;
    }
    t = mir_class_type_named(name, nd);
    (lo, hi) = self.int_bounds(t);
    return self.builder().const_int(
        self.int_bits(lo if nd.right.value == "MIN" else hi, t), t
    );
}

impl MirLowering.sized_wrap(nd: uni.FuncCall, name: str) -> MirValue {
    b = self.builder();
    args = self.call_args(nd);
    if len(args) != 1 {
        raise MirRefused(mir_refusal("call", f"{name}.wrap", nd));
    }
    target = mir_class_type_named(name, nd);
    value = self.enum_as_int(self.lower_expr(args[0]), args[0]);
    if value.type.kind == MirKind.BOOL {
        value = b.convert(value, mir_int());
    }
    if value.type.kind == MirKind.FLOAT {
        value = b.convert(b.convert(value, mir_float()), mir_int());
    }
    if value.type.kind != MirKind.INT {
        raise MirRefused(
            mir_refusal("call", f"{name}.wrap of {value.type.render()}", nd)
        );
    }
    return b.convert(value, target);
}

impl MirLowering.wrapping_call(
    nd: uni.FuncCall, name: str, args: list[uni.Expr]
) -> MirValue {
    b = self.builder();
    values = [self.lower_expr(arg) for arg in args];
    if not values or not all(value.type.kind == MirKind.INT for value in values) {
        raise MirRefused(mir_refusal("call", name, nd));
    }
    if name == "wrapping_neg" and len(values) == 1 {
        return b.binary("sub", b.const_int(0, values[0].type), values[0]);
    }
    if len(values) != 2 {
        raise MirRefused(mir_refusal("call", name, nd));
    }
    (left, right) = (values[0], values[1]);
    if name == "wrapping_shl" {
        count = b.binary(
            "and",
            b.convert(right, left.type),
            b.const_int(left.type.width - 1, left.type)
        );
        return b.binary("shl", left, count);
    }
    if right.type is not left.type {
        right = b.convert(right, left.type);
    }
    ops = {"wrapping_add": "add", "wrapping_sub": "sub", "wrapping_mul": "mul"};
    op = ops.get(name);
    if op is None {
        raise MirRefused(mir_refusal("call", name, nd));
    }
    return b.binary(op, left, right);
}

impl MirLowering.checked_cast(
    value: MirValue, to: MirType, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    if value.type.kind == MirKind.BOOL {
        value = b.convert(value, mir_int());
    }
    if to.kind != MirKind.INT or not to.is_sized() {
        return b.convert(value, to);
    }
    (lo, hi) = self.int_bounds(to);
    if value.type.kind == MirKind.FLOAT {
        wide = b.convert(value, mir_float());
        below = float(lo - 1);
        above = float(hi + 1);
        low_ok = b.compare("gt", wide, b.const_float(below, mir_float()))
            if below == lo - 1
            else b.compare("ge", wide, b.const_float(float(lo), mir_float()));
        high_ok = b.compare("lt", wide, b.const_float(above, mir_float()))
            if above == hi + 1
            else b.compare("le", wide, b.const_float(float(hi), mir_float()));
        self.raise_if(
            b.logical_not(b.binary("and", low_ok, high_ok)),
            "OverflowError",
            OVERFLOW_MESSAGE
        );
        return b.convert(wide, to);
    }
    if value.type.kind != MirKind.INT {
        return b.convert(value, to);
    }
    src = value.type;
    (src_lo, src_hi) = self.int_bounds(src);
    if lo > src_lo {
        self.raise_if(
            b.compare("lt", value, b.const_int(self.int_bits(lo, src), src)),
            "OverflowError",
            OVERFLOW_MESSAGE
        );
    }
    if hi < src_hi {
        self.raise_if(
            b.compare("gt", value, b.const_int(self.int_bits(hi, src), src)),
            "OverflowError",
            OVERFLOW_MESSAGE
        );
    }
    return b.convert(value, to);
}

impl MirLowering.int_bytes_call(
    nd: uni.FuncCall, target: uni.AtomTrailer, name: str
) -> (MirValue | None) {
    b = self.builder();
    owner = target.target;
    is_class = isinstance(owner, uni.Name)
        and owner.value == "int"
        and not (owner.sym is not None and id(owner.sym) in self.st().locals);
    if name == "from_bytes" and not is_class {
        return None;
    }
    if name == "to_bytes"
        and (
            is_class
            or not isinstance(owner, uni.Expr)
            or self.expr_type(owner).kind not in (MirKind.INT, MirKind.BOOL)
        ) {
        return None;
    }
    (args, named) = self.split_args(nd);
    order_names = ["length", "byteorder"]
        if name == "to_bytes"
        else ["bytes", "byteorder"];
    for (index, arg) in enumerate(args) {
        if index >= len(order_names) {
            raise MirRefused(mir_refusal("call", f"int.{name} arguments", nd));
        }
        named[order_names[index]] = arg;
    }
    if set(named) - set(order_names + ["signed"]) or order_names[0] not in named {
        raise MirRefused(mir_refusal("call", f"int.{name} arguments", nd));
    }
    big = b.const_bool(True);
    order = named.get("byteorder");
    if order is not None {
        literal = uni.literal_string_value(order);
        if literal == "big" or literal == "little" {
            big = b.const_bool(literal == "big");
        } else {
            big = self.compare_values(
                Tok.EE, self.lower_expr(order), b.const_str("big", mir_str()), order
            );
        }
    }
    signed = b.const_bool(False);
    if "signed" in named {
        signed = self.truthy(self.lower_expr(named["signed"]), named["signed"]);
    }
    if name == "from_bytes" {
        source = self.spill(self.lower_expr(named["bytes"]));
        if not self.is_byte_seq(source) {
            raise MirRefused(
                mir_refusal("call", f"int.from_bytes of {source.type.render()}", nd)
            );
        }
        (data, size) = self.byte_parts(source);
        return self.call_rt("__jac_rt_int_from_bytes", [data, size, big, signed]);
    }
    value = b.convert(self.lower_expr(owner), mir_int());
    length = self.coerce(self.lower_expr(named["length"]), mir_int(), nd);
    return b.ref_cast(
        self.call_rt("__jac_rt_int_to_bytes", [value, length, big, signed]),
        mir_bytes(),
        True
    );
}

impl MirLowering.struct_call(nd: uni.FuncCall, name: str) -> MirValue {
    b = self.builder();
    (args, named) = self.split_args(nd);
    fmt = uni.literal_string_value(args[0]) if args else None;
    layout = self.prog.get_type_evaluator().struct_format_fields(fmt)
        if isinstance(fmt, str)
        else None;
    if named or layout is None {
        raise MirRefused(
            mir_refusal(
                "call",
                f"struct.{name}",
                nd,
                "Native struct calls take a literal format of fixed-size codes and positional values."
            )
        );
    }
    (fields, total, big) = layout;
    if name == "calcsize" and len(args) == 1 {
        return b.const_int(total, mir_int());
    }
    big_flag = b.const_bool(big);
    u8p = mir_c_ptr(mir_int(8, False));
    if name == "pack" {
        values = args[1:];
        if len(values) != len(fields) {
            raise MirRefused(
                mir_refusal(
                    "call",
                    f"struct.pack with {len(values)} values for {len(fields)} fields",
                    nd
                )
            );
        }
        made = self.spill(
            b.ref_cast(
                self.call_rt("__jac_rt_bytes_zero", [b.const_int(total, mir_int())]),
                mir_bytes(),
                True
            )
        );
        (data, _) = self.byte_parts(made);
        for ((code, offset, size), arg) in zip(fields, values) {
            if code in "cs" {
                raise MirRefused(mir_refusal("call", f"struct.pack of '{code}'", arg));
            }
            value = self.lower_expr(arg);
            bits: MirValue;
            if code in "fd" {
                width = 32 if code == "f" else 64;
                raw = self.emit_value(
                    MirOp.BITCAST,
                    mir_int(width, True, True),
                    [b.convert(self.coerce(value, mir_float(), arg), mir_float(width))]
                );
                bits = b.convert(
                    b.convert(raw, mir_int(width, False, True)), mir_int()
                );
            } else {
                bits = self.coerce(self.enum_as_int(value, arg), mir_int(), arg);
            }
            self.runtime(
                "__jac_rt_struct_put",
                [
                    self.emit_value(
                        MirOp.PTR_OFFSET, u8p, [data, b.const_int(offset, mir_int())]
                    ),
                    bits,
                    b.const_int(size, mir_int()),
                    big_flag
                ]
            );
        }
        return made;
    }
    if name not in ("unpack", "unpack_from") or len(args) not in (2, 3) {
        raise MirRefused(mir_refusal("call", f"struct.{name}", nd));
    }
    source = self.spill(self.lower_expr(args[1]));
    if not self.is_byte_seq(source) {
        raise MirRefused(
            mir_refusal("call", f"struct.{name} of {source.type.render()}", nd)
        );
    }
    (data, size) = self.byte_parts(source);
    start = b.const_int(0, mir_int());
    if name == "unpack_from" and len(args) == 3 {
        start = self.coerce(self.lower_expr(args[2]), mir_int(), args[2]);
    }
    if name == "unpack" {
        self.raise_if(
            b.compare("ne", size, b.const_int(total, mir_int())),
            "ValueError",
            f"unpack requires a buffer of {total} bytes"
        );
    } else {
        self.raise_if(
            b.binary(
                "or",
                b.compare("lt", start, b.const_int(0, mir_int())),
                b.compare(
                    "gt", b.binary("add", start, b.const_int(total, mir_int())), size
                )
            ),
            "ValueError",
            f"unpack_from requires a buffer of at least {total} bytes"
        );
    }
    result_type = self.expr_type(nd);
    if result_type.kind != MirKind.TUPLE or len(result_type.args) != len(fields) {
        raise MirRefused(mir_refusal("call", f"struct.{name} result", nd));
    }
    members: list[MirValue] = [];
    for ((code, offset, width), member) in zip(fields, result_type.args) {
        at = self.emit_value(
            MirOp.PTR_OFFSET,
            u8p,
            [data, b.binary("add", start, b.const_int(offset, mir_int()))]
        );
        if code in "cs" {
            made_bytes = b.ref_cast(
                self.call_rt("__jac_rt_bytes_new", [at, b.const_int(width, mir_int())]),
                mir_bytes(),
                True
            );
            members.append(self.coerce(made_bytes, member, nd));
            continue;
        }
        signed = code in "bhilqn";
        raw = self.call_rt(
            "__jac_rt_int_from_bytes",
            [at, b.const_int(width, mir_int()), big_flag, b.const_bool(signed)]
        );
        if code in "fd" {
            float_width = 32 if code == "f" else 64;
            real = self.emit_value(
                MirOp.BITCAST,
                mir_float(float_width),
                [b.convert(raw, mir_int(float_width, True, True))]
            );
            members.append(self.coerce(b.convert(real, mir_float()), member, nd));
        } elif code == "?" {
            members.append(
                self.coerce(b.compare("ne", raw, b.const_int(0, mir_int())), member, nd)
            );
        } else {
            members.append(self.coerce(raw, member, nd));
        }
    }
    return self.emit_value(MirOp.TUPLE_MAKE, result_type, members);
}
