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
    # Skip engine creation if this module is being compiled as an import
    # during native cross-module linking. We only need the LLVM IR here;
    # the parent's _compile_and_link_native_imports will collect ALL
    # transitive deps itself (DFS with a shared visited set) and link them
    # into the single top-level module — so we must NOT link anything here
    # to avoid duplicate symbols.
    if self.prog._compile_options.skip_native_engine {
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
                    # Try as absolute/relative path first
                    if os.path.exists(lib_path) {
                        llvm.load_library_permanently(lib_path);
                    } else {
                        # Try system library lookup
                        found = ctypes.util.find_library(lib_path);
                        if found {
                            llvm.load_library_permanently(found);
                        } else {
                            self.emit(W5021, path=lib_path);
                        }
                    }
                } except Exception as lib_err {
                    self.emit(W5022, path=lib_path, error=str(lib_err));
                }
            }
        }
        mod = llvm.parse_assembly(llvm_ir_str);
        mod.verify();
        target = llvm.Target.from_default_triple();
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
            _src_name = _os.path.basename(module.loc.mod_path)
                if module.loc
                else "jac_native";
            _stem = _os.path.splitext(_src_name)[0];
            _src_dir = _os.path.dirname(_os.path.abspath(module.loc.mod_path))
                if module.loc
                else ".";
            _ir_dir = _os.path.join(_src_dir, ".jac_ir");
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
        if self.prog._compile_options.aot_mode {
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
            } except Exception {
                pass;
            }
        }

        engine = llvm.create_mcjit_compiler(mod, target_machine);
        # In debug mode, register JIT code with GDB so function names and
        # DWARF line info appear in backtraces instead of bare addresses.
        if _native_debug {
            try {
                engine.enable_jit_events();
            } except Exception {
                pass;  # best-effort; GDB listener may not be available
            }
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

"""Link imported .na.jac modules at IR level (before JIT compilation)."""
impl NativeCompilePass._compile_and_link_native_imports(
    module: uni.Module, main_mod: object, imports: list, target_machine: object
) -> None {
    import os;
    import from jaclang.jac0core.codeinfo { NativeModuleInfo, NativeFunctionInfo }
    # Keep track of linked modules to avoid duplicate linking.
    # Keyed by os.path.realpath so diamond deps (A→B→C, A→C) are linked once.
    linked_modules: dict = {};
    # Work queue: (binding, base_dir). Seeded with direct imports; transitive
    # deps are appended after each successful compile.
    work_queue: list = [];
    base_dir = os.path.dirname(module.loc.mod_path) if module.loc else ".";
    for binding in imports {
        work_queue.append((binding, base_dir));
    }
    queue_idx = 0;
    while queue_idx < len(work_queue) {
        (binding, cur_base_dir) = work_queue[queue_idx];
        queue_idx += 1;
        source_mod_path = binding.source_module;
        if source_mod_path is None {
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

        # Compile the imported module to get its LLVM IR.
        # Use options with skip_native_engine=True to skip JIT engine creation.
        import from jaclang.jac0core.compile_options { CompileOptions }
        import_options = CompileOptions(skip_native_engine=True);
        try {
            imported_ir = self.prog.compile(
                file_path=full_path, options=import_options
            );
        } except Exception as e {
            self.emit(W5024, path=full_path, error=str(e));
            continue;
        }

        if imported_ir is None or imported_ir.gen.llvm_ir is None {
            self.emit(W5024, path=full_path, error="No LLVM IR generated");
            continue;
        }

        # Load any .so libraries required by this imported module so that
        # MCJIT can resolve their external symbols at JIT compilation time.
        # Without this, transitive `import from "lib.so" { ... }` in a dep
        # module causes an unresolved-symbol segfault at runtime.
        import ctypes.util as _ctu;
        dep_clib_paths = imported_ir.gen._clib_paths;
        if dep_clib_paths {
            # Propagate dep C-lib paths back to the main module so that
            # nacompile (AOT) can discover all needed shared libraries.
            for dep_lib_path in dep_clib_paths {
                if dep_lib_path not in module.gen._clib_paths {
                    module.gen._clib_paths.append(dep_lib_path);
                }
                try {
                    if os.path.exists(dep_lib_path) {
                        llvm.load_library_permanently(dep_lib_path);
                    } else {
                        found_lib = _ctu.find_library(dep_lib_path);
                        if found_lib {
                            llvm.load_library_permanently(found_lib);
                        }
                    }
                } except Exception {
                    pass;  # best-effort; missing lib will fail at JIT time anyway
                }
            }
        }

        # Enqueue transitive deps of this module for DFS traversal.
        dep_manifest = imported_ir.gen.interop_manifest;
        if dep_manifest is not None {
            dep_base = os.path.dirname(full_path);
            for dep_binding in dep_manifest.native_cross_module_imports {
                work_queue.append((dep_binding, dep_base));
            }
        }

        try {
            # Parse the imported module's IR, renaming jac_entry to avoid
            # duplicate symbol conflicts (each .na.jac has its own entry).
            # LLVM IR may quote names as @"jac_entry" or use bare @jac_entry.
            imported_llvm_str = str(imported_ir.gen.llvm_ir);
            import re;
            safe_name = re.sub(r'[^a-zA-Z0-9_]', '_', source_mod_path);
            entry_rename = f"__jac_entry_{safe_name}";
            imported_llvm_str = imported_llvm_str.replace(
                '@"jac_entry"', f'@"{entry_rename}"'
            );
            imported_llvm_str = imported_llvm_str.replace(
                "@jac_entry", f"@{entry_rename}"
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
            imported_mod = llvm.parse_assembly(imported_llvm_str);

            # Collect exported function names BEFORE linking, because
            # link_in consumes the module and invalidates its references
            exported_funcs: list[str] = [];
            for func in imported_mod.functions {
                if not func.name.startswith("llvm.") and not func.is_declaration {
                    exported_funcs.append(func.name);
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
            self.emit(W5025, path=full_path, error=str(e));
        }
    }
}
