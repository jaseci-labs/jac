import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.compiler.driver.pipeline { PRODUCTS }
import from jaclang.compiler.driver.pipeline_types { CompilationProduct }
import jaclang.server.assembly;
import from jaclang.dist.precompile_bytecode {
    placement_facts_map,
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
