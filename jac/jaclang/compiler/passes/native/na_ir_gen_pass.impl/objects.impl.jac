impl NaIRGenPass._native_archetypes(module: uni.Module) -> list[uni.Archetype] {
    result: dict[(str, uni.Archetype)] = {};

    for stmt in ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE) {
        if isinstance(stmt, uni.Archetype) {
            aname = stmt.name.value if stmt.name else "unknown";
            if aname not in result or stmt.body is not None {
                result[aname] = stmt;
            }
        }
    }

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

impl NaIRGenPass._forward_declare_archetype_names(module: uni.Module) -> None {
    for arch in self._native_archetypes(module) {
        aname = arch.name.value if arch.name else None;
        if aname is not None and aname not in self.struct_types {
            struct_type = self.llvm_module.context.get_identified_type(aname);
            self.struct_types[aname] = struct_type;
        }
    }
}

impl NaIRGenPass._register_archetypes(module: uni.Module) -> None {
    archetypes: list[uni.Archetype] = self._native_archetypes(module);
    arch_map: dict[(str, uni.Archetype)] = {};
    for arch in archetypes {
        arch_map[arch.name.value if arch.name else "unknown"] = arch;
    }

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        struct_type = self.llvm_module.context.get_identified_type(arch_name);
        self.struct_types[arch_name] = struct_type;
        self.has_native_code = True;
    }

    self._compute_osp_model(archetypes);

    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }
    layout_reg = get_layout_registry(self.ir_in, self.prog);
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        self.arch_ast_map[arch_name] = arch;
    }

    topo_order = layout_reg.get_topo_order();
    for topo_name in topo_order {
        if topo_name in arch_map {
            self._codegen_archetype(arch_map[topo_name]);
        }
    }

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch.body is not None {
            for stmt in arch.body {
                if isinstance(stmt, uni.Ability) {
                    if stmt.signature is not None
                    and isinstance(stmt.signature, uni.FuncSignature) {
                        self._forward_declare_method(arch_name, stmt);
                    } elif stmt.signature is None and stmt.body is not None {
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
                        self._forward_declare_event_method(arch_name, stmt);
                        if arch.arch_kind is not None {
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
                            E5092,
                            node_override=stmt,
                            kind="archetype method",
                            name=f"{arch_name}.{_m_name} ({_sig_kind})"
                        );
                    }
                }
            }
        }
    }

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        self._emit_struct_release_fn(arch_name);
        self._emit_trace_fn(arch_name);
    }

    for arch in archetypes {
        self._visit_nonprimary_ancestor_methods(arch, declare=True);
    }

    for topo_name in topo_order {
        if self._arch_has_vtable(topo_name) {
            self._build_vtable(topo_name);
        }
    }

    for (base_name, layout) in self.vtable_layouts.items() {
        non_overridden: set[str] = set();
        for method_name in layout {
            defining_class = self._resolve_method_owner(base_name, method_name);
            if defining_class is None {
                continue;
            }

            overridden = False;
            for child_name in self.arch_ast_map {
                child_mro = self._mro_of(child_name);
                if base_name not in child_mro {
                    continue;
                }

                child_full = f"{child_name}.{method_name}";
                if child_full in self.method_funcs {
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

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if self._arch_has_vtable(arch_name) {
            self._emit_vtable_global(arch_name);
        }
    }

    self._forward_declare_functions(module);

    self._register_osp_kernel_module();
    self._emit_osp_setup();

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
                        self._codegen_no_sig_method(arch_name, stmt);
                    }
                }
            }
        }
    }

    for arch in archetypes {
        self._visit_nonprimary_ancestor_methods(arch, declare=False);
    }

    self._generate_inherited_method_wrappers();
}

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

impl NaIRGenPass._codegen_archetype(nd: uni.Archetype) -> None {
    arch_name = (nd).name.value if (nd).name else "unknown";
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None {
        return;
    }
    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }
    _owner_mod = nd.find_parent_of_type(uni.Module) or self.ir_in;
    layout = get_layout_registry(_owner_mod, self.prog).get_layout(arch_name);
    if layout is None {
        return;
    }

    field_types: list[ir.Type] = [];
    field_index_map: dict[(str, int)] = {};
    field_type_map: dict[(str, ir.Type)] = {};
    field_default_map: dict[(str, object)] = {};

    opaque_fields: set = set();

    if layout.vtable_ptr_slot is not None {
        field_types.append(ir.IntType(8).as_pointer().as_pointer());
    }
    if layout.type_tag_slot is not None {
        field_types.append(ir.IntType(64));
        self.osp_type_tag_field[arch_name] = layout.type_tag_slot;
    }
    if layout.reports_slot is not None {
        self._emit_list_helpers("i64", ir.IntType(64));
        _rep_lt = self.list_types.get("i64");
        if _rep_lt is not None {
            field_types.append(_rep_lt.as_pointer());
            field_index_map["reports"] = layout.reports_slot;
            field_type_map["reports"] = _rep_lt.as_pointer();
            self.osp_reports_field[arch_name] = layout.reports_slot;
        }
    }

    self.parent_field_start[arch_name] = dict(layout.parent_field_start);

    for finfo in layout.fields {
        fname = finfo.name;
        var = finfo.decl_node;
        ftype = ir.IntType(64);
        _is_opaque = False;
        if var is not None and var.type_tag is not None {
            if finfo.owner in self.clib_struct_names {
                ftype = self._resolve_jac_type(var.type_tag);
            } else {
                (ftype, _is_opaque) = self._try_resolve_field_type(var);
                if _is_opaque {
                    opaque_fields.add(fname);
                }
            }

            ftag_name = self._get_name(var.type_tag.tag);
            if ftag_name is not None and ftag_name in self.enum_types {
                if arch_name not in self.struct_field_enum_type {
                    self.struct_field_enum_type[arch_name] = {};
                }
                self.struct_field_enum_type[arch_name][fname] = ftag_name;
            }
        }
        field_types.append(ftype);
        field_index_map[fname] = finfo.index;
        field_type_map[fname] = ftype;

        if var is not None and var.value is not None and not _is_opaque {
            field_default_map[fname] = var.value;
        }
    }

    if (nd).body is not None {
        for stmt in (nd).body {
            if isinstance(stmt, uni.ArchHas) and stmt.is_static {
                self._register_static_fields(arch_name, stmt);
            }
        }
    }

    struct_type.set_body(*field_types);
    self.struct_field_indices[arch_name] = field_index_map;
    self.struct_field_types[arch_name] = field_type_map;
    self.struct_field_defaults[arch_name] = field_default_map;
    self.struct_field_opaque[arch_name] = opaque_fields;
}

impl NaIRGenPass._register_static_fields(arch_name: str, archhas: uni.ArchHas) -> None {
    for var in archhas.vars {
        fname = var.name.value if var.name else "field";
        full_name = f"{arch_name}.{fname}";
        if full_name in self.static_fields {
            continue;
        }
        ftype: ir.Type = ir.IntType(64);
        if var.type_tag is not None {
            ftype = self._resolve_jac_type(var.type_tag);
        } elif var.value is not None {
            inferred = self._infer_global_init_type(var.value);
            if inferred is not None {
                ftype = inferred;
            }
        }

        if full_name in self.llvm_module.globals {
            continue;
        }
        gv = ir.GlobalVariable(self.llvm_module, ftype, name=full_name);

        gv.linkage = "";
        const_init = self._codegen_const_expr(var.value, ftype)
            if var.value is not None
            else None;
        if const_init is not None {
            gv.initializer = const_init;
        } else {
            gv.initializer = ir.Constant(ftype, None);
        }
        self.static_fields[full_name] = gv;
        self.static_field_types[full_name] = ftype;
        self.global_vars[full_name] = gv;
        self.global_var_types[full_name] = ftype;
        self.has_native_code = True;

        if var.value is not None and const_init is None {
            if not self?._global_init_nodes {
                self._global_init_nodes: list = [];
            }
            self._global_init_nodes.append((full_name, var.value, ftype));
        }
    }
}


impl NaIRGenPass._forward_declare_method(arch_name: str, method: uni.Ability) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";

    if full_name in self.method_funcs {
        return;
    }
    sig = method.signature;
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None or sig is None {
        return;
    }
    _is_static = method.is_static;

    param_types: list[ir.Type] = [] if _is_static else [struct_type.as_pointer()];
    for p in sig.get_parameters() {
        param_types.append(
            self._resolve_jac_type(p) if p.type_tag is not None else ir.IntType(64)
        );
    }

    ret_type = self._resolve_jac_type(sig.return_type);
    if isinstance(ret_type, ir.VoidType) {
        ;
    }
    fnty = ir.FunctionType(ret_type, param_types);
    func = ir.Function(self.llvm_module, fnty, name=full_name);

    _base = 0 if _is_static else 1;
    if not _is_static {
        func.args[0].name = "self";
    }
    for (i, p) in enumerate(sig.get_parameters()) {
        func.args[i + _base].name = p.name.value if p.name else f"arg{i}";
    }
    self.method_funcs[full_name] = func;
    self.func_symtab[full_name] = func;
    if _is_static {
        self.static_methods[full_name] = True;
    }
}

impl NaIRGenPass._codegen_method(arch_name: str, method: uni.Ability) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    func = self.method_funcs.get(full_name);
    if func is None {
        return;
    }

    block = func.append_basic_block(name="entry");
    saved_builder = self._builder;
    saved_locals = self.local_vars;
    saved_param_vars = self.param_vars;
    saved_list_elem_struct = dict(self.var_list_elem_struct);
    self._builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.param_vars = set();
    self.var_list_elem_struct = {};

    saved_self_arch = self._self_arch;
    self._self_arch = arch_name;

    self._attach_di_subprogram(
        func, full_name, method.loc.first_line if method.loc else 0
    );

    _is_static = method.is_static;
    _base = 0;
    if not _is_static {
        self_alloca = self.builder.alloca(func.args[0].type, name="self");
        self.builder.store(func.args[0], self_alloca);
        self.local_vars["self"] = self_alloca;
        _base = 1;
    }

    sig = method.signature;
    for (i, p) in enumerate(sig.get_parameters()) {
        param_name = p.name.value if p.name else f"arg{i}";
        arg_val = func.args[i + _base];
        alloca = self.builder.alloca(arg_val.type, name=param_name);
        self.builder.store(arg_val, alloca);
        self.local_vars[param_name] = alloca;

        if isinstance(arg_val.type, ir.PointerType)
        and bool(p.name?.sym?.param_rebound) {
            self._emit_rc_retain(arg_val, op="param_promote", loc=full_name);
        } else {
            self.param_vars.add(param_name);
        }
    }

    _isolate = method_name not in ("init", "__init__", "postinit", "__post_init__")
    and method_name not in self.vtable_method_indices.get(arch_name, {});
    _err_mark = len(self.prog.errors_had) if _isolate else 0;
    _local_mark = len(self.errors_had) if _isolate else 0;

    try {
        body = ModuleCodegenPass.unwrap_body(method);
        if body is not None {
            self._codegen_body(body);
        }

        if not self.builder.block.is_terminated {
            _mth_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{method.loc.last_line
                if method.loc
                else 0}";

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

        self._finalize_di_locations(func, method.loc.first_line if method.loc else 1);
    } except Exception as _codegen_exc {
        if not _isolate {
            raise;
        }

        self.emit(
            E5092,
            node_override=method,
            kind="method (native emitter error in)",
            name=full_name,
            help_text=f"The native backend raised {type(_codegen_exc).__name__} "
            f"while lowering this method; it falls back to its Python "
            f"implementation. Original error: {_codegen_exc}"
        );
    }

    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.param_vars = saved_param_vars;
    self.var_list_elem_struct = saved_list_elem_struct;
    self._self_arch = saved_self_arch;

    if _isolate {
        self._demote_method_if_unlowerable(full_name, func, _err_mark, _local_mark);
    }
}

impl NaIRGenPass._demote_method_if_unlowerable(
    full_name: str, func: ir.Function, err_mark: int, local_mark: int
) -> bool {
    if len(self.prog.errors_had) <= err_mark {
        return False;
    }

    import os;
    _warn = bool(os.environ.get("JAC_NATIVE_DEBUG", ""));

    _accel_quiet = False;
    try {
        import from jaclang.jac0core.native_accel { native_accel_warnings_suppressed }
        _accel_quiet = native_accel_warnings_suppressed();
    } except Exception { }
    if not _warn and not _accel_quiet {
        _warn = True;
        try {
            import from jaclang.project.config { get_config }
            _cfg = get_config();
            if _cfg and _cfg.check {
                _warn = bool(_cfg.check.warn_native_seams);
            }
        } except Exception { }
    }
    if _warn {
        import sys;
        _why = "; ".join(str(e) for e in self.prog.errors_had[err_mark:]);
        sys.stderr.write(
            f"warning: native seam -- demoting {full_name} to Python-only "
            f"(un-lowerable): {_why}\n"
        );
    }
    del self.prog.errors_had[err_mark:];
    del self.errors_had[local_mark:];
    func.blocks.clear();
    blk = func.append_basic_block(name="entry");
    b = ir.IRBuilder(blk);
    self._get_or_declare_extern("abort", ir.VoidType(), []);
    b.call(self.extern_funcs["abort"], []);
    b.unreachable();
    self.method_funcs.pop(full_name, None);
    self.func_symtab.pop(full_name, None);
    self._native_skipped_methods.add(full_name);
    return True;
}

impl NaIRGenPass._codegen_no_sig_method(arch_name: str, method: uni.Ability) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    func = self.method_funcs.get(full_name);
    if func is None {
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

    body = ModuleCodegenPass.unwrap_body(method);
    if body is not None {
        self._codegen_body(body);
    }

    if not self.builder.block.is_terminated {
        _nosig_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{method.loc.last_line
            if method.loc
            else 0}";

        self._emit_scope_cleanup(skip_var=None, loc=_nosig_loc);
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

impl NaIRGenPass._mro_of(arch_name: str) -> list[str] {
    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }
    mro = get_layout_registry(self.ir_in, self.prog).get_mro(arch_name);
    return mro or [arch_name];
}

impl NaIRGenPass._arch_has_vtable(arch_name: str) -> bool {
    if arch_name not in self.struct_types {
        return False;
    }
    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }
    lay = get_layout_registry(self.ir_in, self.prog).get_layout(arch_name);
    return lay is not None and lay.has_vtable;
}

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
                continue;
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

    loc_name = "here" if sig.from_walker else "visitor";
    loc_arg = func.args[1];
    loc_alloca = self.builder.alloca(loc_arg.type, name=loc_name);
    self.builder.store(loc_arg, loc_alloca);
    self.local_vars[loc_name] = loc_alloca;
    self.param_vars.add(loc_name);
    if sig.arch_tag_info is not None {
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

impl NaIRGenPass._stack_alloc_target_ok(nd: uni.UniNode) -> bool {
    p = nd.parent;
    if not isinstance(p, uni.Assignment) or p.aug_op is not None or p.value is not nd {
        return False;
    }
    targets = p.target if isinstance(p.target, (list, tuple)) else [(p.target)];
    if len(targets) != 1 or not isinstance(targets[0], uni.Name) {
        return False;
    }
    sym = targets[0].sym;
    return sym is not None and sym.na_stack_ok;
}

impl NaIRGenPass._codegen_instantiation(
    nd: (uni.FuncCall | uni.Name)
) -> (ir.Value | None) {
    _is_call = isinstance(nd, uni.FuncCall);
    type_name = self._get_name(nd.target if _is_call else nd);
    if type_name is None or type_name not in self.struct_types {
        return None;
    }
    struct_type = self.struct_types[type_name];
    struct_ptr_type = struct_type.as_pointer();

    _vt_struct = type_name in self.clib_vtable_structs;
    _stack_ok = (
        not _vt_struct
        and self._stack_alloc_target_ok(nd)
        and self._arch_is_acyclic(type_name)
        and not self._struct_has_ref_fields(type_name)
        and not self._arch_has_vtable(type_name)
        and not self._arch_is_osp_name(type_name)
        and f"{type_name}.drop" not in self.func_symtab
    );
    _headerless = self._nogc_headerless() and not self._arch_is_osp_name(type_name);
    if _stack_ok and _headerless {
        obj_ptr = self._entry_alloca(struct_type, f"stk.{type_name}");
        _tgt_asgn = nd.find_parent_of_type(uni.Assignment);
        if _tgt_asgn is not None
        and len(_tgt_asgn.target) == 1
        and isinstance(_tgt_asgn.target[0], uni.Name) {
            self.nogc_stack_vars.add(_tgt_asgn.target[0].sym_name);
        }
    } elif _stack_ok {
        _i8 = ir.IntType(8);
        _i32s = ir.IntType(32);
        _i64s = ir.IntType(64);
        _hdr_arr = ir.ArrayType(_i8, HDR_TOTAL);
        _slab_ty = ir.LiteralStructType([_hdr_arr, struct_type]);
        _slab = self._entry_alloca(_slab_ty, f"stk.{type_name}");
        obj_ptr = self.builder.gep(
            _slab, [ir.Constant(_i32s, 0), ir.Constant(_i32s, 1)], name="stk.obj"
        );
        _stk_i8 = self.builder.bitcast(obj_ptr, _i8.as_pointer(), name="stk.i8");
        _stk_rc_slot = self.builder.gep(
            _stk_i8, [ir.Constant(_i64s, HDR_RC_OFF)], name="stk.rc.slot"
        );
        self.builder.store(
            ir.Constant(_i64s, RC_SENTINEL),
            self.builder.bitcast(_stk_rc_slot, _i64s.as_pointer(), name="stk.rc.p")
        );
        _stk_dtor_slot = self.builder.gep(
            _stk_i8, [ir.Constant(_i64s, HDR_DTOR_OFF)], name="stk.dtor.slot"
        );
        self.builder.store(
            ir.Constant(_i64s, 0),
            self.builder.bitcast(_stk_dtor_slot, _i64s.as_pointer(), name="stk.dtor.p")
        );
        _stk_aid_slot = self.builder.gep(
            _stk_i8, [ir.Constant(_i64s, HDR_ALLOC_ID_OFF)], name="stk.aid.slot"
        );
        self.builder.store(
            ir.Constant(_i64s, 0),
            self.builder.bitcast(_stk_aid_slot, _i64s.as_pointer(), name="stk.aid.p")
        );
        if self.rc_set_type_fn is not None {
            self._emit_set_type_tag(self.builder, _stk_i8, type_name);
        }
    } elif _vt_struct {
        obj_ptr = self._clib_alloc_vtable(type_name);
    } elif _headerless {
        null_ptr = ir.Constant(struct_ptr_type, None);
        size_gep = self.builder.gep(
            null_ptr, [ir.Constant(ir.IntType(32), 1)], name="sizeof.gep"
        );
        size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="sizeof");
        _malloc_fn = self._get_or_declare_extern(
            "malloc", ir.IntType(8).as_pointer(), [ir.IntType(64)]
        );
        raw_ptr = self.builder.call(_malloc_fn, [size], name="raw.ptr");
        obj_ptr = self.builder.bitcast(raw_ptr, struct_ptr_type, name="obj.ptr");
        self._emit_struct_drop_fn(type_name);
    } elif self.region_stack and not self._arch_is_walker_name(type_name) {
        null_ptr = ir.Constant(struct_ptr_type, None);
        size_gep = self.builder.gep(
            null_ptr, [ir.Constant(ir.IntType(32), 1)], name="sizeof.gep"
        );
        size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="sizeof");
        raw_ptr = self._region_alloc(size, name="region.obj");
        obj_ptr = self.builder.bitcast(raw_ptr, struct_ptr_type, name="obj.ptr");
        if self.rc_set_type_fn is not None {
            _obj_i8_r = self.builder.bitcast(
                obj_ptr, ir.IntType(8).as_pointer(), name="obj.i8.rtag"
            );
            self._emit_set_type_tag(self.builder, _obj_i8_r, type_name);
        }
        self._region_log_dtor_if_needed(raw_ptr, type_name);
    } elif (
        self._arch_is_osp_name(type_name)
        and not self._arch_is_walker_name(type_name)
        and "here" in self.local_vars
    ) {
        self._emit_arena_helpers();
        null_ptr = ir.Constant(struct_ptr_type, None);
        size_gep = self.builder.gep(
            null_ptr, [ir.Constant(ir.IntType(32), 1)], name="sizeof.gep"
        );
        size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="sizeof");
        _i8p_g = ir.IntType(8).as_pointer();
        _here_val = self.builder.load(self.local_vars["here"], name="growth.here");
        _here_i8 = self.builder.bitcast(_here_val, _i8p_g, name="growth.here.i8");
        _gdtor = self._emit_struct_drop_fields_fn(type_name);
        _gdtor_i8 = (
            self.builder.bitcast(_gdtor, _i8p_g, name="growth.dtor")
                if _gdtor is not None
                else ir.Constant(_i8p_g, None)
        );
        raw_ptr = self.builder.call(
            self.osp_anchor_alloc_fn, [_here_i8, size, _gdtor_i8], name="growth.obj"
        );
        obj_ptr = self.builder.bitcast(raw_ptr, struct_ptr_type, name="obj.ptr");
        if self.rc_set_type_fn is not None {
            _obj_i8_g = self.builder.bitcast(
                obj_ptr, ir.IntType(8).as_pointer(), name="obj.i8.gtag"
            );
            self._emit_set_type_tag(self.builder, _obj_i8_g, type_name);
        }
    } else {
        null_ptr = ir.Constant(struct_ptr_type, None);
        size_gep = self.builder.gep(
            null_ptr, [ir.Constant(ir.IntType(32), 1)], name="sizeof.gep"
        );
        size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="sizeof");
        _inst_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
            if nd.loc
            else 0}";
        raw_ptr = self._rc_call_with_ctx(
            self.rc_alloc_fn, [size], op="new", loc=_inst_loc, name="raw.ptr"
        );
        obj_ptr = self.builder.bitcast(raw_ptr, struct_ptr_type, name="obj.ptr");
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
        self._emit_trace_fn(type_name);
        _trace_fn_s = self.struct_trace_fns.get(type_name);
        self._require_trace_fn(
            type_name,
            (
                self._struct_has_ref_fields(type_name)
                and not self._arch_is_acyclic(type_name)
            ),
            _trace_fn_s is not None
        );
        if self.rc_set_type_fn is not None {
            _obj_i8 = self.builder.bitcast(
                obj_ptr, ir.IntType(8).as_pointer(), name="obj.i8.tag"
            );
            self._emit_set_type_tag(self.builder, _obj_i8, type_name);
        }
    }

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

    _tt_idx = self.osp_type_tag_field.get(type_name);
    if _tt_idx is not None {
        _tt_slot = self.builder.gep(
            obj_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), _tt_idx)],
            name="type_tag.slot"
        );

        _tt_val = stable_osp_tag(type_name);
        self.builder.store(ir.Constant(ir.IntType(64), _tt_val), _tt_slot);

        if not self._arch_is_walker_name(type_name) {
            self._osp_make_immortal(obj_ptr);
        }
    }

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

    field_indices = self.struct_field_indices.get(type_name, {});
    field_types = self.struct_field_types.get(type_name, {});
    field_defaults = self.struct_field_defaults.get(type_name, {});
    opaque_fields = self.struct_field_opaque.get(type_name, set());

    set_fields: set[str] = set();
    params = (nd.params or []) if _is_call else [];
    for param in params {
        if isinstance(param, uni.KWPair) {
            key_name = param.key.sym_name if param.key else None;
            if key_name is None or key_name not in field_indices {
                continue;
            }

            if key_name in opaque_fields {
                continue;
            }
            val = self._codegen_expr(param.value);
            if val is None {
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

            _is_clib_cb = (
                type_name in self.clib_vtable_structs
                and isinstance(ftype, ir.PointerType)
                and isinstance(ftype.pointee, ir.FunctionType)
            );
            if _is_clib_cb {
                val = self._clib_coerce_callback(val, ftype);
            } else {
                val = self._coerce_type(val, ftype);
            }

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

    for (fname, default_expr) in field_defaults.items() {
        if fname in opaque_fields {
            continue;
        }
        if fname not in set_fields {
            val = self._codegen_expr(default_expr);

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

    init_fn: (ir.Function | None) = None;
    for candidate in [f"{type_name}.init", f"{type_name}.__init__"] {
        if candidate in self.method_funcs {
            init_fn = self.method_funcs[candidate];
            break;
        }
    }
    if init_fn is not None {
        init_args: list[ir.Value] = [obj_ptr];
        init_sig = self._arch_init_sig_of(type_name) if _is_call else None;
        if init_sig is not None {
            _init_pos: list = [];
            _init_kw: dict = {};
            for param in params {
                if isinstance(param, uni.KWPair) {
                    _k = param.key.sym_name if param.key is not None else None;
                    if _k is not None {
                        _init_kw[_k] = param.value;
                    }
                } else {
                    _init_pos.append(param);
                }
            }
            _sig_params = init_sig.get_parameters();
            for (pix, sp) in enumerate(_sig_params) {
                _slot = 1 + pix;
                _expected = init_fn.args[_slot].type
                    if _slot < len(init_fn.args)
                    else ir.IntType(64);
                _chosen: (uni.Expr | None) = None;
                if pix < len(_init_pos) {
                    _chosen = _init_pos[pix];
                } elif sp.name.sym_name in _init_kw {
                    _chosen = _init_kw[sp.name.sym_name];
                } elif sp.value is not None {
                    _chosen = sp.value;
                }
                _val = self._codegen_expr(_chosen) if _chosen is not None else None;
                if _val is not None {
                    init_args.append(_val);
                } else {
                    init_args.append(self._default_arg_fallback(_expected));
                }
            }
            for pix in range(len(_sig_params), len(_init_pos)) {
                _extra = self._codegen_expr(_init_pos[pix]);
                if _extra is not None {
                    init_args.append(_extra);
                }
            }
        } else {
            for param in params {
                if not isinstance(param, uni.KWPair) {
                    val = self._codegen_expr(param);
                    if val is not None {
                        init_args.append(val);
                    }
                }
            }
            _fill = len(init_args);
            while _fill < len(init_fn.args) {
                init_args.append(self._default_arg_fallback(init_fn.args[_fill].type));
                _fill += 1;
            }
        }

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

    for pname in [f"{type_name}.__post_init__", f"{type_name}.postinit"] {
        if pname in self.method_funcs {
            postinit_fn = self.method_funcs[pname];
            self.builder.call(postinit_fn, [obj_ptr]);
            break;
        }
    }
    return obj_ptr;
}

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

    if (
        target_name is not None
        and target_name in self.struct_types
        and target_name not in self.local_vars
    ) {
        _sfull: (str | None) = None;
        for _cn in self._mro_of(target_name) {
            _cand = f"{_cn}.{method_name}";
            if _cand in self.static_methods {
                _sfull = _cand;
                break;
            }
        }
        if _sfull is not None {
            _sfunc = self.method_funcs[_sfull];
            _sargs: list[ir.Value] = [];
            for (_i, _p) in enumerate(nd.params or []) {
                _pv = self._codegen_expr(_p);
                if _pv is None {
                    return None;
                }
                if _i < len(_sfunc.args) {
                    _pv = self._coerce_type(_pv, _sfunc.args[_i].type);
                }
                _sargs.append(_pv);
            }
            _sr = self.builder.call(_sfunc, _sargs, name=f"scall.{method_name}");
            if isinstance(_sfunc.return_value.type, ir.VoidType) {
                return None;
            }
            return _sr;
        }
    }

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

    if (
        target_name == "time"
        and self?._native_stdlib_modules
        and "time" in self._native_stdlib_modules
        and method_name in NATIVE_TIME_FUNCS
    ) {
        return self._emit_time_call(method_name, nd);
    }

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

    if (
        target_name == "os"
        and self?._native_stdlib_modules
        and "os" in self._native_stdlib_modules
        and method_name in NATIVE_OS_FUNCS
    ) {
        return self._emit_os_call(method_name, nd);
    }

    if (
        target_name == "random"
        and self?._native_stdlib_modules
        and "random" in self._native_stdlib_modules
        and method_name in NATIVE_RANDOM_FUNCS
    ) {
        return self._emit_random_call(method_name, nd);
    }

    if (
        target_name == "struct"
        and self?._native_stdlib_modules
        and "struct" in self._native_stdlib_modules
        and method_name in NATIVE_STRUCT_FUNCS
    ) {
        return self._emit_struct_call(method_name, nd);
    }

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

    list_spec = self._list_spec_of(trailer.target);
    if list_spec is not None {
        list_val = self._codegen_expr(trailer.target);
        if list_val is not None {
            _shape_spec = self._infer_list_elem_type(list_val);
            elem_type_name = _shape_spec if _shape_spec is not None else list_spec;
            arg_vals = self._codegen_call_args(nd);

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
                "list",
                method_name,
                list_val,
                arg_vals,
                elem_type_name,
                kwargs=self._split_call_kwargs(nd),
                kw_node=nd
            );

            self._clear_rc_ctx();
            if result is not None {
                return result;
            }
        }
    }

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

    dict_type_key: (str | None) = self._dict_key_of(trailer.target);
    if dict_type_key is None and target_name is not None {
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

    if method_name in self._primitive_method_names("bytes") {
        bytes_val = self._codegen_expr(trailer.target);
        if bytes_val is not None and self._is_bytes_value(bytes_val) {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "bytes", method_name, bytes_val, arg_vals, ""
            );
            if result is not None {
                return result;
            }
        }
    }

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

    type_name: (str | None) = self._struct_name_of(trailer.target);
    obj_val: (ir.Value | None) = None;
    if type_name is None {
        obj_val = self._codegen_expr(trailer.target);
        if obj_val is not None {
            type_name = self._infer_type_name(obj_val);

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

    func = self._resolve_method(type_name, method_name);
    _demoted = False;
    if func is None {
        if f"{type_name}.{method_name}" in self._native_skipped_methods {
            _demoted = True;
        } else {
            _owner = self._resolve_method_owner(type_name, method_name);
            if _owner is not None
            and f"{_owner}.{method_name}" in self._native_skipped_methods {
                _demoted = True;
            }
        }
    }
    if func is None {
        if _demoted {
            self.emit(
                E5092,
                node_override=nd,
                kind="method",
                name=f"{type_name}.{method_name}",
                help_text=(
                    f"'{method_name}' has no native lowering and was demoted to "
                    f"its Python implementation; it cannot be called from native "
                    f"code. Call it from a Python/@sv context instead."
                )
            );
        }
        return None;
    }

    if obj_val is None {
        obj_val = self._codegen_expr(trailer.target);
    }
    if obj_val is None {
        return None;
    }

    if isinstance(obj_val.type, ir.PointerType) {
        null_ptr = ir.Constant(obj_val.type, None);
        is_null = self.builder.icmp_unsigned(
            "==", obj_val, null_ptr, name="null.method.chk"
        );
        self._emit_runtime_raise(
            is_null, "AttributeError", "'NoneType' object has no attribute"
        );
    }

    args: list[ir.Value] = [obj_val] + self._codegen_bound_args(
        nd, func, self_offset=1
    );

    if self._arch_has_vtable(type_name) {
        result = self._codegen_virtual_call(obj_val, method_name, args, type_name);
        if result is not None {
            if isinstance(func.return_value.type, ir.VoidType) {
                return ir.Constant(ir.IntType(64), 0);
            }

            return result;
        }
    }

    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(args) {
        if i < len(func.args) {
            coerced.append(self._coerce_type(arg, func.args[i].type));
        } else {
            coerced.append(arg);
        }
    }
    result = self.builder.call(func, coerced, name=f"call.{method_name}");

    if isinstance(func.return_value.type, ir.VoidType) {
        return ir.Constant(ir.IntType(64), 0);
    }

    return result;
}

impl NaIRGenPass._emit_obj_str(val: ir.Value) -> (ir.Value | None) {
    type_name = self._infer_type_name(val);
    if type_name is None {
        return None;
    }

    func = self._resolve_method(type_name, "__str__");

    i8p = ir.IntType(8).as_pointer();
    is_null = self.builder.icmp_unsigned(
        "==", val, ir.Constant(val.type, None), name="objstr.isnull"
    );
    fn = self.builder.basic_block.function;
    null_bb = fn.append_basic_block(name="objstr.null");
    live_bb = fn.append_basic_block(name="objstr.live");
    cont_bb = fn.append_basic_block(name="objstr.cont");
    self.builder.cbranch(is_null, null_bb, live_bb);

    self.builder.position_at_end(null_bb);
    none_s = self._make_global_string("None", name_prefix=".objstr.none");
    null_end = self.builder.basic_block;
    self.builder.branch(cont_bb);

    self.builder.position_at_end(live_bb);
    if func is None {
        live_res = self._emit_default_obj_repr(val, type_name);
    } else {
        was_owned = self._is_owned(val);
        if was_owned {
            val.is_owned = False;
        }
        result = None;
        if self._arch_has_vtable(type_name) {
            result = self._codegen_virtual_call(val, "__str__", [val], type_name);
        }
        if result is None {
            coerced = [self._coerce_type(val, func.args[0].type)];
            result = self.builder.call(func, coerced, name="call.__str__");
        }
        if was_owned {
            val.is_owned = True;
        }
        live_res = result;
    }
    live_res = self._coerce_type(live_res, i8p);
    live_end = self.builder.basic_block;
    self.builder.branch(cont_bb);

    self.builder.position_at_end(cont_bb);
    phi = self.builder.phi(i8p, name="objstr.result");
    phi.add_incoming(none_s, null_end);
    phi.add_incoming(live_res, live_end);

    return self._mark_owned(phi);
}

impl NaIRGenPass._emit_default_obj_repr(val: ir.Value, type_name: str) -> ir.Value {
    b = self.builder;
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);

    buf_len = len(type_name) + 48;
    buf = self._rc_call_with_ctx(
        self.rc_alloc_fn,
        [ir.Constant(i64, buf_len)],
        op="obj_repr",
        loc="",
        name="obj.repr.buf"
    );
    self._emit_set_type_tag(b, buf, "str");
    snprintf = self._get_or_declare_extern(
        "snprintf", ir.IntType(32), [i8p, i64, i8p], var_arg=True
    );
    fmt = self._make_global_string(
        "<%s object at 0x%llx>", name_prefix=".obj.repr.fmt"
    );
    name_g = self._make_global_string(type_name, name_prefix=".obj.repr.name");
    addr = b.ptrtoint(val, i64, name="obj.repr.addr");
    b.call(
        snprintf,
        [buf, ir.Constant(i64, buf_len), fmt, name_g, addr],
        name="obj.repr.snprintf"
    );
    return self._mark_owned(buf);
}

impl NaIRGenPass._codegen_field_access(
    obj_val: ir.Value, field_name: str, type_name: str
) -> (ir.Value | None) {
    field_indices = self.struct_field_indices.get(type_name);
    if field_indices is None or field_name not in field_indices {
        return None;
    }

    if isinstance(obj_val.type, ir.IntType) and (type_name in self.struct_types) {
        obj_val = self.builder.inttoptr(
            obj_val, self.struct_types[type_name].as_pointer(), name="osp.handle.ptr"
        );
    }

    target_struct = self.struct_types.get(type_name);
    if target_struct is not None
    and isinstance(obj_val.type, ir.PointerType)
    and obj_val.type.pointee is not target_struct {
        obj_val = self.builder.bitcast(
            obj_val, target_struct.as_pointer(), name=f"narrow.{type_name}"
        );
    }

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

impl NaIRGenPass._codegen_field_aug_assign(
    target: uni.AtomTrailer, rhs: ir.Value, aug_op: str
) -> (ir.Value | None) {
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

    current = self._codegen_field_access(obj_val, field_name, type_name);
    if current is None {
        return None;
    }

    scalar = self._apply_scalar_aug_op(current, rhs, aug_op);
    if scalar is not None {
        return scalar;
    }

    coerced = self._coerce_type(rhs, current.type);

    if aug_op == "+=" and isinstance(current.type, ir.PointerType) {
        result = self._emit_binary_op(Tok.PLUS, current, coerced);
        return result if result is not None else current;
    }

    return coerced;
}

impl NaIRGenPass._codegen_field_assign(
    target: uni.AtomTrailer, value: ir.Value
) -> None {
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
                E5092,
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
