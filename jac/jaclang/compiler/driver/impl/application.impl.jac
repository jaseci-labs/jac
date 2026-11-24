impl _runtime_output(name: str) -> bool {
    return name.endswith(('.log', '.db', '.db-wal', '.db-shm', '.sqlite', '.sqlite3'));
}

impl _inventory(`root: any, inputs: bool = False) -> dict[str, str] {
    result: dict[str, str] = {};
    for (directory, dirs, files) in os.walk(`root) {
        dirs[:] = sorted(
            d
            for d in dirs
            if ((d not in _SKIP) and not d.startswith('.'))
        );
        for name in sorted(files) {
            if inputs and _runtime_output(name) {
                continue;
            }
            path = os.path.join(directory, name);
            result[path] = compute_content_sha256(path);
        }
    }
    for toml_path in Path(`root).`glob('jac*.toml') {
        result[str(toml_path)] = compute_content_sha256(str(toml_path));
    }
    return result;
}

impl _client_inventory(
    `root: str, dirs: list[str], files: list[str]
) -> dict[str, str] {
    result: dict[str, str] = {};
    def take(path: str) {
        if os.path.isfile(path) {
            result[path] = compute_content_sha256(path);
        }
    }
    for name in sorted(os.listdir(`root)) {
        if not _runtime_output(name) {
            take(os.path.join(`root, name));
        }
    }
    for directory in dirs {
        for (current, subdirs, names) in os.walk(directory) {
            subdirs[:] = sorted(
                d
                for d in subdirs
                if d not in _SKIP and not d.startswith('.')
            );
            for name in sorted(names) {
                take(os.path.join(current, name));
            }
        }
    }
    for path in files {
        take(path);
    }
    return result;
}

impl _identity -> tuple[str, str | None, str] {
    return (
        compiler_generation(),
        sys.implementation.cache_tag,
        os.environ.get('JAC_PROFILE', '')
    );
}

impl _write(path: any, value: any) {
    atomic_write(path, marshal.dumps(value));
}

impl _sections(path: any, program: any) -> dict[int, bytes] {
    actual = program_for(path, program);
    with cache_scope(actual.options) {
        return _context_sections(path);
    }
}

impl _context_sections(path: any) -> dict[int, bytes] {
    cache = get_module_cache_path(path);
    if not cache.exists() {
        return {};
    }
    data = read_jir(cache);
    pos = data.find(SECTIONS_MAGIC, HEADER_SIZE);
    return read_sections(data, (pos + len(SECTIONS_MAGIC))) if (pos >= 0) else {};
}

impl _project_modules(program: any, `root: any) -> dict[str, uni.Module] {
    result: dict[str, uni.Module] = {};
    selfhost = program._get_compiler().selfhost;
    for hub in program.execution_hubs() {
        for (path, module) in `list(hub.items()) {
            if module
                and os.path.realpath(path).startswith((`root + os.sep))
                and not selfhost.is_selfhost(selfhost.resolve(path, program)) {
                result[os.path.realpath(path)] = module;
            }
        }
    }
    return result;
}

impl _semantic_metadata(revision: PreparedApplication, program: any) {
    for path in revision.code {
        actual = program_for(path, program);
        prefix = base_stem(path) + '.';
        revision.semantic[path] = {
            key: value
            for (key, value) in actual.mtir_map.items()
            if key.startswith(prefix)
        };
    }
}

impl _tree_source(
    program: any, mod: uni.Module, imported: bool = True
) -> ManifestSource {
    if imported {
        import from jaclang.compiler.driver.pipeline { require, CompilationProduct }
        manifest = mod.gen.interop_manifest;
        if not (manifest and manifest.surface) {
            require(program, mod, CompilationProduct.BOUNDARIES);
        }
    }
    return ManifestSource(
        path=mod.loc.mod_path if mod.loc else '',
        app=mod.app or '',
        persistence=mod.persistence,
        edges=import_edges(mod) if imported else [],
        interop=mod.gen.interop_manifest,
        client=mod.gen.client_manifest
    );
}

impl _manifest(program: any, path: any, `root: any, mod: any = None) -> dict[str, any] {
    mod = mod if (mod is not None) else program.find_module(path);
    if (mod is None) {
        raise RuntimeError(f'Preparation did not produce metadata for {path}');
    }
    selfhost = program._get_compiler().selfhost;
    def lookup(source: str) -> (ManifestSource | None) {
        if selfhost.is_selfhost(selfhost.resolve(source, program)) {
            return None;
        }
        imported = program.find_module(source);
        return _tree_source(program, imported) if imported is not None else None;
    }
    return build_manifest(
        `root,
        _tree_source(program, mod),
        lookup,
        [
            _tree_source(program, m, imported=False)
            for m in _project_modules(program, `root).values()
        ]
    );
}

impl build_manifest(
    `root: str,
    main: ManifestSource,
    lookup: Callable[[str], ManifestSource | None],
    project: list[ManifestSource]
) -> dict[str, any] {
    def key_of(source: ManifestSource) -> str {
        return os.path.realpath(source.path) if source.path else '';
    }
    sources: list[ManifestSource] = [main];
    listed: set[str] = {key_of(main)};
    namespace_sources: list[ManifestSource] = [main];
    namespaces: set[str] = {key_of(main)};
    imported_functions: set[tuple[str, str]] = set();
    for namespace in namespace_sources {
        for (absorb, source_path, names) in namespace.edges {
            imported = lookup(source_path);
            if imported is None {
                continue;
            }
            if key_of(imported) not in listed {
                listed.add(key_of(imported));
                sources.append(imported);
            }
            if absorb {
                if key_of(imported) not in namespaces {
                    namespaces.add(key_of(imported));
                    namespace_sources.append(imported);
                }
            } else {
                for name in names {
                    imported_functions.add((imported.path, name));
                }
            }
        }
    }
    surface: dict[str, dict[str, any]] = {};
    private_declarations: set[str] = set();
    effects: dict[str, dict[str, any]] = {};
    ordered = list(sources)
        + [
            m
            for m in project
            if key_of(m) not in listed
        ];
    for source in ordered {
        manifest = source.interop;
        if not manifest {
            continue;
        }
        effects.update(manifest.endpoint_effects);
        if not manifest.surface or source.app != main.app {
            continue;
        }
        src_path = source.path;
        if not src_path {
            continue;
        }
        rel = os.path.relpath(os.path.realpath(src_path), `root).replace(os.sep, '/');
        for (name, rec) in manifest.surface.items() {
            if (
                not rec.explicit_access
                and rec.exposure == 'private'
                and rec.placement != 'client'
                and not name.startswith('_')
                and (
                    rec.kind == 'walker'
                    or key_of(source) in namespaces
                    or (src_path, name) in imported_functions
                )
            ) {
                private_declarations.add(f'{rel}:{name}');
            }
            if name in surface or not rec.is_served() {
                continue;
            }
            surface[name] = {** rec.to_dict(), 'src': rel};
        }
    }
    client = main.client;
    return `dict(
        `root=`root,
        app=main.app,
        persistence=main.persistence,
        client=`dict(
            exports=`list(client.exports),
            globals=`list(client.globals),
            params=client.params,
            globals_values=client.globals_values,
            has_client=client.has_client
        )
            if client
            else {},
        surface=surface,
        private_declarations=sorted(private_declarations),
        endpoint_effects=effects
    );
}

impl _warn_private_declarations(application: PreparedApplication, console: any) {
    app = app_for_path(application.entry);
    if app is None or not app.has_server {
        return;
    }
    metadata = application.manifests.get(application.entry, {});
    declarations = metadata.get('private_declarations', []);
    if declarations {
        console.warning(
            f"App '{app.name}' has unmarked declarations that are now private "
                + "and are not served: "
                + ', '.join(declarations)
                + ". "
                + "Review the migration with jac fix access --dry-run; "
                + "use :protect or :pub for endpoints, or :priv to keep them private."
        );
    }
}

impl _check(program: any, before: any) {
    errors = program.errors_had[before:];
    if errors {
        raise BuildFailed('\n'.join(e.pretty_print() for e in errors));
    }
}

impl _surface_sources(manifests: list[dict[str, any]], `root: str) -> set[str] {
    return {
        os.path.realpath(os.path.join(`root, rec['src']))
        for metadata in manifests
        for rec in (metadata.get('surface') or {}).values()
        if rec.get('src')
    };
}

impl _drain(pending: set[str], code: dict[str, any], visit: any) {
    while pending {
        path = pending.pop();
        if path not in code {
            pending.update(visit(path) - code.keys());
        }
    }
}

impl _name_applications(applications: list[PreparedApplication]) {
    for application in applications {
        application.name = application.manifests.get(application.entry, {}).get(
            'app', ''
        );
    }
}

impl _drop_client(revision: PreparedApplication) {
    revision.client_compiler = None;
    revision.client_dist = '';
}

impl _prepare_sealed(
    `entry: str, program: any, image_root: str, entries: list[str]
) -> PreparedApplication {
    bundle_dir = Path(image_root) / '_precompiled';
    image = image_for_bundle_dir(bundle_dir) or register_image(bundle_dir);
    if image is None {
        raise RuntimeError(
            f'Sealed application has no artifact manifest: {image_root}'
        );
    }
    manifest = read_serve_manifest(image_root);
    manifest['root'] = image_root;
    recorded: dict[str, set[str]] = {
        os.path.realpath(os.path.join(image_root, source)): {
            os.path.realpath(os.path.join(image_root, dependency))
            for dependency in dependencies
        } for (source, dependencies) in (manifest.get('runtime_imports') or {}).items()
    };
    def imports_of(code: any, path: str) -> set[str] {
        known = recorded.get(path);
        return known if known is not None else runtime_sources(code, path, image_root);
    }
    revision = PreparedApplication(
        image_root, `entry, services=tuple(entries[1:]), dev=False
    );
    dist = Path(image_root) / CLIENT_DIST_REL;
    if dist.is_dir() {
        revision.client_dist = str(dist);
        revision.client_enabled = True;
    }
    for (source, metadata) in manifest['module_manifests'].items() {
        revision.manifests[os.path.realpath(os.path.join(image_root, source))] = {
            ** metadata,
            'root': image_root
        };
    }
    for path in entries {
        if path not in revision.manifests {
            raise RuntimeError(
                f'Sealed application is missing serving metadata: {path}'
            );
        }
    }
    pending = set(entries)
        | _surface_sources(
            list(manifest['module_manifests'].values()) + [manifest], image_root
        );
    for path in list(pending) {
        parent = Path(path).parent;
        while parent.is_relative_to(image_root) {
            relative = parent.relative_to(image_root).as_posix();
            for (source, info) in image.manifest['modules'].items() {
                if info.get('package') and Path(source).parent.as_posix() == relative {
                    pending.add(os.path.realpath(os.path.join(image_root, source)));
                }
            }
            parent = parent.parent;
        }
    }
    compiler = program._get_compiler();
    def visit(path: str) -> set[str] {
        if Path(path).suffix == '.py' {
            code = compiler.get_bytecode(path, program);
            if code is None {
                raise RuntimeError(
                    f'Sealed application has no Python artifact: {path}'
                );
            }
            revision.code[path] = code;
            return imports_of(code, path);
        }
        sealed = compiler._sealed_jir_data(path);
        if sealed is None {
            raise RuntimeError(
                f'Sealed application is missing executable artifact: {path}'
            );
        }
        (data, artifact_root) = sealed;
        bytecode = read_bytecode_only(data);
        if bytecode is None {
            raise RuntimeError(
                f'Sealed application has no executable bytecode: {path}'
            );
        }
        revision.code[path] = marshal.loads(
            patch_co_filenames_bytes(bytecode, PRECOMPILE_SENTINEL, artifact_root)
        );
        pos = data.find(SECTIONS_MAGIC, HEADER_SIZE);
        if pos >= 0 {
            compiler._restore_sections(
                path,
                compiler.selfhost.resolve(path, program),
                read_sections(data, pos + len(SECTIONS_MAGIC))
            );
        }
        revision.native[path] = compiler.get_native_interop_setup(path, program);
        return imports_of(revision.code[path], path);
    }
    _drain(pending, revision.code, visit);
    revision.applications = [
        PreparedApplication(
            image_root,
            path,
            code=revision.code,
            manifests=revision.manifests,
            native=revision.native,
            dev=False
        ) for path in entries[1:]
    ];
    _name_applications([revision, *revision.applications]);
    publish(revision);
    return revision;
}

impl prepare_application(
    `entry: str,
    program: any,
    `root: (str | None) = None,
    services: any = (),
    client: bool = False,
    dev: (bool | None) = None,
    force_codespace: str = ''
) -> PreparedApplication {
    dev_mode = True if dev is None else dev;
    `entry = os.path.realpath(`entry);
    `root = os.path.realpath((`root or os.path.dirname(`entry)));
    entries = `list(`dict.fromkeys([`entry, *(os.path.realpath(p) for p in services)]));
    import from jaclang.server.sealed_serve { sealed_root_for, unlisted_image_root }
    image_root = sealed_root_for(`entry);
    if image_root is not None and dev is not True {
        console.print('  Loading sealed application artifacts', file=sys.stderr);
        return _prepare_sealed(`entry, program, image_root, entries);
    }
    unlisted = unlisted_image_root(`entry);
    if unlisted is not None {
        missing = os.path.relpath(`entry, unlisted);
        console.print(
            f'  Sealed image at {unlisted} does not list {missing}; '
            'preparing from source'
        );
    }
    import from jaclang.compiler.driver.pass_driver { compile_progress }
    started = time.monotonic();
    active: list[str] = [];
    completed: list[int] = [0];
    def begin(path: any) {
        active.append(path);
    }
    def finish(path: any) {
        if (path in active) {
            active.remove(path);
        }
        completed[0] += 1;
    }
    def progress -> str {
        current = ' · ' + os.path.relpath(active[-1], `root) if active else '';
        return f'Preparing application: {completed[0]} modules · {(
            time.monotonic() - started
        ):.1f}s{current}';
    }
    import from jaclang.compiler.frontend.codeinfo {
        get_effective_default_codespace_override,
        set_effective_default_codespace
    }
    import from jaclang.runtime.preparation_lock { PREPARATION_LOCK }
    with PREPARATION_LOCK {
        previous = get_effective_default_codespace_override();
        set_effective_default_codespace('server');
        watched = bool(os.environ.get('JAC_PREPARE_TRACEBACK'));
        if watched {
            import faulthandler;
            try {
                faulthandler.dump_traceback_later(
                    SLOW_PREPARE_SECONDS, repeat=True, file=sys.stderr
                );
            } except (ValueError, OSError) {
                watched = False;
            }
        }
        try {
            with console.status(
                'Preparing application...', file=sys.stderr
            ) as status {
                status.update(progress);
                with compile_progress.listen(begin, finish) {
                    import from jaclang.compiler.driver.compilation_context {
                        bind_options,
                        context_program
                    }
                    import from jaclang.compiler.driver.compile_options {
                        CompileOptions
                    }
                    import from jaclang.runtime.prepared { publish }
                    applications: list[PreparedApplication] = [];
                    for path in entries {
                        source_root = `root
                            if Path(path).is_relative_to(`root)
                            else os.path.dirname(path);
                        options = bind_options(
                            path,
                            program,
                            CompileOptions(
                                default_codespace='server',
                                force_codespace=force_codespace,
                                skip_native_engine=program.options.skip_native_engine,
                                retain_interfaces=program.options.retain_interfaces,
                                entry_point=path,
                                project_root=`root,
                                client_source_root=source_root if client else ''
                            )
                        );
                        actual = context_program(program, options);
                        applications.append(
                            _prepare(
                                path,
                                actual,
                                `root,
                                [path],
                                client and path == `entry,
                                dev_mode,
                                console
                            )
                        );
                    }
                    revision = applications[0];
                    for application in applications {
                        _warn_private_declarations(application, console);
                    }
                    _name_applications(applications);
                    revision.services = tuple(entries[1:]);
                    revision.applications = applications[1:];
                    publish(revision);
                    _release_compile_state(program);
                    return revision;
                }
            }
        } finally {
            if watched {
                import faulthandler;
                faulthandler.cancel_dump_traceback_later();
            }
            set_effective_default_codespace(previous);
        }
    }
}

impl _release_compile_state(program: any) {
    program._get_compiler().release_compile_state(program);
}

impl _capture_input(path: str, inputs: dict[str, str]) {
    path = os.path.realpath(path);
    if path not in inputs {
        inputs[path] = ct_dep_digest(path, with_annexes=True);
    }
}

impl _prepare(
    `entry: any,
    program: any,
    `root: any,
    entries: any,
    client: any,
    dev: any,
    console: any
) -> PreparedApplication {
    program.forget_failed_modules();
    if client {
        import from jaclang.client.config_loader { JacClientConfig }
        JacClientConfig(Path(`root), entry_path=`entry).load();
    }
    inputs: dict[str, str] = {};
    selfhost = program._get_compiler().selfhost;
    def capture(path: str) {
        if not selfhost.is_selfhost(selfhost.resolve(path, program)) {
            _capture_input(path, inputs);
        }
    }
    _capture_input(str(Path(`root) / 'jac.toml'), inputs);
    for config in Path(`root).`glob('jac*.toml') {
        _capture_input(str(config), inputs);
    }
    for path in entries {
        capture(path);
    }
    import from jaclang.compiler.driver.jir { begin_prepare_memo, end_prepare_memo }
    with compile_progress.listen(capture) {
        memo = begin_prepare_memo();
        try {
            return _prepare_revision(
                `entry, program, `root, entries, client, dev, console, inputs
            );
        } finally {
            end_prepare_memo(memo);
        }
    }
}

impl _prepare_revision(
    `entry: any,
    program: any,
    `root: any,
    entries: any,
    client: any,
    dev: any,
    console: any,
    inputs: dict[str, str]
) -> PreparedApplication {
    inventory_root = `root
        if client
        else os.path.join(os.path.dirname(`entry), 'pages');
    retain = bool(program.options.retain_interfaces);
    slot = hashlib.sha256(
        repr((`entry, entries, client, dev) + (("retain", ) if retain else ())).encode()
    ).hexdigest()[:20];
    cache = Path(`root) / '.jac' / 'cache' / 'applications' / f'{slot}.bin';
    candidate: any = None;
    try {
        with cache.open('rb') as stream {
            candidate = marshal.load(stream);
        }
    } except (OSError, ValueError, EOFError, TypeError) {}
    held = candidate if isinstance(candidate, dict) else {};
    client_dirs: list[str] = [];
    if client {
        import from jaclang.client.config_loader { JacClientConfig }
        import from jaclang.project.client_paths { client_input_dirs }
        client_dirs = client_input_dirs(
            JacClientConfig(Path(`root), entry_path=`entry).get_jac_config(),
            Path(`root),
            `entry
        );
    }
    client_files: list[str] = list(held.get('client_files') or []);
    inventory = _client_inventory(`root, client_dirs, client_files)
        if client
        else _inventory(inventory_root, inputs=True);
    key = (
        _FORMAT,
        _identity(),
        inventory,
        sorted(inputs.items()),
        entries,
        client,
        dev
    )
        + ((tuple(client_build_env()), ) if client else ())
        + (("retain", ) if retain else ());
    compiler = program._get_compiler();
    revision = PreparedApplication(
        `root, `entry, client_enabled=client, services=`tuple(entries[1:]), dev=dev
    );
    record = None;
    try {
        import from jaclang.compiler.driver.jir { cache_mode }
        if candidate is not None
            and not cache_mode()[0]
            and (candidate['key'] == key)
            and all(
                compute_content_sha256(path) == digest
                for (path, digest) in candidate['outputs'].items()
            )
            and all(
                (ct_dep_digest(path, with_annexes=True) == digest)
                for (path, digest) in (
                    candidate['dependencies'] | candidate['client_modules']
                ).items()
            ) {
            record = candidate;
        }
    } except (OSError, ValueError, EOFError, TypeError, KeyError) {}
    builder = None;
    if client {
        import from jaclang.client.vite_client_bundle { make_client_bundle_builder }
        builder = make_client_bundle_builder(
            Path(`root), entry_path=`entry, program=program
        );
        revision.client_compiler = builder._get_compiler();
        revision.client_dist = str(revision.client_compiler.vite_bundler.output_dir);
    }
    if (record is not None) {
        console.print('  Restoring prepared application', file=sys.stderr);
        if not record['has_client'] {
            _drop_client(revision);
        }
        if revision.client_compiler is not None {
            revision.client_compiler.jac_client_compiler.na_wasm_modules = set(
                record['client_native_sources']
            );
            revision.client_compiler._has_pages = record['client_has_pages'];
            revision.client_compiler.jac_client_compiler._has_pages = record[
                'client_has_pages'
            ];
        }
        revision.code = record['code'];
        revision.sources = sorted(record['dependencies']);
        revision.manifests = record['manifests'];
        for (path, sections) in record['sections'].items() {
            import from jaclang.compiler.driver.compilation_context { program_for }
            actual = program_for(path, program);
            compiler._restore_sections(path, actual, sections);
        }
        for path in revision.code {
            revision.native[path] = compiler.get_native_interop_setup(path, program);
        }
        _semantic_metadata(revision, program);
        return revision;
    }
    console.print(
        '  Compiling server modules and placement metadata...', file=sys.stderr
    );
    before = len(program.errors_had);
    import copy;
    modules: dict[str, uni.Module] = {};
    import from jaclang.compiler.driver.pipeline_runner { compile_application }
    for path in entries {
        options = copy.copy(program.options);
        options.project_root = `root;
        options.no_cgen = False;
        modules[path] = compile_application(program, path, options);
        _check(program, before);
    }
    entry_client = modules[`entry].gen.client_manifest;
    has_client = client
        and bool(
            (entry_client is not None and entry_client.has_client)
                or (Path(`entry).parent / 'pages').is_dir()
        );
    if has_client {
        assert revision.client_compiler is not None;
        console.print('  Compiling client and native artifacts...', file=sys.stderr);
        revision.client_compiler.compile(None, Path(`entry));
        if not dev {
            bundler = revision.client_compiler.vite_bundler;
            compiled_dir = revision.client_compiler.compiled_dir;
            assert compiled_dir is not None;
            bundler.build(entry_file=(compiled_dir / '_entry.js'));
        }
        revision.client_compiler._emit_na_wasm(Path(`entry));
        _check(program, before);
    } else {
        _drop_client(revision);
    }
    routes = prepare_route_metadata(os.path.dirname(`entry), program);
    for path in entries {
        revision.manifests[path] = _manifest(program, path, `root, modules[path]);
        _check(program, before);
    }
    revision.manifests[`entry]['spa_routes'] = routes;
    import from jaclang.compiler.backends.py.artifact_imports {
        import_specs,
        package_sources,
        resolve_imports
    }
    sections = {};
    previous_code: dict[str, any] = held.get('code') or {};
    previous_specs: dict[str, list[tuple[int, str, (tuple[str, ...] | None)]]] = (
        held.get('import_specs') or {}
    );
    specs_of: dict[str, list[tuple[int, str, (tuple[str, ...] | None)]]] = {};
    pending = `set(entries)
        | _surface_sources(list(revision.manifests.values()), `root);
    for path in entries {
        pending.update(package_sources(path, `root));
    }
    def visit(path: str) -> set[str] {
        if path not in entries
            and compiler.selfhost.is_selfhost(
                compiler.selfhost.resolve(path, program)
            ) {
            return set();
        }
        _capture_input(path, inputs);
        code = compiler.get_bytecode(path, program);
        _check(program, before);
        if (code is None) {
            import from jaclang.compiler.driver.source_failures {
                module_scoped_failure_details,
                bootstrap_tier_failure_details
            }
            actual = compiler.selfhost.resolve(path, program);
            details = module_scoped_failure_details(path, actual)
                or bootstrap_tier_failure_details(path);
            if details {
                raise RuntimeError(details);
            }
            raise RuntimeError(f'No executable artifact produced for {path}');
        }
        revision.code[path] = code;
        sections[path] = _sections(path, program);
        revision.native[path] = compiler.get_native_interop_setup(path, program);
        known = previous_specs.get(path);
        specs = known
            if known is not None and previous_code.get(path) == code
            else import_specs(code, path);
        specs_of[path] = specs;
        return resolve_imports(specs, path, `root);
    }
    _drain(pending, revision.code, visit);

    project_facts: dict[str, tuple[str, any]] = {
        path: (mod.app or '', mod.persistence)
        for (path, mod) in _project_modules(program, `root).items()
    };
    for (path, facts) in project_facts.items() {
        if path in revision.code {
            revision.manifests.setdefault(
                path, {'root': `root, 'app': facts[0], 'persistence': facts[1]}
            );
        }
    }
    outputs = {};
    if has_client {
        assert revision.client_compiler is not None;
        for directory in (
            revision.client_compiler.compiled_dir,
            revision.client_compiler.vite_bundler.output_dir
        ) {
            if (directory and Path(directory).exists()) {
                outputs.update(_inventory(str(directory)));
            }
        }
    }
    for path in revision.code {
        _capture_input(path, inputs);
    }
    for path in project_facts {
        _capture_input(path, inputs);
    }
    if any(
        ct_dep_digest(path, with_annexes=True) != digest
        for (path, digest) in inputs.items()
    ) {
        raise SourcesChanged(
            'Sources changed during preparation; retry with the new revision.'
        );
    }
    read: dict[str, str] = {};
    client_modules: dict[str, str] = {};
    if revision.client_compiler is not None {
        read = dict(revision.client_compiler.jac_client_compiler.input_files);
        client_modules = dict(
            revision.client_compiler.jac_client_compiler.client_modules
        );
        client_files = sorted(read);
    }
    current = _client_inventory(`root, client_dirs, client_files)
        if client
        else _inventory(inventory_root, inputs=True);
    if (not client and current != inventory)
        or any(current.get(path) != digest for (path, digest) in inventory.items())
        or any(current.get(path, '') != digest for (path, digest) in read.items())
        or any(
            ct_dep_digest(path, with_annexes=True) != digest
            for (path, digest) in client_modules.items()
        ) {
        raise SourcesChanged(
            'Sources changed during preparation; retry with the new revision.'
        );
    }
    if client {
        key = (key[0], key[1], current) + tuple(key[3:]);
    }
    _write(
        cache,
        `dict(
            key=key,
            has_client=has_client,
            client_native_sources=sorted(
                revision.client_compiler.jac_client_compiler.na_wasm_modules
            )
                if revision.client_compiler is not None
                else [],
            client_has_pages=revision.client_compiler._has_pages
                if revision.client_compiler is not None
                else False,
            code=revision.code,
            import_specs=specs_of,
            manifests=revision.manifests,
            sections=sections,
            outputs=outputs,
            client_files=client_files,
            client_modules=client_modules,
            dependencies=inputs
        )
    );
    revision.sources = sorted(inputs);
    _semantic_metadata(revision, program);
    return revision;
}

impl prepare_route_metadata(`root: str, program: any) -> (list[str] | None) {
    if not (Path(`root) / 'pages').is_dir() {
        return None;
    }
    import from jaclang.client.route_scanner { RouteScanner }
    import from jaclang.compiler.driver.pipeline_runner { route_exports }
    def exports(path: Path) -> tuple[str | None, str | None] {
        return route_exports(program, str(path));
    }
    scanner = RouteScanner(project_root=Path(`root), route_exports_of=exports);
    return [
        route.path
        for route in scanner.scan()
        if (route.path not in ('*', '/*'))
    ];
}

impl reprepare_application(
    application: PreparedApplication, program: any
) -> PreparedApplication {
    return prepare_application(
        application.entry,
        program,
        `root=application.root,
        services=application.services,
        client=application.client_enabled,
        dev=application.dev
    );
}

impl prepare_dynamic_module(
    path: str, program: any, application: PreparedApplication
) -> PreparedApplication {
    console.print(f'Preparing dynamically imported module: {path}', file=sys.stderr);
    if os.path.realpath(path) in (application.entry, *application.services) {
        return reprepare_application(application, program);
    }
    import from jaclang.compiler.driver.compilation_context { program_for }
    import from jaclang.runtime.prepared { publish }
    import from jaclang.runtime.preparation_lock { PREPARATION_LOCK }
    with PREPARATION_LOCK {
        actual = program_for(application.entry, program);
        revision = _prepare(
            application.entry,
            actual,
            application.root,
            [application.entry, path],
            application.client_enabled,
            application.dev,
            console
        );
        revision.services = application.services;
        revision.applications = application.applications;
        publish(revision);
        return revision;
    }
}
