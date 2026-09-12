"""Standalone client builds finish compilation before starting the bundler."""

import tempfile;
import weakref;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.client.targets.web_target { WebTarget }
import from jaclang.client.vite_bundler { ViteBundler }
import from jaclang.runtime.runtime { JacRuntime as Jac }

test "standalone client build releases application trees before bundling" {
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp).resolve();
        entry_path = project_dir / "main.jac";
        entry_path.write_text('def:pub launch -> any { return <div>lifetime</div>; }');
        (project_dir / "jac.toml").write_text(
            '[project]\nname = "lifetime"\nkind = "web-app"\n'
        );
        (project_dir / "package.json").write_text(
            '{"name":"lifetime","version":"0.0.0"}'
        );
        Jac.set_full_target_path(str(entry_path));
        reached: list[bool] = [];
        trees: list = [];
        program = Jac.get_program();
        original_compile = program.compile;
        def compile(*args: any, **kwargs: any) -> any {
            mod = original_compile(*args, **kwargs);
            if mod.loc.mod_path == str(entry_path) {
                trees.append(weakref.ref(mod));
            }
            return mod;
        }
        def bundle(self: ViteBundler, *args: any, **kwargs: any) {
            program = Jac.get_program();
            assert not program.source_store.units , (
                "application source trees remain live while the bundler runs"
            );
            assert not program.contexts , (
                "application compilation contexts remain live while the bundler runs"
            );
            assert trees and all(ref() is None for ref in trees) , (
                "the bundler starts while an application syntax tree is still reachable"
            );
            reached.append(True);
            self.output_dir.mkdir(parents=True, exist_ok=True);
            (self.output_dir / "client.test.js").write_text(
                'export function launch() {}'
            );
        }
        with patch.object(program, "compile", compile), patch.object(
            ViteBundler, "build", bundle
        ) {
            WebTarget().build(entry_path, project_dir);
        }
        assert reached == [True];
        index = next(project_dir.rglob("index.html")).read_text();
        assert '"function": "launch"' in index;
    }
}

test "prepared native assets and exports survive the bundler clearing its output" {
    import shutil;
    import from types { ModuleType }
    import from jaclang.client.compiler { ViteCompiler }
    import from jaclang.client.vite_client_bundle { make_client_bundle_builder }
    with tempfile.TemporaryDirectory() as tmp {
        project_dir = Path(tmp).resolve();
        entry_path = project_dir / "main.jac";
        entry_path.write_text("# prepared build\n");
        (project_dir / "jac.toml").write_text('[project]\nname = "prepared"\n');
        Jac.set_full_target_path(str(entry_path));
        loaded = ModuleType("prepared");
        loaded.__file__ = str(entry_path);
        builder = make_client_bundle_builder(project_dir);
        assets = {
            "native.wasm": b"\x00asm\x01\x00\x00\x00",
            "native.wasm.imports.json": b'{"imports": {}}'
        };
        def bundle(self: ViteBundler, *args: any, **kwargs: any) {
            if self.output_dir.exists() {
                shutil.rmtree(self.output_dir);
            }
            self.output_dir.mkdir(parents=True);
            (self.output_dir / "client.test.js").write_text(
                "export const ready = true;"
            );
        }
        with patch.object(
            ViteCompiler, "compile", return_value=(["launch"], ["ready"])
        ), patch.object(ViteCompiler, "_wasm_targets", return_value=[entry_path]), patch.object(
            ViteCompiler, "_compile_wasm_module", return_value=assets
        ), patch(
            "jaclang.compiler.boundary_audit.boundary_audit",
            return_value={"prepared": True}
        ) {
            inputs = builder.prepare(loaded);
        }
        with patch.object(ViteBundler, "build", bundle) {
            result = builder.bundle(inputs);
        }
        assert result.module_name == "prepared";
        assert result.client_functions == ["launch"];
        assert result.client_globals == ["ready"];
        assert result.code == "export const ready = true;";
        output = builder._get_compiler().vite_bundler.output_dir;
        for (name, content) in assets.items() {
            assert (output / name).read_bytes() == content;
        }
        import json;
        assert json.loads((output / "boundaries.json").read_text())
            == {"prepared": True};
    }
}
