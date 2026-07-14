impl NaIRGenPass._get_or_declare_extern(
    name: str, ret_type: ir.Type, arg_types: list[ir.Type], var_arg: bool = False
) -> ir.Function {
    if name in self.extern_funcs {
        return self.extern_funcs[name];
    }

    for gv in self.llvm_module.global_values {
        if isinstance(gv, ir.Function) and gv.name == name {
            self.extern_funcs[name] = gv;
            return gv;
        }
    }
    fnty = ir.FunctionType(ret_type, arg_types, var_arg=var_arg);
    func = ir.Function(self.llvm_module, fnty, name=name);
    self.extern_funcs[name] = func;
    return func;
}

impl NaIRGenPass._get_printf -> ir.Function {
    return self._get_or_declare_extern(
        "printf", ir.IntType(32), [ir.IntType(8).as_pointer()], var_arg=True
    );
}

impl NaIRGenPass._emit_print(nd: uni.FuncCall) -> (ir.Value | None) {
    printf = self._get_printf();
    params = nd.params or [];
    if not params {
        fmt = self._get_fmt_string("");
        fmt_ptr = self.builder.bitcast(fmt, ir.IntType(8).as_pointer());
        self.builder.call(printf, [fmt_ptr]);
        return ir.Constant(ir.IntType(64), 0);
    }

    fmt_parts = [];
    args = [];
    for (i, param) in enumerate(params) {
        val = self._codegen_expr(param);
        if val is None {
            continue;
        }

        if i > 0 {
            fmt_parts.append(" ");
        }

        if isinstance(val.type, ir.IntType) {
            if val.type.width == 1 {
                val = self.builder.zext(val, ir.IntType(64));
            } elif val.type.width < 64 {
                val = self.builder.sext(val, ir.IntType(64));
            }
            fmt_parts.append("%lld");
            args.append(val);
        } elif isinstance(val.type, ir.DoubleType) {
            fmt_parts.append("%s");
            args.append(self._emit_float_repr(val));
        } elif isinstance(val.type, ir.FloatType) {
            val = self.builder.fpext(val, ir.DoubleType());
            fmt_parts.append("%s");
            args.append(self._emit_float_repr(val));
        } elif isinstance(val.type, ir.PointerType) {
            obj_s = self._emit_obj_str(val);
            if obj_s is not None {
                if self._is_owned(val) {
                    self._emit_rc_release_typed(val, op="print_obj_src", loc="");
                }
                val = obj_s;
            }
            fmt_parts.append("%s");
            args.append(val);
        }
    }

    if fmt_parts {
        fmt_str = "".join(fmt_parts);
        fmt = self._get_fmt_string(fmt_str);
        fmt_ptr = self.builder.bitcast(fmt, ir.IntType(8).as_pointer());
        self.builder.call(printf, [fmt_ptr] + args);

        for _parg in args {
            if isinstance(_parg.type, ir.PointerType) and self._is_owned(_parg) {
                self._emit_rc_release_typed(_parg, op="print_tmp", loc="");
            }
        }
    }
    return ir.Constant(ir.IntType(64), 0);
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

    result = None;
    for part in nd.strings {
        if isinstance(part, uni.FString) {
            val = self._codegen_fstring(part);
        } else {
            val = self._codegen_string(part);
        }
        if val is None {
            continue;
        }
        if result is None {
            result = val;
        } else {
            _ms_old = result;
            _ms_val = val;
            result = self._emit_binary_op(Tok.PLUS, _ms_old, _ms_val);
            if self._is_owned(_ms_old) {
                self._emit_rc_release_typed(_ms_old, op="mstr_old", loc="");
            }
            if self._is_owned(_ms_val) {
                self._emit_rc_release_typed(_ms_val, op="mstr_val", loc="");
            }
        }
    }
    return result;
}

impl NaIRGenPass._make_global_string(text: str, name_prefix: str = ".str") -> ir.Value {
    i64 = ir.IntType(64);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    _key = f"{name_prefix}\x00{text}";
    global_str = self._interned_strs.get(_key);
    if global_str is None {
        str_bytes = bytearray((text + "\0").encode("utf8"));
        arr_type = ir.ArrayType(i8, len(str_bytes));
        struct_type = ir.LiteralStructType([i64, i64, arr_type]);
        sentinel_val = ir.Constant(i64, 0x7FFFFFFFFFFFFFFF);
        dtor_val = ir.Constant(i64, 0);
        c_str = ir.Constant(arr_type, str_bytes);
        struct_val = ir.Constant(struct_type, [sentinel_val, dtor_val, c_str]);
        global_str = ir.GlobalVariable(
            self.llvm_module, struct_type, name=f"{name_prefix}.{self._str_count}"
        );
        self._str_count = self._str_count + 1;
        global_str.linkage = "private";
        global_str.global_constant = True;
        global_str.initializer = struct_val;
        self._interned_strs[_key] = global_str;
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
    import from jaclang.compiler.passes.main.capability_check_pass {
        static_fstring_spec_text
    }
    return static_fstring_spec_text(spec);
}

impl NaIRGenPass._fstring_spec_to_printf(spec: str, kind: str) -> (tuple | None) {
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

impl NaIRGenPass._codegen_fstring(nd: uni.FString) -> (ir.Value | None) {
    fmt_parts: list[str] = [];
    args: list[ir.Value] = [];

    obj_strs: list[ir.Value] = [];
    for part in nd.parts {
        if isinstance(part, uni.String) {
            text = part.lit_value;

            text = text.replace("%", "%%");
            fmt_parts.append(text);
        } elif isinstance(part, uni.FormattedValue) {
            val = self._codegen_expr(part.format_part);
            if val is None {
                continue;
            }
            _conv = part.conversion if part.conversion is not None else -1;
            if _conv not in (-1, 115) {
                self.emit(
                    E5092,
                    node_override=part,
                    kind="f-string conversion",
                    name=("!r" if _conv == 114 else "!a")
                );
                return None;
            }
            _spec_txt: (str | None) = None;
            if part.format_spec is not None {
                _spec_txt = self._fstring_spec_text(part.format_spec);
                if _spec_txt is None {
                    self.emit(
                        E5092,
                        node_override=part,
                        kind="f-string format spec",
                        name="<dynamic spec>"
                    );
                    return None;
                }
            }
            if _spec_txt {
                if isinstance(val.type, ir.IntType) and val.type.width == 1 {
                    val = self.builder.zext(val, ir.IntType(64));
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
                    self.emit(
                        E5092,
                        node_override=part,
                        kind="f-string format spec",
                        name=_spec_txt
                    );
                    return None;
                }
                (directive, want) = _tr;
                if want == "float" {
                    fmt_parts.append(directive);
                    args.append(self._coerce_type(val, ir.DoubleType()));
                } elif want == "repr" {
                    fmt_parts.append(directive);
                    args.append(self._emit_float_repr(val));
                } elif want == "str" {
                    if val.type != ir.IntType(8).as_pointer() {
                        obj_s = self._emit_obj_str(val);
                        if obj_s is not None {
                            if self._is_owned(val) {
                                self._emit_rc_release_typed(
                                    val, op="fstr_obj_src", loc=""
                                );
                            }
                            val = obj_s;
                            obj_strs.append(obj_s);
                        }
                    }
                    fmt_parts.append(directive);
                    args.append(val);
                } else {
                    fmt_parts.append(directive);
                    args.append(val);
                }
                continue;
            }
            if isinstance(val.type, ir.IntType) and val.type.width == 64 {
                fmt_parts.append("%lld");
                args.append(val);
            } elif isinstance(val.type, ir.IntType) and val.type.width == 1 {
                val = self.builder.zext(val, ir.IntType(64));
                fmt_parts.append("%lld");
                args.append(val);
            } elif isinstance(val.type, ir.DoubleType) {
                fmt_parts.append("%s");
                args.append(self._emit_float_repr(val));
            } elif isinstance(val.type, ir.PointerType) {
                obj_s = self._emit_obj_str(val);
                if obj_s is not None {
                    if self._is_owned(val) {
                        self._emit_rc_release_typed(val, op="fstr_obj_src", loc="");
                    }
                    val = obj_s;
                    obj_strs.append(obj_s);
                }
                fmt_parts.append("%s");
                args.append(val);
            }
        }
    }
    fmt_str = "".join(fmt_parts);

    _fstr_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
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
    buf = self._rc_call_with_ctx(
        self.rc_alloc_fn, [buf_size], op="fstring", loc=_fstr_loc, name="fstr.buf"
    );
    self._emit_set_type_tag(self.builder, buf, "str");
    call_args: list[ir.Value] = [buf, buf_size, fmt_global];
    for a in args {
        call_args.append(a);
    }
    self.builder.call(snprintf_fn, call_args, name="fstr.len");

    for _obj_s in obj_strs {
        self._emit_rc_release_typed(_obj_s, op="fstr_obj_tmp", loc="");
    }

    self._mark_owned(buf);
    return buf;
}

impl NaIRGenPass._codegen_string_index(
    target_val: ir.Value, index_val: ir.Value
) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);

    char_ptr = self.builder.gep(target_val, [index_val], name="char.ptr");
    char_val = self.builder.load(char_ptr, name="char.val");

    two = ir.Constant(i64, 2);
    _sidx_loc = getattr(target_val, 'jac_loc', '');
    new_str = self._rc_call_with_ctx(
        self.rc_alloc_fn, [two], op="str_index", loc=_sidx_loc, name="char.str"
    );
    self._emit_set_type_tag(self.builder, new_str, "str");
    self.builder.store(char_val, new_str);

    one_ptr = self.builder.gep(new_str, [ir.Constant(i64, 1)], name="null.ptr");
    self.builder.store(ir.Constant(i8, 0), one_ptr);

    self._mark_owned(new_str);
    return new_str;
}

impl NaIRGenPass._emit_norm_slice_bounds(
    slice_node: object, src_len: ir.Value
) -> (tuple | None) {
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

    i_alloca = self.builder.alloca(i64, name="sl.i");
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
    elem = self.builder.call(helpers["get"], [target_val, cur_i], name="sl.elem");
    self._rc_call_with_ctx(helpers["append"], [new_list, elem], op="list_slice");

    next_i = self.builder.add(cur_i, step_val, name="sl.next");
    self.builder.store(next_i, i_alloca);
    self.builder.branch(loop_check);

    self.builder.position_at_end(loop_done);

    return new_list;
}

impl NaIRGenPass._codegen_string_slice(
    target_val: ir.Value, slice_node: object
) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);
    func = self.builder.function;

    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    src_len = self.builder.call(strlen_fn, [target_val], name="ss.len");
    bounds = self._emit_norm_slice_bounds(slice_node, src_len);
    if bounds is None {
        return None;
    }
    (start_val, stop_val, step_val, step_pos) = bounds;

    diff = self.builder.select(
        step_pos,
        self.builder.sub(stop_val, start_val, name="ss.d.fwd"),
        self.builder.sub(start_val, stop_val, name="ss.d.bwd"),
        name="ss.diff"
    );
    astep = self.builder.select(
        step_pos,
        step_val,
        self.builder.sub(zero, step_val, name="ss.step.neg"),
        name="ss.astep"
    );
    n_num = self.builder.add(
        diff, self.builder.sub(astep, one, name="ss.am1"), name="ss.nnum"
    );
    n_raw = self.builder.sdiv(n_num, astep, name="ss.nraw");
    diff_pos = self.builder.icmp_signed(">", diff, zero, name="ss.dpos");
    n_val = self.builder.select(diff_pos, n_raw, zero, name="ss.n");

    alloc_size = self.builder.add(n_val, one, name="ss.alloc");
    self._set_rc_ctx("str_substr", "");
    new_str = self.builder.call(self.rc_alloc_fn, [alloc_size], name="ss.new");
    self._clear_rc_ctx();
    self._emit_set_type_tag(self.builder, new_str, "str");

    i_alloca = self.builder.alloca(i64, name="ss.i");
    k_alloca = self.builder.alloca(i64, name="ss.k");
    self.builder.store(start_val, i_alloca);
    self.builder.store(zero, k_alloca);
    loop_check = func.append_basic_block(name="ss.check");
    loop_body = func.append_basic_block(name="ss.body");
    loop_done = func.append_basic_block(name="ss.done");
    self.builder.branch(loop_check);

    self.builder.position_at_end(loop_check);
    cur_i = self.builder.load(i_alloca, name="ss.cur");
    fwd = self.builder.icmp_signed("<", cur_i, stop_val, name="ss.fwd");
    bwd = self.builder.icmp_signed(">", cur_i, stop_val, name="ss.bwd");
    in_range = self.builder.select(step_pos, fwd, bwd, name="ss.inrange");
    self.builder.cbranch(in_range, loop_body, loop_done);

    self.builder.position_at_end(loop_body);
    ch_ptr = self.builder.gep(target_val, [cur_i], name="ss.src.ch");
    ch = self.builder.load(ch_ptr, name="ss.ch");
    cur_k = self.builder.load(k_alloca, name="ss.curk");
    out_ptr = self.builder.gep(new_str, [cur_k], name="ss.out.ch");
    self.builder.store(ch, out_ptr);
    self.builder.store(self.builder.add(cur_k, one, name="ss.nextk"), k_alloca);
    self.builder.store(self.builder.add(cur_i, step_val, name="ss.nexti"), i_alloca);
    self.builder.branch(loop_check);

    self.builder.position_at_end(loop_done);
    null_ptr = self.builder.gep(new_str, [n_val], name="ss.null");
    self.builder.store(ir.Constant(i8, 0), null_ptr);
    return new_str;
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
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    slen = self.builder.call(strlen_fn, [str_val], name="strip.len");

    final_start = ir.Constant(i64, 0);
    if do_left {
        start_alloca = self.builder.alloca(i64, name="strip.start");
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
        end_alloca = self.builder.alloca(i64, name="strip.end");
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
    result_ptr = self.builder.call(self.rc_alloc_fn, [alloc_size], name="strip.result");
    self._clear_rc_ctx();
    self._emit_set_type_tag(self.builder, result_ptr, "str");

    src_ptr = self.builder.gep(str_val, [final_start], name="src.ptr");
    memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    self.builder.call(memcpy, [result_ptr, src_ptr, result_len]);

    null_ptr = self.builder.gep(result_ptr, [result_len], name="null.ptr");
    self.builder.store(ir.Constant(i8, 0), null_ptr);
    return result_ptr;
}

impl NaIRGenPass._codegen_str_split(
    str_val: ir.Value, sep_val: ir.Value
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

    self._set_rc_ctx("str_split", "");
    new_list = self.builder.call(helpers["new"], [], name="split.list");
    self._clear_rc_ctx();

    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    str_len = self.builder.call(strlen_fn, [str_val], name="str.len");
    sep_len = self.builder.call(strlen_fn, [sep_val], name="sep.len");
    memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    strncmp_fn = self._get_or_declare_extern(
        "strncmp", ir.IntType(32), [i8p, i8p, i64]
    );

    i_alloca = self.builder.alloca(i64, name="split.i");
    token_start_alloca = self.builder.alloca(i64, name="split.token.start");
    self.builder.store(ir.Constant(i64, 0), i_alloca);
    self.builder.store(ir.Constant(i64, 0), token_start_alloca);
    loop_check_bb = func.append_basic_block(name="split.check");
    loop_body_bb = func.append_basic_block(name="split.body");
    match_bb = func.append_basic_block(name="split.match");
    no_match_bb = func.append_basic_block(name="split.nomatch");
    loop_done_bb = func.append_basic_block(name="split.done");
    self.builder.branch(loop_check_bb);

    self.builder.position_at_end(loop_check_bb);
    cur_i = self.builder.load(i_alloca, name="cur.i");

    i_plus_sep = self.builder.add(cur_i, sep_len, name="i.plus.sep");
    can_match = self.builder.icmp_signed("<=", i_plus_sep, str_len, name="can.match");
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
    token_len = self.builder.sub(cur_i, ts, name="token.len");
    alloc_len = self.builder.add(token_len, ir.Constant(i64, 1), name="token.alloc");
    self._set_rc_ctx("str_split", "");
    token_ptr = self.builder.call(self.rc_alloc_fn, [alloc_len], name="token.ptr");
    self._clear_rc_ctx();
    src = self.builder.gep(str_val, [ts], name="token.src");
    self.builder.call(memcpy, [token_ptr, src, token_len]);
    null_pos = self.builder.gep(token_ptr, [token_len], name="token.null");
    self.builder.store(ir.Constant(i8, 0), null_pos);

    self._rc_call_with_ctx(helpers["append"], [new_list, token_ptr], op="str_split");

    new_i = self.builder.add(cur_i, sep_len, name="new.i");
    self.builder.store(new_i, i_alloca);
    self.builder.store(new_i, token_start_alloca);
    self.builder.branch(loop_check_bb);

    self.builder.position_at_end(no_match_bb);
    next_i = self.builder.add(cur_i, ir.Constant(i64, 1), name="next.i");
    self.builder.store(next_i, i_alloca);
    self.builder.branch(loop_check_bb);

    self.builder.position_at_end(loop_done_bb);
    final_ts = self.builder.load(token_start_alloca, name="final.ts");
    last_len = self.builder.sub(str_len, final_ts, name="last.len");
    last_alloc = self.builder.add(last_len, ir.Constant(i64, 1), name="last.alloc");
    self._set_rc_ctx("str_split", "");
    last_ptr = self.builder.call(self.rc_alloc_fn, [last_alloc], name="last.ptr");
    self._clear_rc_ctx();
    last_src = self.builder.gep(str_val, [final_ts], name="last.src");
    self.builder.call(memcpy, [last_ptr, last_src, last_len]);
    last_null = self.builder.gep(last_ptr, [last_len], name="last.null");
    self.builder.store(ir.Constant(i8, 0), last_null);
    self._rc_call_with_ctx(helpers["append"], [new_list, last_ptr], op="str_split");
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

    if "__jac_argc" not in self.extern_funcs {
        argc_global = ir.GlobalVariable(self.llvm_module, i32, name="__jac_argc");
        argc_global.initializer = ir.Constant(i32, 0);
        self.extern_funcs["__jac_argc"] = argc_global;
    }
    if "__jac_argv" not in self.extern_funcs {
        argv_global = ir.GlobalVariable(
            self.llvm_module, i8p.as_pointer(), name="__jac_argv"
        );
        argv_global.initializer = ir.Constant(i8p.as_pointer(), None);
        self.extern_funcs["__jac_argv"] = argv_global;
    }

    argc_global = self.extern_funcs["__jac_argc"];
    argv_global = self.extern_funcs["__jac_argv"];

    argc_i32 = self.builder.load(argc_global, name="argc.i32");
    argc = self.builder.sext(argc_i32, i64, name="argc");
    argv = self.builder.load(argv_global, name="argv");

    new_list = self.builder.call(helpers["new"], [], name="sys.argv.list");

    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);

    i_alloca = self.builder.alloca(i64, name="argv.i");
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

    slen = self.builder.call(strlen_fn, [arg_ptr], name="arg.len");
    alloc_size = self.builder.add(slen, ir.Constant(i64, 1), name="arg.alloc");
    self._set_rc_ctx("argv", "");
    rc_str = self.builder.call(self.rc_alloc_fn, [alloc_size], name="arg.str");
    self._clear_rc_ctx();
    self._emit_set_type_tag(self.builder, rc_str, "str");
    self.builder.call(memcpy_fn, [rc_str, arg_ptr, alloc_size]);

    self._rc_call_with_ctx(helpers["append"], [new_list, rc_str], op="argv");

    next_i = self.builder.add(cur_i, ir.Constant(i64, 1), name="argv.next");
    self.builder.store(next_i, i_alloca);
    self.builder.branch(loop_check);

    self.builder.position_at_end(loop_done);
    return new_list;
}

impl NaIRGenPass._emit_sys_exit(args: list[ir.Value]) -> (ir.Value | None) {
    i32 = ir.IntType(32);
    exit_fn = self._get_or_declare_extern("exit", ir.VoidType(), [i32]);

    if args {
        code = self._coerce_type(args[0], i32);
    } else {
        code = ir.Constant(i32, 0);
    }
    self.builder.call(exit_fn, [code]);
    self.builder.unreachable();
    return ir.Constant(ir.IntType(64), 0);
}

impl NaIRGenPass._emit_float_repr(fv: ir.Value) -> ir.Value {
    _repr = self.builder.call(self._float_repr_fn(), [fv], name="f.repr");
    self._mark_owned(_repr);
    return _repr;
}

impl NaIRGenPass._float_repr_fn -> ir.Function {
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
    strlen = self._get_or_declare_extern("strlen", i64, [i8p]);
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
        _strdup_hl = self._get_or_declare_extern("strdup", i8p, [i8p]);
        b.ret(b.call(_strdup_hl, [s_nan], name="fr.nan.dup"));
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
        _strdup_hl2 = self._get_or_declare_extern("strdup", i8p, [i8p]);
        b.ret(b.call(_strdup_hl2, [s_inf], name="fr.inf.dup"));
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
        _strdup_hl3 = self._get_or_declare_extern("strdup", i8p, [i8p]);
        b.ret(b.call(_strdup_hl3, [s_ninf], name="fr.ninf.dup"));
    } else {
        b.ret(s_ninf);
    }

    b.position_at_end(setup_bb);
    cap = ir.Constant(i64, 64);
    tmp = b.call(self.rc_alloc_fn, [cap], name="fr.tmp");
    endptr = b.alloca(i8p, name="fr.endptr");
    pvar = b.alloca(i32, name="fr.p");
    b.store(ir.Constant(i32, 0), pvar);
    loop_cond = fn.append_basic_block("fr.cond");
    loop_inc = fn.append_basic_block("fr.inc");
    loop_done = fn.append_basic_block("fr.done");
    b.branch(loop_cond);
    b.position_at_end(loop_cond);
    pv = b.load(pvar, name="fr.pv");
    b.call(snprintf, [tmp, cap, fmt_e, pv, d]);
    parsed = b.call(strtod, [tmp, endptr], name="fr.parsed");
    eq = b.fcmp_ordered("==", parsed, d, name="fr.eq");
    at_max = b.icmp_signed(">=", pv, ir.Constant(i32, 17), name="fr.atmax");
    b.cbranch(b.or_(eq, at_max, name="fr.stop"), loop_done, loop_inc);
    b.position_at_end(loop_inc);
    b.store(b.add(pv, ir.Constant(i32, 1)), pvar);
    b.branch(loop_cond);

    b.position_at_end(loop_done);
    pfin = b.load(pvar, name="fr.pfin");
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
    b.ret(tmp);

    b.position_at_end(fixed_bb);
    fr0 = b.sub(ndig, decpt, name="fr.frac0");
    is_neg = b.icmp_signed("<", fr0, ir.Constant(i64, 0), name="fr.fracneg");
    frac = b.select(is_neg, ir.Constant(i64, 0), fr0, name="fr.frac");
    if self._nogc_headerless() {
        _free_hl = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
        b.call(_free_hl, [tmp]);
    }
    fbuf = b.call(self.rc_alloc_fn, [cap], name="fr.fbuf");
    frac32 = b.trunc(frac, i32, name="fr.frac32");
    b.call(snprintf, [fbuf, cap, fmt_f, frac32, d]);
    is_int = b.icmp_signed("==", frac, ir.Constant(i64, 0), name="fr.isint");
    dot_bb = fn.append_basic_block("fr.adddot");
    ret_bb = fn.append_basic_block("fr.fixed.ret");
    b.cbranch(is_int, dot_bb, ret_bb);
    b.position_at_end(dot_bb);
    flen = b.call(strlen, [fbuf], name="fr.flen");
    b.store(ir.Constant(i8, 46), b.gep(fbuf, [flen], name="fr.dotp"));
    f1 = b.add(flen, ir.Constant(i64, 1), name="fr.f1");
    b.store(ir.Constant(i8, 48), b.gep(fbuf, [f1], name="fr.zerop"));
    f2 = b.add(flen, ir.Constant(i64, 2), name="fr.f2");
    b.store(ir.Constant(i8, 0), b.gep(fbuf, [f2], name="fr.nulp"));
    b.branch(ret_bb);
    b.position_at_end(ret_bb);
    b.ret(fbuf);

    self._builder = saved_builder;
    self._float_repr_function = fn;
    return fn;
}
