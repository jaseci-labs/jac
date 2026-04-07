"""Function/ability declaration and codegen for native compilation."""
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
        if p.type_tag and p.type_tag.tag {
            param_types.append(self._resolve_jac_type(p.type_tag.tag));
        } else {
            param_types.append(ir.IntType(64));
        }
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
    # Store AST signature for return type propagation in for-loops
    self.method_ast_sigs[name] = sig;
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
    self.builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.var_dict_type = {};
    self.var_set_elem_type = {};
    # DWARF debug info (JAC_NATIVE_DEBUG=1)
    self._attach_di_subprogram(
        func, name, self._func_loc.get(name, nd.loc.first_line if nd.loc else 0)
    );
    # Store parameters as local variables (alloca + store pattern)
    sig = (nd).signature;
    for (i, p) in enumerate(sig.get_parameters()) {
        param_name = p.name.value if p.name else f"arg{i}";
        arg_val = func.args[i];
        alloca = self.builder.alloca(arg_val.type, name=param_name);
        self.builder.store(arg_val, alloca);
        self.local_vars[param_name] = alloca;
        # Track type annotations for parameters
        if p.type_tag and p.type_tag.tag {
            self.var_type_node[param_name] = p.type_tag.tag;
            for (ename, ltype) in self.list_types.items() {
                if arg_val.type == ltype.as_pointer() {
                    self.var_list_elem_type[param_name] = ename;
                    break;
                }
            }
            # Track dict type for dict parameters
            for (dkey, dtype) in self.dict_types.items() {
                if arg_val.type == dtype.as_pointer() {
                    self.var_dict_type[param_name] = dkey;
                    break;
                }
            }
            # Track set element type for set parameters
            for (ename, stype) in self.set_types.items() {
                if arg_val.type == stype.as_pointer() {
                    self.var_set_elem_type[param_name] = ename;
                    break;
                }
            }
            # Track struct types (including union T | None)
            tag_name = self._get_name(p.type_tag.tag);
            tag_node = p.type_tag.tag;
            if tag_name is None and isinstance(tag_node, uni.BinaryExpr) {
                op_val = getattr(tag_node.op, 'value', '');
                if op_val == "|" {
                    tag_name = self._get_name(tag_node.left);
                }
            }
            if tag_name is not None and tag_name in self.struct_types {
                self.type_var_map[param_name] = tag_name;
            }
            # Track enum type for enum-typed parameters
            if tag_name is not None and tag_name in self.enum_types {
                self.var_enum_type[param_name] = tag_name;
            }
        }
    }
    # Generate body via manual tree-walking (handle ImplDef wrapper from DeclImplMatchPass)
    body = ModuleCodegenPass.unwrap_body(nd);
    if body is not None {
        self._codegen_body(body);
    }
    # Ensure function has a terminator
    if not self.builder.block.is_terminated {
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

    (nd).gen.llvm_ir = func;
    self.builder = None;
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
    saved_builder = self.builder;
    saved_locals = self.local_vars if self?.local_vars else {};
    # Emit void __jac_glob_init()
    fnty = ir.FunctionType(ir.VoidType(), []);
    func = ir.Function(self.llvm_module, fnty, name="__jac_glob_init");
    block = func.append_basic_block(name="entry");
    self.builder = ir.IRBuilder(block);
    self.local_vars = {};
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
    self.func_symtab["__jac_glob_init"] = func;
    # Restore outer builder context
    self.builder = saved_builder;
    self.local_vars = saved_locals;
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
    self.builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.var_dict_type = {};
    self.var_set_elem_type = {};
    # Emit __jac_glob_init() (current module) and call it first.
    # This initialises all list/dict globs declared in THIS module before any
    # imported module's code can observe them.
    self._emit_glob_init_func();
    glob_init_fn = self.func_symtab.get("__jac_glob_init");
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
        self.builder.call(imp_init_fn, []);
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
        self.builder.ret_void();
    }
    self.has_native_code = True;
    self.builder = None;
}
