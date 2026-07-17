glob RC_INTRINSIC_NAMES: frozenset[str] = frozenset(
         {
             "__rc_debug_enable",
             "__rc_debug_disable",
             "__rc_gc_disable",
             "__rc_gc_enable",
             "__rc_collect_cycles",

         }
     );

impl NaIRGenPass._callee_sig_of(nd: uni.FuncCall) -> (uni.FuncSignature | None) {
    decl = nd.callee_decl;
    sig = decl.signature if decl is not None else None;
    return sig if isinstance(sig, uni.FuncSignature) else None;
}

impl NaIRGenPass._arch_init_sig_of(type_name: str) -> (uni.FuncSignature | None) {
    arch = self.arch_ast_map.get(type_name);
    if not isinstance(arch, uni.Archetype) or arch.body is None {
        return None;
    }
    for stmt in arch.body {
        if isinstance(stmt, uni.Ability)
        and stmt.name_ref is not None
        and stmt.name_ref.sym_name in ("init", "__init__")
        and isinstance(stmt.signature, uni.FuncSignature) {
            return stmt.signature;
        }
    }
    return None;
}

impl NaIRGenPass._default_arg_fallback(t: ir.Type) -> ir.Value {
    if isinstance(t, ir.PointerType) {
        if t.pointee == self._get_bytes_struct_type() {
            return self._make_global_bytes(b"");
        }
        return ir.Constant(t, None);
    }
    return ir.Constant(t, 0);
}

impl NaIRGenPass._codegen_bound_args(
    nd: uni.FuncCall, func: ir.Function, self_offset: int = 0
) -> list {
    raw = nd.params or [];
    positional: list = [];
    kw_map: dict = {};
    for param in raw {
        if isinstance(param, uni.KWPair) {
            key = param.key.sym_name if param.key is not None else None;
            if key is not None {
                kw_map[key] = param.value;
            }
        } else {
            positional.append(param);
        }
    }

    callee_sig = self._callee_sig_of(nd);
    args: list = [];

    if callee_sig is None {
        for p in positional {
            v = self._codegen_expr(p);
            if v is not None {
                args.append(v);
            }
        }
        slot = self_offset + len(args);
        while slot < len(func.args) {
            args.append(self._default_arg_fallback(func.args[slot].type));
            slot += 1;
        }
        return args;
    }

    sig_params = callee_sig.get_parameters();
    for (pix, sp) in enumerate(sig_params) {
        slot = self_offset + pix;
        expected_type = func.args[slot].type
            if slot < len(func.args)
            else ir.IntType(64);
        chosen: (uni.Expr | None) = None;
        if pix < len(positional) {
            chosen = positional[pix];
        } elif sp.name.sym_name in kw_map {
            chosen = kw_map[sp.name.sym_name];
        } elif sp.value is not None {
            chosen = sp.value;
            if isinstance(chosen, uni.Null)
            and str(chosen.loc.mod_path).endswith(".pyi") {
                chosen = None;
            }
        }
        val = self._codegen_expr(chosen) if chosen is not None else None;
        if val is not None {
            args.append(val);
        } else {
            args.append(self._default_arg_fallback(expected_type));
        }
    }

    for pix in range(len(sig_params), len(positional)) {
        v = self._codegen_expr(positional[pix]);
        if v is not None {
            args.append(v);
        }
    }
    return args;
}

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

impl NaIRGenPass._emit_take_ref(value: ir.Value, op: str, loc: str = "") -> None {
    if isinstance(value.type, ir.PointerType) and not self._is_owned(value) {
        self._emit_rc_retain(value, op=op, loc=loc);
    }
}

impl NaIRGenPass._emit_unsupported_builtin_call(
    nd: uni.FuncCall, func_name: str
) -> None {
    self.emit(
        E5092,
        node_override=nd,
        kind="builtin call",
        name=func_name,
        help_text="This builtin is implemented for some argument types but could not be lowered for the argument(s) at this call site (for example `sum`/`min`/`max` over a `range` rather than a list). Restructure to a supported form, or move the code to a @sv/Python context."
    );
}

impl NaIRGenPass._native_module_call_target(nd: uni.FuncCall) -> (str | None) {
    trailer = nd.target;
    if not isinstance(trailer, uni.AtomTrailer) or not trailer.is_attr {
        return None;
    }

    if isinstance(trailer.target, uni.AtomTrailer) {
        return None;
    }
    mod_name = self._get_name(trailer.target);
    method_name = self._get_name(trailer.right);
    if mod_name is None or method_name is None {
        return None;
    }

    if (
        self?._native_module_imports
        and mod_name in self._native_module_imports
        and mod_name not in self.local_vars
        and mod_name not in self.struct_types
    ) {
        return method_name;
    }
    return None;
}

impl NaIRGenPass._codegen_rc_intrinsic(func_name: str) -> bool {
    if func_name not in RC_INTRINSIC_NAMES {
        return False;
    }
    if func_name == "__rc_collect_cycles" and self._gc_mode() != "cycles" {
        return True;
    }
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    self.builder.call(self.llvm_module.get_global(func_name), []);
    return True;
}

impl NaIRGenPass._codegen_call(nd: uni.FuncCall) -> (ir.Value | None) {
    _call_kind = nd.call_kind;

    if _call_kind == "method" {
        _mod_fn = self._native_module_call_target(nd);
        if _mod_fn is None {
            return self._codegen_method_call(nd);
        }
        func_name = _mod_fn;
    } else {
        func_name = self._get_name(nd.target);
        if func_name is None {
            return None;
        }
    }

    if self._codegen_rc_intrinsic(func_name) {
        return None;
    }

    if _call_kind == "builtin" {
        if func_name == "print" {
            return self._emit_print(nd);
        }

        if func_name == "managed" {
            params_l = nd.params or [];
            if params_l {
                return self._codegen_expr(params_l[0]);
            }
            return None;
        }

        if func_name == "Region" {
            import from jaclang.compiler.symbol_utils { is_builtin_region_name }
            if is_builtin_region_name(nd.target) {
                self._emit_arena_helpers();
                return self.builder.call(self.region_new_fn, [], name="region.new");
            }
            if "Region" in self.struct_types {
                return self._codegen_instantiation(nd);
            }
        }

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

        if func_name == "isinstance" {
            return self._emit_isinstance(nd);
        }

        if func_name == "len" {
            params_l = nd.params or [];
            if params_l {
                elem_type_name: (str | None) = None;
                arg_val = self._codegen_expr(params_l[0]);
                if arg_val is not None {
                    _len_result: (ir.Value | None) = None;

                    if self?.jacval_type and arg_val.type == self.jacval_type {
                        _len_result = self._codegen_any_len(arg_val);
                    }

                    if _len_result is None and self._is_bytes_value(arg_val) {
                        _len_result = self._bytes_len_val(arg_val);
                    }

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
                        if isinstance(arg_val.type, ir.PointerType)
                        and self._is_owned(arg_val) {
                            self._emit_rc_release_simple(arg_val, op="len_arg", loc="");
                        }
                        return _len_result;
                    }
                }
            }
        }

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

                for _barg in arg_vals {
                    if isinstance(_barg.type, ir.PointerType)
                    and self._is_owned(_barg) {
                        self._emit_rc_release_simple(_barg, op="builtin_arg", loc="");
                    }
                }
                if result is not None {
                    return result;
                }

                self._emit_unsupported_builtin_call(nd, func_name);
                return None;
            }
        }

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
                    result = self._dispatch_builtin(
                        func_name,
                        [arg_val],
                        kwargs=self._split_call_kwargs(nd),
                        kw_node=nd
                    );

                    if isinstance(arg_val.type, ir.PointerType)
                    and self._is_owned(arg_val) {
                        self._emit_rc_release_simple(
                            arg_val, op="builtin1_arg", loc=""
                        );
                    }
                    if result is not None {
                        return result;
                    }

                    if not self._split_call_kwargs(nd) {
                        self._emit_unsupported_builtin_call(nd, func_name);
                    }
                    return None;
                }
            }
        }

        if func_name == "input" {
            i8p = ir.IntType(8).as_pointer();
            params_l = nd.params or [];

            if params_l {
                prompt_val = self._codegen_expr(params_l[0]);
                if prompt_val is not None {
                    _prompt_orig = prompt_val;
                    printf = self._get_printf();
                    fmt = self._get_fmt_string("%s");
                    fmt_ptr = self.builder.bitcast(fmt, i8p, name="fmt.ptr");

                    if isinstance(prompt_val.type, ir.PointerType)
                    and prompt_val.type != i8p {
                        prompt_val = self.builder.bitcast(
                            prompt_val, i8p, name="prompt.cast"
                        );
                    }
                    self.builder.call(printf, [fmt_ptr, prompt_val]);

                    if isinstance(_prompt_orig.type, ir.PointerType)
                    and self._is_owned(_prompt_orig) {
                        self._emit_rc_release_simple(
                            _prompt_orig, op="input_prompt", loc=""
                        );
                    }
                }
            }

            buf_size = 256;
            buf_type = ir.ArrayType(ir.IntType(8), buf_size);
            buf = self.builder.alloca(buf_type, name="input.buf");
            buf_ptr = self.builder.bitcast(buf, i8p, name="input.ptr");

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

            func = self.builder.function;
            eof_bb = func.append_basic_block(name="input.eof");
            ok_bb = func.append_basic_block(name="input.ok");
            merge_bb = func.append_basic_block(name="input.merge");
            null_ptr = ir.Constant(i8p, None);
            is_eof = self.builder.icmp_signed("==", fgets_ret, null_ptr, name="is.eof");
            self.builder.cbranch(is_eof, eof_bb, ok_bb);

            self.builder.position_at_start(eof_bb);
            eof_str = self.builder.call(
                self.rc_alloc_fn, [ir.Constant(ir.IntType(64), 1)], name="eof.str"
            );
            self.builder.store(ir.Constant(ir.IntType(8), 0), eof_str);
            self.builder.branch(merge_bb);
            eof_bb_end = self.builder.block;

            self.builder.position_at_start(ok_bb);

            strlen_fn = self._get_or_declare_extern("strlen", ir.IntType(64), [i8p]);
            slen = self.builder.call(strlen_fn, [buf_ptr], name="input.len");

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

            null_byte = ir.Constant(ir.IntType(8), 0);
            store_val = self.builder.select(
                is_newline, null_byte, last_byte, name="strip.nl"
            );
            self.builder.store(store_val, last_ptr);

            strip_cr_bb = func.append_basic_block(name="input.strip.cr");
            self.builder.cbranch(is_newline, strip_cr_bb, nostrip_bb);
            self.builder.position_at_start(strip_cr_bb);

            has_cr_len = self.builder.icmp_signed(
                ">=", slen, ir.Constant(ir.IntType(64), 2), name="has.cr.len"
            );
            strip_cr_check_bb = func.append_basic_block(name="input.strip.cr.check");
            self.builder.cbranch(has_cr_len, strip_cr_check_bb, nostrip_bb);
            self.builder.position_at_start(strip_cr_check_bb);

            cr_idx = self.builder.sub(
                slen, ir.Constant(ir.IntType(64), 2), name="cr.idx"
            );
            cr_ptr = self.builder.gep(result_ptr, [cr_idx], name="cr.ptr");
            cr_byte = self.builder.load(cr_ptr, name="cr.byte");
            is_cr = self.builder.icmp_signed(
                "==", cr_byte, ir.Constant(ir.IntType(8), 13), name="is.cr"
            );

            store_cr_val = self.builder.select(
                is_cr, null_byte, cr_byte, name="strip.cr"
            );
            self.builder.store(store_cr_val, cr_ptr);
            self.builder.branch(nostrip_bb);
            self.builder.position_at_start(nostrip_bb);
            self.builder.branch(merge_bb);
            ok_bb_end = self.builder.block;

            self.builder.position_at_start(merge_bb);
            phi = self.builder.phi(i8p, name="input.phi");
            phi.add_incoming(eof_str, eof_bb_end);
            phi.add_incoming(result_ptr, ok_bb_end);
            return phi;
        }

        if func_name == "open" {
            _open_result = self._emit_open(nd);
            if _open_result is not None {
                return _open_result;
            }
            self.emit(E5092, node_override=nd, kind="function", name=func_name);
            return None;
        }
    }

    if func_name in self.struct_types {
        return self._codegen_instantiation(nd);
    }
    func = self.func_symtab.get(func_name);
    if func is None {
        manifest = self.ir_in.gen.interop_manifest;
        binding = manifest.bindings.get(func_name);
        if binding is not None
        and (
            binding.source_context.value == "server"
            or (
                binding.source_context.value == "native"
                and binding.source_module is not None
            )
        ) {
            sig = self._callee_sig_of(nd);
            if sig is None
            and isinstance(binding.ast_node, uni.Ability)
            and isinstance(binding.ast_node.signature, uni.FuncSignature) {
                sig = binding.ast_node.signature;
            }
            if sig is None {
                self.emit(
                    E5092, node_override=nd, kind="function signature", name=func_name
                );
                return None;
            }
            param_ir_types: list = [];
            for p in sig.get_parameters() {
                param_ir_types.append(
                    self._resolve_jac_type(p.type_tag)
                        if p.type_tag is not None
                        else ir.IntType(64)
                );
            }
            ret_ir_type = self._resolve_jac_type(sig.return_type);
            func = self._get_or_declare_extern(func_name, ret_ir_type, param_ir_types);
        }
    }
    if func is None {
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

                if func_name in self.lambda_captures {
                    for (_cname, _c_alloca) in self.lambda_captures[func_name] {
                        _cval = self.builder.load(_c_alloca, name=f"cap.{_cname}");
                        _icoerced.append(_cval);
                    }
                }
                _icall_result = self.builder.call(
                    _loaded, _icoerced, name=f"icall.{func_name}"
                );

                for _icarg in _iargs {
                    if isinstance(_icarg.type, ir.PointerType)
                    and self._is_owned(_icarg) {
                        self._emit_rc_release_simple(_icarg, op="icall_arg", loc="");
                    }
                }
                return _icall_result;
            }
        }

        if _call_kind != "builtin" {
            self.emit(E5092, node_override=nd, kind="function", name=func_name);
        }
        return None;
    }

    args: list[ir.Value] = self._codegen_bound_args(nd, func, self_offset=0);

    if func_name in self.clib_fn_abi {
        return self._codegen_clib_call(func, func_name, args);
    }

    _is_foreign = func_name in self.clib_extern_names;
    coerced: list[ir.Value] = [];

    release_args: list[ir.Value] = [];
    _i8ptr = ir.IntType(8).as_pointer();
    for (i, arg) in enumerate(args) {
        if (
            _is_foreign
            and self._is_bytes_value(arg)
            and i < len(func.args)
            and (func.args[i].type == _i8ptr or self._is_bytes_type(func.args[i].type))
        ) {
            coerced.append(
                self._bytes_data_ptr(arg) if func.args[i].type == _i8ptr else arg
            );
            release_args.append(arg);
        } elif i < len(func.args) {
            _c = self._coerce_type(arg, func.args[i].type);
            coerced.append(_c);
            release_args.append(_c);
        } else {
            coerced.append(arg);
            release_args.append(arg);
        }
    }
    result = self.builder.call(func, coerced, name=f"call.{func_name}");

    self._release_owned_args(release_args, op="call_arg");

    if func_name in self.clib_extern_names {
        for (sname, abi_type) in self.clib_struct_abi_types.items() {
            if result.type == abi_type {
                result = self._coerce_type(
                    result, self.struct_types[sname].as_pointer()
                );
                break;
            }
        }

        if not isinstance(result.type, ir.PointerType) {
            for (sname, stype) in self.struct_types.items() {
                if sname in self.clib_struct_names and result.type == stype {
                    result = self._coerce_type(result, stype.as_pointer());
                    break;
                }
            }
        }
    }

    return result;
}

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
    if name == "NoneType" {
        return [8];
    }
    return [];
}

impl NaIRGenPass._isinstance_type_name(nd: uni.UniNode) -> (str | None) {
    if (
        isinstance(nd, uni.FuncCall)
        and self._get_name(nd.target) == "type"
        and nd.params
        and len(nd.params) == 1
        and isinstance(nd.params[0], uni.Null)
    ) {
        import from jaclang.compiler.symbol_utils { classify_call, CallKind }
        if classify_call(nd) == CallKind.BUILTIN {
            return "NoneType";
        }
        return None;
    }
    return self._get_name(nd);
}

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

    type_arg = params[1];
    names: list[str] = [];
    if isinstance(type_arg, uni.TupleVal) {
        for v in (type_arg.values or []) {
            nm = self._isinstance_type_name(v);
            if nm is not None {
                names.append(nm);
            }
        }
    } else {
        nm = self._isinstance_type_name(type_arg);
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
            return self._emit_isinstance_user(nd, operand, unresolved);
        }

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

    if isinstance(operand.type, ir.PointerType) and self._is_owned(operand) {
        self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
    }
    return result;
}

impl NaIRGenPass._emit_isinstance_user(
    nd: uni.FuncCall, operand: ir.Value, names: list[str]
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);

    if not isinstance(operand.type, ir.PointerType) {
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }

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
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }

    struct_name = self._struct_name_of(nd.params[0] if nd.params else None);
    if struct_name is None or struct_name not in self.struct_types {
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }
    if struct_name not in self.vtable_globals {
        if self._is_owned(operand) {
            self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
        }
        return ir.Constant(i1, 0);
    }

    pre_bb = self.builder.block;
    null_ptr = ir.Constant(operand.type, None);
    is_null = self.builder.icmp_unsigned(
        "==", operand, null_ptr, name="isinst.null.chk"
    );
    nonnull_bb = self.builder.append_basic_block(name="isinst.nonnull");
    merge_bb = self.builder.append_basic_block(name="isinst.merge");
    self.builder.cbranch(is_null, merge_bb, nonnull_bb);

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

    if self._is_owned(operand) {
        self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
    }
    end_nonnull = self.builder.block;
    self.builder.branch(merge_bb);

    self.builder.position_at_end(merge_bb);
    result = self.builder.phi(i1, name="isinst.result");
    result.add_incoming(ir.Constant(i1, 0), pre_bb);
    result.add_incoming(cmp, end_nonnull);
    return result;
}
