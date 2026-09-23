import type from jaclang.runtime.native_library { SharedNativeEngine }
import from jaclang.compiler.driver.pipeline_runner { run_utility }
import from jaclang.compiler.driver.pipeline_types { UtilityProduct }
import from jaclang.compiler.driver.pipeline_types { AnalysisFact }
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
        import from jaclang.jac0core.stubcat_hook { env_disabled }
        if env_disabled() or self._stub_catalog_tried {
            return None;
        }
        self._stub_catalog_tried = True;
        import jaclang.compiler.types.stubcat.format;
        import jaclang.compiler.types.stubcat.reader;
        import from jaclang.compiler.types.stubcat.locate { ensure_catalog }
        found = ensure_catalog();
        self._stub_catalog = found;
    }

    internal = self._selfhost.peek_program() if self._selfhost is not None else None;
    if found is not None
        and internal is not None
        and not self._reentrant_depth
        and not internal.scratch.compile_depth
        and any(path.endswith('.pyi') for path in internal.mod.hub) {
        self.release_compile_state(internal);
    }
    return found;
}

impl JacCompiler.get_native_interop_setup(
    full_target: str, target_program: JacProgram
) -> tuple[((object | None), (dict[(str, object)] | None))] {
    import from jaclang.compiler.driver.compilation_context { program_for }
    actual_program = program_for(full_target, target_program);
    if (full_target in actual_program.hub.artifacts) {
        gen = actual_program.hub.artifacts[full_target];
        return (gen.native_engine, gen.interop_py_funcs);
    }
    if (full_target in actual_program.mod.hub) {
        mod = actual_program.mod.hub[full_target];
        native_engine = mod.gen.native_engine;
        interop_py_funcs = mod.gen.interop_py_funcs;
        return (native_engine, interop_py_funcs);
    }

    keyed = actual_program.find_module(full_target);
    if keyed is not None {
        return (keyed.gen.native_engine, keyed.gen.interop_py_funcs);
    }
    return (None, None);
}

impl JacCompiler.get_native_layout(
    full_target: str, target_program: JacProgram
) -> (NativeModuleLayout | None) {
    import from jaclang.compiler.driver.compilation_context { program_for }
    actual_program = program_for(full_target, target_program);
    _layout: NativeModuleLayout | None = None;
    if (full_target in actual_program.hub.artifacts) {
        gen = actual_program.hub.artifacts[full_target];
        _layout = gen.native_layout;
    } elif (full_target in actual_program.mod.hub) {
        mod = actual_program.mod.hub[full_target];
        _layout = mod.gen.native_layout;
    }
    if _layout is not None {
        JacCompiler._check_native_abi(_layout, full_target);
    }
    return _layout;
}

impl JacCompiler._check_native_abi(
    layout: NativeModuleLayout, full_target: str
) -> None {
    import from jaclang.compiler.frontend.codeinfo { NATIVE_ABI_VERSION }
    stamped = layout.abi_version;
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
    import from jaclang.compiler.driver.compilation_context {
        bind_options,
        context_program,
        compilation_scope
    }
    if full_target.endswith('.py') {
        import builtins;
        import from jaclang.project.source { read_file_with_encoding }
        return builtins.compile(
            read_file_with_encoding(full_target), full_target, 'exec'
        );
    }
    actual = self.selfhost.resolve(full_target, target_program, execution=True);
    if not actual.internal {
        options = bind_options(full_target, actual, actual.options);
        actual = context_program(actual, options);
    }
    import from jaclang.compiler.driver.compilation_context { owner_scope_options }
    with compilation_scope(owner_scope_options(actual)) {
        return self._get_bytecode(full_target, actual);
    }
}

impl JacCompiler._get_bytecode(
    full_target: str, target_program: JacProgram
) -> (types.CodeType | None) {
    actual_program = self.selfhost.resolve(full_target, target_program, execution=True);
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
        hit_mod = actual_program.mod.hub[full_target];
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
                full_target, actual_program, self._build_interop_dict(hit_mod)
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
            jir_data = cache_path.read_bytes();
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
                symtab_only_recovery = True;
            }
        } except Exception {}
    }

    allow_unsealed = (not rebuild) and (not no_precompile);
    precompiled = self._get_precompiled_jir_bytecode(full_target, allow_unsealed);
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

    is_internal = actual_program.internal;
    if is_internal {
        setup_progress.on_internal_compile(full_target);
        self.selfhost.enter_bytecode();
    }
    options = CompileOptions(
        skip_native_engine=not self._wants_native_engine(full_target, actual_program)
    );
    result: (uni.Module | None) = None;
    enclosing_closure = self._closure_opts;
    self._closure_opts = options;
    try {
        result = self.compile(
            file_path=full_target, target_program=actual_program, options=options
        );
        if result.gen.py_bytecode {
            actual_program.hub_cache_stamp(full_target);
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

impl JacCompiler._wants_native_engine(full_target: str, program: JacProgram) -> bool {
    import from jaclang.compiler.frontend.codeinfo { is_compiler_source_path }
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
    """Restore the owned native engine and its import metadata from cache.""";
    import from jaclang.compiler.frontend.codeinfo { CodeGenTarget }
    import type from jaclang.compiler.backends.native.llvm.binding { ExecutionEngine }
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
        manifest = self._deserialize_interop_table(cached_interop);
        gen.interop_manifest = manifest;
        import from jaclang.runtime.native_library { SharedNativeEngine }
        if manifest.native_imports and not isinstance(engine, SharedNativeEngine) {
            import from jaclang.runtime.interop_bridge { register_py_callbacks }
            import jaclang.compiler.backends.native.llvm.binding as llvm;
            register_py_callbacks(
                manifest.native_imports, py_func_table, callbacks_list, llvm.add_symbol
            );
        }
    }
    target_program.hub.artifacts[full_target] = gen;
}

impl JacCompiler._sealed_native_engine(
    full_target: str
) -> (SharedNativeEngine | None) {
    import from jaclang.jac0core { sealed as _sealed }
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
    import pickle;
    client_bytes = secs.get(SEC_CLIENT);
    if client_bytes is not None {
        import from jaclang.compiler.frontend.codeinfo { ClientArtifact }
        restored_client = ClientArtifact.from_bytes(client_bytes);
        if restored_client is not None {
            actual_program.hub.client_artifacts[full_target] = restored_client;
        }
    }
    mtir_bytes = secs.get(SEC_MTIR);
    if mtir_bytes is not None {
        try {
            mtir_map = pickle.loads(mtir_bytes);
            actual_program.mtir_map.update(mtir_map);
        } except Exception {}
    }

    placement_bytes = secs.get(SEC_PLACEMENT);
    if placement_bytes is not None {
        try {
            import from jaclang.compiler.placement.placement {
                summary_from_bytes,
                summary_store
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

impl JacCompiler._precompiled_jir_data(full_target: str) -> (tuple[bytes, str] | None) {
    """The unit a precompiled tree carries for this source, with the root its
    dependency rows are relative to: a sealed image is trusted by its
    manifest, and an unsealed bundle (a checkout seeded with the kit's
    precompile) only while the unit's key still matches the source.""";
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
    norm_file = os.path.normpath(os.path.abspath(full_target));
    d = os.path.dirname(norm_file);
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    while True {
        bundle_dir = os.path.join(d, '_precompiled');
        if os.path.isdir(bundle_dir) {
            if not bundle_dir_allowed(bundle_dir) {
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
            if not os.path.isfile(jir_path) {
                return None;
            }
            try {
                data = _Path(jir_path).read_bytes();
                if precompiled_jir_matches_source(
                    data, norm_file, package_root=norm_root
                ) {
                    return (data, norm_root);
                }
            } except Exception {}
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
) -> (tuple[bytes, bytes] | None) {
    import from pathlib { Path as _Path }
    import from jaclang.compiler.driver.jir {
        PRECOMPILE_SENTINEL,
        SEC_CTDEPS,
        absolutize_ct_deps_section,
        bundle_dir_allowed,
        cache_mode,
        precompile_required
    }
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
            if not bundle_dir_allowed(bundle_dir) {
                break;
            }
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
                served: (tuple[bytes, bytes] | None) = None;
                try {
                    jir_data = _Path(jir_path).read_bytes();
                    trusted = (
                        sealed_img is not None
                        or (
                            precompiled_jir_matches_source(
                                jir_data, norm_file, package_root=norm_root
                            )
                        )
                    );
                    if trusted {
                        bc = read_bytecode_only(jir_data);
                        if bc is not None {
                            _ct_raw = read_section_bytes(jir_data, SEC_CTDEPS);
                            served = (
                                patch_co_filenames_bytes(bc, PRECOMPILE_SENTINEL, d),
                                absolutize_ct_deps_section(_ct_raw, norm_root)
                                    if _ct_raw
                                    else b"",

                            );
                        }
                    }
                } except Exception {}
                if served is not None {
                    return served;
                }
                if precompile_required() {
                    raise RuntimeError(
                        f"JAC_PRECOMPILE_REQUIRED: {norm_file} has a bundled unit at "
                        f"{jir_path} that this compiler will not reuse, so it would be "
                        "recompiled from source. The bundle was built by a different "
                        "compiler generation, jaclang version, Python minor or runtime "
                        "variant than the one now running."
                    );
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

impl JacCompiler._build_interop_dict(result: uni.Module) -> dict[str, any] {
    manifest = result.gen.interop_manifest;
    if manifest is None {
        return {};
    }
    interop_data: dict[str, any] = {
        'bindings': {},
        'clib_paths': list(result.gen._clib_paths),
        'clib_symbol_lib': dict(result.gen._clib_symbol_lib),
        'exported_symbols': list(result.gen._exported_symbols)
    };
    for (name, binding) in manifest.bindings.items() {
        interop_data['bindings'][name] = {
            'name': binding.name,
            'source_context': binding.source_context.value,
            'callers': [c.value for c in binding.callers],
            'ret_type': binding.ret_type,
            'param_types': binding.param_types,
            'param_names': binding.param_names,
            'source_module': binding.source_module,
            'kind': binding.kind,
            'provider_app': binding.provider_app,
            'native_contract': binding.native_contract,
            'endpoint_id': binding.endpoint_id
        };
    }

    interop_data['surface'] = {
        name: rec.to_dict() for (name, rec) in manifest.surface.items()
    };
    interop_data['endpoint_effects'] = dict(manifest.endpoint_effects);
    interop_data['native_host_imports'] = dict(manifest.native_host_imports);
    interop_data['app_edges'] = list(manifest.app_edges);
    interop_data['provider_routes'] = dict(manifest.provider_routes);
    return interop_data;
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

impl JacCompiler._deserialize_interop_table(
    cached_interop: dict[str, any]
) -> InteropManifest {
    import from jaclang.compiler.frontend.codeinfo {
        InteropManifest,
        InteropBinding,
        InteropContext
    }
    manifest = InteropManifest();
    cached_bindings: dict[str, dict[str, any]] = cached_interop.get('bindings', {});
    for (name, data) in cached_bindings.items() {
        binding = InteropBinding(
            name=data['name'],
            source_context=InteropContext(data['source_context']),
            callers={InteropContext(c) for c in data.get('callers', [])},
            ret_type=data.get('ret_type', 'int'),
            param_types=data.get('param_types', []),
            param_names=data.get('param_names', []),
            source_module=data.get('source_module'),
            kind=data.get('kind', 'function'),
            provider_app=data['provider_app'],
            native_contract=data['native_contract'],
            endpoint_id=data['endpoint_id']
        );
        manifest.bindings[name] = binding;
    }
    import from jaclang.runtime.surface { SurfaceEntry }
    manifest.surface.update(
        {
            str(name): SurfaceEntry.from_dict(str(name), dict(rec))
            for (name, rec) in dict(cached_interop.get('surface', {}) or {}).items()
        }
    );
    manifest.endpoint_effects.update(cached_interop.get('endpoint_effects', {}));
    manifest.native_host_imports.update(cached_interop['native_host_imports']);
    manifest.app_edges.extend(cached_interop['app_edges']);
    manifest.provider_routes.update(cached_interop['provider_routes']);
    return manifest;
}

impl JacCompiler.compile(
    file_path: str,
    target_program: JacProgram,
    use_str: (str | None) = None,
    options: CompileOptions = CompileOptions()
) -> uni.Module {
    import from jaclang.compiler.driver.compilation_context {
        bind_options,
        context_program
    }
    caller_program = target_program;
    resolved_program = target_program;
    if not resolved_program.internal {
        options = bind_options(file_path, resolved_program, options);
        target_program = resolved_program
            if resolved_program._natives is not None
                and resolved_program._natives.session is not None
            else context_program(resolved_program, options);
    } else {
        target_program = resolved_program;
    }
    context_errors = len(target_program.errors_had);
    context_warnings = len(target_program.warnings_had);
    import from jaclang.compiler.driver.compilation_context {
        compilation_scope,
        owner_scope_options
    }
    owner_options = owner_scope_options(target_program, options);
    with compilation_scope(owner_options) {
        with compile_progress.track(str(file_path)) {
            if self._reentrant_depth == 0 and not self.stub_catalog_disabled {
                if not target_program.internal {
                    import from jaclang.compiler.types.stubcat.locate {
                        StubCatalogUnavailable
                    }
                    try {
                        self.ensure_stub_catalog();
                    } except StubCatalogUnavailable {}
                }
            }
            import from pathlib { Path as _WrapPath }
            import from jaclang.compiler.frontend.codeinfo {
                get_effective_default_codespace_override,
                set_effective_default_codespace
            }
            _prev_cs = get_effective_default_codespace_override();
            _depth_prev = self._reentrant_depth;
            self._reentrant_depth = _depth_prev + 1;
            if _depth_prev == 0 {
                self._closure_opts = options;
            }
            _gc_prev: (tuple[int, int, int] | None) = None;
            if _depth_prev == 0 and not os.environ.get('JAC_GC_NO_COMPILE_BOOST') {
                import gc;
                _gc_prev = gc.get_threshold();
                thresholds = CHECK_GC_THRESHOLDS
                    if options.no_cgen or _gc_prev == CHECK_GC_THRESHOLDS
                    else COMPILE_GC_THRESHOLDS;
                if _gc_prev[0] >= thresholds[0] {
                    _gc_prev = None;
                } else {
                    gc.set_threshold(*thresholds);
                }
            }
            _outer_opts: (CompileOptions | None) = None;
            _outer_prog: (JacProgram | None) = None;
            _scratch_prog: (JacProgram | None) = None;
            import from jaclang.compiler.frontend.codeinfo {
                set_native_unit_compile,
                reset_native_unit_compile
            }
            native_token = set_native_unit_compile(bool(options.native_unit));
            retain_selfhost = target_program.internal;
            if retain_selfhost {
                self.selfhost.enter_execution();
            }
            try {
                _wrap_prog = target_program;

                _scratch_prog = _wrap_prog;
                _wrap_prog.scratch.compile_depth += 1;
                if _depth_prev > 0 {
                    _outer_prog = _wrap_prog;
                    _outer_opts = _wrap_prog.options;
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
                            "module, so the name is not bound yet. A module a pass "
                            "reaches at run time belongs in the schedule's dependency "
                            "list (IR_SCHED_DEPS in jaclang.compiler.driver.pipeline), "
                            "which the loader pre-imports and which puts any compile "
                            "nested in its import on the bootstrap tier."
                        ) from _crash;
                    }
                }
                _resolved = os.path.realpath(file_path);
                _probe = _mod
                    if _mod is not None
                    else _wrap_prog.mod.hub.get(_resolved);
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
                    assert _mod is not None;
                    return _mod;
                }

                _is_ice = _crash is not None
                    and len(_wrap_prog.errors_had) == _pre_errs;
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
                _wrap_prog.native_units().record_verdict(
                    _resolved, _demote_code, _first_err
                );
                del _wrap_prog.errors_had[_pre_errs:];
                del _wrap_prog.warnings_had[_pre_warns:];
                try {
                    _wrap_prog.invalidate_module(_resolved);
                } except Exception {}
                try {
                    import from jaclang.compiler.placement.placement_solver {
                        invalidate_importers_es
                    }
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
                    (_note_msg, _note_style) = na_demotion_note(
                        file_path, _first_err, _is_ice
                    );
                    _note_console.print(_note_msg, style=_note_style, file=sys.stderr);
                } except Exception {}
                return self._compile_once(
                    file_path=file_path,
                    target_program=target_program,
                    use_str=use_str,
                    options=options
                );
            } finally {
                if target_program is not caller_program
                    and not target_program.internal {
                    caller_program.errors_had.extend(
                        target_program.errors_had[context_errors:]
                    );
                    caller_program.warnings_had.extend(
                        target_program.warnings_had[context_warnings:]
                    );
                }
                reset_native_unit_compile(native_token);
                set_effective_default_codespace(_prev_cs);
                self._reentrant_depth = _depth_prev;
                if _depth_prev == 0 {
                    self._closure_opts = None;
                    if caller_program is not target_program {
                        self._release_compile_scratch(caller_program);
                    }
                }
                if _outer_prog is not None and _outer_opts is not None {
                    _outer_prog.options = _outer_opts;
                }
                if _scratch_prog is not None {
                    _scratch_prog.scratch.compile_depth -= 1;
                    if _scratch_prog.scratch.compile_depth <= 0 {
                        _scratch_prog.scratch.compile_depth = 0;
                        self._release_compile_scratch(_scratch_prog);
                    }
                }
                if _gc_prev is not None {
                    import gc;
                    gc.set_threshold(*_gc_prev);
                }
                if retain_selfhost {
                    self.selfhost.exit_execution();
                }
            }
        }
    }
}

impl JacCompiler._persist_module_cache(
    full_target: str, result: uni.Module, actual_program: JacProgram
) -> None {
    import from jaclang.compiler.driver.jir {
        get_module_cache_path,
        is_module_cache_valid
    }
    try {
        _pmc_path = get_module_cache_path(full_target);
        if is_module_cache_valid(full_target, _pmc_path) {
            _pmc_data = _pmc_path.read_bytes();
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
        import pickle;
        import json;
        import zlib;
        sections: dict[int, bytes] = {};
        sections[SEC_BYTECODE] = cache_bc;
        if actual_program.mtir_map {
            sections[SEC_MTIR] = pickle.dumps(
                actual_program.mtir_map, int(pickle.HIGHEST_PROTOCOL)
            );
        }

        registry = actual_program.native_units();
        if registry.record_module(result, actual_program.options) is not None {
            sections.update(registry.product_sections(full_target));
        }
        interop_dict = self._build_interop_dict(result);
        if interop_dict {
            sections[SEC_INTEROP] = json.dumps(interop_dict).encode('utf-8');
        }
        client_artifact = self.client_artifact_of(result);
        if client_artifact is not None {
            try {
                sections[SEC_CLIENT] = client_artifact.to_bytes();
            } except Exception {}
        }
        try {
            import from jaclang.compiler.placement.placement {
                get_module_summary,
                summary_to_bytes
            }
            sections[SEC_PLACEMENT] = summary_to_bytes(
                get_module_summary(result, actual_program)
            );
        } except Exception {}
        import from jaclang.compiler.driver.jir {
            SEC_CTDEPS,
            ct_deps_section,
            write_module_cache
        }
        if result.ct_file_deps {
            sections[SEC_CTDEPS] = ct_deps_section(
                result.ct_file_deps, result.ct_body_deps
            );
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
        interop_dict = self._build_interop_dict(result);
        if interop_dict {
            import json;
            sections[SEC_INTEROP] = json.dumps(interop_dict).encode('utf-8');
        }
        try {
            import from jaclang.compiler.placement.placement {
                get_module_summary,
                summary_to_bytes
            }
            sections[SEC_PLACEMENT] = summary_to_bytes(
                get_module_summary(result, actual_program)
            );
        } except Exception {}
        write_module_cache(full_target, None, extra_sections=sections);
    } except Exception as exc {
        import logging;
        logging.getLogger(__name__).warning(
            f"Could not persist native products for {full_target}: {exc}", exc_info=True
        );
    }
}

impl JacCompiler._release_compile_scratch(target_program: JacProgram) -> None {
    try {
        target_program.release_check_caches();
    } except Exception {}
}

impl JacCompiler._compile_once(
    file_path: str,
    target_program: JacProgram,
    use_str: (str | None) = None,
    options: CompileOptions = CompileOptions()
) -> uni.Module {
    if use_str is not None and not options.no_ir_cache {
        import copy;
        options = copy.copy(options);
        options.no_ir_cache = True;
    }
    import from jaclang.jac0core.ext_registry { is_annex }
    if (use_str is None and options.resolve_annex_parent and is_annex(file_path)) {
        import from jaclang.compiler.driver.bccache { discover_base_file }
        base_path = discover_base_file(file_path);
        if (base_path and base_path not in target_program.mod.hub) {
            return self.compile(
                file_path=base_path, target_program=target_program, options=options
            );
        }
    }
    actual_program = target_program;

    _prev_opts = actual_program.options;
    if _prev_opts is not None
        and not (options.nogc_enforce_all or options.memory_enforce) {
        options.nogc_enforce_all = _prev_opts.nogc_enforce_all;
        options.memory_enforce = _prev_opts.memory_enforce;
        options.memory_exempt = _prev_opts.memory_exempt;
    }
    if _prev_opts is not None and not options.default_codespace {
        options.default_codespace = _prev_opts.default_codespace;
    }
    _closure = self._closure_opts;
    if _closure is not None and _closure is not options and _closure.need_full_ast {
        options.need_full_ast = True;
    }
    actual_program.options = options;
    if options.default_codespace {
        import from jaclang.compiler.frontend.codeinfo {
            set_effective_default_codespace
        }
        set_effective_default_codespace(options.default_codespace);
    }

    _iface_reg: any = None;
    _iface_target = "";
    if use_str is None {
        _iface_target = os.path.realpath(str(file_path));
        _reg_probe = actual_program.iface_registry();
        if _reg_probe.eligible(self, _iface_target, options) {
            _served = _reg_probe.serve(self, _iface_target, options);
            if _served is not None {
                return _served;
            }
            _iface_reg = _reg_probe;
        }
    }
    if _iface_reg is None {
        _plain = self._compile_pipeline(file_path, actual_program, use_str, options);
        if use_str is None {
            self._persist_native_unit(_iface_target, _plain, actual_program);
        }
        return _plain;
    }
    _err_start = len(actual_program.errors_had);
    _warn_start = len(actual_program.warnings_had);
    _iface_reg.frame_push(_iface_target);
    _mod_out: (uni.Module | None) = None;
    try {
        _mod_out = self._compile_pipeline(file_path, actual_program, use_str, options);
        try {
            _iface_reg.persist_after_compile(
                _iface_target, _mod_out, options, _err_start, _warn_start
            );
        } except Exception {}
        self._persist_native_unit(_iface_target, _mod_out, actual_program);
    } finally {
        _iface_reg.frame_pop();
    }
    assert _mod_out is not None;
    return _mod_out;
}

impl JacCompiler._compile_pipeline(
    file_path: str,
    actual_program: JacProgram,
    use_str: (str | None) = None,
    options: CompileOptions = CompileOptions()
) -> uni.Module {
    import from jaclang.compiler.driver.pipeline_runner { compile_module }
    return compile_module(self, actual_program, file_path, options, use_str);
}

impl JacCompiler.build(
    file_path: str, target_program: JacProgram, use_str: (str | None) = None
) -> uni.Module {
    actual_program = target_program;
    mod_targ = self.compile(
        file_path, actual_program, use_str, options=CompileOptions()
    );
    return mod_targ;
}

impl JacCompiler._prepare_tool_program(
    source_str: str, file_path: str
) -> tuple[JacProgram, (uni.Module | None)] {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.frontend.parser { parse as rd_parse }
    prog = JacProgram();
    (current_mod, had_error) = rd_parse(source_str, file_path, prog=prog);
    if had_error {
        prog.reset_module_root(uni.ProgramModule(main_mod=current_mod));
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
    import from jaclang.compiler.driver.pipeline { execute_passes }
    current_mod = execute_passes(
        prog, current_mod, get_format_sched(auto_lint=auto_lint)
    );
    prog.reset_module_root(uni.ProgramModule(main_mod=current_mod));
    return prog;
}

impl JacCompiler.jac_str_formatter(
    source_str: str, file_path: str, auto_lint: bool = False
) -> JacProgram {
    (prog, current_mod) = JacCompiler._prepare_tool_program(source_str, file_path);
    if current_mod is None {
        return prog;
    }
    import from jaclang.compiler.driver.pipeline { execute_passes }
    current_mod = execute_passes(
        prog, current_mod, get_format_sched(auto_lint=auto_lint)
    );
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
    current_mod = execute_passes(prog, current_mod, get_lint_sched());
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
    if target_program.analysis.analyses_run.provides(mod, AnalysisFact.TYPE_OF) {
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
    import from jaclang.compiler.driver.pipeline { require_product, CompilationProduct }
    return require_product(target_program, mod, CompilationProduct.CLIENT);
}

impl JacCompiler.client_artifact_of(mod: uni.Module) -> (ClientArtifact | None) {
    import from jaclang.compiler.frontend.codeinfo { ClientArtifact }
    js = mod.gen.js;
    if not js {
        return None;
    }
    native_sources: list[str] = [];
    if mod.declares_codespace(CodeContext.NATIVE) {
        native_sources.append(mod.loc.mod_path);
    }
    for binding in mod.gen.interop_manifest.client_native_imports {
        if binding.source_module {
            native_sources.append(str(binding.source_module));
        }
    }
    segments: list[tuple[int, int, int, int, str]] = [];
    import from jaclang.compiler.backends.es.estree { Node as EsNode }
    es_ast = mod.gen.es_ast;
    if isinstance(es_ast, EsNode) {
        try {
            import from jaclang.compiler.backends.es.es_unparse { es_to_js_with_map }
            (_, segments) = es_to_js_with_map(es_ast);
        } except Exception {
            segments = [];
        }
    }
    manifest = mod.gen.client_manifest;
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
    import from jaclang.compiler.backends.es.backends.registry {
        resolve_active_backend
    }
    return ClientArtifact(
        js=js,
        manifest=manifest,
        native_import_sources=native_sources,
        source_map=segments,
        dep_digests=digests,
        boundary_contracts=self._build_interop_dict(mod),
        framework=resolve_active_backend().name()
    );
}

impl JacCompiler._cached_client_artifact(full_target: str) -> (ClientArtifact | None) {
    import from jaclang.compiler.frontend.codeinfo { ClientArtifact }
    (rebuild, _no_precompile) = cache_mode();
    if rebuild {
        return None;
    }
    try {
        cache_path = get_module_cache_path(full_target);
        if not is_module_cache_valid(full_target, cache_path) {
            return None;
        }
        raw = read_section_bytes(cache_path.read_bytes(), SEC_CLIENT);
    } except Exception {
        return None;
    }
    if raw is None {
        return None;
    }
    return ClientArtifact.from_bytes(raw);
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
            full_target, None, extra_sections={SEC_CLIENT: artifact.to_bytes()}
        );
    } except Exception {}
}

impl JacCompiler.get_client_artifact(
    full_target: str, target_program: JacProgram
) -> (ClientArtifact | None) {
    import from jaclang.compiler.driver.compilation_context {
        bind_options,
        context_program,
        compilation_scope
    }
    actual = self.selfhost.resolve(full_target, target_program);
    if not actual.internal {
        options = bind_options(full_target, actual, actual.options);
        actual = context_program(actual, options);
    }
    import from jaclang.compiler.driver.compilation_context { owner_scope_options }
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
    if previous is None {
        previous = self._cached_client_artifact(full_target);
    }
    if previous is not None and not JacCompiler._client_deps_fresh(previous) {
        actual_program.invalidate_module(full_target);
    }
    ready = self.client_codegen_target(full_target, actual_program);
    if ready is not None {
        if not self.ensure_client_codegen(ready, actual_program) {
            return None;
        }
        built = self.client_artifact_of(ready);
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
        held = self._cached_client_artifact(full_target);
    }
    if held is not None {
        import from jaclang.compiler.backends.es.backends.registry {
            resolve_active_backend
        }
        if (
            held.framework == resolve_active_backend().name()
            and JacCompiler._client_deps_fresh(held)
        ) {
            actual_program.hub.client_artifacts[full_target] = held;
            return held;
        }
        actual_program.hub.client_artifacts.pop(full_target, None);
    }
    mark = len(actual_program.errors_had);
    compiled = self.compile(
        file_path=full_target,
        target_program=actual_program,
        options=CompileOptions(no_cgen=True)
    );
    if len(actual_program.errors_had) > mark {
        return None;
    }
    if not self.ensure_client_codegen(compiled, actual_program) {
        return None;
    }
    built = self.client_artifact_of(compiled);
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
        or owner.scratch.compile_depth
        or (internal is not None and internal.scratch.compile_depth) {
        raise RuntimeError("Cannot release compiler state during compilation");
    }
    owner.release_compile_closure(collect=False, retain_stubs=False);
    if internal is not None and internal is not owner {
        internal.release_compile_closure(collect=False, retain_stubs=False);
    }

    import gc;
    gc.collect();
}
