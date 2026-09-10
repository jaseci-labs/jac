impl module_functions(mod: ModuleRef) -> list {
    fns = mod.functions;
    assert isinstance(fns, Iterator);
    return list(fns);
}

impl module_bitcode(mod: ModuleRef) -> bytes {
    bitcode = mod.as_bitcode();
    assert isinstance(bitcode, bytes);
    return bitcode;
}

impl emit_unit_object(bitcode: bytes, options: CompileOptions) -> bytes {
    mod = llvm.parse_bitcode(bitcode);
    tm = create_unit_target_machine(options);
    result = tm.emit_object(mod);
    assert isinstance(result, bytes);
    return result;
}

impl create_unit_target_machine(
    options: CompileOptions, jit: bool = False
) -> TargetMachine {
    target_ovr = options.native_target or "";
    if target_ovr {
        llvm.initialize_all_targets();
        llvm.initialize_all_asmprinters();
        target = llvm.Target.from_triple(target_ovr);
    } else {
        llvm.initialize_native_target();
        llvm.initialize_native_asmprinter();
        target = llvm.Target.from_default_triple();
    }
    assert isinstance(target, llvm.Target);
    opt = 0 if options.native_debug else 2;
    tm = target.create_target_machine(
        opt=opt, reloc=NATIVE_RELOC_MODEL, codemodel=NATIVE_CODE_MODEL, jit=jit
    );
    assert isinstance(tm, llvm.TargetMachine);
    return tm;
}

impl optimize_unit(
    mod: ModuleRef, target_machine: TargetMachine, opt_level: int
) -> None {
    if opt_level <= 0 {
        return;
    }
    pto = llvm.create_pipeline_tuning_options(speed_level=opt_level);
    pb = llvm.create_pass_builder(target_machine, pto);
    assert isinstance(pb, llvm.PassBuilder);
    mpm = pb.getModulePassManager();
    assert isinstance(mpm, llvm.ModulePassManager);
    mpm.run(mod, pb);
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
    options = self.prog.options;
    try {
        registry = self.prog.native_units();
        cached = None
            if options.no_ir_cache
            else registry.ensure(
                module.loc.mod_path, compile_on_miss=False, options=options
            );
        native_debug = bool(options.native_debug);
        target_machine = create_unit_target_machine(options);
        if cached is not None and cached.bitcode is not None {
            mod = llvm.parse_bitcode(cached.bitcode);
            module.gen.native_bitcode = cached.bitcode;
            module.gen.native_object = cached.object_bytes;
        } else {
            mod = llvm.parse_assembly(str(module.gen.llvm_ir));
            mod.verify();
            opt_level = 0 if native_debug else int(options.opt_level or 0);
            optimize_unit(mod, target_machine, opt_level);
            module.gen.native_bitcode = module_bitcode(mod);
            if native_debug {
                obj_bytes = target_machine.emit_object(mod);
                assert isinstance(obj_bytes, bytes);
                module.gen.native_object = obj_bytes;
            }
            registry.note_codegen(module.loc.mod_path, native_debug);
        }

        dump_path = options.dump_ir_path or "";
        if dump_path {
            with open(dump_path, "w") as f {
                f.write(str(mod));
            }
        }

        debug_obj_path = "";
        if native_debug {
            debug_obj_path = self._emit_debug_products(module, mod, target_machine);
        }

        if options.aot_mode or options.skip_native_engine or self.errors_had {
            return ir_in;
        }

        manifest = module.gen.interop_manifest;
        if manifest.native_imports {
            import from jaclang.runtime.interop_bridge { register_py_callbacks }
            py_func_table: dict = {};
            callbacks_list: list = [];
            register_py_callbacks(manifest, py_func_table, callbacks_list);
            module.gen.interop_py_funcs = py_func_table;
            module.gen._interop_callbacks = callbacks_list;
        }

        import from jaclang.compiler.backends.native.link_plan { jit_engine_for_module }
        engine = jit_engine_for_module(self.prog, module, options);
        if engine is None {
            return ir_in;
        }
        if native_debug {
            try {
                engine.enable_jit_events();
            } except Exception {}
        }
        module.gen.native_engine = engine;
        self._share_engine(module, engine);

        if native_debug and debug_obj_path {
            fn_names: list[str] = [];
            for fn in module_functions(mod) {
                if not fn.is_declaration {
                    fn_names.append(str(fn.name));
                }
            }
            self._write_symbol_map(module, debug_obj_path, fn_names);
        }
    } except Exception as e {
        import from jaclang.compiler.backends.native.link_plan { SymbolCollision }
        if isinstance(e, SymbolCollision) {
            self.emit(
                E5026, symbol=e.symbol, existing_module=e.first, new_module=e.second
            );
        } else {
            self.emit(E5020, error=str(e));
        }
    }
    return ir_in;
}

impl NativeCompilePass._share_engine(module: uni.Module, engine: any) -> None {
    """The plan may have recompiled this module as a unit while settling,
    which evicts the module the importer will ask about and leaves its
    products on the program's artifact carrier; the engine and the interop
    tables go on that carrier too, so the lookup finds them either way.""";
    import os;
    if not (module.loc and module.loc.mod_path) {
        return;
    }
    resolved = os.path.realpath(module.loc.mod_path);
    carrier = self.prog.hub.artifacts.get(resolved);
    if carrier is None or carrier is module.gen {
        return;
    }
    carrier.native_engine = engine;
    carrier.interop_py_funcs = module.gen.interop_py_funcs;
    carrier._interop_callbacks = module.gen._interop_callbacks;
    carrier.interop_manifest = module.gen.interop_manifest;
    carrier.native_layout = module.gen.native_layout;
}

impl NativeCompilePass._emit_debug_products(
    module: uni.Module, mod: ModuleRef, target_machine: TargetMachine
) -> str {
    import os;
    import from jaclang.compiler.driver.jir { get_native_debug_dir }
    mod_path = module.loc.mod_path if module.loc else "jac_native";
    stem = os.path.splitext(os.path.basename(mod_path))[0];
    ir_dir = str(get_native_debug_dir(mod_path));
    try {
        os.makedirs(ir_dir, exist_ok=True);
        debug_obj_path = os.path.join(ir_dir, stem + ".debug.o");
        with open(debug_obj_path, "wb") as of {
            of.write(module.gen.native_object or b"");
        }
        return debug_obj_path;
    } except Exception {
        return "";
    }
}

impl NativeCompilePass._write_symbol_map(
    module: uni.Module, debug_obj_path: str, fn_names: list[str]
) -> None {
    import os;
    engine = module.gen.native_engine;
    if engine is None {
        return;
    }
    try {
        text_addr = 0;
        fn_addrs: list = [];
        for fn_name in fn_names {
            addr = engine.get_function_address(fn_name);
            if addr != 0 {
                fn_addrs.append((fn_name, addr));
                if text_addr == 0 or addr < text_addr {
                    text_addr = addr;
                }
            }
        }
        if text_addr == 0 {
            return;
        }
        symmap_path = os.path.splitext(debug_obj_path)[0] + ".symmap";
        with open(symmap_path, "w") as sf {
            sf.write(f"{debug_obj_path}\n");
            sf.write(f"0x{text_addr:x}\n");
            for (fn_name, addr) in fn_addrs {
                sf.write(f"{fn_name} 0x{addr:x}\n");
            }
        }
    } except Exception {}
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

impl native_linked_ir_text(module: uni.Module) -> str {
    bitcode = module.gen.native_bitcode;
    if bitcode is not None {
        return str(llvm.parse_bitcode(bitcode));
    }
    return str(module.gen.llvm_ir);
}


impl native_demoted_ir_symbols(llvm_ir_text: str) -> list[str] {
    import re as _ds_re;
    _ds_def = _ds_re.compile(
        r'^define\b[^@\n]*@(?:"([^"]+\.__jac_demoted)"'
        r'|([A-Za-z0-9_.$\-]+\.__jac_demoted))\(',
        _ds_re.MULTILINE
    );
    import from jaclang.compiler.backends.native.lowering {
        NativeLoweringKind,
        native_lowering_issues
    }
    found: set[str] = {
        issue.symbol
        for issue in native_lowering_issues(llvm_ir_text)
        if issue.kind == NativeLoweringKind.CALLABLE
    };
    for (_ds_q, _ds_bare) in _ds_def.findall(llvm_ir_text) {
        found.add((_ds_q or _ds_bare)[:-len(".__jac_demoted")]);
    }
    return sorted(found);
}
