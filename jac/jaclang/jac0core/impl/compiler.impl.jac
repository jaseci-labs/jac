impl _SetupProgress.postinit -> None {
    self._seen_files = `set();
}

impl _SetupProgress._get_jaclang_root -> str {
    if (self._jaclang_root is None) {
        self._jaclang_root = os.path.dirname(os.path.dirname(__file__));
    }
    return self._jaclang_root;
}

impl _SetupProgress._atexit_handler -> None {
    if (self._banner_shown and (self._compile_count > 0)) {
        sys.stderr.write(
            f"Jac setup complete ({self._compile_count} modules compiled and cached)\n"
        );
        sys.stderr.flush();
    }
}

impl _SetupProgress.on_internal_compile(file_path: str) -> None {
    normalized = os.path.normpath(file_path);
    if (normalized in self._seen_files) {
        return;
    }
    self._seen_files.add(normalized);
    if not self._banner_shown {
        self._banner_shown = True;
        atexit.register(self._atexit_handler);
        sys.stderr.write(
            '\nSetting up Jac for first use (compiling and caching compiler)...\n'
        );
        sys.stderr.flush();
    }
    jaclang_root = self._get_jaclang_root();
    rel_path = file_path;
    if normalized.startswith((jaclang_root + os.sep)) {
        rel_path = os.path.relpath(normalized, os.path.dirname(jaclang_root));
    }
    self._compile_count += 1;
    sys.stderr.write(f"  Compiling {rel_path}...\n");
    sys.stderr.flush();
}

impl _SetupProgress.is_active.getter -> bool {
    return self._banner_shown;
}

impl JacCompiler.internal_program.getter -> JacProgram {
    if (self._internal_program is None) {
        import from jaclang.jac0core.program { JacProgram }
        prog = JacProgram();
        prog._compiler = self;
        self._internal_program = prog;
    }
    return self._internal_program;
}

impl JacCompiler._get_jaclang_root(cls: any) -> str {
    if (cls._jaclang_root is None) {
        cls._jaclang_root = os.path.realpath(
            os.path.dirname(os.path.dirname(__file__))
        );
    }
    return cls._jaclang_root;
}

impl JacCompiler._resolve_program(
    file_path: str, target_program: JacProgram
) -> JacProgram {
    normalized_path = os.path.realpath(file_path);
    jaclang_root = self._get_jaclang_root();
    if normalized_path.startswith((jaclang_root + os.sep)) {
        return self.internal_program;
    }
    return target_program;
}

impl JacCompiler.get_native_interop_setup(
    full_target: str, target_program: JacProgram
) -> tuple[((object | None), (dict[(str, object)] | None))] {
    actual_program = self._resolve_program(full_target, target_program);
    if (full_target in actual_program._native_cache) {
        gen = actual_program._native_cache[full_target];
        return (gen.native_engine, gen.interop_py_funcs);
    }
    if (full_target in actual_program.mod.hub) {
        mod = actual_program.mod.hub[full_target];
        native_engine = mod.gen.native_engine;
        interop_py_funcs = mod.gen.interop_py_funcs;
        return (native_engine, interop_py_funcs);
    }
    return (None, None);
}

impl JacCompiler.get_native_layout(
    full_target: str, target_program: JacProgram
) -> (object | None) {
    actual_program = self._resolve_program(full_target, target_program);
    if (full_target in actual_program._native_cache) {
        gen = actual_program._native_cache[full_target];
        return gen?.native_layout;
    }
    if (full_target in actual_program.mod.hub) {
        mod = actual_program.mod.hub[full_target];
        return mod.gen?.native_layout;
    }
    return None;
}

impl JacCompiler.get_bytecode(
    full_target: str, target_program: JacProgram
) -> (types.CodeType | None) {
    actual_program = self._resolve_program(full_target, target_program);
    (rebuild, no_precompile) = cache_mode();

    if (
        (not rebuild)
        and (full_target in actual_program.mod.hub)
        and not actual_program.is_hub_entry_fresh(full_target)
    ) {
        actual_program.invalidate_module(full_target);
    }
    if (
        (not rebuild)
        and (full_target in actual_program.mod.hub)
        and actual_program.mod.hub[full_target].gen.py_bytecode
    ) {
        codeobj = actual_program.mod.hub[full_target].gen.py_bytecode;
        return marshal.loads(codeobj) if isinstance(codeobj, `bytes) else None;
    }

    if not rebuild {
        sealed = self._sealed_jir_data(full_target);
        if sealed is not None {
            import from jaclang.jac0core.jir { PRECOMPILE_SENTINEL }
            (sealed_data, sealed_root) = sealed;
            bc = read_bytecode_only(sealed_data);
            if bc is not None {
                magic0: any = SECTIONS_MAGIC;
                sp0 = sealed_data.find(magic0, HEADER_SIZE);
                if sp0 >= 0 {
                    self._restore_sections(
                        full_target,
                        actual_program,
                        read_sections(sealed_data, sp0 + len(magic0))
                    );
                }
                return marshal.loads(
                    patch_co_filenames_bytes(bc, PRECOMPILE_SENTINEL, sealed_root)
                );
            }
        }
    }

    cache_path = get_module_cache_path(full_target);
    if (not rebuild) and is_module_cache_valid(full_target, cache_path) {
        try {
            jir_data = cache_path.read_bytes();
            bc = read_bytecode_only(jir_data);
            if bc is not None {
                magic_bytes: any = SECTIONS_MAGIC;
                sec_pos = jir_data.find(magic_bytes, HEADER_SIZE);
                _had_native_secs = False;
                if sec_pos >= 0 {
                    secs = read_sections(jir_data, sec_pos + len(magic_bytes));
                    self._restore_sections(full_target, actual_program, secs);
                    _had_native_secs = SEC_NATIVE_OBJ in secs or SEC_LLVM_IR in secs;
                }
                import from jaclang.jac0core.ext_registry {
                    is_native_module as _bc_is_na
                }
                if (
                    _had_native_secs
                    and full_target not in actual_program._native_cache
                    and actual_program is not self._internal_program
                    and _bc_is_na(full_target)
                ) {
                    import logging as _bc_logging;
                    _bc_logging.getLogger(__name__).warning(
                        f"Cached native sections for {full_target} could "
                        f"not be restored; recompiling."
                    );

                    cache_path.unlink(missing_ok=True);
                } else {
                    return marshal.loads(bc);
                }
            }
        } except Exception {
            ;
        }
    }

    allow_unsealed = (not rebuild) and (not no_precompile);
    precompiled_bc = self._get_precompiled_jir_bytecode(full_target, allow_unsealed);
    if precompiled_bc is not None {
        try {
            import from jaclang.jac0core.jir { write_precompiled_jir, FLAG_PRECOMPILED }
            jir_bytes = write_precompiled_jir(
                precompiled_bc, compute_module_key(full_target), FLAG_PRECOMPILED
            );
            cache_path.parent.mkdir(parents=True, exist_ok=True);

            import os as _os;
            tmp_path = cache_path.with_suffix(f'.{_os.getpid()}.tmp');
            try {
                tmp_path.write_bytes(jir_bytes);
                tmp_path.rename(cache_path);
            } finally {
                tmp_path.unlink(missing_ok=True);
            }
        } except Exception {
            ;
        }
        return marshal.loads(precompiled_bc);
    }

    is_internal = actual_program is self._internal_program;
    if is_internal {
        setup_progress.on_internal_compile(full_target);
    }

    can_typecheck = (
        is_internal
        and 'jaclang.compiler.passes.main.type_checker_pass' in sys.modules
        and 'jaclang.compiler.type_system.type_evaluator' in sys.modules
        and hasattr(
            sys.modules['jaclang.compiler.passes.main.type_checker_pass'],
            'TypeCheckPass'
        )
        and hasattr(
            sys.modules['jaclang.compiler.type_system.type_evaluator'], 'TypeEvaluator'
        )
    );
    options = CompileOptions(type_check=can_typecheck);
    result = self.compile(
        file_path=full_target, target_program=actual_program, options=options
    );
    if result.gen.py_bytecode {
        actual_program.hub_cache_stamp(full_target);
        try {
            import from jaclang.jac0core.jir_passes { JirWriter }
            import pickle;
            import json;
            import zlib;
            sections: dict[int, bytes] = {};
            sections[SEC_BYTECODE] = result.gen.py_bytecode;
            sections[SEC_MODKEY] = compute_module_key(full_target).encode('utf-8');
            if actual_program.mtir_map {
                sections[SEC_MTIR] = pickle.dumps(
                    actual_program.mtir_map, int(pickle.HIGHEST_PROTOCOL)
                );
            }

            native_bc = result.gen.native_bitcode;
            if native_bc is not None {
                import struct as _struct;
                import jaclang.compiler.passes.native.llvm.binding as _llvm;
                triple = _llvm.get_default_triple().encode('utf-8');
                hdr = _struct.pack('<H', len(triple)) + triple;
                sections[SEC_NATIVE_OBJ] = hdr + native_bc;
            } else {
                llvm_ir = result.gen.llvm_ir;
                if llvm_ir is not None {
                    sections[SEC_LLVM_IR] = zlib.compress(
                        str(llvm_ir).encode('utf-8'), 6
                    );
                }
            }
            interop_dict = self._build_interop_dict(result);
            if interop_dict {
                sections[SEC_INTEROP] = json.dumps(interop_dict).encode('utf-8');
            }
            writer = JirWriter();
            jir_bytes = writer.write_module(result, sections=sections);
            cache_path.parent.mkdir(parents=True, exist_ok=True);

            import os as _os;
            tmp_path = cache_path.with_suffix(f'.{_os.getpid()}.tmp');
            try {
                tmp_path.write_bytes(jir_bytes);
                tmp_path.rename(cache_path);
            } finally {
                tmp_path.unlink(missing_ok=True);
            }
        } except Exception {
            ;
        }
        return marshal.loads(result.gen.py_bytecode);
    }
    return None;
}

impl JacCompiler._load_native_from_cache(
    full_target: str,
    target_program: JacProgram,
    cached_ir: str,
    cached_interop: (dict[str, any] | None)
) -> None {
    try {
        import jaclang.compiler.passes.native.llvm.binding as llvm;
        llvm.initialize_native_target();
        llvm.initialize_native_asmprinter();
        import ctypes;
        import ctypes.util;
        libc_name = ctypes.util.find_library('c');
        if libc_name {
            llvm.load_library_permanently(libc_name);
        }
        libgc_name = ctypes.util.find_library('gc');
        if libgc_name {
            llvm.load_library_permanently(libgc_name);
        } else {
            libc = ctypes.CDLL(libc_name);
            malloc_addr = ctypes.cast(libc.malloc, ctypes.c_void_p).value;
            llvm.add_symbol('GC_malloc', malloc_addr);
        }
        llvm_mod = llvm.parse_assembly(cached_ir);
        llvm_mod.verify();
        target = llvm.Target.from_default_triple();
        target_machine = target.create_target_machine();
        engine = llvm.create_mcjit_compiler(llvm_mod, target_machine);
        import from jaclang.jac0core.codeinfo { CodeGenTarget }
        gen = CodeGenTarget();
        gen.native_engine = engine;
        py_func_table: dict = {};
        callbacks_list: list = [];
        gen.interop_py_funcs = py_func_table;
        gen._interop_callbacks = callbacks_list;
        if cached_interop {
            import from jaclang.jac0core.interop_bridge { register_py_callbacks }
            manifest = self._deserialize_interop_table(cached_interop);
            gen.interop_manifest = manifest;
            if manifest.native_imports {
                register_py_callbacks(manifest, py_func_table, callbacks_list);
            }
        }
        target_program._native_cache[full_target] = gen;
    } except Exception as e {
        import logging;
        logging.getLogger(__name__).debug(
            f"Failed to load native module from cache: {e}"
        );
    }
}

impl JacCompiler._load_native_from_bitcode(
    full_target: str,
    target_program: JacProgram,
    section_data: bytes,
    cached_interop: (dict[str, any] | None)
) -> None {
    import struct as _struct;
    import jaclang.compiler.passes.native.llvm.binding as llvm;
    llvm.initialize_native_target();
    llvm.initialize_native_asmprinter();

    if len(section_data) < 2 {
        raise ValueError("SEC_NATIVE_OBJ section too short");
    }
    (triple_len, ) = _struct.unpack_from('<H', section_data, 0);
    if len(section_data) < 2 + triple_len {
        raise ValueError("SEC_NATIVE_OBJ triple truncated");
    }
    cached_triple = section_data[2:2 + triple_len].decode('utf-8');
    current_triple = llvm.get_default_triple();
    if cached_triple != current_triple {
        raise ValueError(
            f"Platform mismatch: cached={cached_triple}, current={current_triple}"
        );
    }
    bitcode = section_data[2 + triple_len:];

    import ctypes;
    import ctypes.util;
    libc_name = ctypes.util.find_library('c');
    if libc_name {
        llvm.load_library_permanently(libc_name);
    }

    llvm_mod = llvm.parse_bitcode(bitcode);
    target = llvm.Target.from_default_triple();
    target_machine = target.create_target_machine();
    engine = llvm.create_mcjit_compiler(llvm_mod, target_machine);
    import from jaclang.jac0core.codeinfo { CodeGenTarget }
    gen = CodeGenTarget();
    gen.native_engine = engine;
    py_func_table: dict = {};
    callbacks_list: list = [];
    gen.interop_py_funcs = py_func_table;
    gen._interop_callbacks = callbacks_list;
    if cached_interop {
        import from jaclang.jac0core.interop_bridge { register_py_callbacks }
        manifest = self._deserialize_interop_table(cached_interop);
        gen.interop_manifest = manifest;
        if manifest.native_imports {
            register_py_callbacks(manifest, py_func_table, callbacks_list);
        }
    }
    target_program._native_cache[full_target] = gen;
}

impl JacCompiler._restore_sections(
    full_target: str, actual_program: JacProgram, secs: dict[int, bytes]
) -> None {
    import pickle;
    mtir_bytes = secs.get(SEC_MTIR);
    if mtir_bytes is not None {
        try {
            mtir_map = pickle.loads(mtir_bytes);
            actual_program.mtir_map.update(mtir_map);
        } except Exception {
            ;
        }
    }

    native_obj_bytes = secs.get(SEC_NATIVE_OBJ);
    if native_obj_bytes is not None {
        try {
            import json;
            cached_interop: (dict[str, any] | None) = None;
            interop_bytes = secs.get(SEC_INTEROP);
            if interop_bytes is not None {
                cached_interop = json.loads(interop_bytes.decode('utf-8'));
            }
            self._load_native_from_bitcode(
                full_target, actual_program, native_obj_bytes, cached_interop
            );
            return;
        } except Exception {
            ;
        }
    }

    llvm_bytes = secs.get(SEC_LLVM_IR);
    if llvm_bytes is not None {
        try {
            import zlib;
            import json;
            cached_ir = zlib.decompress(llvm_bytes).decode('utf-8');
            cached_interop2: (dict[str, any] | None) = None;
            interop_bytes2 = secs.get(SEC_INTEROP);
            if interop_bytes2 is not None {
                cached_interop2 = json.loads(interop_bytes2.decode('utf-8'));
            }
            self._load_native_from_cache(
                full_target, actual_program, cached_ir, cached_interop2
            );
        } except Exception {
            ;
        }
    }
}

impl JacCompiler._sealed_jir_data(full_target: str) -> (tuple[bytes, str] | None) {
    import from pathlib { Path as _Path }
    import from jaclang.jac0core { sealed as _sealed }
    norm_file = os.path.normpath(os.path.abspath(full_target));
    d = os.path.dirname(norm_file);
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    while True {
        bundle_dir = os.path.join(d, '_precompiled');
        if os.path.isdir(bundle_dir) {
            if _sealed.image_for_bundle_dir(bundle_dir) is None {
                return None;
            }
            norm_root = os.path.normpath(d);
            if not norm_file.startswith(norm_root + os.sep) {
                return None;
            }
            rel_path = norm_file[len(norm_root) + 1:];
            jir_path = os.path.join(
                bundle_dir, pyver, os.path.splitext(rel_path)[0] + '.jir'
            );
            if os.path.isfile(jir_path) {
                try {
                    return (_Path(jir_path).read_bytes(), d);
                } except OSError {
                    return None;
                }
            }
            return None;
        }
        parent = os.path.dirname(d);
        if parent == d {
            return None;
        }
        d = parent;
    }
}

impl JacCompiler._get_precompiled_jir_bytecode(
    full_target: str, allow_unsealed: bool = True
) -> (bytes | None) {
    import from pathlib { Path as _Path }
    import from jaclang.jac0core.jir { PRECOMPILE_SENTINEL }
    import from jaclang.jac0core { sealed as _sealed }
    norm_file = os.path.normpath(os.path.abspath(full_target));
    d = os.path.dirname(norm_file);
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    while True {
        bundle_dir = os.path.join(d, '_precompiled');
        if os.path.isdir(bundle_dir) {
            norm_root = os.path.normpath(d);
            if not norm_file.startswith(norm_root + os.sep) {
                break;
            }
            rel_path = norm_file[len(norm_root) + 1:];
            jir_rel = os.path.splitext(rel_path)[0] + '.jir';
            jir_path = os.path.join(bundle_dir, pyver, jir_rel);

            sealed_img = _sealed.image_for_bundle_dir(bundle_dir);
            if sealed_img is None and not allow_unsealed {
                break;
            }
            if os.path.isfile(jir_path) {
                try {
                    jir_data = _Path(jir_path).read_bytes();
                    trusted = (
                        sealed_img is not None
                        or jir_matches_source(jir_data, norm_file)
                    );
                    if trusted {
                        bc = read_bytecode_only(jir_data);
                        if bc is not None {
                            return patch_co_filenames_bytes(bc, PRECOMPILE_SENTINEL, d);
                        }
                    }
                } except Exception {
                    ;
                }
            }
            break;
        }
        parent = os.path.dirname(d);
        if parent == d {
            break;
        }
        d = parent;
    }
    return None;
}

impl JacCompiler._build_interop_dict(result: uni.Module) -> dict {
    manifest = result.gen.interop_manifest;
    if manifest is None {
        return {};
    }
    interop_data: dict = {'bindings': {}};
    for (name, binding) in manifest.bindings.items() {
        interop_data['bindings'][name] = {
            'source_context': binding.source_context.value,
            'callers': [c.value for c in binding.callers],
            'ret_type': binding.ret_type,
            'param_types': binding.param_types,
            'param_names': binding.param_names,
            'source_module': binding.source_module
        };
    }

    interop_data['func_access'] = dict(manifest.func_access);
    interop_data['walker_access'] = dict(manifest.walker_access);
    interop_data['endpoint_effects'] = dict(manifest.endpoint_effects);
    return interop_data;
}

impl JacCompiler._deserialize_interop_table(
    cached_interop: dict[str, any]
) -> InteropManifest {
    import from jaclang.jac0core.codeinfo {
        InteropManifest,
        InteropBinding,
        InteropContext
    }
    manifest = InteropManifest();
    for (name, data) in cached_interop.get('bindings', {}).items() {
        binding = InteropBinding(
            name=name,
            source_context=InteropContext(data['source_context']),
            callers={InteropContext(c) for c in data.get('callers', [])},
            ret_type=data.get('ret_type', 'int'),
            param_types=data.get('param_types', []),
            param_names=data.get('param_names', []),
            source_module=data.get('source_module')
        );
        manifest.bindings[name] = binding;
    }
    manifest.func_access.update(cached_interop.get('func_access', {}));
    manifest.walker_access.update(cached_interop.get('walker_access', {}));
    manifest.endpoint_effects.update(cached_interop.get('endpoint_effects', {}));
    return manifest;
}

impl JacCompiler.parse_str(
    source_str: str,
    file_path: str,
    target_program: JacProgram,
    cancel_token: (Event | None) = None
) -> uni.Module {
    had_error = False;
    if (file_path.endswith('.py') or file_path.endswith('.pyi')) {
        import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
        parsed_ast = py_ast.parse(source_str);
        py_ast_ret = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                parsed_ast, orig_src=uni.Source(source_str, mod_path=file_path)
            ),
            prog=target_program,
            cancel_token=cancel_token
        );
        had_error = len(py_ast_ret.errors_had) > 0;
        mod = py_ast_ret.ir_out;
    } else {
        import from jaclang.jac0core.parser { parse as rd_parse }
        import from jaclang.jac0core.ext_registry { codespace_of }
        (mod, had_error) = rd_parse(source_str, file_path, prog=target_program);
        codespace = codespace_of(file_path);
        if (codespace == 'client') {
            _coerce_client_module(mod);
        } elif (codespace == 'server') {
            _coerce_server_module(mod);
        } elif (codespace == 'native') {
            _coerce_native_module(mod);
        }
    }
    if had_error {
        return mod;
    }
    if target_program.mod.main.stub_only {
        old_hub = target_program.mod.hub;
        target_program.mod = uni.ProgramModule(main_mod=mod);
        target_program.mod.hub.update(old_hub);
    }
    import from pathlib { Path as _HubPath }
    target_program.mod.hub[str(_HubPath(mod.loc.mod_path).resolve())] = mod;

    JacAnnexPass(ir_in=mod, prog=target_program);
    return mod;
}

impl JacCompiler.compile(
    file_path: str,
    target_program: JacProgram,
    use_str: (str | None) = None,
    options: CompileOptions = CompileOptions()
) -> uni.Module {
    import from jaclang.jac0core.ext_registry { is_annex }
    if (use_str is None and options.resolve_annex_parent and is_annex(file_path)) {
        import from jaclang.jac0core.bccache { discover_base_file }
        base_path = discover_base_file(file_path);
        if (base_path and base_path not in target_program.mod.hub) {
            return self.compile(
                file_path=base_path, target_program=target_program, options=options
            );
        }
    }
    if options.force_target_program {
        actual_program = target_program;
    } else {
        actual_program = self._resolve_program(file_path, target_program);
    }
    actual_program._compile_options = options;
    keep_str = use_str or read_file_with_encoding(file_path);
    had_parse_errors = len(actual_program.errors_had);
    mod_targ = self.parse_str(
        keep_str, file_path, actual_program, cancel_token=options.cancel_token
    );
    had_parse_errors = len(actual_program.errors_had) > had_parse_errors;

    cur_mod_path = os.path.normpath(file_path);
    blocking_errs_pre_ir = self._count_module_blocking_errors(
        actual_program, cur_mod_path
    );
    if options.symtab_ir_only {
        self.run_schedule(
            mod=mod_targ,
            target_program=actual_program,
            passes=get_symtab_ir_sched(),
            cancel_token=options.cancel_token
        );
    } else {
        self.run_schedule(
            mod=mod_targ,
            target_program=actual_program,
            passes=get_ir_gen_sched(),
            cancel_token=options.cancel_token
        );
    }

    blocking_errs_post_ir = self._count_module_blocking_errors(
        actual_program, cur_mod_path
    );
    had_blocking_errors = blocking_errs_post_ir > blocking_errs_pre_ir;

    import from jaclang.jac0core.ext_registry { is_native_module, is_client_module }
    mp = mod_targ.loc.mod_path if (mod_targ?.loc and mod_targ.loc) else file_path;
    is_na_file = bool(mp) and is_native_module(mp);
    is_explicit_native = is_na_file;
    is_client_mod = bool(mp) and is_client_module(mp);
    if (not is_explicit_native or not is_client_mod) and mod_targ?.body {
        for _stmt in mod_targ.body {
            if isinstance(_stmt, uni.NativeBlock) {
                is_explicit_native = True;
            }
            if isinstance(_stmt, uni.ClientBlock) {
                is_client_mod = True;
            }
        }
    }
    is_native_mod = is_explicit_native
    or (
        actual_program._auto_promote_native
        and mod_targ?.gen
        and mod_targ.gen.native_compat
    );

    run_inference = options.type_check
    or is_native_mod
    or (is_client_mod and not options.no_cgen and not options.symtab_ir_only);
    if run_inference {
        mod_targ._inference_started = True;

        if options.symtab_ir_only {
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_cfg_sched(),
                cancel_token=options.cancel_token
            );
        }

        mod_targ._type_check_requested = bool(options.type_check);
        try {
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_inference_sched(),
                cancel_token=options.cancel_token
            );
        } except Exception {
            mod_targ._inference_started = False;
            raise;
        }

        import from jaclang.jac0core.ext_registry { is_native_module as _is_na }
        for dep_mod in list(actual_program.mod.hub.values()) {
            if (dep_mod is mod_targ) or dep_mod?._inference_started {
                continue;
            }
            dep_path = dep_mod.loc.mod_path if dep_mod?.loc else '';
            if _is_na(dep_path) {
                dep_mod._inference_started = True;

                dep_mod._inference_quiet = True;
                try {
                    self.run_schedule(
                        mod=dep_mod,
                        target_program=actual_program,
                        passes=get_inference_sched(),
                        cancel_token=options.cancel_token
                    );
                } except Exception {
                    dep_mod._inference_started = False;
                    raise;
                } finally {
                    dep_mod._inference_quiet = False;
                }
            }
        }
    }
    if options.type_check {
        self.run_schedule(
            mod=mod_targ,
            target_program=actual_program,
            passes=get_type_check_sched(),
            cancel_token=options.cancel_token
        );
    }

    if (
        not had_parse_errors and not had_blocking_errors and not options.symtab_ir_only
    ) {
        self.run_schedule(
            mod=mod_targ,
            target_program=actual_program,
            passes=get_boundary_analysis_sched(),
            cancel_token=options.cancel_token
        );
    }

    if (
        options.no_cgen
        and options.type_check
        and not options.symtab_ir_only
        and not had_parse_errors
        and not had_blocking_errors
        and is_explicit_native
    ) {
        _parity_passes: list[type[Transform[uni.Module, uni.Module]]] = [];
        if getattr(mod_targ, '_inference_started', False) {
            try {
                import from jaclang.compiler.passes.native { NaIRGenPass }
                _parity_passes = [NaIRGenPass];
            } except ImportError {
                _parity_passes = [];
            }
        }
        if not _parity_passes {
            import from jaclang.compiler.passes.main.capability_check_pass {
                NativeCapabilityCheckPass
            }
            _parity_passes = [NativeCapabilityCheckPass];
        }
        self.run_schedule(
            mod=mod_targ,
            target_program=actual_program,
            passes=_parity_passes,
            cancel_token=options.cancel_token
        );
    }

    if (
        not had_parse_errors
        and not had_blocking_errors
        and not options.symtab_ir_only
        and not options.no_cgen
    ) {
        import os as _cb_os;
        cb_seen: set[str] = set();
        cb_worklist: list = [mod_targ];

        cb_opts = CompileOptions(
            type_check=False,
            no_cgen=True,
            force_target_program=True,
            cancel_token=options.cancel_token
        );
        while cb_worklist {
            cb_cur = cb_worklist.pop();
            if cb_cur is None {
                continue;
            }
            for cb_imp in cb_cur.get_all_sub_nodes(uni.Import) {
                if not cb_imp.from_loc {
                    continue;
                }

                cb_tgt = cb_imp.from_loc.dot_path_str
                    if cb_imp.from_loc?.dot_path_str
                    else '';
                if cb_tgt.startswith('@jac/') {
                    continue;
                }
                try {
                    cb_src = cb_imp.from_loc.resolve_relative_path();
                } except Exception {
                    continue;
                }
                import from jaclang.jac0core.ext_registry { is_client_module }
                if not (isinstance(cb_src, str) and is_client_module(cb_src)) {
                    continue;
                }
                cb_src = _cb_os.path.abspath(cb_src);
                if cb_src in cb_seen {
                    continue;
                }
                cb_seen.add(cb_src);
                cb_mod = actual_program.mod.hub.get(cb_src);
                cb_has_facts = (
                    cb_mod is not None
                    and cb_mod.gen
                    and cb_mod.gen.interop_manifest
                    and bool(cb_mod.gen.interop_manifest.bindings)
                );
                if not cb_has_facts {
                    try {
                        cb_mod = self.compile(
                            file_path=cb_src,
                            target_program=actual_program,
                            options=cb_opts
                        );
                    } except Exception {
                        cb_mod = actual_program.mod.hub.get(cb_src);
                    }
                }
                cb_worklist.append(cb_mod);
            }
        }
        actual_program._compile_options = options;
    }
    if (not had_parse_errors and not had_blocking_errors and not options.no_cgen) {
        actual_program._compile_options = options;

        import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }
        needs_native = is_native_mod
        or ModuleCodegenPass.has_native_context_stmts(mod_targ);
        self.run_schedule(
            mod=mod_targ,
            target_program=actual_program,
            passes=get_py_code_gen(native=needs_native),
            cancel_token=options.cancel_token
        );
        if is_na_file {
            JacCompiler._scrub_native_artifacts_on_error(actual_program, mod_targ);
        }
    }
    return mod_targ;
}

impl JacCompiler.build(
    file_path: str,
    target_program: JacProgram,
    use_str: (str | None) = None,
    type_check: bool = False
) -> uni.Module {
    actual_program = self._resolve_program(file_path, target_program);
    options = CompileOptions(type_check=type_check);
    mod_targ = self.compile(file_path, actual_program, use_str, options=options);
    SemanticAnalysisPass(ir_in=mod_targ, prog=actual_program);
    return mod_targ;
}

impl JacCompiler.run_schedule(
    mod: uni.Module,
    target_program: JacProgram,
    passes: list[type[Transform[uni.Module, uni.Module]]],
    cancel_token: (Event | None) = None
) -> None {
    for current_pass in passes {
        if (cancel_token and cancel_token.is_set()) {
            break;
        }
        current_pass(ir_in=mod, prog=target_program, cancel_token=cancel_token);
    }
}

impl JacCompiler._count_module_blocking_errors(
    target_program: JacProgram, mod_path: str
) -> int {
    count = 0;
    for e in target_program.errors_had {
        if e.code is None or not e.code.blocks_codegen {
            continue;
        }
        try {
            e_path = os.path.normpath(e.loc.mod_path);
        } except Exception {
            continue;
        }
        if e_path == mod_path {
            count += 1;
        }
    }
    return count;
}

impl JacCompiler._module_scoped_errors(
    target_program: JacProgram, mod_path: str
) -> bool {
    import from jaclang.jac0core.diagnostics { Category }
    norm = os.path.normpath(mod_path);

    prefix = (norm[:-4] if norm.endswith('.jac') else norm) + '.';
    for e in target_program.errors_had {
        if e.code is None or e.code.category not in (Category.CODEGEN, Category.ICE) {
            continue;
        }
        try {
            e_path = os.path.normpath(e.loc.mod_path);
        } except Exception {
            continue;
        }
        if e_path == norm or e_path.startswith(prefix) {
            return True;
        }
    }
    return False;
}

impl JacCompiler._scrub_native_artifacts_on_error(
    target_program: JacProgram, mod: uni.Module
) -> bool {
    mod_path = mod.loc.mod_path if mod?.loc else '';
    if not mod_path {
        return False;
    }
    if not JacCompiler._module_scoped_errors(target_program, mod_path) {
        return False;
    }
    gen = mod.gen;
    gen.py_bytecode = None;
    gen.llvm_ir = None;
    gen.native_engine = None;
    gen.native_bitcode = None;
    gen.native_layout = None;
    return True;
}

impl JacCompiler._prepare_tool_program(
    source_str: str, file_path: str
) -> tuple[JacProgram, (uni.Module | None)] {
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.parser { parse as rd_parse }
    prog = JacProgram();
    (current_mod, had_error) = rd_parse(source_str, file_path, prog=prog);
    if had_error {
        prog.mod = uni.ProgramModule(main_mod=current_mod);
        return (prog, None);
    }

    return (prog, current_mod);
}

impl JacCompiler.jac_file_formatter(
    file_path: str, auto_lint: bool = False
) -> JacProgram {
    source_str = read_file_with_encoding(file_path);
    (prog, current_mod) = JacCompiler._prepare_tool_program(source_str, file_path);
    if current_mod is None {
        return prog;
    }
    for pass_cls in get_format_sched(auto_lint=auto_lint) {
        current_mod = pass_cls(ir_in=current_mod, prog=prog).ir_out;
    }
    prog.mod = uni.ProgramModule(main_mod=current_mod);
    return prog;
}

impl JacCompiler.jac_str_formatter(
    source_str: str, file_path: str, auto_lint: bool = False
) -> JacProgram {
    (prog, current_mod) = JacCompiler._prepare_tool_program(source_str, file_path);
    if current_mod is None {
        return prog;
    }
    for pass_cls in get_format_sched(auto_lint=auto_lint) {
        current_mod = pass_cls(ir_in=current_mod, prog=prog).ir_out;
    }
    prog.mod = uni.ProgramModule(main_mod=current_mod);
    return prog;
}

impl JacCompiler.jac_file_linter(file_path: str) -> JacProgram {
    source_str = read_file_with_encoding(file_path);
    (prog, current_mod) = JacCompiler._prepare_tool_program(source_str, file_path);
    if current_mod is None {
        return prog;
    }
    for pass_cls in get_lint_sched() {
        current_mod = pass_cls(ir_in=current_mod, prog=prog).ir_out;
    }
    prog.mod = uni.ProgramModule(main_mod=current_mod);
    return prog;
}
