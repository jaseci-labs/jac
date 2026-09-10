import hashlib;
import marshal;
import os;
import sys;
import tempfile;
import time;
import from pathlib { Path }
import type from jaclang.runtime.prepared { PreparedApplication }
glob _FORMAT: int = 4,
     _SKIP: set[str] = {'.jac', '.git', '.venv', 'venv', 'node_modules', '__pycache__'};

def _inventory(`root: any, inputs: bool = False) -> dict {
    result = {};
    for (directory, dirs, files) in os.walk(`root) {
        dirs[:] = sorted(
            d
            for d in dirs
            if ((d not in _SKIP) and not d.startswith('.'))
        );
        for name in sorted(files) {
            if inputs
                and name.endswith(
                    ('.log', '.db', '.db-wal', '.db-shm', '.sqlite', '.sqlite3')
                ) {
                continue;
            }
            path = os.path.join(directory, name);
            stat = os.stat(path);
            result[path] = (stat.st_mtime_ns, stat.st_size);
        }
    }
    for path in Path(`root).`glob('jac*.toml') {
        stat = path.stat();
        result[str(path)] = (stat.st_mtime_ns, stat.st_size);
    }
    return result;
}

def _identity -> tuple {
    import from jaclang.compiler.driver.jir { compiler_generation }
    return (
        compiler_generation(),
        sys.implementation.cache_tag,
        os.environ.get('JAC_PROFILE', '')
    );
}

def _write(path: any, value: any) {
    path.parent.mkdir(parents=True, exist_ok=True);
    tmp: str = "";
    try {
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream {
            tmp = stream.name;
            marshal.dump(value, stream);
        }
        os.replace(tmp, path);
    } finally {
        if (tmp and os.path.exists(tmp)) {
            os.unlink(tmp);
        }
    }
}

def _sections(path: any, program: any) -> dict {
    import from jaclang.compiler.driver.compilation_context { cache_scope, program_for }
    actual = program_for(path, program);
    with cache_scope(actual.context_key, actual.options) {
        return _context_sections(path);
    }
}

def _context_sections(path: any) -> dict {
    import from jaclang.compiler.driver.jir {
        get_module_cache_path,
        HEADER_SIZE,
        SECTIONS_MAGIC,
        read_sections
    }
    cache = get_module_cache_path(path);
    if not cache.exists() {
        return {};
    }
    data = cache.read_bytes();
    pos = data.find(SECTIONS_MAGIC, HEADER_SIZE);
    return read_sections(data, (pos + len(SECTIONS_MAGIC))) if (pos >= 0) else {};
}

def _project_modules(program: any, `root: any) -> dict {
    result = {};
    for hub in program._search_hubs() {
        for (path, module) in `list(hub.items()) {
            if (module and os.path.realpath(path).startswith((`root + os.sep))) {
                result[os.path.realpath(path)] = module;
            }
        }
    }
    return result;
}

def _manifest(program: any, path: any, `root: any, mod: any = None) -> dict {
    import from jaclang.compiler.frontend { unitree as uni }
    import from jaclang.compiler.frontend.constant { Tokens as Tok }
    mod = mod if (mod is not None) else program.find_module(path);
    if (mod is None) {
        raise RuntimeError(f'Preparation did not produce metadata for {path}');
    }
    sources = [mod];
    for item in mod.body {
        if (isinstance(item, uni.Import) and item.is_jac and item.from_loc) {
            source = item.from_loc.resolve_relative_path();
            imported = program.find_module(source) if source else None;
            if (imported is not None) {
                sources.append(imported);
            }
        }
    }
    (funcs, walkers, effects) = ({}, {}, {});
    import from jaclang.compiler.driver.pipeline { require_product, CompilationProduct }
    for source in sources {
        manifest = source.gen.interop_manifest;
        if (manifest and not (manifest.func_access or manifest.walker_access)) {
            require_product(program, source, CompilationProduct.BOUNDARIES);
            manifest = source.gen.interop_manifest;
        }
        if manifest {
            for (name, access) in manifest.func_access.items() {
                funcs.setdefault(name, access);
            }
            for (name, access) in manifest.walker_access.items() {
                walkers.setdefault(name, access);
            }
        }
    }
    (cross, seen) = ([], `set());
    for source in _project_modules(program, `root).values() {
        manifest = source.gen.interop_manifest;
        if not manifest {
            continue;
        }
        effects.update(manifest.endpoint_effects);
        for binding in manifest.server_exports_to_client {
            `node = binding.ast_node;
            if ((`node is None) or ((binding.name, binding.kind) in seen)) {
                continue;
            }
            src = `node.loc.mod_path;
            if (not src or not os.path.realpath(src).startswith((`root + os.sep))) {
                continue;
            }
            access = `node?.access;
            auth = not ((access is not None) and (access.tag.name == Tok.KW_PUB));
            seen.add((binding.name, binding.kind));
            cross.append(
                `dict(
                    name=binding.name,
                    kind=binding.kind,
                    src=os.path.relpath(src, `root),
                    auth=auth
                )
            );
        }
    }
    client = mod.gen.client_manifest;
    return `dict(
        `root=`root,
        app=mod.app or '',
        client=`dict(
            exports=`list(client.exports),
            globals=`list(client.globals),
            params=client.params,
            globals_values=client.globals_values,
            has_client=client.has_client
        )
            if client
            else {},
        func_access=funcs,
        walker_access=walkers,
        endpoint_effects=effects,
        cross_bindings=cross
    );
}

def _check(program: any, before: any) {
    errors = program.errors_had[before:];
    if errors {
        raise RuntimeError('\n'.join(e.pretty_print() for e in errors));
    }
}

def _prepare_sealed(
    `entry: str, program: any, image_root: str, entries: list
) -> PreparedApplication {
    import json;
    import from jaclang.runtime.prepared { PreparedApplication, publish }
    import from jaclang.server.sealed_serve { SERVE_MANIFEST_REL, CLIENT_DIST_REL }
    import from jaclang.compiler.driver.jir {
        HEADER_SIZE,
        SECTIONS_MAGIC,
        PRECOMPILE_SENTINEL,
        read_sections,
        read_bytecode_only,
        patch_co_filenames_bytes
    }
    import from jaclang.compiler.backends.py.artifact_imports {
        runtime_sources,
        package_sources
    }
    import from jaclang.jac0core.sealed { image_for_bundle_dir, register_image }
    bundle_dir = Path(image_root) / '_precompiled';
    image = image_for_bundle_dir(bundle_dir) or register_image(bundle_dir);
    if image is None {
        raise RuntimeError(
            f'Sealed application has no artifact manifest: {image_root}'
        );
    }
    manifest = json.loads((Path(image_root) / SERVE_MANIFEST_REL).read_text());
    manifest['root'] = image_root;
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
    pending = set(entries);
    pending.update(
        os.path.realpath(os.path.join(image_root, binding['src']))
        for binding in manifest.get('cross_bindings', [])
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
    while pending {
        path = pending.pop();
        if path in revision.code {
            continue;
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
        pending.update(
            runtime_sources(revision.code[path], path, image_root)
                - revision.code.keys()
        );
    }
    publish(revision);
    return revision;
}

def prepare_application(
    `entry: str,
    program: any,
    `root: (str | None) = None,
    services: any = (),
    client: bool = False,
    dev: bool = True
) -> PreparedApplication {
    import from jaclang.cli.console { console }
    `entry = os.path.realpath(`entry);
    `root = os.path.realpath((`root or os.path.dirname(`entry)));
    entries = `list(`dict.fromkeys([`entry, *(os.path.realpath(p) for p in services)]));
    import from jaclang.server.sealed_serve { sealed_root_for }
    image_root = sealed_root_for(`entry);
    if image_root is not None {
        console.print('  Loading sealed application artifacts');
        return _prepare_sealed(`entry, program, image_root, entries);
    }
    import from jaclang.compiler.driver.pass_driver { compile_progress }
    started = time.monotonic();
    active = [];
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
    previous = get_effective_default_codespace_override();
    set_effective_default_codespace('server');
    try {
        with console.status('Preparing application...') as status {
            status.update(progress);
            with compile_progress.listen(begin, finish) {
                import from jaclang.compiler.driver.compilation_context {
                    bind_options,
                    context_program
                }
                import from jaclang.compiler.driver.compile_options { CompileOptions }
                import from jaclang.runtime.prepared { publish }
                applications = [];
                for path in entries {
                    options = bind_options(
                        path,
                        program,
                        CompileOptions(
                            default_codespace='server',
                            entry_point=path,
                            project_root=`root
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
                            dev,
                            console
                        )
                    );
                }
                revision = applications[0];
                revision.services = tuple(entries[1:]);
                revision.applications = applications[1:];
                publish(revision);
                return revision;
            }
        }
    } finally {
        set_effective_default_codespace(previous);
    }
}

def _prepare(
    `entry: any,
    program: any,
    `root: any,
    entries: any,
    client: any,
    dev: any,
    console: any
) -> PreparedApplication {
    import from jaclang.runtime.prepared { PreparedApplication, publish }
    inventory = _inventory(`root, inputs=True);
    key = (_FORMAT, _identity(), inventory, entries, client, dev);
    slot = hashlib.sha256(repr((`entry, entries, client, dev)).encode()).hexdigest()[:20];
    cache = Path(`root) / '.jac' / 'cache' / 'applications' / f'{slot}.bin';
    compiler = program._get_compiler();
    revision = PreparedApplication(
        `root, `entry, client_enabled=client, services=`tuple(entries[1:]), dev=dev
    );
    record = None;
    try {
        with cache.open('rb') as stream {
            candidate = marshal.load(stream);
        }
        import from jaclang.compiler.driver.jir { cache_mode }
        if (
            not cache_mode()[0]
            and (candidate['key'] == key)
            and all(
                (
                    Path(path).is_file()
                    and ((os.stat(path).st_mtime_ns, os.stat(path).st_size) == stamp)
                ) for (path, stamp) in candidate['outputs'].items()
            )
            and all(
                (
                    Path(path).is_file()
                    and ((os.stat(path).st_mtime_ns, os.stat(path).st_size) == stamp)
                ) for (path, stamp) in candidate['dependencies'].items()
            )
        ) {
            record = candidate;
        }
    } except (OSError, ValueError, EOFError, TypeError, KeyError) {}
    builder = None;
    if client {
        import from jaclang.client.vite_client_bundle { make_client_bundle_builder }
        builder = make_client_bundle_builder(Path(`root));
        revision.client_compiler = builder._get_compiler();
        revision.client_dist = str(revision.client_compiler.vite_bundler.output_dir);
    }
    if (record is not None) {
        console.print('  Restoring prepared application');
        if not record['has_client'] {
            revision.client_compiler = None;
            revision.client_dist = '';
        }
        revision.code = record['code'];
        revision.manifests = record['manifests'];
        for (path, sections) in record['sections'].items() {
            import from jaclang.compiler.driver.compilation_context {
                program_for,
                cache_scope
            }
            actual = program_for(path, program);
            compiler._restore_sections(path, actual, sections);
        }
        for path in revision.code {
            revision.native[path] = compiler.get_native_interop_setup(path, program);
        }
        return revision;
    }
    console.print('  Compiling server modules and placement metadata...');
    before = len(program.errors_had);
    import copy;
    modules = {};
    import from jaclang.compiler.driver.pipeline { compile_application }
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
        console.print('  Compiling client and native artifacts...');
        revision.client_compiler.compile(None, Path(`entry));
        if not dev {
            bundler = revision.client_compiler.vite_bundler;
            bundler.build(
                entry_file=(revision.client_compiler.compiled_dir / '_entry.js')
            );
        }
        revision.client_compiler._emit_na_wasm(Path(`entry));
        _check(program, before);
    } else {
        revision.client_compiler = None;
        revision.client_dist = '';
    }
    routes = prepare_route_metadata(os.path.dirname(`entry), program);
    for path in entries {
        mod = modules[path];
        revision.manifests[path] = _manifest(program, path, `root, mod);
        _check(program, before);
    }
    revision.manifests[`entry]['spa_routes'] = routes;
    import from jaclang.compiler.backends.py.artifact_imports {
        runtime_sources,
        package_sources
    }
    sections = {};
    pending = `set(entries);
    for path in entries {
        pending.update(package_sources(path, `root));
    }
    for manifest in revision.manifests.values() {
        for binding in manifest['cross_bindings'] {
            pending.add(os.path.realpath(os.path.join(`root, binding['src'])));
        }
    }
    while pending {
        path = pending.pop();
        if (path in revision.code) {
            continue;
        }
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
        pending.update((runtime_sources(code, path, `root) - revision.code.keys()));
    }
    outputs = {};
    if has_client {
        for directory in (
            revision.client_compiler.compiled_dir,
            revision.client_compiler.vite_bundler.output_dir
        ) {
            if (directory and Path(directory).exists()) {
                outputs.update(_inventory(str(directory)));
            }
        }
    }
    dependencies = {};
    for path in revision.code {
        if (path not in inventory) {
            stat = os.stat(path);
            dependencies[path] = (stat.st_mtime_ns, stat.st_size);
        }
    }
    for hub in program._search_hubs() {
        for path in hub {
            if (
                os.path.isfile(path)
                and not os.path.realpath(path).startswith((`root + os.sep))
            ) {
                stat = os.stat(path);
                dependencies[path] = (stat.st_mtime_ns, stat.st_size);
            }
        }
    }
    if `any(
        (
            not os.path.isfile(path)
            or ((os.stat(path).st_mtime_ns, os.stat(path).st_size) != stamp)
        ) for (path, stamp) in inventory.items()
    ) {
        raise RuntimeError(
            'Sources changed during preparation; retry with the new revision.'
        );
    }
    _write(
        cache,
        `dict(
            key=key,
            has_client=has_client,
            code=revision.code,
            manifests=revision.manifests,
            sections=sections,
            outputs=outputs,
            dependencies=dependencies
        )
    );
    return revision;
}

def prepare_route_metadata(`root: str, program: any) -> (list[str] | None) {
    if not (Path(`root) / 'pages').is_dir() {
        return None;
    }
    import from jaclang.client.route_scanner { RouteScanner }
    import from jaclang.compiler.driver.pipeline { route_exports }
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

def reprepare_application(
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

def prepare_dynamic_module(
    path: str, program: any, application: PreparedApplication
) -> PreparedApplication {
    import from jaclang.cli.console { console }
    console.print(f'Preparing dynamically imported module: {path}');
    import from jaclang.compiler.driver.compilation_context { program_for }
    import from jaclang.runtime.prepared { publish }
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
