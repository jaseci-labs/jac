"""HMR must re-emit wasm when a native module the client imports changes.

`jac run --dev` compiles the client's `na` imports to `/static/<stem>.wasm`
once at startup (`ViteCompiler._emit_na_wasm`). Editing one of those modules
during the session recompiled the Jac side and left the stale wasm in place,
so native game code needed a full server restart to show up in the browser.

The set of modules that owe a wasm is already tracked -- the client compile
records them in `JacClientCompiler.na_wasm_modules` -- so the watcher has
everything it needs to re-emit the one that changed and ask the page to
reload.
"""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

import from jaclang.server.hmr { HotReloader }
import from jaclang.server.watcher { JacFileWatcher }


obj _FakeJacClientCompiler {
    has compiled_dir: Path,
        project_dir: Path,
        na_wasm_modules: set[str],
        recompiled: list[str];

    def _output_path_for(module_path: Path, source_root: Path) -> Path {
        return self.compiled_dir / (module_path.stem + ".js");
    }

    def emit_dependencies(module_path: Path, **kwargs: any) {
        self.recompiled.append(str(module_path));
    }

    def rescan_pages -> bool {
        return False;
    }
}


obj _FakeViteCompiler {
    has jac_client_compiler: _FakeJacClientCompiler,
        emitted: list[str],
        _has_pages: bool = False,
        emit_succeeds: bool = True;

    def _emit_wasm_module(module_path: Path) -> bool {
        self.emitted.append(str(module_path));
        return self.emit_succeeds;
    }

    def create_entry_file(module_path: Path) {}
}


def _reload_signal(project_dir: str) -> Path {
    return Path(project_dir) / ".jac" / "client" / ".jac-force-reload";
}


"""Build a project holding a client entry and one native module, and return
(base_path, native_module_path, hot_reloader, fake_compiler)."""
def _make_reloader(tmp: str, succeeds: bool = True) -> tuple {
    Path(os.path.join(tmp, "jac.toml")).write_text(
        '[project]\nname = "wasmproj"\n', encoding="utf-8"
    );
    Path(os.path.join(tmp, "main.jac")).write_text(
        'glob READY: bool = True;\n', encoding="utf-8"
    );
    na_dir = Path(tmp) / "game";
    na_dir.mkdir();
    na_file = na_dir / "arena.jac";
    na_file.write_text(
        'na {\n    def tick(x: int) -> int {\n        return x + 1;\n    }\n}\n',
        encoding="utf-8"
    );
    compiled_dir = Path(tmp) / ".jac" / "client" / "compiled";
    compiled_dir.mkdir(parents=True);
    sibling = na_dir / "gmath.jac";
    sibling.write_text(
        'na {\n    def two -> int {\n        return 2;\n    }\n}\n', encoding="utf-8"
    );
    jcc = _FakeJacClientCompiler(
        compiled_dir=compiled_dir,
        project_dir=Path(tmp),
        na_wasm_modules={str(na_file.resolve()), str(sibling.resolve())},
        recompiled=[]
    );
    compiler = _FakeViteCompiler(
        jac_client_compiler=jcc, emitted=[], emit_succeeds=succeeds
    );
    reloader = HotReloader(
        base_path=tmp,
        module_name="main",
        watcher=JacFileWatcher(watch_paths=[tmp]),
        client_compiler=compiler
    );
    reloader._running = True;
    return (na_file, reloader, compiler);
}


test "editing a tracked native module re-emits its wasm" {
    with TemporaryDirectory() as tmp {
        (na_file, reloader, compiler) = _make_reloader(tmp);
        reloader._process_change(str(na_file));
        emitted = list(compiler.emitted);
    }
    assert emitted , (
        "a change to a module the client imports natively must re-emit its "
        "wasm; the watcher emitted nothing"
    );
    assert any(str(na_file) in e for e in emitted) , (
        f"the changed native module must be the one re-emitted; got {emitted}"
    );
}


test "re-emitting wasm asks the browser to reload" {
    with TemporaryDirectory() as tmp {
        (na_file, reloader, compiler) = _make_reloader(tmp);
        reloader._process_change(str(na_file));
        existed = _reload_signal(tmp).exists();
    }
    assert existed , (
        "a fresh wasm binary is only picked up on a full page load, so the "
        "watcher must raise the force-reload signal"
    );
}


test "an ordinary module change does not re-emit wasm" {
    with TemporaryDirectory() as tmp {
        (na_file, reloader, compiler) = _make_reloader(tmp);
        other = Path(tmp) / "main.jac";
        reloader._process_change(str(other));
        emitted = list(compiler.emitted);
    }
    assert emitted == [] , (
        f"only tracked native modules owe a wasm re-emit; got {emitted}"
    );
}


test "a tracked native module owes a wasm even when the hub has forgotten it" {
    # After a server-module reload the na module is no longer in the compile
    # hub -- it is imported by client code, not by the server -- so the hub
    # lookup that decides "does this owe a wasm" answered no and the emit was
    # skipped with a warning. The client compile already recorded the module
    # as a native import; that record is the answer.
    import from jaclang.client.vite_client_bundle { make_client_bundle_builder }

    with TemporaryDirectory() as tmp {
        Path(os.path.join(tmp, "jac.toml")).write_text(
            '[project]\nname = "wasmproj"\n', encoding="utf-8"
        );
        na_file = Path(tmp) / "game" / "arena.jac";
        na_file.parent.mkdir(parents=True);
        na_file.write_text(
            'na {\n    def tick(x: int) -> int {\n        return x + 1;\n    }\n}\n',
            encoding="utf-8"
        );
        compiler = make_client_bundle_builder(base_path=Path(tmp))._get_compiler();
        compiler.jac_client_compiler.na_wasm_modules = {str(na_file.resolve())};
        owed = compiler._owes_wasm(na_file);
        stranger = Path(tmp) / "game" / "unrelated.jac";
        stranger.write_text("glob READY: bool = True;\n", encoding="utf-8");
        not_owed = compiler._owes_wasm(stranger);
    }
    assert owed , (
        "a module the client compile recorded as a native import owes a wasm "
        "even when the compile hub no longer holds it"
    );
    assert not not_owed , "an unrelated module must not be compiled to wasm";
}


test "only the module that changed is re-emitted" {
    # _emit_na_wasm walks every tracked module, which on a dev edit rebuilds
    # wasm nobody asked for. A watcher event is about one file.
    with TemporaryDirectory() as tmp {
        (na_file, reloader, compiler) = _make_reloader(tmp);
        reloader._process_change(str(na_file));
        emitted = list(compiler.emitted);
    }
    assert len(emitted) == 1 , (
        f"one changed module means one wasm emit; got {emitted}"
    );
    assert str(na_file) in emitted[0] , (
        f"the emitted module must be the changed one; got {emitted}"
    );
}


test "an untracked native module is left alone" {
    # Declaring native code is not the same as being reachable from the
    # client: only a module the client compile recorded owes a wasm.
    with TemporaryDirectory() as tmp {
        (na_file, reloader, compiler) = _make_reloader(tmp);
        stray = Path(tmp) / "tools" / "stray.jac";
        stray.parent.mkdir(parents=True);
        stray.write_text(
            'na {\n    def one -> int {\n        return 1;\n    }\n}\n',
            encoding="utf-8"
        );
        reloader._process_change(str(stray));
        emitted = list(compiler.emitted);
    }
    assert emitted == [] , (
        f"a native module the client never imports owes no wasm; got {emitted}"
    );
}


test "a failed wasm emit does not reload the page" {
    with TemporaryDirectory() as tmp {
        (na_file, reloader, compiler) = _make_reloader(tmp, succeeds=False);
        signal = _reload_signal(tmp);
        if signal.exists() {
            signal.unlink();
        }
        reloader._process_change(str(na_file));
        raised = signal.exists();
    }
    assert not raised , (
        "reloading on a failed emit swaps in nothing and hides the error"
    );
}

test "wasm and its import manifest follow the client bundle output directory" {
    import json;
    import from unittest.mock { patch }
    import from jaclang.client.vite_client_bundle { ViteClientBundleBuilder }

    with TemporaryDirectory() as tmp {
        project = Path(tmp);
        (project / "package.json").write_text('{"name":"wasm-output"}');
        wasm = bytes.fromhex("0061736d01000000");
        for output in [
            project / ".jac" / "client" / "web" / "dist",
            project / "custom-output"
        ] {
            builder = ViteClientBundleBuilder(
                vite_package_json=project / "package.json", vite_output_dir=output
            );
            compiler = builder._get_compiler();
            with patch(
                "jaclang.compiler.backends.native.wasm_build.compile_to_wasm",
                return_value=wasm
            ) {
                assert compiler._emit_wasm_module(project / "arena.jac");
            }
            assert (output / "arena.wasm").read_bytes() == wasm;
            manifest = json.loads((output / "arena.wasm.imports.json").read_text());
            assert manifest["imports"] == {};
        }
        assert not (project / ".jac" / "client" / "dist" / "arena.wasm").exists();
    }
}
