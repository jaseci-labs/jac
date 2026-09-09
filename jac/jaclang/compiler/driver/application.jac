"""Prepare source applications before executing their modules.

The revision cache contains executable code, compiler restoration sections and
serving metadata. Runtime consumers never reconstruct these from source.
"""
import hashlib;
import marshal;
import os;
import sys;
import tempfile;
import time;
import from pathlib { Path }
import from jaclang.runtime.prepared { PreparedApplication, publish }
glob _FORMAT: int = 1,
     _SKIP: set[str] = {'.jac', '.git', '.venv', 'venv', 'node_modules', '__pycache__'};

def _inventory(`root: any) -> dict {
    result = {};
    for (directory, dirs, files) in os.walk(`root) {
        dirs[:] = sorted(
            d
            for d in dirs
            if ((d not in _SKIP) and not d.startswith('.'))
        );
        for name in sorted(files) {
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

def _identity() -> tuple {
    import from jaclang.compiler.driver.jir { compiler_generation }
    return (
        compiler_generation(),
        sys.implementation.cache_tag,
        os.environ.get('JAC_PROFILE', '')
    );
}

def _write(path: any, value: any) -> None {
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

def _sections(path: any) -> dict {
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
    import from jaclang.compiler.driver.schedules { get_boundary_analysis_sched }
    for source in sources {
        manifest = source.gen.interop_manifest;
        if (manifest and not (manifest.func_access or manifest.walker_access)) {
            program.run_schedule(source, get_boundary_analysis_sched());
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
            access = getattr(`node, 'access', None);
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

def _check(program: any, before: any) -> None {
    errors = program.errors_had[before:];
    if errors {
        raise RuntimeError('\n'.join(e.pretty_print() for e in errors));
    }
}

"""Build or restore an application without executing application modules.

    Each call establishes a new filesystem snapshot. Publish happens only after
    every required artifact has been prepared successfully.
    """
def prepare_application(
    `entry: str,
    program: any,
    `root: (str | None) = None,
    services: any = (),
    client: bool = False,
    dev: bool = True
) -> PreparedApplication {
    import from jaclang.cli.console { console }
    import from jaclang.compiler.placement.ownership { workspace_snapshot }
    `entry = os.path.realpath(`entry);
    `root = os.path.realpath((`root or os.path.dirname(`entry)));
    entries = `list(`dict.fromkeys([`entry, *(os.path.realpath(p) for p in services)]));
    import from jaclang.compiler.driver.pass_driver { compile_progress }
    started = time.monotonic();
    active = [];
    completed: list[int] = [0];
    def begin(path: any) -> None {
        active.append(path);
    }
    def finish(path: any) -> None {
        if (path in active) {
            active.remove(path);
        }
        completed[0] += 1;
    }
    def progress() -> str {
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
            with workspace_snapshot(), compile_progress.listen(begin, finish) {
                return _prepare(`entry, program, `root, entries, client, dev, console);
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
    inventory = _inventory(`root);
    import from jaclang.compiler.placement.ownership { seed_workspace_snapshot }
    seed_workspace_snapshot(`root, inventory);
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
        revision.code = record['code'];
        revision.manifests = record['manifests'];
        for (path, sections) in record['sections'].items() {
            actual = compiler.selfhost.resolve(path, program);
            compiler._restore_sections(path, actual, sections);
        }
        for path in revision.code {
            revision.native[path] = compiler.get_native_interop_setup(path, program);
        }
        publish(revision);
        return revision;
    }
    console.print('  Compiling server modules and placement metadata...');
    before = len(program.errors_had);
    for path in entries {
        program.compile(path);
        _check(program, before);
    }
    if client {
        console.print('  Compiling client and native artifacts...');
        revision.client_compiler.compile(None, Path(`entry));
        revision.client_compiler._emit_na_wasm(Path(`entry));
        if not dev {
            bundler = revision.client_compiler.vite_bundler;
            bundler.build(
                entry_file=(revision.client_compiler.compiled_dir / '_entry.js')
            );
        }
        _check(program, before);
    }
    import from jaclang.compiler.frontend { unitree as uni }
    for path in entries {
        mod = program.find_module(path);
        if (mod is None) {
            mod = program.compile(path);
        }
        for item in mod.body {
            if (isinstance(item, uni.Import) and item.is_jac and item.from_loc) {
                source = item.from_loc.resolve_relative_path();
                if (source and source.endswith('.jac') and os.path.isfile(source)) {
                    if (program.find_module(source) is None) {
                        program.compile(source);
                    }
                }
            }
        }
        _check(program, before);
        revision.manifests[path] = _manifest(program, path, `root, mod);
        _check(program, before);
    }
    revision.manifests[`entry]['spa_routes'] = prepare_route_metadata(
        os.path.dirname(`entry)
    );
    import from jaclang.compiler.backends.py.artifact_imports { runtime_sources }
    sections = {};
    pending = `set(entries);
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
            raise RuntimeError(f'No executable artifact produced for {path}');
        }
        revision.code[path] = code;
        sections[path] = _sections(path);
        revision.native[path] = compiler.get_native_interop_setup(path, program);
        pending.update((runtime_sources(code, path, `root) - revision.code.keys()));
    }
    outputs = {};
    if client {
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
            code=revision.code,
            manifests=revision.manifests,
            sections=sections,
            outputs=outputs,
            dependencies=dependencies
        )
    );
    publish(revision);
    return revision;
}

"""Resolve the route table during preparation, including metadata-only builds."""
def prepare_route_metadata(`root: str) -> (list[str] | None) {
    if not (Path(`root) / 'pages').is_dir() {
        return None;
    }
    import from jaclang.client.route_scanner { RouteScanner, resolve_route_exports }
    scanner = RouteScanner(
        project_root=Path(`root), route_exports_of=resolve_route_exports
    );
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
    return prepare_application(
        application.entry,
        program,
        `root=application.root,
        services=(*application.services, path),
        client=application.client_enabled,
        dev=application.dev
    );
}
