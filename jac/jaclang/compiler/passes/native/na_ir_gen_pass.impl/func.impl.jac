"""Function/ability declaration and codegen for native compilation."""
"""Walk the module and declare all native functions."""
impl NaIRGenPass._forward_declare_functions(module: uni.Module) -> None {
    for stmt in module.body {
        if isinstance(stmt, uni.NativeBlock) {
            for inner in stmt.body {
                self._maybe_declare_ability(inner);
            }
        } elif isinstance(stmt, uni.Ability) {
            if (
                isinstance(stmt, uni.ContextAwareNode)
                and stmt.code_context == CodeContext.NATIVE
            ) {
                self._maybe_declare_ability(stmt);
            }
        }
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
    # Create function
    fnty = ir.FunctionType(ret_type, param_types);
    func = ir.Function(self.llvm_module, fnty, name=name);
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
        }
    }
    # Generate body via manual tree-walking
    if isinstance((nd).body, (list, tuple)) {
        self._codegen_body((nd).body);
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
    (nd).gen.llvm_ir = func;
    self.builder = None;
}

# ─── Body / Statement Codegen ─────────────────────────────────
"""Generate jac_entry() function for with entry { ... } blocks."""
impl NaIRGenPass._codegen_entry(nd: uni.ModuleCode) -> None {
    i64 = ir.IntType(64);
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
    # Initialize global variables that have complex initializers (dicts, lists, etc.)
    if self?._global_init_nodes and self._global_init_nodes {
        for init_tuple in self._global_init_nodes {
            var_name = init_tuple[0];
            init_node = init_tuple[1];
            var_type = init_tuple[2];
            init_val = self._codegen_expr(init_node);
            if init_val is not None {
                global_var = self.global_vars.get(var_name);
                if global_var is not None {
                    coerced = self._coerce_type(init_val, var_type);
                    self.builder.store(coerced, global_var);
                }
            }
        }
    }
    # Generate body statements
    if (nd).body {
        self._codegen_body((nd).body);
    }
    # Ensure function has a terminator
    if not self.builder.block.is_terminated {
        self.builder.ret_void();
    }
    self.has_native_code = True;
    self.builder = None;
}
