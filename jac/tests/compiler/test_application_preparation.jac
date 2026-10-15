"""Application preparation owns compilation; loading consumes its artifacts."""

import dis;
import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.compiler.driver.application { prepare_application }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compiler { JacCompiler }
import from jaclang.runtime.prepared {
    forget,
    prepared_manifest,
    initialize_application
}

glob SERVE_MANIFEST_SHAPES: dict[int, dict[str, set[str]]] = {
         3: {
             'manifest': {
                 'app',
                 'client',
                 'endpoint_effects',
                 'format',
                 'jaclang_version',
                 'module_manifests',
                 'persistence',
                 'private_declarations',
                 'spa_routes',
                 'surface'
             },
             'module': {
                 'app',
                 'client',
                 'endpoint_effects',
                 'persistence',
                 'private_declarations',
                 'spa_routes',
                 'surface'
             },
             'surface': {
                 'explicit_access',
                 'exposure',
                 'kind',
                 'placement',
                 'reflect',
                 'route',
                 'scheduled',
                 'src'
             }
         }
     };

"""Collect the key names of a serve manifest, its module records, and their surface entries."""
def serve_manifest_shape(manifest: dict[str, any]) -> dict[str, set[str]] {
    modules = list(manifest['module_manifests'].values());
    return {
        'manifest': set(manifest),
        'module': {key for record in modules for key in record},
        'surface': {
            key for record in modules for rec in (record.get('surface') or {}).values()
            for key in rec
        }
    };
}

test "sealing retains each colocated service's access metadata" {
    import from jaclang.dist.seal { build_serve_manifest }
    import from jaclang.server.sealed_serve { SERVE_MANIFEST_FORMAT }
    import from jaclang.cli.manifest_route { resolve_cli_version }
    with tempfile.TemporaryDirectory() as tmp {
        base = Path(tmp);
        (base / 'jac.toml').write_text(
            '[project]\nname="contracts"\ndefault-app="web"\n'
                + '[apps.web]\nkind="web-app"\nentry-point="main"\n'
                + '[apps.scoring]\nkind="service"\nentry-point="scoring"\n'
        );
        path = base / 'main.jac';
        path.write_text('def:pub ping -> int { return 1; }\n');
        (base / 'scoring.jac').write_text(
            'walker:pub Score { can run with Root entry { report 42; } }\n'
                + 'def private_score -> int { return 42; }\n'
        );
        try {
            manifest = build_serve_manifest(path, base);
            assert manifest is not None;
            assert manifest['format'] == SERVE_MANIFEST_FORMAT;
            assert manifest['jaclang_version'] == resolve_cli_version();
            shape = serve_manifest_shape(manifest);
            assert shape == SERVE_MANIFEST_SHAPES.get(SERVE_MANIFEST_FORMAT) , (
                f'serve manifest shape changed under format {SERVE_MANIFEST_FORMAT}: '
                + f'{shape}. If older readers cannot handle the change, bump '
                + 'SERVE_MANIFEST_FORMAT; then record the new shape in SERVE_MANIFEST_SHAPES.'
            );
            modules = manifest['module_manifests'];
            assert modules['main.jac']['app'] == 'web';
            assert modules['scoring.jac']['app'] == 'scoring';
            assert modules['scoring.jac']['surface']['Score']['exposure'] == 'public';
            assert 'private_score' not in modules['scoring.jac']['surface'] , (
                "the served surface lists only exposed declarations"
            );
            for entry_manifest in [manifest, *modules.values()] {
                assert 'root' not in entry_manifest , (
                    "a baked manifest must not pin the seal stage's path"
                );
                for rec in (entry_manifest.get('surface') or {}).values() {
                    assert 'module' not in rec , (
                        "a baked surface entry must not pin the seal stage's path"
                    );
                }
            }
        } finally {
            forget(str(path));
        }
    }
}

test "server entries do not build a browser app during cold or warm preparation" {
    import from jaclang.client.compiler { ViteCompiler }
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / 'main.jac';
        path.write_text('walker:pub Ping { can ping with Root entry { report 1; } }\n');
        try {
            with patch.object(
                ViteCompiler,
                'compile',
                side_effect=AssertionError('server entry requested a browser bundle')
            ) {
                for iteration in range(2) {
                    prepared = prepare_application(
                        str(path), JacProgram(), tmp, client=True
                    );
                    assert prepared.client_compiler is None;
                    assert prepared.client_dist == '';
                }
            }
        } finally {
            forget(str(path));
        }
    }
}


test "executable import discovery includes package initializers and deferred imports" {
    import from jaclang.compiler.backends.py.artifact_imports { runtime_sources }
    tmp = tempfile.mkdtemp(prefix="jac-prepared-imports-");
    try {
        base = Path(tmp);
        for name in ['pkg', 'shared'] {
            (base / name).mkdir();
        }
        expected = [
            'pkg/__init__.jac',
            'pkg/util.jac',
            'pkg/extra.jac',
            'shared/__init__.jac',
            'shared/sub.jac'
        ];
        for name in expected {
            (base / name).write_text('');
        }
        source = str(base / 'pkg' / 'main.jac');
        code = compile(
            'from .util import f\nfrom shared import sub\ndef later():\n import pkg.extra\n',
            source,
            'exec'
        );
        assert runtime_sources(code, source, tmp)
            == {str(base / name) for name in expected};
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "import discovery reads levels past a module's single-byte name pool" {
    import from jaclang.compiler.backends.py.artifact_imports { runtime_sources }
    tmp = tempfile.mkdtemp(prefix="jac-prepared-extended-");
    try {
        base = Path(tmp);
        (base / 'pkg').mkdir();
        expected = ['pkg/__init__.jac', 'pkg/util.jac'];
        for name in expected {
            (base / name).write_text('');
        }
        source = str(base / 'pkg' / 'main.jac');
        padding = '\n'.join(f'name{index}()' for index in range(300));
        code = compile(padding + '\nfrom .util import loader\n', source, 'exec');
        imports = [
            instruction
            for instruction in dis.get_instructions(code)
            if instruction.opname == 'IMPORT_NAME'
        ];
        assert imports[0].arg > 255;
        assert runtime_sources(code, source, tmp)
            == {str(base / name) for name in expected};
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "preparation does not execute modules and warm restoration does not compile" {
    tmp = tempfile.mkdtemp(prefix="jac-prepared-");
    try {
        path = Path(tmp) / 'main.jac';
        marker = Path(tmp) / 'initialized';
        (Path(tmp) / 'values.jac').write_text(
            "def:pub message -> str { return 'hello'; }\n"
        );
        path.write_text(
            "import from values { message }\n"
                + "import from pathlib { Path }\n"
                + f"with entry {{ Path({str(marker)!r}).write_text('yes'); }}\n"
                + "def:pub hello -> str { return message(); }\n"
        );
        first = prepare_application(str(path), JacProgram(), tmp);
        assert not marker.exists();
        assert str(path) in first.code;
        assert first.manifests[str(path)]['surface']['hello']['exposure'] == 'public';
        assert first.manifests[str(path)]['surface']['message']['exposure'] == 'public';
        forget(str(path));
        with patch.object(
            JacCompiler,
            '_compile_pipeline',
            side_effect=AssertionError('warm preparation entered the compiler')
        ) {
            second = prepare_application(str(path), JacProgram(), tmp);
        }
        assert not marker.exists();
        assert second.manifests == first.manifests;
        with patch.object(
            JacCompiler,
            'get_bytecode',
            side_effect=AssertionError('initialization requested compiler bytecode')
        ) {
            module: any = initialize_application(second);
        }
        assert marker.exists();
        assert module.hello() == 'hello';
    } finally {
        forget(str(Path(tmp) / 'main.jac'));
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "source changes invalidate a prepared revision and replace its access metadata" {
    tmp = tempfile.mkdtemp(prefix="jac-prepared-edit-");
    try {
        path = Path(tmp) / 'main.jac';
        path.write_text("def:pub hello -> str { return 'old'; }\n");
        prepare_application(str(path), JacProgram(), tmp);
        path.write_text("def hello -> str { return 'changed'; }\n");
        updated = prepare_application(str(path), JacProgram(), tmp);
        assert 'hello' not in updated.manifests[str(path)]['surface'] , (
            "dropping :pub makes hello private, so it leaves the served surface"
        );
        assert prepared_manifest(str(path)) == updated.manifests[str(path)];
    } finally {
        forget(str(Path(tmp) / 'main.jac'));
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "a prepare after an edit reads only the edited module's imports again" {
    import from jaclang.compiler.backends.py { artifact_imports }
    tmp = tempfile.mkdtemp(prefix="jac-prepared-imports-");
    real_specs = artifact_imports.import_specs;
    scanned: list[str] = [];
    def counting_specs(code: any, source: str) -> list[any] {
        scanned.append(os.path.basename(source));
        return real_specs(code, source);
    }
    path = Path(tmp) / 'main.jac';
    try {
        (Path(tmp) / 'mods').mkdir();
        for name in ['a', 'b', 'c'] {
            (Path(tmp) / 'mods' / f'{name}.jac').write_text(
                f"def:pub {name}_value -> int {{ return 1; }}\n"
            );
        }
        path.write_text(
            "import from mods.a { a_value }\n"
                + "import from mods.b { b_value }\n"
                + "import from mods.c { c_value }\n"
                + "def:pub total -> int { return a_value() + b_value() + c_value(); }\n"
        );
        first = prepare_application(str(path), JacProgram(), tmp);
        edited = os.path.realpath(str(Path(tmp) / 'mods' / 'a.jac'));
        old_code = first.code[edited];
        forget(str(path));
        (Path(tmp) / 'mods' / 'a.jac').write_text(
            "def:pub a_value -> int { return 2; }\n"
        );
        artifact_imports.import_specs = counting_specs;
        updated = prepare_application(str(path), JacProgram(), tmp);
        assert updated.code[edited] != old_code , "the edited module kept its old code";
        assert scanned == ['a.jac'] , (
            f"a one-module edit re-read the imports of {scanned}; only a.jac changed"
        );
    } finally {
        artifact_imports.import_specs = real_specs;
        forget(str(path));
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "a prepare resolves an unchanged module's imports against the files as they are now" {
    tmp = tempfile.mkdtemp(prefix="jac-prepared-moved-");
    path = Path(tmp) / 'main.jac';
    try {
        (Path(tmp) / 'helper.py').write_text("VALUE = 1\n");
        (Path(tmp) / 'util.py').write_text("import helper\nVALUE = helper.VALUE\n");
        path.write_text("import util;\ndef:pub value -> int { return util.VALUE; }\n");
        prepare_application(str(path), JacProgram(), tmp);
        forget(str(path));
        (Path(tmp) / 'helper.py').unlink();
        (Path(tmp) / 'helper').mkdir();
        (Path(tmp) / 'helper' / '__init__.py').write_text("VALUE = 2\n");
        updated = prepare_application(str(path), JacProgram(), tmp);
        moved = os.path.realpath(str(Path(tmp) / 'helper' / '__init__.py'));
        assert moved in updated.code , (
            "an import that moved into a package was resolved to its old path"
        );
    } finally {
        forget(str(path));
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "runtime logs and toolchain directories do not become application inputs" {
    import jaclang.compiler.driver.application as preparation;
    import from jaclang.runtime.prepared { containing_application }
    with tempfile.TemporaryDirectory(prefix='jac-prepared-log-') as tmp {
        base = Path(tmp);
        path = base / 'main.jac';
        log = base / 'server.log';
        path.write_text("def:pub hello -> str { return 'hello'; }\n");
        log.write_text('starting');
        original = preparation._manifest;
        def logging_manifest(*args: any, **kwargs: any) -> dict[str, any] {
            log.write_text(log.read_text() + '\ncompiling');
            return original(*args, **kwargs);
        }
        try {
            with patch.object(preparation, '_manifest', side_effect=logging_manifest) {
                prepare_application(str(path), JacProgram(), tmp);
            }
            log.write_text('still running');
            with patch.object(
                JacCompiler,
                '_compile_pipeline',
                side_effect=AssertionError('log invalidated revision')
            ) {
                prepare_application(str(path), JacProgram(), tmp);
            }
            assert containing_application(str(base / 'dynamic.jac')) is not None;
            assert containing_application(str(base / '.jachome' / 'runtime.jac'))
                is None;
            assert containing_application(str(base / 'node_modules' / 'package.jac'))
                is None;
            assert containing_application(
                str(base / 'vendor' / 'jac' / 'jaclang' / 'runtime' / 'graph_walk.jac'),
                'jaclang.runtime.graph_walk'
            )
                is None , "the compiler's own modules are not application code";
        } finally {
            forget(str(path));
        }
    }
}

test "sealed preparation consumes baked artifacts without compiling retained source" {
    import json;
    import hashlib;
    import sys;
    import from jaclang.jac0core { sealed }
    import site;
    site_before = sys.modules['site'];
    images_before = list(sealed._images);
    import from jaclang.compiler.driver.jir { get_module_cache_path }
    import from jaclang.server.sealed_serve { client_dist_for, serve_manifest_stamp }
    import from jaclang.cli.console { console }
    for package_name in ['prepared_sealed_test', 'site'] {
        with tempfile.TemporaryDirectory(prefix='jac-prepared-sealed-') as raw_tmp {
            tmp = os.path.realpath(raw_tmp);
            base = Path(tmp);
            path = base / f'{package_name}.jac';
            package_init = base / '__init__.jac';
            package_init.write_text('');
            models = base / 'models.jac';
            models.write_text("node Stored { has value: str = 'kept'; }\n");
            service = base / 'service.jac';
            service.write_text('import from models { Stored }\n');
            path.write_text(
                "import from models { Stored }\ndef:pub hello -> str { return 'sealed'; }\nnode Record { has value: str = 'stored'; }\n"
            );
            try {
                source_program = JacProgram();
                first = prepare_application(
                    str(path),
                    source_program,
                    tmp,
                    services=[str(package_init), str(service)]
                );
                import from jaclang.data.serializer { Serializer }
                import from jaclang.data.type_identity { resolution_scope }
                import from jaclang.runtime.prepared {
                    load_prepared_module,
                    application_namespace
                }
                source_module: any = initialize_application(first);
                payload: any = Serializer.serialize(
                    source_module.Record().__jac__, include_type=True
                );
                stored_payload: any = Serializer.serialize(
                    source_module.Stored().__jac__, include_type=True
                );
                import from jaclang.compiler.driver.ifacecache { artifact_cache_path }
                data = artifact_cache_path(str(path), source_program).read_bytes();
                init_data = artifact_cache_path(
                    str(package_init), source_program
                ).read_bytes();
                extra = {
                    name: artifact_cache_path(
                        str(base / f'{name}.jac'), source_program
                    ).read_bytes() for name in ['models', 'service']
                };
                forget(str(path));
                source_namespaces = {
                    application_namespace(application)
                    for application in [first, *first.applications]
                };
                for name in list(sys.modules) {
                    if name.split('.')[0] in source_namespaces {
                        sys.modules.pop(name, None);
                    }
                }
                bundle = base / '_precompiled';
                (bundle / sealed.python_tag()).mkdir(parents=True);
                (bundle / sealed.python_tag() / f'{package_name}.jir').write_bytes(
                    data
                );
                (bundle / sealed.python_tag() / '__init__.jir').write_bytes(init_data);
                for (name, blob) in extra.items() {
                    (bundle / sealed.python_tag() / f'{name}.jir').write_bytes(blob);
                }
                (bundle / 'MANIFEST.json').write_text(
                    json.dumps(
                        {
                            'format': sealed.MANIFEST_FORMAT,
                            'python_tag': sealed.python_tag(),
                            'jir_format_version': sealed.JIR_FORMAT_VERSION,
                            'package': package_name,
                            'modules': {
                                f'{package_name}.jac': {
                                    'module': f'{package_name}.{package_name}',
                                    'jir': f'{package_name}.jir',
                                    'package': False,
                                    'sha256': hashlib.sha256(data).hexdigest()
                                },
                                '__init__.jac': {
                                    'module': package_name,
                                    'jir': '__init__.jir',
                                    'package': True,
                                    'sha256': hashlib.sha256(init_data).hexdigest()
                                },
                                ** {
                                    f'{name}.jac': {
                                        'module': f'{package_name}.{name}',
                                        'jir': f'{name}.jir',
                                        'package': False,
                                        'sha256': hashlib.sha256(blob).hexdigest()
                                    } for (name, blob) in extra.items()
                                }
                            }
                        }
                    )
                );
                (base / '.jac' / 'serve_manifest.json').write_text(
                    json.dumps(
                        {
                            ** first.manifests[str(path)],
                            ** serve_manifest_stamp(),
                            'module_manifests': {
                                os.path.relpath(source, tmp): metadata
                                for application in [first, *first.applications]
                                for (source, metadata) in application.manifests.items()
                            }
                        }
                    )
                );
                dist = base / '.jac' / 'client' / 'dist';
                dist.mkdir(parents=True);
                (dist / 'arena.wasm').write_bytes(b'baked wasm');
                unlisted = base / 'unlisted.jac';
                unlisted.write_text("def:pub other -> str { return 'source'; }\n");
                with patch.object(console, 'print') as printed {
                    prepare_application(str(unlisted), JacProgram(), tmp);
                }
                lines = [
                    str(call.args[0])
                    for call in printed.call_args_list
                    if call.args
                ];
                assert f'  Sealed image at {tmp} does not list unlisted.jac; preparing from source'
                    in lines , lines;
                assert '  Loading sealed application artifacts' not in lines , lines;
                forget(str(unlisted));
                for retained in [path, package_init, models, service] {
                    retained.write_text('retained source must never be analyzed');
                }
                with patch.object(
                    JacCompiler,
                    '_compile_pipeline',
                    side_effect=AssertionError('sealed source was compiled')
                ), patch.object(
                    JacCompiler,
                    'get_bytecode',
                    side_effect=AssertionError('sealed startup used source loader')
                ) {
                    prepared = prepare_application(
                        str(path),
                        JacProgram(),
                        tmp,
                        services=[str(package_init), str(service)],
                        client=True,
                        dev=False
                    );
                    assert str(package_init) in prepared.code;
                    module: any = initialize_application(prepared);
                    service_module: any = load_prepared_module(str(service));
                }
                assert module.__file__ == str(path);
                assert module.__name__.endswith('.' + package_name);
                assert sys.modules['site'] is site_before;
                assert module.hello() == 'sealed';
                with resolution_scope(prepared) {
                    restored: any = Serializer.deserialize(payload);
                    assert isinstance(restored.archetype, module.Record);
                    assert restored.archetype.value == 'stored';
                    kept: any = Serializer.deserialize(stored_payload);
                    assert type(kept.archetype) is module.Stored , (
                        f'{type(kept.archetype).__module__} is not the app class '
                        + f'{module.Stored.__module__}'
                    );
                }
                assert load_prepared_module(str(models), prepared)
                    is sys.modules[module.Stored.__module__];
                service_app = prepared.applications[1];
                assert service_app.entry == str(service);
                assert service_module.Stored is not module.Stored;
                with resolution_scope(service_app) {
                    kept = Serializer.deserialize(stored_payload);
                    assert type(kept.archetype) is service_module.Stored;
                }
                assert sealed.image_for_bundle_dir(bundle) is not None;
                assert prepared.client_compiler is None;
                assert client_dist_for(str(path)) == dist;
                assert (dist / 'arena.wasm').read_bytes() == b'baked wasm';
                serve_manifest = base / '.jac' / 'serve_manifest.json';
                for (stale, expected) in [
                    (
                        {'module_manifests': {}},
                        'built by an older jac (serve manifest format unstamped)'
                    ),
                    (
                        {
                            'format': 2,
                            'jaclang_version': '0.37.11',
                            'module_manifests': {}
                        },
                        'built by jac 0.37.11 (serve manifest format 2)'
                    ),
                    (None, 'Sealed application has no serving manifest')
                ] {
                    if stale is None {
                        serve_manifest.unlink();
                    } else {
                        serve_manifest.write_text(json.dumps(stale));
                    }
                    caught = '';
                    try {
                        prepare_application(str(path), JacProgram(), tmp, dev=False);
                    } except RuntimeError as e {
                        caught = str(e);
                    }
                    assert expected in caught , caught;
                }
            } finally {
                for (name, loaded) in list(sys.modules.items()) {
                    if str(getattr(loaded, '__file__', '') or '').startswith(
                        tmp + os.sep
                    ) {
                        sys.modules.pop(name, None);
                    }
                }
                sealed._images[:] = images_before;
                forget(str(path));
            }
        }
    }
}


test "failed preparation does not replace the last working revision" {
    tmp = tempfile.mkdtemp(prefix="jac-prepared-fail-");
    try {
        path = Path(tmp) / 'main.jac';
        path.write_text("def:pub hello -> str { return 'old'; }\n");
        previous = prepare_application(str(path), JacProgram(), tmp);
        path.write_text("def hello -> str { return missing_symbol; }\n");
        failed = False;
        try {
            prepare_application(str(path), JacProgram(), tmp);
        } except RuntimeError {
            failed = True;
        }
        assert failed;
        assert prepared_manifest(str(path)) == previous.manifests[str(path)];
    } finally {
        forget(str(Path(tmp) / 'main.jac'));
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "preparation infrastructure compiles through the binary bootstrap" {
    import from jaclang.jac0 { compile_jac }
    package = Path(__file__).resolve().parents[2] / 'jaclang';
    for relative in [
        'compiler/driver/application.jac',
        'compiler/backends/py/artifact_imports.jac',
        'runtime/prepared.jac'
    ] {
        path = package / relative;
        compile(compile_jac(path.read_text(), str(path)), str(path), 'exec');
    }
}


test "prepared services with the same entry filename load independently" {
    import from jaclang.runtime.prepared { load_prepared_module }
    tmp = tempfile.mkdtemp(prefix='jac-prepared-services-');
    try {
        base = Path(tmp);
        paths: list[str] = [];
        for name in ['web', 'catalog', 'orders'] {
            directory = base / name;
            directory.mkdir();
            path = directory / 'main.jac';
            path.write_text(f"def:pub service_name -> str {{ return '{name}'; }}\n");
            paths.append(str(path));
        }
        prepare_application(paths[0], JacProgram(), tmp, paths[1:]);
        catalog: any = load_prepared_module(paths[1]);
        orders: any = load_prepared_module(paths[2]);
        assert catalog.service_name() == 'catalog';
        assert orders.service_name() == 'orders';
        assert catalog is not orders;
    } finally {
        forget(str(Path(tmp) / 'web' / 'main.jac'));
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "frozen application modules reload their artifacts without compiler services" {
    import importlib;
    import jaclang.runtime.build_services as services;
    import from jaclang.runtime.prepared {
        PreparedApplication,
        publish,
        load_prepared_module
    }
    with tempfile.TemporaryDirectory() as tmp {
        source = str(Path(tmp) / 'frozen.jac');
        application = PreparedApplication(
            tmp,
            source,
            code={source: compile('def answer(): return 42', source, 'exec')},
            dev=False
        );
        try {
            publish(application);
            with patch.object(
                services,
                'build_services',
                side_effect=AssertionError('artifact reload requested a compiler')
            ) {
                module = load_prepared_module(source, application);
                assert importlib.reload(module).answer() == 42;
            }
        } finally {
            forget(source);
        }
    }
}


test "preparation leaves compiler dependencies in their canonical runtime" {
    import jaclang;
    import from jaclang.runtime.prepared { load_prepared_module }
    compiler_root = Path(str(jaclang.__file__)).resolve().parent;
    with tempfile.TemporaryDirectory(dir=compiler_root.parent) as tmp {
        path = Path(tmp) / 'probe.jac';
        path.write_text('import from jaclang.compiler.driver.program { JacProgram }\n');
        try {
            prepared = prepare_application(
                str(path), JacProgram(), str(compiler_root.parent)
            );
            assert not any(
                Path(source).is_relative_to(compiler_root) for source in prepared.code
            );
            module = load_prepared_module(str(path), prepared);
            assert module.JacProgram is JacProgram;
        } finally {
            forget(str(path));
        }
    }
}


test "unrelated source changes do not invalidate a prepared dependency closure" {
    import jaclang.compiler.driver.application as preparation;
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / 'main.jac';
        unrelated = Path(tmp) / 'other.jac';
        path.write_text('def hello -> int { return 1; }\n');
        unrelated.write_text('def other -> int { return 1; }\n');
        original = preparation._manifest;
        def changing_manifest(*args: any, **kwargs: any) -> dict[str, any] {
            unrelated.write_text('def other -> int { return 2; }\n');
            return original(*args, **kwargs);
        }
        try {
            with patch.object(
                preparation, '_manifest', side_effect=changing_manifest
            ) {
                prepare_application(str(path), JacProgram(), tmp);
            }
            unrelated.write_text('def other -> int { return 3; }\n');
            with patch.object(
                JacCompiler,
                '_compile_pipeline',
                side_effect=AssertionError('unrelated source invalidated preparation')
            ) {
                prepare_application(str(path), JacProgram(), tmp);
            }
        } finally {
            forget(str(path));
        }
    }
}


test "changes to consumed sources still reject a torn prepared revision" {
    import jaclang.compiler.driver.application as preparation;
    with tempfile.TemporaryDirectory() as tmp {
        path = Path(tmp) / 'main.jac';
        path.write_text('def hello -> int { return 1; }\n');
        original = preparation.build_manifest;
        def changing_manifest(*args: any, **kwargs: any) -> dict[str, any] {
            path.write_text('def hello -> int { return 2; }\n');
            return original(*args, **kwargs);
        }
        failed = False;
        try {
            with patch.object(
                preparation, 'build_manifest', side_effect=changing_manifest
            ) {
                prepare_application(str(path), JacProgram(), tmp);
            }
        } except RuntimeError as error {
            failed = 'Sources changed during preparation' in str(error);
        } finally {
            forget(str(path));
        }
        assert failed;
    }
}


test "prepare warns about unmarked endpoints on cold and cached applications" {
    import from jaclang.cli.console { console }
    with tempfile.TemporaryDirectory() as tmp {
        base = Path(tmp);
        (base / 'jac.toml').write_text(
            '[project]\nname="migration"\ndefault-app="api"\n'
                + '[apps.api]\nkind="service"\nentry-point="main"\n'
        );
        path = base / 'main.jac';
        path.write_text(
            'include helpers;\n'
                + 'def plain -> int { return 1; }\n'
                + 'def:priv intentional -> int { return 2; }\n'
                + 'def _helper -> int { return 0; }\n'
                + 'def:pub exposed -> int { return 3; }\n'
                + 'walker PlainWalker {}\n'
        );
        (base / 'helpers.jac').write_text('def included -> int { return 4; }\n');
        try {
            for iteration in range(2) {
                with patch.object(console, 'warning') as warning {
                    prepared = prepare_application(str(path), JacProgram(), tmp);
                    messages = '\n'.join(
                        str(call.args[0]) for call in warning.call_args_list
                    );
                    assert 'main.jac:plain' in messages , messages;
                    assert 'main.jac:PlainWalker' in messages , messages;
                    assert 'helpers.jac:included' in messages , messages;
                    assert 'jac fix access --dry-run' in messages , messages;
                    assert 'intentional' not in messages , messages;
                    assert '_helper' not in messages , messages;
                    assert 'main.jac:exposed' not in messages , messages;
                    assert len(warning.call_args_list) == 1 , messages;
                    assert 'plain' not in prepared.manifests[str(path)]['surface'];
                }
            }
        } finally {
            forget(str(path));
        }
    }
}

test "preparation does not load native libraries used only by the client" {
    import jaclang.compiler.backends.native.link_plan as linking;
    with tempfile.TemporaryDirectory(prefix='jac-client-native-') as tmp {
        base = Path(tmp);
        path = base / 'main.jac';
        path.write_text(
            'import from graphics { draw }\n'
                + 'def app -> JsxElement { return <p>{draw()}</p>; }\n'
                + 'def:pub ping -> int { return 7; }\n'
        );
        (base / 'graphics.jac').write_text(
            'import from "lib_unavailable_on_server.so" { def render -> i64; }\n'
                + 'def draw -> int { return render(); }\n'
        );
        try {
            with patch.object(
                linking,
                'load_jit_library',
                side_effect=AssertionError('client library loaded on the server')
            ) {
                for iteration in range(2) {
                    prepared = prepare_application(str(path), JacProgram(), tmp);
                    module: any = initialize_application(prepared);
                    assert module.ping() == 7;
                    forget(str(path));
                }
            }
        } finally {
            forget(str(path));
        }
    }
}

test "preparation loads native engines for executable server calls" {
    with tempfile.TemporaryDirectory(prefix='jac-server-native-') as tmp {
        base = Path(tmp);
        path = base / 'main.jac';
        (base / 'jac.toml').write_text('[placement.pins]\n"main.positive"="native"\n');
        path.write_text(
            'def positive(value: int) -> int { return -value; }\n'
                + 'def:pub answer -> int { return positive(-5); }\n'
        );
        try {
            for iteration in range(2) {
                prepared = prepare_application(str(path), JacProgram(), tmp);
                assert prepared.native[str(path)][0] is not None;
                module: any = initialize_application(prepared);
                assert module.answer() == 5;
                forget(str(path));
            }
        } finally {
            forget(str(path));
        }
    }
}

"""Prepare `path` and report whether it restored the recorded application."""
def _restored(path: Path, `root: str) -> bool {
    import contextlib;
    import io;
    err = io.StringIO();
    try {
        with contextlib.redirect_stderr(err) {
            prepare_application(str(path), JacProgram(), `root);
        }
    } finally {
        forget(str(path));
    }
    return 'Restoring prepared application' in err.getvalue();
}

test "an in-process prepare releases the compiler state it built" {
    import from jaclang.project.kernel_compile { _APPLICATION_UNITS }
    import from jaclang.project.kernel_snapshot { _IFACE_MEMO, _IFACE_REFUSED }
    with tempfile.TemporaryDirectory(prefix='jac-prepared-release-') as tmp {
        base = Path(tmp);
        path = base / 'main.jac';
        helper = base / 'helper.jac';
        helper.write_text("def:pub twice(n: int) -> int { return n * 2; }\n");
        path.write_text(
            "import from helper { twice }\n"
            "def:pub hello -> int { return twice(21); }\n"
        );
        program = JacProgram();
        memo: any = _IFACE_MEMO;
        memo[str(base / 'stale_iface.py')] = ([], [], None);
        _IFACE_REFUSED[str(base / 'stale_refused.py')] = 'stamp';
        try {
            prepared = prepare_application(str(path), program, tmp);
            assert prepared.code , "the prepared application lost its code";
            held = [
                key
                for key in program.mod.hub
                if key.startswith(tmp)
            ];
            assert not held , (
                f"the program still holds {len(held)} parsed app modules after prepare"
            );
            assert not program.contexts , (
                f"{len(program.contexts)} per-context programs survived the prepare"
            );
            assert not [
                p
                for p in _APPLICATION_UNITS
                if p.startswith(tmp)
            ] , "kernel unit products for the app survived the prepare";
            assert not _IFACE_MEMO and not _IFACE_REFUSED , (
                "the interface memo survived the prepare"
            );
        } finally {
            forget(str(path));
        }
    }
}

def _join_all(threads: list[any]) -> list[str] {
    for thread in threads {
        thread.join(300);
    }
    return [
        thread.name
        for thread in threads
        if thread.is_alive()
    ];
}

test "a preparation on another thread neither breaks nor wedges an in-process prepare" {
    import threading;
    import jaclang.compiler.driver.application as application;
    tmp = tempfile.mkdtemp(prefix='jac-prepare-threads-');
    stuck: list[str] = [];
    try {
        base = Path(tmp);
        path = base / 'main.jac';
        extra = base / 'extra.jac';
        path.write_text("def:pub hello -> int { return 1; }\n");
        extra.write_text("def:pub other -> int { return 2; }\n");
        program = JacProgram();
        compiler = program._get_compiler();
        first = prepare_application(str(path), program, tmp);
        releasing = threading.Event();
        compiling = threading.Event();
        released = threading.Event();
        original_release = application._release_compile_state;
        original_enter = JacCompiler.enter_compile;
        def held_release(owner: any) {
            releasing.set();
            compiling.wait(5);
            try {
                original_release(owner);
            } finally {
                released.set();
            }
        }
        def held_enter(self: any, ctx: any) -> any {
            frame = original_enter(self, ctx);
            if threading.current_thread().name == 'dynamic-import'
                and not compiling.is_set() {
                compiling.set();
                released.wait(5);
            }
            return frame;
        }
        errors: list[str] = [];
        def reprepare {
            try {
                application.reprepare_application(first, program);
            } except Exception as e {
                errors.append(f"reprepare: {e}");
            }
        }
        def dynamic {
            releasing.wait(120);
            try {
                application.prepare_dynamic_module(str(extra), program, first);
            } except Exception as e {
                errors.append(f"dynamic import: {e}");
            }
        }
        path.write_text("def:pub hello -> int { return 3; }\n");
        try {
            with patch.object(application, '_release_compile_state', held_release) {
                with patch.object(JacCompiler, 'enter_compile', held_enter) {
                    threads = [
                        threading.Thread(target=reprepare, name='hmr-reprepare'),
                        threading.Thread(target=dynamic, name='dynamic-import')
                    ];
                    for thread in threads {
                        thread.start();
                    }
                    stuck.extend(_join_all(threads));
                }
            }
            assert not stuck , f"workers still running: {stuck}";
            assert not errors , errors;
            assert compiler._reentrant_depth == 0 , (
                f"the compiler was left {compiler._reentrant_depth} compiles deep"
            );
            path.write_text("def:pub hello -> int { return 4; }\n");
            assert application.reprepare_application(first, program).code;
        } finally {
            if not stuck {
                forget(str(path));
            }
        }
    } finally {
        if not stuck {
            shutil.rmtree(tmp, ignore_errors=True);
        }
    }
}

test "compiles on two threads leave the compiler free to release" {
    import threading;
    tmp = tempfile.mkdtemp(prefix='jac-compile-threads-');
    stuck: list[str] = [];
    try {
        base = Path(tmp);
        first = base / 'first.jac';
        second = base / 'second.jac';
        first.write_text("def:pub one -> int { return 1; }\n");
        second.write_text("def:pub two -> int { return 2; }\n");
        program = JacProgram();
        compiler = program._get_compiler();
        first_entered = threading.Event();
        second_entered = threading.Event();
        first_done = threading.Event();
        original_enter = JacCompiler.enter_compile;
        def held_enter(self: any, ctx: any) -> any {
            frame = original_enter(self, ctx);
            name = threading.current_thread().name;
            if name == 'first' and not first_entered.is_set() {
                first_entered.set();
                assert second_entered.wait(120) , "the second compile never started";
            } elif name == 'second' and not second_entered.is_set() {
                second_entered.set();
                assert first_done.wait(120) , (
                    "the first compile did not finish before the second"
                );
            }
            return frame;
        }
        errors: list[str] = [];
        def compile_one(path: Path) {
            try {
                if path == second {
                    first_entered.wait(60);
                }
                compiler.compile(str(path), program);
            } except Exception as e {
                errors.append(f"{path.name}: {e}");
            } finally {
                if path == first {
                    first_done.set();
                }
            }
        }
        with patch.object(JacCompiler, 'enter_compile', held_enter) {
            threads = [
                threading.Thread(target=compile_one, args=(first, ), name='first'),
                threading.Thread(target=compile_one, args=(second, ), name='second')
            ];
            for thread in threads {
                thread.start();
            }
            stuck.extend(_join_all(threads));
        }
        assert not stuck , f"workers still running: {stuck}";
        assert not errors , errors;
        assert compiler._reentrant_depth == 0 , (
            f"the compiler was left {compiler._reentrant_depth} compiles deep"
        );
        compiler.release_compile_state(program);
    } finally {
        if not stuck {
            shutil.rmtree(tmp, ignore_errors=True);
        }
    }
}

obj _ReloadingIntrospector {
    has reload: any;

    def load(force_reload: bool = False) {
        self.reload();
    }
}

obj _DevServer {
    has introspector: _ReloadingIntrospector,
        app: any = None,
        _hmr_pending: bool = True;
}

test "a dev reload waits for the preparation lock before it takes the import lock" {
    import _imp;
    import threading;
    import from jaclang.runtime.preparation_lock { PREPARATION_LOCK }
    import from jaclang.server.server { JacAPIServer }
    holding = threading.Event();
    requesting = threading.Event();
    reloading = threading.Event();
    waiting: list[bool] = [];
    def reload_under_import_lock {
        _imp.acquire_lock();
        reloading.set();
        try {
            took = PREPARATION_LOCK.acquire(timeout=5);
            waiting.append(not took);
            if took {
                PREPARATION_LOCK.release();
            }
        } finally {
            _imp.release_lock();
        }
    }
    def watcher {
        with PREPARATION_LOCK {
            holding.set();
            assert requesting.wait(60) , "the request never started";
            reloading.wait(5);
            _imp.acquire_lock();
            _imp.release_lock();
        }
    }
    def request {
        holding.wait(60);
        server = _DevServer(
            introspector=_ReloadingIntrospector(reload=reload_under_import_lock)
        );
        refresh: any = JacAPIServer._refresh_dev_endpoints;
        requesting.set();
        refresh(server);
    }
    threads = [
        threading.Thread(target=watcher, name='watcher'),
        threading.Thread(target=request, name='request')
    ];
    for thread in threads {
        thread.start();
    }
    stuck = _join_all(threads);
    assert not stuck , f"workers still running: {stuck}";
    assert waiting == [False] , (
        "the reload waited for the preparation lock while holding the import lock"
    );
}

test "a compile that leaves first keeps the closure of one still running" {
    import threading;
    tmp = tempfile.mkdtemp(prefix='jac-compile-closure-');
    stuck: list[str] = [];
    try {
        base = Path(tmp);
        first = base / 'first.jac';
        second = base / 'second.jac';
        first.write_text("def:pub one -> int { return 1; }\n");
        second.write_text("def:pub two -> int { return 2; }\n");
        program = JacProgram();
        compiler = program._get_compiler();
        first_entered = threading.Event();
        second_entered = threading.Event();
        first_done = threading.Event();
        kept: list[bool] = [];
        original_enter = JacCompiler.enter_compile;
        def held_enter(self: any, ctx: any) -> any {
            frame = original_enter(self, ctx);
            name = threading.current_thread().name;
            if name == 'first' and not first_entered.is_set() {
                first_entered.set();
                assert second_entered.wait(120) , "the second compile never started";
            } elif name == 'second' and not second_entered.is_set() {
                second_entered.set();
                assert first_done.wait(120) , (
                    "the first compile did not finish before the second"
                );
                kept.append(self._closure_opts is not None);
            }
            return frame;
        }
        errors: list[str] = [];
        def compile_one(path: Path) {
            try {
                if path == second {
                    first_entered.wait(60);
                }
                compiler.compile(str(path), program);
            } except Exception as e {
                errors.append(f"{path.name}: {e}");
            } finally {
                if path == first {
                    first_done.set();
                }
            }
        }
        with patch.object(JacCompiler, 'enter_compile', held_enter) {
            threads = [
                threading.Thread(target=compile_one, args=(first, ), name='first'),
                threading.Thread(target=compile_one, args=(second, ), name='second')
            ];
            for thread in threads {
                thread.start();
            }
            stuck.extend(_join_all(threads));
        }
        assert not stuck , f"workers still running: {stuck}";
        assert not errors , errors;
        assert kept == [True] , (
            "the compile that left first cleared the closure options of the one still running"
        );
        assert compiler._closure_opts is None;
        assert compiler._reentrant_depth == 0;
    } finally {
        if not stuck {
            shutil.rmtree(tmp, ignore_errors=True);
        }
    }
}

obj _ReloadProbe {
    has name: str,
        reaching: any,
        waited: list[bool];

    def find_spec(fullname: str, path: any = None, target: any = None) -> any {
        import from jaclang.runtime.preparation_lock { PREPARATION_LOCK }
        if fullname != self.name or target is None {
            return None;
        }
        self.reaching.set();
        took = PREPARATION_LOCK.acquire(timeout=5);
        self.waited.append(not took);
        if took {
            PREPARATION_LOCK.release();
        }
        return None;
    }
}

test "every module reload takes the preparation lock before the import lock" {
    import _imp;
    import importlib;
    import sys;
    import threading;
    import from jaclang.runtime.preparation_lock { PREPARATION_LOCK }
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    tmp = tempfile.mkdtemp(prefix='jac-reload-order-');
    name = f"reload_order_probe_{Path(tmp).name.replace('-', '_')}";
    Path(tmp, f"{name}.py").write_text("VALUE = 1\n");
    sys.path.insert(0, tmp);
    stuck: list[str] = [];
    probe = _ReloadProbe(name=name, reaching=threading.Event(), waited=[]);
    try {
        importlib.import_module(name);
        holding = threading.Event();
        requesting = threading.Event();
        errors: list[str] = [];
        def watcher {
            try {
                with PREPARATION_LOCK {
                    holding.set();
                    assert requesting.wait(60) , "the reload never started";
                    probe.reaching.wait(5);
                    _imp.acquire_lock();
                    _imp.release_lock();
                }
            } except Exception as e {
                errors.append(f"watcher: {e}");
            }
        }
        def request {
            try {
                holding.wait(60);
                requesting.set();
                Jac.jac_import(
                    target=name, base_path=tmp, reload_module=True, lng='py'
                );
            } except Exception as e {
                errors.append(f"request: {e}");
            }
        }
        sys.meta_path.insert(0, probe);
        threads = [
            threading.Thread(target=watcher, name='watcher'),
            threading.Thread(target=request, name='request')
        ];
        for thread in threads {
            thread.start();
        }
        stuck.extend(_join_all(threads));
        assert not stuck , f"workers still running: {stuck}";
        assert not errors , errors;
        assert probe.waited == [False] , (
            "the reload waited for the preparation lock while holding the import lock"
        );
    } finally {
        if probe in sys.meta_path {
            sys.meta_path.remove(probe);
        }
        sys.modules.pop(name, None);
        if tmp in sys.path {
            sys.path.remove(tmp);
        }
        if not stuck {
            shutil.rmtree(tmp, ignore_errors=True);
        }
    }
}

test "prepared applications are reused by content, not by timestamp" {
    import time;
    with tempfile.TemporaryDirectory() as tmp {
        base = Path(tmp);
        path = base / 'main.jac';
        annex = base / 'main.test.jac';
        page = base / 'pages' / 'about.txt';
        page.parent.mkdir();
        path.write_text("def:pub hello -> int { return 1; }\n");
        annex.write_text('test "hello" { assert hello() == 1; }\n');
        page.write_text('about: one');
        assert not _restored(path, tmp);
        moved = time.time_ns() - 3_600_000_000_000;
        for source in (path, annex, page) {
            os.utime(source, ns=(moved, moved));
        }
        assert _restored(path, tmp) , (
            "identical bytes under new timestamps discarded the prepared application"
        );
        assert _restored(path, tmp);
        page.write_text('about: two');
        assert not _restored(path, tmp) , "a same-size content change was reused";
        annex.unlink();
        assert not _restored(path, tmp) , "an annex deletion was reused";
    }
}

def _prepared_lookups(modules: int) -> int {
    import sys;
    lookups = [0];
    with tempfile.TemporaryDirectory() as tmp {
        base = Path(tmp);
        (base / 'mods').mkdir();
        lines: list[str] = [];
        for k in range(modules) {
            (base / 'mods' / f'm{k}.jac').write_text(
                f'walker:pub w{k} {{\n    can go with Root entry {{\n        report {k};\n    }}\n}}\n'
            );
            lines.append(f'import from mods.m{k} {{ w{k} }}\n');
        }
        path = base / 'main.jac';
        path.write_text(''.join(lines));
        prepared = prepare_application(str(path), JacProgram(), tmp);
        def tally(frame: any, event: str, arg: any) {
            if event == 'call'
                and frame.f_code.co_filename.endswith(
                    ('prepared.jac', 'prepared_loader.jac')
                ) {
                lookups[0] += 1;
            }
        }
        sys.setprofile(tally);
        try {
            initialize_application(prepared);
        } finally {
            sys.setprofile(None);
            forget(str(path));
        }
    }
    return lookups[0];
}

"""Finding a prepared module by name or package used to scan every prepared
module, so loading an application grew with the square of its module count.
Counted on a real load, not timed."""
test "loading a prepared application grows with its module count, not its square" {
    small = _prepared_lookups(8);
    large = _prepared_lookups(32);
    assert large < 6 * small , (
        f"prepared lookups went {small} -> {large} for 4x the modules"
    );
}
