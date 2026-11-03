impl MirLowering.builtin_value(nd: uni.FuncCall, name: str) -> (MirValue | None) {
    if name == "jid" {
        return self.lower_jid(nd);
    }
    args = self.call_args(nd);
    if not args and name in ("list", "dict", "set", "frozenset") {
        made = self.expr_type(nd);
        if made.kind == MirKind.LIST {
            return self.new_list(made.payload(), 0);
        }
        if made.kind == MirKind.DICT {
            return self.new_dict(made.args[0], made.args[1], made);
        }
        if made.kind == MirKind.SET {
            return self.new_dict(made.payload(), None, made);
        }
        raise MirRefused(mir_refusal("call", f"{name}() as {made.render()}", nd));
    }
    if len(args) != 1 {
        return None;
    }
    b = self.builder();
    if name == "id" {
        return self.identity_of(self.lower_expr(args[0]), nd);
    }
    if name in ("set", "frozenset") {
        made_type = self.expr_type(nd);
        if made_type.kind != MirKind.SET {
            raise MirRefused(
                mir_refusal("call", f"{name} as {made_type.render()}", nd)
            );
        }
        source = self.lower_expr(args[0]);
        built = self.spill(self.new_dict(made_type.payload(), None, made_type));
        self.extend_from(built, source, args[0]);
        return built;
    }
    if name == "dict" {
        made_type = self.expr_type(nd);
        source = self.lower_expr(args[0]);
        if made_type.kind != MirKind.DICT or source.type.kind != MirKind.DICT {
            raise MirRefused(
                mir_refusal("call", f"dict of {source.type.render()}", nd)
            );
        }
        built = self.spill(
            self.new_dict(made_type.args[0], made_type.args[1], made_type)
        );
        self.merge_dict(built, source, args[0], False);
        return built;
    }
    if name in ("list", "reversed") {
        value = self.lower_expr(args[0]);
        if name == "list" and value.type.kind != MirKind.LIST {
            made_type = self.expr_type(nd);
            if made_type.kind != MirKind.LIST {
                raise MirRefused(
                    mir_refusal("call", f"list as {made_type.render()}", nd)
                );
            }
            return self.drain(value, made_type.payload(), nd);
        }
        if value.type.kind != MirKind.LIST {
            raise MirRefused(
                mir_refusal("call", f"{name} of {value.type.render()}", nd)
            );
        }
        handle = self.runtime(
            "__jac_rt_list_copy",
            [value, b.const_int(self.elem_kind(value.type.payload(), nd), mir_int())]
        );
        if handle is None {
            raise MirRefused(mir_refusal("call", name, nd));
        }
        copied = b.ref_cast(handle, value.type, True);
        if name == "reversed" {
            self.runtime("__jac_rt_list_reverse", [copied]);
        }
        return copied;
    }
    return None;
}

impl MirLowering.list_concat(left: MirValue, right: MirValue) -> MirValue {
    b = self.builder();
    kind = b.const_int(self.elem_kind(left.type.payload(), self.module), mir_int());
    made = self.runtime("__jac_rt_list_copy", [left, kind]);
    if made is None {
        raise MirRefused(mir_refusal("binary operator", "list +"));
    }
    joined = b.ref_cast(made, left.type, True);
    self.runtime("__jac_rt_list_extend", [joined, right, kind]);
    return joined;
}

impl MirLowering.list_repeat(
    items: MirValue, times: MirValue, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    held = self.spill(items);
    kind = b.const_int(self.elem_kind(held.type.payload(), site), mir_int());
    made = self.spill(self.new_list(held.type.payload(), 0));
    count = self.temp_slot(mir_int());
    limit = self.spill(b.convert(times, mir_int()));
    b.store(count, b.const_int(0, mir_int()));
    head = fn.new_block("lrep.head");
    body = fn.new_block("lrep.body");
    done = fn.new_block("lrep.done");
    b.branch(head);
    b.position(head);
    b.cond_branch(b.compare("lt", b.load(count, mir_int()), limit), body, done);
    b.position(body);
    self.runtime("__jac_rt_list_extend", [made, held, kind]);
    b.store(
        count, b.binary("add", b.load(count, mir_int()), b.const_int(1, mir_int()))
    );
    b.branch(head);
    b.position(done);
    return made;
}

impl MirLowering.str_subscript(nd: uni.AtomTrailer) -> (MirValue | None) {
    right = nd.right;
    if nd.is_attr
        or not isinstance(right, uni.IndexSlice)
        or not isinstance(nd.target, uni.Expr)
        or right.is_range
        or len(right.slices) != 1
        or right.slices[0].start is None
        or self.expr_type(nd.target).kind != MirKind.STR {
        return None;
    }
    b = self.builder();
    text = self.spill(self.as_text(self.lower_expr(nd.target)));
    position = right.slices[0].start;
    at = self.coerce(self.lower_expr(position), mir_int(), position);
    count = self.runtime(
        "__jac_rt_str_len",
        [b.str_part(text, "root"), b.str_part(text, "data"), b.str_part(text, "len")]
    );
    if count is None {
        raise MirRefused(mir_refusal("subscript", "str", nd));
    }
    wrapped = b.select(
        b.compare("lt", at, b.const_int(0, mir_int())), b.binary("add", at, count), at
    );
    self.raise_if(
        b.binary(
            "or",
            b.compare("lt", wrapped, b.const_int(0, mir_int())),
            b.compare("ge", wrapped, count)
        ),
        "IndexError",
        STR_INDEX_MESSAGE
    );
    made = self.runtime(
        "__jac_rt_str_char_at",
        [b.str_part(text, "data"), b.str_part(text, "len"), wrapped]
    );
    size = self.runtime("__jac_rt_str_size", [made]) if made is not None else None;
    if made is None or size is None {
        raise MirRefused(mir_refusal("subscript", "str", nd));
    }
    return b.str_make(made, made, size);
}

impl MirLowering.identity_of(value: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    t = value.type;
    if t.kind == MirKind.OPT {
        held = self.spill(value);
        return b.select(
            self.opt_present(held),
            self.identity_of(self.opt_get(held), site),
            b.const_int(0, mir_int())
        );
    }
    if t.kind == MirKind.ANY {
        return self.emit_value(MirOp.ANY_PAYLOAD, mir_int(), [value]);
    }
    if t.kind in (MirKind.INT, MirKind.BOOL, MirKind.ENUM) {
        return b.convert(value, mir_int());
    }
    if t.kind == MirKind.FLOAT {
        return self.emit_value(
            MirOp.BITCAST, mir_int(), [b.convert(value, mir_float())]
        );
    }
    if t.kind == MirKind.STR {
        return self.address_of(b.str_part(value, "data"));
    }
    if mir_holds_ref(t) and t.kind != MirKind.TUPLE {
        return self.address_of(value);
    }
    raise MirRefused(mir_refusal("call", f"id of {t.render()}", site));
}

impl MirLowering.sys_attr(nd: uni.AtomTrailer) -> (MirValue | None) {
    if not nd.is_attr
        or not isinstance(nd.target, uni.Name)
        or not isinstance(nd.target.type, ModuleType)
        or nd.target.type.mod_name != "sys"
        or not isinstance(nd.right, uni.Name)
        or nd.right.value != "argv" {
        return None;
    }
    b = self.builder();
    count_type = mir_int(32, True);
    table_type = mir_c_ptr(mir_int(8, False));
    count = b.load(self.extern_global("__jac_argc", count_type), count_type);
    table = b.load(self.extern_global("__jac_argv", table_type), table_type);
    handle = self.call_rt("__jac_rt_argv_list", [b.convert(count, mir_int()), table]);
    return self.typed_handle(handle, nd);
}

impl MirLowering.extern_global(symbol: str, t: MirType) -> MirValue {
    if symbol not in self.mir.globals {
        self.mir.globals[symbol] = MirGlobal(
            name=symbol, symbol=symbol, type=t, linkage="weak"
        );
    }
    return self.emit_value(MirOp.GLOBAL_ADDR, mir_c_ptr(t), [], str_value=symbol);
}

impl MirLowering.input_call(nd: uni.FuncCall) -> MirValue {
    args = self.call_args(nd);
    if len(args) > 1 {
        raise MirRefused(mir_refusal("call", f"input with {len(args)} arguments", nd));
    }
    b = self.builder();
    if args {
        self.write_value(self.lower_expr(args[0]), 1, nd);
    }
    self.runtime("__jac_rt_flush", [b.const_int(1, mir_int())]);
    line = self.call_rt("__jac_rt_input_line", []);
    self.raise_if(
        b.compare("eq", self.address_of(line), b.const_int(0, mir_int())),
        "EOFError",
        "EOF when reading a line"
    );
    return b.str_make(line, line, self.runtime_value("__jac_rt_str_size", [line]));
}

impl MirLowering.sys_exit(nd: uni.FuncCall) -> MirValue {
    args = self.call_args(nd);
    b = self.builder();
    code = b.const_int(0, mir_int());
    if args {
        given = self.lower_expr(args[0]);
        if given.type.kind == MirKind.NONE {
            code = b.const_int(0, mir_int());
        } elif given.type.kind in (MirKind.INT, MirKind.BOOL) {
            code = b.convert(given, mir_int());
        } else {
            raise MirRefused(
                mir_refusal(
                    "call",
                    f"sys.exit with {given.type.render()}",
                    nd,
                    "Native sys.exit takes an int status (or none)."
                )
            );
        }
    }
    self.runtime("__jac_rt_exit", [code]);
    return self.none_value();
}

impl MirLowering.cstr_of(value: MirValue) -> MirValue {
    b = self.builder();
    text = self.as_text(value);
    held = self.runtime_value(
        "__jac_rt_str_ref",
        [b.str_part(text, "root"), b.str_part(text, "data"), b.str_part(text, "len")]
    );
    return self.emit_value(MirOp.PTR_CAST, mir_c_ptr(mir_int(8, False)), [held]);
}

impl MirLowering.open_call(nd: uni.FuncCall) -> MirValue {
    b = self.builder();
    made_type = self.expr_type(nd);
    if made_type.kind != MirKind.FILE {
        raise MirRefused(mir_refusal("call", f"open as {made_type.render()}", nd));
    }
    positional: list[uni.Expr] = [];
    mode_nd: (uni.Expr | None) = None;
    for arg in list(nd.params or []) {
        if isinstance(arg, uni.KWPair) {
            key = arg.key.sym_name if arg.key is not None else "";
            if key == "mode" {
                mode_nd = arg.value;
            } elif key == "encoding" {
                self.lower_expr(arg.value);
            } else {
                raise MirRefused(mir_refusal("call argument", f"open {key}=", arg));
            }
        } else {
            positional.append(arg);
        }
    }
    if not positional or len(positional) > 2 {
        raise MirRefused(
            mir_refusal("call", f"open with {len(positional)} arguments", nd)
        );
    }
    if len(positional) == 2 {
        mode_nd = positional[1];
    }
    path = self.cstr_of(self.lower_expr(positional[0]));
    mode = self.cstr_of(self.lower_expr(mode_nd))
        if mode_nd is not None
        else self.cstr_of(b.const_str("r", mir_str()));
    made = self.runtime_value(
        "__jac_rt_file_open", [path, mode, b.const_bool(made_type.name == "BinaryFile")]
    );
    self.raise_if(
        b.compare("eq", self.address_of(made), b.const_int(0, mir_int())),
        "FileNotFoundError",
        "No such file or directory"
    );
    return b.ref_cast(made, made_type, True);
}

impl MirLowering.file_method(
    handle: MirValue, name: str, nd: uni.FuncCall
) -> (MirValue | None) {
    b = self.builder();
    binary = handle.type.name == "BinaryFile";
    args = self.call_args(nd);
    if name in ("read", "readline") and not args {
        made = self.runtime_value(
            "__jac_rt_file_read",
            [handle, b.const_bool(binary), b.const_bool(name == "readline")]
        );
        if binary {
            return b.ref_cast(made, mir_bytes(), True);
        }
        text = b.ref_cast(made, mir_str_ref(), True);
        return self.owned_text(text);
    }
    if name == "write" and len(args) == 1 {
        value = self.spill(self.lower_expr(args[0]));
        (data, size) = self.text_bytes(value);
        return self.runtime_value("__jac_rt_file_write", [handle, data, size]);
    }
    if name in ("close", "flush") and not args {
        self.runtime(f"__jac_rt_file_{name}", [handle]);
        return self.none_value();
    }
    if name == "__enter__" and not args {
        return handle;
    }
    if name == "__exit__" {
        for arg in args {
            self.lower_expr(arg);
        }
        self.runtime("__jac_rt_file_close", [handle]);
        return b.const_bool(False);
    }
    return None;
}
