"""Function call codegen including builtins and method calls."""

"""Resolve a type name string to an LLVM type.

Checks type_map (primitives), then struct_types (user-defined objs),
falling back to i64 for unknown types.
"""
impl NaIRGenPass._resolve_type_str(type_name: str) -> ir.Type {
    if type_name in self.type_map {
        return self.type_map[type_name];
    }
    if type_name in self.struct_types {
        return self.struct_types[type_name].as_pointer();
    }
    return ir.IntType(64);
}

"""Resolved callee signature for a call site.

Consumes the checker-stamped `FuncCall.callee_decl` (Phase 4, analysis
centralization). Call nodes synthesized after type checking (desugared
pipe-forward) carry no stamp; for those the declaration is recovered
through the target's stored `.sym` - a stamped-fact read, mirroring how
`call_kind` is classified on the spot for the same nodes.
"""
impl NaIRGenPass._callee_sig_of(nd: uni.FuncCall) -> (uni.FuncSignature | None) {
    decl = nd.callee_decl;
    if decl is None {
        sym: (uni.Symbol | None) = None;
        if isinstance(nd.target, uni.AstSymbolNode) {
            sym = nd.target.sym;
        } elif isinstance(nd.target, uni.AtomTrailer)
        and isinstance(nd.target.right, uni.AstSymbolNode) {
            sym = nd.target.right.sym;
        }
        if sym is not None and sym.defn {
            cand = sym.defn[0];
            if isinstance(cand, uni.Ability) {
                decl = cand;
            } elif isinstance(cand.parent, uni.Ability) {
                decl = cand.parent;
            }
        }
    }
    sig = decl.signature if decl is not None else None;
    return sig if isinstance(sig, uni.FuncSignature) else None;
}

"""Fill omitted trailing parameters at a call site from the resolved
callee's default-value expressions (FuncCall.callee_decl, the
checker-stamped fact). Used by both free-function and method dispatch;
`skip_self` accounts for the implicit receiver already in `args`."""
impl NaIRGenPass._fill_default_args(
    nd: uni.FuncCall, func: ir.Function, args: list, skip_self: bool = False
) -> None {
    callee_sig = self._callee_sig_of(nd);
    if len(args) >= len(func.args) {
        return;
    }
    if callee_sig is None {
        while len(args) < len(func.args) {
            args.append(ir.Constant(func.args[len(args)].type, 0));
        }
        return;
    }
    sig_params = callee_sig.get_parameters();
    base = len(args) - 1 if skip_self else len(args);
    for pix in range(base, len(sig_params)) {
        expected_type = func.args[len(args)].type
            if len(args) < len(func.args)
            else ir.IntType(64);
        p = sig_params[pix];
        if p.value is not None {
            dval = self._codegen_expr(p.value);
            if dval is not None {
                args.append(self._coerce_type(dval, expected_type));
            } else {
                args.append(ir.Constant(expected_type, 0));
            }
        } else {
            args.append(ir.Constant(expected_type, 0));
        }
    }
}

"""Evaluate a call node's argument expressions in order, dropping any
that failed to lower (their own diagnostics already fired)."""
impl NaIRGenPass._codegen_call_args(nd: uni.FuncCall) -> list {
    arg_vals: list[ir.Value] = [];
    for param in (nd.params or []) {
        v = self._codegen_expr(param);
        if v is not None {
            arg_vals.append(v);
        }
    }
    return arg_vals;
}

"""Take a reference for a slot that is about to own `value`: a BORROWED
value is retained; an OWNED value's +1 transfers to the slot as-is
(compiler/ownership.jac invariant). Non-pointer values are untouched."""
impl NaIRGenPass._emit_take_ref(value: ir.Value, op: str, loc: str = "") -> None {
    if isinstance(value.type, ir.PointerType) and not self._is_owned(value) {
        self._emit_rc_retain(value, op=op, loc=loc);
    }
}

"""Emit E5090 for a builtin call the native emitter could not lower.

Shared by the multi-arg and single-arg builtin dispatch paths so the
diagnostic and its guidance stay consistent (issue #6357).
"""
impl NaIRGenPass._emit_unsupported_builtin_call(
    nd: uni.FuncCall, func_name: str
) -> None {
    self.emit(
        E5090,
        node_override=nd,
        kind="builtin call",
        name=func_name,
        help_text="This builtin is implemented for some argument types but could not be lowered for the argument(s) at this call site (for example `sum`/`min`/`max` over a `range` rather than a list). Restructure to a supported form, or move the code to a @sv/Python context."
    );
}

"""Generate function call."""
impl NaIRGenPass._codegen_call(nd: uni.FuncCall) -> (ir.Value | None) {
    # Dispatch on the checker-stamped call classification. Only call nodes
    # synthesized after type checking (e.g. desugared pipe-forward) lack
    # the stamp and are classified on the spot.
    _call_kind = nd.call_kind;
    if _call_kind is None {
        import from jaclang.compiler.symbol_utils { classify_call }
        _call_kind = classify_call(nd).value;
    }
    # Handle method calls: obj.method(args)
    if _call_kind == "method" {
        return self._codegen_method_call(nd);
    }
    func_name = self._get_name(nd.target);
    if func_name is None {
        return None;
    }
    # Builtin fast-paths fire only when the call actually resolves to a builtin.
    # The classification is shadow-aware, so a user symbol named e.g. `len` is
    # "function" and falls through to the free-function path below instead of
    # being hijacked by the builtin handling.
    if _call_kind == "builtin" {
        # Handle print() specially
        if func_name == "print" {
            return self._emit_print(nd);
        }
        # Handle RC debug toggle builtins (zero-argument functions)
        if func_name == "__rc_debug_enable" {
            if self.rc_alloc_fn is None {
                self._emit_rc_helpers();
            }
            en_fn = self.llvm_module.get_global("__rc_debug_enable");
            self.builder.call(en_fn, []);
            return None;
        }
        if func_name == "__rc_debug_disable" {
            if self.rc_alloc_fn is None {
                self._emit_rc_helpers();
            }
            dis_fn = self.llvm_module.get_global("__rc_debug_disable");
            self.builder.call(dis_fn, []);
            return None;
        }
        # GC on/off switch builtins
        if func_name == "__rc_gc_disable" {
            if self.rc_alloc_fn is None {
                self._emit_rc_helpers();
            }
            self.builder.call(self.rc_gc_disable_fn, []);
            return None;
        }
        if func_name == "__rc_gc_enable" {
            if self.rc_alloc_fn is None {
                self._emit_rc_helpers();
            }
            self.builder.call(self.rc_gc_enable_fn, []);
            return None;
        }
        # __float_bits(d: float)->int64 / __bits_float(b: int64)->float: IEEE-754 bitcast intrinsics.
        # Each compiles to a single LLVM bitcast (used by NaN-boxed JSValue helpers in jac-bun).
        if func_name == "__float_bits" {
            params_l = nd.params or [];
            if params_l {
                arg_val = self._codegen_expr(params_l[0]);
                if arg_val is not None {
                    if not isinstance(arg_val.type, ir.DoubleType) {
                        arg_val = self._coerce_type(arg_val, ir.DoubleType());
                    }
                    return self.builder.bitcast(
                        arg_val, ir.IntType(64), name="float_bits"
                    );
                }
            }
            return ir.Constant(ir.IntType(64), 0);
        }
        if func_name == "__bits_float" {
            params_l = nd.params or [];
            if params_l {
                arg_val = self._codegen_expr(params_l[0]);
                if arg_val is not None {
                    if not isinstance(arg_val.type, ir.IntType) {
                        arg_val = self._coerce_type(arg_val, ir.IntType(64));
                    } elif arg_val.type.width != 64 {
                        arg_val = self._coerce_type(arg_val, ir.IntType(64));
                    }
                    return self.builder.bitcast(
                        arg_val, ir.DoubleType(), name="bits_float"
                    );
                }
            }
            return ir.Constant(ir.DoubleType(), 0.0);
        }
        # isinstance(x, T): lower to a JacVal tag comparison. Works on an `any`
        # operand (runtime tag) and a concrete one (the box folds to a constant
        # tag). The engine behind generic-over-`any` dispatch (#6421).
        if func_name == "isinstance" {
            return self._emit_isinstance(nd);
        }
        # Handle len() builtin for lists, dicts, sets, and strings
        if func_name == "len" {
            params_l = nd.params or [];
            if params_l {
                elem_type_name: (str | None) = None;
                arg_val = self._codegen_expr(params_l[0]);
                if arg_val is not None {
                    _len_result: (ir.Value | None) = None;
                    # len() on an `any` (boxed JacVal): tag-dispatch at runtime so
                    # a generic walker can measure a list/dict/set/str pulled out
                    # of a loads() result without narrowing it first. (#6943 NA-5)
                    if self?.jacval_type and arg_val.type == self.jacval_type {
                        _len_result = self._codegen_any_len(arg_val);
                    }
                    # bytes: read the explicit length field (never strlen — the
                    # buffer may contain embedded NULs).
                    if _len_result is None and self._is_bytes_value(arg_val) {
                        _len_result = self._bytes_len_val(arg_val);
                    }
                    # Check for dict type by inferring from value
                    if _len_result is None {
                        for (dict_key, helpers) in self.dict_helpers.items() {
                            dict_type = self.dict_types.get(dict_key);
                            if dict_type is not None
                            and arg_val.type == dict_type.as_pointer() {
                                _len_result = self.builder.call(
                                    helpers["len"], [arg_val], name="dict.len"
                                );
                                break;
                            }
                        }
                    }
                    # Check for set type by inferring from value
                    if _len_result is None {
                        for (set_key, helpers) in self.set_helpers.items() {
                            set_type = self.set_types.get(set_key);
                            if set_type is not None
                            and arg_val.type == set_type.as_pointer() {
                                _len_result = self.builder.call(
                                    helpers["len"], [arg_val], name="set.len"
                                );
                                break;
                            }
                        }
                    }
                    # Check for list type
                    if _len_result is None {
                        if elem_type_name is None {
                            elem_type_name = self._infer_list_elem_type(arg_val);
                        }
                        if elem_type_name is not None {
                            helpers = self.list_helpers.get(elem_type_name);
                            if helpers is not None {
                                _len_result = self.builder.call(
                                    helpers["len"], [arg_val], name="list.len"
                                );
                            }
                        }
                    }
                    # String len: call strlen
                    if _len_result is None
                    and arg_val.type == ir.IntType(8).as_pointer() {
                        strlen_fn = self._get_or_declare_extern(
                            "strlen", ir.IntType(64), [ir.IntType(8).as_pointer()]
                        );
                        _len_result = self.builder.call(
                            strlen_fn, [arg_val], name="str.len"
                        );
                    }
                    if _len_result is not None {
                        # len() borrows the arg; release if caller owns it (e.g. inline fstring)
                        if isinstance(arg_val.type, ir.PointerType)
                        and self._is_owned(arg_val) {
                            self._emit_rc_release_simple(arg_val, op="len_arg", loc="");
                        }
                        return _len_result;
                    }
                }
            }
        }
        # First-class iterator builtins (#6403 phase 2). `iter(x)` boxes a
        # JacIter over x (its element type flows from the checker's
        # Iterator[T]); `next(it)` pulls one element and raises StopIteration
        # at exhaustion. For-loop driving of map/filter/... and of a stored
        # iterator is handled earlier in `_try_iter_protocol_for`.
        if func_name == "iter" {
            built = self._build_iter_from_expr(nd);
            if built is not None {
                (iter_val, _ename, _etype) = built;
                return iter_val;
            }
            self._emit_unsupported_builtin_call(nd, "iter");
            return None;
        }
        if func_name == "next" {
            return self._codegen_next(nd);
        }
        # Handle complex() constructor: complex(real, imag) -> JacComplex*
        if func_name == "complex" {
            params_l = nd.params or [];
            if len(params_l) >= 2 {
                real_val = self._codegen_expr(params_l[0]);
                imag_val = self._codegen_expr(params_l[1]);
                if real_val is not None and imag_val is not None {
                    f64 = ir.DoubleType();
                    i64 = ir.IntType(64);
                    real_f = self._coerce_type(real_val, f64)
                        if not isinstance(real_val.type, ir.DoubleType)
                        else real_val;
                    imag_f = self._coerce_type(imag_val, f64)
                        if not isinstance(imag_val.type, ir.DoubleType)
                        else imag_val;
                    ctype = self.complex_struct_type;
                    raw = self.builder.call(
                        self.rc_alloc_fn, [ir.Constant(i64, 16)], name="complex.raw"
                    );
                    ptr = self.builder.bitcast(
                        raw, ctype.as_pointer(), name="complex.ptr"
                    );
                    rp = self.builder.gep(
                        ptr,
                        [
                            ir.Constant(ir.IntType(32), 0),
                            ir.Constant(ir.IntType(32), 0)
                        ],
                        name="complex.re.ptr"
                    );
                    ip = self.builder.gep(
                        ptr,
                        [
                            ir.Constant(ir.IntType(32), 0),
                            ir.Constant(ir.IntType(32), 1)
                        ],
                        name="complex.im.ptr"
                    );
                    self.builder.store(real_f, rp);
                    self.builder.store(imag_f, ip);
                    return ptr;
                }
            }
        }
        # Handle range() constructor: range(stop), range(start,stop), range(start,stop,step)
        if func_name == "range" {
            params_l = nd.params or [];
            i64 = ir.IntType(64);
            i32 = ir.IntType(32);
            start_v: (ir.Value | None) = None;
            stop_v: (ir.Value | None) = None;
            step_v: (ir.Value | None) = None;
            if len(params_l) == 1 {
                start_v = ir.Constant(i64, 0);
                stop_v = self._codegen_expr(params_l[0]);
                step_v = ir.Constant(i64, 1);
            } elif len(params_l) == 2 {
                start_v = self._codegen_expr(params_l[0]);
                stop_v = self._codegen_expr(params_l[1]);
                step_v = ir.Constant(i64, 1);
            } elif len(params_l) >= 3 {
                start_v = self._codegen_expr(params_l[0]);
                stop_v = self._codegen_expr(params_l[1]);
                step_v = self._codegen_expr(params_l[2]);
            }
            if start_v is not None and stop_v is not None and step_v is not None {
                start_v = self._coerce_type(start_v, i64);
                stop_v = self._coerce_type(stop_v, i64);
                step_v = self._coerce_type(step_v, i64);
                rtype = self.range_struct_type;
                raw = self.builder.call(
                    self.rc_alloc_fn, [ir.Constant(i64, 24)], name="range.raw"
                );
                ptr = self.builder.bitcast(raw, rtype.as_pointer(), name="range.ptr");
                z0 = ir.Constant(i32, 0);
                self.builder.store(
                    start_v,
                    self.builder.gep(ptr, [z0, ir.Constant(i32, 0)], name="range.sp")
                );
                self.builder.store(
                    stop_v,
                    self.builder.gep(ptr, [z0, ir.Constant(i32, 1)], name="range.ep")
                );
                self.builder.store(
                    step_v,
                    self.builder.gep(ptr, [z0, ir.Constant(i32, 2)], name="range.tp")
                );
                return ptr;
            }
        }
        # Handle slice() constructor: slice(stop), slice(start,stop), slice(start,stop,step)
        if func_name == "slice" {
            params_l = nd.params or [];
            i64 = ir.IntType(64);
            i32 = ir.IntType(32);
            start_v: (ir.Value | None) = None;
            stop_v: (ir.Value | None) = None;
            step_v: (ir.Value | None) = None;
            if len(params_l) == 1 {
                start_v = ir.Constant(i64, 0);
                stop_v = self._codegen_expr(params_l[0]);
                step_v = ir.Constant(i64, 1);
            } elif len(params_l) == 2 {
                start_v = self._codegen_expr(params_l[0]);
                stop_v = self._codegen_expr(params_l[1]);
                step_v = ir.Constant(i64, 1);
            } elif len(params_l) >= 3 {
                start_v = self._codegen_expr(params_l[0]);
                stop_v = self._codegen_expr(params_l[1]);
                step_v = self._codegen_expr(params_l[2]);
            }
            if start_v is not None and stop_v is not None and step_v is not None {
                start_v = self._coerce_type(start_v, i64);
                stop_v = self._coerce_type(stop_v, i64);
                step_v = self._coerce_type(step_v, i64);
                stype = self.slice_struct_type;
                raw = self.builder.call(
                    self.rc_alloc_fn, [ir.Constant(i64, 24)], name="slice.raw"
                );
                ptr = self.builder.bitcast(raw, stype.as_pointer(), name="slice.ptr");
                z0 = ir.Constant(i32, 0);
                self.builder.store(
                    start_v,
                    self.builder.gep(ptr, [z0, ir.Constant(i32, 0)], name="slice.sp")
                );
                self.builder.store(
                    stop_v,
                    self.builder.gep(ptr, [z0, ir.Constant(i32, 1)], name="slice.ep")
                );
                self.builder.store(
                    step_v,
                    self.builder.gep(ptr, [z0, ir.Constant(i32, 2)], name="slice.tp")
                );
                return ptr;
            }
        }
        # Handle multi-arg builtins via emitter dispatch
        if func_name in (
            "abs",
            "min",
            "max",
            "pow",
            "divmod",
            "sum",
            "any",
            "all",
            "format"
        ) {
            params_l = nd.params or [];
            arg_vals: list[ir.Value] = [];
            for param in params_l {
                v = self._codegen_expr(param);
                if v is not None {
                    arg_vals.append(v);
                }
            }
            if arg_vals {
                result = self._dispatch_builtin(func_name, arg_vals);
                # dispatch borrows each arg; release any owned temporaries (e.g. fstrings)
                for _barg in arg_vals {
                    if isinstance(_barg.type, ir.PointerType)
                    and self._is_owned(_barg) {
                        self._emit_rc_release_simple(_barg, op="builtin_arg", loc="");
                    }
                }
                if result is not None {
                    return result;
                }
                # Builtin recognized with arguments, but the native emitter
                # could not lower it for these argument types (e.g. `sum`/`min`/
                # `max` over a `range` rather than a materialized list). Fail
                # loudly instead of returning None and emitting a binary that
                # silently prints an empty value (issue #6357).
                self._emit_unsupported_builtin_call(nd, func_name);
                return None;
            }
        }
        # Handle ord, int, chr, str, hex, oct, bin, round, float, list, set builtins via emitter dispatch
        if func_name in (
            "ord",
            "int",
            "chr",
            "str",
            "hex",
            "oct",
            "bin",
            "round",
            "float",
            "bool",
            "sorted",
            "reversed",
            "list",
            "set",
            "frozenset",
            "dict",
            "bytes",
            "bytearray",
            "id",
            "hash",
            "repr",
            "ascii"
        ) {
            params_l = nd.params or [];
            if params_l {
                arg_val = self._codegen_expr(params_l[0]);
                if arg_val is not None {
                    result = self._dispatch_builtin(func_name, [arg_val]);
                    # dispatch borrows the arg; release if caller owns it (e.g. fstring)
                    if isinstance(arg_val.type, ir.PointerType)
                    and self._is_owned(arg_val) {
                        self._emit_rc_release_simple(
                            arg_val, op="builtin1_arg", loc=""
                        );
                    }
                    if result is not None {
                        return result;
                    }
                    # Builtin recognized with an argument, but the native
                    # emitter could not lower it for this argument type. Fail
                    # loudly rather than silently dropping the value (#6357).
                    self._emit_unsupported_builtin_call(nd, func_name);
                    return None;
                }
            }
        }
        # Handle input() builtin: printf prompt, fgets from stdin
        if func_name == "input" {
            i8p = ir.IntType(8).as_pointer();
            params_l = nd.params or [];
            # Print prompt if provided
            if params_l {
                prompt_val = self._codegen_expr(params_l[0]);
                if prompt_val is not None {
                    _prompt_orig = prompt_val;
                    printf = self._get_printf();
                    fmt = self._get_fmt_string("%s");
                    fmt_ptr = self.builder.bitcast(fmt, i8p, name="fmt.ptr");
                    # Ensure prompt is i8* (bitcast if needed)
                    if isinstance(prompt_val.type, ir.PointerType)
                    and prompt_val.type != i8p {
                        prompt_val = self.builder.bitcast(
                            prompt_val, i8p, name="prompt.cast"
                        );
                    }
                    self.builder.call(printf, [fmt_ptr, prompt_val]);
                    # printf borrows the prompt; release if we own it (e.g. fstring result)
                    if isinstance(_prompt_orig.type, ir.PointerType)
                    and self._is_owned(_prompt_orig) {
                        self._emit_rc_release_simple(
                            _prompt_orig, op="input_prompt", loc=""
                        );
                    }
                }
            }
            # Allocate buffer, call fgets
            buf_size = 256;
            buf_type = ir.ArrayType(ir.IntType(8), buf_size);
            buf = self.builder.alloca(buf_type, name="input.buf");
            buf_ptr = self.builder.bitcast(buf, i8p, name="input.ptr");
            # Get stdin via fdopen or use __stdinp — use a simple approach with fgets(buf, size, stdin)
            # Declare stdin as external global (macOS uses __stdinp, Linux uses stdin)
            import platform;
            stdin_name = "__stdinp" if platform.system() == "Darwin" else "stdin";
            if stdin_name not in self.extern_funcs {
                stdin_type = i8p;
                stdin_global = ir.GlobalVariable(
                    self.llvm_module, stdin_type, name=stdin_name
                );
                stdin_global.linkage = "external";
                self.extern_funcs[stdin_name] = stdin_global;
            }
            stdin_var = self.extern_funcs[stdin_name];
            stdin_val = self.builder.load(stdin_var, name="stdin.val");
            fgets = self._get_or_declare_extern(
                "fgets", i8p, [i8p, ir.IntType(32), i8p]
            );
            size_val = ir.Constant(ir.IntType(32), buf_size);
            fgets_ret = self.builder.call(
                fgets, [buf_ptr, size_val, stdin_val], name="fgets.result"
            );
            # Check for EOF (fgets returns NULL)
            func = self.builder.function;
            eof_bb = func.append_basic_block(name="input.eof");
            ok_bb = func.append_basic_block(name="input.ok");
            merge_bb = func.append_basic_block(name="input.merge");
            null_ptr = ir.Constant(i8p, None);
            is_eof = self.builder.icmp_signed("==", fgets_ret, null_ptr, name="is.eof");
            self.builder.cbranch(is_eof, eof_bb, ok_bb);
            # EOF path: return empty string
            self.builder.position_at_start(eof_bb);
            eof_str = self.builder.call(
                self.rc_alloc_fn, [ir.Constant(ir.IntType(64), 1)], name="eof.str"
            );
            self.builder.store(ir.Constant(ir.IntType(8), 0), eof_str);
            self.builder.branch(merge_bb);
            eof_bb_end = self.builder.block;
            # OK path: process input normally
            self.builder.position_at_start(ok_bb);
            # Strip trailing newline: find length, then set buf[len-1] = 0 if it's '\n'
            strlen_fn = self._get_or_declare_extern("strlen", ir.IntType(64), [i8p]);
            slen = self.builder.call(strlen_fn, [buf_ptr], name="input.len");
            # Copy to RC-managed string
            alloc_size = self.builder.add(
                slen, ir.Constant(ir.IntType(64), 1), name="alloc.size"
            );
            result_ptr = self.builder.call(
                self.rc_alloc_fn, [alloc_size], name="input.result"
            );
            memcpy = self._get_or_declare_extern(
                "memcpy", i8p, [i8p, i8p, ir.IntType(64)]
            );
            self.builder.call(memcpy, [result_ptr, buf_ptr, alloc_size]);
            # Strip trailing newline if present (only if slen > 0)
            has_len = self.builder.icmp_signed(
                ">", slen, ir.Constant(ir.IntType(64), 0), name="has.len"
            );
            strip_bb = func.append_basic_block(name="input.strip");
            nostrip_bb = func.append_basic_block(name="input.nostrip");
            self.builder.cbranch(has_len, strip_bb, nostrip_bb);
            self.builder.position_at_start(strip_bb);
            last_idx = self.builder.sub(
                slen, ir.Constant(ir.IntType(64), 1), name="last.idx"
            );
            last_ptr = self.builder.gep(result_ptr, [last_idx], name="last.ptr");
            last_byte = self.builder.load(last_ptr, name="last.byte");
            is_newline = self.builder.icmp_signed(
                "==", last_byte, ir.Constant(ir.IntType(8), 10), name="is.nl"
            );
            # Conditionally null-terminate at newline position
            null_byte = ir.Constant(ir.IntType(8), 0);
            store_val = self.builder.select(
                is_newline, null_byte, last_byte, name="strip.nl"
            );
            self.builder.store(store_val, last_ptr);
            # Also strip \r if present (for \r\n line endings in WSL2/Windows)
            strip_cr_bb = func.append_basic_block(name="input.strip.cr");
            self.builder.cbranch(is_newline, strip_cr_bb, nostrip_bb);
            self.builder.position_at_start(strip_cr_bb);
            # Check if slen >= 2 (need at least 2 chars for \r\n)
            has_cr_len = self.builder.icmp_signed(
                ">=", slen, ir.Constant(ir.IntType(64), 2), name="has.cr.len"
            );
            strip_cr_check_bb = func.append_basic_block(name="input.strip.cr.check");
            self.builder.cbranch(has_cr_len, strip_cr_check_bb, nostrip_bb);
            self.builder.position_at_start(strip_cr_check_bb);
            # Check if char at slen-2 is \r (13)
            cr_idx = self.builder.sub(
                slen, ir.Constant(ir.IntType(64), 2), name="cr.idx"
            );
            cr_ptr = self.builder.gep(result_ptr, [cr_idx], name="cr.ptr");
            cr_byte = self.builder.load(cr_ptr, name="cr.byte");
            is_cr = self.builder.icmp_signed(
                "==", cr_byte, ir.Constant(ir.IntType(8), 13), name="is.cr"
            );
            # Conditionally null-terminate at CR position
            store_cr_val = self.builder.select(
                is_cr, null_byte, cr_byte, name="strip.cr"
            );
            self.builder.store(store_cr_val, cr_ptr);
            self.builder.branch(nostrip_bb);
            self.builder.position_at_start(nostrip_bb);
            self.builder.branch(merge_bb);
            ok_bb_end = self.builder.block;
            # Merge: phi for result
            self.builder.position_at_start(merge_bb);
            phi = self.builder.phi(i8p, name="input.phi");
            phi.add_incoming(eof_str, eof_bb_end);
            phi.add_incoming(result_ptr, ok_bb_end);
            return phi;
        }
        # Handle open() builtin for file I/O
        if func_name == "open" {
            return self._emit_open(nd);
        }
    }
    # Handle object instantiation: ClassName(args)
    if func_name in self.struct_types {
        return self._codegen_instantiation(nd);
    }
    func = self.func_symtab.get(func_name);
    if func is None {
        # Check interop manifest for cross-boundary functions callable from native
        manifest = self.ir_in.gen.interop_manifest;
        binding = manifest.bindings.get(func_name);
        if binding is not None {
            if binding.source_context.value == "server" {
                # Declare extern function for this Python function (sv↔na)
                param_ir_types: list = [];
                for pt in binding.param_types {
                    param_ir_types.append(self._resolve_type_str(pt));
                }
                ret_ir_type = self._resolve_type_str(binding.ret_type);
                func = self._get_or_declare_extern(
                    func_name, ret_ir_type, param_ir_types
                );
            } elif binding.source_context.value == "native"
            and binding.source_module is not None {
                # Declare extern function for imported native function (na↔na)
                # The symbol will be resolved at link time by NativeCompilePass
                param_ir_types: list = [];
                if binding.param_types {
                    for pt in binding.param_types {
                        param_ir_types.append(self._resolve_type_str(pt));
                    }
                } else {
                    # Infer parameter types from call arguments
                    params = nd.params or [];
                    for param in params {
                        param_ir_types.append(ir.IntType(64));  # Default to i64
                    }
                }
                ret_ir_type = self._resolve_type_str(binding.ret_type);
                func = self._get_or_declare_extern(
                    func_name, ret_ir_type, param_ir_types
                );
            }
        }
    }
    if func is None {
        # ── Indirect call via function-pointer local variable ────────────────
        # If the callee name resolves to a local variable whose loaded type is
        # a pointer to FunctionType (i.e., a Callable parameter), build an
        # indirect call instead of giving up.
        if func_name in self.local_vars {
            _alloca = self.local_vars[func_name];
            _loaded = self.builder.load(_alloca, name=f"fptr.{func_name}");
            if (
                isinstance(_loaded.type, ir.PointerType)
                and isinstance(_loaded.type.pointee, ir.FunctionType)
            ) {
                _fn_type = _loaded.type.pointee;
                _iargs: list[ir.Value] = [];
                _iparams = nd.params or [];
                for _ip in _iparams {
                    _iv = self._codegen_expr(_ip);
                    if _iv is not None {
                        _iargs.append(_iv);
                    }
                }
                _icoerced: list[ir.Value] = [];
                for (_ii, _ia) in enumerate(_iargs) {
                    if _ii < len(_fn_type.args) {
                        _icoerced.append(self._coerce_type(_ia, _fn_type.args[_ii]));
                    } else {
                        _icoerced.append(_ia);
                    }
                }
                # Inject captured closure variables if this is a capturing lambda.
                # If the function pointer expects more args than were explicitly
                # passed, look up the capture info by variable name and load
                # the captured values from the current scope's local variables.
                if func_name in self.lambda_captures {
                    for (_cname, _c_alloca) in self.lambda_captures[func_name] {
                        _cval = self.builder.load(_c_alloca, name=f"cap.{_cname}");
                        _icoerced.append(_cval);
                    }
                }
                _icall_result = self.builder.call(
                    _loaded, _icoerced, name=f"icall.{func_name}"
                );
                # indirect call borrows all args; release owned temporaries
                for _icarg in _iargs {
                    if isinstance(_icarg.type, ir.PointerType)
                    and self._is_owned(_icarg) {
                        self._emit_rc_release_simple(_icarg, op="icall_arg", loc="");
                    }
                }
                return _icall_result;
            }
        }
        # Nothing resolved this free-function call: not a user function,
        # struct constructor, interop binding, or callable local. A genuinely
        # unknown name (typo'd or Python-only function) cannot be lowered to
        # the native subset -- emit a structured error rather than silently
        # returning None, which would leave the call site empty and produce a
        # binary that prints garbage instead of failing the compile (issue
        # #6357). Builtin-classified names are excluded here: a no-arg
        # collection constructor like `set()`/`dict()`/`list()` legitimately
        # reaches this point and is materialized from the assignment's type
        # annotation; builtin calls that truly cannot be lowered are caught at
        # their dispatch site above (where the arguments are known).
        if _call_kind != "builtin" {
            self.emit(E5090, node_override=nd, kind="function", name=func_name);
        }
        return None;
    }
    # Build arguments
    args: list[ir.Value] = [];
    params = nd.params or [];
    for param in params {
        val = self._codegen_expr(param);
        if val is not None {
            args.append(val);
        }
    }
    # Fill in missing optional parameters with the resolved callee's
    # default-value exprs (checker-stamped fact, not a name-keyed cache)
    self._fill_default_args(nd, func, args, skip_self=False);
    # Foreign (clib) calls: marshal per the recorded System V ABI plan. This is
    # the single authority for foreign argument/return lowering — it slices
    # struct args into register pieces / byval pointers and reconstructs the
    # return, instead of guessing from LLVM value shapes at the call site.
    if func_name in self.clib_fn_abi {
        return self._codegen_clib_call(func, func_name, args);
    }
    # Type coerce arguments
    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(args) {
        if i < len(func.args) {
            coerced.append(self._coerce_type(arg, func.args[i].type));
        } else {
            coerced.append(arg);
        }
    }
    result = self.builder.call(func, coerced, name=f"call.{func_name}");
    # The callee borrows its arguments (it RETAINs internally any it keeps);
    # release any owned temporaries we passed so they don't leak (e.g.
    # `f([(-1,-1), (1,1)])` — the list literal, and any value-tuple boxed by
    # _coerce_type, are owned temporaries borrowed by the callee).
    self._release_owned_args(coerced, op="call_arg");
    # Box clib extern struct return values: C returns by value (or ABI int), Jac uses pointers
    if func_name in self.clib_extern_names {
        # Check ABI integer return types first (small structs coerced to int)
        for (sname, abi_type) in self.clib_struct_abi_types.items() {
            if result.type == abi_type {
                result = self._coerce_type(
                    result, self.struct_types[sname].as_pointer()
                );
                break;
            }
        }
        # Check direct struct return types (larger structs)
        if not isinstance(result.type, ir.PointerType) {
            for (sname, stype) in self.struct_types.items() {
                if sname in self.clib_struct_names and result.type == stype {
                    result = self._coerce_type(result, stype.as_pointer());
                    break;
                }
            }
        }
    }
    # Every pointer returned by a user function carries a +1 (RETAIN inside
    # the callee for borrowed refs, or skip-var donation for named locals);
    # ownership is applied at the _codegen_expr seam from the central
    # invariant (compiler/ownership.jac).
    return result;
}
# ─── isinstance-on-`any` (JacVal tag dispatch) ───────────────
"""JacVal tag(s) that satisfy `isinstance(x, name)`.

Keyed off the box scheme in `_box_to_jacval`. `int` also accepts `bool` (tag 7)
because CPython treats `bool` as a subtype of `int`; `bool` accepts only tag 7.
An empty result means the type operand is not lowerable here (e.g. a user
archetype), and the caller surfaces a structured error instead of miscompiling.
"""
impl NaIRGenPass._jacval_tags_for_type(name: str) -> list[int] {
    if name == "int" {
        return [0, 7];
    }
    if name == "bool" {
        return [7];
    }
    if name == "float" {
        return [1];
    }
    if name == "str" {
        return [2];
    }
    if name == "list" {
        return [3];
    }
    if name == "dict" {
        return [4];
    }
    if name == "set" {
        return [5];
    }
    return [];
}

"""Lower `isinstance(operand, T)` to a JacVal tag comparison.

`T` is a type name or a tuple of type names (`isinstance(x, (int, str))`). The
operand is boxed once — a no-op for an already-boxed `any`, and a constant the
optimizer folds for a concrete value — then its tag byte is compared against the
tag set for `T`. Returns an `i1`; `None` (with a structured error) when `T` names
a type that has no native tag.
"""
impl NaIRGenPass._emit_isinstance(nd: uni.FuncCall) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    params = nd.params or [];
    if len(params) < 2 {
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }
    operand = self._codegen_expr(params[0]);
    if operand is None {
        return None;
    }
    # Collect the type name(s): a bare name or a tuple of names.
    type_arg = params[1];
    names: list[str] = [];
    if isinstance(type_arg, uni.TupleVal) {
        for v in (type_arg.values or []) {
            nm = self._get_name(v);
            if nm is not None {
                names.append(nm);
            }
        }
    } else {
        nm = self._get_name(type_arg);
        if nm is not None {
            names.append(nm);
        }
    }
    tags: list[int] = [];
    unresolved: list[str] = [];
    for nm in names {
        nm_tags = self._jacval_tags_for_type(nm);
        if not nm_tags {
            unresolved.append(nm);
        }
        for t in nm_tags {
            if t not in tags {
                tags.append(t);
            }
        }
    }
    if unresolved {
        if not tags {
            # Every target name lacks a builtin JacVal tag: lower as a user
            # archetype check via vtable-pointer identity. The helper surfaces
            # E5090 itself if a name resolves to no native vtable.
            return self._emit_isinstance_user(nd, operand, unresolved);
        }
        # Mixed builtin + user names (`isinstance(x, (int, MyNode))`) cannot be
        # lowered soundly: the operand is either a boxed scalar or a struct
        # pointer, never both. Surface a structured error rather than silently
        # dropping the unsupported arm.
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }
    if not tags {
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }
    boxed = self._box_to_jacval(operand);
    tag = self.builder.extract_value(boxed, 0, name="isinst.tag");
    result: (ir.Value | None) = None;
    for t in sorted(tags) {
        cmp = self.builder.icmp_unsigned(
            "==", tag, ir.Constant(i8, t), name="isinst.cmp"
        );
        result = cmp
            if result is None
            else self.builder.or_(result, cmp, name="isinst.or");
    }
    # Only the tag was inspected; release an owned pointer temporary so e.g.
    # `isinstance([1, 2, 3], list)` does not leak the literal.
    if isinstance(operand.type, ir.PointerType) and self._is_owned(operand) {
        self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
    }
    return result;
}

"""Lower `isinstance(operand, T)` where `T` (or every member of a tuple of
types) is a user archetype, via vtable-pointer identity.

Every archetype that participates in inheritance carries its class's `__vtable`
pointer at field 0 (set at allocation), so the runtime vtable pointer uniquely
identifies the concrete class. The check compares the operand's field-0 pointer
against the vtables of `T` and *all its subclasses* -- the subtype set is
resolved statically from the C3 MRO, making this inheritance- and
multiple-inheritance-safe with no new runtime metadata. `isinstance(None, T)` is
False (guarded, never a deref). Returns an `i1`; `None` with a structured error
when `operand` carries no static struct or no target resolves to a native
vtable.
"""
impl NaIRGenPass._emit_isinstance_user(
    nd: uni.FuncCall, operand: ir.Value, names: list[str]
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    # The operand must be a struct pointer carrying a vtable at field 0; an
    # `any`-typed (boxed) operand has no static struct to read.
    if not isinstance(operand.type, ir.PointerType) {
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }
    # Concrete target set: every native archetype with an emitted vtable whose
    # MRO contains a requested name (i.e. the name itself or a subclass of it).
    # Iterating a dict already yields unique keys and the inner `break` stops at
    # the first matching name, so no extra dedup is needed.
    target_vtables: list[ir.GlobalVariable] = [];
    for cand in self.vtable_globals {
        cand_mro = self._mro_of(cand);
        for name in names {
            if name in cand_mro {
                target_vtables.append(self.vtable_globals[cand]);
                break;
            }
        }
    }
    if not target_vtables {
        # No native subclass with a vtable matches (e.g. a foreign or
        # non-polymorphic type name) -- cannot lower soundly.
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }
    # Field 0 is the vtable slot only when the operand's static struct has a
    # vtable; for a plain struct it is the first user-declared field and must
    # NOT be read as a vtable pointer. Resolve the operand's static struct to
    # decide how (and whether) to read field 0.
    struct_name = self._struct_name_of(nd.params[0] if nd.params else None);
    if struct_name is None or struct_name not in self.struct_types {
        # Unknown / foreign / not-lowered operand: cannot read field 0 soundly.
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }
    if struct_name not in self.vtable_globals {
        # A locally lowered struct with no vtable participates in no inheritance,
        # so it can never be an instance of a vtable-bearing target: the result
        # is statically False (and field 0 is a user field, not a vtable slot).
        if self._is_owned(operand) {
            self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
        }
        return ir.Constant(i1, 0);
    }
    # Guard the field-0 load behind a null check: `isinstance(None, T)` is
    # False and must not dereference.
    pre_bb = self.builder.block;
    null_ptr = ir.Constant(operand.type, None);
    is_null = self.builder.icmp_unsigned(
        "==", operand, null_ptr, name="isinst.null.chk"
    );
    nonnull_bb = self.builder.append_basic_block(name="isinst.nonnull");
    merge_bb = self.builder.append_basic_block(name="isinst.merge");
    self.builder.cbranch(is_null, merge_bb, nonnull_bb);
    # Non-null: read the vtable pointer at field 0 and OR-compare it against
    # every concrete target vtable base.
    self.builder.position_at_end(nonnull_bb);
    i8_pp = i8.as_pointer().as_pointer();
    op_as = self.builder.bitcast(operand, i8_pp.as_pointer(), name="isinst.obj");
    vptr = self.builder.load(op_as, name="isinst.vptr");
    cmp: (ir.Value | None) = None;
    for vt in target_vtables {
        vt_base = self.builder.gep(
            vt, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="isinst.vt.base"
        );
        eq = self.builder.icmp_unsigned("==", vptr, vt_base, name="isinst.eq");
        cmp = eq if cmp is None else self.builder.or_(cmp, eq, name="isinst.or");
    }
    # Only the vtable pointer was inspected; release an owned operand temporary
    # exactly once (e.g. `isinstance(make_node(), Leaf)`). Owned temporaries are
    # never null, so this runs only on the non-null path.
    if self._is_owned(operand) {
        self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
    }
    end_nonnull = self.builder.block;
    self.builder.branch(merge_bb);
    # Merge: False when the operand was null, else the comparison result.
    self.builder.position_at_end(merge_bb);
    result = self.builder.phi(i1, name="isinst.result");
    result.add_incoming(ir.Constant(i1, 0), pre_bb);
    result.add_incoming(cmp, end_nonnull);
    return result;
}
# ─── External Function Support ───────────────────────────────
