"""Implementation for compiler.jac obj methods."""

impl _SetupProgress.postinit -> None {
    self._seen_files = `set();
}

impl _SetupProgress._get_jaclang_root -> str {
    if (self._jaclang_root is None) {
        self._jaclang_root = os.path.dirname(os.path.dirname(__file__));
    }
    return self._jaclang_root;
}

"""Print the completion summary when the process exits."""
impl _SetupProgress._atexit_handler -> None {
    if (self._banner_shown and (self._compile_count > 0)) {
        sys.stderr.write(
            f"Jac setup complete! ({self._compile_count} modules compiled and cached)\n"
        );
        sys.stderr.flush();
    }
}

"""Called when an internal jaclang module needs compilation (cache miss)."""
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

"""Whether we're currently in a first-run setup."""
impl _SetupProgress.is_active -> bool {
    return self._banner_shown;
}

"""Module hub for jaclang.* modules (lazily initialized)."""
impl JacCompiler.internal_program -> JacProgram {
    if (self._internal_program is None) {
        import from jaclang.jac0core.program { JacProgram }
        self._internal_program = JacProgram();
    }
    return self._internal_program;
}

"""Get the jaclang package root path."""
impl JacCompiler._get_jaclang_root(cls: Any) -> str {
    if (cls._jaclang_root is None) {
        cls._jaclang_root = os.path.dirname(os.path.dirname(__file__));
    }
    return cls._jaclang_root;
}

"""Route jaclang.* files to internal_program, others to target_program."""
impl JacCompiler._resolve_program(
    file_path: str, target_program: JacProgram
) -> JacProgram {
    normalized_path = os.path.normpath(file_path);
    jaclang_root = self._get_jaclang_root();
    if normalized_path.startswith((jaclang_root + os.sep)) {
        return self.internal_program;
    }
    return target_program;
}

"""Get native interop setup for a module.

    Returns:
        Tuple of (native_engine, interop_py_funcs_dict).
        native_engine is None if no native code.
        interop_py_funcs_dict is None if module not found in hub
        (caller should not inject into module dict in this case).
    """
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

"""Get native module layout metadata for auto-marshalling."""
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

"""Get bytecode using 2-tier cache: in-memory -> JIR -> compile.

    Tier 1: in-memory hub (py_bytecode already set).
    Tier 2: JIR cache fast-path (read_bytecode_only, no AST deserialize).
    Tier 2.5: precompiled JIR bundle shipped with the package.
    Tier 3: full compile + atomic JIR write.
    """
impl JacCompiler.get_bytecode(
    full_target: str, target_program: JacProgram
) -> (types.CodeType | None) {
    actual_program = self._resolve_program(full_target, target_program);

    # Tier 1: in-memory hub
    if (
        (full_target in actual_program.mod.hub)
        and actual_program.mod.hub[full_target].gen.py_bytecode
    ) {
        codeobj = actual_program.mod.hub[full_target].gen.py_bytecode;
        return marshal.loads(codeobj) if isinstance(codeobj, `bytes) else None;
    }

    # Tier 2: JIR cache fast path
    cache_path = get_module_cache_path(full_target);
    if is_module_cache_valid(full_target, cache_path) {
        try {
            jir_data = cache_path.read_bytes();
            bc = read_bytecode_only(jir_data);
            if bc is not None {
                magic_bytes: Any = SECTIONS_MAGIC;
                sec_pos = jir_data.find(magic_bytes, HEADER_SIZE);
                if sec_pos >= 0 {
                    secs = read_sections(jir_data, sec_pos + len(magic_bytes));
                    self._restore_sections(full_target, actual_program, secs);
                }
                return marshal.loads(bc);
            }
        } except Exception {
            ;
        }
    }

    # Tier 2.5: precompiled JIR bundle shipped with the package
    precompiled_bc = self._get_precompiled_jir_bytecode(full_target);
    if precompiled_bc is not None {
        try {
            import from jaclang.jac0core.jir { write_precompiled_jir, FLAG_PRECOMPILED }
            jir_bytes = write_precompiled_jir(precompiled_bc, 0, FLAG_PRECOMPILED);
            cache_path.parent.mkdir(parents=True, exist_ok=True);
            tmp_path = cache_path.with_suffix('.tmp');
            tmp_path.write_bytes(jir_bytes);
            tmp_path.rename(cache_path);
        } except Exception {
            ;
        }
        return marshal.loads(precompiled_bc);
    }

    # Tier 3: full compile + JIR write
    is_internal = actual_program is self._internal_program;
    if is_internal {
        setup_progress.on_internal_compile(full_target);
    }
    # Skip type checking when the type check infrastructure is not yet
    # available. This happens during bootstrap: TypeCheckPass and
    # TypeEvaluator are themselves internal modules that need compilation,
    # so attempting to type-check before they're ready causes circular
    # imports. Once bootstrap completes, all modules get type-checked.
    can_typecheck = (
        'jaclang.compiler.passes.main.type_checker_pass' in sys.modules
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
        try {
            import from jaclang.jac0core.jir_passes { JirWriter }
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
            # Prefer post-optimization bitcode (SEC_NATIVE_OBJ) over
            # text IR (SEC_LLVM_IR). Bitcode is faster to parse and
            # preserves optimization work done by NativeCompilePass.
            native_bc = result.gen.native_bitcode;
            if native_bc is not None {
                import struct as _struct;
                import llvmlite.binding as _llvm;
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
            tmp_path = cache_path.with_suffix('.tmp');
            tmp_path.write_bytes(jir_bytes);
            tmp_path.rename(cache_path);
        } except Exception {
            ;
        }
        return marshal.loads(result.gen.py_bytecode);
    }
    return None;
}

"""Load native module from cached LLVM IR.

    Creates a fresh MCJIT engine from the cached IR string and sets up
    interop callbacks. This is much faster than full recompilation since
    we skip the Jac-AST-LLVM IR pipeline.
    """
impl JacCompiler._load_native_from_cache(
    full_target: str,
    target_program: JacProgram,
    cached_ir: str,
    cached_interop: (dict[str, Any] | None)
) -> None {
    try {
        import llvmlite.binding as llvm;
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
        import from jaclang.jac0core.codeinfo { CodeGenTarget, InteropManifest }
        gen = CodeGenTarget();
        gen.native_engine = engine;
        py_func_table: dict = {};
        callbacks_list: list = [];
        gen.interop_py_funcs = py_func_table;
        gen._interop_callbacks = callbacks_list;
        if cached_interop {
            import from jaclang.jac0core.codeinfo { InteropBinding, InteropContext }
            import from jaclang.jac0core.interop_bridge { register_py_callbacks }
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

"""Load native module from cached post-optimization bitcode.

    Parses the SEC_NATIVE_OBJ section which contains a platform header
    followed by LLVM bitcode. Bitcode parsing is faster than text IR
    parsing and the bitcode is already optimized.
    """
impl JacCompiler._load_native_from_bitcode(
    full_target: str,
    target_program: JacProgram,
    section_data: bytes,
    cached_interop: (dict[str, Any] | None)
) -> None {
    import struct as _struct;
    import llvmlite.binding as llvm;
    llvm.initialize_native_target();
    llvm.initialize_native_asmprinter();
    # Parse platform header: [triple_len: 2 LE] [triple: UTF-8] [bitcode ...]
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
    # Load shared libraries for symbol resolution
    import ctypes;
    import ctypes.util;
    libc_name = ctypes.util.find_library('c');
    if libc_name {
        llvm.load_library_permanently(libc_name);
    }
    # Parse bitcode and create engine (no optimization needed — already done)
    llvm_mod = llvm.parse_bitcode(bitcode);
    target = llvm.Target.from_default_triple();
    target_machine = target.create_target_machine();
    engine = llvm.create_mcjit_compiler(llvm_mod, target_machine);
    import from jaclang.jac0core.codeinfo { CodeGenTarget, InteropManifest }
    gen = CodeGenTarget();
    gen.native_engine = engine;
    py_func_table: dict = {};
    callbacks_list: list = [];
    gen.interop_py_funcs = py_func_table;
    gen._interop_callbacks = callbacks_list;
    if cached_interop {
        import from jaclang.jac0core.codeinfo { InteropBinding, InteropContext }
        import from jaclang.jac0core.interop_bridge { register_py_callbacks }
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
        gen.interop_manifest = manifest;
        if manifest.native_imports {
            register_py_callbacks(manifest, py_func_table, callbacks_list);
        }
    }
    target_program._native_cache[full_target] = gen;
}

"""Restore side-effects (MTIR, native) from decoded JIR sections."""
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
    # Try fast path: post-optimization bitcode (SEC_NATIVE_OBJ)
    native_obj_bytes = secs.get(SEC_NATIVE_OBJ);
    if native_obj_bytes is not None {
        try {
            import json;
            cached_interop: (dict[str, Any] | None) = None;
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
    # Fallback: text IR (SEC_LLVM_IR)
    llvm_bytes = secs.get(SEC_LLVM_IR);
    if llvm_bytes is not None {
        try {
            import zlib;
            import json;
            cached_ir = zlib.decompress(llvm_bytes).decode('utf-8');
            cached_interop2: (dict[str, Any] | None) = None;
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

"""Walk up from a .jac file looking for a _precompiled/ JIR bundle."""
impl JacCompiler._get_precompiled_jir_bytecode(full_target: str) -> (bytes | None) {
    import hashlib;
    import json;
    import from pathlib { Path as _Path }
    norm_file = os.path.normpath(os.path.abspath(full_target));
    d = os.path.dirname(norm_file);
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    while True {
        manifest_path = os.path.join(d, '_precompiled', 'manifest.json');
        if os.path.isfile(manifest_path) {
            try {
                with open(manifest_path, encoding='utf-8') as f {
                    manifest = json.load(f);
                }
                norm_root = os.path.normpath(d);
                if not norm_file.startswith(norm_root + os.sep) {
                    break;
                }
                rel_path = norm_file[len(norm_root) + 1:];
                rel_key = rel_path.replace(os.sep, '/');
                entries = manifest.get('entries', {});
                entry = entries.get(rel_key);
                if not isinstance(entry, dict) {
                    break;
                }
                expected = entry.get('source_hash');
                if expected {
                    with open(norm_file, 'rb') as f2 {
                        actual = hashlib.sha256(f2.read()).hexdigest();
                    }
                    if actual != expected {
                        break;
                    }
                }
                sentinel = manifest.get('filename_sentinel', '__PKG_ROOT__');
                # Try .jir bundle first
                jir_rel = os.path.splitext(rel_path)[0] + '.jir';
                jir_path = os.path.join(d, '_precompiled', pyver, jir_rel);
                if os.path.isfile(jir_path) {
                    jir_data = _Path(jir_path).read_bytes();
                    if len(jir_data) >= 32 {
                        import struct;
                        (flags_val, ) = struct.unpack_from('<I', jir_data, 28);
                        if flags_val & FLAG_PRECOMPILED {
                            bc = read_bytecode_only(jir_data);
                            if bc is not None {
                                return patch_co_filenames_bytes(bc, sentinel, d);
                            }
                        }
                    }
                }
                # Fallback: legacy .jbc bundle
                jbc_rel = os.path.splitext(rel_path)[0] + '.jbc';
                jbc_path = os.path.join(d, '_precompiled', pyver, jbc_rel);
                if os.path.isfile(jbc_path) {
                    return patch_co_filenames_bytes(
                        _Path(jbc_path).read_bytes(), sentinel, d
                    );
                }
            } except Exception {
                ;
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

"""Build a JSON-serializable interop dict from a compiled module."""
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
    return interop_data;
}

"""Parse source string into AST module."""
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
        (mod, had_error) = rd_parse(source_str, file_path, prog=target_program);
        if file_path.endswith('.cl.jac') {
            _coerce_client_module(mod);
        } elif file_path.endswith('.sv.jac') {
            _coerce_server_module(mod);
        } elif file_path.endswith('.na.jac') {
            _coerce_native_module(mod);
        }
    }
    if had_error {
        return mod;
    }
    if target_program.mod.main.stub_only {
        # Preserve the existing hub when replacing the stub main module
        old_hub = target_program.mod.hub;
        target_program.mod = uni.ProgramModule(main_mod=mod);
        target_program.mod.hub.update(old_hub);
    }
    target_program.mod.hub[mod.loc.mod_path] = mod;
    JacAnnexPass(ir_in=mod, prog=target_program);
    return mod;
}

"""Compile a Jac file into module AST.

    Args:
        file_path: Path to the Jac file to compile.
        target_program: JacProgram to store compiled module in.
        use_str: Optional source string instead of reading from file.
        options: CompileOptions controlling compilation behavior.
    """
impl JacCompiler.compile(
    file_path: str,
    target_program: JacProgram,
    use_str: (str | None) = None,
    options: CompileOptions = CompileOptions()
) -> uni.Module {
    # For impl/test annex files compiled standalone, redirect to compile the
    # parent module instead. The parent's JacAnnexPass discovers and attaches
    # the impl, and DeclImplMatchPass connects them with full scope context.
    # Only applies when resolve_annex_parent is set to avoid affecting
    # AST-only compilation (e.g., micro suite tests).
    if (
        use_str is None
        and options.resolve_annex_parent
        and (file_path.endswith('.impl.jac') or file_path.endswith('.test.jac'))
    ) {
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
    if options.type_check {
        self.run_schedule(
            mod=mod_targ,
            target_program=actual_program,
            passes=get_type_check_sched(),
            cancel_token=options.cancel_token
        );
    }
    if (not had_parse_errors and not options.no_cgen) {
        self.run_schedule(
            mod=mod_targ,
            target_program=actual_program,
            passes=get_py_code_gen(),
            cancel_token=options.cancel_token
        );
    }
    return mod_targ;
}

"""Build a Jac file with import dependency resolution."""
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

"""Run a list of passes on a module."""
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

"""Parse a Jac file/string and optionally load annexes for tooling passes.

Shared scaffold for jac_file_formatter, jac_str_formatter, and jac_file_linter.
Returns (prog, current_mod) or (prog, None) if parse errors occurred.
"""
impl JacCompiler._prepare_tool_program(
    source_str: str,
    file_path: str,
    load_impl_annexes: bool = False,
    load_test_annexes: bool = False
) -> tuple[JacProgram, (uni.Module | None)] {
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.parser { parse as rd_parse }
    prog = JacProgram();
    (current_mod, had_error) = rd_parse(source_str, file_path, prog=prog);
    if had_error {
        prog.mod = uni.ProgramModule(main_mod=current_mod);
        return (prog, None);
    }
    # Parse-only annex loading: just parse .impl.jac/.test.jac files
    # without running SymTabBuildPass or any compilation passes.
    # This avoids cascading import resolution that would compile the
    # entire dependency graph for each formatted file.
    if load_impl_annexes or load_test_annexes {
        import from jaclang.jac0core.bccache { discover_annex_files }
        if load_impl_annexes {
            for annex_path in discover_annex_files(file_path, '.impl.jac') {
                try {
                    annex_src = read_file_with_encoding(annex_path);
                    (annex_mod, _) = rd_parse(annex_src, annex_path, prog=prog);
                    current_mod.impl_mod.append(annex_mod);
                } except Exception {
                    ;
                }
            }
        }
        if load_test_annexes {
            for annex_path in discover_annex_files(file_path, '.test.jac') {
                try {
                    annex_src = read_file_with_encoding(annex_path);
                    (annex_mod, _) = rd_parse(annex_src, annex_path, prog=prog);
                    current_mod.test_mod.append(annex_mod);
                } except Exception {
                    ;
                }
            }
        }
    }
    return (prog, current_mod);
}

"""Format a Jac file."""
impl JacCompiler.jac_file_formatter(
    file_path: str, auto_lint: bool = False
) -> JacProgram {
    source_str = read_file_with_encoding(file_path);
    (prog, current_mod) = JacCompiler._prepare_tool_program(
        source_str, file_path, load_impl_annexes=auto_lint, load_test_annexes=auto_lint
    );
    if current_mod is None {
        return prog;
    }
    for pass_cls in get_format_sched(auto_lint=auto_lint) {
        current_mod = pass_cls(ir_in=current_mod, prog=prog).ir_out;
    }
    prog.mod = uni.ProgramModule(main_mod=current_mod);
    return prog;
}

"""Format a Jac source string."""
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

"""Lint a Jac file (report only, no formatting or output generation)."""
impl JacCompiler.jac_file_linter(file_path: str) -> JacProgram {
    source_str = read_file_with_encoding(file_path);
    (prog, current_mod) = JacCompiler._prepare_tool_program(
        source_str, file_path, load_impl_annexes=True
    );
    if current_mod is None {
        return prog;
    }
    for pass_cls in get_lint_sched() {
        current_mod = pass_cls(ir_in=current_mod, prog=prog).ir_out;
    }
    prog.mod = uni.ProgramModule(main_mod=current_mod);
    return prog;
}
