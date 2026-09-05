def _mod_functions(mod: ModuleRef) -> list[ValueRef] {
    fns = mod.functions;
    assert isinstance(fns, Iterator);
    return list(fns);
}

def _mod_globals(mod: ModuleRef) -> list[ValueRef] {
    gvs = mod.global_variables;
    assert isinstance(gvs, Iterator);
    return list(gvs);
}

def _mod_bitcode(mod: ModuleRef) -> bytes {
    bitcode = mod.as_bitcode();
    assert isinstance(bitcode, bytes);
    return bitcode;
}

impl native_compiler_fingerprint(options: any) -> str {
    import glob as _cgl;
    import hashlib as _cfh_hash;
    import os as _cfp_os;
    import jaclang as _jlm;
    _jl_dir = _cfp_os.path.dirname(_cfp_os.path.abspath(_jlm.__file__));
    _nat_dir = _cfp_os.path.join(_jl_dir, "compiler", "backends", "native");
    _comp_h = _cfh_hash.sha256();
    import from jaclang.compiler.driver.jir { FORMAT_VERSION }
    _comp_h.update(str(FORMAT_VERSION).encode());
    for _cp in [
        _cfp_os.path.join(_nat_dir, "impl", "*.jac"),
        _cfp_os.path.join(_nat_dir, "na_ir_gen", "*.jac"),
        _cfp_os.path.join(_jl_dir, "compiler", "types", "*.jac"),
        _cfp_os.path.join(_jl_dir, "compiler", "types", "*", "*.jac"),
        _cfp_os.path.join(_jl_dir, "compiler", "type_registry.jac"),
        _cfp_os.path.join(_jl_dir, "runtime", "scalars.jac")
    ] {
        for _cf in sorted(_cgl.`glob(_cp)) {
            try {
                with open(_cf, "rb") as _cfh {
                    _comp_h.update(_cfh.read());
                }
            } except Exception {}
        }
    }
    _comp_h.update(options.codegen_identity().encode());
    return _comp_h.hexdigest()[:8];
}

impl native_dep_cache_paths(real_path: str, options: any) -> tuple {
    import hashlib as _dcp_hash;
    import os as _dcp_os;
    import from jaclang.compiler.driver.jir { get_native_cache_dir }
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
        "demoted_symbols": self.demoted_symbols,
        "transitive_deps": self.transitive_deps,
        "ct_deps": self.ct_deps,
        "options_fingerprint": self.options_fingerprint,
        "unverified_live_calls": self.unverified_live_calls,
        "coverage": self.coverage
    };
}

impl DepClibMeta.from_meta(meta: dict) -> DepClibMeta {
    return DepClibMeta(
        clib_paths=meta.get("clib_paths", []),
        clib_symbol_lib=meta.get("clib_symbol_lib", {}),
        exported_symbols=meta.get("exported_symbols", []),
        imported_symbols=meta.get("imported_symbols", []),
        owned_symbols=meta.get("owned_symbols", []),
        demoted_symbols=meta.get("demoted_symbols", []),
        transitive_deps=meta.get("transitive_deps", []),
        ct_deps=meta.get("ct_deps", ""),
        options_fingerprint=meta.get("options_fingerprint", ""),
        unverified_live_calls=meta.get("unverified_live_calls", {}),
        coverage=meta.get("coverage", {})
    );
}

impl native_verdict_blast_guard(
    prog: any, composed: int, aot_lane: bool = False
) -> str {
    _bg_taint = 0;
    _bg_mods = 0;
    _bg_live: dict[str, dict[str, set[str]]] = prog.scratch.na_unverified_live or {};
    for _bg_rec in _bg_live.values() {
        _bg_mods += 1;
        for _bg_names in _bg_rec.values() {
            _bg_taint += len(_bg_names);
        }
    }
    _bg_misses = int(prog.scratch.na_verdict_misses or 0);
    _bg_taint_ok = aot_lane or _bg_taint <= NATIVE_VERDICT_TAINT_BOUND;
    if (
        _bg_taint_ok
        and composed <= NATIVE_LINK_COMPILE_BOUND
        and _bg_misses <= NATIVE_VERDICT_MISS_BOUND
    ) {
        return "";
    }
    return (
        f"{_bg_taint} tainted name(s) across {_bg_mods} module(s), "
        f"{composed} link-time module compile(s), {_bg_misses} fail-closed "
        f"verdict miss(es); bounds "
        f"{NATIVE_VERDICT_TAINT_BOUND}/{NATIVE_LINK_COMPILE_BOUND}/"
        f"{NATIVE_VERDICT_MISS_BOUND}"
    );
}

impl native_linked_ir_text(module: uni.Module) -> str {
    linked = module.gen.native_linked_ir;
    if linked is not None {
        return linked;
    }
    return str(module.gen.llvm_ir);
}

impl native_ir_live_externs(llvm_ir_text: str) -> set[str] {
    import re as _dc_re;
    _dc_decl = _dc_re.compile(
        r'^declare\b[^@\n]*@(?:"([^"]+)"|([A-Za-z0-9_.$\-]+))\s*\(', _dc_re.MULTILINE
    );
    declared: set[str] = set();
    for (_dc_q, _dc_bare) in _dc_decl.findall(llvm_ir_text) {
        declared.add(_dc_q or _dc_bare);
    }
    if not declared {
        return declared;
    }
    _dc_use = _dc_re.compile(r'@(?:"([^"]+)"|([A-Za-z0-9_.$\-]+))');
    counts: dict[str, int] = {};
    for (_dc_q, _dc_bare) in _dc_use.findall(llvm_ir_text) {
        _dc_name = _dc_q or _dc_bare;
        if _dc_name in declared {
            counts[_dc_name] = counts.get(_dc_name, 0) + 1;
        }
    }
    return {
        _dc_name
        for (_dc_name, _dc_n) in counts.items()
        if _dc_n > 1
    };
}

impl native_prune_live_record(
    pending: dict, declared: set[str]
) -> dict[str, set[str]] {
    pruned: dict[str, set[str]] = {};
    for (_pr_callee, _pr_names) in (pending or {}).items() {
        _pr_hit = set(_pr_names) & declared;
        if _pr_hit {
            pruned[_pr_callee] = _pr_hit;
        }
    }
    return pruned;
}

impl native_unit_demotions(
    prog: any, real_path: str, options: any
) -> (set[str] | None) {
    import os as _ud_os;
    `entry: any = prog.scratch.na_dep_units.get(real_path);
    _ud_mid_compile = False;
    if `entry is None {
        for _ud_key in (real_path, _ud_os.path.abspath(real_path)) {
            _ud_mod = prog.mod.hub.get(_ud_key);
            if _ud_mod is None {
                continue;
            }
            if _ud_mod.gen.llvm_ir is not None {
                `entry = _ud_mod;
            } else {
                _ud_mid_compile = (
                    real_path in prog.scratch.na_dep_inflight
                    or real_path in prog.scratch.na_verdict_resolving
                    or _ud_key in prog.scratch.na_dep_inflight
                    or _ud_key in prog.scratch.na_verdict_resolving
                );
            }
            break;
        }
    }
    if (
        `entry is None
        and not _ud_mid_compile
        and real_path not in prog.scratch.na_dep_inflight
        and real_path not in prog.scratch.na_verdict_resolving
        and _ud_os.path.isfile(real_path)
    ) {
        import from jaclang.compiler.driver.jir {
            native_ir_cache_suspended as _ud_suspended
        }
        if not (getattr(options, "no_ir_cache", False) or _ud_suspended()) {
            try {
                import json as _ud_json;
                (_, _ud_meta_path) = native_dep_cache_paths(real_path, options);
                if _ud_os.path.exists(_ud_meta_path) {
                    with open(_ud_meta_path, "r") as _ud_mf {
                        _ud_meta = _ud_json.loads(_ud_mf.read());
                    }
                    _ud_cached = _ud_meta.get("demoted_symbols");
                    if _ud_cached is not None {
                        return set(_ud_cached);
                    }
                }
            } except Exception {}
        }
        prog.scratch.na_verdict_resolving.add(real_path);
        try {
            `entry = prog.compile(
                file_path=real_path, options=options.clone_for_native_import()
            );
        } except Exception as _ud_exc {
            `entry = f"{type(_ud_exc).__name__}: {_ud_exc}";
        } finally {
            prog.scratch.na_verdict_resolving.discard(real_path);
        }
        prog.scratch.na_dep_units[real_path] = `entry;
    }
    if `entry is None or isinstance(`entry, str) or `entry.gen.llvm_ir is None {
        prog.scratch.na_verdict_misses += 1;
        _ud_tree = `entry
            if (`entry is not None and not isinstance(`entry, str))
            else prog.mod.hub.get(real_path);
        if _ud_tree is None {
            return None;
        }
        _ud_all: set = set();
        import jaclang.compiler.frontend.unitree as _ud_uni;
        import from jaclang.compiler.backends.py.module_codegen_pass {
            ModuleCodegenPass as _UdWalk
        }
        for _ud_stmt in _UdWalk.iter_context_stmts(_ud_tree) {
            if isinstance(_ud_stmt, _ud_uni.Ability) and _ud_stmt.name_ref {
                _ud_all.add(_ud_stmt.name_ref.sym_name);
            } elif isinstance(_ud_stmt, _ud_uni.Archetype)
                and _ud_stmt.body is not None
                and _ud_stmt.name is not None {
                for _ud_meth in _ud_stmt.body {
                    if isinstance(_ud_meth, _ud_uni.Ability) and _ud_meth.name_ref {
                        _ud_all.add(
                            f"{_ud_stmt.name.value}.{_ud_meth.name_ref.sym_name}"
                        );
                    }
                }
            }
        }
        return _ud_all;
    }
    return set(native_demoted_ir_symbols(str(`entry.gen.llvm_ir)));
}

impl native_live_call_conflicts(
    prog: any, pending: dict, options: any
) -> dict[str, set[str]] {
    conflicts: dict[str, set[str]] = {};
    for (_cc_callee, _cc_names) in (pending or {}).items() {
        _cc_demoted = native_unit_demotions(prog, _cc_callee, options);
        _cc_hit = (
            set(_cc_names) if _cc_demoted is None else (set(_cc_names) & _cc_demoted)
        );
        if _cc_hit {
            conflicts[_cc_callee] = _cc_hit;
        }
    }
    return conflicts;
}

impl native_demoted_ir_symbols(llvm_ir_text: str) -> list[str] {
    import re as _ds_re;
    _ds_def = _ds_re.compile(
        r'^define\b[^@\n]*@(?:"([^"]+\.__jac_demoted)"'
        r'|([A-Za-z0-9_.$\-]+\.__jac_demoted))\(',
        _ds_re.MULTILINE
    );
    found: set[str] = set();
    for (_ds_q, _ds_bare) in _ds_def.findall(llvm_ir_text) {
        found.add((_ds_q or _ds_bare)[:-len(".__jac_demoted")]);
    }
    return sorted(found);
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

impl NativeCompilePass._run_impl(ir_in: uni.Module) -> uni.Module {
    module = ir_in;
    if module.gen.llvm_ir is None {
        return ir_in;
    }

    _compile_opts = self.prog.options;

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
        clib_paths: (list[str] | None) = module.gen._clib_paths;
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
        assert isinstance(target, llvm.Target);

        _native_debug: bool = bool(_compile_opts.native_debug);
        if _native_debug {
            target_machine = target.create_target_machine(opt=0, jit=True);
        } else {
            target_machine = target.create_target_machine(jit=True);
        }
        assert isinstance(target_machine, llvm.TargetMachine);

        manifest = module.gen.interop_manifest;
        native_imports = manifest.native_imports;
        if native_imports {
            import from jaclang.runtime.interop_bridge { register_py_callbacks }
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

        _is_kernel_unit = bool(getattr(_compile_opts, "kernel_unit", False));

        _needs_osp_kernel = (manifest is not None)
            and ("osp_kernel" in manifest.native_transitive_sources);
        if (not _needs_osp_kernel) and self._references_undefined_osp_kernel(mod) {
            _needs_osp_kernel = True;
        }
        _kernel_linked = False;
        if _needs_osp_kernel and not _is_kernel_unit {
            self._link_osp_kernel(mod);
            module.gen.llvm_ir = mod;
            _kernel_linked = True;
        }

        _needs_fmt_kernel = (manifest is not None)
            and ("fmt_kernel" in manifest.native_transitive_sources);
        if (not _needs_fmt_kernel) and self._references_undefined_fmt_kernel(mod) {
            _needs_fmt_kernel = True;
        }
        if _needs_fmt_kernel and not _is_kernel_unit {
            self._link_fmt_kernel(mod);
            module.gen.llvm_ir = mod;
            _kernel_linked = True;
        }

        _needs_region_kernel = (manifest is not None)
            and ("region_kernel" in manifest.native_transitive_sources);
        if (not _needs_region_kernel)
            and self._references_undefined_region_kernel(mod) {
            _needs_region_kernel = True;
        }
        if _needs_region_kernel and not _is_kernel_unit {
            self._link_region_kernel(mod);
            _kernel_linked = True;
        }
        module.gen.native_linked_ir = str(mod) if _kernel_linked else None;

        import os as _os;
        _opt_level = int(_compile_opts.opt_level or 0);

        if _native_debug {
            _opt_level = 0;
        }
        if _opt_level > 0 {
            pto = llvm.create_pipeline_tuning_options(speed_level=_opt_level);
            pb = llvm.create_pass_builder(target_machine, pto);
            assert isinstance(pb, llvm.PassBuilder);
            opt_mpm = pb.getModulePassManager();
            assert isinstance(opt_mpm, llvm.ModulePassManager);
            opt_mpm.run(mod, pb);
        }

        _dump_path = _compile_opts.dump_ir_path or "";
        if _dump_path {
            with open(_dump_path, "w") as _f {
                _f.write(str(mod));
            }
        }

        module.gen.native_bitcode = _mod_bitcode(mod);

        _debug_obj_path = "";
        _ir_dir = "";
        _stem = "";
        if _native_debug {
            import from jaclang.compiler.driver.jir { get_native_cache_dir }
            _mod_path = module.loc.mod_path if module.loc else "jac_native";
            _src_name = _os.path.basename(_mod_path);
            _stem = _os.path.splitext(_src_name)[0];
            _ir_dir = str(get_native_cache_dir(_mod_path));
            _os.makedirs(_ir_dir, exist_ok=True);
            try {
                _obj_bytes = target_machine.emit_object(mod);
                assert isinstance(_obj_bytes, bytes);
                _debug_obj_path = _os.path.join(_ir_dir, _stem + ".debug.o");
                with open(_debug_obj_path, "wb") as _of {
                    _of.write(_obj_bytes);
                }

                mod = llvm.parse_assembly(str(module.gen.llvm_ir));
                mod.verify();

                module.gen.native_bitcode = _mod_bitcode(mod);
            } except Exception as _dbg_err {}
        }

        if _compile_opts.aot_mode {
            return ir_in;
        }

        if self.errors_had {
            return ir_in;
        }

        _all_fn_names: list[str] = [];
        if _native_debug and _debug_obj_path {
            try {
                for _fn in _mod_functions(mod) {
                    _fn_name_str = str(_fn.name);

                    if not _fn.is_declaration {
                        _all_fn_names.append(_fn_name_str);
                    }
                }
            } except Exception {}
        }

        engine = llvm.create_mcjit_compiler(mod, target_machine);
        assert isinstance(engine, llvm.ExecutionEngine);

        if _native_debug {
            try {
                engine.enable_jit_events();
            } except Exception {}
        }
        install_native_static_init(engine, module.gen.interop_manifest);
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
                } else {}
            } except Exception as _sym_err {}
        }
    } except Exception as e {
        self.emit(E5020, error=str(e));
    }
    return ir_in;
}

impl NativeCompilePass._jit_load_clib(lib_path: str) -> bool {
    import os;
    import sys;
    import ctypes.util;

    def is_darwin_abort_stub(cand: str) -> bool {
        if sys.platform != "darwin" {
            return False;
        }
        cand_base = os.path.basename(cand);
        if cand_base not in ("libcrypto.dylib", "libssl.dylib") {
            return False;
        }
        if os.path.isabs(cand) {
            return os.path.dirname(os.path.realpath(cand)) == "/usr/lib";
        }

        return True;
    }

    probe = lib_path;
    if probe.startswith("$ORIGIN/") {
        probe = probe[8:];
    } elif probe.startswith("@loader_path/") {
        probe = probe[13:];
    }
    base = os.path.basename(probe);

    for cand in [lib_path, probe, os.path.join(".", base)] {
        if cand and os.path.exists(cand) and not is_darwin_abort_stub(cand) {
            llvm.load_library_permanently(os.path.abspath(cand));
            return True;
        }
    }

    if not is_darwin_abort_stub(base) {
        try {
            llvm.load_library_permanently(base);
            return True;
        } except Exception {}
    }

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
    if found and not is_darwin_abort_stub(found) {
        llvm.load_library_permanently(found);
        return True;
    }
    return False;
}

impl NativeCompilePass._compile_and_link_native_imports(
    module: uni.Module,
    main_mod: ModuleRef,
    imports: list,
    target_machine: TargetMachine
) -> None {
    import os;
    import hashlib;
    import json;
    import from jaclang.compiler.frontend.codeinfo {
        NativeModuleInfo,
        NativeFunctionInfo,
        native_safe_sym
    }

    import from jaclang.compiler.driver.compile_options {
        CompileOptions as _LinkOpts,
        link_fingerprint_mismatches
    }
    _link_opts = self.prog?.options or _LinkOpts();
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
    for _mfn in _mod_functions(main_mod) {
        _mfn_name = str(_mfn.name);
        if _mfn.is_declaration or _mfn_name.startswith("llvm.") {
            continue;
        }
        if _mfn.linkage == _INTERNAL_LINKAGE or _mfn.linkage == _PRIVATE_LINKAGE {
            continue;
        }
        symbol_origins[_mfn_name] = _MAIN_ORIGIN;
        symbol_owned[_mfn_name] = _mfn_name not in _main_imported_names;
    }
    for _mgv in _mod_globals(main_mod) {
        _mgv_name = str(_mgv.name);
        if _mgv.is_declaration {
            continue;
        }
        if _mgv.linkage == _INTERNAL_LINKAGE or _mgv.linkage == _PRIVATE_LINKAGE {
            continue;
        }
        symbol_origins[_mgv_name] = _MAIN_ORIGIN;
        symbol_owned[_mgv_name] = _mgv_name not in _main_imported_names;
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

    import from jaclang.compiler.frontend.codeinfo { native_stdlib_root }
    _bundled_stdlib_root = native_stdlib_root();
    queue_idx = 0;
    _lk_composed = 0;
    while queue_idx < len(work_queue) {
        (binding, cur_base_dir) = work_queue[queue_idx];
        queue_idx += 1;
        source_mod_path = binding.source_module;
        if source_mod_path is None {
            continue;
        }
        _bg_aot = bool(self.prog.options and self.prog.options.aot_mode);
        _bg_msg = native_verdict_blast_guard(self.prog, _lk_composed, _bg_aot);
        if _bg_msg {
            self.emit(E5029, path=str(source_mod_path), detail=_bg_msg);
            break;
        }

        if source_mod_path.endswith(".jac") {
            full_path = os.path.join(cur_base_dir, source_mod_path);
        } else {
            import from jaclang.compiler.frontend.codeinfo {
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

        import from jaclang.compiler.driver.jir { get_native_cache_dir }
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

            import from jaclang.compiler.driver.jir { native_ir_cache_suspended }
            _no_ir_cache = (
                bool(getattr(_link_opts, "no_ir_cache", False))
                or native_ir_cache_suspended()
            );
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
        } except Exception {}

        if _cache_hit and meta.ct_deps {
            import from jaclang.compiler.driver.jir { ct_dep_text_fresh }
            if not ct_dep_text_fresh(meta.ct_deps) {
                _cache_hit = False;
                imported_llvm_str_raw = "";
                meta = DepClibMeta();
                for _ct_stale in (_cache_ir_path, _cache_meta_path) {
                    try {
                        os.remove(_ct_stale);
                    } except OSError {}
                }
            }
        }

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

        if _cache_hit and meta.unverified_live_calls {
            _uv_cached_pending = native_prune_live_record(
                meta.unverified_live_calls,
                native_ir_live_externs(imported_llvm_str_raw)
            );
            _uv_cached_conflicts = native_live_call_conflicts(
                self.prog, _uv_cached_pending, _link_opts
            )
                if _uv_cached_pending
                else {};
            if _uv_cached_conflicts {
                _cache_hit = False;
                imported_llvm_str_raw = "";
                meta = DepClibMeta();
                for _uv_stale in (_cache_ir_path, _cache_meta_path) {
                    try {
                        os.remove(_uv_stale);
                    } except OSError {}
                }
            }
        }

        if _cache_hit {
            import from jaclang.compiler.driver.na_coverage { na_coverage_replay }
            na_coverage_replay(real_path, meta.coverage);
            dep_base = os.path.dirname(full_path);
            for dep_mod_path in meta.transitive_deps {
                work_queue.append((_DepBinding(dep_mod_path), dep_base));
            }
        } else {
            imported_ir: (uni.Module | None) = None;
            import_options = _link_opts.clone_for_native_import();
            _na_units = self.prog.scratch.na_dep_units;
            if real_path in _na_units {
                _memo_entry = _na_units.pop(real_path);
                if isinstance(_memo_entry, str) {
                    self.emit(E5024, path=full_path, error=_memo_entry);
                    continue;
                }
                imported_ir = _memo_entry;
            } else {
                try {
                    _lk_composed += 1;
                    imported_ir = self.prog.compile(
                        file_path=full_path, options=import_options
                    );
                } except Exception as e {
                    self.emit(E5024, path=full_path, error=str(e));
                    continue;
                }
            }
            if imported_ir is None or imported_ir.gen.llvm_ir is None {
                self.emit(E5024, path=full_path, error="No LLVM IR generated");
                continue;
            }
            _uv_record = self.prog.scratch.na_unverified_live.get(real_path) or {};
            _uv_pending = native_prune_live_record(
                _uv_record, native_ir_live_externs(str(imported_ir.gen.llvm_ir))
            )
                if _uv_record
                else {};
            _uv_attempts = 0;
            _uv_failed = "";
            while _uv_pending and _uv_attempts < 3 {
                _uv_conflicts = native_live_call_conflicts(
                    self.prog, _uv_pending, _link_opts
                );
                if not _uv_conflicts {
                    break;
                }
                _uv_attempts += 1;
                import from jaclang.cli.console { console }
                _uv_what = "; ".join(
                    f"{os.path.basename(_uv_c)} demotes " + ", ".join(sorted(_uv_n))
                    for (_uv_c, _uv_n) in sorted(_uv_conflicts.items())
                );
                console.warning(
                    f"native seam -- re-emitting "
                    f"{os.path.basename(real_path)}: it declared callables "
                    f"live while their module's verdict was pending, and the "
                    f"landed verdict disagrees ({_uv_what})"
                );
                self.prog.scratch.na_unverified_live.pop(real_path, None);
                self.prog.scratch.na_dep_units.pop(real_path, None);
                try {
                    self.prog.invalidate_module(real_path);
                } except Exception {}
                try {
                    _lk_composed += 1;
                    imported_ir = self.prog.compile(
                        file_path=full_path, options=import_options
                    );
                } except Exception as _uv_exc {
                    _uv_failed = str(_uv_exc);
                    break;
                }
                if imported_ir is None or imported_ir.gen.llvm_ir is None {
                    _uv_failed = "No LLVM IR generated on re-emission";
                    break;
                }
                _uv_record = self.prog.scratch.na_unverified_live.get(real_path) or {};
                _uv_pending = native_prune_live_record(
                    _uv_record, native_ir_live_externs(str(imported_ir.gen.llvm_ir))
                )
                    if _uv_record
                    else {};
            }
            if _uv_failed {
                self.emit(E5024, path=full_path, error=_uv_failed);
                continue;
            }
            if _uv_pending and _uv_attempts >= 3 {
                _uv_conflicts = native_live_call_conflicts(
                    self.prog, _uv_pending, _link_opts
                );
                if _uv_conflicts {
                    self.emit(
                        E5028,
                        path=full_path,
                        names=", ".join(
                            sorted(
                                _uv_n for _uv_ns in _uv_conflicts.values()
                                for _uv_n in _uv_ns
                            )
                        ),
                        attempts=_uv_attempts
                    );
                    continue;
                }
            }
            assert imported_ir is not None;
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
            meta.demoted_symbols = native_demoted_ir_symbols(imported_llvm_str_raw);
            import from jaclang.compiler.driver.na_coverage { na_coverage_capture }
            meta.coverage = na_coverage_capture(real_path);
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
            import from jaclang.compiler.driver.jir { module_ct_deps_text }
            meta.ct_deps = module_ct_deps_text(imported_ir);
            meta.unverified_live_calls = {
                _uv_c: sorted(_uv_n) for (_uv_c, _uv_n) in _uv_pending.items()
            };
            try {
                os.makedirs(_ir_cache_dir, exist_ok=True);

                import glob as _glob;
                for stale in _glob.`glob(
                    os.path.join(_ir_cache_dir, f"{_src_stem}.*.ir_cache")
                ) {
                    if stale != _cache_ir_path {
                        os.remove(stale);
                    }
                }
                for stale in _glob.`glob(
                    os.path.join(_ir_cache_dir, f"{_src_stem}.*.ir_meta")
                ) {
                    if stale != _cache_meta_path {
                        os.remove(stale);
                    }
                }

                _meta_obj = meta.to_meta();
                _tmp_ir = f"{_cache_ir_path}.{os.getpid()}.tmp";
                _tmp_meta = f"{_cache_meta_path}.{os.getpid()}.tmp";
                try {
                    with open(_tmp_ir, "w") as _wf {
                        _wf.write(imported_llvm_str_raw);
                    }
                    with open(_tmp_meta, "w") as _wmf {
                        _wmf.write(json.dumps(_meta_obj));
                    }
                    os.replace(_tmp_ir, _cache_ir_path);
                    os.replace(_tmp_meta, _cache_meta_path);
                } finally {
                    for _leftover in (_tmp_ir, _tmp_meta) {
                        try {
                            os.remove(_leftover);
                        } except OSError {}
                    }
                }
            } except Exception {}
            if os.path.exists(_cache_ir_path) and os.path.exists(_cache_meta_path) {
                try {
                    if imported_ir.gen.llvm_ir is not None {
                        imported_ir.gen.llvm_ir.close();
                    }
                } except Exception {}
                imported_ir.gen.llvm_ir = None;
                try {
                    self.prog.invalidate_module(real_path);
                } except Exception {}
            }
        }

        if not self.prog.options.aot_mode {
            for dep_lib_path in meta.clib_paths {
                try {
                    self._jit_load_clib(dep_lib_path);
                } except Exception {}
            }
        }

        try {
            imported_llvm_str = imported_llvm_str_raw;

            import from jaclang.compiler.frontend.codeinfo { native_module_key }
            safe_name = native_safe_sym(native_module_key(real_path));
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
            for func in _mod_functions(imported_mod) {
                _func_name = str(func.name);
                if _func_name.startswith("llvm.") or func.is_declaration {
                    continue;
                }
                if func.linkage == _INTERNAL_LINKAGE
                    or func.linkage == _PRIVATE_LINKAGE
                    or func.linkage == _WEAK_LINKAGE
                    or func.linkage == _WEAK_ODR_LINKAGE {
                    continue;
                }
                exported_funcs.append(_func_name);
                if _func_name in symbol_origins {
                    _is_owned = (
                        _func_name in dep_owned_set
                            if dep_owned_set
                            else _func_name not in dep_imported_set
                    );
                    if _is_owned and symbol_owned.get(_func_name, True) {
                        self.emit(
                            E5026,
                            symbol=_func_name,
                            existing_module=symbol_origins[_func_name],
                            new_module=full_path
                        );
                        has_real_collision = True;
                    } else {
                        _benign_dup_funcs.append(func);
                    }
                }
            }
            exported_globals: list[str] = [];
            for gv in _mod_globals(imported_mod) {
                _gv_name = str(gv.name);
                if gv.is_declaration
                    or gv.linkage == _INTERNAL_LINKAGE
                    or gv.linkage == _PRIVATE_LINKAGE
                    or gv.linkage == _WEAK_LINKAGE
                    or gv.linkage == _WEAK_ODR_LINKAGE {
                    continue;
                }
                exported_globals.append(_gv_name);
                if _gv_name in symbol_origins {
                    _is_owned = (
                        _gv_name in dep_owned_set
                            if dep_owned_set
                            else _gv_name not in dep_imported_set
                    );
                    if _is_owned and symbol_owned.get(_gv_name, True) {
                        self.emit(
                            E5026,
                            symbol=_gv_name,
                            existing_module=symbol_origins[_gv_name],
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

glob _OSP_KERNEL_IR_CACHE: dict[str, str] = {},
     _REGION_KERNEL_IR_CACHE: dict[str, str] = {};

def _kernel_unit_opts(gc_mode: str, enforce: bool) -> any {
    import from jaclang.compiler.driver.compile_options {
        CompileOptions as _KernelOpts
    }
    return _KernelOpts(
        aot_mode=True,
        kernel_unit=True,
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
}

def _compile_kernel_unit_ir(
    unit: str, cache: dict[str, str], gc_mode: str, enforce: bool
) -> (str | None) {
    import from jaclang.compiler.backends.kernel_units {
        load_unit_artifact,
        store_unit_artifact
    }
    import from jaclang.compiler.driver.program { JacProgram }
    kernel_opts = _kernel_unit_opts(gc_mode, enforce);
    cache_key = f"{unit}|{kernel_opts.codegen_fingerprint()}";
    if cache_key in cache {
        return cache[cache_key];
    }
    fp = native_compiler_fingerprint(kernel_opts);
    ir_str = load_unit_artifact(unit, "ll", fp);
    if ir_str is not None {
        cache[cache_key] = ir_str;
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
        cache[cache_key] = ir_str;
        store_unit_artifact(unit, "ll", fp, ir_str);
    }
    return ir_str;
}

def _compile_osp_kernel_ir(
    gc_mode: str = "cycles", enforce: bool = False
) -> (str | None) {
    import from jaclang.compiler.backends.kernel_units { osp_core_unit_path }
    variant = f"na_{gc_mode}_enf" if enforce else f"na_{gc_mode}";
    return _compile_kernel_unit_ir(
        osp_core_unit_path(variant), _OSP_KERNEL_IR_CACHE, gc_mode, enforce
    );
}

def _compile_region_kernel_ir(
    gc_mode: str = "cycles", enforce: bool = False
) -> (str | None) {
    import from jaclang.compiler.backends.kernel_units { region_kernel_unit_path }
    variant = f"na_{gc_mode}_enf" if enforce else f"na_{gc_mode}";
    return _compile_kernel_unit_ir(
        region_kernel_unit_path(variant), _REGION_KERNEL_IR_CACHE, gc_mode, enforce
    );
}

def _rename_kernel_glob_init(ir_str: str, suffix: str) -> str {
    ir_str = ir_str.replace('@"__jac_glob_init"', f'@"__jac_glob_init_{suffix}"');
    ir_str = ir_str.replace("@__jac_glob_init(", f"@__jac_glob_init_{suffix}(");
    return ir_str.replace(
        'name: "__jac_glob_init"', f'name: "__jac_glob_init_{suffix}"'
    );
}

impl NativeCompilePass._module_defines(main_mod: ModuleRef, name: str) -> bool {
    try {
        for _fn in _mod_functions(main_mod) {
            if _fn.name == name and not _fn.is_declaration {
                return True;
            }
        }
    } except Exception {
        return False;
    }
    return False;
}

impl NativeCompilePass._references_undefined_region_kernel(
    main_mod: ModuleRef
) -> bool {
    import from jaclang.compiler.backends.kernel_units { REGION_KERNEL_ABI }
    try {
        for _fn in _mod_functions(main_mod) {
            if _fn.is_declaration and _fn.name in REGION_KERNEL_ABI {
                return True;
            }
        }
    } except Exception {
        return False;
    }
    return False;
}

impl NativeCompilePass._link_region_kernel(main_mod: ModuleRef) -> None {
    _gc = str(getattr(self.prog?.options, "na_gc_mode", "cycles") or "cycles");
    _enf = bool(getattr(self.prog?.options, "nogc_enforce_all", False))
        or bool(getattr(self.ir_in.gen, "nogc_enforced", False));
    ir_str = _compile_region_kernel_ir(_gc, _enf and _gc == "none");
    if ir_str is None {
        self.emit(
            E5025,
            path=f"region kernel unit (gc={_gc})",
            error="the kernel unit failed to compile to LLVM IR; every region "
            "operation in this module would be an unresolved symbol at link"
        );
        return;
    }
    ir_str = _rename_kernel_glob_init(ir_str, "region_kernel");
    try {
        kmod = llvm.parse_assembly(ir_str);
        kmod.verify();
        for _gv in _mod_globals(kmod) {
            if not _gv.is_declaration {
                _gv.linkage = "internal";
            }
        }
        main_mod.link_in(kmod);
    } except Exception as _e {
        self.emit(E5025, path=f"region kernel unit (gc={_gc})", error=str(_e));
        return;
    }
    if self._module_defines(main_mod, "__jac_region_died_hook") {
        return;
    }
    _hook_ir = (
        "define linkonce_odr void @__jac_region_died_hook(i64 %rgn) {\n"
        "entry:\n"
        "  ret void\n"
        "}\n"
    );
    try {
        hmod = llvm.parse_assembly(_hook_ir);
        hmod.verify();
        main_mod.link_in(hmod);
    } except Exception as _e {
        self.emit(E5025, path="region kernel died hook", error=str(_e));
    }
}

impl NativeCompilePass._references_undefined_osp_kernel(main_mod: ModuleRef) -> bool {
    try {
        for _fn in _mod_functions(main_mod) {
            if _fn.name == "__jac_glob_init_osp_kernel" and _fn.is_declaration {
                return True;
            }
        }
    } except Exception {
        return False;
    }
    return False;
}

impl NativeCompilePass._link_osp_kernel(main_mod: ModuleRef) -> None {
    _gc = str(getattr(self.prog?.options, "na_gc_mode", "cycles") or "cycles");
    _enf = bool(getattr(self.prog?.options, "nogc_enforce_all", False))
        or bool(getattr(self.ir_in.gen, "nogc_enforced", False));
    ir_str = _compile_osp_kernel_ir(_gc, _enf and _gc == "none");
    if ir_str is None {
        self.emit(
            E5025,
            path=f"osp_core kernel unit (gc={_gc})",
            error="the kernel unit failed to compile to LLVM IR; every OSP "
            "operation in this module would be an unresolved symbol at link"
        );
        return;
    }

    ir_str = _rename_kernel_glob_init(ir_str, "osp_kernel");
    try {
        kmod = llvm.parse_assembly(ir_str);
        kmod.verify();
        main_mod.link_in(kmod);
    } except Exception as _e {
        self.emit(E5025, path=f"osp_core kernel unit (gc={_gc})", error=str(_e));
    }
}

glob _FMT_KERNEL_IR_CACHE: dict = {};

def _compile_fmt_kernel_ir -> (str | None) {
    import from jaclang.compiler.backends.kernel_units {
        fmt_kernel_unit_path,
        load_unit_artifact,
        store_unit_artifact
    }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options {
        CompileOptions as _KernelOpts
    }

    kernel_opts = _KernelOpts(
        aot_mode=True, default_codespace='native', na_gc_mode='cycles'
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

impl NativeCompilePass._references_undefined_fmt_kernel(main_mod: ModuleRef) -> bool {
    try {
        for _fn in _mod_functions(main_mod) {
            _fn_name = str(_fn.name);
            if _fn.is_declaration
                and (
                    _fn_name.startswith("jac_fmt_")
                    or _fn_name.startswith("_jac_fmt_")
                    or _fn_name == "__jac_glob_init_fmt_kernel"
                ) {
                return True;
            }
        }
    } except Exception {
        return False;
    }
    return False;
}

impl NativeCompilePass._link_fmt_kernel(main_mod: ModuleRef) -> None {
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
    } except Exception as _e {}
}

impl NativeCompilePass.transform(ir_in: uni.Module) -> uni.Module {
    self.ir_out = ir_in;
    ir_in spawn self;
    out = self.ir_out;
    assert isinstance(out, uni.Module);
    return out;
}

impl NativeCompilePass.run_walk with uni.Module entry {
    self.ir_out = self._run_impl(here);
}
