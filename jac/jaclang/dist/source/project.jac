"""Editable source projection of the compiler's prepared application products."""

import copy;
import json;
import os;
import pickle;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.project.config { JacConfig }
import from jaclang.runtime.prepared { PreparedApplication }
import type from jaclang.compiler.frontend.unitree { Module }


def python_source(path: str, program: JacProgram) -> tuple[str, Module | None] {
    if Path(path).suffix == '.py' {
        return (Path(path).read_text(encoding='utf-8'), None);
    }
    import from jaclang.compiler.driver.compilation_context { program_for }
    actual = program_for(path, program);
    options = copy.copy(actual.options);
    options.need_full_ast = True;
    before = len(actual.errors_had);
    module = actual.compile(file_path=path, options=options);
    if len(actual.errors_had) > before {
        raise RuntimeError(
            '\n'.join(error.pretty_print() for error in actual.errors_had[before:])
        );
    }
    if module is None or not module.gen.py {
        raise RuntimeError(f'No Python source product for {path}');
    }
    return (str(module.gen.py), module);
}


def _copy_resources(source: Path, destination: Path, output: Path) -> None {
    import from jaclang.dist.publish.sources { EXCLUDED_DIRS, EXCLUDED_SUFFIXES }
    excluded = set(EXCLUDED_DIRS);
    for (directory, dirs, files) in os.walk(str(source)) {
        parent = Path(directory);
        dirs[:] = sorted(
            name
            for name in dirs
            if name not in excluded
                and not name.startswith('.')
                and (parent / name).resolve() != output
        );
        for name in sorted(files) {
            item = parent / name;
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
) -> dict {
    directory = base / 'applications' / application.name;
    _copy_resources(project_root, directory, output);
    modules: list[dict] = [];
    record: dict = {
        'name': application.name,
        'runner': 'jaclang.runtime.source_app',
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
            import from jaclang.dist.source.native { write_native_library }
            item['native'] = write_native_library(module, directory, python_path);
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
    import from jaclang.project.capabilities {
        derive_capabilities,
        scale_intent_from_config,
        resolve_closure,
        RUNTIME
    }
    import from jaclang.project.pyvenv { make_pip_spec }
    caps = derive_capabilities(
        scale_intent_from_config(config), ['serve'] if server else []
    );
    closure = resolve_closure(caps, RUNTIME);
    dependencies = dict(closure.deps);
    dependencies.update(config.dependencies);
    return [
        make_pip_spec(name, version) for (name, version) in sorted(dependencies.items())
    ];
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
        records: list[dict] = [];
        if application is not None {
            records = [
                _write_application(item, program, base, project_root, output, sources)
                for item in [application, *application.applications]
            ];
        } elif native_module is not None {
            import from jaclang.compiler.backends.native.na_compile_pass {
                native_linked_ir_text
            }
            import from jaclang.compiler.backends.native.c_emit { emit_c }
            import from jaclang.compiler.backends.native.shared_emit {
                inject_shared_init
            }
            directory = base / 'applications' / app.name;
            directory.mkdir(parents=True);
            import from jaclang.compiler.backends.native.entry_points {
                inject_main,
                validate_native_application
            }
            llvm_ir = validate_native_application(
                native_module, kind == 'native-lib', config.memory.profile
            );
            if kind == 'native-lib' {
                (llvm_ir, exports) = inject_shared_init(
                    llvm_ir, native_module.gen.interop_manifest
                );
            } else {
                llvm_ir = inject_main(llvm_ir);
            }
            (directory / 'main.c').write_text(emit_c(llvm_ir), encoding='utf-8');
            records.append(
                {
                    'name': app.name,
                    'root': directory.relative_to(base).as_posix(),
                    'entry': 'main',
                    'modules': [],
                    'native': {
                        'source': 'main.c',
                        'output': 'main.so' if kind == 'native-lib' else 'main',
                        'kind': 'shared' if kind == 'native-lib' else 'executable'
                    }
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
        if output.exists() {
            shutil.rmtree(output);
        }
        base.replace(output);
    }
    return output;
}
