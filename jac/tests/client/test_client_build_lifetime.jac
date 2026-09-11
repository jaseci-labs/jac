"""Standalone client builds finish compilation before starting the bundler."""

import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.client.targets.web_target { WebTarget }
import from jaclang.client.vite_bundler { ViteBundler }
import from jaclang.runtime.runtime { JacRuntime as Jac }

test "standalone client build releases application trees before bundling" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp).resolve();
        entry = project_dir / "main.jac";
        entry.write_text('def:pub app -> any { return <div>lifetime</div>; }');
        (project_dir / "jac.toml").write_text(
            '[project]\nname = "lifetime"\nkind = "web-app"\n'
        );
        (project_dir / "package.json").write_text('{"name":"lifetime","version":"0.0.0"}');
        reached: list[bool] = [];

        def bundle(self: ViteBundler, *args: any, **kwargs: any) {
            program = Jac.get_program();
            assert not program.source_store.units , (
                "application source trees remain live while the bundler runs"
            );
            assert not program.contexts , (
                "application compilation contexts remain live while the bundler runs"
            );
            reached.append(True);
            self.output_dir.mkdir(parents=True, exist_ok=True);
            (self.output_dir / "client.js").write_text('export function app() {}');
        }

        with patch.object(ViteBundler, "build", bundle) {
            WebTarget().build(entry, project_dir);
        }
        assert reached == [True];
    }
}
