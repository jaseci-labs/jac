impl NaIRGenPass.postinit -> None {
    import os as _ni_os;

    self._rc_debug_codegen = bool(_ni_os.environ.get("JAC_RC_DEBUG_CODEGEN", ""));
    _ni_src: str = self.ir_in.loc.mod_path if self.ir_in.loc else "";
    _ni_mod_name: str = _ni_os.path.basename(_ni_src) if _ni_src else "jac_native";
    self.llvm_module = ir.Module(name=_ni_mod_name, context=ir.Context());
    import jaclang.compiler.passes.native.llvm.binding as _llvm_bind;

    _ni_target_ovr = _ni_os.environ.get("JAC_NATIVE_TARGET", "");
    if _ni_target_ovr {
        _llvm_bind.initialize_all_targets();
        _llvm_bind.initialize_all_asmprinters();
        _target = _llvm_bind.Target.from_triple(_ni_target_ovr);
    } else {
        _llvm_bind.initialize_native_target();
        _target = _llvm_bind.Target.from_default_triple();
    }

    _tm = _target.create_target_machine(codemodel="large");
    self.llvm_module.data_layout = str(_tm.target_data);
    self.llvm_module.triple = _tm.triple;

    if _ni_src and _ni_os.environ.get("JAC_NATIVE_DEBUG", "") {
        _ni_src_dir: str = _ni_os.path.dirname(_ni_os.path.abspath(_ni_src));
        try {
            self.di_file = self.llvm_module.add_debug_info(
                "DIFile", {"filename": _ni_mod_name, "directory": _ni_src_dir}
            );
            self.di_cu = self.llvm_module.add_debug_info(
                "DICompileUnit",
                {
                    "language": ir.DIToken("DW_LANG_C"),
                    "file": self.di_file,
                    "producer": "jac native compiler",
                    "runtimeVersion": 0,
                    "isOptimized": False,
                    "emissionKind": ir.DIToken("FullDebug"),

                },
                is_distinct=True
            );
        } except Exception {
            self.di_file = None;
            self.di_cu = None;
        }
    }

    _spec_map: dict[str, ir.Type] = {
        "i8": ir.IntType(8),
        "i16": ir.IntType(16),
        "i32": ir.IntType(32),
        "i64": ir.IntType(64),
        "f32": ir.FloatType(),
        "f64": ir.DoubleType(),
        "i1": ir.IntType(1),
        "i8*": ir.IntType(8).as_pointer()
    };
    self.type_map = {};
    try {
        import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
        for (_name, _spec) in JAC_TYPE_REGISTRY.na_type_entries() {
            self.type_map[_name] = _spec_map[_spec];
        }
    } except ImportError {
        self.type_map["int"] = _spec_map["i64"];
        self.type_map["float"] = _spec_map["f64"];
        self.type_map["bool"] = _spec_map["i1"];
        self.type_map["str"] = _spec_map["i8*"];
    }

    self.type_map["LiteralString"] = self.type_map.get("str", _spec_map["i8*"]);

    self.complex_struct_type = self.llvm_module.context.get_identified_type(
        "JacComplex"
    );
    self.complex_struct_type.set_body(ir.DoubleType(), ir.DoubleType());

    self.range_struct_type = self.llvm_module.context.get_identified_type("JacRange");
    self.range_struct_type.set_body(ir.IntType(64), ir.IntType(64), ir.IntType(64));

    self.slice_struct_type = self.llvm_module.context.get_identified_type("JacSlice");
    self.slice_struct_type.set_body(ir.IntType(64), ir.IntType(64), ir.IntType(64));

    self.jacval_type = self.llvm_module.context.get_identified_type("JacVal");
    self.jacval_type.set_body(ir.IntType(8), ir.IntType(64));

    super.postinit();
}

impl NaIRGenPass.transform(ir_in: uni.Module) -> uni.Module {
    if (self.prog._auto_promote_native and self.ir_in.gen.native_compat) {
        mod_path = self.ir_in.loc.mod_path if self.ir_in.loc else "";
        main_target = self.prog._auto_promote_target;
        import from jaclang.jac0core.ext_registry { is_native_module, is_annex }
        if (
            mod_path == main_target
            and not is_native_module(mod_path)
            and not is_annex(mod_path)
        ) {
            import from jaclang.jac0core.compiler { _coerce_native_module }
            _coerce_native_module(self.ir_in);
        }
    }

    import from jaclang.compiler.passes.main.capability_check_pass {
        native_capability_violations
    }
    _viols = native_capability_violations(self.ir_in);
    for (_vnode, _vkind, _vname, _vhelp) in _viols {
        self.emit(
            E5090, node_override=_vnode, kind=_vkind, name=_vname, help_text=_vhelp
        );
    }
    if _viols {
        return self.ir_in;
    }

    self._emit_rc_helpers();

    self._process_clib_imports(self.ir_in);

    self._register_enums(self.ir_in);

    self._forward_declare_archetype_names(self.ir_in);

    self._register_imported_struct_types();
    self._register_globals(self.ir_in);

    self._register_archetypes(self.ir_in);

    _entry_nodes: list = [];
    for stmt in ModuleCodegenPass.iter_context_stmts(self.ir_in, CodeContext.NATIVE) {
        if (
            isinstance(stmt, uni.Ability)
            and stmt.signature is not None
            and isinstance(stmt.signature, uni.FuncSignature)
        ) {
            self._codegen_ability(stmt);
        } elif isinstance(stmt, uni.ModuleCode) {
            _entry_nodes.append(stmt);
        } elif isinstance(stmt, uni.Test) {
            self._codegen_test(stmt);
        }
    }
    self._codegen_entry(_entry_nodes);
    self._finalize_trace_lookup();

    if self.has_native_code {
        if self.errors_had {
            return self.ir_in;
        }
        if "__jac_glob_init" not in self.func_symtab {
            self._emit_glob_init_func();
        }
        self.ir_in.gen.llvm_ir = self.llvm_module;

        import os;
        if os.environ.get("JAC_RC_STATS", "") {
            _rc_total = self.rc_retains_emitted + self.rc_releases_emitted;
            _rc_known = _rc_total + self.rc_ops_elided;
            _rc_pct = (100.0 * self.rc_ops_elided / _rc_known) if _rc_known else 0.0;
            import sys;
            sys.stderr.write(
                f"rc-stats [{os.path.basename(self.ir_in.loc.mod_path)}] "
                f"gc={self._gc_mode()} retains={self.rc_retains_emitted} "
                f"releases={self.rc_releases_emitted} "
                f"elided={self.rc_ops_elided} coverage={_rc_pct:.1f}%\n"
            );
        }
        _ir_dump_path = os.environ.get("JAC_DUMP_IR", "");
        if _ir_dump_path {
            with open(_ir_dump_path, "w") as _f {
                _f.write(str(self.llvm_module));
            }
        }

        self._export_native_layout();
    }
    return self.ir_in;
}

impl NaIRGenPass._llvm_type_str(ty: ir.Type) -> str {
    if isinstance(ty, ir.IntType) {
        if ty.width == 64 {
            return "i64";
        }
        if ty.width == 32 {
            return "i32";
        }
        if ty.width == 8 {
            return "i8";
        }
        if ty.width == 1 {
            return "i1";
        }
        return f"i{ty.width}";
    }
    if isinstance(ty, ir.DoubleType) {
        return "f64";
    }
    if isinstance(ty, ir.FloatType) {
        return "f32";
    }
    if isinstance(ty, ir.VoidType) {
        return "void";
    }
    if isinstance(ty, ir.PointerType) {
        if ty?.pointee {
            if isinstance(ty.pointee, ir.IntType) and ty.pointee.width == 8 {
                return "i8*";
            }

            for (sname, stype) in self.struct_types.items() {
                if ty.pointee == stype {
                    return f"{sname}*";
                }
            }

            for (ename, ltype) in self.list_types.items() {
                if ty.pointee == ltype {
                    return f"List.{ename}*";
                }
            }

            for (tkey, ttype) in self.tuple_types.items() {
                if ty.pointee == ttype {
                    return f"Tuple*";
                }
            }
        }
        return "ptr";
    }
    return "i64";
}

impl NaIRGenPass._export_native_layout -> None {
    import from jaclang.jac0core.codeinfo {
        NativeModuleLayout,
        NativeStructLayout,
        NativeFieldInfo,
        NativeEnumLayout,
        NativeFuncLayout,
        NativeTupleLayout,
        NativeTestLayout
    }
    layout = NativeModuleLayout();

    for (arch_name, field_indices) in self.struct_field_indices.items() {
        field_types = self.struct_field_types.get(arch_name, {});
        fields: list[NativeFieldInfo] = [];
        enum_types = self.struct_field_enum_type.get(arch_name, {});
        for (fname, idx) in sorted(field_indices.items(), key=lambda (x) { x[1]; }) {
            ftype = field_types.get(fname);
            llvm_t = self._llvm_type_str(ftype) if ftype is not None else "i64";

            is_fn_ptr = False;
            fn_param_types: (list[str] | None) = None;
            fn_ret_type: (str | None) = None;
            if (
                ftype is not None
                and isinstance(ftype, ir.PointerType)
                and isinstance(ftype.pointee, ir.FunctionType)
            ) {
                is_fn_ptr = True;
                fn_param_types = [self._llvm_type_str(a) for a in ftype.pointee.args];
                fn_ret_type = self._llvm_type_str(ftype.pointee.return_type);
            }
            fields.append(
                NativeFieldInfo(
                    name=fname,
                    llvm_type=llvm_t,
                    index=idx,
                    enum_type=enum_types.get(fname),
                    is_func_ptr=is_fn_ptr,
                    func_param_types=fn_param_types,
                    func_ret_type=fn_ret_type
                )
            );
        }
        layout.structs[arch_name] = NativeStructLayout(
            name=arch_name, fields=fields, has_vtable=self._arch_has_vtable(arch_name)
        );
    }

    for (enum_name, entries) in self.enum_string_values.items() {
        layout.enums[enum_name] = NativeEnumLayout(
            name=enum_name, is_string_valued=True, members=list(entries)
        );
    }

    for (tkey, ttype) in self.tuple_types.items() {
        elem_types = [self._llvm_type_str(e) for e in ttype.elements];
        layout.tuples[tkey] = NativeTupleLayout(
            key=tkey,
            element_types=elem_types,
            element_struct_hints=[None] * len(elem_types)
        );
    }

    method_names = set(self.method_funcs.keys());
    for (fname, func) in self.func_symtab.items() {
        if fname.startswith("__") or fname == "jac_entry" or fname in method_names {
            continue;
        }
        param_types = [self._llvm_type_str(a) for a in func.function_type.args];
        param_names: list[str] = [a.name for a in func.args];
        ret_type = self._llvm_type_str(func.function_type.return_type);
        ret_struct: (str | None) = None;
        ret_tuple: (NativeTupleLayout | None) = None;
        if isinstance(func.function_type.return_type, ir.PointerType) {
            for (sn, st) in self.struct_types.items() {
                if func.function_type.return_type.pointee == st {
                    ret_struct = sn;
                    break;
                }
            }

            if ret_type.startswith("Tuple") {
                for (tkey, ttype) in self.tuple_types.items() {
                    if func.function_type.return_type.pointee == ttype {
                        ret_tuple = layout.tuples.get(tkey);
                        if ret_tuple is not None {
                            hints = self.func_ret_tuple_hints.get(fname);
                            if hints and len(hints) == len(ret_tuple.element_types) {
                                ret_tuple = NativeTupleLayout(
                                    key=ret_tuple.key,
                                    element_types=ret_tuple.element_types,
                                    element_struct_hints=hints
                                );
                                layout.tuples[tkey] = ret_tuple;
                            }
                        }
                        break;
                    }
                }
            }
        }

        ret_enum: (str | None) = None;
        if ret_type == "i64" {
            _rname = self.func_ret_ann_name.get(fname);
            if _rname is not None and _rname in self.enum_types {
                ret_enum = _rname;
            }
        }
        layout.functions[fname] = NativeFuncLayout(
            name=fname,
            param_types=param_types,
            param_names=param_names,
            ret_type=ret_type,
            ret_struct_name=ret_struct,
            ret_tuple_layout=ret_tuple,
            ret_enum_type=ret_enum
        );
    }

    for (mname, func) in self.method_funcs.items() {
        param_types = [self._llvm_type_str(a) for a in func.function_type.args];
        param_names = [a.name for a in func.args];
        ret_type = self._llvm_type_str(func.function_type.return_type);
        ret_struct: (str | None) = None;
        if isinstance(func.function_type.return_type, ir.PointerType) {
            for (sn, st) in self.struct_types.items() {
                if func.function_type.return_type.pointee == st {
                    ret_struct = sn;
                    break;
                }
            }
        }
        layout.methods[mname] = NativeFuncLayout(
            name=mname,
            param_types=param_types,
            param_names=param_names,
            ret_type=ret_type,
            ret_struct_name=ret_struct
        );
    }

    for (ename, ltype) in self.list_types.items() {
        layout.list_elem_types[f"List.{ename}"] = ename;
    }

    for (tname, tsymbol, tdesc, tline) in self.native_tests {
        layout.tests.append(
            NativeTestLayout(name=tname, symbol=tsymbol, description=tdesc, line=tline)
        );
    }
    self.ir_in.gen.native_layout = layout;
}

impl NaIRGenPass._extract_tuple_struct_hints(type_node: object) -> list {
    hints: list = [];
    if not isinstance(type_node, uni.Expr) {
        return hints;
    }

    if type_node?.right and type_node.right?.slices {
        slices = type_node.right.slices or [];
        for s in slices {
            inner = s.start if s?.start else s;

            if isinstance(inner, uni.TupleVal) {
                for tv in inner.values {
                    hints.append(self._extract_elem_struct_hint(tv));
                }
            } else {
                hints.append(self._extract_elem_struct_hint(inner));
            }
        }
    }
    return hints;
}

impl NaIRGenPass._extract_elem_struct_hint(type_node: object) -> (str | None) {
    if not isinstance(type_node, uni.Expr) {
        return None;
    }

    name = self._get_name(type_node);
    if name is None and isinstance(type_node, uni.AtomTrailer) {
        if type_node.kid {
            name = self._get_name(type_node.kid[0]);
        }
    }

    if name == "list" and type_node?.right and type_node.right?.slices {
        inner_slices = type_node.right.slices or [];
        for is_ in inner_slices {
            inner_type = is_.start if is_?.start else is_;
            inner_name = self._get_name(inner_type);
            if inner_name is not None and inner_name in self.struct_types {
                return inner_name;
            }
        }
    }

    if name is not None and name in self.struct_types {
        return name;
    }
    return None;
}

impl NaIRGenPass._register_imported_struct_types -> None {
    import os;
    import from jaclang.jac0core.codeinfo {
        resolve_native_module,
        is_bundled_native_module
    }

    processed_modules: set[str] = set();
    imported_mods: list = [];
    manifest = self.ir_in.gen.interop_manifest;

    entry_base = os.path.dirname(os.path.abspath(self.ir_in.loc.mod_path))
        if (self.ir_in?.loc)
        else os.getcwd();

    _has_native_code: bool = any(
        True
        for _s in ModuleCodegenPass.iter_context_stmts(self.ir_in, CodeContext.NATIVE)
    );
    wq: list = [];
    for imp in [
        s
        for s in ModuleCodegenPass.iter_context_stmts(self.ir_in)
        if isinstance(s, uni.Import)
    ] {
        mod_name = self._extract_import_module_name(imp);
        if not mod_name {
            continue;
        }
        if (not imp.from_loc)
        and ((not _has_native_code) or (not is_bundled_native_module(mod_name))) {
            continue;
        }
        wq.append((mod_name, entry_base));
    }

    qi = 0;
    while qi < len(wq) {
        (mod_name, cur_base) = wq[qi];
        qi += 1;
        (src_mod_str, full_path) = resolve_native_module(mod_name, cur_base);
        if src_mod_str is None or full_path is None {
            continue;
        }
        abs_key = os.path.abspath(full_path);
        if abs_key in processed_modules {
            continue;
        }

        imported_mod = self.prog.mod.hub.get(full_path);
        if imported_mod is None {
            imported_mod = self.prog.mod.hub.get(abs_key);
        }

        if imported_mod is None and os.path.isfile(full_path) {
            _saved_opts = self.prog._compile_options;
            try {
                imported_mod = self.prog.compile(
                    full_path, no_cgen=True, symtab_ir_only=True
                );
            } except Exception {
                imported_mod = None;
            } finally {
                self.prog._compile_options = _saved_opts;
            }
        }
        if imported_mod is None {
            continue;
        }
        processed_modules.add(abs_key);
        imported_mods.append((src_mod_str, imported_mod));

        sub_base = os.path.dirname(os.path.abspath(full_path));
        for sub_imp in [
            s
            for s in ModuleCodegenPass.iter_context_stmts(imported_mod)
            if isinstance(s, uni.Import)
        ] {
            sub_name = self._extract_import_module_name(sub_imp);
            if sub_name {
                wq.append((sub_name, sub_base));
            }
        }
    }

    self._foreign_modules = [m for (_s, m) in imported_mods];

    for (src_mod_str, _) in imported_mods {
        if src_mod_str not in manifest.native_transitive_sources {
            manifest.native_transitive_sources.append(src_mod_str);
        }
    }

    for (_, imported_mod) in imported_mods {
        self._process_clib_imports(imported_mod);
    }

    for (_, imported_mod) in imported_mods {
        self._walk_imported_module_type_names(imported_mod);
    }

    for (_, imported_mod) in imported_mods {
        self._register_imported_hierarchy(imported_mod);
    }

    for (_, imported_mod) in imported_mods {
        self._walk_imported_module_types(imported_mod);
    }

    for (_, imported_mod) in imported_mods {
        self._walk_imported_module_abilities(imported_mod);
    }
}

impl NaIRGenPass._extract_import_module_name(imp: uni.Import) -> (str | None) {
    if imp.clib_decls {
        return None;
    }
    if not imp.from_loc or not isinstance(imp.from_loc, uni.ModulePath) {
        if imp.items {
            for it in imp.items {
                if isinstance(it, uni.ModulePath) and it.path {
                    return '.'.join(getattr(p, 'value', str(p)) for p in it.path);
                }
            }
        }
        return None;
    }

    if imp.clib_decls {
        return None;
    }
    if imp.from_loc.path and isinstance(imp.from_loc.path[0], uni.String) {
        return None;
    }
    mod_name = imp.from_loc?.dot_path_str;
    if not mod_name and imp.from_loc?.path and imp.from_loc.path {
        mod_name = '.'.join(getattr(p, 'value', str(p)) for p in imp.from_loc.path);
    }
    return mod_name;
}

impl NaIRGenPass._walk_imported_module_type_names(imported_mod: uni.Module) -> None {
    for stmt in ModuleCodegenPass.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
        ) {
            continue;
        }
        if isinstance(stmt, uni.Archetype) {
            aname = stmt.name.value if stmt.name else None;
            if aname is not None and aname not in self.struct_types {
                struct_type = self.llvm_module.context.get_identified_type(aname);
                self.struct_types[aname] = struct_type;
            }
        }
    }
}

impl NaIRGenPass._walk_imported_module_types(imported_mod: uni.Module) -> None {
    for stmt in ModuleCodegenPass.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
        ) {
            continue;
        }
        if isinstance(stmt, uni.Archetype) {
            self._register_imported_archetype(stmt);

            _aname = stmt.name.value if stmt.name else None;
            if (_aname is not None) and (stmt.arch_kind is not None) {
                self.imported_osp_archs[_aname] = (stmt.arch_kind, imported_mod.name);
            }
        } elif isinstance(stmt, uni.Enum) {
            self._codegen_enum(stmt);
        } elif isinstance(stmt, uni.GlobalVars) {
            _imp_path = imported_mod.loc.mod_path if imported_mod?.loc else "";
            self._register_imported_globals(stmt, _imp_path);
        }
    }
}

impl NaIRGenPass._walk_imported_module_abilities(imported_mod: uni.Module) -> None {
    for stmt in ModuleCodegenPass.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
        ) {
            continue;
        }
        if isinstance(stmt, uni.Archetype) {
            self._forward_declare_archetype_methods(stmt);
        }
    }

    for stmt in ModuleCodegenPass.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
        ) {
            continue;
        }
        if isinstance(stmt, uni.Ability) {
            self._forward_declare_imported_ability(stmt);
        }
    }
}

impl NaIRGenPass._forward_declare_archetype_methods(arch: uni.Archetype) -> None {
    aname = arch.name.value if arch.name else None;
    if aname is None or arch.body is None {
        return;
    }
    for stmt in arch.body {
        if isinstance(stmt, uni.Ability) {
            if stmt.signature is not None
            and isinstance(stmt.signature, uni.FuncSignature) {
                self._forward_declare_method(aname, stmt);
            } elif isinstance(stmt.signature, uni.EventSignature)
            and (arch.arch_kind is not None) {
                self._forward_declare_event_method(aname, stmt);
                self._emit_osp_thunk(aname, stmt);
            }
        }
    }
}

impl NaIRGenPass._register_imported_hierarchy(imported_mod: uni.Module) -> None {
    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }
    _imp_reg = get_layout_registry(imported_mod, self.prog);
    _cons_reg = get_layout_registry(self.ir_in, self.prog);
    for (_name, _parents) in _imp_reg.class_parents.items() {
        if _name not in _cons_reg.class_parents {
            _cons_reg.class_parents[_name] = _parents;
        }
    }
    for (_name, _mro) in _imp_reg.mro_order.items() {
        if _name not in _cons_reg.mro_order {
            _cons_reg.mro_order[_name] = _mro;
        }
    }

    for stmt in ModuleCodegenPass.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
        ) {
            continue;
        }
        if isinstance(stmt, uni.Archetype) {
            _aname = stmt.name.value if stmt.name else None;
            if (_aname is not None) and (_aname not in self.arch_ast_map) {
                self.arch_ast_map[_aname] = stmt;
            }
        }
    }
}

impl NaIRGenPass._register_imported_archetype(arch: uni.Archetype) -> None {
    aname = arch.name.value if arch.name else None;
    if aname is None {
        return;
    }

    if aname not in self.struct_types {
        struct_type = self.llvm_module.context.get_identified_type(aname);
        self.struct_types[aname] = struct_type;
    }

    if aname in self._struct_bodies_done {
        return;
    }

    for _anc in self._mro_of(aname) {
        if (
            _anc != aname
            and _anc in self.arch_ast_map
            and _anc not in self._struct_bodies_done
        ) {
            _anc_arch = self.arch_ast_map[_anc];
            if isinstance(_anc_arch, uni.Archetype) {
                self._register_imported_archetype(_anc_arch);
            }
        }
    }
    if aname in self._struct_bodies_done {
        return;
    }
    self._struct_bodies_done.add(aname);

    self._codegen_archetype(arch);
}

impl NaIRGenPass._register_imported_globals(
    nd: uni.GlobalVars, source_path: str = ""
) -> None {
    for assign in nd.assignments {
        targets = assign.target
            if isinstance(assign.target, (list, tuple))
            else [(assign.target)];
        for target in targets {
            var_name = self._get_name(target);
            if var_name is None or var_name in self.global_vars {
                continue;
            }
            var_type: ir.Type = ir.IntType(64);
            if assign.type_tag and assign.type_tag.tag {
                var_type = self._resolve_jac_type(assign.type_tag.tag);
            }
            global_var = ir.GlobalVariable(self.llvm_module, var_type, name=var_name);
            global_var.linkage = "external";
            self.global_vars[var_name] = global_var;
            self.global_var_types[var_name] = var_type;

            if source_path {
                self._global_origins[var_name] = source_path;
            }
            self.has_native_code = True;
        }
    }
}

impl NaIRGenPass._forward_declare_imported_ability(nd: uni.Ability) -> None {
    name = nd.name_ref.sym_name if nd.name_ref else None;
    if name is None or name in self.func_symtab {
        return;
    }

    if nd.body is None {
        return;
    }
    self._maybe_declare_ability(nd);
}

impl NaIRGenPass._process_clib_imports(module: uni.Module) -> None {
    imports = [
        s
        for s in ModuleCodegenPass.iter_context_stmts(module)
        if isinstance(s, uni.Import)
    ];
    for stmt in imports {
        if not stmt.clib_decls {
            if stmt.items {
                for item in stmt.items {
                    import from jaclang.compiler.passes.main.capability_check_pass {
                        classify_native_import
                    }
                    import from jaclang.jac0core.codeinfo { is_bundled_native_module }
                    (mod_name, _supported) = classify_native_import(item);
                    if _supported {
                        self._native_stdlib_modules.add(mod_name);
                    } elif mod_name is not None
                    and is_bundled_native_module(mod_name) {
                        self._native_module_imports.add(mod_name);
                    }
                }
            }
            continue;
        }

        _paths_before = len(self._clib_paths);
        if stmt.from_loc is not None and stmt.from_loc.path {
            _name_components: list[str] = [];
            for path_part in stmt.from_loc.path {
                if isinstance(path_part, uni.String) {
                    raw = path_part.value;

                    if (len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "\"'") {
                        raw = raw[1:-1];
                    }

                    self._clib_paths.append(raw);
                } elif isinstance(path_part, uni.Name) {
                    _name_components.append(path_part.value);
                }
            }
            if _name_components {
                self._clib_paths.append(
                    self._resolve_clib_lib_name(_name_components, stmt.from_loc.level)
                );
            }
        }

        _cur_lib = self._clib_paths[-1]
            if len(self._clib_paths) > _paths_before
            else None;

        for decl in stmt.clib_decls {
            if isinstance(decl, uni.Archetype) {
                arch_name = decl.name.value if decl.name else None;
                if arch_name is not None {
                    struct_type = self.llvm_module.context.get_identified_type(
                        arch_name
                    );
                    self.struct_types[arch_name] = struct_type;
                    self.clib_struct_names.add(arch_name);
                    self.has_native_code = True;
                }
            }
        }

        for decl in stmt.clib_decls {
            if isinstance(decl, uni.Archetype) {
                arch_name = decl.name.value if decl.name else None;
                if arch_name is not None and arch_name in self.struct_types {
                    self._codegen_archetype(decl);

                    stype = self.struct_types[arch_name];
                    if stype?.elements and stype.elements {
                        total_bits = 0;
                        all_int = True;
                        for elem in stype.elements {
                            if isinstance(elem, ir.IntType) {
                                total_bits += elem.width;
                            } else {
                                all_int = False;
                                break;
                            }
                        }
                        if all_int and 0 < total_bits <= 64 {
                            abi_bits = 8;
                            while abi_bits < total_bits {
                                abi_bits *= 2;
                            }
                            self.clib_struct_abi_types[arch_name] = ir.IntType(
                                abi_bits
                            );
                        }
                    }
                }
            }
        }

        self._clib_detect_vtable_structs();

        for decl in stmt.clib_decls {
            if isinstance(decl, uni.Ability) {
                fn_name = decl.name_ref.sym_name if decl.name_ref else None;

                _is_empty_list = isinstance(decl.body, list) and not decl.body;
                if decl.body is not None and not _is_empty_list {
                    self.emit(E5060, name=fn_name);
                    continue;
                }
                self._declare_clib_ability(decl);
                if fn_name {
                    self.clib_extern_names.add(fn_name);
                    if _cur_lib is not None {
                        self._clib_symbol_lib[fn_name] = _cur_lib;
                    }
                }
            }
        }

        if self._clib_paths {
            module.gen._clib_paths = self._clib_paths;
            module.gen._clib_symbol_lib = self._clib_symbol_lib;
            self.has_native_code = True;
        }
    }
}

impl NaIRGenPass._resolve_clib_lib_name(components: list[str], level: int) -> str {
    triple = str(self.llvm_module.triple or "").lower();
    if ("darwin" in triple)
    or ("apple" in triple)
    or ("macos" in triple)
    or ("ios" in triple) {
        prefix = "lib";
        ext = ".dylib";
        origin_token = "@loader_path";
    } elif ("windows" in triple)
    or ("win32" in triple)
    or ("mingw" in triple)
    or ("msvc" in triple) {
        prefix = "";
        ext = ".dll";
        origin_token = ".";
    } else {
        prefix = "lib";
        ext = ".so";
        origin_token = "$ORIGIN";
    }
    stem = components[-1];
    subdir_parts = components[:-1];
    filename = prefix + stem + ext;
    if subdir_parts or level > 0 {
        rel = "/".join(subdir_parts + [filename]) if subdir_parts else filename;
        return origin_token + "/" + rel;
    }

    return filename;
}

impl NaIRGenPass._ensure_emitters -> None {
    if self._native_emitters is not None {
        return;
    }
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    import jaclang.compiler.passes.native.primitives_native as _pn;
    self._native_emitters = {};
    for (_tn, _suffix) in JAC_TYPE_REGISTRY.emitter_items() {
        _ecls = getattr(_pn, "Native" + _suffix, None);
        if _ecls is not None {
            self._native_emitters[_tn] = _ecls();
        }
    }
    self._native_builtin_emitter = _pn.NativeBuiltinEmitter();
    self._native_emit_ctx_class = _pn.NativeEmitCtx;
}

impl NaIRGenPass._primitive_method_names(type_name: str) -> set[str] {
    import inspect;
    self._ensure_emitters();
    if self._primitive_method_name_cache is None {
        self._primitive_method_name_cache = {};
    }
    _cached = self._primitive_method_name_cache.get(type_name);
    if _cached is not None {
        return _cached;
    }
    _names: set[str] = set();
    _emitter = self._native_emitters.get(type_name);
    if _emitter is not None {
        for _n in dir(_emitter) {
            if _n.startswith("emit_") and not _n.startswith("emit_op_") {
                _fn = getattr(_emitter, _n);

                if len(inspect.signature(_fn).parameters) >= 3 {
                    _names.add(_n.removeprefix("emit_"));
                }
            }
        }
    }
    self._primitive_method_name_cache[type_name] = _names;
    return _names;
}

impl NaIRGenPass._dispatch_primitive_method(
    type_name: str,
    method_name: str,
    target: ir.Value,
    args: list[ir.Value],
    type_key: str,
    kwargs: (dict | None) = None,
    kw_node: (uni.UniNode | None) = None
) -> (ir.Value | None) {
    self._ensure_emitters();
    _emitter = self._native_emitters.get(type_name);
    if _emitter is None {
        return None;
    }
    _emit_fn = getattr(_emitter, "emit_" + method_name, None);
    if _emit_fn is None {
        return None;
    }
    if kwargs and method_name not in ("sort", ) {
        self.emit(
            E5090,
            node_override=kw_node,
            kind="keyword argument for native method",
            name=f"{method_name}({', '.join(kwargs.keys())}=...)"
        );
        return None;
    }
    _ctx = self._native_emit_ctx_class(
        pass_ref=self, type_key=type_key, call_kwargs=(kwargs or {})
    );
    return _emit_fn(_ctx, target, args);
}

impl NaIRGenPass._dispatch_builtin(
    func_name: str,
    args: list[ir.Value],
    kwargs: (dict | None) = None,
    kw_node: (uni.UniNode | None) = None
) -> (ir.Value | None) {
    self._ensure_emitters();
    _emit_fn = getattr(self._native_builtin_emitter, "emit_" + func_name, None);
    if _emit_fn is None {
        return None;
    }
    if kwargs and func_name not in ("sorted", ) {
        self.emit(
            E5090,
            node_override=kw_node,
            kind="keyword argument for native builtin",
            name=f"{func_name}({', '.join(kwargs.keys())}=...)"
        );
        return None;
    }
    _ctx = self._native_emit_ctx_class(
        pass_ref=self, type_key="", call_kwargs=(kwargs or {})
    );
    return _emit_fn(_ctx, args);
}

impl NaIRGenPass._split_call_kwargs(nd: uni.FuncCall) -> dict {
    out: dict = {};
    for param in (nd.params or []) {
        if isinstance(param, uni.KWPair) and param.key is not None {
            out[param.key.sym_name] = param.value;
        }
    }
    return out;
}
