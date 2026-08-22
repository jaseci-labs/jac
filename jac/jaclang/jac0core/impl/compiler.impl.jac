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

impl JacCompiler._get_jaclang_root -> str {
    if (self._jaclang_root is None) {
        self._jaclang_root = os.path.realpath(
            os.path.dirname(os.path.dirname(__file__))
        );
    }
    return self._jaclang_root;
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
    _layout: any = None;
    if (full_target in actual_program._native_cache) {
        gen = actual_program._native_cache[full_target];
        _layout = gen?.native_layout;
    } elif (full_target in actual_program.mod.hub) {
        mod = actual_program.mod.hub[full_target];
        _layout = mod.gen?.native_layout;
    }
    if _layout is not None {
        JacCompiler._check_native_abi(_layout, full_target);
    }
    return _layout;
}

impl JacCompiler._check_native_abi(layout: any, full_target: str) -> None {
    import from jaclang.jac0core.codeinfo { NATIVE_ABI_VERSION }
    stamped = layout?.abi_version;
    if stamped is not None and stamped != NATIVE_ABI_VERSION {
        import logging as _abi_log;
        _abi_log.getLogger(__name__).warning(
            f"native ABI mismatch for {full_target}: layout abi_version="
            f"{stamped} but this compiler emits {NATIVE_ABI_VERSION}; recompile."
        );
    }
}

impl JacCompiler.get_bytecode(
    full_target: str, target_program: JacProgram
) -> (types.CodeType | None) {
    actual_program = self._resolve_program(full_target, target_program);
    (rebuild, no_precompile) = cache_mode();
    symtab_only_recovery = False;

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
        and not actual_program.mod.hub[full_target].gen.py_bytecode
    ) {
        actual_program.invalidate_module(full_target);
        symtab_only_recovery = True;
    } elif (
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
                if (
                    _had_native_secs
                    and full_target not in actual_program._native_cache
                    and actual_program is not self._internal_program
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
            } else {
                cache_path.unlink(missing_ok=True);
                actual_program.invalidate_module(full_target);
                symtab_only_recovery = True;
            }
        } except Exception {
            ;
        }
    }

    allow_unsealed = (not rebuild) and (not no_precompile);
    precompiled_bc = self._get_precompiled_jir_bytecode(full_target, allow_unsealed);
    if precompiled_bc is not None {
        try {
            import from jaclang.jac0core.jir {
                write_precompiled_jir,
                module_jir_key_sections,
                FLAG_PRECOMPILED
            }
            jir_bytes = write_precompiled_jir(
                precompiled_bc,
                flags=FLAG_PRECOMPILED,
                extra_sections=module_jir_key_sections(full_target)
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
        self._internal_bytecode_depth += 1;
    }
    options = CompileOptions(type_check=False);
    result: (uni.Module | None) = None;
    try {
        result = self.compile(
            file_path=full_target, target_program=actual_program, options=options
        );
        if result.gen.py_bytecode {
            actual_program.hub_cache_stamp(full_target);
            try {
                import pickle;
                import json;
                import zlib;
                sections: dict[int, bytes] = {};
                sections[SEC_BYTECODE] = result.gen.py_bytecode;
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
                try {
                    import from jaclang.jac0core.placement {
                        get_module_summary,
                        summary_to_bytes
                    }
                    sections[SEC_PLACEMENT] = summary_to_bytes(
                        get_module_summary(result, actual_program)
                    );
                } except Exception {
                    ;
                }
                import from jaclang.jac0core.jir { write_module_cache }
                cache_bc: any = result.gen?.py_bytecode;
                if cache_bc is not None and not result.parse_failed {
                    write_module_cache(full_target, cache_bc, extra_sections=sections);
                }
            } except Exception {
                ;
            }
            if is_internal {
                note_compiler_source_failure(full_target, '');
            }
            return marshal.loads(result.gen.py_bytecode);
        }
        if is_internal {
            note_compiler_source_failure(
                full_target, module_scoped_failure_details(full_target, actual_program)
            );
        }
        return None;
    } finally {
        if is_internal {
            if self._internal_bytecode_depth == 1 {
                self._evict_internal_unit(full_target, actual_program, result);
            }
            self._internal_bytecode_depth -= 1;
        }
    }
}

impl JacCompiler._evict_internal_unit(
    full_target: str, actual_program: JacProgram, result: (uni.Module | None)
) -> None {
    import os;
    if os.environ.get("JAC_NO_UNIT_EVICT") {
        return;
    }

    if result is not None and result.gen.native_engine is not None {
        import from jaclang.jac0core.codeinfo { CodeGenTarget }
        slim = CodeGenTarget();
        slim.native_engine = result.gen.native_engine;
        slim.native_layout = result.gen.native_layout;
        slim.interop_py_funcs = result.gen.interop_py_funcs;
        slim._interop_callbacks = result.gen._interop_callbacks;
        slim.interop_manifest = result.gen.interop_manifest;
        actual_program._native_cache[full_target] = slim;
    }

    actual_program.release_compile_closure(keep_stubs=True);
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
        import from jaclang.jac0core.codeinfo {
            CodeGenTarget,
            install_native_static_init
        }
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
        install_native_static_init(engine, gen.interop_manifest);
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
    import from jaclang.jac0core.codeinfo { CodeGenTarget, install_native_static_init }
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
    install_native_static_init(engine, gen.interop_manifest);
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

    placement_bytes = secs.get(SEC_PLACEMENT);
    if placement_bytes is not None {
        try {
            import from jaclang.jac0core.placement { summary_from_bytes, summary_store }
            restored = summary_from_bytes(placement_bytes);
            if restored is not None {
                summary_store(actual_program)[os.path.abspath(full_target)] = restored;
            }
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
    import from jaclang.jac0core.jir { PRECOMPILE_SENTINEL, cache_mode }
    import from jaclang.jac0core { sealed as _sealed }
    (rebuild_flag, no_precompile) = cache_mode();
    if rebuild_flag or no_precompile {
        return None;
    }
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
                        or precompiled_jir_matches_source(jir_data, norm_file)
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
            'source_module': binding.source_module,
            'kind': binding.kind
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
            source_module=data.get('source_module'),
            kind=data.get('kind', 'function')
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
    cancel_token: (Event | None) = None,
    prefix_kind: str = ''
) -> uni.Module {
    had_error = False;
    run_codespace_infer = False;
    if (file_path.endswith('.py') or file_path.endswith('.pyi')) {
        import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
        parsed_ast = py_ast.parse(source_str);
        py_ast_ret = run_pass(
            PyastBuildPass,
            uni.PythonModuleAst(
                parsed_ast, orig_src=uni.Source(source_str, mod_path=file_path)
            ),
            target_program,
            cancel_token=cancel_token
        );
        had_error = len(py_ast_ret.errors_had) > 0;
        mod = py_ast_ret.ir_out;
    } elif (
        file_path.endswith('.c') or file_path.endswith('.h') or file_path.endswith('.i')
    ) {
        import from jaclang.compiler.passes.main.cast_load_pass { CastBuildPass }
        import from jaclang.vendor.pycparser { c_parser }
        c_src = source_str;
        if not file_path.endswith('.i') {
            import from jaclang.compiler.cfront.preprocess { preprocess_c }
            c_src = preprocess_c(c_src, file_path);
        }
        file_ast = c_parser.CParser().parse(c_src, file_path);
        cast_ret = CastBuildPass(
            ir_in=uni.CModuleAst(
                file_ast, orig_src=uni.Source(c_src, mod_path=file_path)
            ),
            prog=target_program,
            cancel_token=cancel_token,
            lenient_c=True
        );
        had_error = len(cast_ret.errors_had) > 0;
        mod = cast_ret.ir_out;
    } else {
        import from jaclang.jac0core.ext_registry {
            is_retired_client_marker,
            is_retired_native_marker
        }
        if is_retired_native_marker(file_path) {
            raise ValueError(
                f"{file_path}: the .na.jac marker was retired in 0.35 -- rename "
                "the file to .jac; native placement is inferred (or forced by "
                "'jac nacompile' / 'jac build --as native'). See 'jac guide "
                "reference/language/native-pathway'."
            );
        }
        if is_retired_client_marker(file_path) {
            raise ValueError(
                f"{file_path}: the .cl.jac marker was retired -- rename the "
                "file to .jac; client placement is inferred from JSX/npm "
                "imports (override via [placement.pins] in jac.toml). Run "
                "'jac fix placement' to migrate the project."
            );
        }
        import from jaclang.jac0core.prefix_flip { parse_with_prefix }
        _p_opts_pre = target_program._compile_options;
        codespace = '';
        import from jaclang.jac0core.codeinfo {
            is_client_by_location as _cbl,
            is_native_by_location as _nbl
        }
        if _nbl(file_path) {
            codespace = 'native';
        }
        if not codespace and _cbl(file_path) {
            codespace = 'client';
        }
        if not codespace {
            import from jaclang.jac0core.placement_pins {
                effective_module_pin as _mod_pin
            }
            _pinned_space = _mod_pin(file_path);
            if _pinned_space in ('client', 'native') {
                codespace = _pinned_space;
            }
        }
        if not codespace {
            _p_opts = target_program._compile_options;
            _forced_pre = _p_opts.force_codespace if _p_opts is not None else '';
            if (
                not _forced_pre
                and _p_opts is not None
                and _p_opts.aot_mode
                and target_program is not self._internal_program
                and _default_codespace_for(target_program) == 'native'
            ) {
                _forced_pre = 'native';
            }
            if _forced_pre and target_program is not self._internal_program {
                codespace = _forced_pre;
            }
        }
        if not codespace and target_program is not self._internal_program {
            import from jaclang.jac0core.placement_pins {
                config_kind_space as _kind_space_of
            }
            _kind_space = _kind_space_of(file_path);
            if _kind_space in ('client', 'native') {
                codespace = _kind_space;
            }
        }
        (mod, had_error) = parse_with_prefix(
            source_str,
            file_path,
            target_program,
            kind=prefix_kind,
            no_cgen=bool(_p_opts_pre.no_cgen) if _p_opts_pre is not None else False,
            codespace=codespace
        );
        if (codespace == 'client') {
            _coerce_client_module(mod);
        } elif (codespace == 'native') {
            _coerce_native_module(mod);
            na_coverage_record(mod.loc.mod_path, 'native');
        } else {
            run_codespace_infer = True;
        }
        if not had_error
        and any(
            [
                imp.clib_header is not None
                for imp in mod.get_all_sub_nodes(typ=uni.Import)
            ]
        ) {
            import from jaclang.compiler.cfront.clib_bind { synthesize_clib_bindings }
            synthesize_clib_bindings(mod, file_path);
        }
    }
    hub_key = target_program.hub_key(mod.loc.mod_path);
    if had_error {
        mod.parse_failed = True;
        target_program.mod.hub[hub_key] = mod;
        target_program.hub_cache_stamp(hub_key);
        return mod;
    }
    if target_program.mod.main.stub_only {
        old_hub = target_program.mod.hub;
        target_program.mod = uni.ProgramModule(main_mod=mod);

        target_program.mod.hub.clear();
        target_program.mod.hub.update(old_hub);
    }
    target_program.mod.hub[hub_key] = mod;

    mod.annex_mods = self.load_annex_modules(mod, target_program);
    run_pass(JacAnnexPass, mod, target_program);
    if run_codespace_infer {
        _opts = target_program._compile_options;
        _analysis_only = _opts is not None and _opts.no_cgen;
        _native_eligible = (
            not _analysis_only
            and target_program is not self._internal_program
            and _default_codespace_for(target_program) == 'native'
        );
        if _native_eligible {
            import from jaclang.jac0core.placement_solver { native_default_verdict }
            (_na_ok, _na_why) = native_default_verdict(mod);
            if _na_ok {
                _coerce_native_module(mod);
                na_coverage_record(mod.loc.mod_path, 'native');
            } else {
                na_coverage_record(mod.loc.mod_path, 'server', '', _na_why);
            }
        }
    }
    return mod;
}

impl JacCompiler.load_annex_modules(
    mod: uni.Module, target_program: JacProgram
) -> list[uni.Module] {
    import from jaclang.jac0core.bccache { discover_annex_files }
    import from jaclang.jac0core.parser { parse as rd_parse }
    mod_path = mod.loc.mod_path;
    if (mod.stub_only or not mod_path.endswith('.jac') or mod.annexable_by) {
        return [];
    }
    annexes: list[uni.Module] = [];
    seen: set[str] = set();
    for path in [
        *discover_annex_files(mod_path, '.impl.jac'),
        *discover_annex_files(mod_path, '.test.jac')
    ] {
        if path in seen {
            continue;
        }
        seen.add(path);
        source_str = read_file_with_encoding(path);
        (annex_mod, _had_error) = rd_parse(source_str, path, prog=target_program);
        annexes.append(annex_mod);
    }
    return annexes;
}

impl JacCompiler.resolve_absorb_imports(
    mod: uni.Module, target_program: JacProgram
) -> None {
    import from jaclang.jac0core.unitree { find_python_scope_node_of }
    for imp in mod.get_all_sub_nodes(uni.Import) {
        if imp.from_loc is not None {
            for item in imp.items {
                if (
                    isinstance(item, uni.ModulePath) and item.path and not item.alias
                ) {
                    imp.jac_detected = imp.is_jac;
                    break;
                }
            }
        }
        if not imp.is_absorb {
            continue;
        }
        if (find_python_scope_node_of(imp) is None) {
            continue;
        }
        path_node = imp.items[0];
        if not isinstance(path_node, uni.ModulePath) {
            continue;
        }
        resolved = path_node.resolve_relative_path();
        module: (uni.Module | None) = None;
        if (resolved in target_program.mod.hub) {
            module = target_program.mod.hub[resolved];
        } else {
            try {
                module = target_program.compile(
                    resolved, no_cgen=True, type_check=False
                );
            } except Exception {
                module = None;
            }
        }
        imp.absorbed_mod = module;
    }
}

impl JacCompiler.stamp_access_check_facts(mod: uni.Module) -> None {
    import from jaclang.jac0core.modresolver { find_jac_project_root }
    mod.jac_project_root = find_jac_project_root(mod.loc.mod_path) if mod.loc else None;
    enforce = False;
    try {
        import from jaclang.project.config { get_config }
        config = get_config();
        if (config and config.check) {
            enforce = config.check.enforce_access;
        }
    } except Exception {
        enforce = False;
    }
    mod.access_enforced = enforce;
}

impl JacCompiler.stamp_native_import_facts(
    mod: uni.Module, target_program: JacProgram
) -> None {
    """Stamp each import with the emitter's native-only verdict.

    Whether an import resolves to a module the native lane owns, and
    whether that module lives inside jaclang's own tree, are both
    import-resolution questions: they need the hub, the placement pins
    and the filesystem, which is the driver's ground and not a pass's.
    The emitter used to ask for them through `self.prog`, the one
    driver read left in a sealed pass. It now consumes a bool.
    """;
    import os;
    for imp in mod.get_all_sub_nodes(uni.Import) {
        target = native_only_import_target(imp, target_program);
        imp.native_only_drop = target is not None
            and (os.sep + 'jaclang' + os.sep) not in os.path.abspath(target);
    }
}

impl JacCompiler.stamp_client_kind_facts(
    mod: uni.Module, target_program: JacProgram
) -> None {
    import from jaclang.project.client_kind { resolve_client_kind_context }
    opts = target_program._compile_options;
    mod_path = mod.loc.mod_path if mod.loc else '';
    (kind, proj_root) = resolve_client_kind_context(
        mod_path, opts.project_kind, opts.project_root
    );
    mod.mobui_enforced_root = proj_root if kind == 'mobui' else None;
}

impl JacCompiler.stamp_boundary_facts(
    mod: uni.Module, target_program: JacProgram
) -> None {
    import from jaclang.jac0core.codeinfo {
        is_bundled_native_module,
        resolve_native_module
    }
    import from jaclang.jac0core.placement_pins { config_module_pin }

    base_dir = '.';
    if mod.loc {
        base_dir = os.path.dirname(mod.loc.mod_path);
    }
    _sb_opts = target_program._compile_options;
    in_native_mod = mod.loc is not None
        and (
            mod.decided_codespace == 'native'
            or (
                _sb_opts is not None
                and _sb_opts.aot_mode
                and target_program is not self._internal_program
                and _default_codespace_for(target_program) == 'native'
            )
        );

    def resolve_native(module_name: str, inferred_ok: bool) -> (str | None) {
        (src_mod_str, _full_path) = resolve_native_module(
            module_name, base_dir, allow_inferred=inferred_ok
        );
        return src_mod_str;
    }

    def parse_only_module(file_path: str) -> (uni.Module | None) {
        memo = target_program._boundary_parse_memo;
        try {
            key = JacProgram.hub_key(file_path);
            stamp = os.path.getmtime(file_path);
        } except OSError {
            return None;
        }
        cached = memo.get(key);
        if cached is not None and cached[0] == stamp {
            return cached[1];
        }
        try {
            src_text = read_file_with_encoding(file_path);
            parsed = JacCompiler().parse_str(
                source_str=src_text, file_path=file_path, target_program=JacProgram()
            );
        } except Exception {
            return None;
        }
        memo[key] = (stamp, parsed);
        return parsed;
    }

    def source_mod_for(resolved_path: (str | None)) -> (uni.Module | None) {
        if resolved_path is None {
            return None;
        }
        found = target_program.find_module(resolved_path);
        if (found is None and os.path.isfile(resolved_path)) {
            found = parse_only_module(resolved_path);
        }
        return found;
    }

    def collect_abilities(nd: uni.UniNode, out: dict[(str, uni.Ability)]) {
        if isinstance(nd, uni.Ability) and nd.sym_name {
            out[nd.sym_name] = nd;
        }
        for k in nd.kid {
            collect_abilities(k, out);
        }
    }

    def collect_pub_walkers(nd: uni.UniNode, out: dict[(str, uni.Archetype)]) {
        if isinstance(nd, uni.Archetype) and nd.sym_name {
            if nd.arch_kind == 'walker' and bool(nd.public_access) {
                out[nd.sym_name] = nd;
            }
        }
        for k in nd.kid {
            collect_pub_walkers(k, out);
        }
    }

    def imported_names(imp: uni.Import) -> set[str] {
        names: set[str] = set();
        for item in imp.items {
            if isinstance(item, uni.ModuleItem) {
                names.add(item.name.value);
            }
        }
        return names;
    }

    def stamp_sv_decls(imp: uni.Import, facts: uni.ImportBoundaryFacts) -> None {
        wanted = imported_names(imp);
        if not wanted {
            return;
        }
        src = source_mod_for(facts.from_loc_resolved);
        if src is None {
            return;
        }
        abilities: dict[(str, uni.Ability)] = {};
        walkers: dict[(str, uni.Archetype)] = {};
        try {
            collect_abilities(src, abilities);
        } except Exception { }
        try {
            collect_pub_walkers(src, walkers);
        } except Exception { }
        for name in wanted {
            wk_decl = walkers.get(name);
            if wk_decl is not None {
                facts.sv_walkers[name] = wk_decl;
                continue;
            }
            ab_decl = abilities.get(name);
            if ab_decl is not None {
                facts.sv_abilities[name] = ab_decl;
            }
        }
    }

    def stamp_na_decls(imp: uni.Import, facts: uni.ImportBoundaryFacts) -> None {
        wanted = imported_names(imp);
        if not wanted {
            return;
        }
        src = source_mod_for(facts.from_loc_resolved);
        if src is None {
            return;
        }
        for decl in src.body {
            if not isinstance(decl, (uni.Ability, uni.Archetype, uni.Enum)) {
                continue;
            }
            name = decl.sym_name;
            if (
                not name
                or name not in wanted
                or name in facts.na_target_decls
                or name in facts.na_unmappable_targets
            ) {
                continue;
            }
            if isinstance(decl, uni.Ability)
                and isinstance(decl.signature, uni.FuncSignature) {
                facts.na_target_decls[name] = decl;
            } else {
                facts.na_unmappable_targets.append(name);
            }
        }
    }

    for nd in mod.get_all_sub_nodes(uni.Import) {
        facts = uni.ImportBoundaryFacts();
        nd.boundary_facts = facts;
        native_ctx = nd.codespace() == CodeContext.NATIVE;

        if (nd.from_loc and isinstance(nd.from_loc, uni.ModulePath)) {
            module_name = nd.from_loc.dot_path_str;
            if (not module_name and nd.from_loc.path) {
                module_name = '.'.join(p.value for p in nd.from_loc.path);
            }
            if module_name {
                cl_na_edge = is_client_native_edge_import(nd, target_program);
                facts.client_native_edge = cl_na_edge;
                na_intent = (
                    native_ctx
                    or in_native_mod
                    or import_declares_native_target(nd)
                    or cl_na_edge
                );
                facts.native_from_path = resolve_native(module_name, na_intent);
                try {
                    facts.from_loc_resolved = nd.from_loc.resolve_relative_path();
                } except Exception {
                    facts.from_loc_resolved = None;
                }
                facts.is_service = nd.is_service_import;
                if (nd.items and not facts.is_service and nd.in_client_context()) {
                    resolved = facts.from_loc_resolved;
                    if (resolved is not None and resolved.endswith('.jac')) {
                        try {
                            facts.pinned_server = (
                                config_module_pin(resolved) == 'server'
                            );
                        } except Exception {
                            facts.pinned_server = False;
                        }
                    }
                }
                if (
                    (facts.is_service and not facts.native_from_path)
                    or (nd.items and not facts.is_service and facts.pinned_server)
                ) {
                    stamp_sv_decls(nd, facts);
                }
                if (cl_na_edge and nd.items) {
                    stamp_na_decls(nd, facts);
                }
                if (
                    nd.items
                    and not facts.is_service
                    and not facts.pinned_server
                    and not cl_na_edge
                    and is_client_boundary_import(nd)
                ) {
                    linked_mod = symbol_linked_source_module(nd);
                    if linked_mod is not None {
                        for item in nd.items {
                            if not isinstance(item, uni.ModuleItem) {
                                continue;
                            }
                            verdict = classify_client_import_item(linked_mod, item);
                            if verdict != ClientImportVerdict.BRIDGED {
                                continue;
                            }
                            sym_name = item.name.value;
                            decl = ability_of_symbol(linked_mod.lookup(sym_name));
                            if decl is not None {
                                facts.bridged_decls[sym_name] = decl;
                            }
                        }
                    }
                }
            }
        }

        if ((not nd.from_loc) and nd.is_absorb and nd.items and (not nd.clib_decls)) {
            item = nd.items[0];
            if (isinstance(item, uni.ModulePath) and item.path) {
                module_name = '.'.join(p.value for p in item.path);
                if module_name {
                    na_intent = (
                        native_ctx or in_native_mod or import_declares_native_target(nd)
                    );
                    facts.native_absorb_path = resolve_native(module_name, na_intent);
                }
            }
            continue;
        }

        if ((not nd.from_loc) and nd.items and (not nd.clib_decls)) {
            for item in nd.items {
                if (isinstance(item, uni.ModulePath) and item.path) {
                    whole_name = '.'.join(p.value for p in item.path);
                    eligible = is_bundled_native_module(whole_name)
                        or (item.alias is None and len(item.path) == 1);
                    if (whole_name and eligible) {
                        na_intent = (
                            native_ctx
                            or in_native_mod
                            or import_declares_native_target(nd)
                        );
                        item_path = resolve_native(whole_name, na_intent);
                        if item_path {
                            facts.native_item_paths[whole_name] = item_path;
                        }
                    }
                }
            }
        }
    }
}

impl JacCompiler.compile(
    file_path: str,
    target_program: JacProgram,
    use_str: (str | None) = None,
    options: CompileOptions = CompileOptions()
) -> uni.Module {
    import from pathlib { Path as _WrapPath }
    import from jaclang.jac0core.codeinfo {
        get_effective_default_codespace_override,
        set_effective_default_codespace
    }
    _prev_cs = get_effective_default_codespace_override();
    _depth_prev = getattr(self, '_reentrant_depth', 0);
    self._reentrant_depth = _depth_prev + 1;
    _outer_opts: (CompileOptions | None) = None;
    _outer_prog: (JacProgram | None) = None;
    _scratch_prog: (JacProgram | None) = None;
    try {
        if options.force_target_program {
            _wrap_prog = target_program;
        } else {
            _wrap_prog = self._resolve_program(file_path, target_program);
        }

        _scratch_prog = _wrap_prog;
        _wrap_prog._compile_depth += 1;
        if _depth_prev > 0 {
            _outer_prog = _wrap_prog;
            _outer_opts = _wrap_prog._compile_options;
        }
        _pre_errs = len(_wrap_prog.errors_had);
        _pre_warns = len(_wrap_prog.warnings_had);
        _mod: (uni.Module | None) = None;
        _crash: (Exception | None) = None;
        try {
            _mod = self._compile_once(
                file_path=file_path,
                target_program=target_program,
                use_str=use_str,
                options=options
            );
        } except Exception as _e {
            _crash = _e;
        }
        if _crash is not None {
            _re_entered = import_error_re_enters(_crash, file_path);
            if _re_entered is not None {
                raise CompilerSourceError(
                    f"compiling {file_path} re-entered it: a pass imported "
                    f"'{_re_entered}' while Python was still executing that "
                    "module, so the name is not bound yet. A pass's run-time "
                    "imports must be pre-imported while the schedule loads "
                    "(see get_ir_gen_sched / get_symtab_ir_sched), never "
                    "reached for the first time during a compile."
                ) from _crash;
            }
        }
        _resolved = os.path.realpath(file_path);
        _probe = _mod if _mod is not None else _wrap_prog.mod.hub.get(_resolved);
        _inferred_native = (
            not options.aot_mode
            and not options.force_codespace
            and _probe is not None
            and _probe.decided_codespace == 'native'
        );
        _failed = _crash is not None or len(_wrap_prog.errors_had) > _pre_errs;
        if not (_inferred_native and _failed) {
            if _crash is not None {
                raise _crash;
            }
            return _mod;
        }

        _is_ice = _crash is not None and len(_wrap_prog.errors_had) == _pre_errs;
        if _is_ice and os.environ.get('JAC_NATIVE_ICE_RAISE') {
            raise _crash;
        }
        _first_err = (
            _wrap_prog.errors_had[_pre_errs].pretty_print().split('\n')[0]
                if len(_wrap_prog.errors_had) > _pre_errs
                else f"{type(_crash).__name__}: {_crash}"
        );
        _demote_alerts = _wrap_prog.errors_had[_pre_errs:];
        _demote_code = (
            _demote_alerts[0].code.code
                if (_demote_alerts and _demote_alerts[0].code is not None)
                else type(_crash).__name__
        );
        na_coverage_record(
            _resolved, 'ice' if _is_ice else 'demoted', _demote_code, _first_err
        );
        import from jaclang.jac0core.placement_pins { _mark_demoted_native }
        _mark_demoted_native(_resolved);
        _wrap_prog.errors_had = _wrap_prog.errors_had[:_pre_errs];
        _wrap_prog.warnings_had = _wrap_prog.warnings_had[:_pre_warns];
        try {
            _wrap_prog.invalidate_module(_resolved);
        } except Exception {
            ;
        }
        try {
            import from jaclang.jac0core.placement_solver { invalidate_importers_es }
            for _stale_mod in invalidate_importers_es(_wrap_prog, _resolved) {
                _drop_demoted_native_bindings(_stale_mod, _resolved);
            }
        } except Exception as _reset_exc {
            import logging as _reset_log;
            _reset_log.getLogger(__name__).warning(
                f"native demotion of {_resolved} could not reset its importers "
                f"({_reset_exc}); stale client bindings may persist until a rebuild."
            );
        }
        try {
            import from jaclang.cli.console { console as _note_console }
            (_note_msg, _note_style) = na_demotion_note(file_path, _first_err, _is_ice);
            _note_console.print(_note_msg, style=_note_style, file=sys.stderr);
        } except Exception {
            ;
        }
        return self._compile_once(
            file_path=file_path,
            target_program=target_program,
            use_str=use_str,
            options=options
        );
    } finally {
        set_effective_default_codespace(_prev_cs);
        self._reentrant_depth = _depth_prev;
        if _outer_prog is not None and _outer_opts is not None {
            _outer_prog._compile_options = _outer_opts;
        }
        if _depth_prev == 0 {
            import from jaclang.jac0core.prefix_flip { emit_prefix_summary }
            emit_prefix_summary();
        }
        if _scratch_prog is not None {
            _scratch_prog._compile_depth -= 1;
            if _scratch_prog._compile_depth <= 0 {
                _scratch_prog._compile_depth = 0;
                self._release_compile_scratch(_scratch_prog);
            }
        }
    }
}

impl JacCompiler._release_compile_scratch(target_program: JacProgram) -> None {
    try {
        target_program.release_native_dep_units();
        target_program.release_check_caches();
    } except Exception { }
}

impl JacCompiler._compile_once(
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

    _prev_opts = actual_program._compile_options;
    if _prev_opts is not None
        and not (
            options.nogc_enforce_all
            or options.nogc_cli_target
            or options.nogc_enforce_modules
        ) {
        options.nogc_enforce_all = _prev_opts.nogc_enforce_all;
        options.nogc_cli_target = _prev_opts.nogc_cli_target;
        options.nogc_enforce_modules = _prev_opts.nogc_enforce_modules;
        options.nogc_grandfathered = _prev_opts.nogc_grandfathered;
    }
    if _prev_opts is not None and not options.default_codespace {
        options.default_codespace = _prev_opts.default_codespace;
    }
    actual_program._compile_options = options;
    if options.default_codespace {
        import from jaclang.jac0core.codeinfo { set_effective_default_codespace }
        set_effective_default_codespace(options.default_codespace);
    }
    keep_str = use_str or read_file_with_encoding(file_path);
    had_parse_errors = len(actual_program.errors_had);
    import from jaclang.jac0core.prefix_flip {
        drop_executed_prefix,
        mark_prefix_provided,
        prefix_span_blocking,
        prefix_span_errors,
        take_prefix_handoff
    }
    mod_targ = self.parse_str(
        keep_str,
        file_path,
        actual_program,
        cancel_token=options.cancel_token,
        prefix_kind=('symtab-ir' if options.symtab_ir_only else 'ir-gen')
    );
    _prefix_span = take_prefix_handoff(mod_targ);
    _prefix_ran = _prefix_span[0];
    had_parse_errors = (
        len(actual_program.errors_had) - prefix_span_errors(_prefix_span)
    )
        > had_parse_errors;

    cur_mod_path = os.path.normpath(file_path);
    blocking_errs_pre_ir = self._count_module_blocking_errors(
        actual_program, cur_mod_path
    )
        - prefix_span_blocking(actual_program, _prefix_span, cur_mod_path);
    if options.symtab_ir_only {
        _head_sched = get_symtab_ir_sched();
    } else {
        _head_sched = get_ir_gen_sched(
            is_internal=(actual_program is self._internal_program),
            gen_mtir=not options.no_cgen
        );
    }
    if _prefix_ran {
        mark_prefix_provided(actual_program, mod_targ, _head_sched[:len(_prefix_ran)]);
    }
    self.run_schedule(
        mod=mod_targ,
        target_program=actual_program,
        passes=drop_executed_prefix(_head_sched, _prefix_ran),
        cancel_token=options.cancel_token
    );

    blocking_errs_post_ir = self._count_module_blocking_errors(
        actual_program, cur_mod_path
    );
    had_blocking_errors = blocking_errs_post_ir > blocking_errs_pre_ir;

    if not options.symtab_ir_only and not had_blocking_errors {
        import from jaclang.jac0core.placement_solver { solve_program_placement }
        try {
            solve_program_placement(mod_targ, actual_program);
        } except Exception {
            ;
        }
    }

    import from jaclang.jac0core.constant { CodeContext as _CodeCtx }
    is_explicit_native = mod_targ is not None
        and mod_targ.declares_codespace(_CodeCtx.NATIVE, path_hint=file_path);
    is_client_mod = mod_targ is not None
        and mod_targ.declares_codespace(_CodeCtx.CLIENT, path_hint=file_path);
    is_native_mod = is_explicit_native;

    run_inference = options.type_check
        or is_native_mod
        or (is_client_mod and not options.no_cgen and not options.symtab_ir_only);
    if run_inference {
        if options.symtab_ir_only {
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_cfg_sched(),
                cancel_token=options.cancel_token
            );
        }

        self.run_schedule(
            mod=mod_targ,
            target_program=actual_program,
            passes=get_inference_sched(),
            cancel_token=options.cancel_token
        );
        actual_program._inferred_mods.add(id(mod_targ));

        import from dataclasses { replace as _replace_opts }
        for dep_mod in list(actual_program.mod.hub.values()) {
            if (dep_mod is mod_targ)
                or (id(dep_mod) in actual_program._inferred_mods)
                or dep_mod.parse_failed {
                continue;
            }
            if dep_mod.decided_codespace == 'native' {
                _saved_opts = actual_program._compile_options;
                actual_program._compile_options = _replace_opts(
                    options, emit_diagnostics=False
                );
                try {
                    self.run_schedule(
                        mod=dep_mod,
                        target_program=actual_program,
                        passes=get_inference_sched(),
                        cancel_token=options.cancel_token
                    );
                    actual_program._inferred_mods.add(id(dep_mod));
                } finally {
                    actual_program._compile_options = _saved_opts;
                }
            }
        }
    }

    if options.type_check or is_native_mod {
        self.run_schedule(
            mod=mod_targ,
            target_program=actual_program,
            passes=get_type_check_sched(
                provided=actual_program._analyses_run.get(id(mod_targ), set())
            ),
            cancel_token=options.cancel_token
        );
    }

    if is_native_mod
        and not had_blocking_errors
        and self._count_module_errors(actual_program, cur_mod_path) > 0 {
        had_blocking_errors = True;
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
        _parity_passes: list[type[Transform]] = [];
        if run_inference {
            try {
                import from jaclang.compiler.passes.native { NaIRGenPass }
                import from jaclang.compiler.passes.main.rc_facts_pass { RcFactsPass }
                _parity_passes = resolve_schedule(
                    [NaIRGenPass],
                    providers=providers_for([RcFactsPass]),
                    preprovided=actual_program._analyses_run.get(id(mod_targ), set()),
                    drop_unsatisfiable=True,
                    origin='native check-parity schedule'
                );
            } except ImportError as e {
                fail_loud_on_compiler_source(e);
                _parity_passes = [];
            }
        }
        if _parity_passes {
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=_parity_passes,
                cancel_token=options.cancel_token
            );
        }
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

                if cb_imp.is_virtual_jac {
                    continue;
                }
                try {
                    cb_src = cb_imp.from_loc.resolve_relative_path();
                } except Exception {
                    continue;
                }
                cb_is_client_dep = isinstance(cb_src, str)
                    and cb_imp.code_context == CodeContext.CLIENT
                    and cb_src.endswith('.jac');
                if not cb_is_client_dep {
                    continue;
                }
                cb_src = _cb_os.path.abspath(cb_src);
                if cb_src in cb_seen {
                    continue;
                }
                cb_seen.add(cb_src);

                cb_mod = actual_program.find_module(cb_src);
                cb_has_facts = (
                    cb_mod is not None
                    and cb_mod.gen
                    and cb_mod.gen.interop_manifest
                    and bool(cb_mod.gen.interop_manifest.bindings)
                );

                cb_known_bad = actual_program.has_failed_parse(cb_src);
                if not cb_has_facts and not cb_known_bad {
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
            passes=get_py_code_gen(
                native=needs_native,
                provided=actual_program._analyses_run.get(id(mod_targ), set())
            ),
            cancel_token=options.cancel_token
        );
        if mod_targ.decided_codespace == 'native' {
            _scrubbed = JacCompiler._scrub_native_artifacts_on_error(
                actual_program, mod_targ
            );
            if options.aot_mode and not _scrubbed {
                JacCompiler._report_missing_native_ir(actual_program, mod_targ);
            }
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
    run_pass(SemanticAnalysisPass, mod_targ, actual_program);
    return mod_targ;
}

impl JacCompiler.run_schedule(
    mod: uni.Module,
    target_program: JacProgram,
    passes: list[type[Transform]],
    cancel_token: (Event | None) = None
) -> None {
    provided = target_program._analyses_run.get(id(mod));
    if provided is None {
        provided = set();
        target_program._analyses_run[id(mod)] = provided;
    }
    validate_schedule(
        passes,
        preprovided=provided,
        origin=(f"schedule for module {mod.loc.mod_path if mod.loc else mod.name}")
    );
    _policy = build_diagnostic_policy(target_program);
    self.stamp_access_check_facts(mod);
    jsx_guard_pass = _jsx_intrinsic_guard_pass_type();
    for current_pass in passes {
        if (cancel_token and cancel_token.is_set()) {
            break;
        }
        if current_pass is SymTabBuildPass {
            self.resolve_absorb_imports(mod, target_program);
        }
        if current_pass is BoundaryAnalysisPass {
            self.stamp_boundary_facts(mod, target_program);
        }
        if current_pass is JcirGenPass {
            self.stamp_native_import_facts(mod, target_program);
        }
        if jsx_guard_pass is not None and current_pass is jsx_guard_pass {
            self.stamp_client_kind_facts(mod, target_program);
        }
        run_pass(
            current_pass, mod, target_program, cancel_token=cancel_token, policy=_policy
        );
        for _prov in (getattr(current_pass, 'PROVIDES', ()) or ()) {
            provided.add(_prov);
        }
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

impl JacCompiler._count_module_errors(
    target_program: JacProgram, mod_path: str
) -> int {
    count = 0;
    for e in target_program.errors_had {
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

impl JacCompiler._report_missing_native_ir(
    target_program: JacProgram, mod: uni.Module
) -> None {
    if mod?.gen is None or mod.gen.llvm_ir is not None {
        return;
    }
    mod_path = mod.loc.mod_path if mod?.loc else '';
    if not mod_path or JacCompiler._count_module_errors(target_program, mod_path) > 0 {
        return;
    }
    import from jaclang.jac0core.diagnostics { E5092 }
    import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }
    import from jaclang.jac0core.passes.transform { Alert }
    reason = native_schedule_failure();
    if not reason {
        (_avail, _why) = native_pipeline_available();
        if not _avail {
            reason = _why;
        }
    }
    if reason {
        detail = f"the native codegen schedule could not be built ({reason})";
    } elif not ModuleCodegenPass.has_native_context_stmts(mod) {
        detail = "the module declares no native code for the backend to lower";
    } else {
        detail = (
            "the native codegen passes ran but emitted neither IR nor a "
            "diagnostic; this is a compiler bug -- please report it"
        );
    }
    from_pass: any = JcirGenPass;
    try {
        import from jaclang.compiler.passes.native { NaIRGenPass }
        from_pass = NaIRGenPass;
    } except Exception {
        ;
    }
    deliver_alerts(
        [
            Alert(
                msg=E5092.format_message(
                    kind='module', name=os.path.basename(mod_path)
                ),
                loc=mod.loc.snapshot(),
                from_pass=from_pass,
                code=E5092,
                help_text=detail
            )
        ],
        [],
        target_program
    );
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
        current_mod = run_pass(pass_cls, current_mod, prog).ir_out;
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
        current_mod = run_pass(pass_cls, current_mod, prog).ir_out;
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
        current_mod = run_pass(pass_cls, current_mod, prog).ir_out;
    }
    prog.mod = uni.ProgramModule(main_mod=current_mod);
    return prog;
}
