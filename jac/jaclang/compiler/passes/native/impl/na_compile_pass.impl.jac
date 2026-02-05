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
        libgc_name = ctypes.util.find_library("gc");
        if libgc_name {
            llvm.load_library_permanently(libgc_name);
        } else {
            # Fallback: map GC_malloc/GC_init to libc malloc/noop
            libc = _ct.CDLL(libc_name);
            malloc_addr = _ct.cast(libc.malloc, _ct.c_void_p).value;
            llvm.add_symbol("GC_malloc", malloc_addr);
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
            import from jaclang.pycore.interop_bridge { register_py_callbacks }
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
    import from jaclang.pycore.codeinfo { NativeModuleInfo, NativeFunctionInfo }
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
        }

        if not os.path.exists(full_path) {
            self.log_warning(f"Native module not found: {full_path}");
            continue;
        }

        # Compile the imported module to get its LLVM IR.
        # Use options with skip_native_engine=True to skip JIT engine creation.
        import from jaclang.pycore.compile_options { CompileOptions }
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
            # Parse the imported module's IR
            imported_llvm_str = str(imported_ir.gen.llvm_ir);
            imported_mod = llvm.parse_assembly(imported_llvm_str);

            # Link the imported module into the main module at IR level
            # This merges the imported module's functions into main_mod
            main_mod.link_in(imported_mod);

            # Create module info for tracking
            mod_info = NativeModuleInfo(
                mod_path=full_path,
                llvm_module=imported_mod,
                native_engine=None  # No separate engine needed - linked into main
            );

            # Track exported functions
            for func in imported_mod.functions {
                func_name = func.name;
                if not func_name.startswith("llvm.") and not func.is_declaration {
                    mod_info.exported_functions[func_name] = NativeFunctionInfo(
                        name=func_name
                    );
                }
            }

            linked_modules[source_mod_path] = mod_info;
            module.gen.interop_manifest.native_module_imports[source_mod_path] = mod_info;
        } except Exception as e {
            self.log_warning(f"Failed to link native module {full_path}: {e}");
        }
    }
}
