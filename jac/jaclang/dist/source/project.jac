import json;
import os;
import pickle;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.project.config { JacConfig }
import from jaclang.runtime.prepared { PreparedApplication, application_namespace }
import from jaclang.compiler.driver.source_products { python_source }


def _copy_resources(source: Path, destination: Path, output: Path) {
    import from jaclang.dist.publish.sources { EXCLUDED_DIRS, EXCLUDED_SUFFIXES }
    excluded = set(EXCLUDED_DIRS);
    for (directory, dirs, files) in os.walk(str(source)) {
        parent: Path = Path(os.fsdecode(directory));
        dirs[:] = sorted(
            name
            for name in dirs
            if name not in excluded
                and not name.startswith('.')
                and (parent / os.fsdecode(name)).resolve() != output
        );
        for name in sorted(files) {
            item = parent / os.fsdecode(name);
            if item.suffix in EXCLUDED_SUFFIXES or name.startswith('.') {
                continue;
            }
            target = destination / item.relative_to(source);
            target.parent.mkdir(parents=True, exist_ok=True);
            shutil.copy2(item, target);
        }
    }
}


def _write_application(
    application: PreparedApplication,
    program: JacProgram,
    base: Path,
    project_root: Path,
    output: Path,
    sources: list[str]
) -> dict[str, any] {
    directory = base / 'applications' / application.name;
    _copy_resources(project_root, directory, output);
    modules: list[dict[str, any]] = [];
    record: dict[str, any] = {
        'name': application.name,
        'runner': 'jaclang.runtime.source_app',
        'namespace': application_namespace(application),
        'root': directory.relative_to(base).as_posix(),
        'entry': Path(application.entry).relative_to(project_root).with_suffix(
            '.py'
        ).as_posix(),
        'modules': modules,
        'services': [child.name for child in application.applications]
    };
    for path in sorted(application.code) {
        relative = Path(path).relative_to(project_root);
        python_path = relative.with_suffix('.py');
        (source, module) = python_source(path, program);
        target = directory / python_path;
        target.parent.mkdir(parents=True, exist_ok=True);
        target.write_text(source, encoding='utf-8');
        sources.append(source);
        item = {
            'path': python_path.as_posix(),
            'origin': relative.as_posix(),
            'manifest': application.manifests.get(path, {})
        };
        if module is not None and module.gen.native_engine is not None {
            import from jaclang.dist.native_product { write_native_product }
            item['native'] = write_native_product(
                module, directory, Path("native") / python_path, program=program
            );
        }
        modules.append(item);
    }
    if application.semantic {
        semantic = directory / 'semantic.pickle';
        with semantic.open('wb') as stream {
            pickle.dump(
                {
                    Path(path).relative_to(project_root).with_suffix(
                        '.py'
                    ).as_posix(): info for (path, info) in application.semantic.items()
                },
                stream
            );
        }
        record['semantic'] = semantic.relative_to(base).as_posix();
    }
    if application.client_compiler is not None {
        import from jaclang.dist.source.client { write_client }
        record['client_dist'] = write_client(application, base);
    }
    return record;
}


def _requirements(config: JacConfig, server: bool) -> list[str] {
    import from jaclang.project.providers { get_python_provider, resolve_plan }
    plan = resolve_plan(config, action='serve' if server else 'run');
    dependencies = [
        dependency
        for dependency in plan.for_ecosystem('python')
        if dependency.name.split('[', 1)[0].lower().replace('_', '-') != 'jaclang'
    ];
    return sorted(get_python_provider().specs_for(dependencies));
}


def export_project(
    config: JacConfig,
    name: str,
    output: Path,
    entry_override: str = '',
    force: bool = False
) -> Path {
    import from jaclang.project.app_kinds { kind_has_client, kind_has_server }
    import from jaclang.compiler.driver.application { prepare_application }
    import from jaclang.server.assembly { service_apps, gateway_colocates }
    import from jaclang.dist.publish.runtime_vendor { vendor_runtime }
    import from jaclang.runtime.source_app { SOURCE_FORMAT }
    if config.project_root is None {
        raise ValueError('Source export requires a project root');
    }
    project_root = config.project_root.resolve();
    output = output.resolve();
    if output == project_root or project_root.is_relative_to(output) {
        raise ValueError('The export directory must not contain the source project');
    }
    if output.exists() and (not force or not output.is_dir()) {
        raise FileExistsError(f'Export destination already exists: {output}');
    }
    app = config.resolve_app(name);
    kind = config.resolved_kind(app);
    entry_path = entry_override or app.entry_path(str(project_root));
    services = service_apps(config, app)
        if gateway_colocates(config) and kind_has_server(kind)
        else [];
    program = JacProgram();
    application: PreparedApplication | None = None;
    native_module = None;
    if kind in ('native-binary', 'native-lib', 'cli-native') {
        import from jaclang.compiler.driver.pipeline_runner { native_application }
        (native_module, native_options) = native_application(program, entry_path);
        if program.errors_had {
            raise RuntimeError(
                '\n'.join(error.pretty_print() for error in program.errors_had)
            );
        }
        if native_module is None or native_module.gen.llvm_ir is None {
            raise RuntimeError(
                f'Native lowering produced no artifact for {entry_path}'
            );
        }
    } else {
        application = prepare_application(
            entry_path,
            program,
            str(project_root),
            services=[service.entry_path(str(project_root)) for service in services],
            client=kind_has_client(kind),
            dev=False
        );
        application.name = app.name;
        for (child, service) in zip(application.applications, services) {
            child.name = service.name;
        }
    }
    output.parent.mkdir(parents=True, exist_ok=True);
    with tempfile.TemporaryDirectory(
        prefix='.jac-source-', dir=output.parent
    ) as temporary {
        base = Path(temporary) / 'project';
        base.mkdir();
        sources: list[str] = [];
        records: list[dict[str, any]] = [];
        if application is not None {
            records = [
                _write_application(item, program, base, project_root, output, sources)
                for item in [application, *application.applications]
            ];
        } elif native_module is not None {
            import from jaclang.dist.native_product { write_native_product }
            directory = base / 'applications' / app.name;
            directory.mkdir(parents=True);
            native = write_native_product(
                native_module,
                directory,
                Path('main'),
                shared=kind == 'native-lib',
                memory=native_options.memory_profile or "",
                program=program
            );
            records.append(
                {
                    'name': app.name,
                    'root': directory.relative_to(base).as_posix(),
                    'entry': 'main',
                    'modules': [],
                    'native': native
                }
            );
        }
        data = {'format': SOURCE_FORMAT, 'entry': app.name, 'applications': records};
        (base / 'project.json').write_text(
            json.dumps(data, indent=2) + '\n', encoding='utf-8'
        );
        vendor_runtime(
            base,
            sources,
            extra_seeds=['jaclang.dist.source.build', 'jaclang.dist.source.run'],
            prepared=application is not None
        );
        if any(base.rglob('*.c')) {
            import from jaclang.toolchains.c_backend {
                c_backend_provenance,
                c_backend_license
            }
            (base / 'licenses').mkdir(exist_ok=True);
            shutil.copy2(c_backend_license(), base / 'licenses' / 'llvm-cbe.txt');
            (base / 'native-toolchain.json').write_text(
                json.dumps(c_backend_provenance(), indent=2) + '\n', encoding='utf-8'
            );
        }
        (base / 'requirements.txt').write_text(
            '\n'.join(_requirements(config, kind_has_server(kind))) + '\n',
            encoding='utf-8'
        );
        (base / 'main.py').write_text(
            'from pathlib import Path\nfrom jaclang.dist.source.run import main\n'
                + 'raise SystemExit(main(str(Path(__file__).with_name("project.json"))))\n',
            encoding='utf-8'
        );
        (base / 'build.py').write_text(
            'from pathlib import Path\nfrom jaclang.dist.source.build import build\n'
                + 'build(Path(__file__).parent)\n',
            encoding='utf-8'
        );
        (base / 'README.md').write_text(
            '# Exported application\n\n'
                + 'Install Python dependencies with `python -m pip install -r requirements.txt`.\n'
                + 'Run `python build.py` to build JavaScript and native C, then `python main.py`.\n'
                + 'Use `--app`, `--host` and `--port` to select the application and listener.\n'
                + 'Application code is under `applications/`; `jaclang/` contains the shared runtime source.\n',
            encoding='utf-8'
        );
        previous = Path(temporary) / 'previous';
        if output.exists() {
            output.replace(previous);
        }
        try {
            base.replace(output);
        } except BaseException {
            if previous.exists() {
                previous.replace(output);
            }
            raise;
        }
    }
    return output;
}
