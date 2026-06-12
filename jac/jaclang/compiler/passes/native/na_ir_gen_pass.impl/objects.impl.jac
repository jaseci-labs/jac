"""Archetype (object) codegen: structs, fields, methods, instantiation."""
"""Archetypes native codegen must compile: every archetype declared in an na {}
block, plus the module-level (shared) archetypes its code transitively references
(constructed, used as a type, or triggered on). The type checker already resolves
shared module-level types into native code; this makes codegen materialize them
as structs instead of producing a NULL no-op. The shared set comes from
ModuleCodegenPass so the cl/ES backend applies the identical sharing rule."""
impl NaIRGenPass._native_archetypes(module: uni.Module) -> list[uni.Archetype] {
    result: dict[(str, uni.Archetype)] = {};
    # na {}-block archetypes (full definition overrides any forward declaration).
    for stmt in ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE) {
        if isinstance(stmt, uni.Archetype) {
            aname = stmt.name.value if stmt.name else "unknown";
            if aname not in result or stmt.body is not None {
                result[aname] = stmt;
            }
        }
    }
    # Shared module-level archetypes referenced by native code (na-block
    # declarations win on name collision -- they are codespace overrides).
    for arch in ModuleCodegenPass.shared_archetypes_for_context(
        module, CodeContext.NATIVE
    ) {
        aname = arch.name.value if arch.name else "unknown";
        if aname not in result {
            result[aname] = arch;
        }
    }
    return list(result.values());
}

"""Pre-register archetype names as opaque struct types for global type resolution."""
impl NaIRGenPass._forward_declare_archetype_names(module: uni.Module) -> None {
    for arch in self._native_archetypes(module) {
        aname = arch.name.value if arch.name else None;
        if aname is not None and aname not in self.struct_types {
            struct_type = self.llvm_module.context.get_identified_type(aname);
            self.struct_types[aname] = struct_type;
        }
    }
}

"""Walk the module and register all native archetypes (obj definitions)."""
impl NaIRGenPass._register_archetypes(module: uni.Module) -> None {
    # na-block archetypes plus shared module-level archetypes referenced by
    # native code; names are already de-duplicated by _native_archetypes.
    archetypes: list[uni.Archetype] = self._native_archetypes(module);
    arch_map: dict[(str, uni.Archetype)] = {};
    for arch in archetypes {
        arch_map[arch.name.value if arch.name else "unknown"] = arch;
    }
    # Pass 1: Create opaque identified struct types (handles forward refs)
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        struct_type = self.llvm_module.context.get_identified_type(arch_name);
        self.struct_types[arch_name] = struct_type;
        self.has_native_code = True;
    }
    # Pass 1.6: assign OSP type-tags (issue #6146) before struct bodies are
    # laid out, so OSP archetypes reserve their `__type_tag` field.
    self._register_osp_tags(archetypes);
    # Pass 1.5: record the AST handle per native archetype. Hierarchy, MRO,
    # and vtable-need are NOT copied: the central LayoutRegistry is queried
    # directly (_mro_of / _arch_has_vtable) wherever they are needed.
    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }
    layout_reg = get_layout_registry(self.ir_in, self.prog);
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        self.arch_ast_map[arch_name] = arch;
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
                    } elif isinstance(stmt.signature, uni.EventSignature) {
                        # Object-spatial ability (`can ... with T entry/exit`):
                        # lower as a two-arg method (self, here/visitor).
                        self._forward_declare_event_method(arch_name, stmt);
                        # Emit its kernel dispatch thunk (issue #6146).
                        if arch_name in self.osp_arch_kind {
                            self._emit_osp_thunk(arch_name, stmt);
                        }
                    } else {
                        _sig_kind = (
                            type(stmt.signature).__name__
                                if stmt.signature is not None
                                else "no-signature"
                        );
                        _m_name = stmt.name_ref.sym_name if stmt.name_ref else "?";
                        self.emit(
                            E5090,
                            node_override=stmt,
                            kind="archetype method",
                            name=f"{arch_name}.{_m_name} ({_sig_kind})"
                        );
                    }
                }
            }
        }
    }
    # Pass 3.1: Forward-declare methods from non-primary ancestors (for
    # re-compilation); only methods NOT already provided by the own
    # definition or the primary ancestor chain.
    for arch in archetypes {
        self._visit_nonprimary_ancestor_methods(arch, declare=True);
    }
    # Pass 3.5: Build vtable layouts (topological order via MRO)
    for topo_name in topo_order {
        if self._arch_has_vtable(topo_name) {
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
            base_mro = self._mro_of(base_name);
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
            for child_name in self.arch_ast_map {
                # Is base_name an ancestor of child_name?
                child_mro = self._mro_of(child_name);
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
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if self._arch_has_vtable(arch_name) {
            self._emit_vtable_global(arch_name);
        }
    }
    # Pass 4.5: Forward-declare free functions (must happen before method bodies)
    self._forward_declare_functions(module);
    # Pass 4.7: Register the portable OSP kernel + emit __osp_setup BEFORE method
    # bodies, so `spawn` lowering inside an ability (e.g. a walker ability that
    # spawns a nested walker) can reference __ospRT / __osp_ensure_init. OSP tags
    # (Pass 1.6) and ability thunks (Pass 3) are already available (issue #6146).
    self._register_osp_kernel_module();
    self._emit_osp_setup();
    # Pass 5: Generate method bodies (own methods)
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch.body is not None {
            for stmt in arch.body {
                if isinstance(stmt, uni.Ability) {
                    if stmt.signature is not None
                    and isinstance(stmt.signature, uni.FuncSignature) {
                        self._codegen_method(arch_name, stmt);
                    } elif isinstance(stmt.signature, uni.EventSignature) {
                        self._codegen_event_method(arch_name, stmt);
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
    # Compile only non-primary ancestor methods NOT already provided by the
    # own definition or the primary ancestor chain (same walk as Pass 3.1,
    # body-emission mode).
    for arch in archetypes {
        self._visit_nonprimary_ancestor_methods(arch, declare=False);
    }
    # Pass 6: Generate wrapper functions for inherited methods
    self._generate_inherited_method_wrappers();
}

"""Walk an archetype's non-primary ancestors and visit each method not
already provided by the own definition or the primary ancestor chain:
forward-declare them (declare=True, registration pass) or emit their
bodies (declare=False, re-compilation pass). One walk serves both
passes; primary-chain methods are inherited structurally and need no
per-subclass copy."""
impl NaIRGenPass._visit_nonprimary_ancestor_methods(
    arch: uni.Archetype, declare: bool
) -> None {
    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }
    import from jaclang.compiler.symbol_utils { collect_method_names }
    layout_reg = get_layout_registry(self.ir_in, self.prog);
    arch_name = arch.name.value if arch.name else "unknown";
    mro = self._mro_of(arch_name);
    if len(mro) < 2 {
        return;
    }
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
            if isinstance(stmt, uni.Ability)
            and stmt.signature is not None
            and isinstance(stmt.signature, uni.FuncSignature) {
                method_name = stmt.name_ref.sym_name if stmt.name_ref else None;
                if method_name is not None and method_name not in provided_methods {
                    full_name = f"{arch_name}.{method_name}";
                    if declare and full_name not in self.method_funcs {
                        self._forward_declare_method(arch_name, stmt);
                    } elif not declare and full_name in self.method_funcs {
                        self._codegen_method(arch_name, stmt);
                    }
                    provided_methods.add(method_name);
                }
            }
        }
    }
}

"""Register a struct type — define its field layout from has declarations."""
impl NaIRGenPass._codegen_archetype(nd: uni.Archetype) -> None {
    arch_name = (nd).name.value if (nd).name else "unknown";
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None {
        return;
    }
    needs_vtable = self._arch_has_vtable(arch_name);
    is_osp = arch_name in self.osp_arch_kind;
    # Collect fields
    field_types: list[ir.Type] = [];
    field_index_map: dict[(str, int)] = {};
    field_type_map: dict[(str, ir.Type)] = {};
    field_default_map: dict[(str, object)] = {};
    # Field 0 is the vtable slot. OSP archetypes always reserve it (null when
    # the type has no vtable) so the i64 `__type_tag` lands at a uniform field
    # index 1 across every OSP archetype -- letting the kernel's `tag_of` read
    # an arbitrary `any` handle's tag at a fixed offset (issue #6146).
    if needs_vtable or is_osp {
        field_types.append(ir.IntType(8).as_pointer().as_pointer());
    }
    if is_osp {
        field_types.append(ir.IntType(64));  # __type_tag at field index 1
        self.osp_type_tag_field[arch_name] = len(field_types) - 1;
    }
    # Flatten fields from all ancestors in MRO order (diamond dedup by name)
    mro = self._mro_of(arch_name);
    seen_fields: set[str] = set();
    # Built-in walker `reports` list at a uniform field index 2 (vtable@0,
    # __type_tag@1). The kernel's on_complete delivers `scope.reports` here at
    # the spawn boundary, so `w.reports` reads back like a normal field. Added
    # before MRO/own fields and marked seen so it sits at a fixed offset and a
    # user-declared `reports` cannot shadow it (issue #6146).
    if is_osp and (self.osp_arch_kind.get(arch_name) == "walker") {
        self._emit_list_helpers("i64", ir.IntType(64));
        _rep_lt = self.list_types.get("i64");
        if _rep_lt is not None {
            _rep_idx = len(field_types);
            field_types.append(_rep_lt.as_pointer());
            field_index_map["reports"] = _rep_idx;
            field_type_map["reports"] = _rep_lt.as_pointer();
            self.osp_reports_field[arch_name] = _rep_idx;
            seen_fields.add("reports");
        }
    }
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
                    if var.type_tag is not None {
                        # HasVar.type is checker-stamped; lower it directly.
                        ftype = self._resolve_jac_type(var);
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
        param_types.append(
            self._resolve_jac_type(p) if p.type_tag is not None else ir.IntType(64)
        );
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
    saved_builder = self._builder;
    saved_locals = self.local_vars;
    saved_param_vars = self.param_vars;
    saved_list_elem_struct = dict(self.var_list_elem_struct);
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.param_vars = set();
    self.var_list_elem_struct = {};
    # Reset per-function borrowed-param promotion state.
    saved_self_arch = self._self_arch;
    self._self_arch = arch_name;
    # DWARF debug info (JAC_NATIVE_DEBUG=1)
    self._attach_di_subprogram(
        func, full_name, method.loc.first_line if method.loc else 0
    );
    # Store self pointer
    self_alloca = self.builder.alloca(func.args[0].type, name="self");
    self.builder.store(func.args[0], self_alloca);
    self.local_vars["self"] = self_alloca;
    # Store other parameters
    sig = method.signature;
    import from jaclang.compiler.ownership { param_plainly_rebound }
    for (i, p) in enumerate(sig.get_parameters()) {
        param_name = p.name.value if p.name else f"arg{i}";
        arg_val = func.args[i + 1];
        alloca = self.builder.alloca(arg_val.type, name=param_name);
        self.builder.store(arg_val, alloca);
        self.local_vars[param_name] = alloca;
        # Rebound borrowed param: owned from birth (see _codegen_ability).
        if isinstance(arg_val.type, ir.PointerType)
        and param_plainly_rebound(p.name.sym if p.name else None) {
            self._emit_rc_retain(arg_val, op="param_promote", loc=full_name);
        } else {
            self.param_vars.add(param_name);
        }
    }
    # Generate body (handle ImplDef wrapper from DeclImplMatchPass)
    body = ModuleCodegenPass.unwrap_body(method);
    if body is not None {
        self._codegen_body(body);
    }
    # Ensure function has a terminator
    if not self.builder.block.is_terminated {
        _mth_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{method.loc.last_line
            if method.loc
            else 0}";
        # release all pointer-typed locals before implicit return.
        self._emit_scope_cleanup(skip_var=None, loc=_mth_loc);
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
    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.param_vars = saved_param_vars;
    self.var_list_elem_struct = saved_list_elem_struct;
    self._self_arch = saved_self_arch;
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
    saved_builder = self._builder;
    saved_locals = self.local_vars;
    saved_param_vars = self.param_vars;
    saved_list_elem_struct = dict(self.var_list_elem_struct);
    saved_self_arch = self._self_arch;
    self._self_arch = arch_name;
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.param_vars = set();
    self.var_list_elem_struct = {};
    # DWARF debug info (JAC_NATIVE_DEBUG=1)
    self._attach_di_subprogram(
        func, full_name, method.loc.first_line if method.loc else 0
    );
    # Store self pointer (only parameter)
    self_alloca = self.builder.alloca(func.args[0].type, name="self");
    self.builder.store(func.args[0], self_alloca);
    self.local_vars["self"] = self_alloca;
    # Generate body (handle ImplDef wrapper from DeclImplMatchPass)
    body = ModuleCodegenPass.unwrap_body(method);
    if body is not None {
        self._codegen_body(body);
    }
    # Ensure function has a terminator
    if not self.builder.block.is_terminated {
        _nosig_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{method.loc.last_line
            if method.loc
            else 0}";
        # release all pointer-typed locals before implicit return.
        self._emit_scope_cleanup(skip_var=None, loc=_nosig_loc);
        self.builder.ret_void();
    }
    method.gen.llvm_ir = func;
    # DWARF post-pass: tag untagged instructions with fallback line
    self._finalize_di_locations(func, method.loc.first_line if method.loc else 1);
    # Restore saved state
    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.param_vars = saved_param_vars;
    self.var_list_elem_struct = saved_list_elem_struct;
    self._self_arch = saved_self_arch;
}

"""Collect the member struct names a trigger tag denotes.

A trigger may be a single `Name` (`with Base entry`), a `|` union, or a
`(A, B)` tuple trigger -- each fires the ability on any listed archetype, so
the implicit `here`/`visitor` is the union of those members. Returns the
known-struct member names in source order (deduped), skipping `None`/unknown.
"""
impl NaIRGenPass._trigger_member_structs(tag: (uni.UniNode | None)) -> list[str] {
    out: list[str] = [];
    if tag is None {
        return out;
    }
    parts: list[uni.UniNode] = [];
    if isinstance(tag, uni.TupleVal) {
        parts = list(tag.values or []);
    } elif isinstance(tag, uni.BinaryExpr) and getattr(tag.op, "value", "") == "|" {
        parts = [tag.left, tag.right];
    } else {
        parts = [tag];
    }
    for part in parts {
        # Recurse so nested forms (e.g. `(A, B | C)`) flatten uniformly.
        if isinstance(part, uni.TupleVal)
        or (
            isinstance(part, uni.BinaryExpr) and getattr(part.op, "value", "") == "|"
        ) {
            for nm in self._trigger_member_structs(part) {
                if nm not in out {
                    out.append(nm);
                }
            }
            continue;
        }
        name = self._get_name(part);
        if name is not None and name in self.struct_types and name not in out {
            out.append(name);
        }
    }
    return out;
}

"""Member struct names an event ability fires on.

Prefers the checker-resolved `Ability.event_triggers` (via the central
`Ability.event_trigger_type_names`) filtered to known structs; falls back
to flattening the trigger AST (`_trigger_member_structs`) when the checker
left no resolution.
"""
impl NaIRGenPass._trigger_struct_names(method: uni.Ability) -> list[str] {
    names = method.event_trigger_type_names();
    if names is None {
        sig = method.signature;
        tag = sig.arch_tag_info if isinstance(sig, uni.EventSignature) else None;
        return self._trigger_member_structs(tag);
    }
    return [
        nm
        for nm in names
        if nm in self.struct_types
    ];
}

"""MRO for an archetype, queried from the central LayoutRegistry (the
single owner of hierarchy facts); [name] when the registry knows nothing
about the name (primitives, foreign names)."""
impl NaIRGenPass._mro_of(arch_name: str) -> list[str] {
    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }
    mro = get_layout_registry(self.ir_in, self.prog).get_mro(arch_name);
    return mro or [arch_name];
}

"""Whether a NATIVE archetype needs a vtable, queried from the central
LayoutRegistry. Restricted to archetypes this module lowered to structs so
non-native archetypes the registry knows about never gain emission here."""
impl NaIRGenPass._arch_has_vtable(arch_name: str) -> bool {
    if arch_name not in self.struct_types {
        return False;
    }
    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }
    lay = get_layout_registry(self.ir_in, self.prog).get_layout(arch_name);
    return lay is not None and lay.has_vtable;
}

"""Find a field whose layout diverges across union trigger members.

Field access on `here`/`visitor` lowers through a single member's layout, so
this is only sound when every field common to all members sits at the same
index and LLVM type. Returns the first divergent field name (for E5091), or
None when the shared layout is consistent (so any member's layout is usable).
"""
impl NaIRGenPass._union_layout_conflict(members: list[str]) -> (str | None) {
    if len(members) <= 1 {
        return None;
    }
    base = members[0];
    base_idx = self.struct_field_indices.get(base, {});
    base_types = self.struct_field_types.get(base, {});
    for fname in base_idx {
        for other in members[1:] {
            other_idx = self.struct_field_indices.get(other, {});
            if fname not in other_idx {
                continue;  # not a common field -- union attr access rejects it
            }
            other_types = self.struct_field_types.get(other, {});
            if other_idx[fname] != base_idx[fname]
            or base_types.get(fname) != other_types.get(fname) {
                return fname;
            }
        }
    }
    return None;
}

"""Forward-declare an Object-Spatial ability (`can ... with T entry/exit`).

An ability with an EventSignature is lowered like a two-parameter method:
`<Arch>.<name>(self, here|visitor)` returning void. The implicit location
parameter is named `here` for a walker ability and `visitor` for a node/edge
ability, typed by the event's archetype tag (the trigger type). `spawn` emits
direct calls to these functions.
"""
impl NaIRGenPass._forward_declare_event_method(
    arch_name: str, method: uni.Ability
) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    if full_name in self.method_funcs {
        return;
    }
    sig = method.signature;
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None or not isinstance(sig, uni.EventSignature) {
        return;
    }
    loc_type: ir.Type = ir.IntType(8).as_pointer();
    if sig.arch_tag_info is not None {
        # A tuple/union trigger has no single struct type; lower the implicit
        # location parameter to a representative member's pointer so field
        # access on `here`/`visitor` has a usable layout (issue #6470). A plain
        # single-type trigger yields exactly the one member, matching the prior
        # `_resolve_jac_type` result.
        _members = self._trigger_struct_names(method);
        if _members {
            loc_type = self.struct_types[_members[0]].as_pointer();
        } else {
            loc_type = self._resolve_jac_type(sig.arch_tag_info);
        }
    }
    fnty = ir.FunctionType(ir.VoidType(), [struct_type.as_pointer(), loc_type]);
    func = ir.Function(self.llvm_module, fnty, name=full_name);
    func.args[0].name = "self";
    func.args[1].name = "here" if sig.from_walker else "visitor";
    self.method_funcs[full_name] = func;
    self.func_symtab[full_name] = func;
}

"""Generate the body of an Object-Spatial ability.

Mirrors `_codegen_no_sig_method` but also binds the implicit location parameter
(`here`/`visitor`) and tracks its trigger type so `here.x` resolves against the
node struct.
"""
impl NaIRGenPass._codegen_event_method(arch_name: str, method: uni.Ability) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    func = self.method_funcs.get(full_name);
    sig = method.signature;
    if func is None or not isinstance(sig, uni.EventSignature) {
        return;
    }
    block = func.append_basic_block(name="entry");
    saved_builder = self._builder;
    saved_locals = self.local_vars;
    saved_param_vars = self.param_vars;
    saved_list_elem_struct = dict(self.var_list_elem_struct);
    saved_self_arch = self._self_arch;
    self._self_arch = arch_name;
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.param_vars = set();
    self.var_list_elem_struct = {};
    self._attach_di_subprogram(
        func, full_name, method.loc.first_line if method.loc else 0
    );
    self_alloca = self.builder.alloca(func.args[0].type, name="self");
    self.builder.store(func.args[0], self_alloca);
    self.local_vars["self"] = self_alloca;
    # Bind the implicit location parameter (here / visitor).
    loc_name = "here" if sig.from_walker else "visitor";
    loc_arg = func.args[1];
    loc_alloca = self.builder.alloca(loc_arg.type, name=loc_name);
    self.builder.store(loc_arg, loc_alloca);
    self.local_vars[loc_name] = loc_alloca;
    self.param_vars.add(loc_name);
    if sig.arch_tag_info is not None {
        # For a tuple/union trigger (`with (A, B) entry`), members must agree
        # on shared field offsets or `here.field` reads would be quietly wrong
        # under the single-layout lowering (issue #6470).
        _members = self._trigger_struct_names(method);
        _conflict = self._union_layout_conflict(_members);
        if _conflict is not None {
            self.emit(
                E5091,
                node_override=sig.arch_tag_info,
                members=", ".join(_members),
                field=_conflict
            );
        }
    }
    body = ModuleCodegenPass.unwrap_body(method);
    if body is not None {
        self._codegen_body(body);
    }
    if not self.builder.block.is_terminated {
        _ev_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{method.loc.last_line
            if method.loc
            else 0}";
        self._emit_scope_cleanup(skip_var=None, loc=_ev_loc);
        self.builder.ret_void();
    }
    method.gen.llvm_ir = func;
    self._finalize_di_locations(func, method.loc.first_line if method.loc else 1);
    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.param_vars = saved_param_vars;
    self.var_list_elem_struct = saved_list_elem_struct;
    self._self_arch = saved_self_arch;
}

"""Generate object instantiation: allocate struct, init fields, call postinit."""
impl NaIRGenPass._codegen_instantiation(nd: uni.FuncCall) -> (ir.Value | None) {
    type_name = self._get_name(nd.target);
    if type_name is None or type_name not in self.struct_types {
        return None;
    }
    struct_type = self.struct_types[type_name];
    struct_ptr_type = struct_type.as_pointer();
    # Clib vtable structs are plain C data handed to the C runtime: C reads
    # them starting at field 0 and owns their lifetime, so they allocate
    # flat (zeroed, C layout, no RC header/destructor/type tag) — see
    # _clib_alloc_vtable (issue #6571).
    _vt_struct = type_name in self.clib_vtable_structs;
    if _vt_struct {
        obj_ptr = self._clib_alloc_vtable(type_name);
    } else {
        # Compute sizeof using GEP-from-null trick
        null_ptr = ir.Constant(struct_ptr_type, None);
        size_gep = self.builder.gep(
            null_ptr, [ir.Constant(ir.IntType(32), 1)], name="sizeof.gep"
        );
        size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="sizeof");
        # Allocate via rc_alloc (RC-managed)
        _inst_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
            if nd.loc
            else 0}";
        raw_ptr = self._rc_call_with_ctx(
            self.rc_alloc_fn, [size], op="new", loc=_inst_loc, name="raw.ptr"
        );
        obj_ptr = self.builder.bitcast(raw_ptr, struct_ptr_type, name="obj.ptr");
        # Store the typed destructor function pointer at obj_ptr - 8
        # so __rc_release_simple dispatches to it when refcount hits zero.
        self._emit_struct_release_fn(type_name);
        _dtor_fn_s = self.struct_release_fns.get(type_name);
        if _dtor_fn_s is not None {
            _i8p_s = ir.IntType(8).as_pointer();
            _i64_s = ir.IntType(64);
            _i64p_s = _i64_s.as_pointer();
            _raw_s = self.builder.bitcast(obj_ptr, _i8p_s, name="obj_raw_s");
            _dtor_slot_s = self.builder.gep(
                _raw_s, [ir.Constant(_i64_s, -8)], name="obj_dtor_slot"
            );
            _dtor_slot_i64_s = self.builder.bitcast(
                _dtor_slot_s, _i64p_s, name="obj_dtor_i64p"
            );
            _dtor_i64_s = self.builder.ptrtoint(
                _dtor_fn_s, _i64_s, name="obj_dtor_i64"
            );
            self.builder.store(_dtor_i64_s, _dtor_slot_i64_s);
        }
        # Set type tag in header (ptr-24) so RC debug log shows the type name.
        if self.rc_set_type_fn is not None {
            _obj_i8 = self.builder.bitcast(
                obj_ptr, ir.IntType(8).as_pointer(), name="obj.i8.tag"
            );
            self._emit_set_type_tag(self.builder, _obj_i8, type_name);
        }
    }
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
    # Store the OSP type-tag into the reserved __type_tag field (issue #6146)
    # so the kernel's `tag_of` can recover this instance's type at runtime.
    _tt_idx = self.osp_type_tag_field.get(type_name);
    if _tt_idx is not None {
        _tt_slot = self.builder.gep(
            obj_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), _tt_idx)],
            name="type_tag.slot"
        );
        self.builder.store(
            ir.Constant(ir.IntType(64), self.osp_tags.get(type_name, 0)), _tt_slot
        );
        # Graph-arena lifetime: an OSP instance is a graph location, referenced
        # by the walk as a borrowed `any` handle (boxed pointer) inside the
        # kernel's work-stack / scope lists. Those lists retain/release the boxed
        # pointer, which over-releases the location and frees it mid-walk (the
        # edge<->node refcount issue, #6146). Pin every node/walker/edge to the
        # immortal sentinel so the graph persists for the program -- matching the
        # immortal descriptor singletons. A scoped arena teardown is future work.
        self._osp_make_immortal(obj_ptr);
    }
    # Initialize the built-in walker `reports` list to empty so `w.reports` is a
    # valid (empty) list before any spawn; the kernel's on_complete replaces it
    # with the walk's collected reports at the spawn boundary (issue #6146).
    _rep_idx = self.osp_reports_field.get(type_name);
    if _rep_idx is not None {
        _rep_h = self.list_helpers.get("i64");
        if _rep_h is not None {
            _rep_list = self._rc_call_with_ctx(
                _rep_h["new"], [], op="new", loc="", name="reports.init"
            );
            self.builder.store(
                _rep_list,
                self.builder.gep(
                    obj_ptr,
                    [
                        ir.Constant(ir.IntType(32), 0),
                        ir.Constant(ir.IntType(32), _rep_idx)
                    ],
                    name="reports.slot"
                )
            );
        }
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
            # Clib vtable fn-ptr slots hold C function pointers (a NULL
            # default or a Jac def behind a C-ABI trampoline) — code
            # addresses, never RC objects (issue #6570).
            _is_clib_cb = (
                type_name in self.clib_vtable_structs
                and isinstance(ftype, ir.PointerType)
                and isinstance(ftype.pointee, ir.FunctionType)
            );
            if _is_clib_cb {
                val = self._clib_coerce_callback(val, ftype);
            } else {
                # _coerce_type propagates is_owned across bitcasts so checking
                # val post-coerce is sufficient.
                val = self._coerce_type(val, ftype);
            }
            # RC: retain pointer values stored into struct fields.
            # skip if already owned (call result) — field takes over rc=1.
            # C-owned vtable structs have no destructor to balance a retain,
            # so their fields never participate in RC (issue #6571).
            if not _vt_struct {
                self._emit_take_ref(
                    val,
                    op="ctor_field",
                    loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                        if nd.loc
                        else 0}"
                );
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
            # An empty collection literal default types itself: the checker
            # stamps it with the declared field type (bidirectional
            # inference), and the literal codegen emits the right variant.
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
                # Clib vtable fn-ptr slots: `= 0` defaults lower to a NULL C
                # function pointer; a Jac def default goes through a C-ABI
                # trampoline (issue #6570). Never RC-retained.
                _is_clib_cb_d = (
                    type_name in self.clib_vtable_structs
                    and isinstance(ftype, ir.PointerType)
                    and isinstance(ftype.pointee, ir.FunctionType)
                );
                if _is_clib_cb_d {
                    val = self._clib_coerce_callback(val, ftype);
                } else {
                    val = self._coerce_type(val, ftype);
                }
                # RC: retain pointer defaults stored into struct fields.
                # skip if already owned (call result) — field takes over rc=1.
                # C-owned vtable structs never participate in RC (issue #6571).
                if not _vt_struct {
                    self._emit_take_ref(
                        val,
                        op="ctor_field",
                        loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                            if nd.loc
                            else 0}"
                    );
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
    # --- Callable struct field: `obj.field(args)` where `field` is a
    # function-pointer field (not a method). Load the pointer and indirect-call.
    # (Method dispatch handles real methods; fields are checked here first.)
    _fld_struct = self._struct_name_of(trailer.target);
    if (
        _fld_struct is not None
        and _fld_struct in self.struct_field_types
        and method_name in self.struct_field_types[_fld_struct]
    ) {
        _fld_ty = self.struct_field_types[_fld_struct][method_name];
        if (
            isinstance(_fld_ty, ir.PointerType)
            and isinstance(_fld_ty.pointee, ir.FunctionType)
        ) {
            _obj_v = self._codegen_expr(trailer.target);
            if _obj_v is not None {
                _idx = self.struct_field_indices[_fld_struct][method_name];
                _fld_ptr = self.builder.gep(
                    _obj_v,
                    [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), _idx)],
                    name=f"{method_name}.fldptr"
                );
                _fnp = self.builder.load(_fld_ptr, name=f"{method_name}.fn");
                _fn_ty = _fld_ty.pointee;
                _cargs: list[ir.Value] = [];
                for (_i, _p) in enumerate(nd.params or []) {
                    _pv = self._codegen_expr(_p);
                    if _pv is not None {
                        if _i < len(_fn_ty.args) {
                            _pv = self._coerce_type(_pv, _fn_ty.args[_i]);
                        }
                        _cargs.append(_pv);
                    }
                }
                _r = self.builder.call(_fnp, _cargs, name=f"icall.{method_name}");
                if isinstance(_fn_ty.return_type, ir.VoidType) {
                    return None;
                }
                return _r;
            }
        }
    }
    # --- Native stdlib module method calls: sys.exit() ---
    if (
        target_name == "sys"
        and self?._native_stdlib_modules
        and "sys" in self._native_stdlib_modules
    ) {
        if method_name == "exit" {
            arg_vals = self._codegen_call_args(nd);
            return self._emit_sys_exit(arg_vals);
        }
    }
    # --- Native stdlib math module calls: math.sqrt(x), math.pow(a, b), ... ---
    if (
        target_name == "math"
        and self?._native_stdlib_modules
        and "math" in self._native_stdlib_modules
    ) {
        _mres = self._emit_math_call(method_name, nd);
        if _mres is not None {
            return _mres;
        }
    }
    # --- Native stdlib time module calls: time.time(), time.sleep(s), ... ---
    # Gated on the known name set so a void result (time.sleep) is not mistaken
    # for "unhandled" and routed to E5090.
    if (
        target_name == "time"
        and self?._native_stdlib_modules
        and "time" in self._native_stdlib_modules
        and method_name in NATIVE_TIME_FUNCS
    ) {
        return self._emit_time_call(method_name, nd);
    }
    # --- Native stdlib os.path.X(...) (nested attribute: trailer.target is
    # itself the AtomTrailer `os.path`). Checked before the flat os.* path. ---
    if (
        isinstance(trailer.target, uni.AtomTrailer)
        and trailer.target.is_attr
        and self._get_name(trailer.target.target) == "os"
        and self._get_name(trailer.target.right) == "path"
        and self?._native_stdlib_modules
        and "os" in self._native_stdlib_modules
    ) {
        return self._emit_ospath_call(method_name, nd);
    }
    # --- Native stdlib flat os.X(...) calls ---
    if (
        target_name == "os"
        and self?._native_stdlib_modules
        and "os" in self._native_stdlib_modules
        and method_name in NATIVE_OS_FUNCS
    ) {
        return self._emit_os_call(method_name, nd);
    }
    # --- Native stdlib random.X(...) calls (gated: random.seed is void) ---
    if (
        target_name == "random"
        and self?._native_stdlib_modules
        and "random" in self._native_stdlib_modules
        and method_name in NATIVE_RANDOM_FUNCS
    ) {
        return self._emit_random_call(method_name, nd);
    }
    # --- Static/class method dispatch (int.from_bytes, float.fromhex) ---
    if target_name == "int" and method_name == "from_bytes" {
        arg_vals = self._codegen_call_args(nd);
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
        arg_vals = self._codegen_call_args(nd);
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
    # List methods — list-ness comes from the checked type of the target;
    # the dispatch spec prefers the value's actual LLVM shape (a bare `list`
    # annotation may hold ptr/f64 elements seeded at runtime).
    list_spec = self._list_spec_of(trailer.target);
    if list_spec is not None {
        list_val = self._codegen_expr(trailer.target);
        if list_val is not None {
            _shape_spec = self._infer_list_elem_type(list_val);
            elem_type_name = _shape_spec if _shape_spec is not None else list_spec;
            arg_vals = self._codegen_call_args(nd);
            # A tuple appended/inserted into a list whose boxed element-struct is
            # tracked (a bare `list` seeded with an `any`-containing tuple) must
            # be stored in that exact layout, otherwise the unpack side reads the
            # wrong field types. Box any concrete scalar that lands in an
            # `any`/`JacVal` slot so producer and consumer agree. See #6511.
            _elem_struct = self.var_list_elem_struct.get(target_name);
            if _elem_struct is not None
            and isinstance(_elem_struct, ir.PointerType)
            and isinstance(_elem_struct.pointee, ir.LiteralStructType) {
                _tidx = -1;
                if method_name == "append" and arg_vals {
                    _tidx = 0;
                } elif method_name == "insert" and len(arg_vals) > 1 {
                    _tidx = 1;
                }
                if _tidx >= 0 {
                    arg_vals[_tidx] = self._coerce_tuple_to_struct(
                        arg_vals[_tidx], _elem_struct.pointee
                    );
                }
            }
            if method_name == "append" {
                self._set_rc_ctx(
                    "append",
                    f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                        if nd.loc
                        else 0}"
                );
            }
            result = self._dispatch_primitive_method(
                "list", method_name, list_val, arg_vals, elem_type_name
            );
            # Clear ctx after dispatch so the next allocation in this scope
            # is not misattributed to this operation.
            self._clear_rc_ctx();
            if result is not None {
                return result;
            }
        }
    }
    # Set methods — set-ness comes from the checked type of the target
    set_spec = self._set_spec_of(trailer.target);
    if set_spec is not None {
        elem_type_name = set_spec;
        set_val = self._codegen_expr(trailer.target);
        if set_val is not None {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "set", method_name, set_val, arg_vals, elem_type_name
            );
            if result is not None {
                return result;
            }
        }
    }
    # Tuple methods — tuple-ness comes from the checked type of the target
    tuple_type_key = self._tuple_key_of(trailer.target);
    if tuple_type_key is not None {
        tuple_val = self._codegen_expr(trailer.target);
        if tuple_val is not None {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "tuple", method_name, tuple_val, arg_vals, tuple_type_key
            );
            if result is not None {
                return result;
            }
        }
    }
    # Dict methods — dict-ness comes from the checked type of the target
    dict_type_key: (str | None) = self._dict_key_of(trailer.target);
    if dict_type_key is None and target_name is not None {
        # Fallback: infer dict type from LLVM type (handles untyped targets)
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
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "dict", method_name, dict_val, arg_vals, dict_type_key
            );
            if result is not None {
                return result;
            }
        }
    }
    # Int methods (on any target expression whose type is i64)
    if method_name in self._primitive_method_names("int") {
        int_val = self._codegen_expr(trailer.target);
        if int_val is not None and isinstance(int_val.type, ir.IntType) {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "int", method_name, int_val, arg_vals, ""
            );
            if result is not None {
                return result;
            }
        }
    }
    # Float methods (on any target expression whose type is double)
    if method_name in self._primitive_method_names("float") {
        float_val = self._codegen_expr(trailer.target);
        if float_val is not None and isinstance(float_val.type, ir.DoubleType) {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "float", method_name, float_val, arg_vals, ""
            );
            if result is not None {
                return result;
            }
        }
    }
    # Complex methods (conjugate)
    if method_name in self._primitive_method_names("complex") {
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
        if self._type_key_of(trailer.target) == "range" {
            rng_val = self._codegen_expr(trailer.target);
            if rng_val is not None {
                arg_vals = self._codegen_call_args(nd);
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
    if method_name in self._primitive_method_names("str") {
        str_val = self._codegen_expr(trailer.target);
        if str_val is not None and str_val.type == ir.IntType(8).as_pointer() {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "str", method_name, str_val, arg_vals, ""
            );
            if result is not None {
                return result;
            }
        }
    }
    # Determine type_name and obj_val (supports chained access) —
    # struct-ness comes from the checked type of the target expression.
    type_name: (str | None) = self._struct_name_of(trailer.target);
    obj_val: (ir.Value | None) = None;
    if type_name is None {
        # Complex expression target (chained access) — evaluate and infer
        obj_val = self._codegen_expr(trailer.target);
        if obj_val is not None {
            type_name = self._infer_type_name(obj_val);
            # Handle list methods on complex targets (e.g. g.items.append(x),
            # self.stack.pop()). Route through the same primitive-method
            # dispatch as simple-name targets so every list method (append,
            # pop, ...) works on field/chained lists, not just append.
            if type_name is None {
                elem_type_name = self._infer_list_elem_type(obj_val);
                if elem_type_name is not None {
                    arg_vals = self._codegen_call_args(nd);
                    if method_name == "append" {
                        self._set_rc_ctx(
                            "append",
                            f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                                if nd.loc
                                else 0}"
                        );
                    }
                    result = self._dispatch_primitive_method(
                        "list", method_name, obj_val, arg_vals, elem_type_name
                    );
                    self._clear_rc_ctx();
                    if result is not None {
                        return result;
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
    for check_name in self._mro_of(type_name) {
        full_name = f"{check_name}.{method_name}";
        if full_name in self.method_funcs {
            func = self.method_funcs[full_name];
            break;
        }
    }
    if func is None {
        return None;
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
    # Fill in missing optional parameters with the resolved callee's
    # default-value exprs (checker-stamped fact, not a name-keyed cache)
    self._fill_default_args(nd, func, args, skip_self=True);
    # Virtual dispatch if type has vtable
    if self._arch_has_vtable(type_name) {
        result = self._codegen_virtual_call(obj_val, method_name, args, type_name);
        if result is not None {
            if isinstance(func.return_value.type, ir.VoidType) {
                return ir.Constant(ir.IntType(64), 0);
            }
            # Pointer results carry +1; ownership applied at the
            # _codegen_expr seam (compiler/ownership.jac).
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
    # Return void calls as None
    if isinstance(func.return_value.type, ir.VoidType) {
        return ir.Constant(ir.IntType(64), 0);
    }
    # Pointer results carry +1; ownership applied at the _codegen_expr
    # seam (compiler/ownership.jac).
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
    field_name = self._get_name(target.right);
    if field_name is None {
        return None;
    }
    type_name: (str | None) = self._struct_name_of(target.target);
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
    # A field store whose receiver type / field can't be resolved used to
    # vanish silently (the #6470 write-side analog). Surface it as E5090,
    # unless a deeper diagnostic already pinpointed the cause.
    _fa_errs = len(self.errors_had);
    field_name = self._get_name(target.right);
    obj_val = self._codegen_expr(target.target);
    type_name: (str | None) = self._struct_name_of(target.target);
    if type_name is None and obj_val is not None {
        type_name = self._infer_type_name(obj_val);
    }
    field_indices = self.struct_field_indices.get(type_name)
        if type_name is not None
        else None;
    if (
        field_name is None
        or obj_val is None
        or type_name is None
        or field_indices is None
        or field_name not in field_indices
    ) {
        if len(self.errors_had) == _fa_errs {
            self.emit(
                E5090,
                node_override=target,
                kind="field assignment",
                name=(field_name or "<field>")
            );
        }
        return;
    }
    field_types = self.struct_field_types.get(type_name);
    idx = field_indices[field_name];
    ftype = field_types[field_name];
    # Clib vtable fn-ptr slots hold C function pointers (NULL or a Jac def
    # behind a C-ABI trampoline) — code addresses, never RC objects, so
    # the retain/release discipline below does not apply (issue #6570).
    _vt_struct = type_name in self.clib_vtable_structs;
    _is_clib_cb = (
        _vt_struct
        and isinstance(ftype, ir.PointerType)
        and isinstance(ftype.pointee, ir.FunctionType)
    );
    if _is_clib_cb {
        value = self._clib_coerce_callback(value, ftype);
    } else {
        value = self._coerce_type(value, ftype);
    }
    field_ptr = self.builder.gep(
        obj_val,
        [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
        name=f"field.{field_name}.ptr"
    );
    # RC: retain new value and release old value for pointer fields.
    # skip retain if value is already owned (function call result) — the
    # field takes over the existing rc=1 without an extra increment.
    # C-owned vtable structs never participate in RC (issue #6571).
    if isinstance(ftype, ir.PointerType) and not _vt_struct {
        self._emit_take_ref(
            value,
            op="field_set",
            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{target.loc.first_line
                if target.loc
                else 0}"
        );
        old_field_val = self.builder.load(field_ptr, name=f"field.{field_name}.old");
        self._emit_rc_release_simple(
            old_field_val,
            op="field_set",
            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{target.loc.first_line
                if target.loc
                else 0}"
        );
    }
    self.builder.store(value, field_ptr);
}
# ─── Phase 4: Lists ──────────────────────────────────────────
