"""Function/ability declaration and codegen for native compilation."""

"""Non-Optional accessor for the active IRBuilder."""
impl NaIRGenPass.builder.getter -> ir.IRBuilder {
    if self._builder is None {
        raise RuntimeError(
            "NaIRGenPass.builder read with no active IRBuilder "
            "(outside a function body)"
        );
    }
    return self._builder;
}

"""Walk the module and declare all native functions."""
impl NaIRGenPass._forward_declare_functions(module: uni.Module) -> None {
    for stmt in ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE) {
        self._maybe_declare_ability(stmt);
    }
}

"""Forward-declare a single ability if it's a function."""
impl NaIRGenPass._maybe_declare_ability(nd: uni.ElementStmt) -> None {
    if not isinstance(nd, uni.Ability) {
        return;
    }
    if nd.signature is None or not isinstance(nd.signature, uni.FuncSignature) {
        return;
    }
    name = nd.name_ref.sym_name if nd.name_ref else "unnamed";
    sig = nd.signature;
    # Build parameter types
    param_types: list[ir.Type] = [];
    for p in sig.get_parameters() {
        param_types.append(
            self._resolve_jac_type(p) if p.type_tag is not None else ir.IntType(64)
        );
    }
    # Return type
    ret_type = self._resolve_jac_type(sig.return_type);
    # Create function
    fnty = ir.FunctionType(ret_type, param_types);
    func = ir.Function(self.llvm_module, fnty, name=name);
    # Name the parameters
    for (i, p) in enumerate(sig.get_parameters()) {
        func.args[i].name = p.name.value if p.name else f"arg{i}";
    }
    self.func_symtab[name] = func;
    # Store line info for use when the body is generated (codegen_ability)
    self._func_loc[name] = nd.loc.first_line if nd.loc else 0;
    # Interop-marshalling return facts, recorded while the declaration is
    # in hand (replacing the deleted name-keyed AST-signature cache):
    # tuple-element struct hints, and the union-peeled return annotation
    # name for enum-return recovery. Consumed by build_interop_layout.
    if sig.return_type is not None {
        hints = self._extract_tuple_struct_hints(sig.return_type);
        if hints {
            self.func_ret_tuple_hints[name] = hints;
        }
        _rt = sig.return_type;
        # Peel `T | None` (and general unions) to the first member.
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

"""Forward-declare a C library extern function with value types for clib structs."""
impl NaIRGenPass._declare_clib_ability(nd: uni.Ability) -> None {
    if not isinstance(nd, uni.Ability) {
        return;
    }
    if nd.signature is None or not isinstance(nd.signature, uni.FuncSignature) {
        return;
    }
    name = nd.name_ref.sym_name if nd.name_ref else "unnamed";
    sig = nd.signature;
    # Whether and how the ABI plan applies is the central target library's
    # decision (classify_foreign_fn): it returns None when no by-value foreign
    # struct crosses the boundary, so pure-scalar foreign functions (sqrt,
    # strlen, calloc, ...) keep the legacy path below - which also correctly
    # handles reuse of the compiler's canonical extern declarations (e.g. a
    # user re-declaring strlen with an `int` parameter still binds to the
    # pre-declared i8* signature). Targets without an ABI classifier always
    # take the legacy path.
    _abi_triple = str(self.llvm_module.triple or "");
    _abi_supported = (
        "x86_64" in _abi_triple or "aarch64" in _abi_triple or "arm64" in _abi_triple
    );
    _decl_params = sig.get_parameters();
    plan: (dict | None) = None;
    if _abi_supported {
        import from jaclang.compiler.targets.abi { classify_foreign_fn }
        # The declared signature names come from the foreign declaration
        # model (collect_foreign_fns) - the central owner of WHAT was
        # declared at the C boundary - not from re-walking the annotation
        # AST here. A function absent from the model is one the collector
        # skipped (unnamed declaration), which cannot name a foreign struct
        # in its signature - so falling through to the legacy scalar path
        # below is the correct (and only) outcome, same as a plan of None.
        _fdecl = self._foreign_fns().get(name);
        if _fdecl is not None {
            plan = classify_foreign_fn(
                self._foreign_model(), _fdecl["params"], _fdecl["ret"], _abi_triple
            );
        }
    }
    if plan is not None {
        # Materialize the central plan. Identified struct types are
        # LLVM-module-context-bound and scalar lowering consults the
        # checker-typed annotation, so only type construction happens here -
        # classification, argument layout, and sret promotion are decided.
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
        # Scalar plan entries carry their resolved LLVM type for call-site
        # argument coercion (the central plan is symbolic by design).
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
        sysv_fnty = ir.FunctionType(sysv_ret_type, sysv_param_types);
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
                # System V passes the indirect aggregate as `byval` (the backend
                # copies it); AAPCS passes a plain pointer to a caller-made copy.
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
    # Build parameter types -- value types for clib structs
    param_types: list[ir.Type] = [];
    for p in sig.get_parameters() {
        if p.type_tag and p.type_tag.tag {
            param_types.append(self._resolve_clib_type(p.type_tag.tag));
        } else {
            param_types.append(ir.IntType(64));
        }
    }
    # Return type -- value type for clib structs
    ret_type = self._resolve_clib_type(sig.return_type);
    # Create function — reuse existing declaration if the compiler already
    # declared this symbol internally (e.g. free, malloc, memcpy, strlen).
    # This prevents DuplicatedNameError when user code imports a C function
    # that the compiler also uses.
    #
    # We do NOT store user-declared functions in self.extern_funcs — that
    # cache is reserved for internal compiler use with canonical C types.
    # If the function is already in extern_funcs (e.g. free/malloc from
    # _emit_rc_helpers), we reuse that declaration.  Otherwise we create
    # a new ir.Function with the user's types; if internal code later needs
    # the same symbol via _get_or_declare_extern, it will look up the
    # existing declaration from the LLVM module globals.
    fnty = ir.FunctionType(ret_type, param_types);
    if name in self.extern_funcs {
        func = self.extern_funcs[name];
    } elif name in self.func_symtab {
        # Already declared (e.g. by a previous _process_clib_imports call on
        # another module that shares the same library symbol).  Reuse it so we
        # don't get a DuplicatedNameError from llvmlite.
        func = self.func_symtab[name];
    } else {
        func = ir.Function(self.llvm_module, fnty, name=name);
        # Do NOT store in extern_funcs — let _get_or_declare_extern
        # create its own version with internal types if needed.
    }
    # Name the parameters
    for (i, p) in enumerate(sig.get_parameters()) {
        func.args[i].name = p.name.value if p.name else f"arg{i}";
    }
    self.func_symtab[name] = func;
    self.has_native_code = True;
}

# ─── Ability (Function Definition) — Manual Codegen ──────────
"""Generate LLVM IR for a complete function definition."""
impl NaIRGenPass._codegen_ability(nd: uni.Ability) -> None {
    name = (nd).name_ref.sym_name if (nd).name_ref else "unnamed";
    func = self.func_symtab.get(name);
    if func is None {
        return;
    }
    # C library externs: keep as LLVM 'declare' (no body).
    # MCJIT resolves them from loaded shared libraries.
    if name in self.clib_extern_names {
        return;
    }
    # Create entry block
    block = func.append_basic_block(name="entry");
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};
    # DWARF debug info (JAC_NATIVE_DEBUG=1)
    self._attach_di_subprogram(
        func, name, self._func_loc.get(name, nd.loc.first_line if nd.loc else 0)
    );
    # Store parameters as local variables (alloca + store pattern)
    sig = (nd).signature;
    import from jaclang.compiler.ownership { param_plainly_rebound }
    for (i, p) in enumerate(sig.get_parameters()) {
        param_name = p.name.value if p.name else f"arg{i}";
        arg_val = func.args[i];
        alloca = self.builder.alloca(arg_val.type, name=param_name);
        self.builder.store(arg_val, alloca);
        self.local_vars[param_name] = alloca;
        # A borrowed param rebound by a plain assignment somewhere in the
        # body owns its slot from birth (central analysis fact,
        # compiler/ownership.jac): take one entry-block +1 so every
        # overwrite-release stays balanced, and leave it out of param_vars
        # so scope exits release it on ALL paths - including early returns
        # emitted before the rebinding statement, which the old lazy
        # promote-at-first-reassignment scheme leaked.
        if isinstance(arg_val.type, ir.PointerType)
        and param_plainly_rebound(p.name.sym if p.name else None) {
            self._emit_rc_retain(arg_val, op="param_promote", loc=name);
        } else {
            self.param_vars.add(param_name);
        }
    }
    # Generate body via manual tree-walking (handle ImplDef wrapper from DeclImplMatchPass)
    body = ModuleCodegenPass.unwrap_body(nd);
    if body is not None {
        # Snapshot the function table so any nested `def` registered while
        # walking this body (see _codegen_nested_ability) is visible for the
        # rest of the body but dropped afterwards — a nested name must not
        # leak into sibling functions or shadow a module-level function.
        _symtab_before_body = dict(self.func_symtab);
        self._codegen_body(body);
        self.func_symtab = _symtab_before_body;
    }
    # Ensure function has a terminator
    if not self.builder.block.is_terminated {
        _fc_loc = f"{self.ir_in.loc.mod_path}:{nd.loc.last_line if nd.loc else 0}";
        # release all pointer-typed locals before implicit void return
        # (functions that have no explicit `return` statement).  Explicit
        # returns are handled by _emit_scope_cleanup in stmt.impl.jac.
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
    # DWARF post-pass: tag untagged instructions with fallback line
    self._finalize_di_locations(
        func, self._func_loc.get(name, nd.loc.first_line if nd.loc else 1)
    );

    # Explicitly :priv abilities get internal linkage so they don't collide
    # when two modules with identically-named private functions are linked.
    # Default (no modifier) and :pub both remain external.
    _is_priv = nd.access and nd.access.tag.name == Tok.KW_PRIV;
    if _is_priv {
        func.linkage = "internal";
    }

    # Record `:pub` free functions as C-ABI shared-library exports, consumed by
    # `jac nacompile --shared`. Methods are named "Class.method" (not a valid C
    # identifier) and are filtered out, so only module-level functions qualify.
    _is_pub = nd.access and nd.access.tag.name == Tok.KW_PUB;
    if _is_pub and self.ir_in?.gen and func.name.isidentifier() {
        if func.name not in self.ir_in.gen._exported_symbols {
            self.ir_in.gen._exported_symbols.append(func.name);
        }
    }

    (nd).gen.llvm_ir = func;
    self._builder = None;
}

"""Lower a test block to a zero-argument native function.

The function returns i8*: null means the test passed, a non-null pointer is
a static failure message. The body runs under an implicit exception handler
(the same setjmp/longjmp machinery as try/except) so a failing assert or any
uncaught runtime raise fails THIS test instead of hitting the no-handler
abort() path and killing the host test runner.
"""
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
    # Locals must survive the setjmp/longjmp round trip (same rationale as
    # _codegen_try): without optnone, mem2reg promotes them to registers and
    # values written between setjmp and the raise are lost.
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
    # ── entry: install the implicit handler ──
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
    # ── test.body ──
    self.builder.position_at_end(body_bb);
    self._codegen_body(nd.body);
    if not self.builder.block.is_terminated {
        self.builder.branch(success_bb);
    }
    # ── test.success: pop handler, release locals, return null (pass) ──
    self.builder.position_at_end(success_bb);
    self.builder.call(self._exc_pop_fn, []);
    _tc_loc = f"{self.ir_in.loc.mod_path}:{nd.loc.last_line if nd.loc else 0}";
    self._emit_scope_cleanup(skip_var=None, loc=_tc_loc);
    self.builder.ret(ir.Constant(i8p, None));
    # ── test.fail: pop handler, return the exception message (fail) ──
    # Locals are deliberately not released here: the longjmp skipped an
    # unknown suffix of the body, so slot states can't be trusted. Leaking
    # on a failing test is acceptable in a test-runner process.
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
    # Mark the node native so PyastGenPass.exit_test emits the host-side shim
    # instead of a Python lowering of the body. Top-level tests in a .na.jac
    # are already coerced; this matters for tests inside inline na {} blocks,
    # whose code_context still carries the SERVER default.
    nd.code_context = CodeContext.NATIVE;
}

"""Generate a nested function definition (a `def` inside another function).

The inner function is lifted to a uniquely-named private LLVM function and
registered under its simple name in func_symtab so the rest of the enclosing
body — including the inner function itself, for recursion — can call it.
_codegen_ability snapshots/restores func_symtab around each body, so the
name does not leak to sibling functions.

Capture of enclosing-function locals is not yet supported: if the inner
body references an enclosing local, we emit E5090 rather than silently
miscompile. References to module globals and other functions are fine.
"""
impl NaIRGenPass._codegen_nested_ability(nd: uni.Ability) -> None {
    name = nd.name_ref.sym_name if nd.name_ref else "unnamed";
    sig = nd.signature;
    # Resolve parameter and return types from the signature.
    param_types: list = [];
    param_names: list = [];
    sig_params = sig.get_parameters() if sig is not None else [];
    for (i, p) in enumerate(sig_params) {
        p_name = p.name.value if p?.name and p.name else f"arg{i}";
        # ParamVar.type is checker-stamped; lower it directly.
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
    # Reject closures over enclosing locals (see docstring). Free variables
    # come from the symbol-table-derived capture fact; the `local_vars`
    # filter keeps only names bound to live allocas in the enclosing
    # function (excluding e.g. sibling nested functions in func_symtab).
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
    # Lift to a uniquely-named private function; expose under the simple name.
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
    # Register before compiling the body so the function can recurse.
    self.func_symtab[name] = fn;
    # Save and reset the per-scope codegen context, then switch into the
    # inner function with a fresh local scope.
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
    # Terminate any open block with a default return.
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
    # Restore the enclosing scope (func_symtab keeps the new name).
    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.param_vars = saved_param_vars;
    self.var_list_elem_struct = saved_var_list_struct;
    nd.gen.llvm_ir = fn;
}

# ─── Body / Statement Codegen ─────────────────────────────────
"""Emit __jac_glob_init() — a standalone void function containing all
non-const glob initializers (list = [] / dict = {} defaults).

Always emitted so that importing modules can declare and call
__jac_glob_init_<safe_name>() to trigger initialization before using
any exported globals.  Called from _codegen_entry (when `with entry`
exists) and from post_transform (when no `with entry` is present).
"""
impl NaIRGenPass._emit_glob_init_func -> None {
    # Save outer builder context (may be None when called from post_transform)
    saved_builder = self._builder;
    saved_locals = self.local_vars if self?.local_vars else {};
    saved_di_sp = self._di_current_sp;
    # Emit void __jac_glob_init()
    fnty = ir.FunctionType(ir.VoidType(), []);
    func = ir.Function(self.llvm_module, fnty, name="__jac_glob_init");
    block = func.append_basic_block(name="entry");
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};
    # DWARF debug info (JAC_NATIVE_DEBUG=1)
    self._attach_di_subprogram(func, "__jac_glob_init", 0);
    if self?._global_init_nodes and self._global_init_nodes {
        for init_tuple in self._global_init_nodes {
            var_name = init_tuple[0];
            init_node = init_tuple[1];
            var_type = init_tuple[2];
            init_val = self._codegen_expr(init_node);
            # For empty dict literals ({}) _codegen_dict_val returns None.
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
            # For empty list literals ([]) _codegen_list_val may return None.
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
    # DWARF post-pass: tag untagged instructions with fallback line
    self._finalize_di_locations(func, 0);
    self.func_symtab["__jac_glob_init"] = func;
    # Restore outer builder context
    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self._di_current_sp = saved_di_sp;
}

"""Generate jac_entry() function for with entry { ... } blocks."""
impl NaIRGenPass._codegen_entry(nd: uni.ModuleCode) -> None {
    i64 = ir.IntType(64);
    import re;
    # Create jac_entry function: void jac_entry()
    fnty = ir.FunctionType(ir.VoidType(), []);
    func = ir.Function(self.llvm_module, fnty, name="jac_entry");
    self.func_symtab["jac_entry"] = func;
    # Create entry block
    block = func.append_basic_block(name="entry");
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};
    # DWARF debug info (JAC_NATIVE_DEBUG=1)
    entry_line = nd.loc.first_line if nd.loc else 0;
    self._attach_di_subprogram(func, "jac_entry", entry_line);
    # Emit __jac_glob_init() (current module) and call it first.
    # This initialises all list/dict globs declared in THIS module before any
    # imported module's code can observe them.
    self._emit_glob_init_func();
    glob_init_fn = self.func_symtab.get("__jac_glob_init");
    # JAC_NO_GC env-var: disable RC on startup (retain/release become no-ops).
    # Must run before glob_init so module-init releases are also suppressed.
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
    if glob_init_fn is not None {
        self.builder.call(glob_init_fn, []);
    }
    # Call __jac_glob_init_<safe_name>() for every imported .na.jac module,
    # including transitive deps.  native_transitive_sources is populated by
    # _register_imported_struct_types (DFS over all import trees) on the
    # shared InteropManifest, and contains the same source_module strings
    # that na_compile_pass uses when renaming __jac_glob_init.
    _manifest = self.ir_in.gen.interop_manifest if (self.ir_in?.gen) else None;
    _all_na_sources = _manifest.native_transitive_sources if _manifest else [];
    _seen_init_mods: set = set();
    for _source_mod in _all_na_sources {
        if _source_mod is None or _source_mod in _seen_init_mods {
            continue;
        }
        _seen_init_mods.add(_source_mod);
        safe_name = re.sub(r'[^a-zA-Z0-9_]', '_', _source_mod);
        init_name = f"__jac_glob_init_{safe_name}";
        # Declare (or reuse) the external init function
        imp_init_fn = self.func_symtab.get(init_name);
        if imp_init_fn is None {
            imp_init_fnty = ir.FunctionType(ir.VoidType(), []);
            imp_init_fn = ir.Function(self.llvm_module, imp_init_fnty, name=init_name);
            self.func_symtab[init_name] = imp_init_fn;
        }
        _init_call = self.builder.call(imp_init_fn, []);
        # Tag the call with a per-module DISubprogram + DILocation so that
        # jac-gdb correctly names the module whose glob_init crashed,
        # instead of attributing the null call to whatever function ran before.
        if self.di_cu is not None and self._di_current_sp is not None {
            try {
                import os as _os_di;
                # Reconstruct a filename from the source_module path string.
                # native_transitive_sources entries are relative paths like
                # "builtins/net_bridge.na.jac" or dot-separated "builtins.net_bridge".
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
            } except Exception {
            # best-effort; debug quality degrades but safety unaffected
            }
        }
    }
    # Generate body statements
    if (nd).body {
        self._codegen_body((nd).body);
    }
    # Flush all stdio buffers before returning to caller
    if not self.builder.block.is_terminated {
        i32 = ir.IntType(32);
        i8p = ir.IntType(8).as_pointer();
        fflush_fn = self._get_or_declare_extern("fflush", i32, [i8p]);
        null_ptr = ir.Constant(i8p, None);
        self.builder.call(fflush_fn, [null_ptr]);
        # release all pointer-typed locals at end of entry block.
        self._emit_scope_cleanup(
            skip_var=None,
            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.last_line
                if nd.loc
                else 0}"
        );
        # Emit live-objects dump (only if debug was enabled at runtime).
        if self.rc_live_head_gv is not None {
            self._emit_rc_live_dump();
        }
        self.builder.ret_void();
    }
    # DWARF post-pass: tag untagged instructions with fallback line
    self._finalize_di_locations(func, entry_line);
    self.has_native_code = True;
    self._builder = None;
}
