impl JacCompiler.selfhost.getter -> SelfHostCache {
    cache = self._selfhost;
    if (cache is None) {
        import from jaclang.runtime.runtime { JacRuntime }
        cache = JacRuntime.get_selfhost();
        self._selfhost = cache;
    }
    return cache;
}

impl JacCompiler.stub_catalog -> any {
    if self.stub_catalog_disabled or self._stub_trees_served {
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

impl JacCompiler.note_stub_tree_served(path: str, program: JacProgram) -> None {
    if self._stub_trees_served or self.selfhost.is_selfhost(program) {
        return;
    }
    if self.stub_catalog() is not None {
        return;
    }
    import from jaclang.compiler.driver.modresolver { _in_typeshed_tree }
    if _in_typeshed_tree(path) {
        self._stub_trees_served = True;
    }
}

impl JacCompiler.ensure_stub_catalog -> any {
    if self.stub_catalog_disabled or self._stub_trees_served {
        return None;
    }
    found = self.stub_catalog();
    if found is not None {
        return found;
    }
    import from jaclang.jac0core.stubcat_hook { env_disabled }
    if env_disabled() {
        return None;
    }
    if self._stub_catalog_tried {
        return None;
    }
    self._stub_catalog_tried = True;
    import jaclang.compiler.types.stubcat.format;
    import jaclang.compiler.types.stubcat.reader;
    import from jaclang.compiler.types.stubcat.locate { ensure_catalog }
    found = ensure_catalog();
    self._stub_catalog = found;
    return found;
}

impl JacCompiler.get_native_interop_setup(
    full_target: str, target_program: JacProgram
) -> tuple[((object | None), (dict[(str, object)] | None))] {
    actual_program = self.selfhost.resolve(full_target, target_program);
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
) -> (object | None) {
    actual_program = self.selfhost.resolve(full_target, target_program);
    _layout: any = None;
    if (full_target in actual_program.hub.artifacts) {
        gen = actual_program.hub.artifacts[full_target];
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
    import from jaclang.compiler.frontend.codeinfo { NATIVE_ABI_VERSION }
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
    actual_program = self.selfhost.resolve(full_target, target_program);
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
        if isinstance(codeobj, `bytes)
            and not self.selfhost.is_selfhost(actual_program) {
            self._persist_module_cache(full_target, hit_mod, actual_program);
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
                    and not self.selfhost.is_selfhost(actual_program)
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
                if SEC_IFACE not in secs and SEC_CLIENT not in secs {
                    cache_path.unlink(missing_ok=True);
                }
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

    is_internal = self.selfhost.is_selfhost(actual_program);
    if is_internal {
        setup_progress.on_internal_compile(full_target);
        self.selfhost.enter_bytecode();
    }
    options = CompileOptions();
    result: (uni.Module | None) = None;
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
                full_target, module_scoped_failure_details(full_target, actual_program)
            );
        }
        return None;
    } finally {
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

"""Rebuild the in-process engine of a native module from its cache.

The module's own bitcode is one unit of a closure, so the engine comes from
the link plan in bitcode mode, rooted at the module, exactly as a fresh
compile would build it. A sealed app with a linked artifact gets a
`SharedNativeEngine` over that artifact instead.
"""
impl JacCompiler._load_native_from_cache(
    full_target: str,
    target_program: JacProgram,
    cached_interop: (dict[str, any] | None)
) -> None {
    import from jaclang.compiler.frontend.codeinfo { CodeGenTarget }
    engine = self._sealed_native_engine(full_target);
    if engine is None {
        import from jaclang.compiler.backends.native.link_plan {
            jit_engine_for_cached
        }
        engine = jit_engine_for_cached(
            target_program, full_target, target_program.options or CompileOptions()
        );
    }
    if engine is None {
        return;
    }
    gen = CodeGenTarget();
    gen.native_engine = engine;
    py_func_table: dict = {};
    callbacks_list: list = [];
    gen.interop_py_funcs = py_func_table;
    gen._interop_callbacks = callbacks_list;
    if cached_interop {
        manifest = self._deserialize_interop_table(cached_interop);
        gen.interop_manifest = manifest;
        import from jaclang.runtime.native_library { SharedNativeEngine }
        if manifest.native_imports and not isinstance(engine, SharedNativeEngine) {
            import from jaclang.runtime.interop_bridge { register_py_callbacks }
            register_py_callbacks(manifest, py_func_table, callbacks_list);
        }
    }
    target_program.hub.artifacts[full_target] = gen;
}

"""The engine over a sealed app's linked native artifact, when the module
belongs to an image that carries one."""
impl JacCompiler._sealed_native_engine(full_target: str) -> (object | None) {
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
    full_target: str, actual_program: JacProgram, secs: dict[int, bytes]
) -> None {
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
            restored = summary_from_bytes(placement_bytes);
            if restored is not None {
                summary_store(actual_program)[os.path.abspath(full_target)] = restored;
            }
        } except Exception {}
    }

    if SEC_NBITCODE in secs or SEC_NOBJ in secs {
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
) -> (tuple[bytes, bytes] | None) {
    import from pathlib { Path as _Path }
    import from jaclang.compiler.driver.jir {
        PRECOMPILE_SENTINEL,
        SEC_CTDEPS,
        absolutize_ct_deps_section,
        cache_mode,
        ct_deps_fresh
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
                        or (
                            precompiled_jir_matches_source(jir_data, norm_file)
                            and ct_deps_fresh(jir_data, norm_root)
                        )
                    );
                    if trusted {
                        bc = read_bytecode_only(jir_data);
                        if bc is not None {
                            _ct_raw = read_section_bytes(jir_data, SEC_CTDEPS);
                            return (
                                patch_co_filenames_bytes(bc, PRECOMPILE_SENTINEL, d),
                                absolutize_ct_deps_section(_ct_raw, norm_root)
                                    if _ct_raw
                                    else b"",

                            );
                        }
                    }
                } except Exception {}
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
    import from jaclang.compiler.frontend.codeinfo {
        InteropManifest,
        InteropBinding,
        InteropContext
    }
    manifest = InteropManifest();
    cached_bindings: dict[str, dict[str, any]] = cached_interop.get('bindings', {});
    for (name, data) in cached_bindings.items() {
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
    cancel_token: (Event | None) = None
) -> uni.Module {
    had_error = False;
    run_codespace_infer = False;
    if (file_path.endswith('.py') or file_path.endswith('.pyi')) {
        import from jaclang.compiler.passes.pyast_load_pass { PyastBuildPass }
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
        import from jaclang.compiler.frontend.parser.frontend {
            annex_sources,
            parse_woven
        }
        codespace = '';
        import from jaclang.compiler.frontend.codeinfo {
            is_client_by_location as _cbl
        }
        import from jaclang.compiler.placement.placement_facts {
            native_only as _native_only,
            native_unit as _native_unit
        }
        _p_opts0 = target_program.options;
        _native_unit_on = bool(_p_opts0 is not None and _p_opts0.native_unit);
        if _native_only(file_path) {
            codespace = 'native';
        }
        if not codespace and _cbl(file_path) {
            codespace = 'client';
        }
        if not codespace {
            import from jaclang.compiler.placement.placement_pins {
                effective_module_pin as _mod_pin
            }
            _pinned_space = _mod_pin(file_path, target_program);
            if _pinned_space in ('client', 'native') {
                codespace = _pinned_space;
            }
        }
        if not codespace and _native_unit(file_path, _native_unit_on) {
            codespace = 'native';
        }
        if not codespace {
            _p_opts = target_program.options;
            _forced_pre = _p_opts.force_codespace if _p_opts is not None else '';
            if (
                not _forced_pre
                and _p_opts is not None
                and _p_opts.aot_mode
                and not self.selfhost.is_selfhost(target_program)
                and _default_codespace_for(target_program) == 'native'
            ) {
                _forced_pre = 'native';
            }
            if _forced_pre and not self.selfhost.is_selfhost(target_program) {
                codespace = _forced_pre;
            }
        }
        if not codespace and not self.selfhost.is_selfhost(target_program) {
            import from jaclang.compiler.placement.placement_pins {
                config_kind_space as _kind_space_of
            }
            _kind_space = _kind_space_of(file_path);
            if _kind_space in ('client', 'native') {
                codespace = _kind_space;
            }
        }
        (mod, had_error) = parse_woven(
            source_str, file_path, target_program, annex_sources(file_path)
        );
        if (codespace == 'client') {
            _coerce_client_module(mod);
        } elif (codespace == 'native') {
            _coerce_native_module(mod);
            na_coverage_record(mod.loc.mod_path, 'native');
        } else {
            run_codespace_infer = True;
        }
    }
    hub_key = target_program.hub_key(mod.loc.mod_path);
    if had_error {
        mod.parse_failed = True;
        target_program.install_module(hub_key, mod);
        return mod;
    }
    if target_program.mod.main.stub_only {
        old_hub = target_program.mod.hub;
        target_program.reset_module_root(uni.ProgramModule(main_mod=mod));

        target_program.mod.hub.clear();
        target_program.mod.hub.update(old_hub);
    }
    target_program.install_module(hub_key, mod);

    if run_codespace_infer {
        _opts = target_program.options;
        _analysis_only = _opts is not None and _opts.no_cgen;
        _native_unit_opt = bool(_opts is not None and _opts.native_unit);
        import from jaclang.compiler.native_scope { in_native_scope_path }
        _scope_native = (
            _native_unit_opt and in_native_scope_path(mod.loc.mod_path or '')
        );
        _native_eligible = (
            not _analysis_only
            and (
                _scope_native
                or (
                    not self.selfhost.is_selfhost(target_program)
                    and _default_codespace_for(target_program) == 'native'
                )
            )
        );
        if _native_eligible {
            import from jaclang.compiler.placement.placement_solver {
                native_default_verdict
            }
            (_na_ok, _na_why) = native_default_verdict(
                mod, target_program, _native_unit_opt
            );
            if _na_ok {
                _coerce_native_module(mod);
                mod.codespace_inferred = True;
                na_coverage_record(mod.loc.mod_path, 'native');
            } elif _na_why == 'previously-demoted' {
                import from jaclang.compiler.placement.placement_pins {
                    native_demotion_code
                }
                na_coverage_record(
                    mod.loc.mod_path,
                    'demoted',
                    native_demotion_code(
                        os.path.realpath(mod.loc.mod_path), target_program
                    ),
                    _na_why
                );
            } else {
                na_coverage_record(mod.loc.mod_path, 'server', '', _na_why);
            }
        }
    }
    return mod;
}

impl JacCompiler.resolve_absorb_imports(
    mod: uni.Module, target_program: JacProgram
) -> None {
    import from jaclang.compiler.frontend.unitree { find_python_scope_node_of }
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
        } elif resolved.endswith('.pyi') {
            try {
                module = target_program.load_dependency_module(
                    resolved, importer_path=mod.loc.mod_path
                );
            } except Exception {
                module = None;
            }
        } else {
            try {
                module = target_program.compile(resolved, no_cgen=True);
            } except Exception {
                module = None;
            }
        }
        imp.absorbed_mod = module;
    }
}

impl JacCompiler.stamp_access_check_facts(mod: uni.Module) -> None {
    import from jaclang.compiler.driver.modresolver { find_jac_project_root }
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
    opts = target_program.options;
    mod_path = mod.loc.mod_path if mod.loc else '';
    (kind, proj_root) = resolve_client_kind_context(
        mod_path, opts.project_kind, opts.project_root
    );
    mod.mobui_enforced_root = proj_root if kind == 'mobui' else None;
}

impl JacCompiler.stamp_boundary_facts(
    mod: uni.Module, target_program: JacProgram
) -> None {
    import from jaclang.compiler.frontend.codeinfo {
        is_bundled_native_module,
        resolve_native_module
    }
    import from jaclang.compiler.placement.placement_pins { config_module_pin }

    base_dir = '.';
    if mod.loc {
        base_dir = os.path.dirname(mod.loc.mod_path);
    }
    _sb_opts = target_program.options;
    in_native_mod = mod.loc is not None
        and (
            mod.decided_codespace == 'native'
            or (
                _sb_opts is not None
                and _sb_opts.aot_mode
                and not self.selfhost.is_selfhost(target_program)
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
        memo = target_program.scratch.boundary_parse_memo;
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
        } except Exception {}
        try {
            collect_pub_walkers(src, walkers);
        } except Exception {}
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
    compile_progress.notify(str(file_path));
    if self._reentrant_depth == 0 and not self.stub_catalog_disabled {
        if not self.selfhost.is_selfhost(target_program) {
            import from jaclang.compiler.types.stubcat.locate { StubCatalogUnavailable }
            try {
                self.ensure_stub_catalog();
            } except StubCatalogUnavailable {}
        }
    }
    import from pathlib { Path as _WrapPath }
    import from jaclang.compiler.frontend.codeinfo {
        get_effective_default_codespace_override,
        set_effective_default_codespace,
        set_native_unit_compile,
        reset_native_unit_compile
    }
    _prev_cs = get_effective_default_codespace_override();
    _native_unit_token = set_native_unit_compile(bool(options.native_unit));
    _depth_prev = self._reentrant_depth;
    self._reentrant_depth = _depth_prev + 1;
    if _depth_prev == 0 {
        self._closure_opts = options;
    }
    _gc_prev: (tuple | None) = None;
    if _depth_prev == 0 and not os.environ.get('JAC_GC_NO_COMPILE_BOOST') {
        import gc;
        _gc_prev = gc.get_threshold();
        if _gc_prev[0] >= COMPILE_GC_THRESHOLDS[0] {
            _gc_prev = None;
        } else {
            gc.set_threshold(*COMPILE_GC_THRESHOLDS);
        }
    }
    _outer_opts: (CompileOptions | None) = None;
    _outer_prog: (JacProgram | None) = None;
    _scratch_prog: (JacProgram | None) = None;

    try {
        if options.force_target_program {
            _wrap_prog = target_program;
        } else {
            _wrap_prog = self.selfhost.resolve(
                file_path, target_program, native_unit=options.native_unit
            );
        }

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
            assert _mod is not None;
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
        _wrap_prog.native_units().record_verdict(_resolved, _demote_code, _first_err);
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
            (_note_msg, _note_style) = na_demotion_note(file_path, _first_err, _is_ice);
            _note_console.print(_note_msg, style=_note_style, file=sys.stderr);
        } except Exception {}
        return self._compile_once(
            file_path=file_path,
            target_program=target_program,
            use_str=use_str,
            options=options
        );
    } finally {
        reset_native_unit_compile(_native_unit_token);
        set_effective_default_codespace(_prev_cs);
        self._reentrant_depth = _depth_prev;
        if _depth_prev == 0 {
            self._closure_opts = None;
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

        sections.update(self._native_sections(full_target, result, actual_program));
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

"""The native sections of a unit, each under the stamp of the compile that
produced it, plus the dependency rows carrying the native digests it was
compiled against."""
impl JacCompiler._native_sections(
    full_target: str, result: uni.Module, actual_program: JacProgram
) -> dict[int, bytes] {
    sections: dict[int, bytes] = {};
    gen = result.gen;
    if gen.native_iface is None {
        return sections;
    }
    import from jaclang.compiler.driver.jir { SEC_DEPS, deps_section }
    registry = actual_program.native_units();
    stamp = registry.stamp_for(actual_program.options);
    sections[SEC_NIFACE] = stamp.pack(gen.native_iface.to_bytes());
    if gen.native_object is not None {
        sections[SEC_NOBJ] = stamp.pack(gen.native_object);
    }
    if gen.native_bitcode is not None {
        sections[SEC_NBITCODE] = stamp.pack(gen.native_bitcode);
    }
    dep_digests = registry.dep_digests(list(gen.native_deps or []));
    registry.record(full_target, gen.native_iface, actual_program.options, dep_digests);
    sections[SEC_DEPS] = deps_section(
        actual_program.iface_registry().dep_rows(
            os.path.realpath(full_target), result, list(gen.native_deps or [])
        )
    );
    return sections;
}

"""Persist a native unit's products right after its compile, whether or not
anything ever asks for its bytecode: the link plan reads them from the JIR
and the interface registry's dependency rows point at them."""
impl JacCompiler._persist_native_unit(
    full_target: str, result: uni.Module, actual_program: JacProgram
) -> None {
    if result is None or result.parse_failed or result.gen.native_iface is None {
        return;
    }
    try {
        sections = self._native_sections(full_target, result, actual_program);
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
    } except Exception {}
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
    if options.force_target_program {
        actual_program = target_program;
    } else {
        actual_program = self.selfhost.resolve(file_path, target_program);
    }

    _prev_opts = actual_program.options;
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

impl JacCompiler._ingest_comptime_producers(
    mod_targ: uni.Module, actual_program: JacProgram, file_path: str
) -> None {
    if mod_targ is None or self.selfhost.is_selfhost(actual_program) {
        return;
    }
    saved_opts = actual_program.options;
    here_real = os.path.realpath(str(file_path));
    try {
        for imp in mod_targ.get_all_sub_nodes(uni.Import) {
            if not imp.is_comptime or imp.from_loc is None or imp.is_virtual_jac {
                continue;
            }
            try {
                target = imp.from_loc.resolve_relative_path();
            } except Exception {
                continue;
            }
            if not isinstance(target, str) or not target.endswith('.jac') {
                continue;
            }
            if not os.path.isfile(target) or os.path.realpath(target) == here_real {
                continue;
            }
            try {
                actual_program.load_dependency_module(
                    target, importer_path=file_path, need_tree=True
                );
            } except Exception as ct_ingest_err {
                import logging as _ct_logging;
                _ct_logging.getLogger(__name__).debug(
                    f"comptime producer {target} of {file_path} "
                    f"could not be ingested: {ct_ingest_err}"
                );
            }
        }
    } finally {
        actual_program.options = saved_opts;
    }
}

impl JacCompiler._compile_pipeline(
    file_path: str,
    actual_program: JacProgram,
    use_str: (str | None) = None,
    options: CompileOptions = CompileOptions()
) -> uni.Module {
    keep_str = use_str or read_file_with_encoding(file_path);
    had_parse_errors = len(actual_program.errors_had);
    mod_targ = self.parse_str(
        keep_str, file_path, actual_program, cancel_token=options.cancel_token
    );
    had_parse_errors = len(actual_program.errors_had) > had_parse_errors;
    self._ingest_comptime_producers(mod_targ, actual_program, file_path);

    cur_mod_path = os.path.normpath(file_path);
    blocking_errs_pre_ir = self._count_module_blocking_errors(
        actual_program, cur_mod_path
    );
    if options.symtab_ir_only {
        _head_sched = get_symtab_ir_sched();
    } else {
        _head_sched = get_ir_gen_sched(
            is_internal=self.selfhost.is_selfhost(actual_program),
            gen_mtir=not options.no_cgen
        );
    }

    _full_head = 'CfgSucc' in providers_of(_head_sched);
    self.run_schedule(
        mod=mod_targ,
        target_program=actual_program,
        passes=_head_sched,
        cancel_token=options.cancel_token
    );

    blocking_errs_post_ir = self._count_module_blocking_errors(
        actual_program, cur_mod_path
    );
    had_blocking_errors = blocking_errs_post_ir > blocking_errs_pre_ir;

    if not options.symtab_ir_only and not had_blocking_errors {
        import from jaclang.compiler.placement.placement_solver {
            solve_program_placement
        }
        try {
            solve_program_placement(mod_targ, actual_program);
        } except Exception {}
    }

    import from jaclang.compiler.frontend.constant { CodeContext as _CodeCtx }
    is_native_mod = mod_targ is not None
        and mod_targ.declares_codespace(_CodeCtx.NATIVE, path_hint=file_path);

    if is_native_mod {
        options.need_full_ast = True;
    }

    _is_decl_stub = str(file_path).endswith('.pyi')
        or str(file_path).endswith('.py')
        or (mod_targ is not None and mod_targ.stub_only)
        or (mod_targ is not None and mod_targ.is_raised_from_py);
    import from jaclang.jac0core.ext_registry { is_annex as _cc_is_annex }
    _annex_of_base = False;
    if _cc_is_annex(file_path) {
        import from jaclang.compiler.driver.bccache {
            discover_base_file as _cc_base_file
        }
        _annex_of_base = _cc_base_file(str(file_path)) is not None;
    }
    _analyze = _full_head
        and not _is_decl_stub
        and not _annex_of_base
        and (
            is_native_mod
            or not self.selfhost.is_selfhost(actual_program)
            or not module_import_in_flight(file_path)
        );

    if _analyze {
        if not actual_program.analysis.analyses_run.provides(mod_targ, 'TypeOf') {
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_analysis_sched(),
                cancel_token=options.cancel_token
            );
        }
    }

    if not had_blocking_errors
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
        and options.native_parity
        and not options.symtab_ir_only
        and not had_parse_errors
        and not had_blocking_errors
        and actual_program.analysis.analyses_run.provides(mod_targ, 'TypeOf')
    ) {
        import from jaclang.compiler.backends.py.module_codegen_pass {
            ModuleCodegenPass as _PtyMcp
        }
        if is_native_mod or _PtyMcp.has_native_context_stmts(mod_targ) {
            _parity_passes: list = [];
            try {
                import from jaclang.compiler.passes.rc_facts_pass {
                    RcFactsPass as _PtyRcFacts
                }
                import from jaclang.compiler.backends.native {
                    NaIRGenPass as _PtyNaIRGen
                }
                _parity_passes = [_PtyRcFacts, _PtyNaIRGen];
            } except ImportError {
                _parity_passes = [];
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
        cb_paths: list[str] = [];

        cb_opts = CompileOptions(
            no_cgen=True, force_target_program=True, cancel_token=options.cancel_token
        );
        cb_reg = actual_program.iface_registry();
        while cb_worklist or cb_paths {
            if cb_worklist {
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
                    cb_paths.append(_cb_os.path.abspath(cb_src));
                }
                continue;
            }
            cb_next = cb_paths.pop();
            if cb_next in cb_seen {
                continue;
            }
            cb_seen.add(cb_next);

            cb_mod = actual_program.find_module(cb_next);
            cb_has_facts = (
                cb_mod is not None
                and cb_mod.gen
                and cb_mod.gen.interop_manifest
                and bool(cb_mod.gen.interop_manifest.bindings)
            );

            cb_known_bad = actual_program.has_failed_parse(cb_next);
            if not cb_has_facts and not cb_known_bad {
                cb_served: (list[str] | None) = None;
                try {
                    cb_served = cb_reg.client_boundary_facts(cb_next);
                } except Exception {
                    cb_served = None;
                }
                if cb_served is not None {
                    for cb_edge in cb_served {
                        cb_paths.append(_cb_os.path.abspath(cb_edge));
                    }
                    continue;
                }
                try {
                    cb_mod = self.compile(
                        file_path=cb_next,
                        target_program=actual_program,
                        options=cb_opts
                    );
                } except Exception {
                    cb_mod = actual_program.mod.hub.get(cb_next);
                }
            }
            cb_worklist.append(cb_mod);
        }
        actual_program.options = options;
    }
    if (
        not had_parse_errors
        and not had_blocking_errors
        and not options.no_cgen
        and not options.symtab_ir_only
    ) {
        actual_program.options = options;

        import from jaclang.compiler.backends.py.module_codegen_pass {
            ModuleCodegenPass
        }
        needs_native = is_native_mod
            or ModuleCodegenPass.has_native_context_stmts(mod_targ);

        if needs_native
            and not actual_program.analysis.analyses_run.provides(mod_targ, 'TypeOf') {
            self.run_schedule(
                mod=mod_targ,
                target_program=actual_program,
                passes=get_analysis_sched(),
                cancel_token=options.cancel_token
            );
        }
        self.run_schedule(
            mod=mod_targ,
            target_program=actual_program,
            passes=get_py_code_gen(
                native=needs_native,
                provided=actual_program.analysis.analyses_run.provided(mod_targ)
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
    file_path: str, target_program: JacProgram, use_str: (str | None) = None
) -> uni.Module {
    actual_program = self.selfhost.resolve(file_path, target_program);
    mod_targ = self.compile(
        file_path, actual_program, use_str, options=CompileOptions()
    );
    run_pass(SemanticAnalysisPass, mod_targ, actual_program);
    return mod_targ;
}

impl JacCompiler.run_schedule(
    mod: uni.Module,
    target_program: JacProgram,
    passes: list[type[Transform]],
    cancel_token: (Event | None) = None
) -> None {
    provided = target_program.analysis.analyses_run.provided(mod);
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
    import from jaclang.compiler.frontend.diagnostics { Category }
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
    gen.native_object = None;
    gen.native_iface = None;
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
    import from jaclang.compiler.frontend.diagnostics { E5092 }
    import from jaclang.compiler.backends.py.module_codegen_pass { ModuleCodegenPass }
    import from jaclang.compiler.passes.transform { Alert }
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
        import from jaclang.compiler.backends.native { NaIRGenPass }
        from_pass = NaIRGenPass;
    } except Exception {}
    deliver_alerts(
        [
            Alert(
                msg=E5092.format_message(
                    kind='module', name=os.path.basename(mod_path)
                ),
                loc=mod.loc.span(),
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
    for pass_cls in get_format_sched(auto_lint=auto_lint) {
        current_mod = run_pass(pass_cls, current_mod, prog).ir_out;
    }
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
    for pass_cls in get_format_sched(auto_lint=auto_lint) {
        current_mod = run_pass(pass_cls, current_mod, prog).ir_out;
    }
    prog.reset_module_root(uni.ProgramModule(main_mod=current_mod));
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
    if target_program.analysis.analyses_run.provides(mod, 'TypeOf') {
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
    import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
    mark = len(target_program.errors_had);
    run_pass(EsastGenPass, mod, target_program);
    return len(target_program.errors_had) == mark;
}

impl JacCompiler.client_artifact_of(mod: uni.Module) -> (ClientArtifact | None) {
    import from jaclang.compiler.frontend.codeinfo { ClientArtifact }
    js = mod.gen.js;
    if not js {
        return None;
    }
    native_sources: list[str] = [];
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
    full_target = JacProgram.hub_key(full_target);
    actual_program = self.selfhost.resolve(full_target, target_program);
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
    held = actual_program.hub.client_artifacts.get(full_target);
    if held is None {
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
        file_path=full_target, target_program=actual_program, options=CompileOptions()
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
