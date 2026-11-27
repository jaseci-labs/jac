impl JacCompiler.selfhost.getter -> SelfHostCache {
    cache = self._selfhost;
    if (cache is None) {
        import from jaclang.runtime.runtime { JacRuntime }
        cache = JacRuntime.get_selfhost();
        self._selfhost = cache;
    }
    return cache;
}

impl JacCompiler.stub_catalog -> StubCatalog | None {
    if self.stub_catalog_disabled {
        return None;
    }
    found = self._stub_catalog;
    if found is not None {
        return found;
    }
    import from jaclang.jac0core.stubcat_hook { active }
    found = active();
    self._stub_catalog = found;
    return found;
}

impl JacCompiler.ensure_stub_catalog -> StubCatalog | None {
    if self.stub_catalog_disabled {
        return None;
    }
    found = self.stub_catalog();
    if found is None {
        import from jaclang.jac0core.artifact_registry { resolution_in_flight }
        if self._stub_catalog_tried or resolution_in_flight() {
            return None;
        }
        self._stub_catalog_tried = True;
        import jaclang.compiler.types.stubcat.format;
        import jaclang.compiler.types.stubcat.reader;
        import from jaclang.compiler.types.stubcat.locate { open_catalog }
        found = open_catalog();
        self._stub_catalog = found;
    }

    internal = self._selfhost.peek_program() if self._selfhost is not None else None;
    if found is not None
        and internal is not None
        and not self._reentrant_depth
        and not internal.compile_depth
        and any(path.endswith('.pyi') for path in internal.mod.hub) {
        self.release_compile_state(internal);
    }
    return found;
}

impl JacCompiler.product_program(
    full_target: str, target_program: JacProgram
) -> JacProgram {
    return program_for(full_target, self.selfhost.resolve(full_target, target_program));
}

impl JacCompiler.get_native_interop_setup(
    full_target: str, target_program: JacProgram
) -> tuple[((object | None), (dict[(str, object)] | None))] {
    actual_program = self.product_program(full_target, target_program);
    if (full_target in actual_program.hub.artifacts) {
        gen = actual_program.hub.artifacts[full_target];
        return (gen.native_engine, gen.interop_py_funcs);
    }
    keyed = actual_program.find_module(full_target);
    if keyed is not None {
        return (keyed.gen.native_engine, keyed.gen.interop_py_funcs);
    }
    return (None, None);
}

impl JacCompiler.get_bytecode(
    full_target: str, target_program: JacProgram, skip_analysis: bool = False
) -> (types.CodeType | None) {
    if full_target.endswith('.py') {
        import builtins;
        import from jaclang.project.textio { read_file_with_encoding }
        return builtins.compile(
            read_file_with_encoding(full_target), full_target, 'exec'
        );
    }
    actual = self.product_program(full_target, target_program);
    with compilation_scope(owner_scope_options(actual)) {
        return self._get_bytecode(full_target, actual, skip_analysis);
    }
}

impl JacCompiler._get_bytecode(
    full_target: str, target_program: JacProgram, skip_analysis: bool = False
) -> (types.CodeType | None) {
    actual_program = self.selfhost.resolve(full_target, target_program);
    (rebuild, _) = cache_mode();
    hit_mod = None if rebuild else actual_program.mod.hub.get(full_target);
    if hit_mod is not None and not actual_program.is_hub_entry_fresh(full_target) {
        actual_program.invalidate_module(full_target);
        hit_mod = None;
    }
    if hit_mod is not None and not hit_mod.gen.py_bytecode {
        actual_program.invalidate_module(full_target);
    } elif hit_mod is not None {
        codeobj = hit_mod.gen.py_bytecode;
        if isinstance(codeobj, `bytes) and not actual_program.internal {
            self._persist_module_cache(full_target, hit_mod, actual_program);
        }
        native_artifact = actual_program.hub.artifacts.get(full_target);
        if hit_mod.gen.llvm_ir is not None
            and hit_mod.gen.native_engine is None
            and (native_artifact is None or native_artifact.native_engine is None)
            and self._wants_native_engine(full_target, actual_program) {
            self._load_native_from_cache(
                full_target, actual_program, interop_record(hit_mod)
            );
        }
        return marshal.loads(codeobj) if isinstance(codeobj, `bytes) else None;
    }

    if not rebuild {
        sealed = self._sealed_jir_data(full_target);
        if sealed is not None {
            import from jaclang.compiler.driver.jir { PRECOMPILE_SENTINEL }
            (sealed_data, sealed_root) = sealed;
            bc = read_bytecode_only(sealed_data);
            if bc is not None {
                magic0: any = SECTIONS_MAGIC;
                sp0 = sealed_data.find(magic0, HEADER_SIZE);
                if sp0 >= 0 {
                    self._restore_sections(
                        full_target,
                        actual_program,
                        read_sections(sealed_data, sp0 + len(magic0)),
                        base_dir=sealed_root
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
            jir_data = read_jir(cache_path);
            magic_bytes: any = SECTIONS_MAGIC;
            sec_pos = jir_data.find(magic_bytes, HEADER_SIZE);
            secs: dict[int, bytes] = (
                read_sections(jir_data, sec_pos + len(magic_bytes))
                    if sec_pos >= 0
                    else {}
            );
            bc = secs.get(SEC_BYTECODE);
            if bc is not None {
                self._restore_sections(full_target, actual_program, secs);
                _had_native_secs = SEC_NBITCODE in secs or SEC_NOBJ in secs;
                if (
                    _had_native_secs
                    and full_target not in actual_program.hub.artifacts
                    and not actual_program.internal
                    and self._wants_native_engine(full_target, actual_program)
                ) {
                    import logging as _bc_logging;
                    _bc_logging.getLogger(__name__).warning(
                        f"Cached native sections for {full_target} could "
                        f"not be restored; recompiling."
                    );

                    actual_program.invalidate_module(full_target);
                } else {
                    return marshal.loads(bc);
                }
            } else {
                actual_program.invalidate_module(full_target);
            }
        } except Exception {}
    }

    precompiled = self._get_precompiled_jir_bytecode(full_target);
    if precompiled is not None {
        (precompiled_bc, precompiled_ctdeps) = precompiled;
        try {
            import from jaclang.compiler.driver.jir { SEC_CTDEPS as _PC_CTDEPS }
            _pc_sections: dict[int, bytes] = {};
            if precompiled_ctdeps {
                _pc_sections[_PC_CTDEPS] = precompiled_ctdeps;
            }
            write_module_cache(
                full_target,
                precompiled_bc,
                flags=FLAG_PRECOMPILED,
                extra_sections=_pc_sections
            );
        } except Exception {}
        return marshal.loads(precompiled_bc);
    }
    carried = None if rebuild else carried_module_bytecode(full_target);
    if carried is not None {
        (carried_bc, carried_ctdeps) = carried;
        try {
            import from jaclang.compiler.driver.jir { SEC_CTDEPS as _CARRY_CTDEPS }
            write_module_cache(
                full_target,
                carried_bc,
                flags=FLAG_CARRIED,
                extra_sections=(
                    {_CARRY_CTDEPS: carried_ctdeps} if carried_ctdeps else {}
                )
            );
        } except Exception {}
        setup_progress.on_internal_reuse(full_target);
        return marshal.loads(carried_bc);
    }

    is_internal = actual_program.internal;
    if is_internal {
        setup_progress.on_internal_compile(full_target);
        self.selfhost.enter_bytecode();
    }
    options = CompileOptions(
        skip_native_engine=not self._wants_native_engine(full_target, actual_program),
        skip_analysis=skip_analysis
    );
    result: (uni.Module | None) = None;
    enclosing_closure = self._closure_opts;
    self._closure_opts = options;
    try {
        result = self.compile(
            file_path=full_target, target_program=actual_program, options=options
        );
        if result.gen.py_bytecode {
            actual_program.hub.stamp(full_target);
            self._persist_module_cache(full_target, result, actual_program);
            if is_internal {
                note_compiler_source_failure(full_target, '');
            }
            return marshal.loads(result.gen.py_bytecode);
        }
        if is_internal {
            note_compiler_source_failure(
                full_target,
                module_scoped_failure_details(full_target, actual_program)
                    or bootstrap_tier_failure_details(full_target)
            );
        }
        return None;
    } finally {
        self._closure_opts = enclosing_closure;
        if is_internal {
            if self.selfhost.at_outermost_bytecode() {
                self.selfhost.evict_unit(
                    full_target, result, collect=self.unit_collect
                );
            }
            self.selfhost.exit_bytecode();
        }
    }
}

impl JacCompiler.native_entry_engine(
    full_target: str, target_program: JacProgram
) -> any {
    path = JacProgram.hub_key(full_target);
    if self.get_bytecode(full_target=path, target_program=target_program) is None {
        return None;
    }
    actual = self.product_program(path, target_program);
    placed = summary_store(actual).get(os.path.abspath(path));
    if placed is None or placed.decided != 'native' {
        return None;
    }
    (engine, _callbacks) = self.get_native_interop_setup(path, target_program);
    return engine;
}

impl JacCompiler._wants_native_engine(full_target: str, program: JacProgram) -> bool {
    if is_compiler_source_path(full_target) {
        return False;
    }
    opts = program.options;
    if opts is None {
        return True;
    }
    return not (opts.aot_mode or opts.skip_native_engine);
}

impl JacCompiler._load_native_from_cache(
    full_target: str,
    target_program: JacProgram,
    cached_interop: (dict[str, any] | None)
) -> None {
    engine: ExecutionEngine | SharedNativeEngine | None = self._sealed_native_engine(
        full_target
    );
    if engine is None {
        import from jaclang.compiler.backends.native.link_plan { jit_engine_for_cached }
        engine = jit_engine_for_cached(
            target_program, full_target, target_program.options or CompileOptions()
        );
    }
    if engine is None {
        return;
    }
    gen = target_program.hub.artifacts.get(full_target) or CodeGenTarget();
    self._restore_native_clibs(gen, cached_interop);
    gen.native_engine = engine;
    py_func_table: dict[str, Callable[..., object]] = {};
    callbacks_list: list[object] = [];
    gen.interop_py_funcs = py_func_table;
    gen._interop_callbacks = callbacks_list;
    if cached_interop {
        manifest = interop_manifest_of(cached_interop);
        gen.interop_manifest = manifest;
        import from jaclang.runtime.native_library { SharedNativeEngine }
        if manifest.callable_native_imports
            and not isinstance(engine, SharedNativeEngine) {
            import from jaclang.runtime.interop_bridge { register_py_callbacks }
            import jaclang.compiler.backends.native.llvm.binding as llvm;
            register_py_callbacks(
                manifest.callable_native_imports,
                py_func_table,
                callbacks_list,
                llvm.add_symbol
            );
        }
    }
    target_program.hub.artifacts[full_target] = gen;
}

impl JacCompiler._sealed_native_engine(
    full_target: str
) -> (SharedNativeEngine | None) {
    found = _sealed.image_for_path(full_target);
    if found is None {
        return None;
    }
    record = found.native_artifact();
    if record is None {
        return None;
    }
    import from jaclang.runtime.native_library { shared_engine_for }
    return shared_engine_for(str(found.pkg_dir / record["path"]), record);
}

impl JacCompiler._restore_sections(
    full_target: str,
    actual_program: JacProgram,
    secs: dict[int, bytes],
    base_dir: str = ""
) -> None {
    if (SEC_NBITCODE in secs or SEC_NOBJ in secs)
        and self._wants_native_engine(full_target, actual_program) {
        try {
            import json;
            cached_interop: (dict[str, any] | None) = None;
            interop_bytes = secs.get(SEC_INTEROP);
            if interop_bytes is not None {
                cached_interop = json.loads(interop_bytes.decode('utf-8'));
            }
            self._load_native_from_cache(full_target, actual_program, cached_interop);
        } except Exception as e {
            import logging;
            logging.getLogger(__name__).debug(
                f"Failed to load native module from cache: {e}"
            );
        }
    }
    client_bytes = secs.get(SEC_CLIENT);
    if client_bytes is not None {
        restored_client = client_artifact_from_bytes(client_bytes);
        if restored_client is not None {
            actual_program.hub.client_artifacts[full_target] = restored_client;
        }
    }
    mtir_bytes = secs.get(SEC_MTIR);
    if mtir_bytes is not None {
        try {
            actual_program.mtir_map.update(
                info_graph_from_json(mtir_bytes.decode("utf-8"))
            );
        } except Exception {}
    }

    placement_bytes = secs.get(SEC_PLACEMENT);
    if placement_bytes is not None {
        try {
            import from jaclang.compiler.placement.placement { summary_store }
            import from jaclang.compiler.placement.placement_export {
                summary_from_bytes
            }
            import from jaclang.compiler.driver.jir { JirPaths, SEC_PATH_ROOT }
            paths = JirPaths.from_bytes(secs.get(SEC_PATH_ROOT), base_dir);
            restored = summary_from_bytes(placement_bytes, path_mapper=paths.resolve);
            if restored is not None {
                summary_store(actual_program)[os.path.abspath(full_target)] = restored;
            }
        } except Exception {}
    }
}

impl JacCompiler._precompiled_location(
    full_target: str
) -> (tuple[str, str, str, str] | None) {
    norm_file = os.path.normpath(os.path.abspath(full_target));
    d = os.path.dirname(norm_file);
    while not os.path.isdir(os.path.join(d, '_precompiled')) {
        parent = os.path.dirname(d);
        if parent == d {
            return None;
        }
        d = parent;
    }
    if not norm_file.startswith(d + os.sep) {
        return None;
    }
    rel_path = norm_file[len(d) + 1:];
    bundle_dir = os.path.join(d, '_precompiled');
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    jir_path = os.path.join(bundle_dir, pyver, os.path.splitext(rel_path)[0] + '.jir');
    return (norm_file, d, bundle_dir, jir_path);
}

impl JacCompiler._sealed_jir_data(full_target: str) -> (tuple[bytes, str] | None) {
    located = JacCompiler._precompiled_location(full_target);
    if located is None {
        return None;
    }
    (_, pkg_root, bundle_dir, jir_path) = located;
    if not os.path.isfile(jir_path) {
        return None;
    }
    if _sealed.image_for_bundle_dir(bundle_dir) is None {
        return None;
    }
    import from pathlib { Path as _Path }
    try {
        return (_Path(jir_path).read_bytes(), pkg_root);
    } except OSError {
        return None;
    }
}

impl JacCompiler._precompiled_jir_data(full_target: str) -> (tuple[bytes, str] | None) {
    sealed = self._sealed_jir_data(full_target);
    if sealed is not None {
        return sealed;
    }
    import from pathlib { Path as _Path }
    import from jaclang.compiler.driver.jir {
        bundle_dir_allowed,
        cache_mode,
        precompiled_jir_matches_source
    }
    (rebuild_flag, no_precompile) = cache_mode();
    if rebuild_flag or no_precompile {
        return None;
    }
    located = JacCompiler._precompiled_location(full_target);
    if located is None {
        return None;
    }
    (norm_file, pkg_root, bundle_dir, jir_path) = located;
    if not bundle_dir_allowed(bundle_dir) or not os.path.isfile(jir_path) {
        return None;
    }
    try {
        data = _Path(jir_path).read_bytes();
        if precompiled_jir_matches_source(data, norm_file, package_root=pkg_root) {
            return (data, pkg_root);
        }
    } except Exception {}
    return None;
}

impl JacCompiler._get_precompiled_jir_bytecode(
    full_target: str
) -> (tuple[bytes, bytes] | None) {
    (rebuild_flag, no_precompile) = cache_mode();
    if rebuild_flag or no_precompile {
        return None;
    }
    located = JacCompiler._precompiled_location(full_target);
    if located is None {
        return None;
    }
    (norm_file, pkg_root, bundle_dir, jir_path) = located;
    if not bundle_dir_allowed(bundle_dir) or not os.path.isfile(jir_path) {
        return None;
    }
    import from pathlib { Path as _Path }
    try {
        jir_data = _Path(jir_path).read_bytes();
        if _sealed.image_for_bundle_dir(bundle_dir) is None
            and not precompiled_jir_matches_source(
                jir_data, norm_file, package_root=pkg_root
            ) {
            return None;
        }
        bc = read_bytecode_only(jir_data);
        if bc is None {
            return None;
        }
        ct_raw = read_section_bytes(jir_data, SEC_CTDEPS);
        return (
            patch_co_filenames_bytes(bc, PRECOMPILE_SENTINEL, pkg_root),
            absolutize_ct_deps_section(ct_raw, pkg_root) if ct_raw else b""
        );
    } except Exception {
        return None;
    }
}

impl JacCompiler._restore_native_clibs(
    gen: CodeGenTarget, cached_interop: (dict[str, any] | None)
) -> None {
    if cached_interop is None or 'clib_paths' not in cached_interop {
        raise ValueError("Native cache lacks foreign-library metadata");
    }

    gen._clib_paths.extend(cached_interop['clib_paths']);
    gen._clib_symbol_lib.update(cached_interop.get('clib_symbol_lib', {}));
    gen._exported_symbols.extend(cached_interop.get('exported_symbols', []));
}

impl JacCompiler.compile(
    file_path: str,
    target_program: JacProgram,
    use_str: (str | None) = None,
    options: CompileOptions = CompileOptions()
) -> uni.Module {
    return compile_in_session(self, file_path, target_program, use_str, options);
}

impl JacCompiler.enter_compile(ctx: SessionContext) -> CompileFrame {
    target_program = ctx.target;
    if self._reentrant_depth == 0
        and not self.stub_catalog_disabled
        and not target_program.internal {
        self.ensure_stub_catalog();
    }
    frame = CompileFrame(depth_prev=self._reentrant_depth);
    self._reentrant_depth += 1;
    if frame.depth_prev == 0 {
        self._closure_opts = ctx.options;
    }
    if frame.depth_prev == 0 and not os.environ.get('JAC_GC_NO_COMPILE_BOOST') {
        import gc;
        gc_prev = gc.get_threshold();
        thresholds = CHECK_GC_THRESHOLDS
            if ctx.options.no_cgen or gc_prev == CHECK_GC_THRESHOLDS
            else COMPILE_GC_THRESHOLDS;
        if gc_prev[0] < thresholds[0] {
            frame.gc_prev = gc_prev;
            gc.set_threshold(*thresholds);
        }
    }
    frame.retain_selfhost = target_program.internal;
    if frame.retain_selfhost {
        self.selfhost.enter_execution();
    }
    return frame;
}

impl JacCompiler.leave_compile(ctx: SessionContext, frame: CompileFrame) {
    self._reentrant_depth = max(self._reentrant_depth - 1, 0);
    if self._reentrant_depth == 0 {
        self._closure_opts = None;
        if ctx.caller is not ctx.target {
            try {
                ctx.caller.release_check_caches();
            } except Exception {}
        }
    }
}

impl JacCompiler.finish_compile(frame: CompileFrame) {
    if frame.gc_prev is not None {
        import gc;
        gc.set_threshold(*frame.gc_prev);
    }
    if frame.retain_selfhost {
        self.selfhost.exit_execution();
    }
}

impl JacCompiler.check_crash(crash: Exception, file_path: str) {
    re_entered = import_error_re_enters(crash, file_path);
    if re_entered is not None {
        raise CompilerSourceError(
            f"compiling {file_path} re-entered it: a pass imported "
            f"'{re_entered}' while Python was still executing that "
            "module, so the name is not bound yet. A module a pass "
            "reaches at run time belongs in its product's loads (the "
            "PRODUCTS table in jaclang.compiler.driver.pipeline), which "
            "the loader pre-imports and which puts any compile nested in "
            "its import on the bootstrap tier."
        ) from crash;
    }
}

impl JacCompiler.closure_options -> (CompileOptions | None) {
    return self._closure_opts;
}

impl JacCompiler._persist_module_cache(
    full_target: str, result: uni.Module, actual_program: JacProgram
) -> None {
    try {
        _pmc_path = get_module_cache_path(full_target);
        if is_module_cache_valid(full_target, _pmc_path) {
            _pmc_data = read_jir(_pmc_path);
            _pmc_client_done = (
                not result.gen.js
                or read_section_bytes(_pmc_data, SEC_CLIENT) is not None
            );
            if read_section_bytes(_pmc_data, SEC_BYTECODE) is not None
                and _pmc_client_done {
                return;
            }
        }
    } except Exception {
        return;
    }
    cache_bc = result.gen.py_bytecode;
    if cache_bc is None or result.parse_failed {
        return;
    }
    try {
        sections = unit_sections(unit_products(result, actual_program), cache_bc);
        registry = actual_program.native_units();
        if registry.record_module(result, actual_program.options) is not None {
            sections.update(registry.product_sections(full_target));
        }
        write_module_cache(full_target, cache_bc, extra_sections=sections);
    } except Exception {}
}

impl JacCompiler._persist_native_unit(
    full_target: str, result: uni.Module, actual_program: JacProgram
) -> None {
    if actual_program.iface_registry().verifying {
        return;
    }
    if result is None or result.parse_failed or result.gen.native_iface is None {
        return;
    }
    try {
        registry = actual_program.native_units();
        registry.record_module(result, actual_program.options);
        sections = registry.product_sections(full_target);
        boundary = UnitProducts(
            path=full_target,
            interop=interop_json(result),
            placement=placement_record(result, actual_program)
        );
        sections.update(unit_sections(boundary, None));
        write_module_cache(full_target, None, extra_sections=sections);
    } except Exception as exc {
        import logging;
        logging.getLogger(__name__).warning(
            f"Could not persist native products for {full_target}: {exc}", exc_info=True
        );
    }
}

impl JacCompiler.run_module(
    file_path: str,
    target_program: JacProgram,
    use_str: (str | None),
    options: CompileOptions
) -> uni.Module {
    registry: any = None;
    iface_target = "";
    if use_str is None {
        iface_target = os.path.realpath(str(file_path));
        probe = target_program.iface_registry();
        if probe.eligible(self, iface_target, options) {
            served = probe.serve(self, iface_target, options);
            if served is not None {
                return served;
            }
            registry = probe;
        }
    }
    if registry is None {
        plain = compile_module(self, target_program, file_path, options, use_str);
        if use_str is None {
            self._persist_native_unit(iface_target, plain, target_program);
        }
        return plain;
    }
    err_start = len(target_program.errors_had);
    warn_start = len(target_program.warnings_had);
    registry.frame_push(iface_target);
    compiled: (uni.Module | None) = None;
    try {
        compiled = compile_module(self, target_program, file_path, options, use_str);
        try {
            registry.persist_after_compile(
                iface_target, compiled, options, err_start, warn_start
            );
        } except Exception {}
        self._persist_native_unit(iface_target, compiled, target_program);
    } finally {
        registry.frame_pop();
    }
    assert compiled is not None;
    return compiled;
}

impl JacCompiler._prepare_tool_program(
    source_str: str, file_path: str
) -> tuple[JacProgram, (uni.Module | None)] {
    prog = JacProgram();
    (current_mod, had_error) = parse_woven(
        source_str, file_path, prog=prog, annexes=[]
    );
    if had_error {
        prog.reset_module_root(uni.ProgramModule(main_mod=current_mod));
        return (prog, None);
    }

    return (prog, current_mod);
}

impl JacCompiler.jac_file_formatter(
    file_path: str, auto_lint: bool = False
) -> JacProgram {
    return JacCompiler.jac_str_formatter(
        read_file_with_encoding(file_path), file_path, auto_lint
    );
}

impl JacCompiler.jac_str_formatter(
    source_str: str, file_path: str, auto_lint: bool = False
) -> JacProgram {
    prog = JacCompiler._format_program(source_str, file_path, auto_lint);
    if not is_arch_file(file_path) or prog.errors_had or prog.mod.main is None {
        return prog;
    }
    canonical = canonical_wiring_source(source_str, file_path);
    if canonical != source_str {
        laid_out = JacCompiler._format_program(canonical, file_path, auto_lint);
        if not laid_out.errors_had and laid_out.mod.main is not None {
            prog.mod.main.gen.jac = laid_out.mod.main.gen.jac;
        }
    }
    return prog;
}

impl JacCompiler._format_program(
    source_str: str, file_path: str, auto_lint: bool
) -> JacProgram {
    (prog, current_mod) = JacCompiler._prepare_tool_program(source_str, file_path);
    if current_mod is None {
        return prog;
    }
    import from jaclang.compiler.driver.pipeline { execute_passes }
    passes = [CommentAttachPass, JacAutoLintPass, DocIRGenPass, JacFormatPass]
        if auto_lint
        else [CommentAttachPass, DocIRGenPass, JacFormatPass];
    execute_passes(prog, current_mod, passes, cancel_token=prog.options.cancel_token);
    prog.reset_module_root(uni.ProgramModule(main_mod=current_mod));
    return prog;
}

impl JacCompiler.jac_file_linter(file_path: str) -> JacProgram {
    source_str = read_file_with_encoding(file_path);
    (prog, current_mod) = JacCompiler._prepare_tool_program(source_str, file_path);
    if current_mod is None {
        return prog;
    }
    import from jaclang.compiler.driver.pipeline { execute_passes }
    execute_passes(
        prog, current_mod, [JacLintCheckPass], cancel_token=prog.options.cancel_token
    );
    prog.reset_module_root(uni.ProgramModule(main_mod=current_mod));
    return prog;
}

impl JacCompiler.client_codegen_target(
    full_target: str, target_program: JacProgram
) -> (uni.Module | None) {
    mod = target_program.find_module(full_target);
    if mod is None {
        return None;
    }
    if target_program.analysis.provides(mod, AnalysisFact.TYPE_OF) {
        return mod;
    }
    return None;
}

impl JacCompiler.ensure_client_codegen(
    mod: uni.Module, target_program: JacProgram
) -> bool {
    if mod.gen.js {
        return True;
    }
    import from jaclang.compiler.driver.pipeline { require }
    return require(target_program, mod, CompilationProduct.CLIENT);
}

impl JacCompiler.last_client_artifact(
    full_target: str, target_program: JacProgram
) -> (ClientArtifact | None) {
    actual = self.product_program(full_target, target_program);
    raw: (bytes | None) = None;
    with compilation_scope(owner_scope_options(actual)) {
        try {
            held = read_jir(get_module_cache_path(JacProgram.hub_key(full_target)));
            raw = read_section_bytes(held, SEC_CLIENT);
        } except Exception {
            return None;
        }
    }
    return client_artifact_from_bytes(raw) if raw is not None else None;
}

impl JacCompiler._client_deps_fresh(artifact: ClientArtifact) -> bool {
    for (dep, digest) in artifact.dep_digests.items() {
        try {
            if compute_content_sha256(dep) != digest {
                return False;
            }
        } except OSError {
            return False;
        }
    }
    return True;
}

impl JacCompiler._persist_client_artifact(
    full_target: str, artifact: ClientArtifact
) -> None {
    try {
        write_module_cache(
            full_target,
            None,
            extra_sections={SEC_CLIENT: client_artifact_bytes(artifact)}
        );
    } except Exception {}
}

impl JacCompiler.get_client_artifact(
    full_target: str, target_program: JacProgram
) -> (ClientArtifact | None) {
    actual = self.product_program(full_target, target_program);
    with compilation_scope(owner_scope_options(actual)) {
        return self._get_client_artifact(full_target, actual);
    }
}

impl JacCompiler._get_client_artifact(
    full_target: str, target_program: JacProgram
) -> (ClientArtifact | None) {
    full_target = JacProgram.hub_key(full_target);
    actual_program = self.selfhost.resolve(full_target, target_program);
    previous = actual_program.hub.client_artifacts.get(full_target);
    stored = cached_client_artifact(full_target) if previous is None else None;
    seen = previous if previous is not None else stored;
    if seen is not None and not JacCompiler._client_deps_fresh(seen) {
        actual_program.invalidate_module(full_target);
    }
    ready = self.client_codegen_target(full_target, actual_program);
    if ready is not None {
        if not self.ensure_client_codegen(ready, actual_program) {
            return None;
        }
        built = built_client_artifact(ready);
        if built is not None {
            actual_program.hub.client_artifacts[full_target] = built;
            self._persist_client_artifact(full_target, built);
        }
        return built;
    }

    has_live_tree = actual_program.find_module(full_target) is not None;
    held = actual_program.hub.client_artifacts.get(full_target)
        if not has_live_tree
        else None;
    if held is None and not has_live_tree {
        held = stored if previous is None else cached_client_artifact(full_target);
    }
    if held is not None {
        if client_artifact_current(held) {
            actual_program.hub.client_artifacts[full_target] = held;
            return held;
        }
        actual_program.hub.client_artifacts.pop(full_target, None);
    }
    mark = len(actual_program.errors_had);
    held_errors = len(actual_program.diags.owned_errors(full_target));
    compiled = self.compile(
        file_path=full_target,
        target_program=actual_program,
        options=CompileOptions(no_cgen=True)
    );
    if len(actual_program.errors_had) > mark {
        if len(actual_program.diags.owned_errors(full_target)) > held_errors {
            import from jaclang.compiler.driver.pipeline { mark_failed }
            mark_failed(actual_program, compiled, CompilationProduct.CLIENT);
        }
        return None;
    }
    if not self.ensure_client_codegen(compiled, actual_program) {
        return None;
    }
    built = built_client_artifact(compiled);
    if built is not None {
        actual_program.hub.client_artifacts[full_target] = built;
        self._persist_module_cache(full_target, compiled, actual_program);
        self._persist_client_artifact(full_target, built);
    }
    return built;
}

impl JacCompiler.release_compile_state(target_program: JacProgram) -> None {
    if os.environ.get("JAC_NO_UNIT_EVICT") {
        return;
    }
    owner = target_program.context_root or target_program;
    internal = self._selfhost.peek_program() if self._selfhost is not None else None;
    if self._reentrant_depth
        or owner.compile_depth
        or (internal is not None and internal.compile_depth) {
        raise RuntimeError("Cannot release compiler state during compilation");
    }
    owner.release_compile_closure(collect=False, retain_stubs=False);
    if internal is not None and internal is not owner {
        internal.release_compile_closure(collect=False, retain_stubs=False);
    }

    import gc;
    gc.collect();
}

impl client_dep_digests(manifest: ClientManifest) -> dict[str, str] {
    digests: dict[str, str] = {};
    for dep_path in manifest.imports.values() {
        dep = str(dep_path);
        if not os.path.isfile(dep) {
            continue;
        }
        try {
            digests[dep] = compute_content_sha256(dep);
        } except OSError {
            continue;
        }
    }
    return digests;
}

impl stamp_client_artifact(artifact: ClientArtifact) -> ClientArtifact {
    artifact.dep_digests = client_dep_digests(artifact.manifest);
    return artifact;
}

impl built_client_artifact(module: uni.Module) -> (ClientArtifact | None) {
    artifact = client_artifact_of(module);
    return stamp_client_artifact(artifact) if artifact is not None else None;
}

impl client_artifact_bytes(artifact: ClientArtifact) -> bytes {
    return client_artifact_json(artifact).encode("utf-8");
}

impl client_artifact_from_bytes(raw: bytes) -> (ClientArtifact | None) {
    try {
        text = raw.decode("utf-8");
    } except UnicodeDecodeError {
        return None;
    }
    return client_artifact_from_json(text);
}

impl cached_client_artifact(full_target: str) -> (ClientArtifact | None) {
    (rebuild, _no_precompile) = cache_mode();
    if rebuild {
        return None;
    }
    try {
        cache_path = get_module_cache_path(full_target);
        if not is_module_cache_valid(full_target, cache_path) {
            return None;
        }
        raw = read_section_bytes(read_jir(cache_path), SEC_CLIENT);
    } except Exception {
        return None;
    }
    if raw is None {
        return None;
    }
    return client_artifact_from_bytes(raw);
}

impl client_artifact_current(artifact: ClientArtifact) -> bool {
    return artifact.framework == resolve_active_backend().name()
        and JacCompiler._client_deps_fresh(artifact);
}

impl cached_client_pulls(full_target: str) -> str {
    held = cached_client_artifact(full_target);
    if held is None or not held.pulled or not client_artifact_current(held) {
        return "";
    }
    return ",".join([str(index) for index in held.pulled]);
}

impl unit_sections(
    products: UnitProducts, bytecode: (bytes | None)
) -> dict[int, bytes] {
    sections: dict[int, bytes] = {};
    if bytecode is not None {
        sections[SEC_BYTECODE] = bytecode;
    }
    if products.mtir {
        sections[SEC_MTIR] = products.mtir.encode("utf-8");
    }
    if products.interop {
        sections[SEC_INTEROP] = products.interop.encode("utf-8");
    }
    if products.client is not None {
        sections[SEC_CLIENT] = client_artifact_bytes(
            stamp_client_artifact(products.client)
        );
    }
    if products.placement {
        sections[SEC_PLACEMENT] = products.placement.encode("utf-8");
    }
    if products.ct_file_deps or products.ct_body_deps or products.ct_def_deps {
        seed_definition_texts(products.def_spans);
        sections[SEC_CTDEPS] = ct_deps_section(
            products.ct_file_deps,
            products.ct_body_deps,
            definitions=products.ct_def_deps
        );
    }
    return sections;
}
