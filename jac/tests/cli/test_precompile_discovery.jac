import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.compiler.driver.pipeline { PRODUCTS }
import from jaclang.compiler.driver.pipeline_types { CompilationProduct }
import jaclang.server.assembly;
import from jaclang.compiler.driver.application { prepare_application }
import from jaclang.compiler.driver.jir { get_module_cache_path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.prepared { forget }
import from jaclang.server.sealed_serve { SERVE_MANIFEST_REL }
import from jaclang.dist.precompile_bytecode {
    placement_facts_map,
    precompile_unit_context,
    precompile_unit,
    sealable_sources
}

test "application source discovery does not generate artifacts" {
    with TemporaryDirectory() as td {
        base = Path(td);
        (base / 'jac.toml').write_text(
            '[project]\nname = "discovery"\ndefault-app = "api"\n'
                + '[apps.api]\nkind = "service"\nentry-point = "api"\n'
                + '[apps.cli]\nkind = "cli"\nentry-point = "cli"\n'
        );
        (base / 'api.jac').write_text(
            'import from helper { value }\ndef:pub read -> int { return value(); }'
        );
        (base / 'helper.jac').write_text('def:pub value -> int { return 7; }');
        (base / 'cli.jac').write_text('this is deliberately invalid Jac');
        with patch.object(
            PRODUCTS[CompilationProduct.PY_IR],
            'passes',
            side_effect=AssertionError('source discovery must not generate artifacts')
        ) {
            sources = {Path(p).name for p in sealable_sources(td)};
        }
        assert sources == {'api.jac', 'helper.jac'};
        assert placement_facts_map(td)['api.jac'] == ['server'];
        import from jaclang.compiler.driver.jir { SEC_BYTECODE, read_section_bytes }
        artifact = precompile_unit(str(base / 'api.jac'), td, app='api');
        assert artifact is not None;
        assert read_section_bytes(artifact, SEC_BYTECODE);
    }
}

test "an app's client-only entry is sealed while its client modules are not" {
    with TemporaryDirectory() as td {
        base = Path(td).resolve();
        (base / 'jac.toml').write_text(
            '[project]\nname = "client_entry"\ndefault-app = "web"\n'
                + '[apps.web]\nkind = "web-app"\nentry-point = "main"\n'
        );
        (base / 'main.jac').write_text(
            'import from .page { Page }\ndef:pub app -> JsxElement {\n    <Page/>\n}\n'
        );
        (base / 'page.jac').write_text(
            'def:pub Page -> JsxElement {\n    <div>sealed</div>\n}\n'
        );
        sources = {Path(p).name for p in sealable_sources(str(base))};
        assert 'main.jac' in sources , sources;
        assert 'page.jac' not in sources , sources;
    }
}

test "discovery on a prepared stage reads the prepare's records instead of compiling" {
    with TemporaryDirectory() as td {
        base = Path(td).resolve();
        (base / 'jac.toml').write_text(
            '[project]\nname = "records"\nentry-point = "main"\n'
        );
        (base / '__init__.jac').write_text('');
        (base / 'helper.jac').write_text('def:pub value -> int { return 7; }\n');
        (base / 'main.jac').write_text(
            'import from helper { value }\ndef:pub read -> int { return value(); }\n'
        );
        main_path = str(base / "main.jac");
        try {
            prepare_application(main_path, JacProgram(), str(base));
        } finally {
            forget(main_path);
        }
        manifest = base / SERVE_MANIFEST_REL;
        manifest.parent.mkdir(parents=True, exist_ok=True);
        manifest.write_text('{}\n');
        compiled: list[str] = [];
        real_compile = JacProgram.compile;
        def recording(self: JacProgram, *args: any, **kwargs: any) -> any {
            compiled.append(str(kwargs.get('file_path', args[0] if args else '')));
            return real_compile(self, *args, **kwargs);
        }
        with patch.object(JacProgram, 'compile', recording) {
            sources = {Path(p).name for p in sealable_sources(str(base))};
        }
        assert {'main.jac', 'helper.jac'} <= sources , sources;
        assert not compiled , f"discovery compiled modules the prepare already analysed: {compiled}";
    }
}

test "a precompiled unit of a client-prepared stage looks up the module the prepare compiled" {
    with TemporaryDirectory() as td {
        base = Path(td).resolve();
        (base / 'jac.toml').write_text(
            '[project]\nname = "reuse"\nentry-point = "main"\n'
        );
        (base / '__init__.jac').write_text('');
        (base / 'helper.jac').write_text('def:pub value -> int { return 7; }\n');
        (base / 'main.jac').write_text(
            'import from helper { value }\ndef:pub read -> int { return value(); }\n'
        );
        main_path = str(base / "main.jac");
        try {
            prepare_application(
                main_path, JacProgram(), str(base), client=True, dev=False
            );
        } finally {
            forget(main_path);
        }
        manifest = base / SERVE_MANIFEST_REL;
        manifest.parent.mkdir(parents=True, exist_ok=True);
        manifest.write_text('{"client_prepared": true}\n');
        prepared = {p.resolve() for p in (base / '.jac').rglob('*.jir')};
        for name in ['main.jac', 'helper.jac'] {
            source = str(base / name);
            with precompile_unit_context(source, str(base), collect=False) {
                looked_up = get_module_cache_path(source);
            }
            assert looked_up.resolve() in prepared , (name, str(looked_up));
        }
    }
}
