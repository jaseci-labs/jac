"""Reading app declarations never walks or parses the source workspace."""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import os;
import from jaclang.project.workspace { workspace_for_path }

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
