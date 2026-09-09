"""Workspace reconciliation is shared by preparation consumers and persisted."""

import shutil;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import jaclang.compiler.placement.ownership as ownership;
import from jaclang.compiler.placement.workspace { workspace_for_path }


test "ownership cache survives a new process state without parsing" {
    tmp = tempfile.mkdtemp(prefix="jac-ownership-");
    try {
        base = Path(tmp);
        (base / 'jac.toml').write_text(
            '[project]\nname="snapshot"\ndefault-app="a"\n'
            + '[apps.a]\nkind="service"\npath="a"\n'
            + '[apps.b]\nkind="service"\npath="b"\n'
        );
        for name in ['a', 'b'] {
            (base / name).mkdir();
            (base / name / 'main.jac').write_text(
                "def:pub hello -> str { return 'ok'; }\n"
            );
        }
        ws = workspace_for_path(str(base / 'a' / 'main.jac'));
        assert ws is not None;
        with patch.object(ownership.os, 'walk', wraps=ownership.os.walk) as walk {
            with ownership.workspace_snapshot() {
                first = ownership.consumer_graph(ws);
                assert ownership.consumer_graph(ws) == first;
            }
            assert walk.call_count == 1;
        }
        ownership._graphs.clear();
        ownership._imports.clear();
        with patch.object(
            ownership, 'parse', side_effect=AssertionError('ownership reparsed unchanged source')
        ) {
            with ownership.workspace_snapshot() {
                assert ownership.consumer_graph(ws) == first;
            }
        }
        (base / 'a' / 'extra.jac').write_text('glob added = 1;\n');
        with ownership.workspace_snapshot() {
            changed = ownership.consumer_graph(ws);
            assert str(base / 'a' / 'extra.jac') in changed[0];
        }
        (base / 'a' / 'extra.jac').unlink();
        with ownership.workspace_snapshot() {
            assert ownership.consumer_graph(ws) == first;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
