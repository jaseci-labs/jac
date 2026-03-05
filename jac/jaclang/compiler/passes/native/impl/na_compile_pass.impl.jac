"""Initialize the native compile pass."""
impl NativeCompilePass.init(
    ir_in: uni.Module, prog: object, cancel_token: (object | None) = None
) -> None {
    llvm.initialize_native_target();
    llvm.initialize_native_asmprinter();
    super.init(ir_in=ir_in, prog=prog, cancel_token=cancel_token);
}

"""Compile the LLVM IR module if one was generated."""
impl NativeCompilePass.transform(ir_in: uni.Module) -> uni.Module {
    module = ir_in;
    if module.gen.llvm_ir is None {
        return ir_in;
    }
    # Skip engine creation if this module is being compiled as an import
    # during native cross-module linking. When compiling imported .na.jac
    # modules, we only need their LLVM IR which will be linked into the
    # main module's IR. The main module creates the single JIT engine that
    # executes all linked native code.
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
        clib_paths = getattr(module.gen, '_clib_paths', None);
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
                            self.log_warning(f"C library not found: {lib_path}");
                        }
                    }
                } except Exception as lib_err {
                    self.log_warning(
                        f"Failed to load C library '{lib_path}': {lib_err}"
                    );
                }
            }
        }
        mod = llvm.parse_assembly(llvm_ir_str);
        mod.verify();
        target = llvm.Target.from_default_triple();
        target_machine = target.create_target_machine();

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

        engine = llvm.create_mcjit_compiler(mod, target_machine);
        module.gen.native_engine = engine;
    } except Exception as e {
        self.log_error(f"Native compilation failed: {e}");
    }
    return ir_in;
}

"""Link imported .na.jac modules at IR level (before JIT compilation)."""
impl NativeCompilePass._compile_and_link_native_imports(
    module: uni.Module, main_mod: object, imports: list, target_machine: object
) -> None {
    import os;
    import from jaclang.jac0core.codeinfo { NativeModuleInfo, NativeFunctionInfo }
    # Keep track of linked modules to avoid duplicate linking
    linked_modules: dict = {};
    for binding in imports {
        source_mod_path = binding.source_module;
        if source_mod_path is None or source_mod_path in linked_modules {
            continue;
        }

        # Resolve the module path relative to current module
        base_dir = os.path.dirname(module.loc.mod_path) if module.loc else ".";
        # Handle .na suffix (convert to .na.jac if needed)
        if source_mod_path.endswith(".na") {
            full_path = os.path.join(base_dir, source_mod_path + ".jac");
            if not os.path.exists(full_path) {
                full_path = os.path.join(
                    base_dir, source_mod_path.replace(".na", ".na.jac")
                );
            }
        } else {
            full_path = os.path.join(base_dir, source_mod_path);
            # Also check if a .na.jac version exists (e.g., tokens → tokens.na.jac)
            if not os.path.exists(full_path) {
                na_path = os.path.join(base_dir, source_mod_path + ".na.jac");
                if os.path.exists(na_path) {
                    full_path = na_path;
                }
            }
        }

        if not os.path.exists(full_path) {
            self.log_warning(f"Native module not found: {full_path}");
            continue;
        }

        # Compile the imported module to get its LLVM IR.
        # Use options with skip_native_engine=True to skip JIT engine creation.
        import from jaclang.jac0core.compile_options { CompileOptions }
        import_options = CompileOptions(skip_native_engine=True);
        try {
            imported_ir = self.prog.compile(
                file_path=full_path, options=import_options
            );
        } except Exception as e {
            self.log_warning(f"Failed to compile native module {full_path}: {e}");
            continue;
        }

        if imported_ir is None or imported_ir.gen.llvm_ir is None {
            self.log_warning(f"Failed to compile native module: {full_path}");
            continue;
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

            linked_modules[source_mod_path] = mod_info;
            module.gen.interop_manifest.native_module_imports[source_mod_path] = mod_info;
        } except Exception as e {
            self.log_warning(f"Failed to link native module {full_path}: {e}");
        }
    }
}
