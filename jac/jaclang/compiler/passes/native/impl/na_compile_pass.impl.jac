impl native_compiler_fingerprint(options: any) -> str {
    import glob as _cgl;
    import hashlib as _cfh_hash;
    import os as _cfp_os;
    import jaclang as _jlm;
    _jl_dir = _cfp_os.path.dirname(_cfp_os.path.abspath(_jlm.__file__));
    _nat_dir = _cfp_os.path.join(_jl_dir, "compiler", "passes", "native");
    _comp_h = _cfh_hash.sha256();
    for _cp in [
        _cfp_os.path.join(_nat_dir, "impl", "*.jac"),
        _cfp_os.path.join(_nat_dir, "na_ir_gen_pass.impl", "*.jac"),

    ] {
        for _cf in sorted(_cgl.glob(_cp)) {
            try {
                with open(_cf, "rb") as _cfh {
                    _comp_h.update(_cfh.read());
                }
            } except Exception { }
        }
    }
    _comp_h.update(options.codegen_identity().encode());
    return _comp_h.hexdigest()[:8];
}

impl native_dep_cache_paths(real_path: str, options: any) -> tuple {
    import hashlib as _dcp_hash;
    import os as _dcp_os;
    import from jaclang.jac0core.jir { get_native_cache_dir }
    _ir_cache_dir = str(get_native_cache_dir(real_path));
    _src_stem = _dcp_os.path.splitext(_dcp_os.path.basename(real_path))[0];
    with open(real_path, "rb") as _sf {
        _source_hash = _dcp_hash.sha256(_sf.read()).hexdigest()[:12];
    }
    _fp = native_compiler_fingerprint(options);
    return (
        _dcp_os.path.join(_ir_cache_dir, f"{_src_stem}.{_source_hash}.{_fp}.ir_cache"),
        _dcp_os.path.join(_ir_cache_dir, f"{_src_stem}.{_source_hash}.{_fp}.ir_meta")
    );
}

impl DepClibMeta.to_meta -> dict {
    return {
        "clib_paths": self.clib_paths,
        "clib_symbol_lib": self.clib_symbol_lib,
        "exported_symbols": self.exported_symbols,
        "imported_symbols": self.imported_symbols,
        "owned_symbols": self.owned_symbols,
        "transitive_deps": self.transitive_deps,
        "options_fingerprint": self.options_fingerprint
    };
}

impl DepClibMeta.from_meta(meta: dict) -> DepClibMeta {
    return DepClibMeta(
        clib_paths=meta.get("clib_paths", []),
        clib_symbol_lib=meta.get("clib_symbol_lib", {}),
        exported_symbols=meta.get("exported_symbols", []),
        imported_symbols=meta.get("imported_symbols", []),
        owned_symbols=meta.get("owned_symbols", []),
        transitive_deps=meta.get("transitive_deps", []),
        options_fingerprint=meta.get("options_fingerprint", "")
    );
}

impl DepClibMeta.propagate_to(gen: CodeGenTarget) -> None {
    for _p in self.clib_paths {
        if _p not in gen._clib_paths {
            gen._clib_paths.append(_p);
        }
    }
    for (_sym, _dll) in self.clib_symbol_lib.items() {
        if _sym not in gen._clib_symbol_lib {
            gen._clib_symbol_lib[_sym] = _dll;
        }
    }
    for _e in self.exported_symbols {
        if _e not in gen._exported_symbols {
            gen._exported_symbols.append(_e);
        }
    }
}

impl NativeCompilePass.postinit -> None {
    llvm.initialize_native_target();
    llvm.initialize_native_asmprinter();
    super.postinit();
}

impl NativeCompilePass.transform(ir_in: uni.Module) -> uni.Module {
    module = ir_in;
    if module.gen.llvm_ir is None {
        return ir_in;
    }

    _compile_opts = self.prog._compile_options;

    if _compile_opts.skip_native_engine {
        return ir_in;
    }
    llvm_ir_str = str(module.gen.llvm_ir);
    try {
        import ctypes as _ct;
        import ctypes.util;
        libc_name = ctypes.util.find_library("c")
            if not _compile_opts.aot_mode
            else None;
        if libc_name {
            llvm.load_library_permanently(libc_name);
        }

        import os;
        clib_paths = module.gen._clib_paths;
        if _compile_opts.aot_mode {
            clib_paths = None;
        }
        if clib_paths {
            for lib_path in clib_paths {
                try {
                    if not self._jit_load_clib(lib_path) {
                        self.emit(W5021, path=lib_path);
                    }
                } except Exception as lib_err {
                    self.emit(W5022, path=lib_path, error=str(lib_err));
                }
            }
        }
        mod = llvm.parse_assembly(llvm_ir_str);
        mod.verify();

        _nc_target_ovr = _compile_opts.native_target or "";
        if _nc_target_ovr {
            llvm.initialize_all_targets();
            llvm.initialize_all_asmprinters();
            target = llvm.Target.from_triple(_nc_target_ovr);
        } else {
            target = llvm.Target.from_default_triple();
        }

        _native_debug: bool = bool(_compile_opts.native_debug);
        if _native_debug {
            target_machine = target.create_target_machine(opt=0, jit=True);
        } else {
            target_machine = target.create_target_machine(jit=True);
        }

        manifest = module.gen.interop_manifest;
        native_imports = manifest.native_imports;
        if native_imports {
            import from jaclang.jac0core.interop_bridge { register_py_callbacks }
            py_func_table: dict = {};
            callbacks_list: list = [];
            register_py_callbacks(manifest, py_func_table, callbacks_list);
            module.gen.interop_py_funcs = py_func_table;
            module.gen._interop_callbacks = callbacks_list;
        }

        cross_module_imports = manifest.native_cross_module_imports;
        if cross_module_imports {
            self._compile_and_link_native_imports(
                module, mod, cross_module_imports, target_machine
            );

            module.gen.llvm_ir = mod;
        }

        _needs_osp_kernel = (manifest is not None)
            and ("osp_kernel" in manifest.native_transitive_sources);
        if (not _needs_osp_kernel) and self._references_undefined_osp_kernel(mod) {
            _needs_osp_kernel = True;
        }
        if _needs_osp_kernel {
            self._link_osp_kernel(mod);
            module.gen.llvm_ir = mod;
        }

        _needs_fmt_kernel = (manifest is not None)
            and ("fmt_kernel" in manifest.native_transitive_sources);
        if (not _needs_fmt_kernel) and self._references_undefined_fmt_kernel(mod) {
            _needs_fmt_kernel = True;
        }
        if _needs_fmt_kernel {
            self._link_fmt_kernel(mod);
            module.gen.llvm_ir = mod;
        }

        import os as _os;
        _opt_level = int(_compile_opts.opt_level or 0);

        if _native_debug {
            _opt_level = 0;
        }
        if _opt_level > 0 {
            pto = llvm.create_pipeline_tuning_options(speed_level=_opt_level);
            pb = llvm.create_pass_builder(target_machine, pto);
            opt_mpm = pb.getModulePassManager();
            opt_mpm.run(mod, pb);
        }

        _dump_path = _compile_opts.dump_ir_path or "";
        if _dump_path {
            with open(_dump_path, "w") as _f {
                _f.write(str(mod));
            }
        }

        module.gen.native_bitcode = mod.as_bitcode();

        _debug_obj_path = "";
        _ir_dir = "";
        _stem = "";
        if _native_debug {
            import from jaclang.jac0core.jir { get_native_cache_dir }
            _mod_path = module.loc.mod_path if module.loc else "jac_native";
            _src_name = _os.path.basename(_mod_path);
            _stem = _os.path.splitext(_src_name)[0];
            _ir_dir = str(get_native_cache_dir(_mod_path));
            _os.makedirs(_ir_dir, exist_ok=True);
            try {
                _obj_bytes = target_machine.emit_object(mod);
                _debug_obj_path = _os.path.join(_ir_dir, _stem + ".debug.o");
                with open(_debug_obj_path, "wb") as _of {
                    _of.write(_obj_bytes);
                }

                mod = llvm.parse_assembly(str(module.gen.llvm_ir));
                mod.verify();

                module.gen.native_bitcode = mod.as_bitcode();
            } except Exception as _dbg_err { }
        }

        if _compile_opts.aot_mode {
            return ir_in;
        }

        if self.errors_had {
            return ir_in;
        }

        _all_fn_names: list = [];
        if _native_debug and _debug_obj_path {
            try {
                for _fn in mod.functions {
                    _fn_name_str = _fn.name;

                    if not _fn.is_declaration {
                        _all_fn_names.append(_fn_name_str);
                    }
                }
            } except Exception { }
        }

        engine = llvm.create_mcjit_compiler(mod, target_machine);

        if _native_debug {
            try {
                engine.enable_jit_events();
            } except Exception { }
        }
        module.gen.native_engine = engine;

        if _native_debug and _debug_obj_path and _all_fn_names {
            try {
                _text_addr = 0;
                _fn_addrs: list = [];
                for _fn_name in _all_fn_names {
                    _addr = engine.get_function_address(_fn_name);
                    if _addr != 0 {
                        _fn_addrs.append((_fn_name, _addr));
                        if _text_addr == 0 or _addr < _text_addr {
                            _text_addr = _addr;
                        }
                    }
                }
                if _text_addr != 0 {
                    _symmap_path = _os.path.join(_ir_dir, _stem + ".symmap");
                    with open(_symmap_path, "w") as _sf {
                        _sf.write(f"{_debug_obj_path}\n");
                        _sf.write(f"0x{_text_addr:x}\n");
                        for (_fn_name, _addr) in _fn_addrs {
                            _sf.write(f"{_fn_name} 0x{_addr:x}\n");
                        }
                    }
                } else { }
            } except Exception as _sym_err { }
        }
    } except Exception as e {
        self.emit(E5020, error=str(e));
    }
    return ir_in;
}

impl NativeCompilePass._jit_load_clib(lib_path: str) -> bool {
    import os;
    import ctypes.util;
    probe = lib_path;
    if probe.startswith("$ORIGIN/") {
        probe = probe[8:];
    } elif probe.startswith("@loader_path/") {
        probe = probe[13:];
    }
    base = os.path.basename(probe);

    for cand in [lib_path, probe, os.path.join(".", base)] {
        if cand and os.path.exists(cand) {
            llvm.load_library_permanently(os.path.abspath(cand));
            return True;
        }
    }

    try {
        llvm.load_library_permanently(base);
        return True;
    } except Exception { }

    stem = base;
    if stem.startswith("lib") {
        stem = stem[3:];
    }
    for _ext in [".so", ".dylib", ".dll"] {
        _i = stem.find(_ext);
        if _i != -1 {
            stem = stem[:_i];
        }
    }
    found = ctypes.util.find_library(stem) or ctypes.util.find_library(probe);
    if found {
        llvm.load_library_permanently(found);
        return True;
    }
    return False;
}

impl NativeCompilePass._compile_and_link_native_imports(
    module: uni.Module, main_mod: object, imports: list, target_machine: object
) -> None {
    import os;
    import hashlib;
    import json;
    import from jaclang.jac0core.codeinfo {
        NativeModuleInfo,
        NativeFunctionInfo,
        native_safe_sym
    }

    import from jaclang.jac0core.compile_options {
        CompileOptions as _LinkOpts,
        link_fingerprint_mismatches
    }
    _link_opts = self.prog?._compile_options or _LinkOpts();
    _link_fp = _link_opts.codegen_fingerprint();

    linked_modules: dict = {};
    if module.loc {
        linked_modules[os.path.realpath(module.loc.mod_path)] = None;
    }

    symbol_origins: dict = {};

    symbol_owned: dict = {};
    _MAIN_ORIGIN = "(main module)";

    _main_imported_names: set = set();
    _main_manifest = module.gen.interop_manifest;
    if _main_manifest is not None {
        for _imp_b in _main_manifest.native_cross_module_imports {
            _main_imported_names.add(_imp_b.name);
        }
    }

    _INTERNAL_LINKAGE = 8;
    _PRIVATE_LINKAGE = 9;
    _WEAK_LINKAGE = 5;
    _WEAK_ODR_LINKAGE = 6;
    for _mfn in main_mod.functions {
        if _mfn.is_declaration or _mfn.name.startswith("llvm.") {
            continue;
        }
        if _mfn.linkage == _INTERNAL_LINKAGE or _mfn.linkage == _PRIVATE_LINKAGE {
            continue;
        }
        symbol_origins[_mfn.name] = _MAIN_ORIGIN;
        symbol_owned[_mfn.name] = _mfn.name not in _main_imported_names;
    }
    for _mgv in main_mod.global_variables {
        if _mgv.is_declaration {
            continue;
        }
        if _mgv.linkage == _INTERNAL_LINKAGE or _mgv.linkage == _PRIVATE_LINKAGE {
            continue;
        }
        symbol_origins[_mgv.name] = _MAIN_ORIGIN;
        symbol_owned[_mgv.name] = _mgv.name not in _main_imported_names;
    }

    class _DepBinding {
        def init(self: _DepBinding, sm: str) {
            self.source_module = sm;
        }
    }
    work_queue: list = [];
    base_dir = os.path.dirname(module.loc.mod_path) if module.loc else ".";
    for binding in imports {
        work_queue.append((binding, base_dir));
    }

    import from jaclang.jac0core.codeinfo { native_stdlib_root }
    _bundled_stdlib_root = native_stdlib_root();
    queue_idx = 0;
    while queue_idx < len(work_queue) {
        (binding, cur_base_dir) = work_queue[queue_idx];
        queue_idx += 1;
        source_mod_path = binding.source_module;
        if source_mod_path is None {
            continue;
        }

        if source_mod_path.endswith(".jac") {
            full_path = os.path.join(cur_base_dir, source_mod_path);
        } else {
            import from jaclang.jac0core.codeinfo {
                resolve_native_module as _resolve_na
            }
            (_rn, _rp) = _resolve_na(
                source_mod_path.replace(os.sep, "."), cur_base_dir
            );
            full_path = _rp
                if _rp is not None
                else os.path.join(cur_base_dir, source_mod_path + ".jac");
        }

        if not os.path.exists(full_path) {
            self.emit(W5023, path=full_path);
            continue;
        }

        real_path = os.path.realpath(full_path);
        if real_path in linked_modules {
            continue;
        }
        linked_modules[real_path] = None;

        import from jaclang.jac0core.jir { get_native_cache_dir }
        _src_stem = os.path.splitext(os.path.basename(real_path))[0];
        _ir_cache_dir = str(get_native_cache_dir(real_path));

        _cache_ir_path = "";
        _cache_meta_path = "";
        _cache_hit = False;
        imported_llvm_str_raw = "";

        meta = DepClibMeta();

        try {
            (_cache_ir_path, _cache_meta_path) = native_dep_cache_paths(
                real_path, _link_opts
            );

            _no_ir_cache = bool(getattr(_link_opts, "no_ir_cache", False));
            if (
                not _no_ir_cache
                and os.path.exists(_cache_ir_path)
                and os.path.exists(_cache_meta_path)
            ) {
                with open(_cache_ir_path, "r") as _cf {
                    imported_llvm_str_raw = _cf.read();
                }
                with open(_cache_meta_path, "r") as _mf {
                    _meta = json.loads(_mf.read());
                }
                meta = DepClibMeta.from_meta(_meta);
                _cache_hit = True;
            }
        } except Exception { }

        if _cache_hit
            and link_fingerprint_mismatches(
                [(real_path, meta.options_fingerprint)], _link_fp
            ) {
            self.emit(
                E5027,
                path=full_path,
                cached_fp=(meta.options_fingerprint or "(unstamped)"),
                current_fp=_link_fp
            );
            continue;
        }

        if _cache_hit {
            dep_base = os.path.dirname(full_path);
            for dep_mod_path in meta.transitive_deps {
                work_queue.append((_DepBinding(dep_mod_path), dep_base));
            }
        } else {
            import_options = _link_opts.clone_for_native_import();
            try {
                imported_ir = self.prog.compile(
                    file_path=full_path, options=import_options
                );
            } except Exception as e {
                self.emit(E5024, path=full_path, error=str(e));
                continue;
            }
            if imported_ir is None or imported_ir.gen.llvm_ir is None {
                self.emit(E5024, path=full_path, error="No LLVM IR generated");
                continue;
            }
            _owned_seen: set[str] = set();
            for _ab in imported_ir.get_all_sub_nodes(uni.Ability) {
                _ab_name = _ab.name_ref.sym_name if _ab.name_ref else None;
                if _ab_name {
                    _owned_seen.add(_ab_name);
                    _encl_arch = _ab.find_parent_of_type(uni.Archetype);
                    if _encl_arch is not None and _encl_arch.name {
                        _owned_seen.add(f"{_encl_arch.name.value}.{_ab_name}");
                    }
                }
            }
            for _gvs in imported_ir.get_all_sub_nodes(uni.GlobalVars) {
                for _asgn in _gvs.assignments {
                    _tgts = _asgn.target
                        if isinstance(_asgn.target, (list, tuple))
                        else [(_asgn.target)];
                    for _tgt in _tgts {
                        if isinstance(_tgt, uni.Name) {
                            _owned_seen.add(_tgt.value);
                        }
                    }
                }
            }
            meta.owned_symbols = sorted(_owned_seen);
            imported_llvm_str_raw = str(imported_ir.gen.llvm_ir);
            meta.clib_paths = imported_ir.gen._clib_paths or [];
            meta.clib_symbol_lib = imported_ir.gen._clib_symbol_lib or {};
            meta.exported_symbols = imported_ir.gen._exported_symbols or [];
            dep_manifest = imported_ir.gen.interop_manifest;
            if dep_manifest is not None {
                dep_base = os.path.dirname(full_path);
                for dep_binding in dep_manifest.native_cross_module_imports {
                    if dep_binding.source_module is not None {
                        meta.transitive_deps.append(dep_binding.source_module);
                        work_queue.append((dep_binding, dep_base));
                    }

                    if dep_binding.name {
                        meta.imported_symbols.append(dep_binding.name);
                    }
                }
            }
            meta.options_fingerprint = _link_fp;
            try {
                os.makedirs(_ir_cache_dir, exist_ok=True);

                import glob as _glob;
                for stale in _glob.glob(
                    os.path.join(_ir_cache_dir, f"{_src_stem}.*.ir_cache")
                ) {
                    if stale != _cache_ir_path {
                        os.remove(stale);
                    }
                }
                for stale in _glob.glob(
                    os.path.join(_ir_cache_dir, f"{_src_stem}.*.ir_meta")
                ) {
                    if stale != _cache_meta_path {
                        os.remove(stale);
                    }
                }
                with open(_cache_ir_path, "w") as _wf {
                    _wf.write(imported_llvm_str_raw);
                }
                _meta_obj = meta.to_meta();
                with open(_cache_meta_path, "w") as _wmf {
                    _wmf.write(json.dumps(_meta_obj));
                }
            } except Exception { }
        }

        if not self.prog._compile_options.aot_mode {
            for dep_lib_path in meta.clib_paths {
                try {
                    self._jit_load_clib(dep_lib_path);
                } except Exception { }
            }
        }

        try {
            imported_llvm_str = imported_llvm_str_raw;

            safe_name = native_safe_sym(source_mod_path);
            entry_rename = f"__jac_entry_{safe_name}";
            imported_llvm_str = imported_llvm_str.replace(
                '@"jac_entry"', f'@"{entry_rename}"'
            );
            imported_llvm_str = imported_llvm_str.replace(
                "@jac_entry", f"@{entry_rename}"
            );

            imported_llvm_str = imported_llvm_str.replace(
                'name: "jac_entry"', f'name: "{entry_rename}"'
            );

            glob_init_rename = f"__jac_glob_init_{safe_name}";
            imported_llvm_str = imported_llvm_str.replace(
                '@"__jac_glob_init"', f'@"{glob_init_rename}"'
            );
            imported_llvm_str = imported_llvm_str.replace(
                "@__jac_glob_init", f"@{glob_init_rename}"
            );

            imported_llvm_str = imported_llvm_str.replace(
                'name: "__jac_glob_init"', f'name: "{glob_init_rename}"'
            );
            imported_mod = llvm.parse_assembly(imported_llvm_str);

            meta.propagate_to(module.gen);

            dep_imported_set: set[str] = set(meta.imported_symbols);
            dep_owned_set: set[str] = set(meta.owned_symbols);
            exported_funcs: list[str] = [];

            has_real_collision = False;
            _benign_dup_funcs: list = [];
            _benign_dup_gvs: list = [];
            for func in imported_mod.functions {
                if func.name.startswith("llvm.") or func.is_declaration {
                    continue;
                }
                if func.linkage == _INTERNAL_LINKAGE
                    or func.linkage == _PRIVATE_LINKAGE
                    or func.linkage == _WEAK_LINKAGE
                    or func.linkage == _WEAK_ODR_LINKAGE {
                    continue;
                }
                exported_funcs.append(func.name);
                if func.name in symbol_origins {
                    _is_owned = (
                        func.name in dep_owned_set
                            if dep_owned_set
                            else func.name not in dep_imported_set
                    );
                    if _is_owned and symbol_owned.get(func.name, True) {
                        self.emit(
                            E5026,
                            symbol=func.name,
                            existing_module=symbol_origins[func.name],
                            new_module=full_path
                        );
                        has_real_collision = True;
                    } else {
                        _benign_dup_funcs.append(func);
                    }
                }
            }
            exported_globals: list[str] = [];
            for gv in imported_mod.global_variables {
                if gv.is_declaration
                    or gv.linkage == _INTERNAL_LINKAGE
                    or gv.linkage == _PRIVATE_LINKAGE
                    or gv.linkage == _WEAK_LINKAGE
                    or gv.linkage == _WEAK_ODR_LINKAGE {
                    continue;
                }
                exported_globals.append(gv.name);
                if gv.name in symbol_origins {
                    _is_owned = (
                        gv.name in dep_owned_set
                            if dep_owned_set
                            else gv.name not in dep_imported_set
                    );
                    if _is_owned and symbol_owned.get(gv.name, True) {
                        self.emit(
                            E5026,
                            symbol=gv.name,
                            existing_module=symbol_origins[gv.name],
                            new_module=full_path
                        );
                        has_real_collision = True;
                    } else {
                        _benign_dup_gvs.append(gv);
                    }
                }
            }
            if has_real_collision {
                continue;
            }
            if _benign_dup_funcs or _benign_dup_gvs {
                _has_unique = (
                    any(f not in symbol_origins for f in exported_funcs)
                    or any(g not in symbol_origins for g in exported_globals)
                );
                if not _has_unique {
                    continue;
                }
                for _bf in _benign_dup_funcs {
                    _bf.linkage = 'available_externally';
                }
                for _bg in _benign_dup_gvs {
                    _bg.linkage = 'available_externally';
                }
            }

            for fname in exported_funcs {
                if fname not in symbol_origins {
                    symbol_origins[fname] = full_path;
                    symbol_owned[fname] = (
                        fname in dep_owned_set
                            if dep_owned_set
                            else fname not in dep_imported_set
                    );
                }
            }
            for gname in exported_globals {
                if gname not in symbol_origins {
                    symbol_origins[gname] = full_path;
                    symbol_owned[gname] = (
                        gname in dep_owned_set
                            if dep_owned_set
                            else gname not in dep_imported_set
                    );
                }
            }

            main_mod.link_in(imported_mod);

            mod_info = NativeModuleInfo(
                mod_path=full_path, llvm_module=None, native_engine=None
            );

            for fname in exported_funcs {
                mod_info.exported_functions[fname] = NativeFunctionInfo(name=fname);
            }

            linked_modules[real_path] = mod_info;
            module.gen.interop_manifest.native_module_imports[source_mod_path] = mod_info;
        } except Exception as e {
            self.emit(E5025, path=full_path, error=str(e));
        }
    }
}

glob _OSP_KERNEL_IR_CACHE: dict[str, str] = {};

def _compile_osp_kernel_ir(
    gc_mode: str = "cycles", enforce: bool = False
) -> (str | None) {
    import from jaclang.jac0core.kernel_units {
        load_unit_artifact,
        osp_core_unit_path,
        store_unit_artifact
    }
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.compile_options { CompileOptions as _KernelOpts }

    kernel_opts = _KernelOpts(
        aot_mode=True,
        type_check=False,
        default_codespace='native',
        na_gc_mode=gc_mode,
        nogc_enforce_all=enforce,
        suppress_codes=(
            [
                "E1301",
                "E1302",
                "E1303",
                "E1304",
                "E1306",
                "E1308",
                "E1309",
                "E1311",
                "E1313",
                "E1314",
                "E1315",
                "E1401",
                "E1402",
                "E1403",
                "E1404",
                "E1405",
                "E1406",
                "W1310",
                "W1312"
            ]
                if enforce
                else []
        )
    );
    cache_key = kernel_opts.codegen_fingerprint();
    if cache_key in _OSP_KERNEL_IR_CACHE {
        return _OSP_KERNEL_IR_CACHE[cache_key];
    }

    variant = f"na_{gc_mode}_enf" if enforce else f"na_{gc_mode}";
    unit = osp_core_unit_path(variant);
    fp = native_compiler_fingerprint(kernel_opts);
    ir_str = load_unit_artifact(unit, "ll", fp);
    if ir_str is not None {
        _OSP_KERNEL_IR_CACHE[cache_key] = ir_str;
        return ir_str;
    }
    try {
        prog = JacProgram();
        m = prog.compile(unit, options=kernel_opts);
        if (m is not None) and m?.gen and (m.gen.llvm_ir is not None) {
            ir_str = str(m.gen.llvm_ir);
        }
    } except Exception {
        ir_str = None;
    }
    if ir_str is not None {
        _OSP_KERNEL_IR_CACHE[cache_key] = ir_str;
        store_unit_artifact(unit, "ll", fp, ir_str);
    }
    return ir_str;
}

impl NativeCompilePass._references_undefined_osp_kernel(main_mod: object) -> bool {
    try {
        for _fn in main_mod.functions {
            if _fn.name == "__jac_glob_init_osp_kernel" and _fn.is_declaration {
                return True;
            }
        }
    } except Exception {
        return False;
    }
    return False;
}

impl NativeCompilePass._link_osp_kernel(main_mod: object) -> None {
    _gc = str(getattr(self.prog?._compile_options, "na_gc_mode", "cycles") or "cycles");
    _enf = bool(getattr(self.prog?._compile_options, "nogc_enforce_all", False))
        or bool(getattr(self.ir_in.gen, "nogc_enforced", False));
    ir_str = _compile_osp_kernel_ir(_gc, _enf and _gc == "none");
    if ir_str is None {
        return;
    }

    ir_str = ir_str.replace('@"__jac_glob_init"', '@"__jac_glob_init_osp_kernel"');
    ir_str = ir_str.replace("@__jac_glob_init", "@__jac_glob_init_osp_kernel");
    ir_str = ir_str.replace(
        'name: "__jac_glob_init"', 'name: "__jac_glob_init_osp_kernel"'
    );
    try {
        kmod = llvm.parse_assembly(ir_str);
        kmod.verify();
        main_mod.link_in(kmod);
    } except Exception as _e {
        ;
    }
}

glob _FMT_KERNEL_IR_CACHE: dict = {};

def _compile_fmt_kernel_ir -> (str | None) {
    import from jaclang.jac0core.kernel_units {
        fmt_kernel_unit_path,
        load_unit_artifact,
        store_unit_artifact
    }
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.compile_options { CompileOptions as _KernelOpts }

    kernel_opts = _KernelOpts(
        aot_mode=True, type_check=False, default_codespace='native', na_gc_mode='cycles'
    );
    cache_key = kernel_opts.codegen_fingerprint();
    if cache_key in _FMT_KERNEL_IR_CACHE {
        return _FMT_KERNEL_IR_CACHE[cache_key];
    }

    unit = fmt_kernel_unit_path('na_cycles');
    fp = native_compiler_fingerprint(kernel_opts);
    ir_str = load_unit_artifact(unit, "ll", fp);
    if ir_str is not None {
        _FMT_KERNEL_IR_CACHE[cache_key] = ir_str;
        return ir_str;
    }
    try {
        prog = JacProgram();
        m = prog.compile(unit, options=kernel_opts);
        if (m is not None) and m?.gen and (m.gen.llvm_ir is not None) {
            ir_str = str(m.gen.llvm_ir);
        }
    } except Exception {
        ir_str = None;
    }
    if ir_str is not None {
        _FMT_KERNEL_IR_CACHE[cache_key] = ir_str;
        store_unit_artifact(unit, "ll", fp, ir_str);
    }
    return ir_str;
}

impl NativeCompilePass._references_undefined_fmt_kernel(main_mod: object) -> bool {
    try {
        for _fn in main_mod.functions {
            if _fn.is_declaration
                and (
                    _fn.name.startswith("jac_fmt_")
                    or _fn.name.startswith("_jac_fmt_")
                    or _fn.name == "__jac_glob_init_fmt_kernel"
                ) {
                return True;
            }
        }
    } except Exception {
        return False;
    }
    return False;
}

impl NativeCompilePass._link_fmt_kernel(main_mod: object) -> None {
    ir_str = _compile_fmt_kernel_ir();
    if ir_str is None {
        return;
    }

    ir_str = ir_str.replace('@"__jac_glob_init"', '@"__jac_glob_init_fmt_kernel"');
    ir_str = ir_str.replace("@__jac_glob_init", "@__jac_glob_init_fmt_kernel");
    ir_str = ir_str.replace(
        'name: "__jac_glob_init"', 'name: "__jac_glob_init_fmt_kernel"'
    );
    try {
        kmod = llvm.parse_assembly(ir_str);
        kmod.verify();
        main_mod.link_in(kmod);
    } except Exception as _e {
        ;
    }
}
