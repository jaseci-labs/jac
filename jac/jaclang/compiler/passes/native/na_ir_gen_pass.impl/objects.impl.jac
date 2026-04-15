"""Archetype (object) codegen: structs, fields, methods, instantiation."""
"""Pre-register archetype names as opaque struct types for global type resolution."""
impl NaIRGenPass._forward_declare_archetype_names(module: uni.Module) -> None {
    for stmt in ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE) {
        if isinstance(stmt, uni.Archetype) {
            aname = stmt.name.value if stmt.name else None;
            if aname is not None and aname not in self.struct_types {
                struct_type = self.llvm_module.context.get_identified_type(aname);
                self.struct_types[aname] = struct_type;
            }
        }
    }
}

"""Walk the module and register all native archetypes (obj definitions)."""
impl NaIRGenPass._register_archetypes(module: uni.Module) -> None {
    # Collect all archetype nodes, deduplicating forward declarations
    arch_map: dict[(str, uni.Archetype)] = {};
    for stmt in ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE) {
        if isinstance(stmt, uni.Archetype) {
            aname = stmt.name.value if stmt.name else "unknown";
            # Full definition overrides forward declaration
            if aname not in arch_map or stmt.body is not None {
                arch_map[aname] = stmt;
            }
        }
    }
    archetypes: list[uni.Archetype] = list(arch_map.values());
    # Pass 1: Create opaque identified struct types (handles forward refs)
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        struct_type = self.llvm_module.context.get_identified_type(arch_name);
        self.struct_types[arch_name] = struct_type;
        self.has_native_code = True;
    }
    # Pass 1.5 + 1.7: Read class hierarchy and MRO from centralized LayoutRegistry
    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }
    layout_reg = get_layout_registry(self.ir_in, self.prog);
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        self.arch_ast_map[arch_name] = arch;
        parents = layout_reg.class_parents.get(arch_name, []);
        # Filter to only include native parents (those with struct types)
        native_parents = [
            p
            for p in parents
            if p in self.struct_types
        ];
        if native_parents {
            self.class_parents[arch_name] = native_parents;
            self.class_hierarchy[arch_name] = native_parents[0];
        }
        self.mro_order[arch_name] = layout_reg.get_mro(arch_name);
    }
    # Determine which classes need vtables from LayoutRegistry
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        arch_layout = layout_reg.get_layout(arch_name);
        if arch_layout is not None and arch_layout.has_vtable {
            self.has_vtable[arch_name] = True;
        }
    }
    # Pass 2: Define struct bodies in topological order from LayoutRegistry
    topo_order = layout_reg.get_topo_order();
    for topo_name in topo_order {
        if topo_name in arch_map {
            self._codegen_archetype(arch_map[topo_name]);
        }
    }
    # Pass 2.5: Emit per-archetype RC destructors (struct bodies must be defined)
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        self._emit_struct_release_fn(arch_name);
    }
    # Pass 3: Forward-declare all own methods
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch.body is not None {
            for stmt in arch.body {
                if isinstance(stmt, uni.Ability) {
                    if stmt.signature is not None
                    and isinstance(stmt.signature, uni.FuncSignature) {
                        self._forward_declare_method(arch_name, stmt);
                    } elif stmt.signature is None and stmt.body is not None {
                        # Handle methods without FuncSignature (e.g., postinit)
                        method_name = stmt.name_ref.sym_name if stmt.name_ref else None;
                        if method_name is not None {
                            full_name = f"{arch_name}.{method_name}";
                            struct_ptr = self.struct_types[arch_name].as_pointer();
                            fnty = ir.FunctionType(ir.VoidType(), [struct_ptr]);
                            func = ir.Function(self.llvm_module, fnty, name=full_name);
                            func.args[0].name = "self";
                            self.func_symtab[full_name] = func;
                            self.method_funcs[full_name] = func;
                            self.has_native_code = True;
                        }
                    }
                }
            }
        }
    }
    # Pass 3.1: Forward-declare methods from non-primary ancestors (for re-compilation)
    # Only for methods NOT already provided by own definition or primary ancestor chain
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        mro = self.mro_order.get(arch_name, [arch_name]);
        if len(mro) < 2 {
            continue;
        }
        # Collect methods already provided by own + primary ancestors
        import from jaclang.compiler.symbol_utils { collect_method_names }
        provided_methods = collect_method_names(arch);
        for anc in mro[1:] {
            if layout_reg.is_primary_ancestor(arch_name, anc) {
                anc_arch = self.arch_ast_map.get(anc);
                if anc_arch is not None {
                    provided_methods.update(collect_method_names(anc_arch));
                }
            }
        }
        for ancestor_name in mro[1:] {
            if layout_reg.is_primary_ancestor(arch_name, ancestor_name) {
                continue;
            }
            ancestor_arch = self.arch_ast_map.get(ancestor_name);
            if ancestor_arch is None or ancestor_arch.body is None {
                continue;
            }
            for stmt in ancestor_arch.body {
                if isinstance(stmt, uni.Ability) {
                    if stmt.signature is not None
                    and isinstance(stmt.signature, uni.FuncSignature) {
                        method_name = stmt.name_ref.sym_name if stmt.name_ref else None;
                        if method_name is not None
                        and method_name not in provided_methods {
                            full_name = f"{arch_name}.{method_name}";
                            if full_name not in self.method_funcs {
                                self._forward_declare_method(arch_name, stmt);
                            }
                            provided_methods.add(method_name);
                        }
                    }
                }
            }
        }
    }
    # Pass 3.5: Build vtable layouts (topological order via MRO)
    for topo_name in topo_order {
        if topo_name in self.has_vtable {
            self._build_vtable(topo_name);
        }
    }
    # Pass 3.6: Compute non-overridden methods for devirtualization
    # A method M on class C is "non-overridden" if NO child class has its own C.M.
    # For these methods, we can emit direct calls instead of vtable dispatch.
    for (base_name, layout) in self.vtable_layouts.items() {
        non_overridden: set[str] = set();
        for method_name in layout {
            # Find the class that defines this method (walk MRO)
            defining_class: (str | None) = None;
            base_mro = self.mro_order.get(base_name, [base_name]);
            for check in base_mro {
                if f"{check}.{method_name}" in self.method_funcs {
                    defining_class = check;
                    break;
                }
            }
            if defining_class is None {
                continue;
            }
            # Check if any child class overrides this method
            overridden = False;
            for (child_name, child_parents) in self.class_parents.items() {
                # Is base_name an ancestor of child_name?
                child_mro = self.mro_order.get(child_name, [child_name]);
                if base_name not in child_mro {
                    continue;
                }
                # Does child have its own implementation?
                child_full = f"{child_name}.{method_name}";
                if child_full in self.method_funcs {
                    # Check if it's a wrapper or an actual override
                    # An actual override means the child class defined this method itself
                    child_arch = self.arch_ast_map.get(child_name);
                    if child_arch is not None and child_arch.body is not None {
                        for stmt in child_arch.body {
                            if isinstance(stmt, uni.Ability) {
                                mn = stmt.name_ref.sym_name if stmt.name_ref else None;
                                if mn == method_name {
                                    overridden = True;
                                    break;
                                }
                            }
                        }
                    }
                }
                if overridden {
                    break;
                }
            }
            if not overridden {
                non_overridden.add(method_name);
            }
        }
        if non_overridden {
            self._non_overridden_methods[base_name] = non_overridden;
        }
    }
    # Pass 4: Emit vtable globals
    for arch_name in self.has_vtable {
        self._emit_vtable_global(arch_name);
    }
    # Pass 4.5: Forward-declare free functions (must happen before method bodies)
    self._forward_declare_functions(module);
    # Pass 5: Generate method bodies (own methods)
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch.body is not None {
            for stmt in arch.body {
                if isinstance(stmt, uni.Ability) {
                    if stmt.signature is not None
                    and isinstance(stmt.signature, uni.FuncSignature) {
                        self._codegen_method(arch_name, stmt);
                    } elif stmt.signature is None and stmt.body is not None {
                        # Generate body for methods without FuncSignature (e.g., postinit)
                        self._codegen_no_sig_method(arch_name, stmt);
                    }
                }
            }
        }
    }
    # Pass 5.1: Re-compile non-primary ancestor methods against child struct layout
    # Only for methods that are NOT already provided by an earlier MRO class
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        mro = self.mro_order.get(arch_name, [arch_name]);
        if len(mro) < 2 {
            continue;
        }
        # Collect methods provided by the child's own definition + primary ancestors
        # (these will be handled by own codegen or bitcast wrappers in Pass 6)
        import from jaclang.compiler.symbol_utils { collect_method_names }
        provided_methods = collect_method_names(arch);
        for anc in mro[1:] {
            if layout_reg.is_primary_ancestor(arch_name, anc) {
                anc_arch = self.arch_ast_map.get(anc);
                if anc_arch is not None {
                    provided_methods.update(collect_method_names(anc_arch));
                }
            }
        }
        # Now re-compile only non-primary ancestor methods NOT already provided
        for ancestor_name in mro[1:] {
            if layout_reg.is_primary_ancestor(arch_name, ancestor_name) {
                continue;
            }
            ancestor_arch = self.arch_ast_map.get(ancestor_name);
            if ancestor_arch is None or ancestor_arch.body is None {
                continue;
            }
            for stmt in ancestor_arch.body {
                if isinstance(stmt, uni.Ability) {
                    if stmt.signature is not None
                    and isinstance(stmt.signature, uni.FuncSignature) {
                        method_name = stmt.name_ref.sym_name if stmt.name_ref else None;
                        if method_name is not None
                        and method_name not in provided_methods {
                            full_name = f"{arch_name}.{method_name}";
                            if full_name in self.method_funcs {
                                self._codegen_method(arch_name, stmt);
                            }
                            provided_methods.add(method_name);
                        }
                    }
                }
            }
        }
    }
    # Pass 6: Generate wrapper functions for inherited methods
    self._generate_inherited_method_wrappers();
}

"""Register a struct type — define its field layout from has declarations."""
impl NaIRGenPass._codegen_archetype(nd: uni.Archetype) -> None {
    arch_name = (nd).name.value if (nd).name else "unknown";
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None {
        return;
    }
    needs_vtable = arch_name in self.has_vtable;
    # Collect fields
    field_types: list[ir.Type] = [];
    field_index_map: dict[(str, int)] = {};
    field_type_map: dict[(str, ir.Type)] = {};
    field_default_map: dict[(str, object)] = {};
    # Add vtable pointer as field 0 if needed
    if needs_vtable {
        field_types.append(ir.IntType(8).as_pointer().as_pointer());
    }
    # Flatten fields from all ancestors in MRO order (diamond dedup by name)
    mro = self.mro_order.get(arch_name, [arch_name]);
    seen_fields: set[str] = set();
    for ancestor_name in mro[1:] {
        if ancestor_name not in self.struct_field_indices {
            continue;
        }
        ancestor_indices = self.struct_field_indices[ancestor_name];
        ancestor_types = self.struct_field_types.get(ancestor_name, {});
        ancestor_defaults = self.struct_field_defaults.get(ancestor_name, {});
        # Record start index for this ancestor's region
        if arch_name not in self.parent_field_start {
            self.parent_field_start[arch_name] = {};
        }
        self.parent_field_start[arch_name][ancestor_name] = len(field_types);
        # Build reverse map: index → field name, then iterate in order
        idx_to_name: dict[(int, str)] = {};
        for (fname, pidx) in ancestor_indices.items() {
            idx_to_name[pidx] = fname;
        }
        sorted_idxs = sorted(idx_to_name.keys());
        for pidx in sorted_idxs {
            fname = idx_to_name[pidx];
            if fname in seen_fields {
                continue;  # Diamond dedup: skip fields already present
            }
            seen_fields.add(fname);
            ftype = ancestor_types.get(fname, ir.IntType(64));
            new_idx = len(field_types);
            field_types.append(ftype);
            field_index_map[fname] = new_idx;
            field_type_map[fname] = ftype;
            if fname in ancestor_defaults {
                field_default_map[fname] = ancestor_defaults[fname];
            }
            # Propagate Jac-level type AST from ancestor
            if ancestor_name in self.field_type_node
            and fname in self.field_type_node[ancestor_name] {
                if arch_name not in self.field_type_node {
                    self.field_type_node[arch_name] = {};
                }
                self.field_type_node[arch_name][fname] = self.field_type_node[
                    ancestor_name
                ][fname];
            }
        }
    }
    # Add own fields from ArchHas nodes
    if (nd).body is not None {
        for stmt in (nd).body {
            if isinstance(stmt, uni.ArchHas) {
                for var in stmt.vars {
                    fname = var.name.value if var.name else "field";
                    if fname in seen_fields {
                        continue;  # Skip fields already inherited
                    }
                    seen_fields.add(fname);
                    ftype = ir.IntType(64);
                    if var.type_tag and var.type_tag.tag {
                        ftype = self._resolve_jac_type(var.type_tag.tag);
                        # Track Jac-level type AST for nested type resolution
                        if arch_name not in self.field_type_node {
                            self.field_type_node[arch_name] = {};
                        }
                        self.field_type_node[arch_name][fname] = var.type_tag.tag;
                        # Track enum-typed fields
                        ftag_name = self._get_name(var.type_tag.tag);
                        if ftag_name is not None and ftag_name in self.enum_types {
                            if arch_name not in self.struct_field_enum_type {
                                self.struct_field_enum_type[arch_name] = {};
                            }
                            self.struct_field_enum_type[arch_name][fname] = ftag_name;
                        }
                    }
                    new_idx = len(field_types);
                    field_types.append(ftype);
                    field_index_map[fname] = new_idx;
                    field_type_map[fname] = ftype;
                    if var.value is not None {
                        field_default_map[fname] = var.value;
                    }
                }
            }
        }
    }
    # Define the struct body (always call set_body, even with empty field_types,
    # to make the struct type non-opaque so GEP operations work)
    struct_type.set_body(*field_types);
    self.struct_field_indices[arch_name] = field_index_map;
    self.struct_field_types[arch_name] = field_type_map;
    self.struct_field_defaults[arch_name] = field_default_map;
}

"""Forward-declare a method with self pointer as first parameter."""
impl NaIRGenPass._forward_declare_method(arch_name: str, method: uni.Ability) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    # Guard: skip if already declared (duplicate Ability nodes or re-visited module)
    if full_name in self.method_funcs {
        return;
    }
    sig = method.signature;
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None or sig is None {
        return;
    }
    # Build parameter types: self pointer + declared params
    param_types: list[ir.Type] = [struct_type.as_pointer()];
    for p in sig.get_parameters() {
        if p.type_tag and p.type_tag.tag {
            param_types.append(self._resolve_jac_type(p.type_tag.tag));
        } else {
            param_types.append(ir.IntType(64));
        }
    }
    # Return type
    ret_type = self._resolve_jac_type(sig.return_type);
    if isinstance(ret_type, ir.VoidType) {
        ;  # keep void
    }
    fnty = ir.FunctionType(ret_type, param_types);
    func = ir.Function(self.llvm_module, fnty, name=full_name);
    # Name the parameters
    func.args[0].name = "self";
    for (i, p) in enumerate(sig.get_parameters()) {
        func.args[i + 1].name = p.name.value if p.name else f"arg{i}";
    }
    self.method_funcs[full_name] = func;
    self.func_symtab[full_name] = func;
    # Store AST signature for return type propagation in method calls
    self.method_ast_sigs[full_name] = sig;
}

"""Generate LLVM IR for a method body."""
impl NaIRGenPass._codegen_method(arch_name: str, method: uni.Ability) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    func = self.method_funcs.get(full_name);
    if func is None {
        return;
    }
    # Create entry block
    block = func.append_basic_block(name="entry");
    saved_builder = self.builder;
    saved_locals = self.local_vars;
    saved_type_map = dict(self.type_var_map);
    saved_type_node = dict(self.var_type_node);
    saved_list_elem = dict(self.var_list_elem_type);
    saved_dict_type = dict(self.var_dict_type);
    saved_set_elem = dict(self.var_set_elem_type);
    saved_tuple_type = dict(self.var_tuple_type);
    self.builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.var_type_node = {};
    self.var_list_elem_type = {};
    self.var_dict_type = {};
    self.var_set_elem_type = {};
    self.var_tuple_type = {};
    # DWARF debug info (JAC_NATIVE_DEBUG=1)
    self._attach_di_subprogram(
        func, full_name, method.loc.first_line if method.loc else 0
    );
    # Store self pointer
    self_alloca = self.builder.alloca(func.args[0].type, name="self");
    self.builder.store(func.args[0], self_alloca);
    self.local_vars["self"] = self_alloca;
    self.type_var_map["self"] = arch_name;
    # Re-populate field list/type info from archetype has-declarations
    if arch_name in self.field_type_node {
        for (fname, ftn) in self.field_type_node[arch_name].items() {
            qname = f"self.{fname}";
            self.var_type_node[qname] = ftn;
            ename = self._get_list_elem_from_type_node(ftn);
            if ename is not None {
                self.var_list_elem_type[qname] = ename;
            }
        }
    }
    # Store other parameters
    sig = method.signature;
    for (i, p) in enumerate(sig.get_parameters()) {
        param_name = p.name.value if p.name else f"arg{i}";
        arg_val = func.args[i + 1];
        alloca = self.builder.alloca(arg_val.type, name=param_name);
        self.builder.store(arg_val, alloca);
        self.local_vars[param_name] = alloca;
        # Track type info for struct pointer parameters
        if isinstance(arg_val.type, ir.PointerType) {
            for (sname, stype) in self.struct_types.items() {
                if arg_val.type == stype.as_pointer() {
                    self.type_var_map[param_name] = sname;
                    break;
                }
            }
        }
        # Track Jac type annotation for parameters (enables nested list resolution)
        if p.type_tag and p.type_tag.tag {
            self.var_type_node[param_name] = p.type_tag.tag;
            # Also track list elem type from annotation
            for (ename, ltype) in self.list_types.items() {
                if arg_val.type == ltype.as_pointer() {
                    self.var_list_elem_type[param_name] = ename;
                    break;
                }
            }
            # Handle union types T | None for struct tracking
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
            # Track enum type for enum-typed method parameters
            if tag_name is not None and tag_name in self.enum_types {
                self.var_enum_type[param_name] = tag_name;
            }
        }
    }
    # Generate body (handle ImplDef wrapper from DeclImplMatchPass)
    body = ModuleCodegenPass.unwrap_body(method);
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
    method.gen.llvm_ir = func;
    # DWARF post-pass: tag untagged instructions with fallback line
    self._finalize_di_locations(func, method.loc.first_line if method.loc else 1);
    # Restore saved state
    self.builder = saved_builder;
    self.local_vars = saved_locals;
    self.type_var_map = saved_type_map;
    self.var_type_node = saved_type_node;
    self.var_list_elem_type = saved_list_elem;
    self.var_dict_type = saved_dict_type;
    self.var_set_elem_type = saved_set_elem;
    self.var_tuple_type = saved_tuple_type;
}

"""Generate method body for methods without FuncSignature (e.g., postinit)."""
impl NaIRGenPass._codegen_no_sig_method(arch_name: str, method: uni.Ability) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    func = self.method_funcs.get(full_name);
    if func is None {
        return;
    }
    # Create entry block
    block = func.append_basic_block(name="entry");
    saved_builder = self.builder;
    saved_locals = self.local_vars;
    saved_type_map = dict(self.type_var_map);
    saved_type_node = dict(self.var_type_node);
    saved_list_elem = dict(self.var_list_elem_type);
    saved_dict_type = dict(self.var_dict_type);
    saved_set_elem = dict(self.var_set_elem_type);
    saved_tuple_type = dict(self.var_tuple_type);
    self.builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.var_type_node = {};
    self.var_list_elem_type = {};
    self.var_dict_type = {};
    self.var_set_elem_type = {};
    self.var_tuple_type = {};
    # DWARF debug info (JAC_NATIVE_DEBUG=1)
    self._attach_di_subprogram(
        func, full_name, method.loc.first_line if method.loc else 0
    );
    # Store self pointer (only parameter)
    self_alloca = self.builder.alloca(func.args[0].type, name="self");
    self.builder.store(func.args[0], self_alloca);
    self.local_vars["self"] = self_alloca;
    self.type_var_map["self"] = arch_name;
    # Re-populate field list/type info from archetype has-declarations
    if arch_name in self.field_type_node {
        for (fname, ftn) in self.field_type_node[arch_name].items() {
            qname = f"self.{fname}";
            self.var_type_node[qname] = ftn;
            ename = self._get_list_elem_from_type_node(ftn);
            if ename is not None {
                self.var_list_elem_type[qname] = ename;
            }
        }
    }
    # Generate body (handle ImplDef wrapper from DeclImplMatchPass)
    body = ModuleCodegenPass.unwrap_body(method);
    if body is not None {
        self._codegen_body(body);
    }
    # Ensure function has a terminator
    if not self.builder.block.is_terminated {
        self.builder.ret_void();
    }
    method.gen.llvm_ir = func;
    # DWARF post-pass: tag untagged instructions with fallback line
    self._finalize_di_locations(func, method.loc.first_line if method.loc else 1);
    # Restore saved state
    self.builder = saved_builder;
    self.local_vars = saved_locals;
    self.type_var_map = saved_type_map;
    self.var_type_node = saved_type_node;
    self.var_list_elem_type = saved_list_elem;
    self.var_dict_type = saved_dict_type;
    self.var_set_elem_type = saved_set_elem;
    self.var_tuple_type = saved_tuple_type;
}

"""Generate object instantiation: allocate struct, init fields, call postinit."""
impl NaIRGenPass._codegen_instantiation(nd: uni.FuncCall) -> (ir.Value | None) {
    type_name = self._get_name(nd.target);
    if type_name is None or type_name not in self.struct_types {
        return None;
    }
    struct_type = self.struct_types[type_name];
    struct_ptr_type = struct_type.as_pointer();
    # Compute sizeof using GEP-from-null trick
    null_ptr = ir.Constant(struct_ptr_type, None);
    size_gep = self.builder.gep(
        null_ptr, [ir.Constant(ir.IntType(32), 1)], name="sizeof.gep"
    );
    size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="sizeof");
    # Allocate via rc_alloc (RC-managed)
    raw_ptr = self.builder.call(self.rc_alloc_fn, [size], name="raw.ptr");
    obj_ptr = self.builder.bitcast(raw_ptr, struct_ptr_type, name="obj.ptr");
    # Store vtable pointer if class has vtable
    if type_name in self.vtable_globals {
        vtable_global = self.vtable_globals[type_name];
        vtable_base = self.builder.gep(
            vtable_global,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)],
            name="vtable.base"
        );
        vtable_slot = self.builder.gep(
            obj_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)],
            name="vtable.slot"
        );
        self.builder.store(vtable_base, vtable_slot);
    }
    # Initialize fields from keyword arguments
    field_indices = self.struct_field_indices.get(type_name, {});
    field_types = self.struct_field_types.get(type_name, {});
    field_defaults = self.struct_field_defaults.get(type_name, {});
    # Track which fields were explicitly set
    set_fields: set[str] = set();
    params = nd.params or [];
    for param in params {
        if isinstance(param, uni.KWPair) {
            key_name = param.key.sym_name if param.key else None;
            if key_name is None or key_name not in field_indices {
                continue;
            }
            val = self._codegen_expr(param.value);
            if val is None {
                # Empty dict/list literal returns None from _codegen_dict_val /
                # _codegen_list_val.  Fall back to calling helpers["new"] for
                # the field's concrete dict or list type.
                ftype_probe = field_types.get(key_name);
                if ftype_probe is not None
                and isinstance(ftype_probe, ir.PointerType) {
                    for (dict_key, dtype) in self.dict_types.items() {
                        if ftype_probe == dtype.as_pointer() {
                            helpers = self.dict_helpers.get(dict_key);
                            if helpers is not None {
                                val = self.builder.call(
                                    helpers["new"], [], name=f"dict.ctor.{key_name}"
                                );
                            }
                            break;
                        }
                    }
                    if val is None {
                        for (elem_key, ltype) in self.list_types.items() {
                            if ftype_probe == ltype.as_pointer() {
                                helpers = self.list_helpers.get(elem_key);
                                if helpers is not None {
                                    val = self.builder.call(
                                        helpers["new"], [], name=f"list.ctor.{key_name}"
                                    );
                                }
                                break;
                            }
                        }
                    }
                }
                if val is None {
                    continue;
                }
            }
            idx = field_indices[key_name];
            ftype = field_types[key_name];
            val = self._coerce_type(val, ftype);
            # RC: retain pointer values stored into struct fields
            if isinstance(ftype, ir.PointerType) {
                self._emit_rc_retain(val);
            }
            field_ptr = self.builder.gep(
                obj_ptr,
                [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                name=f"field.{key_name}"
            );
            self.builder.store(val, field_ptr);
            set_fields.add(key_name);
        }
    }
    # Initialize unset fields with defaults
    for (fname, default_expr) in field_defaults.items() {
        if fname not in set_fields {
            val = self._codegen_expr(default_expr);
            # Empty dict/list default returns None — fall back to helpers["new"].
            if val is None {
                ftype_probe = field_types.get(fname);
                if ftype_probe is not None
                and isinstance(ftype_probe, ir.PointerType) {
                    for (dict_key, dtype) in self.dict_types.items() {
                        if ftype_probe == dtype.as_pointer() {
                            helpers = self.dict_helpers.get(dict_key);
                            if helpers is not None {
                                val = self.builder.call(
                                    helpers["new"], [], name=f"dict.dflt.{fname}"
                                );
                            }
                            break;
                        }
                    }
                    if val is None {
                        for (elem_key, ltype) in self.list_types.items() {
                            if ftype_probe == ltype.as_pointer() {
                                helpers = self.list_helpers.get(elem_key);
                                if helpers is not None {
                                    val = self.builder.call(
                                        helpers["new"], [], name=f"list.dflt.{fname}"
                                    );
                                }
                                break;
                            }
                        }
                    }
                }
            }
            if val is not None {
                idx = field_indices[fname];
                ftype = field_types[fname];
                val = self._coerce_type(val, ftype);
                # RC: retain pointer defaults stored into struct fields
                if isinstance(ftype, ir.PointerType) {
                    self._emit_rc_retain(val);
                }
                field_ptr = self.builder.gep(
                    obj_ptr,
                    [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                    name=f"default.{fname}"
                );
                self.builder.store(val, field_ptr);
                set_fields.add(fname);
            }
        }
    }
    # Zero-initialize any remaining unset fields
    for (fname, idx) in field_indices.items() {
        if fname not in set_fields {
            ftype = field_types[fname];
            if isinstance(ftype, ir.PointerType) {
                zero_val = ir.Constant(ftype, None);
            } else {
                zero_val = ir.Constant(ftype, 0);
            }
            field_ptr = self.builder.gep(
                obj_ptr,
                [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                name=f"zero.{fname}"
            );
            self.builder.store(zero_val, field_ptr);
        }
    }
    # Call init if it exists (try both Jac name and Python dunder name)
    init_fn: (ir.Function | None) = None;
    for candidate in [f"{type_name}.init", f"{type_name}.__init__"] {
        if candidate in self.method_funcs {
            init_fn = self.method_funcs[candidate];
            break;
        }
    }
    if init_fn is not None {
        # Collect non-keyword (positional) arguments
        init_args: list[ir.Value] = [obj_ptr];  # self pointer
        for param in params {
            if not isinstance(param, uni.KWPair) {
                val = self._codegen_expr(param);
                if val is not None {
                    init_args.append(val);
                }
            }
        }
        # Coerce arguments to match function signature
        coerced_args: list[ir.Value] = [];
        for (i, arg) in enumerate(init_args) {
            if i < len(init_fn.args) {
                coerced_args.append(self._coerce_type(arg, init_fn.args[i].type));
            } else {
                coerced_args.append(arg);
            }
        }
        self.builder.call(init_fn, coerced_args, name="call.init");
    }
    # Call postinit if it exists (Jac renames postinit → __post_init__)
    for pname in [f"{type_name}.__post_init__", f"{type_name}.postinit"] {
        if pname in self.method_funcs {
            postinit_fn = self.method_funcs[pname];
            self.builder.call(postinit_fn, [obj_ptr]);
            break;
        }
    }
    return obj_ptr;
}

"""Generate method call: obj.method(args).

Primitive type methods are dispatched through the emitter layer
(primitives_native.jac). If the emitter returns a result, it is used
directly; if it returns None, the inline codegen below handles it.
"""
impl NaIRGenPass._codegen_method_call(nd: uni.FuncCall) -> (ir.Value | None) {
    trailer = nd.target;
    if not isinstance(trailer, uni.AtomTrailer) or not trailer.is_attr {
        return None;
    }
    target_name = self._get_name(trailer.target);
    method_name = self._get_name(trailer.right);
    if method_name is None {
        return None;
    }
    # --- Native stdlib module method calls: sys.exit() ---
    if (
        target_name == "sys"
        and self?._native_stdlib_modules
        and "sys" in self._native_stdlib_modules
    ) {
        if method_name == "exit" {
            params = nd.params or [];
            arg_vals: list[ir.Value] = [];
            for param in params {
                v = self._codegen_expr(param);
                if v is not None {
                    arg_vals.append(v);
                }
            }
            return self._emit_sys_exit(arg_vals);
        }
    }
    # --- Static/class method dispatch (int.from_bytes, float.fromhex) ---
    if target_name == "int" and method_name == "from_bytes" {
        params = nd.params or [];
        arg_vals: list[ir.Value] = [];
        for param in params {
            v = self._codegen_expr(param);
            if v is not None {
                arg_vals.append(v);
            }
        }
        if arg_vals {
            self._ensure_emitters();
            _emitter = self._native_emitters.get("int");
            if _emitter is not None {
                _ctx = self._native_emit_ctx_class(pass_ref=self, type_key="");
                result = _emitter.emit_from_bytes(_ctx, arg_vals);
                if result is not None {
                    return result;
                }
            }
        }
    }
    if target_name == "float" and method_name == "fromhex" {
        params = nd.params or [];
        arg_vals: list[ir.Value] = [];
        for param in params {
            v = self._codegen_expr(param);
            if v is not None {
                arg_vals.append(v);
            }
        }
        if arg_vals {
            self._ensure_emitters();
            _emitter = self._native_emitters.get("float");
            if _emitter is not None {
                _ctx = self._native_emit_ctx_class(pass_ref=self, type_key="");
                result = _emitter.emit_fromhex(_ctx, arg_vals);
                if result is not None {
                    return result;
                }
            }
        }
    }
    # --- Primitive emitter dispatch (list, set, str methods) ---
    # Evaluate target and args, dispatch through emitter layer.
    # List methods (simple name target)
    if target_name is not None and target_name in self.var_list_elem_type {
        elem_type_name = self.var_list_elem_type[target_name];
        list_val = self._codegen_expr(trailer.target);
        if list_val is not None {
            params = nd.params or [];
            arg_vals: list[ir.Value] = [];
            for param in params {
                v = self._codegen_expr(param);
                if v is not None {
                    arg_vals.append(v);
                }
            }
            result = self._dispatch_primitive_method(
                "list", method_name, list_val, arg_vals, elem_type_name
            );
            if result is not None {
                return result;
            }
        }
    }
    # Set methods (simple name target)
    if target_name is not None and target_name in self.var_set_elem_type {
        elem_type_name = self.var_set_elem_type[target_name];
        set_val = self._codegen_expr(trailer.target);
        if set_val is not None {
            params = nd.params or [];
            arg_vals: list[ir.Value] = [];
            for param in params {
                v = self._codegen_expr(param);
                if v is not None {
                    arg_vals.append(v);
                }
            }
            result = self._dispatch_primitive_method(
                "set", method_name, set_val, arg_vals, elem_type_name
            );
            if result is not None {
                return result;
            }
        }
    }
    # Tuple methods (simple name target)
    if target_name is not None and target_name in self.var_tuple_type {
        tuple_type_key = self.var_tuple_type[target_name];
        tuple_val = self._codegen_expr(trailer.target);
        if tuple_val is not None {
            params = nd.params or [];
            arg_vals: list[ir.Value] = [];
            for param in params {
                v = self._codegen_expr(param);
                if v is not None {
                    arg_vals.append(v);
                }
            }
            result = self._dispatch_primitive_method(
                "tuple", method_name, tuple_val, arg_vals, tuple_type_key
            );
            if result is not None {
                return result;
            }
        }
    }
    # Dict methods (simple name target or global dict)
    dict_type_key: (str | None) = None;
    if target_name is not None and target_name in self.var_dict_type {
        dict_type_key = self.var_dict_type[target_name];
    }
    if dict_type_key is None and target_name is not None {
        # Fallback: infer dict type from LLVM type (handles globals after var_dict_type reset)
        probe_val = self._codegen_expr(trailer.target);
        if probe_val is not None {
            dict_type_info = self._infer_dict_type(probe_val);
            if dict_type_info is not None {
                dict_type_key = f"{dict_type_info[0]}:{dict_type_info[1]}";
            }
        }
    }
    if dict_type_key is not None {
        dict_val = self._codegen_expr(trailer.target);
        if dict_val is not None {
            params = nd.params or [];
            arg_vals: list[ir.Value] = [];
            for param in params {
                v = self._codegen_expr(param);
                if v is not None {
                    arg_vals.append(v);
                }
            }
            result = self._dispatch_primitive_method(
                "dict", method_name, dict_val, arg_vals, dict_type_key
            );
            if result is not None {
                return result;
            }
        }
    }
    # Int methods (on any target expression whose type is i64)
    if method_name in (
        "conjugate",
        "bit_length",
        "bit_count",
        "as_integer_ratio",
        "to_bytes"
    ) {
        int_val = self._codegen_expr(trailer.target);
        if int_val is not None and isinstance(int_val.type, ir.IntType) {
            params = nd.params or [];
            arg_vals: list[ir.Value] = [];
            for param in params {
                v = self._codegen_expr(param);
                if v is not None {
                    arg_vals.append(v);
                }
            }
            result = self._dispatch_primitive_method(
                "int", method_name, int_val, arg_vals, ""
            );
            if result is not None {
                return result;
            }
        }
    }
    # Float methods (on any target expression whose type is double)
    if method_name in ("is_integer", "conjugate", "as_integer_ratio", "hex") {
        float_val = self._codegen_expr(trailer.target);
        if float_val is not None and isinstance(float_val.type, ir.DoubleType) {
            params = nd.params or [];
            arg_vals: list[ir.Value] = [];
            for param in params {
                v = self._codegen_expr(param);
                if v is not None {
                    arg_vals.append(v);
                }
            }
            result = self._dispatch_primitive_method(
                "float", method_name, float_val, arg_vals, ""
            );
            if result is not None {
                return result;
            }
        }
    }
    # Complex methods (conjugate)
    if method_name == "conjugate" {
        cval = self._codegen_expr(trailer.target);
        if cval is not None and cval.type == self.complex_struct_type.as_pointer() {
            result = self._dispatch_primitive_method(
                "complex", method_name, cval, [], ""
            );
            if result is not None {
                return result;
            }
        }
    }
    # Range methods (count, index)
    if method_name in ("count", "index") {
        rng_target_name = self._get_name(trailer.target);
        if rng_target_name is not None and rng_target_name in self.var_range {
            rng_val = self._codegen_expr(trailer.target);
            if rng_val is not None {
                params = nd.params or [];
                arg_vals: list[ir.Value] = [];
                for param in params {
                    v = self._codegen_expr(param);
                    if v is not None {
                        arg_vals.append(v);
                    }
                }
                result = self._dispatch_primitive_method(
                    "range", method_name, rng_val, arg_vals, ""
                );
                if result is not None {
                    return result;
                }
            }
        }
    }
    # String methods (on any target expression whose type is i8*)
    if method_name in (
        "strip",
        "lstrip",
        "rstrip",
        "split",
        "upper",
        "lower",
        "capitalize",
        "casefold",
        "swapcase",
        "title",
        "find",
        "rfind",
        "count",
        "startswith",
        "endswith",
        "replace",
        "removeprefix",
        "removesuffix",
        "ljust",
        "rjust",
        "zfill",
        "isalpha",
        "isdigit",
        "isalnum",
        "isspace",
        "islower",
        "isupper",
        "isascii",
        "isdecimal",
        "isnumeric",
        "isprintable",
        "isidentifier",
        "istitle",
        "index",
        "rindex",
        "center",
        "expandtabs",
        "join",
        "rsplit",
        "splitlines",
        "partition",
        "rpartition",
        "encode",
        "format"
    ) {
        str_val = self._codegen_expr(trailer.target);
        if str_val is not None and str_val.type == ir.IntType(8).as_pointer() {
            params = nd.params or [];
            arg_vals: list[ir.Value] = [];
            for param in params {
                v = self._codegen_expr(param);
                if v is not None {
                    arg_vals.append(v);
                }
            }
            result = self._dispatch_primitive_method(
                "str", method_name, str_val, arg_vals, ""
            );
            if result is not None {
                return result;
            }
        }
    }
    # Determine type_name and obj_val (supports chained access)
    type_name: (str | None) = None;
    obj_val: (ir.Value | None) = None;
    if target_name is not None {
        type_name = self.type_var_map.get(target_name);
    }
    if type_name is None {
        # Complex expression target (chained access) — evaluate and infer
        obj_val = self._codegen_expr(trailer.target);
        if obj_val is not None {
            type_name = self._infer_type_name(obj_val);
            # Handle list methods on complex targets (e.g. g.items.append(x))
            if type_name is None {
                elem_type_name = self._infer_list_elem_type(obj_val);
                if elem_type_name is not None and method_name == "append" {
                    helpers = self.list_helpers.get(elem_type_name);
                    if helpers is not None {
                        params = nd.params or [];
                        if params {
                            val = self._codegen_expr(params[0]);
                            if val is not None {
                                val = self._box_value_tuple(val);
                                elem_type = helpers["elem_type"];
                                val = self._coerce_type(val, elem_type);
                                self.builder.call(helpers["append"], [obj_val, val]);
                            }
                        }
                        return ir.Constant(ir.IntType(64), 0);
                    }
                }
            }
        }
    }
    if type_name is None {
        return None;
    }
    # Find method: walk MRO
    func = None;
    full_name = "";
    for check_name in self.mro_order.get(type_name, [type_name]) {
        full_name = f"{check_name}.{method_name}";
        if full_name in self.method_funcs {
            func = self.method_funcs[full_name];
            break;
        }
    }
    if func is None {
        return None;
    }
    # Save return type hint — will be set AFTER args evaluation to avoid overwrite
    method_ret_type_hint: (object | None) = None;
    if full_name in self.method_ast_sigs {
        method_sig = self.method_ast_sigs[full_name];
        if method_sig?.return_type and method_sig.return_type is not None {
            method_ret_type_hint = method_sig.return_type;
        }
    }
    # Get the object pointer (reuse if already computed in chained path)
    if obj_val is None {
        obj_val = self._codegen_expr(trailer.target);
    }
    if obj_val is None {
        return None;
    }
    # AttributeError: check for null pointer (None) before method call
    if isinstance(obj_val.type, ir.PointerType) {
        null_ptr = ir.Constant(obj_val.type, None);
        is_null = self.builder.icmp_unsigned(
            "==", obj_val, null_ptr, name="null.method.chk"
        );
        self._emit_runtime_raise(
            is_null, "AttributeError", "'NoneType' object has no attribute"
        );
    }
    # Build args: [self_ptr, arg1, arg2, ...]
    args: list[ir.Value] = [obj_val];
    params = nd.params or [];
    for param in params {
        val = self._codegen_expr(param);
        if val is not None {
            args.append(val);
        }
    }
    # Fill in missing optional parameters with their AST default values
    if full_name in self.method_ast_sigs and len(args) < len(func.args) {
        sig_params = self.method_ast_sigs[full_name].get_parameters();
        provided_count = len(args) - 1;  # exclude self
        for pix in range(provided_count, len(sig_params)) {
            p = sig_params[pix];
            if pix < len(sig_params) {
                expected_type = func.args[len(args)].type
                    if len(args) < len(func.args)
                    else ir.IntType(64);
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
    }
    # Virtual dispatch if type has vtable
    if type_name in self.has_vtable {
        result = self._codegen_virtual_call(obj_val, method_name, args, type_name);
        if result is not None {
            # Set return type hint AFTER call (args eval may have overwritten it)
            if method_ret_type_hint is not None {
                self._last_type_node_hint = method_ret_type_hint;
            }
            if isinstance(func.return_value.type, ir.VoidType) {
                return ir.Constant(ir.IntType(64), 0);
            }
            return result;
        }
    }
    # Direct call (for non-vtable types or fallback)
    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(args) {
        if i < len(func.args) {
            coerced.append(self._coerce_type(arg, func.args[i].type));
        } else {
            coerced.append(arg);
        }
    }
    result = self.builder.call(func, coerced, name=f"call.{method_name}");
    # Set return type hint AFTER call (args eval may have overwritten it)
    if method_ret_type_hint is not None {
        self._last_type_node_hint = method_ret_type_hint;
    }
    # Return void calls as None
    if isinstance(func.return_value.type, ir.VoidType) {
        return ir.Constant(ir.IntType(64), 0);
    }
    return result;
}

"""Generate field access: GEP into struct + load (with AttributeError null check)."""
impl NaIRGenPass._codegen_field_access(
    obj_val: ir.Value, field_name: str, type_name: str
) -> (ir.Value | None) {
    field_indices = self.struct_field_indices.get(type_name);
    if field_indices is None or field_name not in field_indices {
        return None;
    }
    # AttributeError: check for null pointer (None) before accessing field
    if isinstance(obj_val.type, ir.PointerType) {
        null_ptr = ir.Constant(obj_val.type, None);
        is_null = self.builder.icmp_unsigned(
            "==", obj_val, null_ptr, name="null.field.chk"
        );
        self._emit_runtime_raise(
            is_null, "AttributeError", "'NoneType' object has no attribute"
        );
    }
    idx = field_indices[field_name];
    field_ptr = self.builder.gep(
        obj_val,
        [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
        name=f"field.{field_name}.ptr"
    );
    return self.builder.load(field_ptr, name=f"field.{field_name}");
}

"""Apply augmented assignment op to a field: load current, compute new value."""
impl NaIRGenPass._codegen_field_aug_assign(
    target: uni.AtomTrailer, rhs: ir.Value, aug_op: str
) -> (ir.Value | None) {
    # Resolve the object and field
    target_name = self._get_name(target.target);
    field_name = self._get_name(target.right);
    if field_name is None {
        return None;
    }
    type_name: (str | None) = None;
    if target_name is not None {
        type_name = self.type_var_map.get(target_name);
    }
    obj_val = self._codegen_expr(target.target);
    if obj_val is None {
        return None;
    }
    if type_name is None {
        type_name = self._infer_type_name(obj_val);
    }
    if type_name is None {
        return None;
    }
    # Load current field value
    current = self._codegen_field_access(obj_val, field_name, type_name);
    if current is None {
        return None;
    }
    # Coerce RHS to match field type
    coerced = self._coerce_type(rhs, current.type);
    # Apply the augmented operation
    if aug_op == "+=" {
        if isinstance(current.type, ir.IntType) {
            return self.builder.add(current, coerced, name="field.add");
        } elif isinstance(current.type, ir.DoubleType) {
            return self.builder.fadd(current, coerced, name="field.fadd");
        } elif isinstance(current.type, ir.PointerType) {
            # String concatenation
            result = self._emit_binary_op(Tok.PLUS, current, coerced);
            return result if result is not None else current;
        }
    } elif aug_op == "-=" {
        if isinstance(current.type, ir.IntType) {
            return self.builder.sub(current, coerced, name="field.sub");
        } elif isinstance(current.type, ir.DoubleType) {
            return self.builder.fsub(current, coerced, name="field.fsub");
        }
    } elif aug_op == "*=" {
        if isinstance(current.type, ir.IntType) {
            return self.builder.mul(current, coerced, name="field.mul");
        } elif isinstance(current.type, ir.DoubleType) {
            return self.builder.fmul(current, coerced, name="field.fmul");
        }
    } elif aug_op == "//=" {
        if isinstance(current.type, ir.IntType) {
            return self.builder.sdiv(current, coerced, name="field.sdiv");
        }
    } elif aug_op == "%=" {
        if isinstance(current.type, ir.IntType) {
            return self.builder.srem(current, coerced, name="field.srem");
        }
    } elif aug_op == "&=" {
        if isinstance(current.type, ir.IntType) {
            return self.builder.and_(current, coerced, name="field.and");
        }
    } elif aug_op == "|=" {
        if isinstance(current.type, ir.IntType) {
            return self.builder.or_(current, coerced, name="field.or");
        }
    } elif aug_op == "^=" {
        if isinstance(current.type, ir.IntType) {
            return self.builder.xor(current, coerced, name="field.xor");
        }
    } elif aug_op == "<<=" {
        if isinstance(current.type, ir.IntType) {
            return self.builder.shl(current, coerced, name="field.shl");
        }
    } elif aug_op == ">>=" {
        if isinstance(current.type, ir.IntType) {
            return self.builder.ashr(current, coerced, name="field.ashr");
        }
    }
    # Fallback: just return the RHS (plain assignment)
    return coerced;
}

"""Generate field assignment: GEP into struct + store."""
impl NaIRGenPass._codegen_field_assign(
    target: uni.AtomTrailer, value: ir.Value
) -> None {
    target_name = self._get_name(target.target);
    field_name = self._get_name(target.right);
    if field_name is None {
        return;
    }
    # Resolve the type: try simple name first, then infer from expression
    type_name: (str | None) = None;
    if target_name is not None {
        type_name = self.type_var_map.get(target_name);
    }
    obj_val = self._codegen_expr(target.target);
    if obj_val is None {
        return;
    }
    if type_name is None {
        type_name = self._infer_type_name(obj_val);
    }
    if type_name is None {
        return;
    }
    field_indices = self.struct_field_indices.get(type_name);
    field_types = self.struct_field_types.get(type_name);
    if field_indices is None or field_name not in field_indices {
        return;
    }
    idx = field_indices[field_name];
    ftype = field_types[field_name];
    value = self._coerce_type(value, ftype);
    field_ptr = self.builder.gep(
        obj_val,
        [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
        name=f"field.{field_name}.ptr"
    );
    # RC: retain new value and release old value for pointer fields
    if isinstance(ftype, ir.PointerType) {
        self._emit_rc_retain(value);
        old_field_val = self.builder.load(field_ptr, name=f"field.{field_name}.old");
        self._emit_rc_release_simple(old_field_val);
    }
    self.builder.store(value, field_ptr);
}
# ─── Phase 4: Lists ──────────────────────────────────────────
