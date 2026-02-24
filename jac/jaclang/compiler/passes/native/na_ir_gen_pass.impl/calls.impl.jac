"""Function call codegen including builtins and method calls."""
"""Generate function call."""
impl NaIRGenPass._codegen_call(nd: uni.FuncCall) -> (ir.Value | None) {
    # Handle method calls: obj.method(args)
    if isinstance(nd.target, uni.AtomTrailer) and nd.target.is_attr {
        return self._codegen_method_call(nd);
    }
    func_name = self._get_name(nd.target);
    if func_name is None {
        return None;
    }
    # Handle print() specially
    if func_name == "print" {
        return self._emit_print(nd);
    }
    # Handle len() builtin for lists, dicts, sets, and strings
    if func_name == "len" {
        params_l = nd.params or [];
        if params_l {
            arg_name = self._get_name(params_l[0]);
            elem_type_name: (str | None) = None;
            if arg_name is not None and arg_name in self.var_list_elem_type {
                elem_type_name = self.var_list_elem_type[arg_name];
            }
            arg_val = self._codegen_expr(params_l[0]);
            if arg_val is not None {
                # Check for dict type first
                if arg_name is not None and arg_name in self.var_dict_type {
                    dict_key = self.var_dict_type[arg_name];
                    helpers = self.dict_helpers.get(dict_key);
                    if helpers is not None {
                        return self.builder.call(
                            helpers["len"], [arg_val], name="dict.len"
                        );
                    }
                }
                # Check for dict type by inferring from value
                for (dict_key, helpers) in self.dict_helpers.items() {
                    dict_type = self.dict_types.get(dict_key);
                    if dict_type is not None and arg_val.type == dict_type.as_pointer() {
                        return self.builder.call(
                            helpers["len"], [arg_val], name="dict.len"
                        );
                    }
                }
                # Check for set type
                if arg_name is not None and arg_name in self.var_set_elem_type {
                    set_key = self.var_set_elem_type[arg_name];
                    helpers = self.set_helpers.get(set_key);
                    if helpers is not None {
                        return self.builder.call(
                            helpers["len"], [arg_val], name="set.len"
                        );
                    }
                }
                # Check for set type by inferring from value
                for (set_key, helpers) in self.set_helpers.items() {
                    set_type = self.set_types.get(set_key);
                    if set_type is not None and arg_val.type == set_type.as_pointer() {
                        return self.builder.call(
                            helpers["len"], [arg_val], name="set.len"
                        );
                    }
                }
                # Check for list type
                if elem_type_name is None {
                    elem_type_name = self._infer_list_elem_type(arg_val);
                }
                if elem_type_name is not None {
                    helpers = self.list_helpers.get(elem_type_name);
                    if helpers is not None {
                        return self.builder.call(
                            helpers["len"], [arg_val], name="list.len"
                        );
                    }
                }
                # String len: call strlen
                if arg_val.type == ir.IntType(8).as_pointer() {
                    strlen_fn = self._get_or_declare_extern(
                        "strlen", ir.IntType(64), [ir.IntType(8).as_pointer()]
                    );
                    return self.builder.call(strlen_fn, [arg_val], name="str.len");
                }
            }
        }
    }
    # Handle multi-arg builtins via emitter dispatch
    if func_name in ("abs", "min", "max", "pow") {
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
            if result is not None {
                return result;
            }
        }
    }
    # Handle ord, int, chr, str, hex, oct, bin, round, float builtins via emitter dispatch
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
        "bool"
    ) {
        params_l = nd.params or [];
        if params_l {
            arg_val = self._codegen_expr(params_l[0]);
            if arg_val is not None {
                result = self._dispatch_builtin(func_name, [arg_val]);
                if result is not None {
                    return result;
                }
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
            }
        }
        # Allocate buffer, call fgets
        buf_size = 256;
        buf_type = ir.ArrayType(ir.IntType(8), buf_size);
        buf = self.builder.alloca(buf_type, name="input.buf");
        buf_ptr = self.builder.bitcast(buf, i8p, name="input.ptr");
        # Get stdin via fdopen or use __stdinp — use a simple approach with fgets(buf, size, stdin)
        # Declare stdin as external global
        stdin_name = "stdin";
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
        fgets = self._get_or_declare_extern("fgets", i8p, [i8p, ir.IntType(32), i8p]);
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
        gc_malloc_eof = self._get_or_declare_extern("GC_malloc", i8p, [ir.IntType(64)]);
        eof_str = self.builder.call(
            gc_malloc_eof, [ir.Constant(ir.IntType(64), 1)], name="eof.str"
        );
        self.builder.store(ir.Constant(ir.IntType(8), 0), eof_str);
        self.builder.branch(merge_bb);
        eof_bb_end = self.builder.block;
        # OK path: process input normally
        self.builder.position_at_start(ok_bb);
        # Strip trailing newline: find length, then set buf[len-1] = 0 if it's '\n'
        strlen_fn = self._get_or_declare_extern("strlen", ir.IntType(64), [i8p]);
        slen = self.builder.call(strlen_fn, [buf_ptr], name="input.len");
        # Copy to GC-allocated string
        gc_malloc = self._get_or_declare_extern("GC_malloc", i8p, [ir.IntType(64)]);
        alloc_size = self.builder.add(
            slen, ir.Constant(ir.IntType(64), 1), name="alloc.size"
        );
        result_ptr = self.builder.call(gc_malloc, [alloc_size], name="input.result");
        memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, ir.IntType(64)]);
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
        cr_idx = self.builder.sub(slen, ir.Constant(ir.IntType(64), 2), name="cr.idx");
        cr_ptr = self.builder.gep(result_ptr, [cr_idx], name="cr.ptr");
        cr_byte = self.builder.load(cr_ptr, name="cr.byte");
        is_cr = self.builder.icmp_signed(
            "==", cr_byte, ir.Constant(ir.IntType(8), 13), name="is.cr"
        );
        # Conditionally null-terminate at CR position
        store_cr_val = self.builder.select(is_cr, null_byte, cr_byte, name="strip.cr");
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
                    param_ir_types.append(self.type_map.get(pt, ir.IntType(64)));
                }
                ret_ir_type = self.type_map.get(binding.ret_type, ir.IntType(64));
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
                        param_ir_types.append(self.type_map.get(pt, ir.IntType(64)));
                    }
                } else {
                    # Infer parameter types from call arguments
                    params = nd.params or [];
                    for param in params {
                        param_ir_types.append(ir.IntType(64));  # Default to i64
                    }
                }
                ret_ir_type = self.type_map.get(binding.ret_type, ir.IntType(64));
                func = self._get_or_declare_extern(
                    func_name, ret_ir_type, param_ir_types
                );
            }
        }
    }
    if func is None {
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
    return result;
}
# ─── External Function Support ───────────────────────────────
