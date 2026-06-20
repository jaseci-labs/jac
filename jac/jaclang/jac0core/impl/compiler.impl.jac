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
impl _SetupProgress.is_active.getter -> bool {
    return self._banner_shown;
}

"""Module hub for jaclang.* modules (lazily initialized)."""
impl JacCompiler.internal_program.getter -> JacProgram {
    if (self._internal_program is None) {
        import from jaclang.jac0core.program { JacProgram }
        self._internal_program = JacProgram();
    }
    return self._internal_program;
}

"""Get the jaclang package root path."""
impl JacCompiler._get_jaclang_root(cls: any) -> str {
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
    (rebuild, no_precompile) = cache_mode();

    # Tier 1: in-memory hub
    if (
        (not rebuild)
        and (full_target in actual_program.mod.hub)
        and actual_program.mod.hub[full_target].gen.py_bytecode
    ) {
        codeobj = actual_program.mod.hub[full_target].gen.py_bytecode;
        return marshal.loads(codeobj) if isinstance(codeobj, `bytes) else None;
    }

    # Tier 2: JIR cache fast path
    cache_path = get_module_cache_path(full_target);
    if (not rebuild) and is_module_cache_valid(full_target, cache_path) {
        try {
            jir_data = cache_path.read_bytes();
            bc = read_bytecode_only(jir_data);
            if bc is not None {
                magic_bytes: any = SECTIONS_MAGIC;
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
    if (not rebuild) and (not no_precompile) {
        precompiled_bc = self._get_precompiled_jir_bytecode(full_target);
        if precompiled_bc is not None {
            try {
                # Launder into the module cache, stamped with the real key so
                # the next load hits the Tier 2 mtime fast-path and the entry
                # still re-validates correctly when mtime is ambiguous.
                import from jaclang.jac0core.jir {
                    write_precompiled_jir,
                    FLAG_PRECOMPILED
                }
                jir_bytes = write_precompiled_jir(
                    precompiled_bc, compute_module_key(full_target), FLAG_PRECOMPILED
                );
                cache_path.parent.mkdir(parents=True, exist_ok=True);
                tmp_path = cache_path.with_suffix('.tmp');
                tmp_path.write_bytes(jir_bytes);
                tmp_path.rename(cache_path);
            } except Exception {
                ;
            }
            return marshal.loads(precompiled_bc);
        }
    }

    # Tier 3: full compile + JIR write
    is_internal = actual_program is self._internal_program;
    if is_internal {
        setup_progress.on_internal_compile(full_target);
    }
    # Full type checking here is for INTERNAL (jaclang.*) modules only: the
    # compiler's own code is held to full type discipline post-bootstrap
    # (compile() skips inference for internal modules mid-bootstrap, so this
    # is where they get typed). It must wait until the type check
    # infrastructure is available — TypeCheckPass and TypeEvaluator are
    # themselves internal modules, and type-checking before they're ready
    # causes circular imports.
    #
    # USER modules loaded at runtime must NOT have full diagnostics forced
    # on them: their compile() already runs gated inference (typed-tree
    # contract), and surfacing checker diagnostics belongs to explicit
    # `jac check` / options.type_check (plus the native-context gate).
    # Forcing it here would make `jac run`/`jac start` of a plain sv/cl app
    # fail on checker false positives whenever the module cache is cold and
    # the type system happens to be loaded (#6262).
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
    cached_interop: (dict[str, any] | None)
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

"""Load native module from cached post-optimization bitcode.

    Parses the SEC_NATIVE_OBJ section which contains a platform header
    followed by LLVM bitcode. Bitcode parsing is faster than text IR
    parsing and the bitcode is already optimized.
    """
impl JacCompiler._load_native_from_bitcode(
    full_target: str,
    target_program: JacProgram,
    section_data: bytes,
    cached_interop: (dict[str, any] | None)
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
    # Fallback: text IR (SEC_LLVM_IR)
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

"""Walk up from a .jac file for a self-validating _precompiled/ JIR bundle.

The shipped .jir carries its own SEC_MODKEY, so validation is the same
`jir_matches_source` key-compare the module cache uses — no manifest, no
per-file hash table. co_filenames are patched from the build-time sentinel
back to the install directory.
"""
impl JacCompiler._get_precompiled_jir_bytecode(full_target: str) -> (bytes | None) {
    import from pathlib { Path as _Path }
    import from jaclang.jac0core.jir { PRECOMPILE_SENTINEL }
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
            if os.path.isfile(jir_path) {
                try {
                    jir_data = _Path(jir_path).read_bytes();
                    if jir_matches_source(jir_data, norm_file) {
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
    # Carried so a warm-cache load keeps the serve access table populated.
    interop_data['func_access'] = dict(manifest.func_access);
    interop_data['walker_access'] = dict(manifest.walker_access);
    interop_data['endpoint_effects'] = dict(manifest.endpoint_effects);
    return interop_data;
}

"""Rebuild an InteropManifest from a cached interop dict.

Shared by the native cache loaders so the bindings deserialization lives
in exactly one place. ast_node is intentionally left None: it is a live
AST node that is never reserialized and no cache-hit consumer derefs it.
"""
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
    import from pathlib { Path as _HubPath }
    target_program.mod.hub[str(_HubPath(mod.loc.mod_path).resolve())] = mod;
    # JacAnnexPass splices each annex's body into the head module and coerces it
    # to the head's deployment context (so a native head's annex globals/enums/
    # defs survive native codegen's context filter -- issue #6754).
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
    # Count codegen-blocking errors attributed to *this* module only. The IR
    # schedule below recursively compiles imported modules into the same
    # program; filtering by file path keeps a nested module's diagnostics from
    # poisoning this module's codegen gate.
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
    # Diagnostics flagged blocks_codegen (e.g. E0063 glob inside a function)
    # must prevent code generation just like parse errors, otherwise an
    # invalid construct that happens to compile to valid Python would silently
    # execute. Structural errors not flagged blocking (e.g. E0076 duplicate
    # method) stay non-fatal, matching the codebase's lenient codegen policy.
    blocking_errs_post_ir = self._count_module_blocking_errors(
        actual_program, cur_mod_path
    );
    had_blocking_errors = blocking_errs_post_ir > blocking_errs_pre_ir;
    # Run type inference only when a backend consumes a checker-stamped fact:
    # the native (na) backend lowers annotations through Expr.type, and both
    # the native and client (cl/JavaScript) backends read FuncCall.callee_decl
    # to lower kwargs to ordered positional args (esast_gen_pass has no
    # re-resolution fallback). `jac check` also wants the diagnostics. The
    # plain sv (Python) backend reads none of these (Python keeps kwargs as
    # kwargs), so inference on a pure-sv build is wasted work: it walks the
    # whole import graph and stamps caches nothing consumes. TypeCheckPass
    # still self-gates diagnostic emission (full for `jac check` /
    # native-context per #6049, suppressed otherwise per #6262).
    run_inference = options.type_check;
    if not run_inference {
        mp = mod_targ.loc.mod_path if (mod_targ?.loc and mod_targ.loc) else file_path;
        is_native_mod = (bool(mp) and mp.endswith('.na.jac'))
        or (
            actual_program._auto_promote_native
            and mod_targ?.gen
            and mod_targ.gen.native_compat
        );
        is_client_mod = bool(mp) and mp.endswith('.cl.jac');
        # A `na { }` / `cl { }` block puts native / client code in an otherwise
        # plain .jac module; one body scan covers both extensions' inline form.
        if (not is_native_mod or not is_client_mod) and mod_targ?.body {
            for _stmt in mod_targ.body {
                if isinstance(_stmt, uni.NativeBlock) {
                    is_native_mod = True;
                }
                if isinstance(_stmt, uni.ClientBlock) {
                    is_client_mod = True;
                }
            }
        }
        # Native consumes Expr.type even on lightweight (no_cgen /
        # symtab_ir_only) compiles, since the cross-module native linker lowers
        # a provider's annotations on demand. Client only reads callee_decl
        # while EsastGenPass actually emits JS, so it is gated on real codegen
        # (this keeps the boundary-completion walk's no_cgen=True compiles from
        # paying a TypeCheckPass they would only waste).
        run_inference = is_native_mod
        or (is_client_mod and not options.no_cgen and not options.symtab_ir_only);
    }
    if run_inference {
        mod_targ._inference_started = True;
        # Flow-narrowing (`is not None` / isinstance) inside TypeInferencePass
        # walks the CFG (UniCFGNode.bb_in/bb_out). The full IR-gen schedule
        # built that CFG above, but a symtab_ir_only compile skipped it. Native
        # still forces inference on those modules (imported dependency / on-
        # demand cross-module provider lowering), so build the CFG first or the
        # narrowing silently no-ops and a `T | None` guarded by `is not None`
        # stays `T | None` only on the imported-module path (issue #6667). The
        # entry path (symtab_ir_only False) already has its CFG -- skip the
        # redundant build there.
        if options.symtab_ir_only {
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_cfg_sched(),
                cancel_token=options.cancel_token
            );
        }
        # Diagnostic-mode intent must ride on the module, not on the
        # program's ambient _compile_options: creating the TypeEvaluator
        # inside TypeCheckPass.before_pass triggers nested compiles (stub
        # prefetch, builtin imports) that each overwrite
        # prog._compile_options with their own (non-check) options before
        # the pass reads its diagnostic gate. See before_pass.
        mod_targ._type_check_requested = bool(options.type_check);
        try {
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_inference_sched(),
                cancel_token=options.cancel_token
            );
        } except Exception {
            # A partial inference run must not satisfy the dep-sweep guard:
            # the module would be skipped on retry with an incompletely
            # typed tree and no E9002 to catch it.
            mod_targ._inference_started = False;
            raise;
        }
        # JIR-loaded dependency modules arrive untyped (Expr.type is not
        # serialized), while a freshly compiled dep is typed by its own
        # nested compile. Native cross-module codegen lowers dep-module
        # annotations through Expr.type, so the typed-tree contract must
        # hold for every native module in the program regardless of how it
        # was loaded. The _inference_started flag (set before each run)
        # breaks the cycle where inferring a dep makes the evaluator
        # compile a sibling, whose own dep sweep would re-infer modules
        # already mid-inference.
        for dep_mod in list(actual_program.mod.hub.values()) {
            if (dep_mod is mod_targ) or dep_mod?._inference_started {
                continue;
            }
            dep_path = dep_mod.loc.mod_path if dep_mod?.loc else '';
            if dep_path.endswith('.na.jac') {
                dep_mod._inference_started = True;
                # Quiet run: populate types only. A JIR-loaded tree's
                # cross-module link state is degraded versus a fresh
                # front-end run, so full checking here would emit false
                # positives; diagnostics belong to each module's own
                # entry compile.
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
                    # A leaked quiet flag would silently suppress every
                    # diagnostic from this module's own entry compile later
                    # in the same process.
                    dep_mod._inference_quiet = False;
                }
            }
        }
    }
    if options.type_check {
        # Explicit `jac check`: diagnostic-only extras (StaticAnalysis /
        # Portability / Lint) layered on the inference run above. The
        # inference run already surfaced TYPE diagnostics in full mode;
        # CapabilityCheckPass is NOT re-run here (it runs exactly once at the
        # tail of get_ir_gen_sched — rerunning it mutates AST state that
        # NaIRGenPass and the cross-module linker depend on).
        self.run_schedule(
            mod=mod_targ,
            target_program=actual_program,
            passes=get_type_check_sched(),
            cancel_token=options.cancel_token
        );
    }
    # Single front-end producer of cross-boundary (interop) facts. Runs after
    # type-check and before any codegen, for EVERY module (server / client /
    # native), independent of the codegen gate — so client (.cl.jac) modules
    # and --no-client / --dev compiles still get their boundary facts. Skipped
    # for symtab_ir_only provider resolutions (lightweight, no codegen need).
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
    # Boundary completion for cross-boundary apps. A plain top-level compile runs
    # BoundaryAnalysisPass only on the entry; the client (.cl.jac) modules reached
    # through its `to cl:` imports -- which carry the client->server `sv import`
    # bindings the serve runtime needs -- are not pulled into the program by a
    # normal compile/import (only the bundle/ecmascript build compiles them).
    # Walk the entry's client import graph and front-end-compile each reachable
    # `.cl.jac` into THIS program so BoundaryAnalysisPass records its
    # `server_exports_to_client` bindings in the hub. The serve runtime then
    # reads the endpoint set from that table rather than re-deriving it at
    # request time. Gated to the real top-level compile (not the lightweight
    # symtab_ir_only / no_cgen provider resolutions that nest under it).
    if (
        not had_parse_errors
        and not had_blocking_errors
        and not options.symtab_ir_only
        and not options.no_cgen
    ) {
        import os as _cb_os;
        cb_seen: set[str] = set();
        cb_worklist: list = [mod_targ];
        # type_check=False is load-bearing: CompileOptions.type_check defaults
        # to True, and BoundaryAnalysisPass derives every cross-boundary fact
        # from the AST + symbol table alone (never resolved `.type`), so the
        # type-check schedule buys no boundary fidelity here. Leaving it on
        # would force the full TypeCheckPass over every reachable .cl.jac --
        # exactly the idiomatic-client false positives (untyped JSX-returning
        # components, untyped-prop access, Any-typed handlers) that the
        # top-of-compile NOTE deliberately avoids on the entry; see #6262.
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
                # Skip language built-in `@jac/*` virtual modules (e.g.
                # `@jac/runtime`, the client framework runtime). These are never
                # user cross-boundary providers -- they carry no `sv import`
                # bindings -- yet the alias resolves to a real `.cl.jac` under
                # runtimelib. Pulling the framework runtime into the program
                # makes the entry's codegen type-evaluate its browser-global
                # bodies (document/Array/...), surfacing spurious type errors.
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
                if not (isinstance(cb_src, str) and cb_src.endswith('.cl.jac')) {
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
        # Re-pin _compile_options to *our* options before codegen runs.
        # Earlier schedules may have invoked nested compile()s (e.g.
        # TypeCheckPass loading an imported module to resolve a symbol),
        # and each nested compile overwrites prog._compile_options. Native
        # codegen (NaCompilePass) reads skip_native_engine / aot_mode from
        # this slot; without the re-pin it would see the last nested
        # caller's options instead of ours.
        actual_program._compile_options = options;
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

"""Parse a Jac file/string and optionally load annexes for tooling passes.

Shared scaffold for jac_file_formatter, jac_str_formatter, and jac_file_linter.
Returns (prog, current_mod) or (prog, None) if parse errors occurred.
"""
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
    # Tooling formats each file independently; annex files are formatted as
    # their own tool programs by the caller, so nothing is attached here.
    return (prog, current_mod);
}

"""Format a Jac file."""
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
