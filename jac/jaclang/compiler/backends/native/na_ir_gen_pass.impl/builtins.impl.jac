impl NaIRGenPass._get_or_declare_extern(
    name: str, ret_type: ir.Type, arg_types: list[ir.Type], var_arg: bool = False
) -> ir.Function {
    wanted = ir.FunctionType(ret_type, arg_types, var_arg=var_arg);
    existing: (ir.Function | None) = self.extern_funcs.get(name);
    if existing is None {
        for gv in self.llvm_module.global_values {
            if isinstance(gv, ir.Function) and gv.name == name {
                existing = gv;
                break;
            }
        }
    }
    if existing is None {
        existing = ir.Function(self.llvm_module, wanted, name=name);
    }
    self.extern_funcs[name] = existing;
    actual = existing.function_type;
    if actual == wanted {
        return existing;
    }
    key = name + ":" + str(wanted);
    if key in self.extern_funcs {
        return self.extern_funcs[key];
    }
    if actual.var_arg or var_arg or len(actual.args) != len(arg_types) {
        raise ValueError(
            f"Incompatible native extern declaration for {name}: {actual} versus {wanted}"
        );
    }
    _n_pairs = len(arg_types);
    for _pair_i in range(_n_pairs + 1) {
        source: ir.Type = arg_types[_pair_i]
            if _pair_i < _n_pairs
            else actual.return_type;
        target: ir.Type = actual.args[_pair_i] if _pair_i < _n_pairs else ret_type;
        if source == target {
            continue;
        }
        pointer_pair = isinstance(source, ir.PointerType)
            and isinstance(target, ir.PointerType)
            and source.addrspace == target.addrspace;
        address_pair = (
            isinstance(source, ir.PointerType)
            and source.addrspace == 0
            and target == ir.IntType(64)
        )
            or (
                source == ir.IntType(64)
                and isinstance(target, ir.PointerType)
                and target.addrspace == 0
            );
        if not pointer_pair and not address_pair {
            raise ValueError(
                f"Incompatible native extern declaration for {name}: {actual} versus {wanted}"
            );
        }
    }
    adapter = ir.Function(
        self.llvm_module,
        wanted,
        name=self.llvm_module.scope.deduplicate(name + ".jac_abi")
    );
    adapter.linkage = "internal";
    adapter.attributes.add("alwaysinline");
    builder = ir.IRBuilder(adapter.append_basic_block("entry"));
    converted: list[ir.Value] = [];
    for (value, target) in zip(adapter.args, actual.args) {
        converted.append(self._extern_address_cast(builder, value, target));
    }
    result = builder.call(existing, converted);
    if isinstance(ret_type, ir.VoidType) {
        builder.ret_void();
    } else {
        builder.ret(self._extern_address_cast(builder, result, ret_type));
    }
    self.extern_funcs[key] = adapter;
    return adapter;
}

impl NaIRGenPass._extern_address_cast(
    builder: ir.IRBuilder, value: ir.Value, target: ir.Type
) -> ir.Value {
    if value.type == target {
        return value;
    }
    if isinstance(value.type, ir.PointerType) and isinstance(target, ir.IntType) {
        return builder.ptrtoint(value, target);
    }
    if isinstance(value.type, ir.IntType) and isinstance(target, ir.PointerType) {
        return builder.inttoptr(value, target);
    }
    return builder.bitcast(value, target);
}

impl NaIRGenPass._get_printf -> ir.Function {
    return self._get_or_declare_extern(
        "printf", ir.IntType(32), [ir.IntType(8).as_pointer()], var_arg=True
    );
}

impl NaIRGenPass._emit_print(nd: uni.FuncCall) -> (ir.Value | None) {
    printf = self._get_printf();
    raw: Sequence[uni.Expr | uni.KWPair] = nd.params or [];
    params: list[uni.Expr] = [];
    stream = "stdout";
    for param in raw {
        if not isinstance(param, uni.KWPair) {
            params.append(param);
            continue;
        }
        key = param.key.sym_name if param.key is not None else None;
        named = self._print_stream_name(param.value) if key == "file" else None;
        if named is None {
            self.ctx.emit(
                E5092,
                node_override=param,
                kind="print keyword",
                name=f"{key or '**'}=..."
            );
            return None;
        }
        stream = named;
    }
    if not params {
        fmt = self._get_fmt_string("");
        fmt_ptr = self.builder.bitcast(fmt, ir.IntType(8).as_pointer());
        self._emit_print_call(stream, fmt_ptr, []);
        return ir.Constant(ir.IntType(64), 0);
    }

    fmt_parts = [];
    args: list[ir.Value] = [];
    for (i, param) in enumerate(params) {
        refusals_before = len(self.ctx.errors_had);
        val = self._str_norm_optional(self._codegen_expr(param));
        if len(self.ctx.errors_had) == refusals_before
            and self._type_key_of(param) in ("None", "NoneType") {
            val = self._make_global_string("None", name_prefix=".print.none");
        }
        if val is None {
            self.ctx.emit(
                E5092,
                node_override=param,
                kind="print argument",
                name=type(param).__name__
            );
            return None;
        }

        if i > 0 {
            fmt_parts.append(" ");
        }

        if isinstance(val.type, ir.IntType) {
            if val.type.width == 1 {
                fmt_parts.append("%s");
                args.append(self._bool_text(self.builder, val, "print.bool"));
            } else {
                _unsigned = self._is_unsigned_node(param);
                fmt_parts.append("%llu" if _unsigned else "%lld");
                args.append(self._int_text_arg(val, _unsigned));
            }
        } elif isinstance(val.type, ir.DoubleType) {
            fmt_parts.append("%s");
            args.append(self._emit_float_repr(val));
        } elif isinstance(val.type, ir.FloatType) {
            val = self.builder.fpext(val, ir.DoubleType());
            fmt_parts.append("%s");
            args.append(self._emit_float_repr(val));
        } elif isinstance(val.type, ir.PointerType) {
            obj_s = self._emit_obj_str(val);
            if obj_s is None {
                obj_s = self._emit_container_repr(val, self._type_key_of(param));
            }
            if obj_s is not None {
                if self._is_owned(val) {
                    self._emit_rc_release_typed(val, op="print_obj_src", loc="");
                }
                val = obj_s;
            } elif self._is_null_ptr_const(val) {
                val = self._make_global_string("None", name_prefix=".repr.none");
            } else {
                _pointee = val.type?.pointee;
                _is_char_ptr = isinstance(_pointee, ir.IntType) and _pointee.width == 8;
                if not _is_char_ptr {
                    self.emit(
                        E5092,
                        node_override=param,
                        kind="print argument",
                        name=type(param).__name__
                    );
                    return None;
                }
            }
            fmt_parts.append("%s");
            args.append(val);
        } elif self._opt_payload_of(val.type) is not None {
            _opt_s = self._emit_optional_str(val, param);
            if _opt_s is not None {
                self._release_owned_args([val], op="print_opt_src");
            }
            if _opt_s is None {
                self.emit(
                    E5092,
                    node_override=param,
                    kind="print argument",
                    name=type(param).__name__
                );
                return None;
            }
            fmt_parts.append("%s");
            args.append(_opt_s);
        } elif self?.jacval_type is not None and val.type == self.jacval_type {
            _jv_s = self._str_jacval_fn();
            if _jv_s is None {
                self.emit(
                    E5092,
                    node_override=param,
                    kind="print argument",
                    name=type(param).__name__
                );
                return None;
            }
            fmt_parts.append("%s");
            args.append(self.builder.call(_jv_s, [val], name="print.jv"));
        } elif isinstance(val.type, ir.LiteralStructType) {
            _tup_s = self._emit_container_repr(val, self._type_key_of(param));
            if _tup_s is None {
                self.emit(
                    E5092,
                    node_override=param,
                    kind="print argument",
                    name=type(param).__name__
                );
                return None;
            }
            fmt_parts.append("%s");
            args.append(_tup_s);
        } else {
            self.emit(
                E5092,
                node_override=param,
                kind="print argument",
                name=type(param).__name__
            );
            return None;
        }
    }

    if fmt_parts {
        fmt_str = "".join(fmt_parts);
        fmt = self._get_fmt_string(fmt_str);
        fmt_ptr = self.builder.bitcast(fmt, ir.IntType(8).as_pointer());
        self._emit_print_call(stream, fmt_ptr, args);

        for _parg in args {
            if isinstance(_parg.type, ir.PointerType) and self._is_owned(_parg) {
                self._emit_rc_release_typed(_parg, op="print_tmp", loc="");
            }
        }
    }
    return ir.Constant(ir.IntType(64), 0);
}

impl NaIRGenPass._print_stream_name(value: uni.Expr) -> (str | None) {
    if not isinstance(value, uni.AtomTrailer) {
        return None;
    }
    chain = value.as_attr_list;
    if len(chain) != 2 or chain[0].sym_name != "sys" {
        return None;
    }
    if chain[1].sym_name == "stdout" {
        return "stdout";
    }
    if chain[1].sym_name == "stderr" {
        return "stderr";
    }
    return None;
}

impl NaIRGenPass._emit_print_call(
    stream: str, fmt_ptr: ir.Value, args: list[ir.Value]
) -> None {
    if stream == "stdout" {
        self.builder.call(self._get_printf(), [fmt_ptr] + args);
        return;
    }
    i32 = ir.IntType(32);
    i8p = ir.IntType(8).as_pointer();
    handle = self._emit_stdio_handle(2, "print.stderr");
    fprintf = self._get_or_declare_extern("fprintf", i32, [i8p, i8p], var_arg=True);
    self.builder.call(fprintf, [handle, fmt_ptr] + args);
}

impl NaIRGenPass._get_fmt_string(fmt: str) -> ir.GlobalVariable {
    if fmt in self._fmt_strings {
        return self._fmt_strings[fmt];
    }
    fmt_bytes = bytearray((fmt + "\n\0").encode("utf8"));
    c_fmt = ir.Constant(ir.ArrayType(ir.IntType(8), len(fmt_bytes)), fmt_bytes);
    global_fmt = ir.GlobalVariable(
        self.llvm_module, c_fmt.type, name=f".fmt.{len(self._fmt_strings)}"
    );
    global_fmt.linkage = "private";
    global_fmt.global_constant = True;
    global_fmt.initializer = c_fmt;
    self._fmt_strings[fmt] = global_fmt;
    return global_fmt;
}

impl NaIRGenPass._get_snprintf_fmt(fmt: str) -> ir.GlobalVariable {
    cache_key = "snprintf:" + fmt;
    if cache_key in self._fmt_strings {
        return self._fmt_strings[cache_key];
    }
    fmt_bytes = bytearray((fmt + "\0").encode("utf8"));
    c_fmt = ir.Constant(ir.ArrayType(ir.IntType(8), len(fmt_bytes)), fmt_bytes);
    global_fmt = ir.GlobalVariable(
        self.llvm_module, c_fmt.type, name=f".sfmt.{len(self._fmt_strings)}"
    );
    global_fmt.linkage = "private";
    global_fmt.global_constant = True;
    global_fmt.initializer = c_fmt;
    self._fmt_strings[cache_key] = global_fmt;
    return global_fmt;
}

impl NaIRGenPass._codegen_multistring(nd: uni.MultiString) -> (ir.Value | None) {
    if not nd.strings {
        return None;
    }

    if len(nd.strings) == 1 {
        part = nd.strings[0];
        if isinstance(part, uni.FString) {
            return self._codegen_fstring(part);
        }
        return self._codegen_string(part);
    }

    result: (ir.Value | None) = None;
    for part in nd.strings {
        if isinstance(part, uni.FString) {
            val = self._codegen_fstring(part);
        } else {
            val = self._codegen_string(part);
        }
        if val is None {
            continue;
        }
        _ms_val: ir.Value = val;
        _ms_old = result;
        if _ms_old is None {
            result = _ms_val;
            continue;
        }
        _joined = self._emit_binary_op(Tok.PLUS, _ms_old, _ms_val);
        if _joined is None {
            return None;
        }
        result = _joined;
        if self._is_owned(_ms_old) {
            self._emit_rc_release_typed(_ms_old, op="mstr_old", loc="");
        }
        if self._is_owned(_ms_val) {
            self._emit_rc_release_typed(_ms_val, op="mstr_val", loc="");
        }
    }
    return result;
}

impl NaIRGenPass._static_str_struct_const(data: bytes) -> tuple[ir.Type, ir.Constant] {
    i64 = ir.IntType(64);
    i8 = ir.IntType(8);
    arr_type = ir.ArrayType(i8, len(data));
    struct_type = ir.LiteralStructType([i64, i64, arr_type]);
    sentinel_val = ir.Constant(i64, RC_SENTINEL);
    tagged_len = ir.Constant(
        i64, str_len_tag(len(data) - 1, all(b < 0x80 for b in data))
    );
    c_str = ir.Constant(arr_type, bytearray(data));
    return (struct_type, ir.Constant(struct_type, [sentinel_val, tagged_len, c_str]), );
}

impl NaIRGenPass._make_global_string(text: str, name_prefix: str = ".str") -> ir.Value {
    i32 = ir.IntType(32);
    _key = name_prefix + "\x00" + text;
    global_str = self._interned_strs.get(_key);
    if global_str is None {
        (struct_type, struct_val) = self._static_str_struct_const(
            (text + "\0").encode("utf8")
        );
        global_str = ir.GlobalVariable(
            self.llvm_module, struct_type, name=f"{name_prefix}.{self._str_count}"
        );
        self._str_count = self._str_count + 1;
        global_str.linkage = "private";
        global_str.global_constant = True;
        global_str.initializer = struct_val;
        self._interned_strs[_key] = global_str;
        self._str_literal_text[id(global_str)] = text;
    }

    gep = self.builder.gep(
        global_str,
        [ir.Constant(i32, 0), ir.Constant(i32, 2), ir.Constant(i32, 0)],
        name="str.data"
    );
    return gep;
}

impl NaIRGenPass._codegen_string(nd: uni.String) -> (ir.Value | None) {
    _lit = nd.lit_value;
    if isinstance(_lit, bytes) {
        return self._make_global_bytes(_lit);
    }
    return self._make_global_string(_lit);
}

impl NaIRGenPass._fstring_spec_text(spec: uni.Expr) -> (str | None) {
    return static_fstring_spec_text(spec);
}

impl NaIRGenPass._fstring_spec_to_printf(
    spec: str, kind: str
) -> (tuple[str, str] | None) {
    fill: (str | None) = None;
    align: (str | None) = None;
    i = 0;
    n = len(spec);
    if n >= 2 and spec[1] in "<>^=" {
        fill = spec[0];
        align = spec[1];
        i = 2;
    } elif n >= 1 and spec[0] in "<>^=" {
        align = spec[0];
        i = 1;
    }
    sign: (str | None) = None;
    if i < n and spec[i] in "+ " {
        sign = spec[i];
        i += 1;
    } elif i < n and spec[i] == "-" {
        i += 1;
    }
    if i < n and spec[i] == "#" {
        return None;
    }
    zero = False;
    if i < n and spec[i] == "0" {
        zero = True;
        i += 1;
    }
    width = "";
    while i < n and spec[i].isdigit() {
        width += spec[i];
        i += 1;
    }
    if i < n and spec[i] == "," {
        return None;
    }
    prec = "";
    if i < n and spec[i] == "." {
        i += 1;
        while i < n and spec[i].isdigit() {
            prec += spec[i];
            i += 1;
        }
        if not prec {
            return None;
        }
    }
    type_ch = "";
    if i < n {
        type_ch = spec[i];
        i += 1;
    }
    if i != n or align in ("^", "=") {
        return None;
    }
    if fill is not None and fill != " " {
        return None;
    }
    left = align == "<";
    if kind == "str" and align is None {
        left = True;
    }
    flags = "";
    if left {
        flags += "-";
    }
    if sign is not None {
        flags += sign;
    }
    if zero and not left {
        flags += "0";
    }
    body = flags + width + (("." + prec) if prec else "");
    if kind == "int" {
        if prec {
            return None;
        }
        if type_ch in ("", "d") {
            return ("%" + body + "lld", "int");
        }
        if type_ch == "x" {
            return ("%" + body + "llx", "int");
        }
        if type_ch == "X" {
            return ("%" + body + "llX", "int");
        }
        if type_ch == "o" {
            return ("%" + body + "llo", "int");
        }
        if type_ch in ("f", "F", "e", "E", "g", "G") {
            return ("%" + body + type_ch, "float");
        }
        return None;
    }
    if kind == "float" {
        if type_ch in ("f", "F", "e", "E", "g", "G") {
            return ("%" + body + type_ch, "float");
        }
        if type_ch == "" and not zero and sign is None and not prec {
            return ("%" + body + "s", "repr");
        }
        return None;
    }
    if kind == "str" and type_ch in ("", "s") and not zero and sign is None {
        return ("%" + body + "s", "str");
    }
    return None;
}

impl NaIRGenPass._fstring_str_fit(
    val: ir.Value, directive: str
) -> tuple[str, list[ir.Value]] {
    body = directive[1:-1];
    flags = "";
    while body and body[0] in "-+ 0#" {
        flags += body[0];
        body = body[1:];
    }
    (width_txt, _, prec_txt) = body.partition(".");
    if not width_txt and not prec_txt {
        return (directive, [val]);
    }
    b = self.builder;
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    blen = self._call_str_len(b, val, name="fs.blen");
    ascii = self._call_str_isascii(b, val, val, blen, name="fs.isa");
    shown_bytes = blen;
    shown_points = self._call_utf8_cplen(b, val, blen, ascii, name="fs.cplen");
    out = "%" + flags;
    fit_args: list[ir.Value] = [];
    prec_bytes: (ir.Value | None) = None;
    if prec_txt {
        prec = ir.Constant(i64, int(prec_txt));
        prec_bytes = self._call_utf8_cp_off(
            b, val, blen, prec, ascii, name="fs.pbytes"
        );
        shown_bytes = prec_bytes;
        shown_points = b.select(
            b.icmp_signed("<", prec, shown_points, name="fs.cut"),
            prec,
            shown_points,
            name="fs.points"
        );
    }
    if width_txt {
        out += "*";
        fit_args.append(
            b.trunc(
                b.add(
                    ir.Constant(i64, int(width_txt)),
                    b.sub(shown_bytes, shown_points, name="fs.extra"),
                    name="fs.wbytes"
                ),
                i32,
                name="fs.w32"
            )
        );
    }
    if prec_bytes is not None {
        out += ".*";
        fit_args.append(b.trunc(prec_bytes, i32, name="fs.p32"));
    }
    fit_args.append(val);
    return (out + "s", fit_args);
}

impl NaIRGenPass._emit_optional_str(
    val: ir.Value, part: (uni.UniNode | None), repr_mode: bool = False
) -> (ir.Value | None) {
    _pt = self._opt_payload_of(val.type);
    if _pt is None {
        return None;
    }
    i8p = ir.IntType(8).as_pointer();
    if not isinstance(_pt, ir.PointerType) {
        _scalar_s = self._emit_opt_repr(val);
        if _scalar_s is not None {
            return _scalar_s;
        }
        if not self?.jacval_type {
            return None;
        }
        _jv = self._coerce_type(val, self.jacval_type);
        _rfn = self._repr_jacval_fn();
        if _rfn is None {
            return None;
        }
        boxed_text = self.builder.call(_rfn, [_jv], name="opt.str.jv");
        self._mark_owned(boxed_text);
        return boxed_text;
    }
    _headerless = self._nogc_headerless();
    _none_s = self.builder.bitcast(
        self._make_global_string("None"), i8p, name="opt.str.none"
    );
    if _headerless {
        _none_s = self._call_str_dup(self.builder, _none_s, name="opt.str.none.dup");
    }
    _tag = self.builder.extract_value(val, 0, name="opt.str.tag");
    _set = self.builder.icmp_signed(
        "!=", _tag, ir.Constant(ir.IntType(8), 0), name="opt.str.set"
    );
    _func = self.builder.basic_block.function;
    _entry = self.builder.basic_block;
    _some_bb = _func.append_basic_block(name="opt.str.some");
    _merge_bb = _func.append_basic_block(name="opt.str.done");
    self.builder.cbranch(_set, _some_bb, _merge_bb);
    self.builder.position_at_start(_some_bb);
    _pv = self.builder.extract_value(val, 1, name="opt.str.pv");
    _s: ir.Value = _pv;
    if repr_mode or _pt != i8p {
        _built = self._emit_value_repr(_pv, part)
            if repr_mode
            else self._emit_obj_str(_pv);
        if _built is None and not repr_mode {
            _built = self._emit_container_repr(_pv, self._type_key_of(part));
        }
        if _built is None {
            return None;
        }
        _s = self._coerce_type(_built, i8p);
        if not self._is_owned(_built) {
            if _headerless {
                _s = self._call_str_dup(self.builder, _s, name="opt.str.own");
            } else {
                self._emit_rc_retain(_s, op="opt_str", loc="");
            }
        }
    } elif _headerless {
        _s = self._call_str_dup(self.builder, _pv, name="opt.str.own");
    } else {
        self._emit_rc_retain(_pv, op="opt_str", loc="");
    }
    _some_end = self.builder.basic_block;
    self.builder.branch(_merge_bb);
    self.builder.position_at_start(_merge_bb);
    _phi = self.builder.phi(i8p, name="opt.str");
    _phi.add_incoming(_none_s, _entry);
    _phi.add_incoming(_s, _some_end);
    self._mark_owned(_phi);
    return _phi;
}

impl NaIRGenPass._codegen_fstring(nd: uni.FString) -> (ir.Value | None) {
    fmt_parts: list[str] = [];
    args: list[ir.Value] = [];

    obj_strs: list[ir.Value] = [];
    for part in nd.parts {
        if isinstance(part, uni.String) {
            _lit = part.lit_value;
            text = _lit if isinstance(_lit, str) else _lit.decode("utf-8");
            text = text.replace("%", "%%");
            fmt_parts.append(text);
        } elif isinstance(part, uni.FormattedValue) {
            val = self._str_norm_optional(self._codegen_expr(part.format_part));
            if val is None {
                continue;
            }
            _conv = part.conversion if part.conversion is not None else -1;
            if self._opt_payload_of(val.type) is not None {
                _opt_s = self._emit_optional_str(
                    val, part.format_part, repr_mode=(_conv == 114)
                );
                if _opt_s is None {
                    self.emit(
                        E5092,
                        node_override=part,
                        kind="f-string value",
                        name="optional"
                    );
                    return None;
                }
                self._release_owned_args([val], op="fstr_opt_src");
                val = _opt_s;
                obj_strs.append(_opt_s);
                if _conv == 114 {
                    _conv = -1;
                }
            }
            if _conv == 114 {
                val = self._emit_value_repr(val, part.format_part);
                if val is None {
                    return None;
                }
                if self._is_owned(val) {
                    obj_strs.append(val);
                }
            } elif _conv not in (-1, 115) {
                self.emit(
                    E5092, node_override=part, kind="f-string conversion", name="!a"
                );
                return None;
            }
            _spec_txt: (str | None) = None;
            _spec_val: (ir.Value | None) = None;
            if part.format_spec is not None {
                _spec_txt = self._fstring_spec_text(part.format_spec);
                if _spec_txt is None {
                    if not isinstance(part.format_spec, uni.FString) {
                        self.emit(
                            E5092,
                            node_override=part,
                            kind="f-string format spec",
                            name="<dynamic spec>"
                        );
                        return None;
                    }
                    _spec_val = self._codegen_fstring(part.format_spec);
                    if _spec_val is None {
                        return None;
                    }
                }
            }
            if _spec_val is not None {
                _dyn = self._emit_dyn_spec_format(val, _spec_val, part);
                _dyn = self._str_norm_optional(_dyn);
                if _dyn is None {
                    return None;
                }
                if _conv != 114
                    and isinstance(val.type, ir.PointerType)
                    and self._is_owned(val) {
                    obj_strs.append(val);
                }
                obj_strs.append(_spec_val);
                obj_strs.append(_dyn);
                fmt_parts.append("%s");
                args.append(_dyn);
                continue;
            }
            _unsigned = self._is_unsigned_node(part.format_part);
            if _spec_txt {
                if isinstance(val.type, ir.IntType) {
                    val = self._int_text_arg(val, _unsigned);
                }
                _fs_kind: (str | None) = None;
                if isinstance(val.type, ir.IntType) {
                    _fs_kind = "int";
                } elif isinstance(val.type, ir.DoubleType) {
                    _fs_kind = "float";
                } elif isinstance(val.type, ir.PointerType) {
                    _fs_kind = "str";
                }
                _tr = self._fstring_spec_to_printf(_spec_txt, _fs_kind or "");
                if _tr is None {
                    _sg = self._make_global_string(_spec_txt, name_prefix=".fspec");
                    _sdyn = self._emit_dyn_spec_format(val, _sg, part);
                    _sdyn = self._str_norm_optional(_sdyn);
                    if _sdyn is None {
                        return None;
                    }
                    if _conv != 114
                        and isinstance(val.type, ir.PointerType)
                        and self._is_owned(val) {
                        obj_strs.append(val);
                    }
                    obj_strs.append(_sdyn);
                    fmt_parts.append("%s");
                    args.append(_sdyn);
                    continue;
                }
                (directive, want) = _tr;
                if _unsigned and directive.endswith("lld") {
                    directive = directive[:-1] + "u";
                }
                if want == "float" {
                    fmt_parts.append(directive);
                    args.append(self._coerce_type(val, ir.DoubleType()));
                } elif want == "repr" {
                    _spec_repr = self._emit_float_repr(val);
                    obj_strs.append(_spec_repr);
                    fmt_parts.append(directive);
                    args.append(_spec_repr);
                } elif want == "str" {
                    if val.type != ir.IntType(8).as_pointer() {
                        obj_s = self._emit_obj_str(val);
                        if obj_s is None {
                            obj_s = self._emit_container_repr(
                                val, self._type_key_of(part.format_part)
                            );
                        }
                        if obj_s is not None {
                            if self._is_owned(val) {
                                self._emit_rc_release_typed(
                                    val, op="fstr_obj_src", loc=""
                                );
                            }
                            val = obj_s;
                            obj_strs.append(obj_s);
                        } else {
                            self.emit(
                                E5092,
                                node_override=part,
                                kind="f-string value",
                                name=type(part.format_part).__name__
                            );
                            return None;
                        }
                    }
                    (fit_directive, fit_args) = self._fstring_str_fit(val, directive);
                    fmt_parts.append(fit_directive);
                    args.extend(fit_args);
                } else {
                    fmt_parts.append(directive);
                    args.append(val);
                }
                continue;
            }
            if isinstance(val.type, ir.IntType) and val.type.width == 1 {
                fmt_parts.append("%s");
                args.append(self._bool_text(self.builder, val, "fstr.bool"));
            } elif isinstance(val.type, ir.IntType) {
                fmt_parts.append("%llu" if _unsigned else "%lld");
                args.append(self._int_text_arg(val, _unsigned));
            } elif isinstance(val.type, ir.DoubleType) {
                _float_repr = self._emit_float_repr(val);
                obj_strs.append(_float_repr);
                fmt_parts.append("%s");
                args.append(_float_repr);
            } elif isinstance(val.type, ir.PointerType) {
                obj_s = self._emit_obj_str(val);
                if obj_s is None {
                    obj_s = self._emit_container_repr(
                        val, self._type_key_of(part.format_part)
                    );
                }
                if obj_s is not None {
                    if self._is_owned(val) {
                        self._emit_rc_release_typed(val, op="fstr_obj_src", loc="");
                    }
                    val = obj_s;
                    obj_strs.append(obj_s);
                } elif val.type != ir.IntType(8).as_pointer() {
                    self.emit(
                        E5092,
                        node_override=part,
                        kind="f-string value",
                        name=type(part.format_part).__name__
                    );
                    return None;
                }
                fmt_parts.append("%s");
                args.append(val);
            } elif self?.jacval_type is not None and val.type == self.jacval_type {
                _jv_fn = self._str_jacval_fn();
                if _jv_fn is None {
                    self.emit(
                        E5092,
                        node_override=part,
                        kind="f-string value",
                        name=type(part.format_part).__name__
                    );
                    return None;
                }
                _jv_s = self._mark_owned(
                    self.builder.call(_jv_fn, [val], name="fstr.jv")
                );
                obj_strs.append(_jv_s);
                fmt_parts.append("%s");
                args.append(_jv_s);
            } elif isinstance(val.type, ir.LiteralStructType) {
                _tup_s = self._emit_container_repr(
                    val, self._type_key_of(part.format_part)
                );
                if _tup_s is None {
                    self.emit(
                        E5092,
                        node_override=part,
                        kind="f-string value",
                        name=type(part.format_part).__name__
                    );
                    return None;
                }
                obj_strs.append(_tup_s);
                fmt_parts.append("%s");
                args.append(_tup_s);
            }
        }
    }
    fmt_str = "".join(fmt_parts);

    _fstr_loc = f"{os.path.basename(self.module.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    if not self._nogc_headerless() {
        self._set_rc_ctx("fstring", _fstr_loc);
        _direct = self._fstring_direct(fmt_parts, args);
        self._clear_rc_ctx();
        if _direct is not None {
            for _obj_s in obj_strs {
                self._emit_rc_release_typed(_obj_s, op="fstr_obj_tmp", loc="");
            }
            self._mark_owned(_direct);
            return _direct;
        }
    }
    snprintf_fn = self._get_or_declare_extern(
        "snprintf",
        ir.IntType(32),
        [ir.IntType(8).as_pointer(), ir.IntType(64), ir.IntType(8).as_pointer()],
        var_arg=True
    );
    fmt_global = self._make_global_string(fmt_str, name_prefix=".fstr.fmt");

    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    measure_args: list[ir.Value] = [
        ir.Constant(i8p, None),
        ir.Constant(i64, 0),
        fmt_global
    ];
    for a in args {
        measure_args.append(a);
    }
    need32 = self.builder.call(snprintf_fn, measure_args, name="fstr.need");
    need = self.builder.sext(need32, i64, name="fstr.need64");
    buf_size = self.builder.add(need, ir.Constant(i64, 1), name="fstr.size");
    self._set_rc_ctx("fstring", _fstr_loc);
    buf = self._str_alloc(self.builder, buf_size, name="fstr.buf");
    self._clear_rc_ctx();
    call_args: list[ir.Value] = [buf, buf_size, fmt_global];
    for a in args {
        call_args.append(a);
    }
    self.builder.call(snprintf_fn, call_args, name="fstr.len");
    self._stamp_str_len(self.builder, buf, need);

    for _obj_s in obj_strs {
        self._emit_rc_release_typed(_obj_s, op="fstr_obj_tmp", loc="");
    }

    self._mark_owned(buf);
    return buf;
}

impl NaIRGenPass._codegen_string_index(
    target_val: ir.Value,
    index_val: ir.Value,
    len_val: (ir.Value | None) = None,
    root_val: (ir.Value | None) = None
) -> (ir.Value | None) {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    b = self.builder;
    if len_val is None {
        len_val = self._call_str_len(b, target_val, name="char.blen");
    }
    zero = ir.Constant(i64, 0);
    index_val = self._coerce_type(index_val, i64);
    len_val = self._coerce_type(len_val, i64);
    ascii = self._call_str_isascii(
        b,
        target_val if root_val is None else root_val,
        target_val,
        len_val,
        name="char.isa"
    );
    func = b.function;
    fast_bb = func.append_basic_block(name="char.fast");
    slow_bb = func.append_basic_block(name="char.slow");
    pos_bb = func.append_basic_block(name="char.pos");
    b.cbranch(ascii, fast_bb, slow_bb);
    b.position_at_end(slow_bb);
    _cursor_base = target_val if root_val is None else root_val;
    cplen = self._call_utf8_cplen(
        b,
        target_val,
        len_val,
        ir.Constant(ir.IntType(1), 0),
        name="char.cplen",
        base=_cursor_base
    );
    b.branch(pos_bb);
    b.position_at_end(fast_bb);
    b.branch(pos_bb);
    b.position_at_end(pos_bb);
    count = b.phi(i64, name="char.count");
    count.add_incoming(len_val, fast_bb);
    count.add_incoming(cplen, slow_bb);
    _neg = b.icmp_signed("<", index_val, zero, name="char.neg");
    index_val = b.select(
        _neg, b.add(index_val, count, name="char.wrap"), index_val, name="char.idx.norm"
    );
    _lo = b.icmp_signed("<", index_val, zero, name="char.oob.lo");
    _hi = b.icmp_signed(">=", index_val, count, name="char.oob.hi");
    _oob = b.or_(_lo, _hi, name="char.oob");
    self._emit_runtime_raise(_oob, "IndexError", "string index out of range");
    b = self.builder;
    func = b.function;
    off_slow_bb = func.append_basic_block(name="char.off.slow");
    off_bb = func.append_basic_block(name="char.off");
    entry_bb = b.block;
    b.cbranch(ascii, off_bb, off_slow_bb);
    b.position_at_end(off_slow_bb);
    slow_off = self._call_utf8_cp_off(
        b,
        target_val,
        len_val,
        index_val,
        ir.Constant(ir.IntType(1), 0),
        name="char.off.cp",
        base=_cursor_base
    );
    b.branch(off_bb);
    b.position_at_end(off_bb);
    off = b.phi(i64, name="char.off");
    off.add_incoming(index_val, entry_bb);
    off.add_incoming(slow_off, off_slow_bb);

    _ch_byte = b.load(b.gep(target_val, [off], name="char.ptr"), name="char.byte");
    _byte_idx = b.zext(_ch_byte, i64, name="char.idx");
    cached_bb = b.block;
    wide_bb = func.append_basic_block(name="char.wide");
    done_bb = func.append_basic_block(name="char.done");
    _cached_ptr = b.gep(
        self._get_char_cache_gv(),
        [ir.Constant(i32, 0), _byte_idx, ir.Constant(i32, 2), ir.Constant(i32, 0)],
        name="char.cached"
    );
    b.cbranch(
        self._emit_u8_lone_ascii(
            b, target_val, len_val, off, _byte_idx, name="char.isasc"
        ),
        done_bb,
        wide_bb
    );
    b.position_at_end(wide_bb);
    _wide = self._call_utf8_char_at(b, target_val, len_val, off, name="char.multi");
    b.branch(done_bb);
    b.position_at_end(done_bb);
    _ch = b.phi(_cached_ptr.type, name="char.val");
    _ch.add_incoming(_cached_ptr, cached_bb);
    _ch.add_incoming(_wide, wide_bb);
    return _ch;
}

impl NaIRGenPass._emit_norm_slice_bounds(
    slice_node: object, src_len: ir.Value
) -> (tuple[ir.Value, ir.Value, ir.Value, ir.Value] | None) {
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);
    b = self.builder;

    step_val: ir.Value = one;
    if slice_node?.step is not None {
        sv = self._codegen_expr(slice_node.step);
        if sv is None {
            return None;
        }
        step_val = self._coerce_type(sv, i64);
        _step_zero = b.icmp_signed("==", step_val, zero, name="nsl.step.zero");
        self._emit_runtime_raise(_step_zero, "ValueError", "slice step cannot be zero");
    }
    step_pos = b.icmp_signed(">", step_val, zero, name="nsl.step.pos");
    len_m1 = b.sub(src_len, one, name="nsl.lenm1");
    neg_one = ir.Constant(i64, -1);

    lo = b.select(step_pos, zero, neg_one, name="nsl.lo");
    hi = b.select(step_pos, src_len, len_m1, name="nsl.hi");

    start_val = b.select(step_pos, zero, len_m1, name="nsl.start.dflt");
    if slice_node?.start is not None {
        sv2 = self._codegen_expr(slice_node.start);
        if sv2 is None {
            return None;
        }
        v = self._coerce_type(sv2, i64);
        _neg = b.icmp_signed("<", v, zero, name="nsl.s.neg");
        v = b.select(_neg, b.add(v, src_len, name="nsl.s.wrap"), v, name="nsl.s.w");
        _lo = b.icmp_signed("<", v, lo, name="nsl.s.lo");
        v = b.select(_lo, lo, v, name="nsl.s.cl");
        _hi = b.icmp_signed(">", v, hi, name="nsl.s.hi");
        start_val = b.select(_hi, hi, v, name="nsl.s.ch");
    }

    stop_val = b.select(step_pos, src_len, neg_one, name="nsl.stop.dflt");
    if slice_node?.stop is not None {
        sv3 = self._codegen_expr(slice_node.stop);
        if sv3 is None {
            return None;
        }
        v2 = self._coerce_type(sv3, i64);
        _neg2 = b.icmp_signed("<", v2, zero, name="nsl.e.neg");
        v2 = b.select(_neg2, b.add(v2, src_len, name="nsl.e.wrap"), v2, name="nsl.e.w");
        _lo2 = b.icmp_signed("<", v2, lo, name="nsl.e.lo");
        v2 = b.select(_lo2, lo, v2, name="nsl.e.cl");
        _hi2 = b.icmp_signed(">", v2, hi, name="nsl.e.hi");
        stop_val = b.select(_hi2, hi, v2, name="nsl.e.ch");
    }
    return (start_val, stop_val, step_val, step_pos);
}

impl NaIRGenPass._codegen_list_slice(
    target_val: ir.Value, slice_node: object, elem_type_name: str
) -> (ir.Value | None) {
    helpers = self.list_helpers.get(elem_type_name);
    if helpers is None {
        return None;
    }
    i64 = ir.IntType(64);
    func = self.builder.basic_block.function;

    src_len = self.builder.call(helpers["len"], [target_val], name="sl.srclen");
    bounds = self._emit_norm_slice_bounds(slice_node, src_len);
    if bounds is None {
        return None;
    }
    (start_val, stop_val, step_val, step_pos) = bounds;

    new_list = self.builder.call(helpers["new"], [], name="sl.new");

    i_alloca = self._stack_entry_alloca(i64, "sl.i");
    self.builder.store(start_val, i_alloca);
    loop_check = func.append_basic_block(name="sl.check");
    loop_body = func.append_basic_block(name="sl.body");
    loop_done = func.append_basic_block(name="sl.done");
    self.builder.branch(loop_check);

    self.builder.position_at_end(loop_check);
    cur_i = self.builder.load(i_alloca, name="sl.cur");
    fwd = self.builder.icmp_signed("<", cur_i, stop_val, name="sl.fwd");
    bwd = self.builder.icmp_signed(">", cur_i, stop_val, name="sl.bwd");
    in_range = self.builder.select(step_pos, fwd, bwd, name="sl.inrange");
    self.builder.cbranch(in_range, loop_body, loop_done);

    self.builder.position_at_end(loop_body);
    elem: ir.Value = self.builder.call(
        helpers["get"], [target_val, cur_i], name="sl.elem"
    );
    if self._nogc_headerless() and elem_type_name == "ptr" {
        elem = self._rc_strdup(elem, name="sl.elem.copy");
    }
    self._rc_call_with_ctx(helpers["append"], [new_list, elem], op="list_slice");

    next_i = self.builder.add(cur_i, step_val, name="sl.next");
    self.builder.store(next_i, i_alloca);
    self.builder.branch(loop_check);

    self.builder.position_at_end(loop_done);

    return self._mark_owned(new_list);
}

impl NaIRGenPass._codegen_string_slice(
    target_val: ir.Value, slice_node: object, base_node: object = None
) -> (ir.Value | None) {
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);
    func = self.builder.function;

    _hl = self._nogc_headerless();
    _desc_in = self._str_desc_ty is not None and target_val.type == self._str_desc_ty;
    if _desc_in {
        _root = self.builder.extract_value(target_val, 0, name="ss.root");
        _data = self.builder.extract_value(target_val, 0 if _hl else 1, name="ss.data");
        src_blen = self.builder.extract_value(
            target_val, 1 if _hl else 2, name="ss.srclen"
        );
    } else {
        _root = target_val;
        _data = target_val;
        src_blen = self._call_str_len(self.builder, target_val, name="ss.len");
    }
    src_blen = self._coerce_type(src_blen, i64);
    _ascii = self._call_str_isascii(
        self.builder, _root, _data, src_blen, name="ss.isa"
    );
    src_len = self._call_utf8_cplen(
        self.builder, _data, src_blen, _ascii, name="ss.cplen", base=_root
    );
    bounds = self._emit_norm_slice_bounds(slice_node, src_len);
    if bounds is None {
        return None;
    }
    (start_val, stop_val, step_val, step_pos) = bounds;

    _sl_ast = slice_node;
    if isinstance(_sl_ast, uni.IndexSlice) and len(_sl_ast.slices) == 1 {
        _sl_ast = _sl_ast.slices[0];
    }
    _static_step1 = isinstance(_sl_ast, uni.Slice) and _sl_ast.step is None;
    _view_ok = _static_step1
        and self._str_desc_ty is not None
        and (
            self._gc_mode() != "none"
            or (_hl and self._hl_view_base_licensed(base_node))
        );
    if _view_ok {
        _bstart = self._call_utf8_cp_off(
            self.builder,
            _data,
            src_blen,
            start_val,
            _ascii,
            name="s.view.bstart",
            base=_root
        );
        _bstop = self._call_utf8_cp_off(
            self.builder,
            _data,
            src_blen,
            stop_val,
            _ascii,
            name="s.view.bstop",
            base=_root
        );
        _v_raw = self.builder.sub(_bstop, _bstart, name="s.view.raw");
        _v_len = self.builder.select(
            self.builder.icmp_signed("<", _v_raw, zero, name="s.view.neg"),
            zero,
            _v_raw,
            name="s.view.len"
        );
        _v_data = self.builder.gep(_data, [_bstart], name="s.view.data");
        _i32v = ir.IntType(32);
        _zv = ir.Constant(_i32v, 0);
        _v_slot = self._entry_alloca(self._str_desc_type(), "s.view.slot");
        if _hl {
            self.builder.store(
                _v_data,
                self.builder.gep(
                    _v_slot, [_zv, ir.Constant(_i32v, 0)], name="s.view.dslot"
                )
            );
            self.builder.store(
                _v_len,
                self.builder.gep(
                    _v_slot, [_zv, ir.Constant(_i32v, 1)], name="s.view.lslot"
                )
            );
        } else {
            self._emit_rc_retain(_root, op="str_view", loc="");
            self.builder.store(
                _root,
                self.builder.gep(
                    _v_slot, [_zv, ir.Constant(_i32v, 0)], name="s.view.root"
                )
            );
            self.builder.store(
                _v_data,
                self.builder.gep(
                    _v_slot, [_zv, ir.Constant(_i32v, 1)], name="s.view.dslot"
                )
            );
            self.builder.store(
                _v_len,
                self.builder.gep(
                    _v_slot, [_zv, ir.Constant(_i32v, 2)], name="s.view.lslot"
                )
            );
        }
        _view = self.builder.load(_v_slot, name="s.view");
        if not _hl {
            self._mark_owned(_view);
        }
        return _view;
    }

    b = self.builder;
    diff = b.select(
        step_pos,
        b.sub(stop_val, start_val, name="ss.d.fwd"),
        b.sub(start_val, stop_val, name="ss.d.bwd"),
        name="ss.diff"
    );
    astep = b.select(
        step_pos, step_val, b.sub(zero, step_val, name="ss.step.neg"), name="ss.astep"
    );
    n_raw = b.add(
        b.sdiv(b.sub(diff, one, name="ss.dm1"), astep, name="ss.nq"),
        one,
        name="ss.nraw"
    );
    n_val = b.select(
        b.icmp_signed(">", diff, zero, name="ss.dpos"), n_raw, zero, name="ss.n"
    );
    bstart = b.select(
        b.icmp_signed("<", start_val, zero, name="ss.bs.neg"),
        ir.Constant(i64, -1),
        self._call_utf8_cp_off(
            b, _data, src_blen, start_val, _ascii, name="ss.bstart", base=_root
        ),
        name="ss.bstart.c"
    );
    bstop = b.select(
        b.icmp_signed("<", stop_val, zero, name="ss.be.neg"),
        ir.Constant(i64, -1),
        self._call_utf8_cp_off(
            b, _data, src_blen, stop_val, _ascii, name="ss.bstop", base=_root
        ),
        name="ss.bstop.c"
    );
    i8p = ir.IntType(8).as_pointer();
    entry_bb = b.block;
    size_bb = func.append_basic_block(name="ss.size");
    alloc_bb = func.append_basic_block(name="ss.alloc");
    b.cbranch(_ascii, alloc_bb, size_bb);
    b.position_at_end(size_bb);
    wide_size = self._call_utf8_gather(
        b,
        _data,
        src_blen,
        bstart,
        bstop,
        step_val,
        _ascii,
        ir.Constant(i8p, None),
        ir.Constant(i64, 0x7FFFFFFFFFFFFFFF),
        name="ss.wide.size"
    );
    b.branch(alloc_bb);
    b.position_at_end(alloc_bb);
    out_cap = b.phi(i64, name="ss.cap");
    out_cap.add_incoming(n_val, entry_bb);
    out_cap.add_incoming(wide_size, size_bb);
    self._set_rc_ctx("str_substr", "");
    new_str = self._str_alloc(b, b.add(out_cap, one, name="ss.alloc.n"), name="ss.new");
    self._clear_rc_ctx();
    out_len = self._call_utf8_gather(
        b,
        _data,
        src_blen,
        bstart,
        bstop,
        step_val,
        _ascii,
        new_str,
        out_cap,
        name="ss.copied"
    );
    self._str_finish(b, new_str, out_len);
    self._mark_owned(new_str);
    return new_str;
}

impl NaIRGenPass._hl_view_base_licensed(base_node: object) -> bool {
    _x = base_node;
    while isinstance(_x, uni.AtomTrailer) {
        _x = _x.target;
    }
    if not isinstance(_x, uni.Name) or _x.sym is None {
        return False;
    }
    return (
        _x.sym_name == "self"
        or _x.sym.ownership
            in (
                OwnershipKind.OWN,
                OwnershipKind.BORROW,
                OwnershipKind.MUT_BORROW,
                OwnershipKind.IMM
            )
    );
}

impl NaIRGenPass._emit_is_strip_char(
    ch: ir.Value, charset: (ir.Value | None)
) -> ir.Value {
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    if charset is None {
        is_space = self.builder.icmp_signed(
            "==", ch, ir.Constant(i8, 32), name="is.space"
        );
        is_tab = self.builder.icmp_signed("==", ch, ir.Constant(i8, 9), name="is.tab");
        is_nl = self.builder.icmp_signed("==", ch, ir.Constant(i8, 10), name="is.nl");
        is_cr = self.builder.icmp_signed("==", ch, ir.Constant(i8, 13), name="is.cr");
        is_ws = self.builder.or_(is_space, is_tab, name="ws1");
        is_ws = self.builder.or_(is_ws, is_nl, name="ws2");
        return self.builder.or_(is_ws, is_cr, name="ws3");
    }
    i8p = i8.as_pointer();
    strchr_fn = self._get_or_declare_extern("strchr", i8p, [i8p, i32]);
    ch_i32 = self.builder.zext(ch, i32, name="strip.ch.i32");
    found = self.builder.call(strchr_fn, [charset, ch_i32], name="strip.find");
    return self.builder.icmp_unsigned(
        "!=", found, ir.Constant(i8p, None), name="strip.in"
    );
}

impl NaIRGenPass._codegen_str_strip_chars(
    str_val: ir.Value, charset: (ir.Value | None), do_left: bool, do_right: bool
) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    func = self.builder.function;
    slen = self._call_str_len(self.builder, str_val, name="strip.len");
    if charset is not None {
        return self._codegen_str_strip_units(str_val, slen, charset, do_left, do_right);
    }

    final_start: ir.Value = ir.Constant(i64, 0);
    if do_left {
        start_alloca = self._stack_entry_alloca(i64, "strip.start");
        self.builder.store(ir.Constant(i64, 0), start_alloca);
        start_check_bb = func.append_basic_block(name="strip.start.check");
        start_body_bb = func.append_basic_block(name="strip.start.body");
        start_inc_bb = func.append_basic_block(name="strip.start.inc");
        start_done_bb = func.append_basic_block(name="strip.start.done");
        self.builder.branch(start_check_bb);
        self.builder.position_at_end(start_check_bb);
        start_val = self.builder.load(start_alloca, name="start.cur");
        in_range = self.builder.icmp_signed("<", start_val, slen, name="start.inrange");
        self.builder.cbranch(in_range, start_body_bb, start_done_bb);
        self.builder.position_at_end(start_body_bb);
        ch_ptr = self.builder.gep(str_val, [start_val], name="start.ch.ptr");
        ch = self.builder.load(ch_ptr, name="start.ch");
        is_strip = self._emit_is_strip_char(ch, charset);
        self.builder.cbranch(is_strip, start_inc_bb, start_done_bb);
        self.builder.position_at_end(start_inc_bb);
        next_start = self.builder.add(
            start_val, ir.Constant(i64, 1), name="next.start"
        );
        self.builder.store(next_start, start_alloca);
        self.builder.branch(start_check_bb);
        self.builder.position_at_end(start_done_bb);
        final_start = self.builder.load(start_alloca, name="final.start");
    }

    final_end = slen;
    if do_right {
        end_alloca = self._stack_entry_alloca(i64, "strip.end");
        self.builder.store(slen, end_alloca);
        end_check_bb = func.append_basic_block(name="strip.end.check");
        end_body_bb = func.append_basic_block(name="strip.end.body");
        end_dec_bb = func.append_basic_block(name="strip.end.dec");
        end_done_bb = func.append_basic_block(name="strip.end.done");
        self.builder.branch(end_check_bb);
        self.builder.position_at_end(end_check_bb);
        end_val = self.builder.load(end_alloca, name="end.cur");
        end_gt_start = self.builder.icmp_signed(
            ">", end_val, final_start, name="end.gt.start"
        );
        self.builder.cbranch(end_gt_start, end_body_bb, end_done_bb);
        self.builder.position_at_end(end_body_bb);
        prev_end = self.builder.sub(end_val, ir.Constant(i64, 1), name="prev.end");
        ech_ptr = self.builder.gep(str_val, [prev_end], name="end.ch.ptr");
        ech = self.builder.load(ech_ptr, name="end.ch");
        e_strip = self._emit_is_strip_char(ech, charset);
        self.builder.cbranch(e_strip, end_dec_bb, end_done_bb);
        self.builder.position_at_end(end_dec_bb);
        self.builder.store(prev_end, end_alloca);
        self.builder.branch(end_check_bb);
        self.builder.position_at_end(end_done_bb);
        final_end = self.builder.load(end_alloca, name="final.end");
    }

    result_len = self.builder.sub(final_end, final_start, name="result.len");
    alloc_size = self.builder.add(result_len, ir.Constant(i64, 1), name="alloc.size");
    self._set_rc_ctx("str_strip", "");
    result_ptr = self._str_alloc(self.builder, alloc_size, name="strip.result");
    self._clear_rc_ctx();

    src_ptr = self.builder.gep(str_val, [final_start], name="src.ptr");
    memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    self.builder.call(memcpy, [result_ptr, src_ptr, result_len]);

    self._str_finish(self.builder, result_ptr, result_len);
    return result_ptr;
}

impl NaIRGenPass._codegen_str_strip_units(
    str_val: ir.Value, slen: ir.Value, charset: ir.Value, do_left: bool, do_right: bool
) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    b = self.builder;
    func = b.function;
    set_len = self._call_str_len(b, charset, name="strip.set.len");
    final_start: ir.Value = ir.Constant(i64, 0);
    if do_left {
        head_bb = b.block;
        chk_bb = func.append_basic_block(name="strip.l.chk");
        body_bb = func.append_basic_block(name="strip.l.body");
        next_bb = func.append_basic_block(name="strip.l.next");
        done_bb = func.append_basic_block(name="strip.l.done");
        b.branch(chk_bb);
        b.position_at_end(chk_bb);
        cur = b.phi(i64, name="strip.l.cur");
        cur.add_incoming(ir.Constant(i64, 0), head_bb);
        b.cbranch(b.icmp_signed("<", cur, slen, name="strip.l.go"), body_bb, done_bb);
        b.position_at_end(body_bb);
        width = self._call_utf8_cp_len_at(b, str_val, slen, cur, name="strip.l.w");
        hit = self._call_utf8_unit_in(
            b,
            charset,
            set_len,
            b.gep(str_val, [cur], name="strip.l.unit"),
            width,
            name="strip.l.in"
        );
        b.cbranch(hit, next_bb, done_bb);
        b.position_at_end(next_bb);
        cur.add_incoming(b.add(cur, width, name="strip.l.adv"), next_bb);
        b.branch(chk_bb);
        b.position_at_end(done_bb);
        final_start = cur;
    }
    final_end: ir.Value = slen;
    if do_right {
        head_bb = b.block;
        chk_bb = func.append_basic_block(name="strip.r.chk");
        body_bb = func.append_basic_block(name="strip.r.body");
        next_bb = func.append_basic_block(name="strip.r.next");
        done_bb = func.append_basic_block(name="strip.r.done");
        b.branch(chk_bb);
        b.position_at_end(chk_bb);
        end = b.phi(i64, name="strip.r.end");
        end.add_incoming(slen, head_bb);
        b.cbranch(
            b.icmp_signed(">", end, final_start, name="strip.r.go"), body_bb, done_bb
        );
        b.position_at_end(body_bb);
        prev = self._call_utf8_prev(b, str_val, end, name="strip.r.prev");
        hit = self._call_utf8_unit_in(
            b,
            charset,
            set_len,
            b.gep(str_val, [prev], name="strip.r.unit"),
            b.sub(end, prev, name="strip.r.w"),
            name="strip.r.in"
        );
        b.cbranch(hit, next_bb, done_bb);
        b.position_at_end(next_bb);
        end.add_incoming(prev, next_bb);
        b.branch(chk_bb);
        b.position_at_end(done_bb);
        final_end = end;
    }
    result_len = b.sub(final_end, final_start, name="strip.u.len");
    self._set_rc_ctx("str_strip", "");
    result_ptr = self._str_alloc(
        b,
        b.add(result_len, ir.Constant(i64, 1), name="strip.u.size"),
        name="strip.u.result"
    );
    self._clear_rc_ctx();
    memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    b.call(
        memcpy,
        [result_ptr, b.gep(str_val, [final_start], name="strip.u.src"), result_len]
    );
    self._str_finish(b, result_ptr, result_len);
    return result_ptr;
}

impl NaIRGenPass._codegen_str_split(
    str_val: ir.Value,
    sep_val: ir.Value,
    maxsplit: ir.Value | None = None,
    reverse: bool = False
) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    func = self.builder.function;

    self._emit_list_helpers("ptr", i8p);
    helpers = self.list_helpers.get("ptr");
    if helpers is None {
        return None;
    }

    str_len = self._call_str_len(self.builder, str_val, name="str.len");
    sep_len = self._call_str_len(self.builder, sep_val, name="sep.len");
    self._emit_runtime_raise(
        self.builder.icmp_unsigned("==", sep_len, ir.Constant(i64, 0)),
        "ValueError",
        "empty separator"
    );
    limit = self._coerce_type(maxsplit, i64)
        if maxsplit is not None
        else ir.Constant(i64, -1);
    self._set_rc_ctx("str_split", "");
    new_list = self.builder.call(helpers["new"], [], name="split.list");
    self._clear_rc_ctx();
    self._nogc_stamp_elem_drops(new_list, ["str"]);

    memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    strncmp_fn = self._get_or_declare_extern("memcmp", ir.IntType(32), [i8p, i8p, i64]);

    i_alloca = self._entry_alloca(i64, "split.i");
    token_start_alloca = self._entry_alloca(i64, "split.token.start");
    remaining = self._entry_alloca(i64, "split.remaining");
    self.builder.store(limit, remaining);
    self.builder.store(
        self.builder.sub(str_len, sep_len) if reverse else ir.Constant(i64, 0), i_alloca
    );
    self.builder.store(str_len if reverse else ir.Constant(i64, 0), token_start_alloca);
    loop_check_bb = func.append_basic_block(name="split.check");
    loop_body_bb = func.append_basic_block(name="split.body");
    match_bb = func.append_basic_block(name="split.match");
    no_match_bb = func.append_basic_block(name="split.nomatch");
    loop_done_bb = func.append_basic_block(name="split.done");
    self.builder.branch(loop_check_bb);

    self.builder.position_at_end(loop_check_bb);
    cur_i = self.builder.load(i_alloca, name="cur.i");

    can_match = self.builder.icmp_signed(">=", cur_i, ir.Constant(i64, 0))
        if reverse
        else self.builder.icmp_signed("<=", cur_i, self.builder.sub(str_len, sep_len));
    can_match = self.builder.and_(
        can_match,
        self.builder.icmp_signed(
            "!=", self.builder.load(remaining), ir.Constant(i64, 0)
        )
    );
    self.builder.cbranch(can_match, loop_body_bb, loop_done_bb);

    self.builder.position_at_end(loop_body_bb);
    substr_ptr = self.builder.gep(str_val, [cur_i], name="substr.ptr");
    cmp_result = self.builder.call(
        strncmp_fn, [substr_ptr, sep_val, sep_len], name="cmp"
    );
    is_match = self.builder.icmp_signed(
        "==", cmp_result, ir.Constant(ir.IntType(32), 0), name="is.match"
    );
    self.builder.cbranch(is_match, match_bb, no_match_bb);

    self.builder.position_at_end(match_bb);
    ts = self.builder.load(token_start_alloca, name="token.start");
    token_source = self.builder.add(cur_i, sep_len) if reverse else ts;
    token_len = self.builder.sub(ts, token_source)
        if reverse
        else self.builder.sub(cur_i, ts, name="token.len");
    alloc_len = self.builder.add(token_len, ir.Constant(i64, 1), name="token.alloc");
    self._set_rc_ctx("str_split", "");
    token_ptr = self._str_alloc(self.builder, alloc_len, name="token.ptr");
    self._clear_rc_ctx();
    self._mark_owned(token_ptr);
    src = self.builder.gep(str_val, [token_source], name="token.src");
    self.builder.call(memcpy, [token_ptr, src, token_len]);
    self._str_finish(self.builder, token_ptr, token_len);
    self._rc_call_with_ctx(helpers["append"], [new_list, token_ptr], op="str_split");
    if isinstance(token_ptr.type, ir.PointerType) and self._is_owned(token_ptr) {
        self._emit_rc_release_simple(token_ptr, op="str_split");
    }
    new_i = self.builder.sub(cur_i, sep_len)
        if reverse
        else self.builder.add(cur_i, sep_len, name="new.i");
    self.builder.store(new_i, i_alloca);
    self.builder.store(cur_i if reverse else new_i, token_start_alloca);
    budget = self.builder.load(remaining);
    self.builder.store(
        self.builder.select(
            self.builder.icmp_signed(">", budget, ir.Constant(i64, 0)),
            self.builder.sub(budget, ir.Constant(i64, 1)),
            budget
        ),
        remaining
    );
    self.builder.branch(loop_check_bb);

    self.builder.position_at_end(no_match_bb);
    next_i = self.builder.add(
        cur_i, ir.Constant(i64, -1 if reverse else 1), name="next.i"
    );
    self.builder.store(next_i, i_alloca);
    self.builder.branch(loop_check_bb);

    self.builder.position_at_end(loop_done_bb);
    final_ts = self.builder.load(token_start_alloca, name="final.ts");
    last_len = final_ts
        if reverse
        else self.builder.sub(str_len, final_ts, name="last.len");
    last_alloc = self.builder.add(last_len, ir.Constant(i64, 1), name="last.alloc");
    self._set_rc_ctx("str_split", "");
    last_ptr = self._str_alloc(self.builder, last_alloc, name="last.ptr");
    self._clear_rc_ctx();
    self._mark_owned(last_ptr);
    last_src = self.builder.gep(
        str_val, [ir.Constant(i64, 0) if reverse else final_ts], name="last.src"
    );
    self.builder.call(memcpy, [last_ptr, last_src, last_len]);
    self._str_finish(self.builder, last_ptr, last_len);
    self._rc_call_with_ctx(helpers["append"], [new_list, last_ptr], op="str_split");
    if isinstance(last_ptr.type, ir.PointerType) and self._is_owned(last_ptr) {
        self._emit_rc_release_simple(last_ptr, op="str_split");
    }
    if reverse {
        i32 = ir.IntType(32);
        zero = ir.Constant(i32, 0);
        data = self.builder.load(
            self.builder.gep(new_list, [zero, ir.Constant(i32, 2)])
        );
        length = self.builder.load(self.builder.gep(new_list, [zero, zero]));
        cursor = self._entry_alloca(i64, "split.reverse.index");
        self.builder.store(ir.Constant(i64, 0), cursor);
        check = func.append_basic_block("split.reverse.check");
        swap = func.append_basic_block("split.reverse.swap");
        done = func.append_basic_block("split.reverse.done");
        self.builder.branch(check);
        self.builder.position_at_end(check);
        left = self.builder.load(cursor);
        right = self.builder.sub(self.builder.sub(length, ir.Constant(i64, 1)), left);
        self.builder.cbranch(self.builder.icmp_signed("<", left, right), swap, done);
        self.builder.position_at_end(swap);
        left_ptr = self.builder.gep(data, [left]);
        right_ptr = self.builder.gep(data, [right]);
        left_value = self.builder.load(left_ptr);
        right_value = self.builder.load(right_ptr);
        self.builder.store(right_value, left_ptr);
        self.builder.store(left_value, right_ptr);
        self.builder.store(self.builder.add(left, ir.Constant(i64, 1)), cursor);
        self.builder.branch(check);
        self.builder.position_at_end(done);
    }
    return new_list;
}

impl NaIRGenPass._emit_sys_argv -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    func = self.builder.function;

    self._emit_list_helpers("ptr", i8p);
    helpers = self.list_helpers.get("ptr");
    if helpers is None {
        return None;
    }

    if "__jac_argc" not in self.llvm_module.globals {
        _argc_gv = ir.GlobalVariable(self.llvm_module, i32, name="__jac_argc");
        _argc_gv.initializer = ir.Constant(i32, 0);
        _argc_gv.linkage = "weak";
    }
    if "__jac_argv" not in self.llvm_module.globals {
        _argv_gv = ir.GlobalVariable(
            self.llvm_module, i8p.as_pointer(), name="__jac_argv"
        );
        _argv_gv.initializer = ir.Constant(i8p.as_pointer(), None);
        _argv_gv.linkage = "weak";
    }

    argc_global = self.llvm_module.get_global("__jac_argc");
    argv_global = self.llvm_module.get_global("__jac_argv");

    argc_i32 = self.builder.load(argc_global, name="argc.i32");
    argc = self.builder.sext(argc_i32, i64, name="argc");
    argv = self.builder.load(argv_global, name="argv");

    new_list = self.builder.call(helpers["new"], [], name="sys.argv.list");

    memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);

    i_alloca = self._stack_entry_alloca(i64, "argv.i");
    self.builder.store(ir.Constant(i64, 0), i_alloca);

    loop_check = func.append_basic_block(name="argv.check");
    loop_body = func.append_basic_block(name="argv.body");
    loop_done = func.append_basic_block(name="argv.done");

    self.builder.branch(loop_check);

    self.builder.position_at_end(loop_check);
    cur_i = self.builder.load(i_alloca, name="cur.i");
    in_range = self.builder.icmp_signed("<", cur_i, argc, name="argv.inrange");
    self.builder.cbranch(in_range, loop_body, loop_done);

    self.builder.position_at_end(loop_body);

    arg_ptr_ptr = self.builder.gep(argv, [cur_i], name="argv.ptr.ptr");
    arg_ptr = self.builder.load(arg_ptr_ptr, name="argv.ptr");

    slen = self._call_str_len_raw(self.builder, arg_ptr, name="arg.len");
    alloc_size = self.builder.add(slen, ir.Constant(i64, 1), name="arg.alloc");
    self._set_rc_ctx("argv", "");
    rc_str = self._str_alloc(self.builder, alloc_size, name="arg.str");
    self._clear_rc_ctx();
    self.builder.call(memcpy_fn, [rc_str, arg_ptr, slen]);
    self._str_finish(self.builder, rc_str, slen);

    self._rc_call_with_ctx(helpers["append"], [new_list, rc_str], op="argv");

    next_i = self.builder.add(cur_i, ir.Constant(i64, 1), name="argv.next");
    self.builder.store(next_i, i_alloca);
    self.builder.branch(loop_check);

    self.builder.position_at_end(loop_done);
    return new_list;
}

impl NaIRGenPass._emit_sys_stream(stream: str) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    file_st = self._get_file_struct_type();
    self._emit_file_helpers();

    sing_key = f".sys.{stream}";
    if sing_key not in self.llvm_module.globals {
        hdr_ty = ir.LiteralStructType([i64, i64, file_st]);
        _sing_new = ir.GlobalVariable(self.llvm_module, hdr_ty, name=sing_key);
        _sing_new.linkage = "private";
        _sing_new.initializer = ir.Constant(
            hdr_ty,
            [
                ir.Constant(i64, RC_SENTINEL),
                ir.Constant(i64, 0),
                ir.Constant(
                    file_st,
                    [
                        ir.Constant(i8p, None),
                        ir.Constant(i8p, None),
                        ir.Constant(i8p, None),
                        ir.Constant(i1, 0)
                    ]
                )
            ]
        );
    }

    sing = self.llvm_module.get_global(sing_key);

    z32 = ir.Constant(i32, 0);
    file_ptr = self.builder.gep(
        sing, [z32, ir.Constant(i32, 2)], name=f"sys.{stream}.obj"
    );
    handle = self._emit_stdio_handle(
        1 if stream == "stdout" else 2, f"sys.{stream}.handle"
    );
    self.builder.store(
        handle, self.builder.gep(file_ptr, [z32, z32], name=f"sys.{stream}.hp")
    );
    self.builder.store(
        self._make_global_string(f"<{stream}>"),
        self.builder.gep(file_ptr, [z32, ir.Constant(i32, 1)], name=f"sys.{stream}.pp")
    );
    self.builder.store(
        self._make_global_string("w"),
        self.builder.gep(file_ptr, [z32, ir.Constant(i32, 2)], name=f"sys.{stream}.mp")
    );
    self.builder.store(
        ir.Constant(i1, 0),
        self.builder.gep(file_ptr, [z32, ir.Constant(i32, 3)], name=f"sys.{stream}.cp")
    );
    return file_ptr;
}

impl NaIRGenPass._emit_sys_exit(args: list[ir.Value]) -> (ir.Value | None) {
    i32 = ir.IntType(32);
    exit_fn = self._get_or_declare_extern("exit", ir.VoidType(), [i32]);

    if args {
        code = args[0];
        if isinstance(code.type, ir.IntType) and code.type.width > 32 {
            code = self.builder.trunc(code, i32, name="exit.code");
        } else {
            code = self._coerce_type(code, i32);
        }
    } else {
        code = ir.Constant(i32, 0);
    }
    self.builder.call(exit_fn, [code]);
    self.builder.unreachable();
    return ir.Constant(ir.IntType(64), 0);
}

impl NaIRGenPass._bool_text(b: ir.IRBuilder, flag: ir.Value, name: str) -> ir.Value {
    return b.select(
        flag,
        self._make_global_string("True", name_prefix=".repr.true"),
        self._make_global_string("False", name_prefix=".repr.false"),
        name=name
    );
}

impl NaIRGenPass._get_fmt_int_fn -> ir.Function {
    """`__jac_fmt_i64(v, out, unsigned) -> len`: `v` in decimal at `out` (24 bytes), no NUL.

    `str(int)`, an int's repr and f-strings went through musl's `vsnprintf`,
    whose format parsing, padding and per-call `FILE` setup (a `memset`) cost
    far more than the digits. The digits go backwards into a stack buffer by
    division by 10, a sign in front, and are copied to `out`. The magnitude
    is taken unsigned, so the most negative value prints right.
    """;
    if self._fmt_int_fn is not None {
        return self._fmt_int_fn;
    }
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    fn = ir.Function(
        self.llvm_module, ir.FunctionType(i64, [i64, i8p, i1]), name="__jac_fmt_i64"
    );
    fn.linkage = "private";
    (v, out, unsigned) = (fn.args[0], fn.args[1], fn.args[2]);
    v.name = "v";
    out.name = "out";
    unsigned.name = "unsigned";
    head_bb = fn.append_basic_block("entry");
    loop = fn.append_basic_block("digits");
    sign = fn.append_basic_block("sign");
    copy = fn.append_basic_block("copy");
    b = ir.IRBuilder(head_bb);
    tmp = b.alloca(ir.ArrayType(i8, 24), name="fi.tmp");
    base = b.gep(tmp, [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)]);
    neg = b.and_(
        b.not_(unsigned, name="fi.signed"),
        b.icmp_signed("<", v, ir.Constant(i64, 0), name="fi.lt0"),
        name="fi.neg"
    );
    mag0 = b.select(
        neg, b.sub(ir.Constant(i64, 0), v, name="fi.negv"), v, name="fi.mag"
    );
    b.branch(loop);
    b = ir.IRBuilder(loop);
    mag = b.phi(i64, name="fi.m");
    pos = b.phi(i64, name="fi.pos");
    mag.add_incoming(mag0, head_bb);
    pos.add_incoming(ir.Constant(i64, 24), head_bb);
    q = b.udiv(mag, ir.Constant(i64, 10), name="fi.q");
    digit = b.sub(mag, b.mul(q, ir.Constant(i64, 10)), name="fi.d");
    npos = b.sub(pos, ir.Constant(i64, 1), name="fi.npos");
    b.store(
        b.trunc(b.add(digit, ir.Constant(i64, 48)), i8, name="fi.ch"),
        b.gep(base, [npos])
    );
    mag.add_incoming(q, loop);
    pos.add_incoming(npos, loop);
    b.cbranch(
        b.icmp_unsigned("!=", q, ir.Constant(i64, 0), name="fi.more"), loop, sign
    );
    b = ir.IRBuilder(sign);
    spos = b.sub(npos, ir.Constant(i64, 1), name="fi.spos");
    signed_bb = fn.append_basic_block("minus");
    b.cbranch(neg, signed_bb, copy);
    b = ir.IRBuilder(signed_bb);
    b.store(ir.Constant(i8, 45), b.gep(base, [spos]));
    b.branch(copy);
    b = ir.IRBuilder(copy);
    start = b.phi(i64, name="fi.start");
    start.add_incoming(npos, sign);
    start.add_incoming(spos, signed_bb);
    length = b.sub(ir.Constant(i64, 24), start, name="fi.len");
    memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    b.call(memcpy, [out, b.gep(base, [start]), length]);
    b.ret(length);
    self._fmt_int_fn = fn;
    return fn;
}

impl NaIRGenPass._emit_fmt_int(
    b: ir.IRBuilder, val: ir.Value, out: ir.Value, unsigned: bool
) -> ir.Value {
    i64 = ir.IntType(64);
    if val.type != i64 {
        val = b.zext(val, i64)
            if unsigned or val.type == ir.IntType(1)
            else b.sext(val, i64);
    }
    return b.call(
        self._get_fmt_int_fn(),
        [val, out, ir.Constant(ir.IntType(1), 1 if unsigned else 0)],
        name="fi.len"
    );
}

impl NaIRGenPass._fstring_direct(
    fmt_parts: list[str], args: list[ir.Value]
) -> (ir.Value | None) {
    """An f-string of plain `{str}` and `{int}` pieces, assembled without `snprintf`.

    The f-string ran `snprintf` twice, once to measure and once to write. When
    every piece is literal text, a string (`%s`) or an int (`%lld`/`%llu`)
    with no width, precision or fill, the ints are formatted into stack
    buffers, the strings measured, and the pieces copied into one buffer of
    the exact size. Any other directive keeps `snprintf` (returns None).
    """;
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    pieces: list[tuple[str, any, bool]] = [];
    k = 0;
    for part in fmt_parts {
        if part in ("%s", "%lld", "%llu") {
            if k >= len(args) {
                return None;
            }
            pieces.append((part, args[k], part == "%llu"));
            k += 1;
            continue;
        }
        if "%" in part.replace("%%", "") {
            return None;
        }
        if part {
            pieces.append(("lit", part.replace("%%", "%"), False));
        }
    }
    if k != len(args) {
        return None;
    }
    b = self.builder;
    strlen = self._get_or_declare_extern("strlen", i64, [i8p]);
    memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    null_text: (ir.Value | None) = None;
    sources: list[tuple[ir.Value, ir.Value]] = [];
    total: ir.Value = ir.Constant(i64, 0);
    for (kind, value, unsigned) in pieces {
        src: ir.Value;
        n: ir.Value;
        if kind == "lit" {
            src = self._make_global_string(value, name_prefix=".fstr.lit");
            n = ir.Constant(i64, len(value.encode("utf8")));
        } elif kind == "%s" {
            if null_text is None {
                null_text = self._make_global_string(
                    "(null)", name_prefix=".fstr.null"
                );
            }
            text = b.bitcast(value, i8p) if value.type != i8p else value;
            src = b.select(
                b.icmp_unsigned("==", text, ir.Constant(i8p, None), name="fd.null"),
                null_text,
                text,
                name="fd.str"
            );
            n = b.call(strlen, [src], name="fd.slen");
        } else {
            digits = self._entry_alloca(ir.ArrayType(i8, 24), "fd.digits");
            src = b.bitcast(digits, i8p, name="fd.dp");
            n = self._emit_fmt_int(b, value, src, unsigned);
        }
        sources.append((src, n));
        total = b.add(total, n, name="fd.total");
    }
    buf = self._str_alloc(
        b, b.add(total, ir.Constant(i64, 1), name="fd.size"), name="fstr.buf"
    );
    at: ir.Value = ir.Constant(i64, 0);
    for (src, n) in sources {
        b.call(memcpy, [b.gep(buf, [at], name="fd.at"), src, n]);
        at = b.add(at, n, name="fd.next");
    }
    self._str_finish(b, buf, total);
    return buf;
}

impl NaIRGenPass._int_text_arg(val: ir.Value, unsigned: bool) -> ir.Value {
    i64 = ir.IntType(64);
    if val.type == i64 {
        return val;
    }
    if unsigned or val.type == ir.IntType(1) {
        return self.builder.zext(val, i64, name="text.int");
    }
    return self.builder.sext(val, i64, name="text.int");
}

impl NaIRGenPass._emit_value_repr(
    val: ir.Value, type_node: (uni.UniNode | None)
) -> (ir.Value | None) {
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    if isinstance(val.type, ir.IntType) and val.type.width == 1 {
        return self._bool_text(self.builder, val, "fstr.repr.bool");
    }
    if isinstance(val.type, ir.IntType) {
        fn = self._repr_leaf_fn("int");
        if fn is not None {
            _iv = self._coerce_type(val, i64);
            res = self.builder.call(fn, [_iv], name="fstr.repr.int");
            return self._mark_owned(res);
        }
    } elif isinstance(val.type, (ir.FloatType, ir.DoubleType)) {
        return self._emit_float_repr(self._coerce_type(val, ir.DoubleType()));
    } elif isinstance(val.type, ir.PointerType) and val.type == i8p {
        res = self.builder.call(self._repr_str_fn(), [val], name="fstr.repr.str");
        return self._mark_owned(res);
    } elif self?.jacval_type is not None and val.type == self.jacval_type {
        fn = self._repr_jacval_fn();
        if fn is not None {
            res = self.builder.call(fn, [val], name="fstr.repr.jv");
            return self._mark_owned(res);
        }
    } elif isinstance(val.type, (ir.PointerType, ir.LiteralStructType)) {
        _r = self._emit_container_repr(val, self._type_key_of(type_node));
        if _r is None and isinstance(val.type, ir.PointerType) {
            _r = self._dispatch_builtin(
                "repr", [val], type_key=(self._type_key_of(type_node) or "")
            );
        }
        if _r is not None {
            if isinstance(val.type, ir.PointerType)
                and self._is_owned(val)
                and (_r is not val) {
                self._emit_rc_release_typed(val, op="fstr_repr_src", loc="");
            }
            return _r;
        }
    }
    self.emit(E5092, node_override=type_node, kind="f-string conversion", name="!r");
    return None;
}

impl NaIRGenPass._emit_dyn_spec_format(
    val: ir.Value, spec_val: ir.Value, part: uni.FormattedValue
) -> (ir.Value | None) {
    i8p = ir.IntType(8).as_pointer();
    _nval = self._str_norm(val);
    _nspec = self._str_norm(spec_val);
    val = _nval;
    spec_val = _nspec;
    kname: (str | None) = None;
    sval = val;
    if isinstance(val.type, ir.IntType) and val.type.width == 1 {
        kname = "jac_fmt_bool";
    } elif isinstance(val.type, ir.IntType) {
        kname = "jac_fmt_int";
        sval = self._int_text_arg(val, self._is_unsigned_node(part.format_part));
    } elif isinstance(val.type, (ir.FloatType, ir.DoubleType)) {
        kname = "jac_fmt_float";
        if isinstance(val.type, ir.FloatType) {
            sval = self.builder.fpext(val, ir.DoubleType(), name="fstr.dyn.fpext");
        }
    } elif isinstance(val.type, ir.PointerType) and val.type == i8p {
        kname = "jac_fmt_str";
    } elif isinstance(val.type, (ir.PointerType, ir.LiteralStructType)) {
        _s: (ir.Value | None) = None;
        if isinstance(val.type, ir.PointerType) {
            _s = self._emit_obj_str(val);
        }
        if _s is None {
            _s = self._emit_container_repr(val, self._type_key_of(part.format_part));
        }
        if _s is None {
            self.emit(
                E5092,
                node_override=part,
                kind="f-string value",
                name=type(part.format_part).__name__
            );
            return None;
        }
        sval = _s;
        kname = "jac_fmt_str";
    } else {
        self.emit(
            E5092,
            node_override=part,
            kind="f-string format spec",
            name="<dynamic spec>"
        );
        return None;
    }
    fn = self._get_fmt_kernel_fn(kname);
    if fn is None {
        self.emit(
            E5092,
            node_override=part,
            kind="f-string format spec",
            name="<fmt kernel unavailable>"
        );
        return None;
    }
    _a0 = self._coerce_type(sval, fn.args[0].type);
    _a1 = self._coerce_type(spec_val, fn.args[1].type);
    res = self.builder.call(fn, [_a0, _a1], name="fstr.dyn");
    if (sval is not val)
        and isinstance(sval.type, ir.PointerType)
        and self._is_owned(sval) {
        self._emit_rc_release_typed(sval, op="fstr_dyn_tmp", loc="");
    }
    return self._mark_owned(res);
}

impl NaIRGenPass._emit_opt_repr(opt_val: ir.Value) -> (ir.Value | None) {
    b = self.builder;
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    payload_ty = self._opt_payload_of(opt_val.type);
    if not (
        isinstance(payload_ty, ir.IntType)
        or isinstance(payload_ty, (ir.FloatType, ir.DoubleType))
    ) {
        return None;
    }
    if isinstance(payload_ty, ir.IntType)
        and payload_ty.width != 1
        and self._repr_leaf_fn("int") is None {
        return None;
    }
    tag = b.extract_value(opt_val, 0, name="opt.repr.tag");
    present = b.icmp_signed("!=", tag, ir.Constant(i8, 0), name="opt.repr.has");
    fn = b.basic_block.function;
    some_bb = fn.append_basic_block(name="opt.repr.some");
    none_bb = fn.append_basic_block(name="opt.repr.absent");
    done_bb = fn.append_basic_block(name="opt.repr.done");
    b.cbranch(present, some_bb, none_bb);
    b.position_at_end(some_bb);
    payload = b.extract_value(opt_val, 1, name="opt.repr.pl");
    some_str: ir.Value;
    if isinstance(payload.type, ir.IntType) and payload.type.width == 1 {
        some_str = self._bool_text(b, payload, "opt.repr.bool");
        if self._nogc_headerless() {
            some_str = self._call_str_dup(b, some_str, name="opt.repr.bool.dup");
        }
    } elif isinstance(payload.type, ir.IntType) {
        some_str = b.call(
            self._repr_leaf_fn("int"),
            [self._coerce_type(payload, i64)],
            name="opt.repr.int"
        );
    } else {
        some_str = self._emit_float_repr(self._coerce_type(payload, ir.DoubleType()));
    }
    some_end = b.basic_block;
    b.branch(done_bb);
    b.position_at_end(none_bb);
    none_str = self._make_global_string("None", name_prefix=".repr.none");
    if self._nogc_headerless() {
        none_str = self._call_str_dup(b, none_str, name="opt.repr.none.dup");
    }
    none_end = b.basic_block;
    b.branch(done_bb);
    b.position_at_end(done_bb);
    sel = b.phi(some_str.type, name="opt.repr");
    sel.add_incoming(some_str, some_end);
    sel.add_incoming(self._coerce_type(none_str, some_str.type), none_end);
    self._mark_owned(sel);
    return sel;
}

impl NaIRGenPass._emit_float_repr(fv: ir.Value) -> ir.Value {
    _repr = self.builder.call(self._float_repr_fn(), [fv], name="f.repr");
    self._mark_owned(_repr);
    return _repr;
}

impl NaIRGenPass._float_repr_fn -> ir.Function {
    """The shortest decimal repr of a double, as Python's `repr` prints it.

    Fast path, |d| < 1e15 with at most six decimals: a double below 1e15 has
    one decimal of at most 15 significant digits that reads back as it, so the
    first k (0..6) for which N = round(|d| * 10^k) divided by 10^k gives |d|
    back (IEEE division rounds correctly, as reading the text would) yields
    the shortest repr: N's digits with a point k from the end, the k decimals
    written last first and zero-padded on the left. No printf and no strtod.
    A candidate that does not fit below 1e15 converts 0 instead: `fptoui` of a
    value past the u64 range is poison, which an `and` with a false test
    would not stop from reaching the branch.

    Otherwise 15 significant digits first: a double has at most one decimal of
    15 digits that reads back as it, so if that rounding does, it is the
    shortest once its trailing zeros go (the zeros of the mantissa, just
    before the 'e'); else 16, then 17, which always do. A subnormal has fewer
    than 53 bits, so several 15-digit decimals read back as it: it keeps the
    search from one digit up.
    """;
    if self._float_repr_function is not None {
        return self._float_repr_function;
    }
    f64 = ir.DoubleType();
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    fnty = ir.FunctionType(i8p, [f64]);
    fn = ir.Function(self.llvm_module, fnty, name="__jac_float_repr");
    fn.linkage = "private";
    fn.args[0].name = "d";
    d = fn.args[0];

    saved_builder = self._builder;
    entry_bb = fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb);
    self._builder = b;

    snprintf = self._get_or_declare_extern(
        "snprintf", i32, [i8p, i64, i8p], var_arg=True
    );
    strtod = self._get_or_declare_extern("strtod", f64, [i8p, i8p.as_pointer()]);
    strtol = self._get_or_declare_extern("strtol", i64, [i8p, i8p.as_pointer(), i32]);
    strchr = self._get_or_declare_extern("strchr", i8p, [i8p, i32]);

    fmt_e = self._make_global_string("%.*e", name_prefix=".frepr.e");
    fmt_f = self._make_global_string("%.*f", name_prefix=".frepr.f");
    s_nan = self._make_global_string("nan", name_prefix=".frepr.nan");
    s_inf = self._make_global_string("inf", name_prefix=".frepr.inf");
    s_ninf = self._make_global_string("-inf", name_prefix=".frepr.ninf");

    is_nan = b.not_(b.fcmp_ordered("==", d, d, name="fr.ord"), name="fr.isnan");
    nan_bb = fn.append_basic_block("fr.nan");
    chk_pinf = fn.append_basic_block("fr.chk.pinf");
    b.cbranch(is_nan, nan_bb, chk_pinf);
    b.position_at_end(nan_bb);
    if self._nogc_headerless() {
        b.ret(self._call_str_dup(b, s_nan, name="fr.nan.dup"));
    } else {
        b.ret(s_nan);
    }
    b.position_at_end(chk_pinf);
    pinf = ir.Constant(f64, float("inf"));
    ninf = ir.Constant(f64, float("-inf"));
    is_pinf = b.fcmp_ordered("==", d, pinf, name="fr.ispinf");
    pinf_bb = fn.append_basic_block("fr.pinf");
    chk_ninf = fn.append_basic_block("fr.chk.ninf");
    b.cbranch(is_pinf, pinf_bb, chk_ninf);
    b.position_at_end(pinf_bb);
    if self._nogc_headerless() {
        b.ret(self._call_str_dup(b, s_inf, name="fr.inf.dup"));
    } else {
        b.ret(s_inf);
    }
    b.position_at_end(chk_ninf);
    is_ninf = b.fcmp_ordered("==", d, ninf, name="fr.isninf");
    ninf_bb = fn.append_basic_block("fr.ninf");
    setup_bb = fn.append_basic_block("fr.setup");
    b.cbranch(is_ninf, ninf_bb, setup_bb);
    b.position_at_end(ninf_bb);
    if self._nogc_headerless() {
        b.ret(self._call_str_dup(b, s_ninf, name="fr.ninf.dup"));
    } else {
        b.ret(s_ninf);
    }

    b.position_at_end(setup_bb);
    if not self._nogc_headerless() {
        slow_bb = fn.append_basic_block("fr.slow");
        negative = b.icmp_signed(
            "<", b.bitcast(d, i64, name="fr.bits"), ir.Constant(i64, 0), name="fr.neg"
        );
        mag = b.select(negative, b.fneg(d, name="fr.negd"), d, name="fr.mag");
        emit_bb = fn.append_basic_block("fr.fast.emit");
        is_zero = b.fcmp_ordered("==", mag, ir.Constant(f64, 0.0), name="fr.zero");
        zero_bb = fn.append_basic_block("fr.fast.zero");
        range_bb = fn.append_basic_block("fr.fast.range");
        b.cbranch(is_zero, zero_bb, range_bb);
        b.position_at_end(zero_bb);
        b.ret(
            b.select(
                negative,
                self._make_global_string("-0.0", name_prefix=".frepr.nz"),
                self._make_global_string("0.0", name_prefix=".frepr.z"),
                name="fr.zs"
            )
        );
        b.position_at_end(range_bb);
        in_range = b.and_(
            b.fcmp_ordered(">=", mag, ir.Constant(f64, 0.0001), name="fr.lo.ok"),
            b.fcmp_ordered("<", mag, ir.Constant(f64, 1e15), name="fr.hi.ok"),
            name="fr.inrange"
        );
        try_bb = fn.append_basic_block("fr.fast.k0");
        b.cbranch(in_range, try_bb, slow_bb);
        found: list[tuple[ir.Block, ir.Value, int]] = [];
        for k in range(7) {
            b.position_at_end(try_bb);
            scale = ir.Constant(f64, float(10 ** k));
            scaled = b.fmul(mag, scale, name=f"fr.s{k}");
            fits = b.fcmp_ordered(
                "<", scaled, ir.Constant(f64, 1e15), name=f"fr.fit{k}"
            );
            safe = b.select(fits, scaled, ir.Constant(f64, 0.0), name=f"fr.safe{k}");
            n = b.fptoui(
                b.fadd(safe, ir.Constant(f64, 0.5), name=f"fr.r{k}"),
                i64,
                name=f"fr.n{k}"
            );
            back = b.fdiv(b.uitofp(n, f64, name=f"fr.nf{k}"), scale, name=f"fr.b{k}");
            hit = b.and_(
                fits,
                b.fcmp_ordered("==", back, mag, name=f"fr.eq{k}"),
                name=f"fr.hit{k}"
            );
            next_bb = fn.append_basic_block(f"fr.fast.k{k + 1}") if k < 6 else slow_bb;
            here = b.block;
            b.cbranch(hit, emit_bb, next_bb);
            found.append((here, n, k));
            try_bb = next_bb;
        }
        b.position_at_end(emit_bb);
        n_phi = b.phi(i64, name="fr.N");
        k_phi = b.phi(i64, name="fr.k");
        p_phi = b.phi(i64, name="fr.p10");
        for (blk, n, k) in found {
            n_phi.add_incoming(n, blk);
            k_phi.add_incoming(ir.Constant(i64, k), blk);
            p_phi.add_incoming(ir.Constant(i64, 10 ** k), blk);
        }
        out = self._str_alloc(b, ir.Constant(i64, 48), name="fr.fast.buf");
        start = b.zext(negative, i64, name="fr.signlen");
        sign_bb = fn.append_basic_block("fr.fast.sign");
        int_bb = fn.append_basic_block("fr.fast.int");
        b.cbranch(negative, sign_bb, int_bb);
        b.position_at_end(sign_bb);
        b.store(ir.Constant(i8, 45), out);
        b.branch(int_bb);
        b.position_at_end(int_bb);
        whole = b.udiv(n_phi, p_phi, name="fr.whole");
        part = b.urem(n_phi, p_phi, name="fr.part");
        wlen = self._emit_fmt_int(b, whole, b.gep(out, [start]), True);
        dot = b.add(start, wlen, name="fr.dot");
        b.store(ir.Constant(i8, 46), b.gep(out, [dot]));
        first = b.add(dot, ir.Constant(i64, 1), name="fr.first");
        k_zero = b.icmp_unsigned("==", k_phi, ir.Constant(i64, 0), name="fr.k0");
        tail0_bb = fn.append_basic_block("fr.fast.tail0");
        digits_bb = fn.append_basic_block("fr.fast.digits");
        done_bb = fn.append_basic_block("fr.fast.done");
        b.cbranch(k_zero, tail0_bb, digits_bb);
        b.position_at_end(tail0_bb);
        b.store(ir.Constant(i8, 48), b.gep(out, [first]));
        end0 = b.add(first, ir.Constant(i64, 1), name="fr.end0");
        b.branch(done_bb);

        b.position_at_end(digits_bb);
        j = b.phi(i64, name="fr.j");
        rest = b.phi(i64, name="fr.rest");
        j.add_incoming(k_phi, int_bb);
        rest.add_incoming(part, int_bb);
        j1 = b.sub(j, ir.Constant(i64, 1), name="fr.j1");
        q = b.udiv(rest, ir.Constant(i64, 10), name="fr.q");
        digit = b.sub(rest, b.mul(q, ir.Constant(i64, 10)), name="fr.dg");
        b.store(
            b.trunc(b.add(digit, ir.Constant(i64, 48)), i8, name="fr.ch"),
            b.gep(out, [b.add(first, j1)])
        );
        j.add_incoming(j1, digits_bb);
        rest.add_incoming(q, digits_bb);
        endk = b.add(first, k_phi, name="fr.endk");
        b.cbranch(
            b.icmp_unsigned("==", j1, ir.Constant(i64, 0), name="fr.jdone"),
            done_bb,
            digits_bb
        );
        b.position_at_end(done_bb);
        end = b.phi(i64, name="fr.end");
        end.add_incoming(end0, tail0_bb);
        end.add_incoming(endk, digits_bb);
        self._str_finish(b, out, end);
        b.ret(out);
        b.position_at_end(slow_bb);
    }
    cap = ir.Constant(i64, 64);
    tmp = self._str_alloc(b, cap, name="fr.tmp");
    endptr = b.alloca(i8p, name="fr.endptr");

    try15 = fn.append_basic_block("fr.p15");
    try16 = fn.append_basic_block("fr.p16");
    loop_done = fn.append_basic_block("fr.done");
    sub_cond = fn.append_basic_block("fr.sub.cond");
    sub_inc = fn.append_basic_block("fr.sub.inc");
    sub_done = fn.append_basic_block("fr.sub.done");
    subnormal = b.fcmp_ordered(
        "<",
        b.select(
            b.fcmp_ordered("<", d, ir.Constant(f64, 0.0), name="fr.dneg"),
            b.fneg(d, name="fr.dabs.n"),
            d,
            name="fr.dabs"
        ),
        ir.Constant(f64, 2.2250738585072014e-308),
        name="fr.subnormal"
    );
    sub_entry = b.block;
    b.cbranch(subnormal, sub_cond, try15);
    b.position_at_end(sub_cond);
    sub_p = b.phi(i32, name="fr.sub.p");
    sub_p.add_incoming(ir.Constant(i32, 0), sub_entry);
    b.call(snprintf, [tmp, cap, fmt_e, sub_p, d], name="fr.sub.e");
    sub_eq = b.fcmp_ordered(
        "==", b.call(strtod, [tmp, endptr], name="fr.sub.parsed"), d, name="fr.sub.eq"
    );
    b.cbranch(
        b.or_(
            sub_eq,
            b.icmp_signed(">=", sub_p, ir.Constant(i32, 16), name="fr.sub.max"),
            name="fr.sub.stop"
        ),
        sub_done,
        sub_inc
    );
    b.position_at_end(sub_inc);
    sub_p.add_incoming(b.add(sub_p, ir.Constant(i32, 1), name="fr.sub.p1"), sub_inc);
    b.branch(sub_cond);
    b.position_at_end(sub_done);
    sub_p64 = b.zext(sub_p, i64, name="fr.sub.p64");
    b.branch(loop_done);
    tried: list[tuple[ir.Block, any]] = [(sub_done, sub_p64)];
    for (blk, prec, nxt) in ((try15, 14, try16), (try16, 15, None)) {
        b.position_at_end(blk);
        b.call(
            snprintf, [tmp, cap, fmt_e, ir.Constant(i32, prec), d], name=f"fr.e{prec}"
        );
        parsed = b.call(strtod, [tmp, endptr], name=f"fr.parsed{prec}");
        eq = b.fcmp_ordered("==", parsed, d, name=f"fr.eq{prec}");
        if nxt is not None {
            b.cbranch(eq, loop_done, nxt);
        } else {
            try17 = fn.append_basic_block("fr.p17");
            b.cbranch(eq, loop_done, try17);
            tried.append((b.block, prec));
            b.position_at_end(try17);
            b.call(snprintf, [tmp, cap, fmt_e, ir.Constant(i32, 16), d], name="fr.e16");
            b.branch(loop_done);
            tried.append((b.block, 16));
            break;
        }
        tried.append((b.block, prec));
    }
    b.position_at_end(loop_done);
    pmax = b.phi(i64, name="fr.pmax");
    for (blk, prec) in tried {
        pmax.add_incoming(
            prec if isinstance(prec, ir.Value) else ir.Constant(i64, prec), blk
        );
    }

    epos0 = b.call(strchr, [tmp, ir.Constant(i32, 101)], name="fr.epos0");
    strip_bb = fn.append_basic_block("fr.strip");
    strip_next = fn.append_basic_block("fr.strip.next");
    stripped_bb = fn.append_basic_block("fr.stripped");
    pre_strip = b.block;
    b.branch(strip_bb);
    b.position_at_end(strip_bb);
    zeros = b.phi(i64, name="fr.zeros");
    zeros.add_incoming(ir.Constant(i64, 0), pre_strip);
    at_ch = b.load(
        b.gep(epos0, [b.sub(ir.Constant(i64, -1), zeros, name="fr.zoff")]),
        name="fr.zch"
    );
    more = b.and_(
        b.icmp_unsigned("==", at_ch, ir.Constant(i8, 48), name="fr.iszero"),
        b.icmp_unsigned("<", zeros, pmax, name="fr.zroom"),
        name="fr.zmore"
    );
    b.cbranch(more, strip_next, stripped_bb);
    b.position_at_end(strip_next);
    zeros.add_incoming(b.add(zeros, ir.Constant(i64, 1), name="fr.z1"), strip_next);
    b.branch(strip_bb);
    b.position_at_end(stripped_bb);
    pfin = b.trunc(b.sub(pmax, zeros, name="fr.pfin64"), i32, name="fr.pfin");
    ndig = b.add(b.zext(pfin, i64), ir.Constant(i64, 1), name="fr.ndig");
    epos = b.call(strchr, [tmp, ir.Constant(i32, 101)], name="fr.epos");
    eptr = b.gep(epos, [ir.Constant(i64, 1)], name="fr.eptr");
    expo = b.call(strtol, [eptr, endptr, ir.Constant(i32, 10)], name="fr.exp");
    decpt = b.add(expo, ir.Constant(i64, 1), name="fr.decpt");
    lo = b.icmp_signed("<=", decpt, ir.Constant(i64, -4), name="fr.lo");
    hi = b.icmp_signed(">", decpt, ir.Constant(i64, 16), name="fr.hi");
    use_exp = b.or_(lo, hi, name="fr.useexp");
    exp_bb = fn.append_basic_block("fr.exp.out");
    fixed_bb = fn.append_basic_block("fr.fixed");
    b.cbranch(use_exp, exp_bb, fixed_bb);

    b.position_at_end(exp_bb);
    elen32 = b.call(snprintf, [tmp, cap, fmt_e, pfin, d], name="fr.elen32");
    self._str_finish(b, tmp, b.sext(elen32, i64, name="fr.elen"));
    b.ret(tmp);

    b.position_at_end(fixed_bb);
    fr0 = b.sub(ndig, decpt, name="fr.frac0");
    is_neg = b.icmp_signed("<", fr0, ir.Constant(i64, 0), name="fr.fracneg");
    frac = b.select(is_neg, ir.Constant(i64, 0), fr0, name="fr.frac");
    fbuf = tmp;
    frac32 = b.trunc(frac, i32, name="fr.frac32");
    flen32 = b.call(snprintf, [fbuf, cap, fmt_f, frac32, d], name="fr.flen32");
    self._str_finish(b, fbuf, b.sext(flen32, i64, name="fr.flen0"));
    is_int = b.icmp_signed("==", frac, ir.Constant(i64, 0), name="fr.isint");
    dot_bb = fn.append_basic_block("fr.adddot");
    ret_bb = fn.append_basic_block("fr.fixed.ret");
    b.cbranch(is_int, dot_bb, ret_bb);
    b.position_at_end(dot_bb);
    flen = self._call_str_len(b, fbuf, name="fr.flen");
    b.store(ir.Constant(i8, 46), b.gep(fbuf, [flen], name="fr.dotp"));
    f1 = b.add(flen, ir.Constant(i64, 1), name="fr.f1");
    b.store(ir.Constant(i8, 48), b.gep(fbuf, [f1], name="fr.zerop"));
    f2 = b.add(flen, ir.Constant(i64, 2), name="fr.f2");
    self._str_finish(b, fbuf, f2);
    b.branch(ret_bb);
    b.position_at_end(ret_bb);
    b.ret(fbuf);

    self._builder = saved_builder;
    self._float_repr_function = fn;
    return fn;
}

impl NaIRGenPass._emit_whitespace_width(
    text: ir.Value, cursor: ir.Value, length: ir.Value, reverse: bool
) -> ir.Value {
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    result = self._entry_alloca(i64, "space.width");
    self.builder.store(ir.Constant(i64, 0), result);
    byte_index = self.builder.sub(cursor, ir.Constant(i64, 1)) if reverse else cursor;
    byte = self.builder.load(self.builder.gep(text, [byte_index]));
    ascii_space = self.builder.or_(
        self.builder.and_(
            self.builder.icmp_unsigned(">=", byte, ir.Constant(i8, 9)),
            self.builder.icmp_unsigned("<=", byte, ir.Constant(i8, 13))
        ),
        self.builder.and_(
            self.builder.icmp_unsigned(">=", byte, ir.Constant(i8, 28)),
            self.builder.icmp_unsigned("<=", byte, ir.Constant(i8, 32))
        )
    );
    self.builder.store(
        self.builder.select(ascii_space, ir.Constant(i64, 1), ir.Constant(i64, 0)),
        result
    );

    codes = [133, 160, 5760]
        + list(range(8192, 8203))
        + [8232, 8233, 8239, 8287, 12288];
    for cp in codes {
        encoded = chr(cp).encode("utf-8");
        width = len(encoded);
        func = self.builder.function;
        check = func.append_basic_block("space.utf8");
        next = func.append_basic_block("space.next");
        available = cursor if reverse else self.builder.sub(length, cursor);
        self.builder.cbranch(
            self.builder.icmp_unsigned(">=", available, ir.Constant(i64, width)),
            check,
            next
        );
        self.builder.position_at_end(check);
        start = self.builder.sub(cursor, ir.Constant(i64, width))
            if reverse
            else cursor;
        matches: ir.Value = ir.Constant(ir.IntType(1), 1);
        for offset in range(width) {
            part = self.builder.load(
                self.builder.gep(
                    text, [self.builder.add(start, ir.Constant(i64, offset))]
                )
            );
            matches = self.builder.and_(
                matches,
                self.builder.icmp_unsigned("==", part, ir.Constant(i8, encoded[offset]))
            );
        }
        self.builder.store(
            self.builder.select(
                matches, ir.Constant(i64, width), self.builder.load(result)
            ),
            result
        );
        self.builder.branch(next);
        self.builder.position_at_end(next);
    }
    return self.builder.load(result);
}

impl NaIRGenPass._codegen_str_split_whitespace(
    text: ir.Value, maxsplit: ir.Value | None = None, reverse: bool = False
) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);
    length = self._call_str_len(self.builder, text);
    self._emit_list_helpers("ptr", i8p);
    helpers = self.list_helpers["ptr"];
    result = self.builder.call(helpers["new"], []);
    self._nogc_stamp_elem_drops(result, ["str"]);
    cursor = self._entry_alloca(i64, "ws.cursor");
    token = self._entry_alloca(i64, "ws.token");
    budget = self._entry_alloca(i64, "ws.budget");
    self.builder.store(length if reverse else zero, cursor);
    self.builder.store(
        self._coerce_type(maxsplit, i64)
            if maxsplit is not None
            else ir.Constant(i64, -1),
        budget
    );
    func = self.builder.function;
    skip_bb = func.append_basic_block("ws.skip_bb");
    classify = func.append_basic_block("ws.classify");
    advance = func.append_basic_block("ws.advance");
    begin = func.append_basic_block("ws.begin");
    remainder = func.append_basic_block("ws.remainder");
    scan = func.append_basic_block("ws.scan");
    inspect = func.append_basic_block("ws.inspect");
    step = func.append_basic_block("ws.step");
    emit = func.append_basic_block("ws.emit");
    done = func.append_basic_block("ws.done");
    self.builder.branch(skip_bb);
    self.builder.position_at_end(skip_bb);
    pos = self.builder.load(cursor);
    self.builder.cbranch(
        self.builder.icmp_unsigned(">", pos, zero)
            if reverse
            else self.builder.icmp_unsigned("<", pos, length),
        classify,
        done
    );
    self.builder.position_at_end(classify);
    width = self._emit_whitespace_width(text, pos, length, reverse);
    self.builder.cbranch(self.builder.icmp_unsigned("!=", width, zero), advance, begin);
    self.builder.position_at_end(advance);
    self.builder.store(
        self.builder.sub(pos, width) if reverse else self.builder.add(pos, width),
        cursor
    );
    self.builder.branch(skip_bb);
    self.builder.position_at_end(begin);
    self.builder.store(pos, token);
    self.builder.cbranch(
        self.builder.icmp_signed("==", self.builder.load(budget), zero), remainder, scan
    );
    self.builder.position_at_end(remainder);
    self.builder.store(zero if reverse else length, cursor);
    self.builder.branch(emit);
    self.builder.position_at_end(scan);
    current = self.builder.load(cursor);
    self.builder.cbranch(
        self.builder.icmp_unsigned(">", current, zero)
            if reverse
            else self.builder.icmp_unsigned("<", current, length),
        inspect,
        emit
    );
    self.builder.position_at_end(inspect);
    whitespace = self._emit_whitespace_width(text, current, length, reverse);
    self.builder.cbranch(
        self.builder.icmp_unsigned("!=", whitespace, zero), emit, step
    );
    self.builder.position_at_end(step);
    self.builder.store(
        self.builder.sub(current, one) if reverse else self.builder.add(current, one),
        cursor
    );
    self.builder.branch(scan);
    self.builder.position_at_end(emit);
    finish = self.builder.load(cursor);
    start = self.builder.load(token);
    size = self.builder.sub(start, finish)
        if reverse
        else self.builder.sub(finish, start);
    copy = self._str_alloc(self.builder, self.builder.add(size, one), name="ws.copy");
    memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    self.builder.call(
        memcpy, [copy, self.builder.gep(text, [finish if reverse else start]), size]
    );
    self._str_finish(self.builder, copy, size);
    self._rc_call_with_ctx(helpers["append"], [result, copy], op="str_split");
    self._emit_rc_release_simple(copy, op="str_split");
    remaining = self.builder.load(budget);
    self.builder.store(
        self.builder.select(
            self.builder.icmp_signed(">", remaining, zero),
            self.builder.sub(remaining, one),
            remaining
        ),
        budget
    );
    self.builder.branch(skip_bb);
    self.builder.position_at_end(done);
    if reverse {
        z = ir.Constant(i32, 0);
        data = self.builder.load(self.builder.gep(result, [z, ir.Constant(i32, 2)]));
        count = self.builder.load(self.builder.gep(result, [z, z]));
        index = self._entry_alloca(i64, "ws.reverse");
        self.builder.store(zero, index);
        check = func.append_basic_block("ws.reverse.check");
        swap = func.append_basic_block("ws.reverse.swap");
        end = func.append_basic_block("ws.reverse.end");
        self.builder.branch(check);
        self.builder.position_at_end(check);
        left = self.builder.load(index);
        right = self.builder.sub(self.builder.sub(count, one), left);
        self.builder.cbranch(self.builder.icmp_signed("<", left, right), swap, end);
        self.builder.position_at_end(swap);
        lp = self.builder.gep(data, [left]);
        rp = self.builder.gep(data, [right]);
        lv = self.builder.load(lp);
        rv = self.builder.load(rp);
        self.builder.store(rv, lp);
        self.builder.store(lv, rp);
        self.builder.store(self.builder.add(left, one), index);
        self.builder.branch(check);
        self.builder.position_at_end(end);
    }
    return result;
}

impl NaIRGenPass._codegen_str_splitlines(
    text: ir.Value, keepends: ir.Value | None = None
) -> ir.Value {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);
    b = self.builder;
    length = self._call_str_len(b, text);
    keep = self._coerce_type(keepends, ir.IntType(1))
        if keepends is not None
        else ir.Constant(ir.IntType(1), 0);
    self._emit_list_helpers("ptr", i8p);
    helpers = self.list_helpers["ptr"];
    result = b.call(helpers["new"], []);
    self._nogc_stamp_elem_drops(result, ["str"]);
    cursor = self._entry_alloca(i64, "lines.cursor");
    start = self._entry_alloca(i64, "lines.start");
    width_slot = self._entry_alloca(i64, "lines.width");
    b.store(zero, cursor);
    b.store(zero, start);
    func = b.function;
    scan = func.append_basic_block("lines.scan");
    inspect = func.append_basic_block("lines.inspect");
    advance = func.append_basic_block("lines.advance");
    emit = func.append_basic_block("lines.emit");
    tail = func.append_basic_block("lines.tail");
    done = func.append_basic_block("lines.done");
    b.branch(scan);
    b.position_at_end(scan);
    pos = b.load(cursor);
    b.cbranch(b.icmp_unsigned("<", pos, length), inspect, tail);
    b.position_at_end(inspect);
    byte = b.load(b.gep(text, [pos]));
    ascii_break: ir.Value = b.icmp_unsigned("==", byte, ir.Constant(i8, 10));
    for code in [11, 12, 13, 28, 29, 30] {
        ascii_break = b.or_(
            ascii_break, b.icmp_unsigned("==", byte, ir.Constant(i8, code))
        );
    }
    b.store(b.select(ascii_break, one, zero), width_slot);

    for sequence in [[13, 10], [194, 133], [226, 128, 168], [226, 128, 169]] {
        check = func.append_basic_block("lines.sequence");
        next_check = func.append_basic_block("lines.next");
        sequence_size = ir.Constant(i64, len(sequence));
        b.cbranch(
            b.and_(
                b.icmp_unsigned("==", byte, ir.Constant(i8, sequence[0])),
                b.icmp_unsigned("<=", sequence_size, b.sub(length, pos))
            ),
            check,
            next_check
        );
        b.position_at_end(check);
        matches: ir.Value = ir.Constant(ir.IntType(1), 1);
        for offset in range(1, len(sequence)) {
            part = b.load(b.gep(text, [b.add(pos, ir.Constant(i64, offset))]));
            matches = b.and_(
                matches, b.icmp_unsigned("==", part, ir.Constant(i8, sequence[offset]))
            );
        }
        b.store(b.select(matches, sequence_size, b.load(width_slot)), width_slot);
        b.branch(next_check);
        b.position_at_end(next_check);
    }
    b.cbranch(b.icmp_unsigned("!=", b.load(width_slot), zero), emit, advance);
    b.position_at_end(advance);
    b.store(b.add(pos, one), cursor);
    b.branch(scan);
    b.position_at_end(tail);
    b.store(zero, width_slot);
    b.cbranch(b.icmp_unsigned("<", b.load(start), length), emit, done);
    b.position_at_end(emit);
    finish = b.load(cursor);
    width = b.load(width_slot);
    begin = b.load(start);
    end = b.add(finish, width);
    size = b.sub(b.select(keep, end, finish), begin);
    copy = self._str_alloc(b, b.add(size, one), name="lines.copy");
    memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    b.call(memcpy, [copy, b.gep(text, [begin]), size]);
    self._str_finish(b, copy, size);
    self._rc_call_with_ctx(helpers["append"], [result, copy], op="str_splitlines");
    self._emit_rc_release_simple(copy, op="str_splitlines");
    b.store(end, start);
    b.store(end, cursor);
    b.branch(scan);
    b.position_at_end(done);
    return result;
}
