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

    if self._ability_is_generator(nd) {
        self._ensure_iter_types();
        self.generator_fns[name] = nd;
        ret_type = self._jac_iter_type.as_pointer();
    } else {
        ret_type = self._resolve_jac_type(sig.return_type);
    }

    fnty = ir.FunctionType(ret_type, param_types);

    _dec_names: list[str] = [];
    if nd.decorators
    and not isinstance(nd.parent, uni.Archetype)
    and nd.find_parent_of_type(uni.Ability) is None
    and name not in self.generator_fns {
        for _dx in nd.decorators {
            if isinstance(_dx, uni.Name) {
                _dec_names.append(_dx.value);
            }
        }
        if len(_dec_names) != len(nd.decorators) {
            _dec_names = [];
        }
    }

    if _dec_names {
        func = ir.Function(self.llvm_module, fnty, name=f"__jac_dec_raw_{name}");
        func.linkage = "private";
        slot_gv = ir.GlobalVariable(
            self.llvm_module, fnty.as_pointer(), name=f"{name}.__decslot"
        );
        slot_gv.linkage = "private";
        slot_gv.initializer = ir.Constant(fnty.as_pointer(), None);
        self.decorated_fns[name] = (func, slot_gv, _dec_names, fnty);
    } else {
        func = ir.Function(self.llvm_module, fnty, name=name);
    }

    for (i, p) in enumerate(sig.get_parameters()) {
        func.args[i].name = p.name.value if p.name else f"arg{i}";
    }
    self.func_symtab[name] = func;

    self._func_loc[name] = nd.loc.first_line if nd.loc else 0;

    self._record_ret_facts(name, sig);
    self.has_native_code = True;
}

impl NaIRGenPass._normalize_type_key(key: str) -> str {
    if key.startswith("type[") and key.endswith("]") {
        key = key[5:-1];
    }
    if " | " in key {
        for part in key.split(" | ") {
            _p = part.strip();
            if _p.startswith("type[") and _p.endswith("]") {
                _p = _p[5:-1];
            }
            if _p not in ("None", "NoneType") {
                return _p;
            }
        }
    }
    return key;
}

impl NaIRGenPass._record_ret_facts(name: str, sig: uni.FuncSignature) -> None {
    _rt = sig.return_type;
    if _rt is None {
        return;
    }
    if isinstance(_rt, uni.BinaryExpr) and getattr(_rt.op, 'value', '') == "|" {
        _rt = _rt.left;
    }
    _rtb = _rt?.type;
    if _rtb is not None {
        try {
            self.func_ret_type_key[name] = self._normalize_type_key(_rtb.mangle());
        } except Exception { }
    }
    elems: list = [];
    if isinstance(_rt, uni.TupleVal) {
        elems = list(_rt.values or []);
    } elif _rt?.right and _rt.right?.slices {
        for s in (_rt.right.slices or []) {
            inner = s.start if s?.start else s;
            if isinstance(inner, uni.TupleVal) {
                elems.extend(list(inner.values or []));
            } else {
                elems.append(inner);
            }
        }
    }
    if elems {
        keys: list = [];
        for e in elems {
            _ek: (str | None) = None;
            _etb = e?.type if isinstance(e, uni.Expr) else None;
            if _etb is not None {
                try {
                    _ek = self._normalize_type_key(_etb.mangle());
                } except Exception { }
            }
            keys.append(_ek);
        }
        self.func_ret_elem_keys[name] = keys;
    }
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
    func = self.func_symtab.get(name);
    if func is None {
        return;
    }

    if name in self.clib_extern_names {
        return;
    }

    if name in self.generator_fns and self.generator_fns[name] is nd {
        self._codegen_generator(nd, func);
        return;
    }

    block = func.append_basic_block(name="entry");
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.param_vars = set();
    self.nogc_stack_vars = set();
    self.region_handle_vars = set();
    self.closure_cell_vars = set();
    self.closure_cell_handles = {};

    self._attach_di_subprogram(
        func, name, self._func_loc.get(name, nd.loc.first_line if nd.loc else 0)
    );

    body = ModuleCodegenPass.unwrap_body(nd);
    if body is not None {
        _scan_owner = nd.body if isinstance(nd.body, uni.ImplDef) else nd;
        self._scan_closure_escapes(_scan_owner, body);
    }

    sig = (nd).signature;
    for (i, p) in enumerate(sig.get_parameters()) {
        param_name = p.name.value if p.name else f"arg{i}";
        arg_val = func.args[i];
        if param_name in self.closure_cell_vars {
            slot = self._emit_closure_cell(param_name, arg_val.type);
            self.builder.store(arg_val, slot);
            self.local_vars[param_name] = slot;
            if isinstance(arg_val.type, ir.PointerType) {
                self._emit_rc_retain(arg_val, op="param_cell", loc=name);
            }
            continue;
        }
        alloca = self.builder.alloca(arg_val.type, name=param_name);
        self.builder.store(arg_val, alloca);
        self.local_vars[param_name] = alloca;

        if isinstance(arg_val.type, ir.PointerType)
        and bool(p.name?.sym?.param_rebound) {
            self._emit_rc_retain(arg_val, op="param_promote", loc=name);
        } else {
            self.param_vars.add(param_name);
        }
    }

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
    self.nogc_stack_vars = set();
    self.region_handle_vars = set();
    saved_param_vars = self.param_vars;
    self.param_vars = set();
    saved_cell_vars = self.closure_cell_vars;
    saved_cell_handles = self.closure_cell_handles;
    self.closure_cell_vars = set();
    self.closure_cell_handles = {};
    if nd.body {
        self._scan_closure_escapes(nd, nd.body);
    }
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
    self.closure_cell_vars = saved_cell_vars;
    self.closure_cell_handles = saved_cell_handles;
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

    rebound: set = set();
    for _scope in ([nd] + nd.get_all_sub_nodes(typ=uni.UniScopeNode)) {
        for _rn in _scope.implicit_rebinds {
            rebound.add(_rn);
        }
    }
    captures: list[tuple] = [];
    for fv_name in free_vars {
        cap_alloca = self.local_vars[fv_name];
        cap_mode = "ptr" if fv_name in rebound else "val";
        cap_type = cap_alloca.type if cap_mode == "ptr" else cap_alloca.type.pointee;
        captures.append((fv_name, cap_mode, cap_type));
        param_types.append(cap_type);
    }

    self._str_count += 1;
    mangled = f"__jac_nested_{name}_{self._str_count}";
    fn_type = ir.FunctionType(ret_type, param_types);
    fn = ir.Function(self.llvm_module, fn_type, name=mangled);
    fn.linkage = "private";
    for (i, arg) in enumerate(fn.args) {
        if i < len(param_names) {
            arg.name = param_names[i];
        } else {
            arg.name = f"cap.{captures[i - len(param_names)][0]}";
        }
    }

    self.func_symtab[name] = fn;
    if captures {
        self.nested_captures[name] = (
            fn,
            [(cname, cmode) for (cname, cmode, _ct) in captures]
        );
    }

    saved_builder = self._builder;
    saved_locals = self.local_vars;
    saved_param_vars = self.param_vars;
    saved_var_list_struct = self.var_list_elem_struct;
    saved_cell_vars = self.closure_cell_vars;
    saved_cell_handles = self.closure_cell_handles;
    self._builder = ir.IRBuilder(fn.append_basic_block("entry"));
    self.local_vars = {};
    self.nogc_stack_vars = set();
    self.region_handle_vars = set();
    self.param_vars = set();
    self.var_list_elem_struct = {};
    self.closure_cell_vars = set();
    self.closure_cell_handles = {};
    if body is not None {
        self._scan_closure_escapes(nd, body);
    }
    for (i, arg) in enumerate(fn.args) {
        if i < len(param_names) {
            if param_names[i] in self.closure_cell_vars {
                slot = self._emit_closure_cell(param_names[i], arg.type);
                self.builder.store(arg, slot);
                self.local_vars[param_names[i]] = slot;
                if isinstance(arg.type, ir.PointerType) {
                    self._emit_rc_retain(arg, op="param_cell", loc=name);
                }
                continue;
            }
            alloca = self._entry_alloca(arg.type, param_names[i]);
            self.builder.store(arg, alloca);
            self.local_vars[param_names[i]] = alloca;
            self.param_vars.add(param_names[i]);
            continue;
        }
        (cap_name, cap_mode, _cap_type) = captures[i - len(param_names)];
        if cap_mode == "ptr" {
            self.local_vars[cap_name] = arg;
        } else {
            alloca = self._entry_alloca(arg.type, cap_name);
            self.builder.store(arg, alloca);
            self.local_vars[cap_name] = alloca;
        }
        self.param_vars.add(cap_name);
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
    self.closure_cell_vars = saved_cell_vars;
    self.closure_cell_handles = saved_cell_handles;
    nd.gen.llvm_ir = fn;
}

impl NaIRGenPass._ability_is_generator(nd: uni.Ability) -> bool {
    for y in nd.get_all_sub_nodes(typ=uni.YieldExpr) {
        if y.find_parent_of_type(uni.Ability) is nd {
            return True;
        }
    }
    return False;
}

impl NaIRGenPass._generator_elem_type(nd: uni.Ability) -> (ir.Type | None) {
    sig = nd.signature;
    if not isinstance(sig, uni.FuncSignature) or sig.return_type is None {
        return None;
    }
    rt = sig.return_type;
    if not isinstance(rt, uni.Expr) or rt.type is None {
        return None;
    }
    mangled = rt.type.mangle();
    if mangled.startswith("type[") {
        mangled = mangled[5:];
    }
    for prefix in ("Iterator[", "Generator[", "Iterable[") {
        if mangled.startswith(prefix) {
            targs = rt.type.private.type_args or [];
            if targs {
                return self._lower_type(targs[0]);
            }
        }
    }
    return None;
}

impl NaIRGenPass._codegen_generator(nd: uni.Ability, func: ir.Function) -> None {
    name = nd.name_ref.sym_name if nd.name_ref else "unnamed";
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    i64p = i64.as_pointer();
    self._ensure_iter_types();

    elem_type = self._generator_elem_type(nd);
    if elem_type is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="function",
            name=name,
            help_text="A native generator must declare a generator-family return type with a lowerable element, e.g. `-> Iterator[int]`."
        );
        return;
    }
    for y in nd.get_all_sub_nodes(typ=uni.YieldExpr) {
        if y.find_parent_of_type(uni.Ability) is nd
        and y.find_parent_of_type(uni.TryStmt) is not None {
            self.emit(
                E5092,
                node_override=y,
                kind="expression",
                name="yield inside try",
                help_text="Suspending inside a try block is not supported on native yet; move the yield outside the try or the try into the consumer."
            );
            return;
        }
    }

    resume_fnty = ir.FunctionType(i1, [i8p, i8p]);
    resume_fn = ir.Function(
        self.llvm_module, resume_fnty, name=f"__jac_gen_{name}_next"
    );
    resume_fn.linkage = "private";
    resume_fn.args[0].name = "frame";
    resume_fn.args[1].name = "out";

    saved_builder = self._builder;
    saved_locals = self.local_vars if self?.local_vars else {};
    saved_params = self.param_vars;
    saved_nogc = self.nogc_stack_vars;
    saved_region = self.region_handle_vars;
    saved_cell_vars = self.closure_cell_vars;
    saved_cell_handles = self.closure_cell_handles;

    entry_bb = resume_fn.append_basic_block("entry");
    self._builder = ir.IRBuilder(entry_bb);
    self.local_vars = {};
    self.param_vars = set();
    self.nogc_stack_vars = set();
    self.region_handle_vars = set();
    self.closure_cell_vars = set();
    self.closure_cell_handles = {};

    gc: dict = {
        "resume_fn": resume_fn,
        "frame_i8": resume_fn.args[0],
        "out_i8": resume_fn.args[1],
        "elem_type": elem_type,
        "cursor": 8,
        "slots": [],
        "resume_blocks": [],
        "func_name": name
    };
    self._gen_ctx = gc;

    param_slots: list[tuple] = [];
    sig = nd.signature;
    sig_params = sig.get_parameters() if sig is not None else [];
    for (i, p) in enumerate(sig_params) {
        pname = p.name.value if p.name else f"arg{i}";
        ptype = func.args[i].type;
        slot = self._entry_alloca(ptype, pname);
        (_sn, _soff, _st) = gc["slots"][-1];
        param_slots.append((pname, _soff, ptype));
        self.local_vars[pname] = slot;
        self.param_vars.add(pname);
    }

    dispatch_bb = resume_fn.append_basic_block("dispatch");
    body_bb = resume_fn.append_basic_block("body");
    self.builder.position_at_end(body_bb);

    body = ModuleCodegenPass.unwrap_body(nd);
    if body is not None {
        _symtab_before = dict(self.func_symtab);
        self._codegen_body(body);
        self.func_symtab = _symtab_before;
    }

    if not self.builder.block.is_terminated {
        _gd_loc = f"{self.ir_in.loc.mod_path}:{nd.loc.last_line if nd.loc else 0}";
        self._emit_scope_cleanup(skip_var=None, loc=_gd_loc);
        _ip_done = self.builder.bitcast(gc["frame_i8"], i64p, name="gen.ip.done");
        self.builder.store(ir.Constant(i64, -1), _ip_done);
        self.builder.ret(ir.Constant(i1, 0));
    }
    self.builder.position_at_end(entry_bb);
    self.builder.branch(dispatch_bb);

    self.builder.position_at_end(dispatch_bb);
    ip_slot = self.builder.bitcast(gc["frame_i8"], i64p, name="gen.ip.slot");
    ip = self.builder.load(ip_slot, name="gen.ip");
    default_bb = resume_fn.append_basic_block("gen.exhausted");
    sw = self.builder.switch(ip, default_bb);
    sw.add_case(ir.Constant(i64, 0), body_bb);
    for (k, rbb) in enumerate(gc["resume_blocks"]) {
        sw.add_case(ir.Constant(i64, k + 1), rbb);
    }
    self.builder.position_at_end(default_bb);
    self.builder.ret(ir.Constant(i1, 0));

    for bb in resume_fn.basic_blocks {
        if not bb.is_terminated {
            tb = ir.IRBuilder(bb);
            tb.ret(ir.Constant(i1, 0));
        }
    }

    frame_size = (gc["cursor"] + 7) // 8 * 8;
    frame_slots = list(gc["slots"]);
    self._gen_ctx = None;
    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.param_vars = saved_params;
    self.nogc_stack_vars = saved_nogc;
    self.region_handle_vars = saved_region;
    self.closure_cell_vars = saved_cell_vars;
    self.closure_cell_handles = saved_cell_handles;

    drop_fn = self._emit_generator_drop_fn(name, frame_slots);

    block = func.append_basic_block(name="entry");
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.param_vars = set();
    self.nogc_stack_vars = set();
    self.region_handle_vars = set();

    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    raw = self.builder.call(
        self.rc_alloc_fn, [ir.Constant(i64, frame_size)], name="gen.frame"
    );
    memset_fn = self._get_or_declare_extern("memset", i8p, [i8p, ir.IntType(32), i64]);
    self.builder.call(
        memset_fn, [raw, ir.Constant(ir.IntType(32), 0), ir.Constant(i64, frame_size)]
    );
    dtor_slot = self.builder.gep(raw, [ir.Constant(i64, -8)], name="gen.dtor.slot");
    dtor_slot_p = self.builder.bitcast(dtor_slot, i64p, name="gen.dtor.p");
    self.builder.store(
        self.builder.ptrtoint(drop_fn, i64, name="gen.dtor.i64"), dtor_slot_p
    );

    for (pi, (pname, poff, ptype)) in enumerate(param_slots) {
        arg = func.args[pi];
        p_raw = self.builder.gep(raw, [ir.Constant(i64, poff)], name=f"gen.p.{pname}");
        p_slot = self.builder.bitcast(
            p_raw, ptype.as_pointer(), name=f"gen.ps.{pname}"
        );
        self.builder.store(arg, p_slot);
        if isinstance(ptype, ir.PointerType) {
            self._emit_rc_retain(arg, op="gen_param", loc=name);
        }
    }

    ji = self._make_jac_iter(resume_fn, raw);
    self.builder.ret(ji);

    self._builder = None;
    self.local_vars = {};
    nd.gen.llvm_ir = func;
    nd.code_context = CodeContext.NATIVE;
    self.has_native_code = True;
}

impl NaIRGenPass._emit_generator_drop_fn(name: str, slots: list[tuple]) -> ir.Function {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    fnty = ir.FunctionType(ir.VoidType(), [i8p]);
    fn = ir.Function(self.llvm_module, fnty, name=f"__jac_gen_{name}_drop");
    fn.linkage = "private";
    fn.args[0].name = "frame";

    saved_builder = self._builder;
    bb = fn.append_basic_block("entry");
    self._builder = ir.IRBuilder(bb);
    for (sname, soff, stype) in slots {
        if not isinstance(stype, ir.PointerType) {
            continue;
        }
        if isinstance(stype.pointee, ir.FunctionType) {
            continue;
        }
        s_raw = self.builder.gep(
            fn.args[0], [ir.Constant(i64, soff)], name=f"drop.{sname}"
        );
        s_slot = self.builder.bitcast(
            s_raw, stype.as_pointer(), name=f"drop.s.{sname}"
        );
        val = self.builder.load(s_slot, name=f"drop.v.{sname}");
        self._emit_rc_release_typed(val, op="gen_drop", loc=name);
        self.builder.store(ir.Constant(stype, None), s_slot);
    }
    self.builder.ret_void();
    self._builder = saved_builder;
    return fn;
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
    saved_param_vars = self.param_vars;
    saved_di_sp = self._di_current_sp;
    saved_cell_vars = self.closure_cell_vars;
    saved_cell_handles = self.closure_cell_handles;

    fnty = ir.FunctionType(ir.VoidType(), []);
    func = self._define_function("__jac_glob_init", fnty);
    block = func.append_basic_block(name="entry");
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.param_vars = set();
    self.nogc_stack_vars = set();
    self.region_handle_vars = set();
    self.closure_cell_vars = set();
    self.closure_cell_handles = {};

    self._attach_di_subprogram(func, "__jac_glob_init", 0);
    _i8 = ir.IntType(8);
    _gi_done_gv = ir.GlobalVariable(self.llvm_module, _i8, name="__jac_gi_done");
    _gi_done_gv.linkage = "internal";
    _gi_done_gv.initializer = ir.Constant(_i8, 0);
    _gi_run = func.append_basic_block(name="gi.run");
    _gi_done = func.append_basic_block(name="gi.done");
    self.builder.cbranch(
        self.builder.icmp_unsigned(
            "!=", self.builder.load(_gi_done_gv, name="gi.flag"), ir.Constant(_i8, 0)
        ),
        _gi_done,
        _gi_run
    );
    self.builder.position_at_end(_gi_done);
    self.builder.ret_void();
    self.builder.position_at_end(_gi_run);
    self.builder.store(ir.Constant(_i8, 1), _gi_done_gv);
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
    self._apply_static_decorators();
    self.builder.ret_void();

    self._finalize_di_locations(func, 0);
    self.func_symtab["__jac_glob_init"] = func;

    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.param_vars = saved_param_vars;
    self._di_current_sp = saved_di_sp;
    self.closure_cell_vars = saved_cell_vars;
    self.closure_cell_handles = saved_cell_handles;
}

impl NaIRGenPass._apply_static_decorators -> None {
    if not self.decorated_fns {
        return;
    }
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    for (fname, dec_entry) in self.decorated_fns.items() {
        (raw_fn, slot_gv, dec_names, fnty) = dec_entry;
        cur: ir.Value = raw_fn;
        ok = True;
        for dec in reversed(dec_names) {
            d_fn = self.func_symtab.get(dec);
            if d_fn is None or len(d_fn.args) != 1 {
                self.emit(
                    E5092,
                    node_override=self.ir_in,
                    kind="decorator",
                    name=dec,
                    help_text="A native decorator must resolve to a module-level native function taking exactly one argument."
                );
                ok = False;
                break;
            }
            d_param = d_fn.args[0].type;
            if self?.jacval_type and d_param == self.jacval_type {
                d_arg = self._box_to_jacval(
                    self.builder.bitcast(cur, i8p, name="dec.fn.i8")
                );
            } elif self._closure_struct_of(d_param) is not None {
                d_arg = self._coerce_type(cur, d_param);
            } elif isinstance(d_param, ir.PointerType) {
                d_arg = self.builder.bitcast(cur, d_param, name="dec.fn.cast");
            } else {
                d_arg = self.builder.ptrtoint(cur, i64, name="dec.fn.i64");
            }
            res = self.builder.call(d_fn, [d_arg], name=f"dec.{dec}.{fname}");
            if self?.jacval_type and res.type == self.jacval_type {
                payload = self.builder.extract_value(res, 1, name="dec.res.payload");
                cur = self.builder.inttoptr(
                    payload, fnty.as_pointer(), name="dec.res.fn"
                );
            } elif self._closure_struct_of(res.type) is not None {
                _i32d = ir.IntType(32);
                _denv_slot = self.builder.gep(
                    res,
                    [ir.Constant(_i32d, 0), ir.Constant(_i32d, 1)],
                    name="dec.res.env.slot"
                );
                _denv = self.builder.load(_denv_slot, name="dec.res.env");
                _denv_set = self.builder.icmp_unsigned(
                    "!=", _denv, ir.Constant(i8p, None), name="dec.res.env.set"
                );
                self._emit_runtime_raise(
                    _denv_set,
                    "TypeError",
                    "a native decorator returned a capturing closure; the decorated call slot holds a bare function pointer and cannot carry the closure environment"
                );
                _dfn_slot = self.builder.gep(
                    res,
                    [ir.Constant(_i32d, 0), ir.Constant(_i32d, 0)],
                    name="dec.res.fn.slot"
                );
                _dfn_i64 = self.builder.load(_dfn_slot, name="dec.res.fn.i64");
                cur = self.builder.inttoptr(
                    _dfn_i64, fnty.as_pointer(), name="dec.res.unwrap"
                );
            } elif isinstance(res.type, ir.PointerType) {
                cur = self.builder.bitcast(res, fnty.as_pointer(), name="dec.res.cast");
            } else {
                cur = self.builder.inttoptr(res, fnty.as_pointer(), name="dec.res.i2p");
            }
        }
        if ok {
            self.builder.store(self._coerce_type(cur, fnty.as_pointer()), slot_gv);
        }
    }
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
    self.param_vars = set();
    self.nogc_stack_vars = set();
    self.region_handle_vars = set();
    self.closure_cell_vars = set();
    self.closure_cell_handles = {};

    _first = nodes[0];
    entry_line = _first.loc.first_line if _first.loc else 0;
    self._attach_di_subprogram(func, "jac_entry", entry_line);

    self._emit_glob_init_func();
    glob_init_fn = self.func_symtab.get("__jac_glob_init");

    _i8p = ir.IntType(8).as_pointer();
    _i32 = ir.IntType(32);

    if not self._nogc_headerless() {
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
    }

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

    if glob_init_fn is not None {
        self.builder.call(glob_init_fn, []);
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
