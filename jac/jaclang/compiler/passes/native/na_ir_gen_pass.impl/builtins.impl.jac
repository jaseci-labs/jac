"""Print, string operations, and external function support."""
"""Get or declare an external C function (cached)."""
impl NaIRGenPass._get_or_declare_extern(
    name: str, ret_type: ir.Type, arg_types: list[ir.Type], var_arg: bool = False
) -> ir.Function {
    if name in self.extern_funcs {
        return self.extern_funcs[name];
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
        if isinstance(val.type, ir.IntType) and val.type.width == 64 {
            fmt_parts.append("%lld");
            args.append(val);
        } elif isinstance(val.type, ir.DoubleType) {
            fmt_parts.append("%f");
            args.append(val);
        } elif isinstance(val.type, ir.IntType) and val.type.width == 1 {
            val = self.builder.zext(val, ir.IntType(64));
            fmt_parts.append("%lld");
            args.append(val);
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
            result = self._emit_binary_op(Tok.PLUS, result, val);
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
    # Embed RC sentinel header: { i64 RC_SENTINEL, [N x i8] data }
    # This makes ptr-8 point to the sentinel, so rc_release/retain skip it.
    struct_type = ir.LiteralStructType([i64, arr_type]);
    sentinel_val = ir.Constant(i64, 0x7FFFFFFFFFFFFFFF);
    c_str = ir.Constant(arr_type, str_bytes);
    struct_val = ir.Constant(struct_type, [sentinel_val, c_str]);
    global_str = ir.GlobalVariable(
        self.llvm_module, struct_type, name=f"{name_prefix}.{self._str_count}"
    );
    self._str_count = self._str_count + 1;
    global_str.linkage = "private";
    global_str.global_constant = True;
    global_str.initializer = struct_val;
    # Return pointer to the string data (field 1, offset +8 from struct start)
    gep = self.builder.gep(
        global_str,
        [ir.Constant(i32, 0), ir.Constant(i32, 1), ir.Constant(i32, 0)],
        name="str.data"
    );
    return gep;
}

"""Generate a string literal as a global constant, returning i8*."""
impl NaIRGenPass._codegen_string(nd: uni.String) -> (ir.Value | None) {
    raw = nd.value;
    # Strip quotes for standalone string literals
    if len(raw) >= 6 and (raw[:3] == '"""' or raw[:3] == "'''") {
        text = raw[3:-3];
    } elif len(raw) >= 2 and (raw[0] == '"' or raw[0] == "'") {
        text = raw[1:-1];
    } else {
        # F-string literal parts have no quotes
        text = raw;
    }
    # Handle common escape sequences
    text = text.replace("\\n", "\n");
    text = text.replace("\\t", "\t");
    text = text.replace("\\\\", "\\");
    text = text.replace('\\"', '"');
    text = text.replace("\\'", "'");
    return self._make_global_string(text);
}

"""Generate f-string by building a printf-style format string and calling snprintf."""
impl NaIRGenPass._codegen_fstring(nd: uni.FString) -> (ir.Value | None) {
    fmt_parts: list[str] = [];
    args: list[ir.Value] = [];
    for part in nd.parts {
        if isinstance(part, uni.String) {
            # Literal text portion — value has no quotes for fstring parts
            raw = part.value;
            if len(raw) >= 2 and (raw[0] == '"' or raw[0] == "'") {
                text = raw[1:-1];
            } else {
                text = raw;
            }
            text = text.replace("\\n", "\n");
            text = text.replace("\\t", "\t");
            text = text.replace("\\\\", "\\");
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
                fmt_parts.append("%f");
                args.append(val);
            } elif isinstance(val.type, ir.PointerType) {
                fmt_parts.append("%s");
                args.append(val);
            }
        }
    }
    fmt_str = "".join(fmt_parts);
    # Allocate buffer via rc_alloc (RC-managed)
    buf_size = ir.Constant(ir.IntType(64), 1024);
    buf = self.builder.call(self.rc_alloc_fn, [buf_size], name="fstr.buf");
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
    new_str = self.builder.call(self.rc_alloc_fn, [two], name="char.str");
    self.builder.store(char_val, new_str);
    # Store null terminator at index 1
    one_ptr = self.builder.gep(new_str, [ir.Constant(i64, 1)], name="null.ptr");
    self.builder.store(ir.Constant(i8, 0), one_ptr);
    return new_str;
}

"""String strip: remove leading/trailing whitespace."""
impl NaIRGenPass._codegen_str_strip(str_val: ir.Value) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    i1 = ir.IntType(1);
    func = self.builder.function;
    # Get string length
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    slen = self.builder.call(strlen_fn, [str_val], name="strip.len");
    # Find start index: skip whitespace from beginning
    # We use a simple loop: start = 0; while start < len and (s[start] == ' ' or s[start] == '\t' or s[start] == '\n'): start++
    start_alloca = self.builder.alloca(i64, name="strip.start");
    self.builder.store(ir.Constant(i64, 0), start_alloca);
    # Loop to find start: skip leading whitespace
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
    is_space = self.builder.icmp_signed("==", ch, ir.Constant(i8, 32), name="is.space");
    is_tab = self.builder.icmp_signed("==", ch, ir.Constant(i8, 9), name="is.tab");
    is_nl = self.builder.icmp_signed("==", ch, ir.Constant(i8, 10), name="is.nl");
    is_cr = self.builder.icmp_signed("==", ch, ir.Constant(i8, 13), name="is.cr");
    is_ws = self.builder.or_(is_space, is_tab, name="ws1");
    is_ws = self.builder.or_(is_ws, is_nl, name="ws2");
    is_ws = self.builder.or_(is_ws, is_cr, name="ws3");
    self.builder.cbranch(is_ws, start_inc_bb, start_done_bb);
    # Only increment when whitespace
    self.builder.position_at_end(start_inc_bb);
    next_start = self.builder.add(start_val, ir.Constant(i64, 1), name="next.start");
    self.builder.store(next_start, start_alloca);
    self.builder.branch(start_check_bb);
    # Find end index: skip trailing whitespace
    self.builder.position_at_end(start_done_bb);
    final_start = self.builder.load(start_alloca, name="final.start");
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
    e_space = self.builder.icmp_signed("==", ech, ir.Constant(i8, 32), name="e.space");
    e_tab = self.builder.icmp_signed("==", ech, ir.Constant(i8, 9), name="e.tab");
    e_nl = self.builder.icmp_signed("==", ech, ir.Constant(i8, 10), name="e.nl");
    e_cr = self.builder.icmp_signed("==", ech, ir.Constant(i8, 13), name="e.cr");
    e_ws = self.builder.or_(e_space, e_tab, name="ews1");
    e_ws = self.builder.or_(e_ws, e_nl, name="ews2");
    e_ws = self.builder.or_(e_ws, e_cr, name="ews3");
    self.builder.cbranch(e_ws, end_dec_bb, end_done_bb);
    # Only decrement when whitespace
    self.builder.position_at_end(end_dec_bb);
    self.builder.store(prev_end, end_alloca);
    self.builder.branch(end_check_bb);
    self.builder.position_at_end(end_done_bb);
    final_end = self.builder.load(end_alloca, name="final.end");
    # Allocate result: end - start + 1 (for null terminator)
    result_len = self.builder.sub(final_end, final_start, name="result.len");
    alloc_size = self.builder.add(result_len, ir.Constant(i64, 1), name="alloc.size");
    result_ptr = self.builder.call(self.rc_alloc_fn, [alloc_size], name="strip.result");
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
    new_list = self.builder.call(helpers["new"], [], name="split.list");
    # Get lengths
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    str_len = self.builder.call(strlen_fn, [str_val], name="str.len");
    sep_len = self.builder.call(strlen_fn, [sep_val], name="sep.len");
    memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    strncmp_fn = self._get_or_declare_extern("strncmp", ir.IntType(32), [i8p, i8p, i64]);
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
    token_ptr = self.builder.call(self.rc_alloc_fn, [alloc_len], name="token.ptr");
    src = self.builder.gep(str_val, [ts], name="token.src");
    self.builder.call(memcpy, [token_ptr, src, token_len]);
    null_pos = self.builder.gep(token_ptr, [token_len], name="token.null");
    self.builder.store(ir.Constant(i8, 0), null_pos);
    # Append token to list
    self.builder.call(helpers["append"], [new_list, token_ptr]);
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
    last_ptr = self.builder.call(self.rc_alloc_fn, [last_alloc], name="last.ptr");
    last_src = self.builder.gep(str_val, [final_ts], name="last.src");
    self.builder.call(memcpy, [last_ptr, last_src, last_len]);
    last_null = self.builder.gep(last_ptr, [last_len], name="last.null");
    self.builder.store(ir.Constant(i8, 0), last_null);
    self.builder.call(helpers["append"], [new_list, last_ptr]);
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
    rc_str = self.builder.call(self.rc_alloc_fn, [alloc_size], name="arg.str");
    self.builder.call(memcpy_fn, [rc_str, arg_ptr, alloc_size]);

    # Append to list
    self.builder.call(helpers["append"], [new_list, rc_str]);

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
# ─── Phase 8: Entry Block ────────────────────────────────────
