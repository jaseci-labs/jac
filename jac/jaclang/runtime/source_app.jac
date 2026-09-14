import argparse;
import builtins;
import json;
import os;
import pickle;
import from pathlib { Path }
import from jaclang.runtime.prepared {
    PreparedApplication,
    initialize_application,
    publish
}

glob SOURCE_FORMAT: int = 1;

def artifact_path(base: Path, relative: str) -> Path {
    path = (base / relative).resolve();
    if not path.is_relative_to(base.resolve()) {
        raise ValueError(f'Artifact path escapes its project: {relative}');
    }
    return path;
}

def _load_application(record: dict, base: Path) -> PreparedApplication {
    directory = artifact_path(base, record['root']);
    entry_path = artifact_path(directory, record['entry']);
    application = PreparedApplication(
        str(directory),
        str(entry_path),
        name=record['name'],
        namespace=record.get('namespace', ''),
        scope_imports=record.get('scope_imports', True),
        dev=False,
        client_enabled=bool(record.get('client_dist')),
        client_dist=str(artifact_path(base, record['client_dist']))
            if record.get('client_dist')
            else ''
    );
    for item in record['modules'] {
        source = artifact_path(directory, item['path']);
        path = str(source);
        application.code[path] = builtins.compile(
            source.read_text(encoding='utf-8'), path, 'exec'
        );
        application.origins[path] = item['origin'];
        metadata = dict(item.get('manifest', {}));
        metadata['root'] = str(directory);
        application.manifests[path] = metadata;
        if item.get('native') {
            import from jaclang.runtime.interop_bridge { NativeLibrary, NativeCallback }
            native = item['native'];
            engine = NativeLibrary(
                str(artifact_path(directory, native['output'])),
                bindings=[NativeCallback(**binding) for binding in native['callbacks']]
            );
            application.native[path] = (engine, engine.functions);
        }
    }
    if record.get('semantic') {
        semantic = artifact_path(base, record['semantic']);
        with semantic.open('rb') as stream {
            scopes = pickle.load(stream);
        }
        application.semantic = {
            str(artifact_path(directory, path)): info for (path, info) in scopes.items()
        };
    }
    return application;
}

def load_runtime(directory: Path) {
    manifest = directory / 'runtime.json';
    if manifest.is_file() {
        record = json.loads(manifest.read_text(encoding='utf-8'));
        publish(_load_application(record, directory));
    }
}

def load_project(manifest_path: Path, name: str = '') -> PreparedApplication {
    base = manifest_path.resolve().parent;
    data = json.loads(manifest_path.read_text(encoding='utf-8'));
    if data.get('format') != SOURCE_FORMAT {
        raise ValueError(f'Unsupported source artifact format: {data.get("format")}');
    }
    selected = name or data['entry'];
    applications: dict[str, PreparedApplication] = {};
    for record in data['applications'] {
        application = _load_application(record, base);
        applications[application.name] = application;
    }
    if selected not in applications {
        raise ValueError(
            f'No exported app named {selected!r}; available: {", ".join(applications)}'
        );
    }
    primary = applications[selected];
    record = next(
        item
        for item in data['applications']
        if item['name'] == selected
    );
    primary.applications = [
        applications[service] for service in record.get('services', [])
    ];
    primary.services = tuple(application.entry for application in primary.applications);
    publish(primary);
    return primary;
}

def main(manifest_path: str, name: str = '', argv: list[str] | None = None) -> int {
    import sys;
    application = load_project(Path(manifest_path), name);
    import from jaclang.project.config { JacConfig, set_config }
    import from jaclang.project.app_kinds { kind_has_server }
    config = JacConfig.load(Path(application.root) / 'jac.toml');
    set_config(config);
    served = config.resolve_app(application.name);
    server_enabled = kind_has_server(config.resolved_kind(served));
    arguments = list(sys.argv[1:] if argv is None else argv);
    overrides: dict = {'dev': False, 'no_client': not application.client_enabled};
    if server_enabled {
        parser = argparse.ArgumentParser(description='Run the exported server');
        parser.add_argument('--host', `default='');
        parser.add_argument('--port', type=int, `default=0);
        (args, arguments) = parser.parse_known_args(arguments);
        if args.host {
            overrides['host'] = args.host;
        }
        if args.port {
            overrides['port'] = args.port;
            overrides['strict_port'] = True;
        }
        import from jaclang.scale.runtime.provider { mark_scale_runtime }
        mark_scale_runtime();
    }
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    Jac.set_base_path(application.root);
    Jac.set_full_target_path(application.entry);
    context = Jac.create_j_context(None, application.root, application.entry);
    Jac.set_context(context);
    previous_argv = sys.argv;
    sys.argv = [application.entry, *arguments];
    try {
        module = initialize_application(application, config, served);
        context.mem.unit_exit();
        if not server_enabled {
            return 0;
        }
        import from jaclang.server.settings { ServeSettings }
        import from jaclang.server.server { JacAPIServer }
        settings = ServeSettings.load(application.root, overrides);
        server = JacAPIServer(
            module_name=module.__name__, base_path=application.root, settings=settings
        );
        return server.start(no_client=not application.client_enabled);
    } finally {
        sys.argv = previous_argv;
        context.close();
    }
}
