"""Print, string operations, and external function support."""
"""Get or declare an external C function (cached)."""
impl NaIRGenPass._get_or_declare_extern(
    name: str, ret_type: ir.Type, arg_types: list[ir.Type], var_arg: bool = False
) -> ir.Function {
    if name in self.extern_funcs {
        return self.extern_funcs[name];
    }
    # The function may already exist in the LLVM module — e.g. declared by
    # _declare_clib_ability from a user `import from "lib" { def ...; }`.
    # In that case, ir.Function() would raise DuplicatedNameError.
    # Look it up first; if found, re-use it directly.
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

# ─── Print Support ───────────────────────────────────────────
"""Get or create the printf external function declaration."""
impl NaIRGenPass._get_printf -> ir.Function {
    return self._get_or_declare_extern(
        "printf", ir.IntType(32), [ir.IntType(8).as_pointer()], var_arg=True
    );
}

"""Emit printf call for print()."""
impl NaIRGenPass._emit_print(nd: uni.FuncCall) -> (ir.Value | None) {
    printf = self._get_printf();
    params = nd.params or [];
    if not params {
        fmt = self._get_fmt_string("");
        fmt_ptr = self.builder.bitcast(fmt, ir.IntType(8).as_pointer());
        self.builder.call(printf, [fmt_ptr]);
        return ir.Constant(ir.IntType(64), 0);
    }
    # Build format string and collect args for all parameters
    fmt_parts = [];
    args = [];
    for (i, param) in enumerate(params) {
        val = self._codegen_expr(param);
        if val is None {
            continue;
        }

        # Add space separator between arguments (except before first)
        if i > 0 {
            fmt_parts.append(" ");
        }

        # Determine format specifier based on type
        if isinstance(val.type, ir.IntType) {
            # Promote any narrow integer (i1 bool, i8/i16/i32 — e.g. a foreign
            # `i32` return consumed inline) to i64 for the %lld varargs slot.
            if val.type.width == 1 {
                val = self.builder.zext(val, ir.IntType(64));
            } elif val.type.width < 64 {
                val = self.builder.sext(val, ir.IntType(64));
            }
            fmt_parts.append("%lld");
            args.append(val);
        } elif isinstance(val.type, ir.DoubleType) {
            # print(float): CPython str(float) shortest round-trip, not %f. (#6978 0.3)
            fmt_parts.append("%s");
            args.append(self._emit_float_repr(val));
        } elif isinstance(val.type, ir.FloatType) {
            # C `float` (f32) — widen to double, then shortest round-trip repr.
            val = self.builder.fpext(val, ir.DoubleType());
            fmt_parts.append("%s");
            args.append(self._emit_float_repr(val));
        } elif isinstance(val.type, ir.PointerType) {
            fmt_parts.append("%s");
            args.append(val);
        }
    }
    # Build complete format string and emit single printf call
    if fmt_parts {
        fmt_str = "".join(fmt_parts);
        fmt = self._get_fmt_string(fmt_str);
        fmt_ptr = self.builder.bitcast(fmt, ir.IntType(8).as_pointer());
        self.builder.call(printf, [fmt_ptr] + args);
        # RC: release owned temporaries (inline fstrings, concats) that were passed
        # directly to print() without being stored in a named local variable.
        # Named locals load from allocas, producing a new ir.Value without the
        # is_owned attribute, so this only fires for fresh temporaries.
        for _parg in args {
            if isinstance(_parg.type, ir.PointerType) and self._is_owned(_parg) {
                self._emit_rc_release_typed(_parg, op="print_tmp", loc="");
            }
        }
    }
    return ir.Constant(ir.IntType(64), 0);
}

"""Get or create a global format string for printf."""
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

"""Get or create a global format string for snprintf (no trailing newline)."""
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

# ─── Helper Methods ──────────────────────────────────────────
"""Generate code for a MultiString node (wraps String/FString)."""
impl NaIRGenPass._codegen_multistring(nd: uni.MultiString) -> (ir.Value | None) {
    if not nd.strings {
        return None;
    }
    # Single string — delegate directly
    if len(nd.strings) == 1 {
        part = nd.strings[0];
        if isinstance(part, uni.FString) {
            return self._codegen_fstring(part);
        }
        return self._codegen_string(part);
    }
    # Multiple strings — concatenate via string concat
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
            # Release the two input temps if we own them (rc=1 fresh allocs).
            # The concat borrowed them but did not retain them.
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

"""Create a global constant string and return an i8* pointer to it."""
impl NaIRGenPass._make_global_string(text: str, name_prefix: str = ".str") -> ir.Value {
    str_bytes = bytearray((text + "\0").encode("utf8"));
    i64 = ir.IntType(64);
    i8 = ir.IntType(8);
    i8_ptr = i8.as_pointer();
    i32 = ir.IntType(32);
    arr_type = ir.ArrayType(i8, len(str_bytes));
    # Embed RC 16-byte header: { i64 RC_SENTINEL, i64 dtor(=0), [N x i8] data }
    # This makes ptr-16 point to the sentinel, so rc_release/retain skip it.
    # dtor=0 means "no destructor" (plain free path in __rc_release_simple, never reached
    # for sentinels but kept for layout consistency).
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
    # Return pointer to the string data (field 2, offset +16 from struct start)
    gep = self.builder.gep(
        global_str,
        [ir.Constant(i32, 0), ir.Constant(i32, 2), ir.Constant(i32, 0)],
        name="str.data"
    );
    return gep;
}

"""Generate a string literal as a global constant, returning i8*.

Decode via `String.lit_value` — the same `ast.literal_eval`-based decoder the
sv pathway uses — so every escape form (\\n, \\t, \\xNN, \\uXXXX, \\U00XXXXXX,
\\N{...}, octal) resolves identically across pathways. Reusing the single
shared decoder keeps the na ⊆ sv guarantee true by construction rather than
re-deriving an inevitably-incomplete escape table here (regression: #6442).
"""
impl NaIRGenPass._codegen_string(nd: uni.String) -> (ir.Value | None) {
    # A byte-string literal (b"...") decodes to a Python `bytes` via lit_value;
    # emit it as a length-aware bytes value rather than a NUL-terminated str.
    _lit = nd.lit_value;
    if isinstance(_lit, bytes) {
        return self._make_global_bytes(_lit);
    }
    return self._make_global_string(_lit);
}

"""Generate f-string by building a printf-style format string and calling snprintf."""
impl NaIRGenPass._codegen_fstring(nd: uni.FString) -> (ir.Value | None) {
    fmt_parts: list[str] = [];
    args: list[ir.Value] = [];
    for part in nd.parts {
        if isinstance(part, uni.String) {
            # Literal text portion — `lit_value` decodes escapes the same way
            # the sv pathway does (ast.literal_eval), covering \xNN/\uXXXX/etc.
            text = part.lit_value;
            # Escape % for printf format
            text = text.replace("%", "%%");
            fmt_parts.append(text);
        } elif isinstance(part, uni.FormattedValue) {
            val = self._codegen_expr(part.format_part);
            if val is None {
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
                # f"{float}": CPython str(float) shortest round-trip, not %f. (#6978 0.3)
                fmt_parts.append("%s");
                args.append(self._emit_float_repr(val));
            } elif isinstance(val.type, ir.PointerType) {
                fmt_parts.append("%s");
                args.append(val);
            }
        }
    }
    fmt_str = "".join(fmt_parts);
    # Allocate buffer via rc_alloc (RC-managed)
    buf_size = ir.Constant(ir.IntType(64), 1024);
    _fstr_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    buf = self._rc_call_with_ctx(
        self.rc_alloc_fn, [buf_size], op="fstring", loc=_fstr_loc, name="fstr.buf"
    );
    self._emit_set_type_tag(self.builder, buf, "str");
    # Call snprintf(buf, 1024, fmt, args...)
    snprintf_fn = self._get_or_declare_extern(
        "snprintf",
        ir.IntType(32),
        [ir.IntType(8).as_pointer(), ir.IntType(64), ir.IntType(8).as_pointer()],
        var_arg=True
    );
    fmt_global = self._make_global_string(fmt_str, name_prefix=".fstr.fmt");
    call_args: list[ir.Value] = [buf, buf_size, fmt_global];
    for a in args {
        call_args.append(a);
    }
    self.builder.call(snprintf_fn, call_args, name="fstr.len");
    # RC: caller owns this freshly-allocated fstring buffer (rc=1 from malloc).
    # Mark it so the assign handler skips the extra RETAIN (avoiding rc=2 leak).
    self._mark_owned(buf);
    return buf;
}

# ─── Phase 3: Objects ─────────────────────────────────────────
"""String character access: s[i] -> new single-char string."""
impl NaIRGenPass._codegen_string_index(
    target_val: ir.Value, index_val: ir.Value
) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    # GEP to the character
    char_ptr = self.builder.gep(target_val, [index_val], name="char.ptr");
    char_val = self.builder.load(char_ptr, name="char.val");
    # Allocate a 2-byte string: [char, null] via rc_alloc (RC-managed)
    two = ir.Constant(i64, 2);
    _sidx_loc = getattr(target_val, 'jac_loc', '');
    new_str = self._rc_call_with_ctx(
        self.rc_alloc_fn, [two], op="str_index", loc=_sidx_loc, name="char.str"
    );
    self._emit_set_type_tag(self.builder, new_str, "str");
    self.builder.store(char_val, new_str);
    # Store null terminator at index 1
    one_ptr = self.builder.gep(new_str, [ir.Constant(i64, 1)], name="null.ptr");
    self.builder.store(ir.Constant(i8, 0), one_ptr);
    # RC: caller owns this freshly-allocated single-char string (rc=1).
    self._mark_owned(new_str);
    return new_str;
}

"""List slicing: lst[start:stop:step] → new list with copied elements."""
impl NaIRGenPass._codegen_list_slice(
    target_val: ir.Value, slice_node: object, elem_type_name: str
) -> (ir.Value | None) {
    helpers = self.list_helpers.get(elem_type_name);
    if helpers is None {
        return None;
    }
    i64 = ir.IntType(64);
    func = self.builder.basic_block.function;
    # Get source list length
    src_len = self.builder.call(helpers["len"], [target_val], name="sl.srclen");
    # Compute start (default 0)
    start_val: ir.Value = ir.Constant(i64, 0);
    if slice_node?.start is not None {
        sv = self._codegen_expr(slice_node.start);
        if sv is not None {
            start_val = self._coerce_type(sv, i64);
        }
    }
    # Compute stop (default len)
    stop_val: ir.Value = src_len;
    if slice_node?.stop is not None {
        sv = self._codegen_expr(slice_node.stop);
        if sv is not None {
            stop_val = self._coerce_type(sv, i64);
        }
    }
    # Compute step (default 1)
    step_val: ir.Value = ir.Constant(i64, 1);
    if slice_node?.step is not None {
        sv = self._codegen_expr(slice_node.step);
        if sv is not None {
            step_val = self._coerce_type(sv, i64);
        }
    }
    # Create new list
    new_list = self.builder.call(helpers["new"], [], name="sl.new");
    # Loop: i = start; i < stop; i += step
    i_alloca = self.builder.alloca(i64, name="sl.i");
    self.builder.store(start_val, i_alloca);
    loop_check = func.append_basic_block(name="sl.check");
    loop_body = func.append_basic_block(name="sl.body");
    loop_done = func.append_basic_block(name="sl.done");
    self.builder.branch(loop_check);
    # Check: i < stop
    self.builder.position_at_end(loop_check);
    cur_i = self.builder.load(i_alloca, name="sl.cur");
    in_range = self.builder.icmp_signed("<", cur_i, stop_val, name="sl.inrange");
    self.builder.cbranch(in_range, loop_body, loop_done);
    # Body: get element, append to new list
    self.builder.position_at_end(loop_body);
    elem = self.builder.call(helpers["get"], [target_val, cur_i], name="sl.elem");
    self._rc_call_with_ctx(helpers["append"], [new_list, elem], op="list_slice");
    # i += step
    next_i = self.builder.add(cur_i, step_val, name="sl.next");
    self.builder.store(next_i, i_alloca);
    self.builder.branch(loop_check);
    # Done
    self.builder.position_at_end(loop_done);
    # Track new list type
    return new_list;
}

"""String slicing: s[start:stop:step] → new substring."""
impl NaIRGenPass._codegen_string_slice(
    target_val: ir.Value, slice_node: object
) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    # Get string length
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    src_len = self.builder.call(strlen_fn, [target_val], name="ss.len");
    # Compute start (default 0)
    start_val: ir.Value = ir.Constant(i64, 0);
    if slice_node?.start is not None {
        sv = self._codegen_expr(slice_node.start);
        if sv is not None {
            start_val = self._coerce_type(sv, i64);
        }
    }
    # Compute stop (default len)
    stop_val: ir.Value = src_len;
    if slice_node?.stop is not None {
        sv = self._codegen_expr(slice_node.stop);
        if sv is not None {
            stop_val = self._coerce_type(sv, i64);
        }
    }
    # For step=1 (basic substring): use memcpy
    # slice_len = stop - start
    slice_len = self.builder.sub(stop_val, start_val, name="ss.slen");
    alloc_size = self.builder.add(slice_len, ir.Constant(i64, 1), name="ss.alloc");
    self._set_rc_ctx("str_substr", "");
    new_str = self.builder.call(self.rc_alloc_fn, [alloc_size], name="ss.new");
    self._clear_rc_ctx();
    self._emit_set_type_tag(self.builder, new_str, "str");
    # src_ptr = target_val + start
    src_ptr = self.builder.gep(target_val, [start_val], name="ss.src");
    self.builder.call(memcpy_fn, [new_str, src_ptr, slice_len]);
    # Null terminate
    null_ptr = self.builder.gep(new_str, [slice_len], name="ss.null");
    self.builder.store(ir.Constant(i8, 0), null_ptr);
    return new_str;
}

"""i1 predicate: should char `ch` (i8) be stripped?

When `charset` is None this is the whitespace test (str.strip()/lstrip()/rstrip()
with no argument). When `charset` is an i8* it is membership in that set, matching
CPython's `s.strip(chars)` — `strchr(charset, ch) != NULL`. The stripping loops
only test bytes inside the string body (never the terminator), so a '\\0' never
reaches here and strchr's match-on-NUL quirk cannot fire. (#6943 NA-9)
"""
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

"""String strip: remove leading/trailing whitespace (no-arg form)."""
impl NaIRGenPass._codegen_str_strip(str_val: ir.Value) -> (ir.Value | None) {
    return self._codegen_str_strip_chars(str_val, None, True, True);
}

"""General string strip backing strip()/lstrip()/rstrip(), with or without a
character set. `charset` is None for the whitespace form or an i8* for the
set form; `do_left`/`do_right` select which ends are trimmed. A single
implementation keeps strip/lstrip/rstrip congruent across the no-arg and
char-set cases (#6943 NA-9)."""
impl NaIRGenPass._codegen_str_strip_chars(
    str_val: ir.Value, charset: (ir.Value | None), do_left: bool, do_right: bool
) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    func = self.builder.function;
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    slen = self.builder.call(strlen_fn, [str_val], name="strip.len");
    # Leading scan: advance final_start over strip chars (only if do_left).
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
    # Trailing scan: retreat final_end over strip chars (only if do_right).
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
    # Allocate result: end - start + 1 (for null terminator)
    result_len = self.builder.sub(final_end, final_start, name="result.len");
    alloc_size = self.builder.add(result_len, ir.Constant(i64, 1), name="alloc.size");
    self._set_rc_ctx("str_strip", "");
    result_ptr = self.builder.call(self.rc_alloc_fn, [alloc_size], name="strip.result");
    self._clear_rc_ctx();
    self._emit_set_type_tag(self.builder, result_ptr, "str");
    # memcpy from str_val + start to result
    src_ptr = self.builder.gep(str_val, [final_start], name="src.ptr");
    memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    self.builder.call(memcpy, [result_ptr, src_ptr, result_len]);
    # Null-terminate
    null_ptr = self.builder.gep(result_ptr, [result_len], name="null.ptr");
    self.builder.store(ir.Constant(i8, 0), null_ptr);
    return result_ptr;
}

"""String split by separator, returns list[str]."""
impl NaIRGenPass._codegen_str_split(
    str_val: ir.Value, sep_val: ir.Value
) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    func = self.builder.function;
    # Ensure list[str] helpers exist (str = i8* = "ptr" element type)
    self._emit_list_helpers("ptr", i8p);
    helpers = self.list_helpers.get("ptr");
    if helpers is None {
        return None;
    }
    # Create a new list
    self._set_rc_ctx("str_split", "");
    new_list = self.builder.call(helpers["new"], [], name="split.list");
    self._clear_rc_ctx();
    # Get lengths
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    str_len = self.builder.call(strlen_fn, [str_val], name="str.len");
    sep_len = self.builder.call(strlen_fn, [sep_val], name="sep.len");
    memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    strncmp_fn = self._get_or_declare_extern(
        "strncmp", ir.IntType(32), [i8p, i8p, i64]
    );
    # Loop: scan through string, find separator matches
    # i = current position, token_start = start of current token
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
    # Check: i <= str_len - sep_len (can still find separator)
    self.builder.position_at_end(loop_check_bb);
    cur_i = self.builder.load(i_alloca, name="cur.i");
    # Check if i + sep_len <= str_len
    i_plus_sep = self.builder.add(cur_i, sep_len, name="i.plus.sep");
    can_match = self.builder.icmp_signed("<=", i_plus_sep, str_len, name="can.match");
    self.builder.cbranch(can_match, loop_body_bb, loop_done_bb);
    # Body: compare substring
    self.builder.position_at_end(loop_body_bb);
    substr_ptr = self.builder.gep(str_val, [cur_i], name="substr.ptr");
    cmp_result = self.builder.call(
        strncmp_fn, [substr_ptr, sep_val, sep_len], name="cmp"
    );
    is_match = self.builder.icmp_signed(
        "==", cmp_result, ir.Constant(ir.IntType(32), 0), name="is.match"
    );
    self.builder.cbranch(is_match, match_bb, no_match_bb);
    # Match: extract token from token_start to i, append to list
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
    # Append token to list
    self._rc_call_with_ctx(helpers["append"], [new_list, token_ptr], op="str_split");
    # Advance i past separator, update token_start
    new_i = self.builder.add(cur_i, sep_len, name="new.i");
    self.builder.store(new_i, i_alloca);
    self.builder.store(new_i, token_start_alloca);
    self.builder.branch(loop_check_bb);
    # No match: advance i by 1
    self.builder.position_at_end(no_match_bb);
    next_i = self.builder.add(cur_i, ir.Constant(i64, 1), name="next.i");
    self.builder.store(next_i, i_alloca);
    self.builder.branch(loop_check_bb);
    # Done: append the last token (from token_start to end)
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

# ─── sys Module Support ──────────────────────────────────────
"""Build a list[str] from the C argc/argv globals stored by main().

Emits inline IR that:
1. Loads __jac_argc (i32) and __jac_argv (ptr) globals
2. Creates a new list[str]
3. Loops i = 0..argc, loading argv[i] (char*), copying it
   into an RC-managed string, and appending to the list
4. Returns the list[str] pointer
"""
impl NaIRGenPass._emit_sys_argv -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    func = self.builder.function;

    # Ensure list[str] helpers exist
    self._emit_list_helpers("ptr", i8p);
    helpers = self.list_helpers.get("ptr");
    if helpers is None {
        return None;
    }

    # Define the __jac_argc / __jac_argv globals (populated by injected main)
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

    # Load argc and argv
    argc_i32 = self.builder.load(argc_global, name="argc.i32");
    argc = self.builder.sext(argc_i32, i64, name="argc");
    argv = self.builder.load(argv_global, name="argv");

    # Create new list[str]
    new_list = self.builder.call(helpers["new"], [], name="sys.argv.list");

    # Get strlen, memcpy
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);

    # Loop: for i = 0; i < argc; i++
    i_alloca = self.builder.alloca(i64, name="argv.i");
    self.builder.store(ir.Constant(i64, 0), i_alloca);

    loop_check = func.append_basic_block(name="argv.check");
    loop_body = func.append_basic_block(name="argv.body");
    loop_done = func.append_basic_block(name="argv.done");

    self.builder.branch(loop_check);

    # Check: i < argc
    self.builder.position_at_end(loop_check);
    cur_i = self.builder.load(i_alloca, name="cur.i");
    in_range = self.builder.icmp_signed("<", cur_i, argc, name="argv.inrange");
    self.builder.cbranch(in_range, loop_body, loop_done);

    # Body: copy argv[i] into RC string, append to list
    self.builder.position_at_end(loop_body);
    # argv[i] is a char* — load it from the argv array
    arg_ptr_ptr = self.builder.gep(argv, [cur_i], name="argv.ptr.ptr");
    arg_ptr = self.builder.load(arg_ptr_ptr, name="argv.ptr");

    # Get length, allocate RC string, copy
    slen = self.builder.call(strlen_fn, [arg_ptr], name="arg.len");
    alloc_size = self.builder.add(slen, ir.Constant(i64, 1), name="arg.alloc");
    self._set_rc_ctx("argv", "");
    rc_str = self.builder.call(self.rc_alloc_fn, [alloc_size], name="arg.str");
    self._clear_rc_ctx();
    self._emit_set_type_tag(self.builder, rc_str, "str");
    self.builder.call(memcpy_fn, [rc_str, arg_ptr, alloc_size]);

    # Append to list
    self._rc_call_with_ctx(helpers["append"], [new_list, rc_str], op="argv");

    # i++
    next_i = self.builder.add(cur_i, ir.Constant(i64, 1), name="argv.next");
    self.builder.store(next_i, i_alloca);
    self.builder.branch(loop_check);

    # Done
    self.builder.position_at_end(loop_done);
    return new_list;
}

"""Emit sys.exit(code) as a call to libc exit()."""
impl NaIRGenPass._emit_sys_exit(args: list[ir.Value]) -> (ir.Value | None) {
    i32 = ir.IntType(32);
    exit_fn = self._get_or_declare_extern("exit", ir.VoidType(), [i32]);
    # Default exit code is 0
    if args {
        code = self._coerce_type(args[0], i32);
    } else {
        code = ir.Constant(i32, 0);
    }
    self.builder.call(exit_fn, [code]);
    self.builder.unreachable();
    return ir.Constant(ir.IntType(64), 0);
}

# ─── Float repr (#6978 Phase 0.3) ────────────────────────────
"""Emit a call to the (lazily built) __jac_float_repr helper for a double."""
impl NaIRGenPass._emit_float_repr(fv: ir.Value) -> ir.Value {
    return self.builder.call(self._float_repr_fn(), [fv], name="f.repr");
}

"""Build (once) `i8* __jac_float_repr(double)` producing CPython's `repr(float)`:
the shortest decimal that round-trips back to the exact double, replacing the
lossy `%g` (`str(1.0)` was "1" on na vs "1.0" on sv). Strategy mirrors what a
Ryu/Grisu pass would yield but leans on libc's correctly-rounded printf: find
the smallest precision p in [0,17] whose `%.*e` rendering re-parses (`strtod`)
to the exact input, then reformat in CPython's `'r'` style -- exponential when
decpt<=-4 or decpt>16 (the winning `%.*e` buffer already matches CPython there),
else fixed `%.*f` with a trailing `.0` for integral values (`Py_DTSF_ADD_DOT_0`).
nan/inf/-inf are spelled as CPython does. One helper per module (memoized)."""
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
    # Build with a private builder, but point self.builder at it so the
    # _make_global_string / extern helpers emit into this function, not the
    # caller that triggered the lazy build.
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

    # ── special cases: nan / +inf / -inf (returned globals carry the RC
    # sentinel header, so the caller may treat them as owned strings) ──
    is_nan = b.not_(b.fcmp_ordered("==", d, d, name="fr.ord"), name="fr.isnan");
    nan_bb = fn.append_basic_block("fr.nan");
    chk_pinf = fn.append_basic_block("fr.chk.pinf");
    b.cbranch(is_nan, nan_bb, chk_pinf);
    b.position_at_end(nan_bb);
    b.ret(s_nan);
    b.position_at_end(chk_pinf);
    pinf = ir.Constant(f64, float("inf"));
    ninf = ir.Constant(f64, float("-inf"));
    is_pinf = b.fcmp_ordered("==", d, pinf, name="fr.ispinf");
    pinf_bb = fn.append_basic_block("fr.pinf");
    chk_ninf = fn.append_basic_block("fr.chk.ninf");
    b.cbranch(is_pinf, pinf_bb, chk_ninf);
    b.position_at_end(pinf_bb);
    b.ret(s_inf);
    b.position_at_end(chk_ninf);
    is_ninf = b.fcmp_ordered("==", d, ninf, name="fr.isninf");
    ninf_bb = fn.append_basic_block("fr.ninf");
    setup_bb = fn.append_basic_block("fr.setup");
    b.cbranch(is_ninf, ninf_bb, setup_bb);
    b.position_at_end(ninf_bb);
    b.ret(s_ninf);

    # ── shortest precision search: smallest p whose %.*e re-parses exactly ──
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

    # ── decpt = exp + 1; ndigits = p + 1; pick notation per CPython 'r' ──
    b.position_at_end(loop_done);
    pfin = b.load(pvar, name="fr.pfin");
    ndig = b.add(b.zext(pfin, i64), ir.Constant(i64, 1), name="fr.ndig");
    epos = b.call(strchr, [tmp, ir.Constant(i32, 101)], name="fr.epos");  # 'e'
    eptr = b.gep(epos, [ir.Constant(i64, 1)], name="fr.eptr");
    expo = b.call(strtol, [eptr, endptr, ir.Constant(i32, 10)], name="fr.exp");
    decpt = b.add(expo, ir.Constant(i64, 1), name="fr.decpt");
    lo = b.icmp_signed("<=", decpt, ir.Constant(i64, -4), name="fr.lo");
    hi = b.icmp_signed(">", decpt, ir.Constant(i64, 16), name="fr.hi");
    use_exp = b.or_(lo, hi, name="fr.useexp");
    exp_bb = fn.append_basic_block("fr.exp.out");
    fixed_bb = fn.append_basic_block("fr.fixed");
    b.cbranch(use_exp, exp_bb, fixed_bb);

    # exponential: tmp already holds the winning %.*e rendering, which glibc
    # spells exactly as CPython repr (lowercase e, signed >=2-digit exponent,
    # no trailing .0).
    b.position_at_end(exp_bb);
    b.ret(tmp);

    # fixed: %.*f with frac = max(0, ndigits - decpt); append ".0" if integral.
    b.position_at_end(fixed_bb);
    fr0 = b.sub(ndig, decpt, name="fr.frac0");
    is_neg = b.icmp_signed("<", fr0, ir.Constant(i64, 0), name="fr.fracneg");
    frac = b.select(is_neg, ir.Constant(i64, 0), fr0, name="fr.frac");
    fbuf = b.call(self.rc_alloc_fn, [cap], name="fr.fbuf");
    frac32 = b.trunc(frac, i32, name="fr.frac32");
    b.call(snprintf, [fbuf, cap, fmt_f, frac32, d]);
    is_int = b.icmp_signed("==", frac, ir.Constant(i64, 0), name="fr.isint");
    dot_bb = fn.append_basic_block("fr.adddot");
    ret_bb = fn.append_basic_block("fr.fixed.ret");
    b.cbranch(is_int, dot_bb, ret_bb);
    b.position_at_end(dot_bb);
    flen = b.call(strlen, [fbuf], name="fr.flen");
    b.store(ir.Constant(i8, 46), b.gep(fbuf, [flen], name="fr.dotp"));  # '.'
    f1 = b.add(flen, ir.Constant(i64, 1), name="fr.f1");
    b.store(ir.Constant(i8, 48), b.gep(fbuf, [f1], name="fr.zerop"));  # '0'
    f2 = b.add(flen, ir.Constant(i64, 2), name="fr.f2");
    b.store(ir.Constant(i8, 0), b.gep(fbuf, [f2], name="fr.nulp"));
    b.branch(ret_bb);
    b.position_at_end(ret_bb);
    b.ret(fbuf);

    self._builder = saved_builder;
    self._float_repr_function = fn;
    return fn;
}
# ─── Phase 8: Entry Block ────────────────────────────────────
