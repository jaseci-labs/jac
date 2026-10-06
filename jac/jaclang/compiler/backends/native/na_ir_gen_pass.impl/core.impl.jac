import from jaclang.compiler.driver.pipeline_types { AnalysisFact }
def scalar_llvm_type(`entry: JacTypeEntry) -> ir.Type {
    if `entry.is_float {
        return ir.FloatType() if `entry.width == 32 else ir.DoubleType();
    }
    return ir.IntType(`entry.width);
}

def _source_param_names(func: ir.Function) -> list[str] {
    names: list[str] = [];
    for arg in func.args {
        (stem, _, suffix) = arg.name.rpartition(".");
        names.append(stem if stem and suffix.isdigit() else arg.name);
    }
    return names;
}

impl NaIRGenPass.postinit -> None {
    import os as _ni_os;

    self.lower = take_native_lowering(self.module, self.prog, self.ctx);

    _ni_opts = self.prog.options;
    self._rc_debug_codegen = bool(_ni_opts.rc_debug_codegen);
    _ni_src: str = self.module.loc.mod_path if self.module.loc else "";
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
    self.lower._unit_prefix = native_unit_prefix(_ni_src) if _ni_src else "jac_native";

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
    self.type_map["complex"] = self.complex_struct_type.as_pointer();

    self._range_struct_type = self.llvm_module.context.get_identified_type("JacRange");
    self.range_struct_type.set_body(ir.IntType(64), ir.IntType(64), ir.IntType(64));
    self.type_map["range"] = self.range_struct_type.as_pointer();

    self._slice_struct_type = self.llvm_module.context.get_identified_type("JacSlice");
    self.slice_struct_type.set_body(ir.IntType(64), ir.IntType(64), ir.IntType(64));

    self._jacval_type = self.llvm_module.context.get_identified_type("JacVal");
    self.jacval_type.set_body(ir.IntType(8), ir.IntType(64));
}

impl NaIRGenPass._run_impl(ir_in: uni.Module) -> uni.Module {
    self._capability_demotions = {};
    self._claimed_capability_demotions = set();
    _demotable = self.lower._run_impl_capability_demotions();
    if _demotable is None {
        return self.module;
    }
    self._capability_demotions = _demotable;

    self._emit_rc_helpers();

    self._process_clib_imports(self.module);

    self._register_enums(self.module);

    self._forward_declare_archetype_names(self.module);

    self._register_imported_struct_types();
    self._declare_pending_clib_abilities();
    self._register_globals(self.module);
    self._register_entry_globals(self.module);

    self._register_enum_methods(self.module, declare=True);
    self._register_archetypes(self.module);
    self._register_enum_methods(self.module, declare=False);

    _entry_nodes: list[uni.ModuleCode] = [];
    for stmt in self.lower._run_impl_native_stmts() {
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
    self._propagate_seam_demotions();
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
        return self.module;
    }
    self._codegen_entry(_entry_nodes);
    self._finalize_trace_lookup();
    self._finish_osp_reclaim_hook();

    if self.has_native_code {
        if self.ctx.errors_had {
            return self.module;
        }
        if "__jac_glob_init" not in self.func_symtab {
            self._emit_glob_init_func();
        }
        self.module.gen.llvm_ir = self.llvm_module;
        self.module.gen.native_deps = list(self.lower._native_dep_paths);

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
                f"rc-stats [{os.path.basename(self.module.loc.mod_path)}] "
                f"gc={self.lower._gc_mode()} retains={self.rc_retains_emitted} "
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
    return self.module;
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
        native_module_key,
        native_unit_spelling
    }
    mod_path = self.module.loc.mod_path if self.module?.loc else "";
    iface = NativeIface(
        module=native_module_key(mod_path) if mod_path else "",
        prefix=self.lower._own_prefix(),
        headerless=self.lower._nogc_headerless()
    );
    layout = self.module.gen.native_layout;
    iface.layout = layout;
    for (name, ex) in self.lower._unit_exports.items() {
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
        spelled = native_unit_spelling(name, mod_path);
        ex.name = spelled;
        iface.exports[spelled] = ex;
    }
    import json;
    for (cname, native_body) in self._build_class_layouts().items() {
        body = json.loads(native_unit_spelling(json.dumps(native_body), mod_path));
        iface.classes[native_unit_spelling(cname, mod_path)] = NativeClassLayout(
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
    for (ename, members) in self.lower.enum_string_values.items() {
        if self._enum_source_name.get(ename, self.module.name) == self.module.name {
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
    iface.clib_paths = list(self.module.gen._clib_paths or []);
    iface.python_imports = [
        binding.name for binding in self.module.gen.interop_manifest.native_imports
    ];
    iface.clib_symbol_lib = dict(self.module.gen._clib_symbol_lib or {});
    iface.deps = list(self.lower._native_dep_paths);
    try {
        import from jaclang.compiler.driver.na_coverage { na_coverage_capture }
        iface.coverage = na_coverage_capture(mod_path) if mod_path else {};
    } except Exception {
        iface.coverage = {};
    }
    self.module.gen.native_iface = iface;
    self.module.gen.native_deps = list(self.lower._native_dep_paths);
}

impl NaIRGenPass._build_class_layouts -> dict[str, any] {
    return dict(self._build_jc_layout().get("classes", {}));
}

impl NaIRGenPass._predemote_capability_unit(
    full_name: str,
    func: ir.Function,
    viols: list[tuple[uni.UniNode, str, str, str | None]],
    keep_func: bool = False
) -> bool {
    _local_mark = self.lower._predemote_capability_unit_report(viols);
    return self._demote_method_if_unlowerable(
        full_name, func, _local_mark, keep_func=keep_func
    );
}

impl NaIRGenPass._rename_demoted_symbol(name: str, func: ir.Function) -> None {
    self._demoted_names.add(name);
    self.lower._unit_exports.pop(name, None);
    try {
        self.llvm_module.globals.pop(func.name, None);
        func.name = f"{func.name}.__jac_demoted";
        self.llvm_module.globals[func.name] = func;
    } except Exception {}
}

impl NaIRGenPass._propagate_seam_demotions -> None {
    """Demote every lowered function, method, and test that still reaches a seam
    stub. A caller lowered before its callee demoted holds a direct call to the
    callee's abort stub: the call-site check only sees demotions that already
    happened. Demoting such a caller can strand its own earlier callers, so this
    runs to a fixpoint after the module's bodies are lowered.""";
    if not self._seam_stub_ids {
        return;
    }
    method_names = {id(fn): name for (name, fn) in self.method_funcs.items()};
    owners: list[tuple[str, ir.Function, uni.Ability, bool]] = [];
    for (_fid, (func, decl)) in self._linked_fn_decls.items() {
        if func is None or not func.blocks or id(func) in self._seam_stub_ids {
            continue;
        }
        if id(func) in method_names {
            owners.append((method_names[id(func)], func, decl, True));
        } elif decl.name_ref is not None
            and self.func_symtab.get(decl.name_ref.sym_name) is func {
            owners.append((decl.name_ref.sym_name, func, decl, False));
        }
    }
    changed = True;
    while changed {
        changed = False;
        for (name, func, decl, is_method) in owners {
            if id(func) in self._seam_stub_ids {
                continue;
            }
            reached = self._reaches_seam_stub(func, set());
            if reached is None {
                continue;
            }
            mark = len(self.ctx.errors_had);
            self.emit(
                E5092,
                node_override=decl,
                kind="function",
                name=reached,
                help_text=f"'{reached}' demoted to its Python-only implementation "
                f"(native seam), so '{name}' cannot reach it natively; hoist the "
                f"blocking construct out of '{reached}' or move '{name}' off the "
                f"native pathway."
            );
            if self._demote_method_if_unlowerable(name, func, mark, keep_func=is_method)
                and not is_method {
                self._rename_demoted_symbol(name, func);
            }
            changed = True;
        }
    }
    for (symbol, nd) in list(self._native_test_nodes.items()) {
        func = self.llvm_module.globals.get(symbol);
        if not isinstance(func, ir.Function) or id(func) in self._seam_stub_ids {
            continue;
        }
        reached = self._reaches_seam_stub(func, set());
        if reached is None {
            continue;
        }
        mark = len(self.ctx.errors_had);
        self.emit(
            E5092,
            node_override=nd,
            kind="function",
            name=reached,
            help_text=f"'{reached}' demoted to its Python-only implementation "
            f"(native seam); the test runs in the server codespace instead."
        );
        self._demote_native_test(nd, func, mark);
    }
}

impl NaIRGenPass._reaches_seam_stub(func: ir.Function, seen: set[int]) -> (str | None) {
    """The name of a seam stub `func` calls or references, directly or through the
    private helpers (lambdas, closure bodies) it lowered, or None.""";
    seen.add(id(func));
    for blk in func.blocks {
        for instr in blk.instructions {
            if not isinstance(instr, ir.Instruction) {
                continue;
            }
            for op in instr.operands {
                if not isinstance(op, ir.Function) or id(op) in seen {
                    continue;
                }
                if id(op) in self._seam_stub_ids {
                    linked = self._linked_fn_decls.get(id(op));
                    if linked is not None and linked[1].name_ref is not None {
                        return linked[1].name_ref.sym_name;
                    }
                    return op.name.removesuffix(".__jac_demoted");
                }
                if op.blocks and op.linkage in ("private", "internal") {
                    found = self._reaches_seam_stub(op, seen);
                    if found is not None {
                        return found;
                    }
                }
            }
        }
    }
    return None;
}

impl NaIRGenPass._llvm_type_str(
    ty: ir.Type, pointee_names: dict[(ir.Type, str)]
) -> str {
    _opt_pt = self._opt_payload_of(ty);
    if _opt_pt is not None {
        return "opt." + self._llvm_type_str(_opt_pt, pointee_names);
    }
    if self._str_desc_ty is not None and ty == self._str_desc_ty {
        return self.lower._str_desc_kind();
    }
    if isinstance(ty, ir.IntType) {
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
            return pointee_names.get(ty.pointee, "ptr");
        }
        return "ptr";
    }
    return "i64";
}

impl NaIRGenPass._layout_pointee_names -> dict[(ir.Type, str)] {
    names: dict[(ir.Type, str)] = {};
    for (sname, stype) in self.struct_types.items() {
        names.setdefault(stype, f"{sname}*");
    }
    for (ename, ltype) in self.list_types.items() {
        names.setdefault(ltype, f"List.{ename}*");
    }
    for ttype in self.tuple_types.values() {
        names.setdefault(ttype, "Tuple*");
    }
    for dtype in self.dict_types.values() {
        names.setdefault(dtype, f"{dtype.name}*");
    }
    for setype in self.set_types.values() {
        names.setdefault(setype, f"{setype.name}*");
    }
    return names;
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
    layout = NativeModuleLayout(str_headerless=self.lower._nogc_headerless());
    pointee_names = self._layout_pointee_names();
    struct_names: dict[(ir.Type, str)] = {};
    for (sname, stype) in self.struct_types.items() {
        struct_names.setdefault(stype, sname);
    }
    tuple_keys: dict[(ir.Type, str)] = {};
    for (tkey, ttype) in self.tuple_types.items() {
        tuple_keys.setdefault(ttype, tkey);
    }

    for (arch_name, field_indices) in self.lower.struct_field_indices.items() {
        field_types = self.struct_field_types.get(arch_name, {});
        fields: list[NativeFieldInfo] = [];
        field_enums = self.struct_field_enum_type.get(arch_name, {});
        elem_keys = self.struct_field_elem_keys.get(arch_name, {});
        _foreign_flds = self.struct_field_foreign.get(arch_name, set());
        for (fname, idx) in sorted(field_indices.items(), key=lambda (x) { x[1]; }) {
            ftype = field_types.get(fname);
            llvm_t = self._llvm_type_str(ftype, pointee_names)
                if ftype is not None
                else "i64";

            is_fn_ptr = False;
            fn_param_types: (list[str] | None) = None;
            fn_ret_type: (str | None) = None;
            if (
                ftype is not None
                and isinstance(ftype, ir.PointerType)
                and isinstance(ftype.pointee, ir.FunctionType)
            ) {
                is_fn_ptr = True;
                fn_param_types = [
                    self._llvm_type_str(a, pointee_names) for a in ftype.pointee.args
                ];
                fn_ret_type = self._llvm_type_str(
                    ftype.pointee.return_type, pointee_names
                );
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

    for (enum_name, entries) in self.lower.enum_string_values.items() {
        layout.enums[enum_name] = NativeEnumLayout(
            name=enum_name, is_string_valued=True, members=list(entries)
        );
    }

    for (tkey, ttype) in self.tuple_types.items() {
        elem_types = [self._llvm_type_str(e, pointee_names) for e in ttype.elements];
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
        if fname in self._clib_symbol_lib and self.clib_extern_fns.get(fname) is func {
            continue;
        }
        param_types = [
            self._llvm_type_str(a, pointee_names) for a in func.function_type.args
        ];
        param_names = _source_param_names(func);
        ret_type = self._llvm_type_str(func.function_type.return_type, pointee_names);
        ret_struct: (str | None) = None;
        ret_tuple: (NativeTupleLayout | None) = None;
        if isinstance(func.function_type.return_type, ir.PointerType) {
            ret_struct = struct_names.get(func.function_type.return_type.pointee);

            tkey = tuple_keys.get(func.function_type.return_type.pointee)
                if ret_type.startswith("Tuple")
                else None;
            if tkey is not None {
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
            }
        }

        ret_enum: (str | None) = None;
        if ret_type in ("i64", "opt.i64") {
            _rkey = self.lower.func_ret_type_key.get(fname);
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

        ret_elem: (list[str | None] | None) = None;
        if (
            ret_type.startswith("List.")
            or ret_type.startswith("Dict.")
            or ret_type.startswith("Set.")
        ) {
            ret_elem = self.lower.func_ret_elem_keys.get(fname);
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
        param_types = [
            self._llvm_type_str(a, pointee_names) for a in func.function_type.args
        ];
        param_names = _source_param_names(func);
        ret_type = self._llvm_type_str(func.function_type.return_type, pointee_names);
        ret_struct: (str | None) = None;
        if isinstance(func.function_type.return_type, ir.PointerType) {
            ret_struct = struct_names.get(func.function_type.return_type.pointee);
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
    self.module.gen.native_layout = layout;
}

impl NaIRGenPass._exported_accessors(arch_name: str) -> dict[(str, dict[(str, str)])] {
    out: dict[(str, dict[(str, str)])] = {};
    lay = self.lower._arch_layout(arch_name);
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

impl NaIRGenPass._ret_tuple_hints(
    fname: str, ret_tuple: any
) -> (list[str | None] | None) {
    keys = self.lower.func_ret_elem_keys.get(fname);
    if not keys or len(keys) != len(ret_tuple.element_types) {
        return None;
    }
    hints: list[str | None] = [];
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

    manifest = self.module.gen.interop_manifest;
    (imported_mods, dep_edges, typed_only) = self.lower._register_imported_struct_types_discover();
    self._typed_only_imports = {
        k
        for (k, v) in typed_only.items()
        if v
    };

    self.lower._register_imported_struct_types_note_deps(dep_edges, typed_only);

    imported_mods = self.lower._permuted_walk_order(imported_mods);

    for (_, imported_mod) in imported_mods {
        self._process_clib_imports(imported_mod);
    }

    for (_, imported_mod) in imported_mods {
        self._walk_imported_module_type_names(imported_mod);
    }

    self._declare_pending_clib_abilities();

    for (_, imported_mod) in imported_mods {
        self.lower._register_imported_hierarchy(imported_mod);
    }

    import from jaclang.compiler.passes.layout_pass { adopt_imported_bases }
    adopt_imported_bases(self.module);

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

impl NaIRGenPass._walk_imported_module_type_names(imported_mod: uni.Module) -> None {
    for stmt in self.lower._walk_imported_module_stmts(imported_mod) {
        if self.lower._walk_imported_module_skips(stmt) {
            continue;
        }
        if isinstance(stmt, uni.Archetype) {
            aname = self.lower._arch_key(stmt) if stmt.name else None;
            if aname is not None and aname not in self.struct_types {
                struct_type = self.llvm_module.context.get_identified_type(aname);
                self.struct_types[aname] = struct_type;
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
    for stmt in self.lower._walk_imported_module_stmts(imported_mod) {
        if self.lower._walk_imported_module_skips(stmt) {
            continue;
        }
        if isinstance(stmt, uni.Archetype) {
            self._register_imported_archetype(stmt);

            self.lower._walk_imported_module_types_note_osp(stmt, imported_mod);
        } elif isinstance(stmt, uni.Enum) {
            self._codegen_enum(stmt);
            for method in self.lower._enum_methods(stmt) {
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
    (_imp_layout, _wl_internal, _imp_fn_unavail) = self.lower._walk_imported_module_abilities_verdicts(
        imported_mod, with_fn_verdicts
    );
    for _im_full in self.lower._walk_imported_module_abilities_skipped(
        imported_mod, _imp_layout, _wl_internal, _imp_fn_unavail
    ) {
        self._native_skipped_methods.add(_im_full);
    }
    for stmt in self.lower._walk_imported_module_stmts(imported_mod) {
        if self.lower._walk_imported_module_skips(stmt) {
            continue;
        }
        if isinstance(stmt, uni.Archetype) {
            self._forward_declare_archetype_methods(stmt);
        }
    }

    for stmt in self.lower._walk_imported_module_stmts(imported_mod) {
        if self.lower._walk_imported_module_skips(stmt) {
            continue;
        }
        if isinstance(stmt, uni.Ability) {
            self._forward_declare_imported_ability(stmt, _imp_fn_unavail, _imp_layout);
        }
    }
}

impl NaIRGenPass._forward_declare_archetype_methods(arch: uni.Archetype) -> None {
    aname = self.lower._arch_key(arch) if arch.name else None;
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

impl NaIRGenPass._register_imported_archetype(arch: uni.Archetype) -> None {
    aname = self.lower._arch_key(arch) if arch.name else None;
    if aname is None {
        return;
    }

    _arch_src = os.path.realpath(arch.loc.mod_path) if arch.loc.mod_path else "";
    _seen_src = self.lower._struct_source_mod.get(aname);
    if _seen_src is not None and _arch_src and _seen_src != _arch_src {
        import from jaclang.compiler.frontend.host { active_host }
        active_host().note(
            f"native struct name collision -- '{aname}' from "
            f"{_arch_src} shadows the one from {_seen_src}; skipping "
            f"re-registration",
            style="warning"
        );
        return;
    }
    if _arch_src {
        self.lower._struct_source_mod[aname] = _arch_src;
    }

    if aname not in self.struct_types {
        struct_type = self.llvm_module.context.get_identified_type(aname);
        self.struct_types[aname] = struct_type;
    }

    if aname in self._struct_bodies_done {
        return;
    }

    for _anc in self.lower._mro_of(aname) {
        if (
            _anc != aname
            and _anc in self.lower.arch_ast_map
            and _anc not in self._struct_bodies_done
        ) {
            _anc_arch = self.lower.arch_ast_map[_anc];
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
            var_name = self.lower._get_name(target);
            if var_name is None or var_name in self.global_vars {
                continue;
            }
            var_type: ir.Type = ir.IntType(64);
            if assign.type_tag and assign.type_tag.tag {
                if (
                    self._quiet_glob_type(assign.type_tag.tag) is None
                    and not self.lower._glob_native_use_exists(target)
                ) {
                    continue;
                }
                var_type = self._resolve_jac_type(assign.type_tag.tag);
            } elif assign.value is not None {
                inferred = self._infer_global_init_type(assign.value);
                if inferred is not None {
                    var_type = inferred;
                }
            }
            global_var = ir.GlobalVariable(
                self.llvm_module,
                var_type,
                name=self.lower._register_imported_globals_symbol(nd, var_name)
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
                and self.lower._symbol_for(name, _owner, True) == name
            ) {
            return;
        }
    }

    _fd_demoted = self.lower._forward_declare_imported_ability_demoted(
        nd, name, unavailable, imp_layout
    );
    if _fd_demoted is None {
        return;
    }
    if _fd_demoted {
        if _owner_name {
            self._native_skipped_methods.add(f"{_owner_name}.{name}");
        }
        if _existing is None {
            self._native_skipped_methods.add(name);
        }
        if _owner is not None {
            self.lower._native_skipped_import_origin.setdefault(name, set()).add(
                os.path.realpath(_owner.source.file_path)
            );
        }
        return;
    }
    _is_pub = bool(nd.access and nd.access.tag.name == Tok.KW_PUB);
    _already = self.llvm_module.globals.get(self.lower._symbol_for(name, _owner, _is_pub));
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
    self._maybe_declare_ability(nd, imp_layout);
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

impl NaIRGenPass._process_clib_imports(module: uni.Module) -> None {
    imports = self.lower._process_clib_imports_stmts(module);
    for stmt in imports {
        if not stmt.clib_decls {
            self.lower._process_clib_imports_note_modules(stmt, module);
            continue;
        }

        _paths_before = len(self._clib_paths);
        if stmt.from_loc is not None and stmt.from_loc.path {
            (_raw_paths, _name_components) = self.lower._process_clib_imports_lib_parts(
                stmt
            );
            self._clib_paths.extend(_raw_paths);
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
                    self.lower.clib_struct_names.add(arch_name);
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

                if self.lower._process_clib_imports_has_body(decl) {
                    self.emit(E5060, name=fn_name);
                    continue;
                }
                self._pending_clib_abilities.append(decl);
                if fn_name {
                    self.clib_extern_names.add(fn_name);
                    if _cur_lib is not None {
                        self._clib_symbol_lib[fn_name] = _cur_lib;
                    }
                }
            }
        }

        if self._clib_paths {
            self.module.gen._clib_paths = list(self._clib_paths);
            self.module.gen._clib_symbol_lib = dict(self._clib_symbol_lib);
            self.has_native_code = True;
        }
    }
}

impl NaIRGenPass._declare_pending_clib_abilities -> None {
    pending = self._pending_clib_abilities;
    self._pending_clib_abilities = [];
    for ability in pending {
        self._declare_clib_ability(ability);
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
    import jaclang.compiler.backends.native.primitives_native as _pn;
    emitters: dict[str, object] = {};
    for (_tn, _suffix) in self.lower._ensure_emitters_items() {
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
    kwargs: (dict[str, uni.UniNode] | None) = None,
    kw_node: (uni.UniNode | None) = None
) -> (ir.Value | None) {
    target = self._str_norm(target);
    originals = list(args);
    args = [self._str_borrow(_a) for _a in args];
    _emitter = self._ensure_emitters().get(type_name);
    if _emitter is None {
        return None;
    }
    _emit_fn = getattr(_emitter, "emit_" + method_name, None);
    if _emit_fn is None {
        return None;
    }
    if kwargs and not self.lower._primitive_method_takes_kwargs(type_name, method_name) {
        self.emit(
            E5092,
            node_override=kw_node,
            kind="keyword argument for native method",
            name=f"{method_name}({', '.join(kwargs.keys())}=...)"
        );
        return None;
    }
    _ctx = NativeEmitCtx(pass_ref=self, type_key=type_key, call_kwargs=(kwargs or {}));
    if isinstance(kw_node, uni.FuncCall)
        and isinstance(kw_node.target, uni.AtomTrailer) {
        _ctx.receiver_node = kw_node.target.target;
    }
    try {
        result = _emit_fn(_ctx, target, args);
        if result is not None {
            self._consume_str_args(originals);
        }
        return result;
    } except Exception as _pm_exc {
        if self.lower._na_debug_on() {
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
    kwargs: (dict[str, uni.UniNode] | None) = None,
    kw_node: (uni.UniNode | None) = None,
    type_key: str = "",
    arg_nodes: (list[uni.UniNode] | None) = None
) -> (ir.Value | None) {
    originals = list(args);
    args = [self._str_borrow(_a) for _a in args];
    self._ensure_emitters();
    if (
        func_name == "str"
        and len(args) == 1
        and self._opt_payload_of(args[0].type) is not None
    ) {
        return self._emit_optional_str(args[0], arg_nodes[0] if arg_nodes else None);
    }
    _emit_fn = getattr(self._native_builtin_emitter, "emit_" + func_name, None);
    if _emit_fn is None {
        return None;
    }
    if kwargs and not self.lower._dispatch_builtin_takes_kwargs(func_name) {
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
    result = _emit_fn(_ctx, args);
    if result is not None {
        self._consume_str_args(originals);
    }
    return result;
}

impl NaIRGenPass.run_walk with uni.Module entry {
    self.module = self._run_impl(here);
    if self.ctx.errors_had {
        self.prog.native_units().failures[os.path.realpath(here.loc.mod_path)] = "Native module lowering failed:\n"
            + "\n".join(alert.pretty_print() for alert in self.ctx.errors_had);
    }
}
