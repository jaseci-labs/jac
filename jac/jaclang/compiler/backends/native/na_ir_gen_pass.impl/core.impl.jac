def scalar_llvm_type(`entry: JacTypeEntry) -> ir.Type {
    if `entry.is_float {
        return ir.FloatType() if `entry.width == 32 else ir.DoubleType();
    }
    return ir.IntType(`entry.width);
}

impl NaIRGenPass.postinit -> None {
    import os as _ni_os;

    _ni_opts = self.prog.options;
    self._rc_debug_codegen = bool(_ni_opts.rc_debug_codegen);
    _ni_src: str = self.ir_in.loc.mod_path if self.ir_in.loc else "";
    _ni_mod_name: str = _ni_os.path.basename(_ni_src) if _ni_src else "jac_native";
    self._llvm_module = ir.Module(name=_ni_mod_name, context=ir.Context());
    import jaclang.compiler.backends.native.llvm.binding as _llvm_bind;

    _ni_target_ovr = _ni_opts.native_target or "";
    if _ni_target_ovr {
        _llvm_bind.initialize_all_targets();
        _llvm_bind.initialize_all_asmprinters();
        _target = _llvm_bind.Target.from_triple(_ni_target_ovr);
    } else {
        _llvm_bind.initialize_native_target();
        _target = _llvm_bind.Target.from_default_triple();
    }

    _tm = _target.create_target_machine(reloc="pic", codemodel="small");
    self.llvm_module.data_layout = str(_tm.target_data);
    self.llvm_module.triple = _tm.triple;
    import from jaclang.compiler.frontend.codeinfo { native_unit_prefix }
    self._unit_prefix = native_unit_prefix(_ni_src) if _ni_src else "jac_native";

    if _ni_src and _ni_opts.native_debug {
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

    _byte_ptr = ir.IntType(8).as_pointer();
    self._type_map = {};
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    for _scalar in JAC_TYPE_REGISTRY.scalar_entries() {
        if _scalar.name == "str" {
            continue;
        }
        self.type_map[_scalar.name] = scalar_llvm_type(_scalar);
    }
    self.type_map["str"] = (
        _byte_ptr
            if "wasm" in str(self.llvm_module.triple or "")
            else self._str_desc_type()
    );
    self.type_map["LiteralString"] = self.type_map["str"];
    self.type_map["Region"] = _byte_ptr;

    self.type_map["type"] = _byte_ptr;

    self._complex_struct_type = self.llvm_module.context.get_identified_type(
        "JacComplex"
    );
    self.complex_struct_type.set_body(ir.DoubleType(), ir.DoubleType());

    self._range_struct_type = self.llvm_module.context.get_identified_type("JacRange");
    self.range_struct_type.set_body(ir.IntType(64), ir.IntType(64), ir.IntType(64));

    self._slice_struct_type = self.llvm_module.context.get_identified_type("JacSlice");
    self.slice_struct_type.set_body(ir.IntType(64), ir.IntType(64), ir.IntType(64));

    self._jacval_type = self.llvm_module.context.get_identified_type("JacVal");
    self.jacval_type.set_body(ir.IntType(8), ir.IntType(64));

    super.postinit();
}

impl NaIRGenPass._run_impl(ir_in: uni.Module) -> uni.Module {
    import from jaclang.compiler.passes.capability_check_pass {
        native_capability_violations,
        partition_native_capability_violations
    }
    self._capability_demotions = {};
    self._claimed_capability_demotions = set();
    _viols = native_capability_violations(self.ir_in);
    if _viols {
        (_fatal_viols, _demotable) = partition_native_capability_violations(_viols);
        if _fatal_viols {
            if not self.ir_in.native_viols_reported {
                _report = list(_fatal_viols);
                for _unit_viols in _demotable.values() {
                    _report.extend(_unit_viols);
                }
                for (_vnode, _vkind, _vname, _vhelp) in _report {
                    self.emit(
                        E5090,
                        node_override=_vnode,
                        kind=_vkind,
                        name=_vname,
                        help_text=_vhelp
                    );
                }
            }
            return self.ir_in;
        }
        self._capability_demotions = _demotable;
    }

    self._emit_rc_helpers();

    self._process_clib_imports(self.ir_in);

    self._register_enums(self.ir_in);

    self._forward_declare_archetype_names(self.ir_in);

    self._register_imported_struct_types();
    self._register_globals(self.ir_in);
    self._register_entry_globals(self.ir_in);

    self._register_enum_methods(self.ir_in, declare=True);
    self._register_archetypes(self.ir_in);
    self._register_enum_methods(self.ir_in, declare=False);

    _entry_nodes: list = [];
    for stmt in ModuleFacts.iter_context_stmts(self.ir_in, CodeContext.NATIVE) {
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
    _unclaimed = False;
    for (_ck, _cviols) in self._capability_demotions.items() {
        if _ck in self._claimed_capability_demotions {
            continue;
        }
        _unclaimed = True;
        for (_vnode, _vkind, _vname, _vhelp) in _cviols {
            self.emit(
                E5090, node_override=_vnode, kind=_vkind, name=_vname, help_text=_vhelp
            );
        }
    }
    if _unclaimed {
        return self.ir_in;
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
        self.ir_in.gen.native_deps = list(self._native_dep_paths);

        import os;
        if self.prog.options.rc_stats {
            _rc_total = self.rc_retains_emitted + self.rc_releases_emitted;
            _rc_known = _rc_total + self.rc_ops_elided;
            _rc_pct = (100.0 * self.rc_ops_elided / _rc_known) if _rc_known else 0.0;
            _rc_free = " rc-free" if _rc_total == 0 else "";
            import sys;
            _rc_arena = (
                f" arena={self.rc_region_allocs}" if self.rc_region_allocs else ""
            );
            _rc_stk = (
                f" promoted={self.rc_stack_promotions}"
                    if self.rc_stack_promotions
                    else ""
            );
            sys.stderr.write(
                f"rc-stats [{os.path.basename(self.ir_in.loc.mod_path)}] "
                f"gc={self._gc_mode()} retains={self.rc_retains_emitted} "
                f"releases={self.rc_releases_emitted} "
                f"elided={self.rc_ops_elided} coverage={_rc_pct:.1f}%"
                f"{_rc_stk}{_rc_arena}{_rc_free}\n"
            );
        }
        _ir_dump_path = self.prog.options.dump_ir_path or "";
        if _ir_dump_path {
            with open(_ir_dump_path, "w") as _f {
                _f.write(str(self.llvm_module));
            }
        }

        self._export_native_layout();
        self._export_native_iface();
    }
    return self.ir_in;
}

impl NaIRGenPass._record_lowering_issue(issue: NativeLoweringIssue) -> None {
    self._lowering_issues.append(issue);
    issue.record(self.llvm_module);
}

impl NaIRGenPass._export_native_iface -> None {
    import os as _ni_os;
    import from jaclang.compiler.driver.native_iface {
        NativeClassLayout,
        NativeFieldSlot,
        NativeIface
    }
    import from jaclang.compiler.frontend.codeinfo {
        native_glob_init_name,
        native_module_key
    }
    mod_path = self.ir_in.loc.mod_path if self.ir_in?.loc else "";
    iface = NativeIface(
        module=native_module_key(mod_path) if mod_path else "",
        prefix=self._own_prefix()
    );
    layout = self.ir_in.gen.native_layout;
    iface.layout = layout;
    for (name, ex) in self._unit_exports.items() {
        sig: any = None;
        if layout is not None {
            sig = layout.functions.get(name) or layout.methods.get(name);
        }
        if sig is not None {
            ex.param_types = list(sig.param_types);
            ex.param_names = list(sig.param_names);
            ex.ret_type = sig.ret_type;
        }
        fn = self.func_symtab.get(name);
        if isinstance(fn, ir.Function) {
            decl = self._linked_callee_decl(fn);
            if decl is not None and isinstance(decl.signature, uni.FuncSignature) {
                import json;
                ex.param_defaults = [
                    json.dumps(
                        [
                            [tok.name, tok.value]
                            for tok in p.value.flatten()
                            if isinstance(tok, uni.Token)
                        ]
                    )
                        if p.value is not None
                        else "" for p in decl.signature.get_parameters()
                ];
            }
            ex.ownership = [
                "borrow" if "readonly" in [str(a) for a in arg.attributes] else "own"
                for arg in fn.args
            ];
        }
        iface.exports[name] = ex;
    }
    for (cname, body) in self._build_class_layouts().items() {
        iface.classes[cname] = NativeClassLayout(
            name=cname,
            size=int(body.get("size", 0)),
            tag=int(body.get("tag", 0)),
            tag_offset=int(body.get("tag_offset", -1)),
            fields={
                fname: NativeFieldSlot.from_dict(fd)
                for (fname, fd) in body.get("fields", {}).items()
            },
            bases=list(body.get("bases", [])),
            vtable=list(body.get("vtable", [])),
            is_node=bool(body.get("is_node", False))
        );
    }
    for (ename, members) in self.enum_string_values.items() {
        if self._enum_source_name.get(ename, self.ir_in.name) == self.ir_in.name {
            iface.enums[ename] = [str(m) for m in members];
        }
    }
    if "__jac_glob_init" in self.func_symtab and mod_path {
        iface.init_symbol = native_glob_init_name(mod_path);
    }
    entry_fn = self.func_symtab.get("jac_entry");
    if entry_fn is not None {
        iface.entry_symbol = str(entry_fn.name);
    }
    iface.demoted = sorted(
        self._demoted_names | {issue.symbol for issue in self._lowering_issues}
    );
    iface.clib_paths = list(self.ir_in.gen._clib_paths or []);
    iface.python_imports = [
        binding.name for binding in self.ir_in.gen.interop_manifest.native_imports
    ];
    iface.clib_symbol_lib = dict(self.ir_in.gen._clib_symbol_lib or {});
    iface.deps = list(self._native_dep_paths);
    try {
        import from jaclang.compiler.driver.na_coverage { na_coverage_capture }
        iface.coverage = na_coverage_capture(mod_path) if mod_path else {};
    } except Exception {
        iface.coverage = {};
    }
    self.ir_in.gen.native_iface = iface;
    self.ir_in.gen.native_deps = list(self._native_dep_paths);
}

impl NaIRGenPass._build_class_layouts -> dict {
    return dict(self._build_jc_layout().get("classes", {}));
}

impl NaIRGenPass._own_prefix -> str {
    return self._unit_prefix;
}

impl NaIRGenPass._prefix_of_path(path: str) -> str {
    import os as _pp_os;
    import from jaclang.compiler.frontend.codeinfo { native_unit_prefix }
    key = _pp_os.path.realpath(path);
    found = self._unit_prefixes.get(key);
    if found is None {
        found = native_unit_prefix(key);
        self._unit_prefixes[key] = found;
    }
    return found;
}

impl NaIRGenPass._prefix_of_module(mod: (uni.Module | None)) -> str {
    if mod is None or mod is self.ir_in or not (mod?.loc and mod.loc.mod_path) {
        return self._own_prefix();
    }
    return self._prefix_of_path(mod.loc.mod_path);
}

impl NaIRGenPass._symbol_for(
    name: str, owner: (uni.Module | None) = None, is_pub: bool = False
) -> str {
    import from jaclang.compiler.frontend.codeinfo {
        native_symbol_name,
        native_unit_identity
    }
    module = owner if owner is not None else self.ir_in;
    bundled_library = native_unit_identity(module.loc.mod_path).startswith(
        "jaclang/runtime/na_stdlib/"
    );
    if is_pub and not bundled_library {
        return name;
    }
    return native_symbol_name(self._prefix_of_module(owner), name);
}

impl NaIRGenPass._record_export(
    name: str, symbol: str, kind: str, is_pub: bool = False
) -> None {
    self._unit_exports[name] = NativeExport(
        name=name, symbol=symbol, kind=kind, is_pub=is_pub
    );
    if is_pub {
        self._pub_symbols.add(symbol);
    }
}

impl NaIRGenPass._note_native_dep(path: str) -> None {
    import os as _nd_os;
    real = _nd_os.path.realpath(path);
    own_path = _nd_os.path.realpath(self.ir_in.loc.mod_path) if self.ir_in?.loc else "";
    if real == own_path or real in self._native_dep_paths {
        return;
    }
    self._native_dep_paths.append(real);
}

impl NaIRGenPass._is_catalog_module(mod: uni.Module) -> bool {
    return mod?.cat_id is not None;
}

impl NaIRGenPass._full_ast_of(full_path: str) -> (uni.Module | None) {
    import os as _fa_os;
    key = _fa_os.path.realpath(full_path);
    found = self._full_ast_cache.get(key);
    if found is not None {
        return found;
    }
    try {
        mod = self.prog.load_dependency_module(key, need_tree=True);
    } except Exception as exc {
        import from jaclang.compiler.driver.compile_options { env_na_debug }
        if env_na_debug() {
            import sys as _fa_sys;
            _fa_sys.stderr.write(
                f"NA_DEBUG full AST of {key} raised {type(exc).__name__}: {exc}\n"
            );
        }
        return None;
    }
    if mod is None or self._is_catalog_module(mod) {
        import from jaclang.compiler.driver.compile_options { env_na_debug }
        if env_na_debug() {
            import sys as _fa_sys;
            _fa_sys.stderr.write(
                f"NA_DEBUG full AST of {key} unavailable ({type(mod).__name__})\n"
            );
        }
        return None;
    }
    self._full_ast_cache[key] = mod;
    return mod;
}

impl NaIRGenPass._dep_iface(imported_mod: uni.Module) -> (NativeIface | None) {
    if not (imported_mod?.loc and imported_mod.loc.mod_path) {
        return None;
    }
    opts = self.prog.options;
    ent = self.prog.native_units().ensure(
        imported_mod.loc.mod_path, compile_on_miss=True, options=opts, check_deps=False
    );
    return ent.iface if ent is not None else None;
}

impl NaIRGenPass._load_native_unit_module(path: str) -> (uni.Module | None) {
    import os as _lu_os;
    real = _lu_os.path.realpath(path);
    found = self.prog.mod.hub.get(real);
    if found is not None and found.decided_codespace == 'native' {
        return found;
    }
    if not _lu_os.path.isfile(real) {
        return None;
    }
    import from jaclang.compiler.driver.compile_options { CompileOptions as _UnitOpts }
    saved = self.prog.options;
    try {
        return self.prog.compile(
            real,
            options=_UnitOpts(
                no_cgen=True,
                symtab_ir_only=True,
                aot_mode=True,
                default_codespace='native',
                force_codespace='native',
                native_unit=True
            )
        );
    } finally {
        self.prog.options = saved;
    }
}

impl NaIRGenPass._is_kernel_unit -> bool {
    import from jaclang.compiler.frontend.codeinfo { is_kernel_unit_path }
    return bool(self.ir_in?.loc) and is_kernel_unit_path(self.ir_in.loc.mod_path);
}

impl NaIRGenPass._predemote_capability_unit(
    full_name: str, func: ir.Function, viols: list, keep_func: bool = False
) -> bool {
    _local_mark = len(self.errors_had);
    for (_vnode, _vkind, _vname, _vhelp) in viols {
        self.emit(
            E5090, node_override=_vnode, kind=_vkind, name=_vname, help_text=_vhelp
        );
    }
    return self._demote_method_if_unlowerable(
        full_name, func, _local_mark, keep_func=keep_func
    );
}

impl NaIRGenPass._rename_demoted_symbol(name: str, func: ir.Function) -> None {
    self._demoted_names.add(name);
    self._unit_exports.pop(name, None);
    try {
        self.llvm_module.globals.pop(func.name, None);
        func.name = f"{func.name}.__jac_demoted";
        self.llvm_module.globals[func.name] = func;
    } except Exception {}
}

impl NaIRGenPass._llvm_type_str(ty: ir.Type) -> str {
    _opt_pt = self._opt_payload_of(ty);
    if _opt_pt is not None {
        return "opt." + self._llvm_type_str(_opt_pt);
    }
    if self._str_desc_ty is not None and ty == self._str_desc_ty {
        return self._str_desc_kind();
    }
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

            for (dkey, dtype) in self.dict_types.items() {
                if ty.pointee == dtype {
                    return f"{dtype.name}*";
                }
            }

            for (sekey, setype) in self.set_types.items() {
                if ty.pointee == setype {
                    return f"{setype.name}*";
                }
            }
        }
        return "ptr";
    }
    return "i64";
}

impl NaIRGenPass._export_native_layout -> None {
    import from jaclang.compiler.frontend.codeinfo {
        NativeModuleLayout,
        NativeStructLayout,
        NativeFieldInfo,
        NativeEnumLayout,
        NativeFuncLayout,
        NativeTupleLayout,
        NativeTestLayout
    }
    layout = NativeModuleLayout(str_headerless=self._nogc_headerless());

    for (arch_name, field_indices) in self.struct_field_indices.items() {
        field_types = self.struct_field_types.get(arch_name, {});
        fields: list[NativeFieldInfo] = [];
        field_enums = self.struct_field_enum_type.get(arch_name, {});
        elem_keys = self.struct_field_elem_keys.get(arch_name, {});
        _foreign_flds = self.struct_field_foreign.get(arch_name, set());
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
                    enum_type=field_enums.get(fname),
                    is_func_ptr=is_fn_ptr,
                    func_param_types=fn_param_types,
                    func_ret_type=fn_ret_type,
                    elem_keys=elem_keys.get(fname),
                    foreign=fname in _foreign_flds
                )
            );
        }
        layout.structs[arch_name] = NativeStructLayout(
            name=arch_name,
            fields=fields,
            has_vtable=self._arch_has_vtable(arch_name),
            accessors=self._exported_accessors(arch_name)
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
        if str(func.linkage) in ("internal", "private") {
            continue;
        }
        if fname in self._clib_symbol_lib {
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
                            hints = self._ret_tuple_hints(fname, ret_tuple);
                            if hints is not None {
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
        if ret_type in ("i64", "opt.i64") {
            _rkey = self.func_ret_type_key.get(fname);
            if _rkey is not None {
                if _rkey in self.enum_types {
                    ret_enum = _rkey;
                } elif "|" in _rkey {
                    _rnon = [
                        s.strip()
                        for s in _rkey.split("|")
                        if s.strip() not in ("None", "NoneType")
                    ];
                    if len(_rnon) == 1 and _rnon[0] in self.enum_types {
                        ret_enum = _rnon[0];
                    }
                }
            }
        }

        ret_elem: (list | None) = None;
        if (
            ret_type.startswith("List.")
            or ret_type.startswith("Dict.")
            or ret_type.startswith("Set.")
        ) {
            ret_elem = self.func_ret_elem_keys.get(fname);
        }
        layout.functions[fname] = NativeFuncLayout(
            name=func.name,
            param_types=param_types,
            param_names=param_names,
            ret_type=ret_type,
            ret_struct_name=ret_struct,
            ret_tuple_layout=ret_tuple,
            ret_enum_type=ret_enum,
            ret_elem_keys=ret_elem
        );
    }

    for (mname, func) in self.method_funcs.items() {
        if mname in self._native_skipped_methods {
            continue;
        }
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

impl NaIRGenPass._exported_accessors(arch_name: str) -> dict[(str, dict[(str, str)])] {
    out: dict[(str, dict[(str, str)])] = {};
    lay = self._arch_layout(arch_name);
    if lay is None {
        return out;
    }
    for slot in lay.method_index {
        parts = slot.rsplit(".", 1);
        if len(parts) != 2 or parts[1] not in ACCESSOR_SLOT_SUFFIX.values() {
            continue;
        }
        fn = self._resolve_method(arch_name, slot);
        if fn is None or fn.name in self._native_skipped_methods {
            continue;
        }
        if parts[0] not in out {
            out[parts[0]] = {};
        }
        out[parts[0]][parts[1]] = fn.name;
    }
    return out;
}

impl NaIRGenPass._ret_tuple_hints(fname: str, ret_tuple: any) -> (list | None) {
    keys = self.func_ret_elem_keys.get(fname);
    if not keys or len(keys) != len(ret_tuple.element_types) {
        return None;
    }
    hints: list = [];
    _any = False;
    for k in keys {
        hint: (str | None) = None;
        if k is not None {
            if k in self.struct_types {
                hint = k;
            } elif k.startswith("list[") and k.endswith("]") {
                _inner = k[5:-1];
                if _inner in self.struct_types {
                    hint = _inner;
                }
            }
        }
        if hint is not None {
            _any = True;
        }
        hints.append(hint);
    }
    return hints if _any else None;
}

impl NaIRGenPass._register_imported_struct_types -> None {
    import os;
    import from jaclang.compiler.frontend.codeinfo {
        resolve_native_module,
        is_bundled_native_module
    }

    processed_modules: set[str] = set();
    imported_mods: list = [];

    entry_base = os.path.dirname(os.path.abspath(self.ir_in.loc.mod_path))
        if (self.ir_in?.loc)
        else os.getcwd();

    _native_ids: set = {
        id(_s) for _s in ModuleFacts.iter_context_stmts(self.ir_in, CodeContext.NATIVE)
    };
    _has_native_code: bool = len(_native_ids) > 0;
    _nested_native = ModuleFacts.iter_nested_imports(self.ir_in, CodeContext.NATIVE);
    for _nested_imp in _nested_native {
        _native_ids.add(id(_nested_imp));
    }
    wq: list[tuple[str, str, str | None, bool]] = [];
    for imp in ModuleFacts.iter_module_imports(self.ir_in) + _nested_native {
        mod_name = self._extract_import_module_name(imp);
        if not mod_name {
            continue;
        }
        if (not imp.from_loc) and (not imp.is_absorb) {
            if not _has_native_code {
                continue;
            }
            if not is_bundled_native_module(mod_name) {
                _item0 = next(
                    (
                        i
                        for i in imp.items
                        if isinstance(i, uni.ModulePath)
                    ),
                    None
                );
                if (
                    id(imp) not in _native_ids
                    or _item0 is None
                    or resolve_native_module(mod_name, entry_base)[1] is None
                ) {
                    continue;
                }
            }
        }
        wq.append((mod_name, entry_base, None, bool(imp.is_typed)));
    }

    _self_key = (
        os.path.realpath(self.ir_in.loc.mod_path) if (self.ir_in?.loc) else None
    );

    _canon_src: dict = {};
    dep_edges: dict = {};
    typed_only: dict[str, bool] = {};
    qi = 0;
    while qi < len(wq) {
        (mod_name, cur_base, parent_key, typed) = wq[qi];
        qi += 1;
        assert mod_name is not None;
        (src_mod_str, full_path) = resolve_native_module(mod_name, cur_base);
        if src_mod_str is None or full_path is None {
            continue;
        }
        if _self_key is not None and os.path.realpath(full_path) == _self_key {
            continue;
        }
        abs_key = os.path.abspath(full_path);
        if parent_key in dep_edges {
            dep_edges[parent_key].append(abs_key);
        } else {
            dep_edges[parent_key] = [abs_key];
        }
        typed_only[abs_key] = typed and typed_only.get(abs_key, True);
        if abs_key in processed_modules {
            continue;
        }

        imported_mod = self.prog.mod.hub.get(full_path);
        if imported_mod is None {
            imported_mod = self.prog.mod.hub.get(abs_key);
        }

        if imported_mod is None and os.path.isfile(full_path) {
            _saved_opts = self.prog.options;
            try {
                imported_mod = self.prog.compile(
                    full_path, no_cgen=True, symtab_ir_only=True
                );
            } except Exception {
                imported_mod = None;
            } finally {
                self.prog.options = _saved_opts;
            }
        }
        if imported_mod is not None and self._is_catalog_module(imported_mod) {
            imported_mod = self._full_ast_of(full_path);
        }
        if imported_mod is None {
            import from jaclang.compiler.driver.compile_options { env_na_debug }
            if env_na_debug() {
                import sys as _ti_sys;
                _ti_sys.stderr.write(
                    f"NA_DEBUG typed import {full_path} has no AST in {self.ir_in.loc.mod_path}\n"
                );
            }
            continue;
        }
        self._ensure_dep_inference(imported_mod);
        processed_modules.add(abs_key);
        _canon_src[abs_key] = src_mod_str;
        imported_mods.append((src_mod_str, imported_mod));
        import from jaclang.compiler.driver.compile_options { env_na_debug as _ti_dbg }
        if _ti_dbg() {
            import sys as _ti_sys2;
            _n_arch = sum(
                1
                for _st in ModuleFacts.iter_context_stmts(imported_mod)
                if isinstance(_st, uni.Archetype)
            );
            _ti_sys2.stderr.write(
                f"NA_DEBUG typed walk {os.path.basename(self.ir_in.loc.mod_path)} <- "
                f"{os.path.basename(abs_key)} {type(imported_mod).__name__} "
                f"body={len(imported_mod.body)} archetypes={_n_arch} "
                f"codespace={imported_mod.decided_codespace} typed_only={typed}\n"
            );
        }

        sub_base = os.path.dirname(os.path.abspath(full_path));
        for sub_imp in ModuleFacts.iter_module_imports(imported_mod)
            + ModuleFacts.iter_nested_imports(imported_mod, CodeContext.NATIVE) {
            sub_name = self._extract_import_module_name(sub_imp);
            if sub_name {
                wq.append(
                    (sub_name, sub_base, abs_key, typed or bool(sub_imp.is_typed))
                );
            }
        }
    }

    self._foreign_modules = [m for (_s, m) in imported_mods];
    self._typed_only_imports = {
        k
        for (k, v) in typed_only.items()
        if v
    };

    _dep_seen: set[str] = set();
    _dep_todo: list[str] = list(dep_edges.get(None, []));
    while _dep_todo {
        _direct = _dep_todo.pop(0);
        if _direct in _dep_seen {
            continue;
        }
        _dep_seen.add(_direct);
        if typed_only.get(_direct, False) {
            import from jaclang.compiler.placement.placement_facts {
                native_unit as _typed_native_unit
            }
            import from jaclang.compiler.frontend.codeinfo {
                native_unit_compile_active as _typed_nuc
            }
            if _typed_native_unit(_direct, _typed_nuc()) {
                self._note_native_dep(_direct);
            }
            continue;
        }
        _direct_mod = self.prog.mod.hub.get(_direct);
        _has_own_code = (
            _direct_mod is None
            or self._is_catalog_module(_direct_mod)
            or any(
                not isinstance(s, uni.Import)
                for s in ModuleFacts.iter_context_stmts(_direct_mod)
            )
        );
        if _has_own_code {
            self._note_native_dep(_direct);
        } else {
            """A module made only of imports and includes is a re-export
            surface: the units behind it are what this module links to.""";
            _dep_todo.extend(dep_edges.get(_direct, []));
        }
    }

    imported_mods = self._permuted_walk_order(imported_mods);

    for (_, imported_mod) in imported_mods {
        self._process_clib_imports(imported_mod);
    }

    for (_, imported_mod) in imported_mods {
        self._walk_imported_module_type_names(imported_mod);
    }

    for (_, imported_mod) in imported_mods {
        self._register_imported_hierarchy(imported_mod);
    }

    import from jaclang.compiler.passes.layout_pass { adopt_imported_bases }
    adopt_imported_bases(self.ir_in);

    for (_, imported_mod) in imported_mods {
        self._walk_imported_module_types(imported_mod);
    }

    for (_, imported_mod) in imported_mods {
        _imp_path = os.path.abspath(imported_mod.loc.mod_path)
            if imported_mod?.loc
            else "";
        self._walk_imported_module_abilities(
            imported_mod, with_fn_verdicts=(_imp_path not in self._typed_only_imports)
        );
    }
}

impl NaIRGenPass._permuted_walk_order(mods: list) -> list {
    _spec = self.prog.options.native_module_walk_order or "";
    if not _spec {
        return mods;
    }
    if _spec == "reverse" {
        return list(reversed(mods));
    }
    if _spec.startswith("shuffle:") {
        import random as _wo_random;
        _out = list(mods);
        _wo_random.Random(int(_spec.split(":", 1)[1])).shuffle(_out);
        return _out;
    }
    raise ValueError(f"unknown native_module_walk_order: {_spec!r}");
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
    if imp.from_loc.string_path_value is not None {
        return None;
    }
    mod_name = imp.from_loc?.dot_path_str;
    if not mod_name and imp.from_loc?.path and imp.from_loc.path {
        mod_name = '.'.join(getattr(p, 'value', str(p)) for p in imp.from_loc.path);
    }
    return mod_name;
}

impl NaIRGenPass._walk_imported_module_type_names(imported_mod: uni.Module) -> None {
    for stmt in ModuleFacts.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
            and not stmt.codespace_dual
        ) {
            continue;
        }
        if isinstance(stmt, uni.Archetype) {
            aname = stmt.name.value if stmt.name else None;
            if aname is not None and aname not in self.struct_types {
                struct_type = self.llvm_module.context.get_identified_type(aname);
                self.struct_types[aname] = struct_type;
            }
            if aname is not None and aname not in self._struct_source_name {
                self._struct_source_name[aname] = imported_mod.name;
            }
        } elif isinstance(stmt, uni.Enum) {
            ename = stmt.name.value if stmt.name else None;
            if ename is not None and ename not in self._enum_source_name {
                self._enum_source_name[ename] = imported_mod.name;
            }
        }
    }
}

impl NaIRGenPass._walk_imported_module_types(imported_mod: uni.Module) -> None {
    for stmt in ModuleFacts.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
            and not stmt.codespace_dual
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
            for method in self._enum_methods(stmt) {
                self._forward_declare_method(stmt.name.value, method, imported=True);
            }
        } elif isinstance(stmt, uni.GlobalVars) {
            _imp_path = imported_mod.loc.mod_path if imported_mod?.loc else "";
            self._register_imported_globals(stmt, _imp_path);
        }
    }
}

impl NaIRGenPass._walk_imported_module_abilities(
    imported_mod: uni.Module, with_fn_verdicts: bool = True
) -> None {
    _imp_iface = self._dep_iface(imported_mod) if with_fn_verdicts else None;
    _imp_layout = _imp_iface.layout if _imp_iface is not None else None;
    if _imp_layout is None {
        _imp_layout = imported_mod.gen.native_layout;
    }
    if _imp_layout is None and imported_mod?.loc and imported_mod.loc.mod_path {
        import os as _wl_os;
        _wl_raw = imported_mod.loc.mod_path;
        for _wl_key in (
            _wl_raw,
            _wl_os.path.abspath(_wl_raw),
            _wl_os.path.realpath(_wl_raw)
        ) {
            _wl_slim = self.prog.hub.artifacts.get(_wl_key);
            if _wl_slim is not None and _wl_slim.native_layout is not None {
                _imp_layout = _wl_slim.native_layout;
                break;
            }
        }
    }

    _wl_internal = False;
    if _imp_layout is None and imported_mod?.loc and imported_mod.loc.mod_path {
        import os as _wl_os2;

        _wl_abs = _wl_os2.path.abspath(imported_mod.loc.mod_path);
        _wl_jac_internal = imported_mod.decided_codespace != 'native'
            and (_wl_os2.sep + "jaclang" + _wl_os2.sep) in _wl_abs
            and (_wl_os2.sep + "na_stdlib" + _wl_os2.sep) not in _wl_abs;
        if _wl_jac_internal {
            try {
                import from jaclang.jac0core { sealed as _wl_sealed }
                _wl_internal = _wl_sealed._jaclang_image() is not None;
            } except Exception {
                _wl_internal = False;
            }
        }
    }
    _imp_fn_unavail: (set | None) = None;
    if with_fn_verdicts {
        _imp_fn_unavail = self._imported_function_demotions(imported_mod);
    }
    for _imp_arch in ModuleFacts.iter_context_stmts(imported_mod) {
        if not isinstance(_imp_arch, uni.Archetype)
            or _imp_arch.body is None
            or _imp_arch.name is None {
            continue;
        }
        _ia_name = _imp_arch.name.value;
        for _imp_stmt in _imp_arch.body {
            if (
                isinstance(_imp_stmt, uni.Ability)
                and _imp_stmt.name_ref
                and isinstance(_imp_stmt.signature, uni.FuncSignature)
            ) {
                _im_full = f"{_ia_name}.{_imp_stmt.name_ref.sym_name}";
                if (
                    _imp_layout is not None
                    and _im_full not in _imp_layout.methods
                    and not _imp_stmt.type_params
                )
                    or (_imp_layout is None and _wl_internal)
                    or (_imp_fn_unavail is not None and _im_full in _imp_fn_unavail) {
                    self._native_skipped_methods.add(_im_full);
                }
            }
        }

        for (_ia_slot, _ia_var, _ia_acc) in archetype_accessors(_imp_arch) {
            _im_full = f"{_ia_name}.{_ia_slot}";
            if (_imp_layout is not None and _im_full not in _imp_layout.methods)
                or (_imp_layout is None and _wl_internal) {
                self._native_skipped_methods.add(_im_full);
            }
        }
    }
    for stmt in ModuleFacts.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
            and not stmt.codespace_dual
        ) {
            continue;
        }
        if isinstance(stmt, uni.Archetype) {
            self._forward_declare_archetype_methods(stmt);
        }
    }

    for stmt in ModuleFacts.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
            and not stmt.codespace_dual
        ) {
            continue;
        }
        if isinstance(stmt, uni.Ability) {
            self._forward_declare_imported_ability(stmt, _imp_fn_unavail, _imp_layout);
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
                self._forward_declare_method(aname, stmt, imported=True);
                if stmt.name_ref is not None {
                    self._record_linked_decl(
                        self.method_funcs.get(f"{aname}.{stmt.name_ref.sym_name}"), stmt
                    );
                }
            } elif isinstance(stmt.signature, uni.EventSignature)
                and (arch.arch_kind is not None) {
                self._forward_declare_event_method(aname, stmt);
                self._emit_osp_thunk(aname, stmt);
            }
        }
    }
    for (_slot, _accvar, _acc) in archetype_accessors(arch) {
        self._forward_declare_method(aname, _acc, field=_accvar, imported=True);
    }
}

impl NaIRGenPass._register_imported_hierarchy(imported_mod: uni.Module) -> None {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    _imp_reg = get_layout_registry(imported_mod, self.prog);
    _cons_reg = get_layout_registry(self.ir_in, self.prog);
    for (_name, _parents) in _imp_reg.class_parents.items() {
        if _name not in _cons_reg.class_parents
            or (_name in _imp_reg.layouts and _name not in _cons_reg.layouts) {
            _cons_reg.class_parents[_name] = _parents;
        }
    }
    for (_name, _pmods) in _imp_reg.parent_mods.items() {
        if _name not in _cons_reg.parent_mods {
            _cons_reg.parent_mods[_name] = _pmods;
        }
    }
    for (_name, _mro) in _imp_reg.mro_order.items() {
        if _name not in _cons_reg.mro_order
            or (_name in _imp_reg.layouts and _name not in _cons_reg.layouts) {
            _cons_reg.mro_order[_name] = _mro;
        }
    }
    for (_name, _lay) in _imp_reg.layouts.items() {
        if _name not in _cons_reg.layouts {
            _cons_reg.layouts[_name] = _lay;
        }
    }

    for stmt in ModuleFacts.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
            and not stmt.codespace_dual
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

    _arch_mod = arch.find_parent_of_type(uni.Module);
    _arch_src = _arch_mod.loc.mod_path if _arch_mod is not None else "";
    _seen_src = self._struct_source_mod.get(aname);
    if _seen_src is not None and _arch_src and _seen_src != _arch_src {
        import from jaclang.cli.console { console }
        console.warning(
            f"native struct name collision -- '{aname}' from "
            f"{_arch_src} shadows the one from {_seen_src}; skipping "
            f"re-registration"
        );
        return;
    }
    if _arch_src {
        self._struct_source_mod[aname] = _arch_src;
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

    self._codegen_archetype(arch, imported=True);
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
                if (
                    self._quiet_glob_type(assign.type_tag.tag) is None
                    and not self._glob_native_use_exists(target)
                ) {
                    continue;
                }
                var_type = self._resolve_jac_type(assign.type_tag.tag);
            }
            _is_pub = bool(nd.access and nd.access.tag.name == Tok.KW_PUB);
            _owner = nd.find_parent_of_type(uni.Module);
            global_var = ir.GlobalVariable(
                self.llvm_module,
                var_type,
                name=self._symbol_for(var_name, _owner, _is_pub)
            );
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

impl NaIRGenPass._forward_declare_imported_ability(
    nd: uni.Ability, unavailable: (set | None) = None, imp_layout: any = None
) -> None {
    name = nd.name_ref.sym_name if nd.name_ref else None;
    if name is None {
        return;
    }
    _owner = nd.find_parent_of_type(uni.Module);
    _owner_name = _owner.name if _owner is not None else "";
    if _owner is not None
        and (os.path.realpath(_owner.source.file_path), name)
            in self._module_functions {
        return;
    }
    _existing = self.func_symtab.get(name);
    if _existing is not None {
        """A second imported module defining the same name declares its
        function under the module-qualified key; the bare name keeps the
        binding it already has. Two `:pub` definitions share one bare
        symbol, which the link plan reports as a collision.""";
        if not _owner_name
            or f"{_owner_name}.{name}" in self.func_symtab
            or self._func_def_mod.get(name) == _owner_name
            or (
                bool(nd.access and nd.access.tag.name == Tok.KW_PUB)
                and self._symbol_for(name, _owner, True) == name
            ) {
            return;
        }
    }

    if nd.body is None {
        return;
    }
    if bool(nd.access and nd.access.tag.name == Tok.KW_PRIV) {
        """A private function of another module is not callable from here;
        it neither declares nor marks its name as demoted.""";
        return;
    }
    if not nd.type_params {
        _fd_demoted = (unavailable is not None and name in unavailable)
            or (
                imp_layout is not None
                and not name.startswith("__")
                and name not in imp_layout.functions
            );
        if _fd_demoted {
            if _owner_name {
                self._native_skipped_methods.add(f"{_owner_name}.{name}");
            }
            if _existing is None {
                self._native_skipped_methods.add(name);
            }
            return;
        }
    }
    _is_pub = bool(nd.access and nd.access.tag.name == Tok.KW_PUB);
    _already = self.llvm_module.globals.get(self._symbol_for(name, _owner, _is_pub));
    if isinstance(_already, ir.Function) {
        """The module already declares this symbol (a kernel walk bound it
        under its bare name without recording the owner): bind it, never
        declare it twice.""";
        if _owner_name {
            self.func_symtab[f"{_owner_name}.{name}"] = _already;
        }
        if _existing is None {
            self.func_symtab[name] = _already;
            if _owner_name {
                self._func_def_mod[name] = _owner_name;
            }
        }
        if _owner is not None {
            self._module_functions[(os.path.realpath(_owner.source.file_path), name)] = _already;
        }
        self._record_linked_decl(_already, nd);
        return;
    }
    _prev_def_mod = self._func_def_mod.get(name);
    self._maybe_declare_ability(nd);
    self._record_linked_decl(self.func_symtab.get(name), nd);
    if _existing is not None {
        self.func_symtab[name] = _existing;
        if _prev_def_mod is not None {
            self._func_def_mod[name] = _prev_def_mod;
        }
    }
}

impl NaIRGenPass._record_linked_decl(
    func: (ir.Function | None), decl: uni.Ability
) -> None {
    if func is None or id(func) in self._linked_fn_decls {
        return;
    }
    self._linked_fn_decls[id(func)] = (func, decl);
}

impl NaIRGenPass._ensure_dep_inference(dep_mod: uni.Module) -> None {
    _provided = self.prog.analysis.analyses_run.provided(dep_mod);
    if 'TypeOf' in _provided {
        return;
    }
    _provided.add('TypeOf');
    try {
        import from jaclang.compiler.driver.pass_driver { run_pass }
        import from jaclang.compiler.passes.cfg_build_pass { CFGBuildPass }
        import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
        if 'CfgSucc' not in _provided {
            run_pass(CFGBuildPass, dep_mod, self.prog);
            _provided.add('CfgSucc');
        }
        run_pass(TypeCheckPass, dep_mod, self.prog);
    } except Exception {
        _provided.discard('TypeOf');
        raise;
    }
}

impl NaIRGenPass._imported_function_demotions(
    imported_mod: uni.Module
) -> (set | None) {
    if imported_mod.gen.native_iface is not None {
        return set(imported_mod.gen.native_iface.demoted);
    }
    iface = self._dep_iface(imported_mod);
    if iface is not None {
        return set(iface.demoted);
    }
    return None;
}

impl NaIRGenPass._process_clib_imports(module: uni.Module) -> None {
    imports = ModuleFacts.iter_module_imports(module)
        + ModuleFacts.iter_nested_imports(module, CodeContext.NATIVE);
    for stmt in imports {
        if not stmt.clib_decls {
            if stmt.items {
                for item in stmt.items {
                    import os;
                    import from jaclang.compiler.passes.capability_check_pass {
                        classify_native_import
                    }
                    import from jaclang.compiler.frontend.codeinfo {
                        is_bundled_native_module,
                        resolve_native_module
                    }
                    (mod_name, _supported) = classify_native_import(item);
                    if _supported and mod_name is not None {
                        self._native_stdlib_modules.add(mod_name);
                    } elif mod_name is not None
                        and is_bundled_native_module(mod_name) {
                        self._native_module_imports.add(mod_name);
                    } elif (
                        mod_name is not None
                        and not stmt.is_absorb
                        and isinstance(item, uni.ModulePath)
                    ) {
                        _mb = os.path.dirname(os.path.abspath(module.loc.mod_path))
                            if module?.loc
                            else '.';
                        if resolve_native_module(mod_name, _mb)[1] is not None {
                            self._native_module_imports.add(mod_name);
                        }
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

impl NaIRGenPass._ensure_emitters -> dict[str, object] {
    if self._native_emitters is not None {
        return self._native_emitters;
    }
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    import jaclang.compiler.backends.native.primitives_native as _pn;
    emitters: dict[str, object] = {};
    for (_tn, _suffix) in JAC_TYPE_REGISTRY.emitter_items() {
        _ecls = getattr(_pn, "Native" + _suffix, None);
        if _ecls is not None {
            emitters[_tn] = _ecls();
        }
    }
    self._native_builtin_emitter = _pn.NativeBuiltinEmitter();
    self._native_emitters = emitters;
    return emitters;
}

impl NaIRGenPass._primitive_method_names(type_name: str) -> set[str] {
    import inspect;
    if self._primitive_method_name_cache is None {
        self._primitive_method_name_cache = {};
    }
    _cached = self._primitive_method_name_cache.get(type_name);
    if _cached is not None {
        return _cached;
    }
    _names: set[str] = set();
    _emitter = self._ensure_emitters().get(type_name);
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
    target = self._str_norm(target);
    args = [self._str_norm(_a) for _a in args];
    _emitter = self._ensure_emitters().get(type_name);
    if _emitter is None {
        return None;
    }
    _emit_fn = getattr(_emitter, "emit_" + method_name, None);
    if _emit_fn is None {
        return None;
    }
    if kwargs and method_name not in ("sort", ) {
        self.emit(
            E5092,
            node_override=kw_node,
            kind="keyword argument for native method",
            name=f"{method_name}({', '.join(kwargs.keys())}=...)"
        );
        return None;
    }
    _ctx = NativeEmitCtx(pass_ref=self, type_key=type_key, call_kwargs=(kwargs or {}));
    try {
        return _emit_fn(_ctx, target, args);
    } except Exception as _pm_exc {
        if self._na_debug_on() {
            import sys as _pm_sys;
            import traceback as _pm_tb;
            _pm_sys.stderr.write(f"NA_DEBUG primitive {type_name}.{method_name}\n");
            _pm_tb.print_exc(file=_pm_sys.stderr);
        }
        self.emit(
            E5092,
            node_override=kw_node,
            kind="primitive method",
            name=f"{type_name}.{method_name}",
            help_text=f"The emitter for this builtin method raised "
            f"{type(_pm_exc).__name__} on the operands it was given, which "
            "means an argument did not reach the shape it expects -- most "
            "often a container or tuple where a scalar or string is "
            f"required. Original error: {_pm_exc}"
        );
        return None;
    }
}

impl NaIRGenPass._dispatch_builtin(
    func_name: str,
    args: list[ir.Value],
    kwargs: (dict | None) = None,
    kw_node: (uni.UniNode | None) = None,
    type_key: str = "",
    arg_nodes: (list | None) = None
) -> (ir.Value | None) {
    args = [self._str_norm(_a) for _a in args];
    self._ensure_emitters();
    if (
        func_name == "str"
        and len(args) == 1
        and self._opt_payload_of(args[0].type) is not None
    ) {
        return self._emit_optional_str(args[0], None);
    }
    _emit_fn = getattr(self._native_builtin_emitter, "emit_" + func_name, None);
    if _emit_fn is None {
        return None;
    }
    if kwargs and func_name not in ("sorted", ) {
        self.emit(
            E5092,
            node_override=kw_node,
            kind="keyword argument for native builtin",
            name=f"{func_name}({', '.join(kwargs.keys())}=...)"
        );
        return None;
    }
    _ctx = NativeEmitCtx(
        pass_ref=self,
        type_key=type_key,
        call_kwargs=(kwargs or {}),
        arg_nodes=(arg_nodes or []),
        call_node=kw_node
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
    for (ct_name, ct_expr) in self._ct_ctor_slots(nd.target) {
        out[ct_name] = ct_expr;
    }
    return out;
}

impl NaIRGenPass._ct_ctor_slots(target: uni.UniNode) -> list[tuple[str, uni.UniNode]] {
    out: list[tuple[str, uni.UniNode]] = [];
    if not isinstance(target, uni.AtomTrailer) or target.is_attr {
        return out;
    }
    if not isinstance(target.right, uni.IndexSlice) or target.right.is_range {
        return out;
    }
    t = target.target.type;
    if not isinstance(t, ClassType) {
        return out;
    }
    shared = t.shared;
    if not shared.ct_params {
        return out;
    }
    arch = shared.symbol_table;
    if not isinstance(arch, uni.Archetype) {
        return out;
    }
    s0 = target.right.slices[0] if target.right.slices else None;
    head = s0.start if s0 is not None else None;
    vals: list[uni.UniNode] = `list(head.values)
        if isinstance(head, uni.TupleVal)
        else ([head] if head else []);
    for (i, tp) in enumerate(arch.type_params or []) {
        if tp.is_comptime and i < len(vals) {
            out.append((tp.name.value, vals[i], ));
        }
    }
    return out;
}

impl NaIRGenPass.transform(ir_in: uni.Module) -> uni.Module {
    self.ir_out = ir_in;
    ir_in spawn self;
    if self.errors_had {
        self.prog.native_units().failures[os.path.realpath(ir_in.loc.mod_path)] = "Native module lowering failed:\n"
            + "\n".join(alert.pretty_print() for alert in self.errors_had);
    }
    out = self.ir_out;
    assert isinstance(out, uni.Module);
    return out;
}

impl NaIRGenPass.run_walk with uni.Module entry {
    self.ir_out = self._run_impl(here);
}
