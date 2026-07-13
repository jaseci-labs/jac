import from jaclang.compiler.targets.abi { classify_foreign_fn }

impl NaIRGenPass.builder.getter -> ir.IRBuilder {
    if self._builder is None {
        raise RuntimeError(
            "NaIRGenPass.builder read with no active IRBuilder "
            "(outside a function body)"
        );
    }
    return self._builder;
}

impl NaIRGenPass._forward_declare_functions(module: uni.Module) -> None {
    for stmt in ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE) {
        self._maybe_declare_ability(stmt);
    }
}

impl NaIRGenPass._maybe_declare_ability(nd: uni.ElementStmt) -> None {
    if not isinstance(nd, uni.Ability) {
        return;
    }
    if nd.signature is None or not isinstance(nd.signature, uni.FuncSignature) {
        return;
    }
    name = nd.name_ref.sym_name if nd.name_ref else "unnamed";
    sig = nd.signature;

    param_types: list[ir.Type] = [];
    for p in sig.get_parameters() {
        param_types.append(
            self._resolve_jac_type(p) if p.type_tag is not None else ir.IntType(64)
        );
    }

    ret_type = self._resolve_jac_type(sig.return_type);

    fnty = ir.FunctionType(ret_type, param_types);
    func = ir.Function(self.llvm_module, fnty, name=name);

    for (i, p) in enumerate(sig.get_parameters()) {
        func.args[i].name = p.name.value if p.name else f"arg{i}";
    }
    self.func_symtab[name] = func;

    self._func_loc[name] = nd.loc.first_line if nd.loc else 0;

    if sig.return_type is not None {
        hints = self._extract_tuple_struct_hints(sig.return_type);
        if hints {
            self.func_ret_tuple_hints[name] = hints;
        }
        _rt = sig.return_type;

        if isinstance(_rt, uni.BinaryExpr) and getattr(_rt.op, 'value', '') == "|" {
            _rt = _rt.left;
        }
        _rname = self._get_name(_rt);
        if _rname is not None {
            self.func_ret_ann_name[name] = _rname;
        }
    }
    self.has_native_code = True;
}

impl NaIRGenPass._declare_clib_ability(nd: uni.Ability) -> None {
    if not isinstance(nd, uni.Ability) {
        return;
    }
    if nd.signature is None or not isinstance(nd.signature, uni.FuncSignature) {
        return;
    }
    name = nd.name_ref.sym_name if nd.name_ref else "unnamed";
    sig = nd.signature;

    _abi_triple = str(self.llvm_module.triple or "");
    _abi_supported = (
        "x86_64" in _abi_triple or "aarch64" in _abi_triple or "arm64" in _abi_triple
    );
    _decl_params = sig.get_parameters();

    is_variadic = sig.varargs is not None;
    plan: (dict | None) = None;
    if _abi_supported {
        _fdecl = self._foreign_fns().get(name);
        if _fdecl is not None {
            plan = classify_foreign_fn(
                self._foreign_model(), _fdecl["params"], _fdecl["ret"], _abi_triple
            );
        }
    }
    if plan is not None {
        sysv_param_types: list[ir.Type] = [];
        for slot in plan["sig"] {
            if slot[0] == "structptr" or slot[0] == "sretptr" {
                sysv_param_types.append(self._clib_c_type(slot[1]).as_pointer());
            } elif slot[0] == "coerce" {
                sysv_param_types.append(slot[1]);
            } else {
                _sp = _decl_params[slot[1]];
                sysv_param_types.append(
                    self._resolve_clib_type(_sp.type_tag.tag)
                        if (_sp.type_tag and _sp.type_tag.tag)
                        else ir.IntType(64)
                );
            }
        }

        param_plan = plan["params"];
        for pp in param_plan {
            if pp["kind"] == "scalar" {
                pp["type"] = sysv_param_types[pp["argpos"]];
            }
        }
        sysv_sret = plan["sret"];
        sysv_ret_plan = plan["ret"];
        _sig_ret = plan["sig_ret"];
        if _sig_ret[0] == "void" {
            sysv_ret_type = ir.VoidType();
        } elif _sig_ret[0] == "coerce" {
            _rco = _sig_ret[1];
            if len(_rco) == 1 {
                sysv_ret_type = _rco[0];
            } else {
                sysv_ret_type = ir.LiteralStructType(_rco);
            }
        } else {
            sysv_ret_type = self._resolve_clib_type(sig.return_type);
            sysv_ret_plan["type"] = sysv_ret_type;
        }
        sysv_fnty = ir.FunctionType(
            sysv_ret_type, sysv_param_types, var_arg=is_variadic
        );
        if name in self.extern_funcs {
            sysv_func = self.extern_funcs[name];
        } elif name in self.func_symtab {
            sysv_func = self.func_symtab[name];
        } else {
            sysv_func = ir.Function(self.llvm_module, sysv_fnty, name=name);
        }
        if sysv_sret and len(sysv_func.args) > 0 {
            sysv_func.args[0].add_attribute("sret");
            _sal = sysv_ret_plan["align"];
            sysv_func.args[0].align = _sal if _sal > 8 else 8;
            sysv_func.args[0].name = "agg.result";
        }
        for pp in param_plan {
            _pos = pp["argpos"];
            if pp["kind"] == "struct_mem" and _pos < len(sysv_func.args) {
                _ba = sysv_func.args[_pos];

                if pp["byval"] {
                    _ba.add_attribute("byval");
                    _bal = pp["align"];
                    _ba.align = _bal if _bal > 8 else 8;
                }
                _ba.name = pp["pname"];
            } elif pp["kind"] == "scalar" and _pos < len(sysv_func.args) {
                sysv_func.args[_pos].name = pp["pname"];
            } elif pp["kind"] == "struct_reg" {
                _co = pp["coerce"];
                if len(_co) == 1 and _pos < len(sysv_func.args) {
                    sysv_func.args[_pos].name = pp["pname"];
                } else {
                    for _j in range(len(_co)) {
                        if (_pos + _j) < len(sysv_func.args) {
                            sysv_func.args[_pos + _j].name = f"{pp['pname']}.{_j}";
                        }
                    }
                }
            }
        }
        self.clib_fn_abi[name] = {
            "params": param_plan,
            "ret": sysv_ret_plan,
            "sret": sysv_sret
        };
        self.func_symtab[name] = sysv_func;
        self.has_native_code = True;
        return;
    }

    fixed_params: list = [];
    for p in sig.get_parameters() {
        if p.is_vararg or p.is_kwargs {
            continue;
        }
        fixed_params.append(p);
    }
    param_types: list[ir.Type] = [];
    for p in fixed_params {
        if p.type_tag and p.type_tag.tag {
            param_types.append(self._resolve_clib_type(p.type_tag.tag));
        } else {
            param_types.append(ir.IntType(64));
        }
    }

    ret_type = self._resolve_clib_type(sig.return_type);

    fnty = ir.FunctionType(ret_type, param_types, var_arg=is_variadic);
    if name in self.extern_funcs {
        func = self.extern_funcs[name];
    } elif name in self.func_symtab {
        func = self.func_symtab[name];
    } else {
        func = ir.Function(self.llvm_module, fnty, name=name);
    }

    for (i, p) in enumerate(fixed_params) {
        func.args[i].name = p.name.value if p.name else f"arg{i}";
    }
    self.func_symtab[name] = func;
    self.has_native_code = True;
}

impl NaIRGenPass._codegen_ability(nd: uni.Ability) -> None {
    name = (nd).name_ref.sym_name if (nd).name_ref else "unnamed";
    if isinstance(nd.signature, uni.FuncSignature) {
        for _vp in nd.signature.get_parameters() {
            if _vp.unpack is not None {
                self.emit(
                    E5090,
                    node_override=_vp,
                    kind="variadic parameter",
                    name=f"{_vp.unpack.value}{_vp.name.value if _vp.name else ''}"
                );
                return;
            }
        }
    }
    func = self.func_symtab.get(name);
    if func is None {
        return;
    }

    if name in self.clib_extern_names {
        return;
    }

    block = func.append_basic_block(name="entry");
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};

    self._attach_di_subprogram(
        func, name, self._func_loc.get(name, nd.loc.first_line if nd.loc else 0)
    );

    sig = (nd).signature;
    import from jaclang.compiler.ownership { param_plainly_rebound }
    for (i, p) in enumerate(sig.get_parameters()) {
        param_name = p.name.value if p.name else f"arg{i}";
        arg_val = func.args[i];
        alloca = self.builder.alloca(arg_val.type, name=param_name);
        self.builder.store(arg_val, alloca);
        self.local_vars[param_name] = alloca;

        if isinstance(arg_val.type, ir.PointerType)
        and param_plainly_rebound(p.name.sym if p.name else None) {
            self._emit_rc_retain(arg_val, op="param_promote", loc=name);
        } else {
            self.param_vars.add(param_name);
        }
    }

    body = ModuleCodegenPass.unwrap_body(nd);
    if body is not None {
        _symtab_before_body = dict(self.func_symtab);
        self._codegen_body(body);
        self.func_symtab = _symtab_before_body;
    }

    if not self.builder.block.is_terminated {
        _fc_loc = f"{self.ir_in.loc.mod_path}:{nd.loc.last_line if nd.loc else 0}";

        self._emit_scope_cleanup(skip_var=None, loc=_fc_loc);
        ret_type = func.return_value.type;
        if isinstance(ret_type, ir.VoidType) {
            self.builder.ret_void();
        } elif isinstance(ret_type, ir.PointerType) {
            self.builder.ret(ir.Constant(ret_type, None));
        } else {
            self.builder.ret(ir.Constant(ret_type, 0));
        }
    }

    self._finalize_di_locations(
        func, self._func_loc.get(name, nd.loc.first_line if nd.loc else 1)
    );

    _is_priv = nd.access and nd.access.tag.name == Tok.KW_PRIV;
    if _is_priv {
        func.linkage = "internal";
    }

    _is_pub = nd.access and nd.access.tag.name == Tok.KW_PUB;
    if _is_pub and self.ir_in?.gen and func.name.isidentifier() {
        if func.name not in self.ir_in.gen._exported_symbols {
            self.ir_in.gen._exported_symbols.append(func.name);
        }
    }

    (nd).gen.llvm_ir = func;
    self._builder = None;
}

impl NaIRGenPass._codegen_test(nd: uni.Test) -> None {
    import from jaclang.jac0core.codeinfo { native_test_symbol }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    if self._exc_raise_fn is None {
        self._declare_exception_runtime();
    }
    test_name = nd.name.sym_name;
    line = nd.loc.first_line if nd.loc else 0;
    symbol = native_test_symbol(test_name, line);
    fnty = ir.FunctionType(i8p, []);
    func = ir.Function(self.llvm_module, fnty, name=symbol);

    func.attributes.add("optnone");
    func.attributes.add("noinline");
    entry_bb = func.append_basic_block(name="entry");
    body_bb = func.append_basic_block(name="test.body");
    success_bb = func.append_basic_block(name="test.success");
    fail_bb = func.append_basic_block(name="test.fail");
    self._builder = ir.IRBuilder(entry_bb);
    self.local_vars = {};
    saved_param_vars = self.param_vars;
    self.param_vars = set();
    self._attach_di_subprogram(func, symbol, line);

    exc_state = self.builder.alloca(self._exc_state_type, name="exc.state");
    self.builder.call(self._exc_push_fn, [exc_state]);
    env_ptr = self.builder.gep(
        exc_state, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="env.ptr"
    );
    env_i8p = self.builder.bitcast(env_ptr, i8p, name="env.i8p");
    setjmp_fn = self.extern_funcs["setjmp"];
    setjmp_result = self.builder.call(setjmp_fn, [env_i8p], name="setjmp.result");
    is_exception = self.builder.icmp_signed(
        "!=", setjmp_result, ir.Constant(i32, 0), name="is.exception"
    );
    self.builder.cbranch(is_exception, fail_bb, body_bb);

    self.builder.position_at_end(body_bb);
    self._codegen_body(nd.body);
    if not self.builder.block.is_terminated {
        self.builder.branch(success_bb);
    }

    self.builder.position_at_end(success_bb);
    self.builder.call(self._exc_pop_fn, []);
    _tc_loc = f"{self.ir_in.loc.mod_path}:{nd.loc.last_line if nd.loc else 0}";
    self._emit_scope_cleanup(skip_var=None, loc=_tc_loc);
    self.builder.ret(ir.Constant(i8p, None));

    self.builder.position_at_end(fail_bb);
    self.builder.call(self._exc_pop_fn, []);
    exc_obj_ptr = self.builder.gep(
        exc_state, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="exc.obj.ptr"
    );
    exc_msg = self.builder.load(exc_obj_ptr, name="exc.msg");
    self.builder.ret(exc_msg);
    self._finalize_di_locations(func, line);
    self.param_vars = saved_param_vars;
    self._builder = None;
    desc = nd.description.lit_value if nd.description else "";
    self.native_tests.append((test_name, symbol, desc, line));
    self.has_native_code = True;

    nd.code_context = CodeContext.NATIVE;
}

impl NaIRGenPass._codegen_nested_ability(nd: uni.Ability) -> None {
    name = nd.name_ref.sym_name if nd.name_ref else "unnamed";
    sig = nd.signature;

    param_types: list = [];
    param_names: list = [];
    sig_params = sig.get_parameters() if sig is not None else [];
    for (i, p) in enumerate(sig_params) {
        p_name = p.name.value if p?.name and p.name else f"arg{i}";

        p_type = self._resolve_jac_type(p)
            if p?.type_tag and p.type_tag is not None
            else ir.IntType(64);
        param_types.append(p_type);
        param_names.append(p_name);
    }
    ret_type = ir.IntType(64);
    if sig is not None and sig.return_type is not None {
        ret_type = self._resolve_jac_type(sig.return_type);
    }
    body = ModuleCodegenPass.unwrap_body(nd);

    free_vars = [
        s.sym_name
        for s in nd.get_enclosing_captures()
        if s.sym_name in self.local_vars
    ];
    if free_vars {
        self.emit(
            E5090,
            node_override=nd,
            kind="statement",
            name="Ability (nested function capturing enclosing locals)"
        );
        return;
    }

    self._str_count += 1;
    mangled = f"__jac_nested_{name}_{self._str_count}";
    fn_type = ir.FunctionType(ret_type, param_types);
    fn = ir.Function(self.llvm_module, fn_type, name=mangled);
    fn.linkage = "private";
    for (i, arg) in enumerate(fn.args) {
        if i < len(param_names) {
            arg.name = param_names[i];
        }
    }

    self.func_symtab[name] = fn;

    saved_builder = self._builder;
    saved_locals = self.local_vars;
    saved_param_vars = self.param_vars;
    saved_var_list_struct = self.var_list_elem_struct;
    self._builder = ir.IRBuilder(fn.append_basic_block("entry"));
    self.local_vars = {};
    self.param_vars = set();
    self.var_list_elem_struct = {};
    for (i, arg) in enumerate(fn.args) {
        alloca = self._entry_alloca(arg.type, param_names[i]);
        self.builder.store(arg, alloca);
        self.local_vars[param_names[i]] = alloca;
        self.param_vars.add(param_names[i]);
    }
    if body is not None {
        self._codegen_body(body);
    }

    for bb in fn.basic_blocks {
        if not bb.is_terminated {
            tb = ir.IRBuilder(bb);
            if isinstance(ret_type, ir.VoidType) {
                tb.ret_void();
            } elif isinstance(ret_type, ir.PointerType) {
                tb.ret(ir.Constant(ret_type, None));
            } else {
                tb.ret(ir.Constant(ret_type, 0));
            }
        }
    }

    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.param_vars = saved_param_vars;
    self.var_list_elem_struct = saved_var_list_struct;
    nd.gen.llvm_ir = fn;
}

impl NaIRGenPass._define_function(name: str, fnty: ir.FunctionType) -> ir.Function {
    try {
        self.llvm_module.get_global(name);
    } except KeyError {
        return ir.Function(self.llvm_module, fnty, name=name);
    }
    raise RuntimeError(
        f"native codegen internal error: duplicate definition of '{name}'. "
        f"This fixed-name runtime symbol must be emitted exactly once per module, "
        f"but its emitter was reached a second time. Collect the source nodes and "
        f"emit once, or add a memoized get-or-emit guard (see issue #6660)."
    );
}

impl NaIRGenPass._emit_glob_init_func -> None {
    saved_builder = self._builder;
    saved_locals = self.local_vars if self?.local_vars else {};
    saved_di_sp = self._di_current_sp;

    fnty = ir.FunctionType(ir.VoidType(), []);
    func = self._define_function("__jac_glob_init", fnty);
    block = func.append_basic_block(name="entry");
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};

    self._attach_di_subprogram(func, "__jac_glob_init", 0);
    if self?._global_init_nodes and self._global_init_nodes {
        for init_tuple in self._global_init_nodes {
            var_name = init_tuple[0];
            init_node = init_tuple[1];
            var_type = init_tuple[2];
            init_val = self._codegen_expr(init_node);

            if init_val is None and isinstance(var_type, ir.PointerType) {
                for (dict_key, dtype) in self.dict_types.items() {
                    if var_type == dtype.as_pointer() {
                        helpers = self.dict_helpers.get(dict_key);
                        if helpers is not None {
                            init_val = self.builder.call(
                                helpers["new"], [], name=f"dict.init.{var_name}"
                            );
                            break;
                        }
                    }
                }
            }

            if init_val is None and isinstance(var_type, ir.PointerType) {
                for (elem_key, ltype) in self.list_types.items() {
                    if var_type == ltype.as_pointer() {
                        helpers = self.list_helpers.get(elem_key);
                        if helpers is not None {
                            init_val = self.builder.call(
                                helpers["new"], [], name=f"list.init.{var_name}"
                            );
                            break;
                        }
                    }
                }
            }
            if init_val is not None {
                global_var = self.global_vars.get(var_name);
                if global_var is not None {
                    coerced = self._coerce_type(init_val, var_type);
                    self.builder.store(coerced, global_var);
                }
            }
        }
    }
    self.builder.ret_void();

    self._finalize_di_locations(func, 0);
    self.func_symtab["__jac_glob_init"] = func;

    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self._di_current_sp = saved_di_sp;
}

impl NaIRGenPass._codegen_entry(nodes: list[uni.ModuleCode]) -> None {
    if not nodes {
        return;
    }
    i64 = ir.IntType(64);
    import re;

    import from jaclang.jac0core.codeinfo { native_safe_sym }

    fnty = ir.FunctionType(ir.VoidType(), []);
    func = self._define_function("jac_entry", fnty);
    self.func_symtab["jac_entry"] = func;

    block = func.append_basic_block(name="entry");
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};

    _first = nodes[0];
    entry_line = _first.loc.first_line if _first.loc else 0;
    self._attach_di_subprogram(func, "jac_entry", entry_line);

    self._emit_glob_init_func();
    glob_init_fn = self.func_symtab.get("__jac_glob_init");

    _i8p = ir.IntType(8).as_pointer();
    _i32 = ir.IntType(32);
    _getenv_fn = self._get_or_declare_extern("getenv", _i8p, [_i8p]);
    _nogc_str = self._get_snprintf_fmt("JAC_NO_GC");
    _nogc_ptr = self.builder.gep(
        _nogc_str,
        [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)],
        name="nogc.key"
    );
    _nogc_val = self.builder.call(_getenv_fn, [_nogc_ptr], name="nogc.env");
    _nogc_null = ir.Constant(_i8p, None);
    _nogc_set = self.builder.icmp_unsigned(
        "!=", _nogc_val, _nogc_null, name="nogc.set"
    );
    _nogc_then = func.append_basic_block("nogc_disable");
    _nogc_cont = func.append_basic_block("nogc_cont");
    self.builder.cbranch(_nogc_set, _nogc_then, _nogc_cont);
    b_nogc = ir.IRBuilder(_nogc_then);
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    b_nogc.call(self.rc_gc_disable_fn, []);
    b_nogc.branch(_nogc_cont);
    self._builder = ir.IRBuilder(_nogc_cont);

    if self._gc_mode() == "cycles" {
        _cyc_str = self._get_snprintf_fmt("JAC_GC_CYCLES");
        _cyc_ptr = self.builder.gep(
            _cyc_str,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)],
            name="cyc.key"
        );
        _cyc_val = self.builder.call(_getenv_fn, [_cyc_ptr], name="cyc.env");
        _cyc_set = self.builder.icmp_unsigned(
            "!=", _cyc_val, ir.Constant(_i8p, None), name="cyc.set"
        );
        _cyc_then = func.append_basic_block("cyc_enable");
        _cyc_cont = func.append_basic_block("cyc_cont");
        self.builder.cbranch(_cyc_set, _cyc_then, _cyc_cont);
        b_cyc = ir.IRBuilder(_cyc_then);
        if self.rc_alloc_fn is None {
            self._emit_rc_helpers();
        }
        b_cyc.call(self.rc_cycles_enable_fn, []);
        b_cyc.branch(_cyc_cont);
        self._builder = ir.IRBuilder(_cyc_cont);
    }
    if glob_init_fn is not None {
        self.builder.call(glob_init_fn, []);
    }

    _manifest = self.ir_in.gen.interop_manifest if (self.ir_in?.gen) else None;
    _all_na_sources = _manifest.native_transitive_sources if _manifest else [];
    _seen_init_mods: set = set();
    for _source_mod in _all_na_sources {
        if _source_mod is None or _source_mod in _seen_init_mods {
            continue;
        }
        _seen_init_mods.add(_source_mod);

        safe_name = native_safe_sym(_source_mod);
        init_name = f"__jac_glob_init_{safe_name}";

        imp_init_fn = self.func_symtab.get(init_name);
        if imp_init_fn is None {
            imp_init_fnty = ir.FunctionType(ir.VoidType(), []);
            imp_init_fn = ir.Function(self.llvm_module, imp_init_fnty, name=init_name);
            self.func_symtab[init_name] = imp_init_fn;
        }

        _guard_kernel = (
            (self._osp_kernel_inited_gv is not None)
            and (imp_init_fn is self._osp_kernel_glob_init_fn)
        );
        if _guard_kernel {
            _i8 = ir.IntType(8);
            _gk_run = self.builder.function.append_basic_block("osp_kinit_run");
            _gk_done = self.builder.function.append_basic_block("osp_kinit_done");
            self.builder.cbranch(
                self.builder.icmp_unsigned(
                    "!=",
                    self.builder.load(
                        self._osp_kernel_inited_gv, name="osp.kinited.entry"
                    ),
                    ir.Constant(_i8, 0)
                ),
                _gk_done,
                _gk_run
            );
            self.builder.position_at_end(_gk_run);
            self.builder.store(ir.Constant(_i8, 1), self._osp_kernel_inited_gv);
        }
        _init_call = self.builder.call(imp_init_fn, []);

        if self.di_cu is not None and self._di_current_sp is not None {
            try {
                import os as _os_di;

                _mod_fn = _source_mod;
                if not _mod_fn.endswith(".jac") {
                    _mod_fn = _mod_fn.replace(".", "/") + ".na.jac";
                }
                _di_imp_file = self.llvm_module.add_debug_info(
                    "DIFile",
                    {
                        "filename": _os_di.path.basename(_mod_fn),
                        "directory": _os_di.path.dirname(_mod_fn) or "."
                    }
                );
                _di_sub_ty = self.llvm_module.add_debug_info(
                    "DISubroutineType", {"types": self.llvm_module.add_metadata([])}
                );
                _di_init_sp = self.llvm_module.add_debug_info(
                    "DISubprogram",
                    {
                        "name": init_name,
                        "file": _di_imp_file,
                        "line": 0,
                        "isDefinition": False,
                        "unit": self.di_cu,
                        "type": _di_sub_ty
                    },
                    is_distinct=True
                );
                _di_init_loc = self.llvm_module.add_debug_info(
                    "DILocation", {"line": 1, "column": 0, "scope": _di_init_sp}
                );
                _init_call.set_metadata("dbg", _di_init_loc);
            } except Exception { }
        }
        if _guard_kernel {
            self.builder.branch(_gk_done);
            self.builder.position_at_end(_gk_done);
        }
    }

    for _ent in nodes {
        if self.builder.block.is_terminated {
            break;
        }
        if (_ent).body {
            self._codegen_body((_ent).body);
        }
    }

    if not self.builder.block.is_terminated {
        i32 = ir.IntType(32);
        i8p = ir.IntType(8).as_pointer();
        fflush_fn = self._get_or_declare_extern("fflush", i32, [i8p]);
        null_ptr = ir.Constant(i8p, None);
        self.builder.call(fflush_fn, [null_ptr]);

        _last = nodes[-1];
        self._emit_scope_cleanup(
            skip_var=None,
            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{_last.loc.last_line
                if _last.loc
                else 0}"
        );

        if self.rc_live_head_gv is not None {
            self._emit_rc_live_dump();
        }
        self.builder.ret_void();
    }

    self._finalize_di_locations(func, entry_line);
    self.has_native_code = True;
    self._builder = None;
}
