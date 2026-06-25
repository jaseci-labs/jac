"""Serialize to the .ir_meta cache dict."""
impl DepClibMeta.to_meta -> dict {
    return {
        "clib_paths": self.clib_paths,
        "clib_symbol_lib": self.clib_symbol_lib,
        "exported_symbols": self.exported_symbols,
        "imported_symbols": self.imported_symbols,
        "owned_symbols": self.owned_symbols,
        "transitive_deps": self.transitive_deps
    };
}

"""Build from a .ir_meta cache dict (missing keys default to empty)."""
impl DepClibMeta.from_meta(meta: dict) -> DepClibMeta {
    return DepClibMeta(
        clib_paths=meta.get("clib_paths", []),
        clib_symbol_lib=meta.get("clib_symbol_lib", {}),
        exported_symbols=meta.get("exported_symbols", []),
        imported_symbols=meta.get("imported_symbols", []),
        owned_symbols=meta.get("owned_symbols", []),
        transitive_deps=meta.get("transitive_deps", [])
    );
}

"""Merge the propagated C-ABI surface up into the root module's IR-gen state."""
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

"""Initialize the native compile pass."""
impl NativeCompilePass.postinit -> None {
    llvm.initialize_native_target();
    llvm.initialize_native_asmprinter();
    super.postinit();
}

"""Compile the LLVM IR module if one was generated."""
impl NativeCompilePass.transform(ir_in: uni.Module) -> uni.Module {
    module = ir_in;
    if module.gen.llvm_ir is None {
        return ir_in;
    }
    # Snapshot prog._compile_options at pass entry. This field is mutated by
    # every prog.compile() call (including the recursive ones we issue below
    # while linking imports), so reading it later would pick up the inner
    # caller's options instead of ours.
    _compile_opts = self.prog._compile_options;
    # Skip engine creation if this module is being compiled as an import
    # during native cross-module linking. We only need the LLVM IR here;
    # the parent's _compile_and_link_native_imports will collect ALL
    # transitive deps itself (DFS with a shared visited set) and link them
    # into the single top-level module — so we must NOT link anything here
    # to avoid duplicate symbols.
    if _compile_opts.skip_native_engine {
        return ir_in;
    }
    llvm_ir_str = str(module.gen.llvm_ir);
    try {
        # Load shared libraries so MCJIT can resolve external symbols
        import ctypes as _ct;
        import ctypes.util;
        libc_name = ctypes.util.find_library("c");
        if libc_name {
            llvm.load_library_permanently(libc_name);
        }
        # Note: libgc (Boehm GC) no longer needed — using reference counting
        # Load C shared libraries from import from "lib" { ... } declarations
        import os;
        clib_paths = module.gen._clib_paths;
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
        # Honor a JAC_NATIVE_TARGET cross-compile override; the IR already
        # carries the matching triple/data layout from NaIRGenPass.postinit.
        _nc_target_ovr = os.environ.get("JAC_NATIVE_TARGET", "");
        if _nc_target_ovr {
            llvm.initialize_all_targets();
            llvm.initialize_all_asmprinters();
            target = llvm.Target.from_triple(_nc_target_ovr);
        } else {
            target = llvm.Target.from_default_triple();
        }
        # In debug mode: no optimisation so GDB sees real call frames;
        # jit=True picks the right code model (large on x86-64) for MCJIT.
        _native_debug: bool = bool(os.environ.get("JAC_NATIVE_DEBUG", ""));
        if _native_debug {
            target_machine = target.create_target_machine(opt=0, jit=True);
        } else {
            target_machine = target.create_target_machine(jit=True);
        }

        # Register Python function callbacks before creating engine
        # so MCJIT can resolve them during code generation (sv↔na interop)
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

        # Link imported .na.jac modules at IR level (na↔na linking)
        cross_module_imports = manifest.native_cross_module_imports;
        if cross_module_imports {
            self._compile_and_link_native_imports(
                module, mod, cross_module_imports, target_machine
            );
            # Update llvm_ir with the linked module for caching
            # (the original llvm_ir was pre-linking)
            module.gen.llvm_ir = mod;
        }

        # Link the portable OSP kernel's IR when this program uses Object-Spatial
        # spawn/visit (issue #6146). NaIRGenPass marks DIRECT use on the entry
        # module via native_transitive_sources. But a thin entry that only
        # delegates -- doing no OSP itself while an imported module does the
        # spawn -- carries no such mark, yet the imported IR (already linked into
        # `mod` above) still references the kernel's glob-init. Link the kernel
        # whenever ANY linked module needs it: the dangling `__jac_glob_init_osp_kernel`
        # declaration in the merged IR is the ground truth (issue #6669).
        _needs_osp_kernel = (manifest is not None)
        and ("osp_kernel" in manifest.native_transitive_sources);
        if (not _needs_osp_kernel) and self._references_undefined_osp_kernel(mod) {
            _needs_osp_kernel = True;
        }
        if _needs_osp_kernel {
            self._link_osp_kernel(mod);
            module.gen.llvm_ir = mod;
        }

        # Run LLVM optimization pipeline (after linking, before JIT)
        import os as _os;
        _opt_level = int(_os.environ.get("JAC_OPT_LEVEL", "2"));
        # Never optimise in debug mode — optimisation strips debug info and
        # inlines / re-orders code so GDB backtraces are misleading.
        if _native_debug {
            _opt_level = 0;
        }
        if _opt_level > 0 {
            pto = llvm.create_pipeline_tuning_options(
                speed_level=_opt_level, size_level=0
            );
            pb = llvm.create_pass_builder(target_machine, pto);
            opt_mpm = pb.getModulePassManager();
            opt_mpm.run(mod, pb);
        }

        # Debug: dump IR before JIT compilation (after optimization)
        _dump_path = _os.environ.get("JAC_DUMP_IR", "");
        if _dump_path {
            with open(_dump_path, "w") as _f {
                _f.write(str(mod));
            }
        }

        # Store post-optimization bitcode for fast cache loading.
        # This must happen AFTER optimization but BEFORE create_mcjit_compiler
        # which consumes the module. Bitcode is faster to parse than text IR
        # and preserves the optimization work.
        module.gen.native_bitcode = mod.as_bitcode();

        # ── Debug mode: emit relocatable object file with DWARF info ─────────
        # MCJIT's __jit_debug_register_code is a local symbol in llvmlite's
        # libllvmlite.so, so GDB can't set the breakpoint it needs for live
        # JIT symbol resolution.  Instead we emit a proper ELF .o file with
        # full DWARF sections (debug_info, debug_line, debug_abbrev …) and
        # store the path for jac-gdb to load via GDB's `add-symbol-file`.
        # The object file is written BEFORE create_mcjit_compiler which
        # consumes the module.
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
                # print(f"[JAC_NATIVE_DEBUG] Debug object: {_debug_obj_path}");

                # Re-parse the module IR since emit_object may have consumed it.
                # The original llvm_ir_str is still valid (pre-optimisation text).
                mod = llvm.parse_assembly(str(module.gen.llvm_ir));
                mod.verify();
                # Re-store bitcode from the freshly parsed module
                module.gen.native_bitcode = mod.as_bitcode();
            } except Exception as _dbg_err {
            # print(
            #     f"[JAC_NATIVE_DEBUG] Warning: could not emit debug object: {_dbg_err}"
            # );
            }
        }

        # AOT mode (used by nacompile): all imports are linked and the
        # linked+optimised bitcode is stored above. Skip JIT engine creation
        # so the module is not consumed and the caller can emit object code.
        if _compile_opts.aot_mode {
            return ir_in;
        }

        # Short-circuit before JIT creation if any link-time errors were emitted
        # (e.g. E5024/E5025/E5026). Running create_mcjit_compiler on broken IR
        # can crash or produce misleading follow-on errors.
        if self.errors_had {
            return ir_in;
        }

        # Collect all function names from the module BEFORE create_mcjit_compiler
        # consumes it.  We need these to build the symbol map for GDB.
        _all_fn_names: list = [];
        if _native_debug and _debug_obj_path {
            try {
                for _fn in mod.functions {
                    _fn_name_str = _fn.name;
                    # Skip declarations (external functions like memcpy, printf …)
                    if not _fn.is_declaration {
                        _all_fn_names.append(_fn_name_str);
                    }
                }
            } except Exception { }
        }

        engine = llvm.create_mcjit_compiler(mod, target_machine);
        # In debug mode, register JIT code with GDB so function names and
        # DWARF line info appear in backtraces instead of bare addresses.
        if _native_debug {
            try {
                engine.enable_jit_events();
            } except Exception { }
        }
        module.gen.native_engine = engine;

        # ── Write symbol map for jac-gdb ─────────────────────────────────────
        # After MCJIT finalises, query the JIT address of each function so
        # jac-gdb can tell GDB where .text was loaded in memory.
        if _native_debug and _debug_obj_path and _all_fn_names {
            try {
                # Find the minimum JIT address — that's the .text base
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
                    # Write the symmap file
                    _symmap_path = _os.path.join(_ir_dir, _stem + ".symmap");
                    with open(_symmap_path, "w") as _sf {
                        _sf.write(f"{_debug_obj_path}\n");
                        _sf.write(f"0x{_text_addr:x}\n");
                        # Write per-function addresses
                        for (_fn_name, _addr) in _fn_addrs {
                            _sf.write(f"{_fn_name} 0x{_addr:x}\n");
                        }
                    }
                    # print(f"[JAC_NATIVE_DEBUG] Symbol map: {_symmap_path}");
                } else {
                    # print(
                    #     "[JAC_NATIVE_DEBUG] Warning: no JIT function addresses found"
                    # );
                }
            } except Exception as _sym_err {
            # print(
            #     f"[JAC_NATIVE_DEBUG] Warning: could not write symbol map: {_sym_err}"
            # );
            }
        }
    } except Exception as e {
        self.emit(E5020, error=str(e));
    }
    return ir_in;
}

"""Load a C shared library so MCJIT can resolve its symbols at JIT time.

A logical import (issue #6387) may carry a loader token (`$ORIGIN` /
`@loader_path`) meant for the AOT binary's DT_NEEDED; at JIT time there is no
output binary, so strip it and resolve the remainder relative to the current
directory, then fall back to soname / `find_library` lookup. Shared by the
top-level module's own clibs and the transitive clibs an imported module pulls
in (issue #6687: an imported module's `$ORIGIN/...` clib was never loaded into
the JIT, so its FFI symbols resolved to NULL and the program SIGSEGV'd -- while
the AOT binary, whose loader honors `$ORIGIN`, ran fine). Returns True when the
library was loaded."""
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
    # 1. An explicit/relative/sibling file that exists on disk. Pass the
    #    ABSOLUTE path: dlopen only loads a named file when the string contains
    #    a slash; a bare "libfoo.so" is treated as a soname and searched on the
    #    system path instead of the cwd-relative file we just found.
    for cand in [lib_path, probe, os.path.join(".", base)] {
        if cand and os.path.exists(cand) {
            llvm.load_library_permanently(os.path.abspath(cand));
            return True;
        }
    }
    # 2. dlopen by soname (searches LD_LIBRARY_PATH + ldcache).
    try {
        llvm.load_library_permanently(base);
        return True;
    } except Exception { }
    # 3. find_library on the bare stem (handles versioned sonames, e.g.
    #    libraylib.so -> libraylib.so.5).
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

"""Link imported .na.jac modules at IR level (before JIT compilation)."""
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

    # ── Compiler fingerprint for cache invalidation ─────────────────────
    # Hash all .jac implementation files so that any compiler change
    # automatically invalidates stale .ir_cache files.  Computed once per
    # _compile_and_link_native_imports call (negligible vs. compile time).
    import glob as _cgl;
    import jaclang as _jlm;
    _jl_dir = os.path.dirname(os.path.abspath(_jlm.__file__));
    _nat_dir = os.path.join(_jl_dir, "compiler", "passes", "native");
    _comp_h = hashlib.sha256();
    for _cp in [
        os.path.join(_nat_dir, "impl", "*.jac"),
        os.path.join(_nat_dir, "na_ir_gen_pass.impl", "*.jac"),

    ] {
        for _cf in sorted(_cgl.glob(_cp)) {
            try {
                with open(_cf, "rb") as _cfh {
                    _comp_h.update(_cfh.read());
                }
            } except Exception { }
        }
    }
    _compiler_fp = _comp_h.hexdigest()[:8];

    # Keep track of linked modules to avoid duplicate linking.
    # Keyed by os.path.realpath so diamond deps (A→B→C, A→C) are linked once.
    linked_modules: dict = {};
    # Track which module originally defined each exported symbol, so collision
    # error messages can name both conflicting source files.  We use this dict
    # as the AUTHORITATIVE source of "what is defined and where", rather than
    # querying main_mod.get_function(...).is_declaration after link_in() —
    # that can be unreliable across llvmlite versions for cross-module
    # declarations promoted to definitions during linking.
    symbol_origins: dict = {};  # symbol_name -> module_path
    # Parallel to symbol_origins: True when the recording module genuinely
    # *owns* the symbol (declares it with `def:pub`), False when the symbol
    # is only present because the module imported it and the dep's definition
    # got pulled into its IR transitively. A real collision (E5026) requires
    # two *owning* modules; an owner-vs-carrier overlap is the same symbol
    # reached twice and is benign.
    symbol_owned: dict = {};  # symbol_name -> bool
    _MAIN_ORIGIN = "(main module)";
    # Names the main module imports from other native modules — used to tell
    # owned definitions apart from transitively-carried ones.
    _main_imported_names: set = set();
    _main_manifest = module.gen.interop_manifest;
    if _main_manifest is not None {
        for _imp_b in _main_manifest.native_cross_module_imports {
            _main_imported_names.add(_imp_b.name);
        }
    }
    # Seed symbol_origins with the main module's own non-declaration symbols.
    # Otherwise the very first imported module that legitimately *declares*
    # one of main's functions could be mis-flagged as a collision after a
    # subsequent module *defines* the same name.
    _INTERNAL_LINKAGE = 8;  # internal — per-module, renamed on link_in
    _PRIVATE_LINKAGE = 9;  # private  — per-module
    _WEAK_LINKAGE = 5;  # weak     — linker merges; safe to define in multiple modules
    _WEAK_ODR_LINKAGE = 6;  # weak_odr — same, body guaranteed identical across modules
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
    # Work queue: (binding, base_dir). Seeded with direct imports; transitive
    # deps are appended after each successful compile.
    # Lightweight binding for cache-hit transitive deps: only .source_module is
    # accessed in the outer loop (unlike InteropBinding which also has .name).
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
    # Resolve the bundled native-stdlib root once: it is invariant for this
    # compile, so hoisting it avoids a redundant os.path.isdir() probe per
    # local-miss dep inside the loop below (issue #6940).
    import from jaclang.jac0core.codeinfo { native_stdlib_root }
    _bundled_stdlib_root = native_stdlib_root();
    queue_idx = 0;
    while queue_idx < len(work_queue) {
        (binding, cur_base_dir) = work_queue[queue_idx];
        queue_idx += 1;
        source_mod_path = binding.source_module;
        if source_mod_path is None {
            # No source path => nothing to resolve, compile, or link. This early
            # skip is also the invariant that keeps the AOT clib merge below
            # implicit: meta.clib_paths is only ever populated AFTER this guard,
            # so a clib-bearing dep always carries a source_module and always
            # reaches meta.propagate_to (which appends to module.gen._clib_paths
            # for AOT). There is no path that has clib_paths but no source_module.
            continue;
        }

        # Resolve the module path relative to the declaring module
        if source_mod_path.endswith(".na") {
            full_path = os.path.join(cur_base_dir, source_mod_path + ".jac");
            if not os.path.exists(full_path) {
                full_path = os.path.join(
                    cur_base_dir, source_mod_path.replace(".na", ".na.jac")
                );
            }
        } else {
            full_path = os.path.join(cur_base_dir, source_mod_path);
            # Also check if a .na.jac version exists (e.g., tokens → tokens.na.jac)
            if not os.path.exists(full_path) {
                na_path = os.path.join(cur_base_dir, source_mod_path + ".na.jac");
                if os.path.exists(na_path) {
                    full_path = na_path;
                }
            }
        }

        # Bundled native stdlib fallback (issue #6940): a dep whose
        # source_module names a shipped na_stdlib module lives outside the
        # importing project's tree, so the relative joins above miss it.
        # Re-root the same `<source>.na.jac` suffix at the bundled stdlib dir
        # so the bundled module's object code is compiled and link_in'd exactly
        # like a user dep. resolve_native_module already chose this module for
        # the importer; this is the matching link-side lookup.
        if (not os.path.exists(full_path)) and _bundled_stdlib_root is not None {
            _bundled_rel = source_mod_path + ".jac"
                if source_mod_path.endswith(".na")
                else source_mod_path
                    if source_mod_path.endswith(".jac")
                    else source_mod_path + ".na.jac";
            _bundled_cand = os.path.join(_bundled_stdlib_root, _bundled_rel);
            if os.path.exists(_bundled_cand) {
                full_path = _bundled_cand;
            }
        }

        if not os.path.exists(full_path) {
            self.emit(W5023, path=full_path);
            continue;
        }

        # Dedup by canonical path so different relative spellings of the
        # same file are recognised as identical.
        real_path = os.path.realpath(full_path);
        if real_path in linked_modules {
            continue;
        }
        linked_modules[real_path] = None;  # mark visited before compile

        # ── Incremental compilation: check IR cache before recompiling ────
        # Hash the source file + compiler fingerprint to form the cache key.
        # Cache layout: <cache_dir>/<stem>.<src_hash>.<comp_fp>.ir_cache
        #               <cache_dir>/<stem>.<src_hash>.<comp_fp>.ir_meta
        # where <cache_dir> is get_native_cache_dir(source) — the project's
        # .jac/cache/native/ (or the global cache for installed sources).
        # The .ir_cache file contains the raw LLVM IR text (pre-rename).
        # The .ir_meta file contains clib_paths and transitive dep info.
        # Including _compiler_fp ensures stale caches from a previous compiler
        # version are never reused after compiler implementation files change.
        import from jaclang.jac0core.jir { get_native_cache_dir }
        _src_stem = os.path.splitext(os.path.basename(real_path))[0];
        if _src_stem.endswith(".na") {
            _src_stem = _src_stem[:-3];
        }
        _ir_cache_dir = str(get_native_cache_dir(real_path));

        _source_hash = "";
        _cache_ir_path = "";
        _cache_meta_path = "";
        _cache_hit = False;
        imported_llvm_str_raw = "";
        # All per-dep native C-ABI metadata in one carrier: cache round-trip via
        # to_meta/from_meta, root-module merge via propagate_to. See DepClibMeta.
        meta = DepClibMeta();

        try {
            with open(real_path, "rb") as _sf {
                _source_hash = hashlib.sha256(_sf.read()).hexdigest()[:12];
            }
            _cache_ir_path = os.path.join(
                _ir_cache_dir, f"{_src_stem}.{_source_hash}.{_compiler_fp}.ir_cache"
            );
            _cache_meta_path = os.path.join(
                _ir_cache_dir, f"{_src_stem}.{_source_hash}.{_compiler_fp}.ir_meta"
            );

            if os.path.exists(_cache_ir_path) and os.path.exists(_cache_meta_path) {
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

        if _cache_hit {
            # Use cached IR — skip full compilation. meta already carries the
            # clib paths / exports / symbol map; just enqueue transitive deps.
            dep_base = os.path.dirname(full_path);
            for dep_mod_path in meta.transitive_deps {
                work_queue.append((_DepBinding(dep_mod_path), dep_base));
            }
        } else {
            # No cache hit — compile from scratch
            import from jaclang.jac0core.compile_options { CompileOptions }
            import_options = CompileOptions(skip_native_engine=True, type_check=False);
            try {
                import re as _own_re;
                with open(real_path, "r") as _src_f {
                    _src_txt = _src_f.read();
                }
                _owned_seen: set[str] = set();
                for _def_m in _own_re.finditer(
                    r"\bdef(?::[A-Za-z_, ]+)?\s+([A-Za-z_]\w*)\s*\(", _src_txt
                ) {
                    _owned_seen.add(_def_m.group(1));
                }
                for _glob_m in _own_re.finditer(
                    r"(?:\bglob|,)\s*([A-Za-z_]\w*)\s*:", _src_txt
                ) {
                    _owned_seen.add(_glob_m.group(1));
                }
                meta.owned_symbols = list(_owned_seen);
            } except Exception { }
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
            imported_llvm_str_raw = str(imported_ir.gen.llvm_ir);
            meta.clib_paths = imported_ir.gen._clib_paths or [];
            meta.clib_symbol_lib = imported_ir.gen._clib_symbol_lib or {};
            meta.exported_symbols = imported_ir.gen._exported_symbols or [];
            # Collect transitive dep paths for cache metadata
            dep_manifest = imported_ir.gen.interop_manifest;
            if dep_manifest is not None {
                dep_base = os.path.dirname(full_path);
                for dep_binding in dep_manifest.native_cross_module_imports {
                    if dep_binding.source_module is not None {
                        meta.transitive_deps.append(dep_binding.source_module);
                        work_queue.append((dep_binding, dep_base));
                    }
                    # The imported symbol's name — a definition carrying this
                    # name in the dep's IR is transitively linked, not owned.
                    if dep_binding.name {
                        meta.imported_symbols.append(dep_binding.name);
                    }
                }
            }
            # Write cache files (best-effort, don't fail build on cache errors)
            try {
                os.makedirs(_ir_cache_dir, exist_ok=True);
                # Remove stale caches for this stem (different hash)
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

        # Load each .so/.dylib so MCJIT can resolve its external symbols at JIT
        # time; without this a transitive `import from "lib.so"` in a dep
        # segfaults on an unresolved symbol at runtime (#6687). _jit_load_clib
        # strips the AOT-only `$ORIGIN`/`@loader_path` token a logical import
        # carries, which a bare os.path.exists/find_library could not resolve.
        # This runs before parse_assembly so MCJIT can bind symbols immediately.
        for dep_lib_path in meta.clib_paths {
            try {
                self._jit_load_clib(dep_lib_path);
            } except Exception { }
        }

        # Transitive deps already enqueued above (both cache-hit and cache-miss).
        try {
            # Parse the imported module's IR, renaming jac_entry to avoid
            # duplicate symbol conflicts (each .na.jac has its own entry).
            # LLVM IR may quote names as @"jac_entry" or use bare @jac_entry.
            # imported_llvm_str_raw is set by both cache-hit and cache-miss.
            imported_llvm_str = imported_llvm_str_raw;
            # Unique per-module suffix (human-readable slug + sha1 of the
            # original source_module_str) so 'math_utils.na' and
            # 'math/utils.na' can't collide on __jac_entry_ / __jac_glob_init_.
            # Centralized in codeinfo.native_safe_sym so the emit side here,
            # the IR-gen side (func.impl.jac), the AOT shared-init emitter
            # (nacompile.impl.jac), and the JIT runtime lookup
            # (native_marshal.init_native_globals) all agree on the name.
            safe_name = native_safe_sym(source_mod_path);
            entry_rename = f"__jac_entry_{safe_name}";
            imported_llvm_str = imported_llvm_str.replace(
                '@"jac_entry"', f'@"{entry_rename}"'
            );
            imported_llvm_str = imported_llvm_str.replace(
                "@jac_entry", f"@{entry_rename}"
            );
            # Also update DISubprogram name: for jac_entry so GDB resolves it
            imported_llvm_str = imported_llvm_str.replace(
                'name: "jac_entry"', f'name: "{entry_rename}"'
            );
            # Rename __jac_glob_init to __jac_glob_init_<safe_name> so each
            # imported module's initializer has a unique symbol after linking.
            glob_init_rename = f"__jac_glob_init_{safe_name}";
            imported_llvm_str = imported_llvm_str.replace(
                '@"__jac_glob_init"', f'@"{glob_init_rename}"'
            );
            imported_llvm_str = imported_llvm_str.replace(
                "@__jac_glob_init", f"@{glob_init_rename}"
            );
            # Also update DISubprogram name: for __jac_glob_init so GDB resolves it
            imported_llvm_str = imported_llvm_str.replace(
                'name: "__jac_glob_init"', f'name: "{glob_init_rename}"'
            );
            imported_mod = llvm.parse_assembly(imported_llvm_str);

            # Merge this dep's C-ABI surface into root only after a successful
            # parse -- keeps clib_paths/symbol_lib/exported_symbols clean if
            # the IR is malformed (E5025 path). JIT loads above run regardless
            # since they are idempotent and must precede MCJIT symbol binding.
            # first-seen-wins. See DepClibMeta.propagate_to.
            meta.propagate_to(module.gen);

            # Collect exported function names BEFORE linking, because
            # link_in consumes the module and invalidates its references.
            # Also detect symbol collisions: if an externally-visible
            # *definition* in the imported module corresponds to a symbol
            # already defined by a previously linked module (or by main_mod
            # itself), emit an error instead of silently merging (which
            # causes SIGSEGV).  We consult our own symbol_origins dict
            # rather than main_mod.get_function(...).is_declaration so that
            # *declarations* brought in by an earlier link_in (e.g. mid
            # declares get_leaf, then leaf defines it) are not misreported
            # as collisions.
            #
            # A genuine collision needs two modules that each *own* the
            # symbol (declare it themselves). When a module merely imports a
            # symbol, a dep's definition can still get carried into its IR
            # transitively — that overlaps the real owner's definition but is
            # the *same* symbol, so it is benign: skip the redundant link
            # without raising E5026 (the real owner already provides it).
            #   linkage 0 = external, 8 = internal, 9 = private
            dep_imported_set: set[str] = set(meta.imported_symbols);
            dep_owned_set: set[str] = set(meta.owned_symbols);
            exported_funcs: list[str] = [];
            # Two separate collision outcomes:
            #   has_real_collision — E5026 was emitted; user must fix their code
            #   _benign_dup_* — symbol transitively carried from a dep that was
            #     already linked; safe to handle without aborting the whole module
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
                # If B has no unique symbols it is a pure transitive carrier —
                # skip link_in entirely. If B has unique symbols, demote the
                # duplicate definitions to available_externally so LLVM resolves
                # them against the already-present definitions and links the rest.
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

            # Record symbol origins first-seen-wins; do not overwrite entries
            # already set by a prior module (including available_externally aliases
            # demoted above — the authoritative origin stays with the first linker).
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

            # Link the imported module into the main module at IR level
            # This merges the imported module's functions into main_mod.
            # After this call, imported_mod is consumed and invalid.
            main_mod.link_in(imported_mod);

            # Create module info for tracking
            mod_info = NativeModuleInfo(
                mod_path=full_path,
                llvm_module=None,
                native_engine=None  # No separate engine needed - linked into main
            );

            # Track exported functions from pre-collected names
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

"""Memoized native LLVM IR (text) of the portable OSP kernel (issue #6146)."""
glob _OSP_KERNEL_IR_CACHE: list = [];

"""Compile `osp_kernel.jac` in native context and return its LLVM IR text, or
None on failure. Cached for the process. Mirrors the cl `build_osp_kernel_js`
on-demand compile: a `.na.jac` copy coerces the kernel to native context."""
def _compile_osp_kernel_ir -> (str | None) {
    if _OSP_KERNEL_IR_CACHE {
        return _OSP_KERNEL_IR_CACHE[0];
    }
    import os;
    import shutil;
    import tempfile;
    import jaclang;
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.compiler.passes.native.na_ir_gen_pass {
        _write_native_osp_source
    }
    # The native OSP source is the portable kernel + the native-only edge
    # adjacency, compiled as one module via the same helper as the
    # NaIRGenPass-side load (osp.impl.jac) so decls and definitions agree.
    # osp_kernel.jac stays pristine.
    _core = os.path.join(os.path.dirname(jaclang.__file__), "jac0core");
    tmp_dir = tempfile.mkdtemp();
    na_copy = os.path.join(tmp_dir, "osp_kernel.na.jac");
    ir_str = None;
    try {
        _write_native_osp_source(_core, na_copy);
        prog = JacProgram();
        m = prog.compile(na_copy);
        if (m is not None) and m?.gen and (m.gen.llvm_ir is not None) {
            ir_str = str(m.gen.llvm_ir);
        }
    } except Exception {
        ir_str = None;
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
    if ir_str is not None {
        _OSP_KERNEL_IR_CACHE.append(ir_str);
    }
    return ir_str;
}

"""True when the merged module references the OSP kernel's glob-init symbol
without defining it. Any OSP-using module emits an `__osp_ensure_init` that calls
`__jac_glob_init_osp_kernel`; the kernel that DEFINES that symbol is only linked
by `_link_osp_kernel`. So a dangling declaration in `main_mod` -- after all
imported modules are linked in -- means an imported (non-entry) module pulled in
OSP and the kernel still needs linking, even though the entry module's manifest
never marked it (issue #6669)."""
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

"""Compile + link the portable OSP kernel's IR into an OSP program's module.

NaIRGenPass has already registered the kernel's structs / globals / function
declarations into `main_mod`; this supplies the definitions and the kernel's
glob-init (renamed to `__jac_glob_init_osp_kernel` so the program entry's
transitive-source call resolves it). issue #6146."""
impl NativeCompilePass._link_osp_kernel(main_mod: object) -> None {
    ir_str = _compile_osp_kernel_ir();
    if ir_str is None {
        return;
    }
    # Rename the kernel's glob-init to a unique symbol that the program entry
    # calls (safe_name "osp_kernel"); mirrors the per-import rename in
    # _compile_and_link_native_imports.
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
        # Leave the kernel unlinked; spawn lowering falls back / errors visibly.
        ;
    }
}
