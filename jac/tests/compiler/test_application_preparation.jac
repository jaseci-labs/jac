"""Application preparation owns compilation; loading consumes its artifacts."""

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

test "sealing retains each colocated service's access metadata" {
    import from jaclang.dist.seal { build_serve_manifest }
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
            modules = manifest['module_manifests'];
            assert modules['main.jac']['app'] == 'web';
            assert modules['scoring.jac']['app'] == 'scoring';
            assert modules['scoring.jac']['walker_access']['Score'] is False;
            assert modules['scoring.jac']['func_access']['private_score'] is True;
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
        assert first.manifests[str(path)]['func_access']['hello'] is False;
        assert first.manifests[str(path)]['func_access']['message'] is False;
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
        assert updated.manifests[str(path)]['func_access']['hello'] is True;
        assert prepared_manifest(str(path)) == updated.manifests[str(path)];
    } finally {
        forget(str(Path(tmp) / 'main.jac'));
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
        def logging_manifest(*args: any, **kwargs: any) -> dict {
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
    import from jaclang.server.sealed_serve { client_dist_for }
    for package_name in ['prepared_sealed_test', 'site'] {
        with tempfile.TemporaryDirectory(prefix='jac-prepared-sealed-') as tmp {
            base = Path(tmp);
            path = base / f'{package_name}.jac';
            package_init = base / '__init__.jac';
            package_init.write_text('');
            path.write_text("def:pub hello -> str { return 'sealed'; }\n");
            try {
                source_program = JacProgram();
                first = prepare_application(
                    str(path), source_program, tmp, services=[str(package_init)]
                );
                import from jaclang.compiler.driver.compilation_context {
                    artifact_cache_path
                }
                data = artifact_cache_path(str(path), source_program).read_bytes();
                init_data = artifact_cache_path(
                    str(package_init), source_program
                ).read_bytes();
                forget(str(path));
                bundle = base / '_precompiled';
                (bundle / sealed.python_tag()).mkdir(parents=True);
                (bundle / sealed.python_tag() / f'{package_name}.jir').write_bytes(
                    data
                );
                (bundle / sealed.python_tag() / '__init__.jir').write_bytes(init_data);
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
                                }
                            }
                        }
                    )
                );
                (base / '.jac' / 'serve_manifest.json').write_text(
                    json.dumps(
                        {
                            ** first.manifests[str(path)],
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
                path.write_text('retained source must never be analyzed');
                package_init.write_text('retained initializer must never be analyzed');
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
                        str(path), JacProgram(), tmp, client=True, dev=False
                    );
                    assert str(package_init) in prepared.code;
                    module: any = initialize_application(prepared);
                }
                assert module.__file__ == str(path);
                assert module.__name__.endswith('.' + package_name);
                assert sys.modules['site'] is site_before;
                assert module.hello() == 'sealed';
                assert sealed.image_for_bundle_dir(bundle) is not None;
                assert prepared.client_compiler is None;
                assert client_dist_for(str(path)) == dist;
                assert (dist / 'arena.wasm').read_bytes() == b'baked wasm';
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
