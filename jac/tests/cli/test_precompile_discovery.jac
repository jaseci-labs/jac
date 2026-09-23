import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import jaclang.compiler.driver.pipeline_runner as pipeline;
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
            pipeline,
            'get_py_code_gen',
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
