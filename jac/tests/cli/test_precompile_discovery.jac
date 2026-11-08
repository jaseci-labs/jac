import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.compiler.driver.pipeline { PRODUCTS }
import from jaclang.compiler.driver.pipeline_types { CompilationProduct }
import jaclang.server.assembly;
import from jaclang.compiler.driver.application { prepare_application }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.prepared { forget }
import from jaclang.compiler.driver.jir {
    SEC_BYTECODE,
    SEC_IFACE,
    precompiled_jir_matches_source,
    read_section_bytes,
    write_module_cache
}
import from jaclang.dist.precompile_bytecode {
    _cache_variant,
    compiler_identity,
    _reusable_cache_entry,
    precompile_unit_context,
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


test "a precompiled unit finds the module the application prepare compiled" {
    with TemporaryDirectory() as td {
        base = Path(td);
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
            prepare_application(main_path, JacProgram(), td);
        } finally {
            forget(main_path);
        }
        prepared = {p.resolve() for p in (base / '.jac').rglob('*.jir')};
        for name in ['main.jac', 'helper.jac'] {
            source = str(base / name);
            with precompile_unit_context(source, td, collect=False) {
                hit = _reusable_cache_entry(source, td);
            }
            assert hit is not None , name;
            assert hit[2].resolve() in prepared , (name, str(hit[2]));
        }
    }
}

test "a precompiled unit reused from the application prepare passes the seal check" {
    with TemporaryDirectory() as td {
        base = Path(td);
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
            prepare_application(main_path, JacProgram(), td);
        } finally {
            forget(main_path);
        }
        helper = str(base / 'helper.jac');
        with precompile_unit_context(helper, td, collect=False) {
            hit = _reusable_cache_entry(helper, td);
            assert hit is not None;
            (options, codespace, cache_path) = hit;
            bytecode = read_section_bytes(cache_path.read_bytes(), SEC_BYTECODE);
            with _cache_variant(options, codespace) {
                write_module_cache(helper, bytecode, {SEC_IFACE: b"iface"});
            }
        }
        def compiled -> set[str] {
            return {p.name for p in (base / '.jac').rglob('*.jir')};
        }
        before = compiled();
        artifact = precompile_unit(helper, td);
        assert artifact is not None;
        assert compiled() == before , sorted(compiled() - before);
        assert precompiled_jir_matches_source(
            artifact, helper, compiler_identity(), td
        ) , "the reused unit carries a module key the seal check rejects";
    }
}
