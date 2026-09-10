"""Reading app declarations never walks or parses the source workspace."""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import os;
import from jaclang.compiler.placement.workspace { workspace_for_path }
import from jaclang.compiler.driver.compilation_context { SourceStore }
import from jaclang.compiler.driver.program { JacProgram }

test "unrelated broken source is not discovery input" {
    with TemporaryDirectory() as td {
        base = Path(td);
        (base / 'jac.toml').write_text('[apps.a]\nkind="service"\nentry-point="a"\n');
        (base / 'a.jac').write_text('def:pub hello -> str { return "ok"; }\n');
        (base / 'unrelated.jac').write_text('this is not valid Jac !!!');
        with patch.object(
            os, 'walk', side_effect=AssertionError('source scan during declarations')
        ) {
            spec = workspace_for_path(str(base / 'a.jac'));
            assert spec is not None;
            assert list(spec.apps) == ['a'];
            assert spec.app_for_path(str(base / 'unrelated.jac')) is None;
        }
    }
}

test "source revisions parse once and return isolated syntax" {
    store = SourceStore();
    program = JacProgram();
    (first, failed) = store.parse(
        'glob value = 1;\n', '/tmp/context-source.jac', program, []
    );
    assert not failed;
    (second, failed) = store.parse(
        'glob value = 1;\n', '/tmp/context-source.jac', program, []
    );
    assert not failed and store.parses == 1 and store.hits == 1;
    assert first is not second and first.body[0] is not second.body[0];
    store.parse('glob value = 2;\n', '/tmp/context-source.jac', program, []);
    assert store.parses == 2 and len(store.units) == 1;
}
