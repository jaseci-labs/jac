import json;
import re;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from types { SimpleNamespace }
import from unittest.mock { patch }
import from jaclang.client.vite_client_bundle { ViteClientBundleBuilder }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.project.config { set_config }
import from jaclang.server.hmr { HotReloader }
import from jaclang.server.watcher { JacFileWatcher }

def _compiler(project: Path, program: JacProgram | None = None) -> any {
    project.mkdir(exist_ok=True);
    (project / "jac.toml").write_text(
        '[project]\nname = "external-imports"\nkind = "web-app"\n'
    );
    (project / "package.json").write_text(
        '{"name":"external-imports","type":"module"}'
    );
    return ViteClientBundleBuilder(
        vite_package_json=project / "package.json", program=program or JacProgram()
    )._get_compiler().jac_client_compiler;
}

def _emitted(compiler: any, source: Path) -> Path {
    matches = [
        path
        for path in compiler.compiled_dir.rglob("*.js")
        if path.read_text().startswith(f"/* Source: {source.resolve()} */")
    ];
    assert len(matches) == 1 , f"expected one output for {source}, found {matches}";
    return matches[0];
}

def _assert_import(importer: Path, target: Path) {
    specs = re.findall(r'(?:from\s+|import\s*\(?\s*)"([^"\n]+)"', importer.read_text());
    assert any(
        (importer.parent / spec).resolve() == target.resolve()
        for spec in specs
        if spec.startswith(".")
    ) , f"{importer} does not import {target}: {specs}";
}

test "external imports keep same-named modules and their dependencies on cold and warm builds" {
    with TemporaryDirectory() as tmp, patch(
        "jaclang.project.kernel_compile._IN_PROCESS", [True]
    ) {
        set_config(None);
        base = Path(tmp).resolve();
        project = base / "myapp";
        compiler = _compiler(project);
        local = project / "Local.jac";
        local.write_text('def:pub Local -> any { return <span>local</span>; }\n');
        cards: list[Path] = [];
        for name in ["a", "b"] {
            folder = base / name;
            folder.mkdir();
            card = folder / "Card.jac";
            card.write_text(
                'import from ..myapp.Local { Local }\n'
                    + f'def:pub Card{name} -> any {{ return <Local/>; }}\n'
            );
            cards.append(card);
        }
        entry_file = project / "frontend.jac";
        entry_file.write_text(
            'import from ..a.Card { Carda }\n'
            'import from ..b.Card { Cardb }\n'
            'def:pub app -> any { return <div><Carda/><Cardb/></div>; }\n'
        );
        try {
            for build_index in range(2) {
                compiler.emit_dependencies(entry_file, source_root=project);
                outputs = [_emitted(compiler, card) for card in cards];
                assert outputs[0] != outputs[1];
                for (card, output) in zip(cards, outputs) {
                    assert output.is_relative_to(compiler.compiled_dir);
                    assert str(base)
                        not in str(output.relative_to(compiler.compiled_dir)) , output;
                    _assert_import(_emitted(compiler, entry_file), output);
                    _assert_import(output, _emitted(compiler, local));
                    source_map = json.loads(output.with_suffix(".js.map").read_text());
                    assert source_map["sources"] == [str(card)];
                }
                if build_index == 0 {
                    compiler = _compiler(project);
                }
            }
        } finally {
            set_config(None);
        }
    }
}

test "hot reload updates and removes external assets at the build's output paths" {
    with TemporaryDirectory() as tmp {
        project = Path(tmp).resolve() / "myapp";
        compiler = _compiler(project);
        source_root = project / "src";
        source_root.mkdir();
        compiler.jac_compiler.source_root = source_root;
        reloader = HotReloader(
            base_path=str(project),
            module_name="frontend",
            watcher=JacFileWatcher(watch_paths=[str(project)]),
            client_compiler=SimpleNamespace(jac_client_compiler=compiler)
        );
        for suffix in ["js", "tsx", "css"] {
            asset = project / f"shared.{suffix}";
            asset.write_text("initial");
            compiler._copy_asset_file(asset, source_root);
            output = compiler._output_path_for(asset, source_root);
            assert output.read_text() == "initial";
            asset.write_text("edited");
            reloader._copy_frontend_files(str(asset));
            assert output.read_text() == "edited";
            asset.unlink();
            reloader._copy_frontend_files(str(asset));
            assert not output.exists();
        }
    }
}

test "a shared module gets imports for each consumer's layout rather than a cached previous layout" {
    with TemporaryDirectory() as tmp {
        set_config(None);
        base = Path(tmp).resolve();
        app_a = base / "app_a";
        app_b = base / "app_b";
        shared = base / "shared";
        app_a.mkdir();
        shared.mkdir();
        (shared / "jac.toml").write_text(
            '[project]\nname = "@tests/shared-ui"\nexports = ["*"]\n'
        );
        local = app_a / "Local.jac";
        local.write_text('def:pub Local -> any { return <span>local</span>; }\n');
        component = shared / "Card.jac";
        component.write_text(
            'import from ..app_a.Local { Local }\n'
            'def:pub Card -> any { return <Local/>; }\n'
        );
        program = JacProgram();
        try {
            for project in [app_a, app_b, app_a] {
                compiler = _compiler(project, program);
                entry_file = project / "frontend.jac";
                entry_file.write_text(
                    'import from ..shared.Card { Card }\n'
                    'def:pub app -> any { return <Card/>; }\n'
                );
                compiler.emit_dependencies(entry_file, source_root=project);
                _assert_import(
                    _emitted(compiler, entry_file), _emitted(compiler, component)
                );
                _assert_import(
                    _emitted(compiler, component), _emitted(compiler, local)
                );
            }
        } finally {
            set_config(None);
        }
    }
}
