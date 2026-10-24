import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.client.vite_client_bundle { ViteClientBundleBuilder }
import from jaclang.client.client_bundle { ClientBundleError }
import from jaclang.project.config { set_config }

def _compiler(project: Path) -> any {
    (project / "package.json").write_text('{"name":"imports","version":"0.0.0"}');
    (project / "jac.toml").write_text(
        '[project]\nname = "imports"\nkind = "web-app"\n'
        '[placement.pins]\n"provider" = "client"\n'
    );
    builder = ViteClientBundleBuilder(vite_package_json=project / "package.json");
    compiler = builder._get_compiler().jac_client_compiler;
    compiler.compiled_dir = project / "compiled";
    return compiler;
}

test "annotation imports disappear but values and module effects survive" {
    with TemporaryDirectory() as tmp {
        set_config(None);
        project = Path(tmp);
        compiler = _compiler(project);
        (project / "provider.jac").write_text(
            'obj Session { has name: str = ""; }\n'
            'obj:pub Value { has name: str = "value"; }\n'
            'def:pub session -> Session { return Session(); }\n'
        );
        (project / "main.jac").write_text(
            'import from .provider { Session as State, Value as Item, session }\n'
            'def:pub app -> any {\n'
            '    state: State = session();\n'
            '    item = Item();\n'
            '    return <div>{state.name}{item.name}</div>;\n'
            '}\n'
        );
        try {
            compiler.emit_dependencies(project / "main.jac", source_root=project);
            js = (project / "compiled" / "main.js").read_text();
            imports = "\n".join(
                line
                for line in js.splitlines()
                if line.startswith("import ")
            );
            assert "Session" not in imports , imports;
            assert "Value as Item" in imports , imports;
            assert "session" in imports , imports;
            # The same checks must apply when compiler artifacts come from cache.
            compiler.emit_dependencies(project / "main.jac", source_root=project);
        } finally {
            set_config(None);
        }
    }
}

test "missing runtime exports fail before either client bundler starts" {
    with TemporaryDirectory() as tmp {
        set_config(None);
        project = Path(tmp);
        compiler = _compiler(project);
        (project / "provider.jac").write_text(
            'obj:priv Hidden { has name: str = ""; }\n'
        );
        (project / "main.jac").write_text(
            'import from .provider { Hidden }\n'
            'def:pub app -> any { value = Hidden(); return <div>{value.name}</div>; }\n'
        );
        try {
            failed = False;
            try {
                compiler.emit_dependencies(project / "main.jac", source_root=project);
            } except ClientBundleError as error {
                failed = True;
                assert "runtime import(s)" in str(error) , str(error);
                assert "Hidden" in str(error) and "provider.jac" in str(error) , str(
                    error
                );
            }
            assert failed , "invalid runtime imports reached the bundler";
        } finally {
            set_config(None);
        }
    }
}

test "client providers export exactly the names client importers bind" {
    # (provider, provider source, importer source, provider's export lines)
    cases = [
        (
            "shared",
            'glob LABELS: dict[str, str] = {"new": "New"};\n'
            'obj Model { has name: str = "new"; }\n'
            'def Card(m: Model) -> JsxElement { return <b>{LABELS[m.name]}</b>; }\n'
            'def Local -> JsxElement { return <i>local</i>; }\n',
            'import from .shared { Card, LABELS, Model }\n'
            'def show(m: Model) -> JsxElement { return <Card m={m} />; }\n'
            'def:pub app -> any { return <div>{LABELS["new"]}</div>; }\n',
            ["export {Card, LABELS};"]
        ),
        (
            "widgets",
            'obj Model { has name: str = "new"; }\n'
            'def Card(m: Model) -> JsxElement { return <b>{m.name}</b>; }\n',
            'import from .widgets { Card, Model }\n'
            'def:pub app(m: Model) -> any { return <Card m={m} />; }\n',
            ["/*jac:refresh-boundary*/;", "export {Card};"]
        ),
        (
            "provider",
            'obj Hidden { has name: str = ""; }\n',
            'import from .provider { Hidden }\n'
            'def:pub app -> any { value = Hidden(); return <div>{value.name}</div>; }\n',
            ["export {Hidden};"]
        ),
        (
            "relay",
            'import from .badge { Badge }\n',
            'import from .relay { Badge }\n'
            'def:pub app -> any { return <Badge />; }\n',
            ['export {Badge} from "./badge.js";']
        ),

    ];
    with TemporaryDirectory() as tmp {
        set_config(None);
        project = Path(tmp);
        compiler = _compiler(project);
        (project / "badge.jac").write_text(
            'def Badge -> JsxElement { return <i>badge</i>; }\n'
        );
        def export_lines(name: str) -> list[str] {
            js = (project / "compiled" / f"{name}.js").read_text();
            return [
                line
                for line in js.splitlines()
                if line.startswith("export {") or line.startswith("/*jac:")
            ];
        }
        try {
            for (name, source, importer, expected) in cases {
                (project / f"{name}.jac").write_text(source);
                (project / f"use_{name}.jac").write_text(importer);
                compiler.emit_dependencies(
                    project / f"use_{name}.jac", source_root=project
                );
                assert export_lines(name) == expected , (name, export_lines(name));
                # A dev-server edit recompiles the provider alone.
                compiler.emit_dependencies(
                    project / f"{name}.jac", source_root=project
                );
                assert export_lines(name) == expected , (name, export_lines(name));
            }
            assert export_lines("badge")
                == ["/*jac:refresh-boundary*/;", "export {Badge};"] , export_lines(
                "badge"
            );
        } finally {
            set_config(None);
        }
    }
}

test "an annotation-only binding preserves module evaluation" {
    with TemporaryDirectory() as tmp {
        set_config(None);
        project = Path(tmp);
        compiler = _compiler(project);
        (project / "provider.jac").write_text(
            'obj Session { has name: str = ""; }\n'
            'glob:pub loads: int = 0;\n'
            'with entry { loads += 1; }\n'
        );
        (project / "main.jac").write_text(
            'import from .provider { Session }\n'
            'def:pub app(value: Session) -> any { return <div>{value.name}</div>; }\n'
        );
        try {
            compiler.emit_dependencies(project / "main.jac", source_root=project);
            js = (project / "compiled" / "main.js").read_text();
            assert 'import "./provider.js";' in js , js;
            assert (project / "compiled" / "provider.js").is_file();
        } finally {
            set_config(None);
        }
    }
}

test "client artifact caches preserve the runtime import contract" {
    import pickle;
    import from jaclang.compiler.frontend.codeinfo { ClientArtifact, ClientManifest }
    import from jaclang.compiler.driver.compiler {
        client_artifact_bytes,
        client_artifact_from_bytes
    }
    manifest = ClientManifest(runtime_imports={"provider.jac": ["Value"]});
    artifact = ClientArtifact(js="", manifest=manifest);
    restored = client_artifact_from_bytes(client_artifact_bytes(artifact));
    assert restored is not None;
    assert restored.manifest.runtime_imports == manifest.runtime_imports;
    legacy = pickle.dumps(("", manifest, [], [], {}, ""));
    assert client_artifact_from_bytes(legacy) is None;
}

test "jsx references and shadowed names retain their runtime imports" {
    with TemporaryDirectory() as tmp {
        set_config(None);
        project = Path(tmp);
        compiler = _compiler(project);
        (project / "provider.jac").write_text(
            'def:pub Button -> any { return <button>ok</button>; }\n'
            'def:pub value -> int { return 1; }\n'
        );
        (project / "main.jac").write_text(
            'import from .provider { Button, value }\n'
            'def shadow(value: int) -> int { return value; }\n'
            'def:pub app -> any { assert value() == 1; return <Button />; }\n'
        );
        try {
            compiler.emit_dependencies(project / "main.jac", source_root=project);
            js = (project / "compiled" / "main.js").read_text();
            imports = "\n".join(
                line
                for line in js.splitlines()
                if line.startswith("import ")
            );
            assert "Button" in imports and "value" in imports , imports;
        } finally {
            set_config(None);
        }
    }
}

test "native runtime emits dependencies for bare imports" {
    with TemporaryDirectory() as tmp {
        set_config(None);
        project = Path(tmp);
        compiler = _compiler(project);
        try {
            (js, exports) = compiler.compile_runtime_utils(
                compiler.NATIVE_RUNTIME_FILE
            );
            for name in ["useJacState", "jacSetToken"] {
                assert name in exports , f"Native runtime is missing {name}";
                assert f"function {name}(" in js , f"Missing implementation: {name}";
            }
            assert "html_tag_map.js" in js;
            assert (
                project / "compiled" / "targets" / "react_native" / "html_tag_map.js"
            ).is_file();
        } finally {
            set_config(None);
        }
    }
}

test "a provider an earlier page emitted is refreshed when a later page grows it" {
    import from jaclang.compiler.driver.client_graph { collect_client_graph }
    import from jaclang.compiler.frontend.codeinfo { ClientArtifact, ClientManifest }

    with TemporaryDirectory() as tmp {
        base = Path(tmp).resolve();
        (layout, page, provider, nested, extra) = (
            base / "layout.jac",
            base / "page.jac",
            base / "provider.jac",
            base / "nested.jac",
            base / "extra.jac"
        );
        for path in (layout, page, provider, nested, extra) {
            path.write_text("");
        }
        grown = {"pulled": False};
        def module(
            exports: list[str], imports: dict[str, str], needs: dict[str, list[str]]
        ) -> ClientArtifact {
            return ClientArtifact(
                js=",".join(exports),
                manifest=ClientManifest(
                    exports=exports, imports=imports, runtime_imports=needs
                )
            );
        }
        def artifact_of(path: Path) -> ClientArtifact {
            if path == layout {
                return module(
                    [], {"provider": str(provider)}, {str(provider): ["palette"]}
                );
            }
            if path == page {
                grown["pulled"] = True;
                return module(
                    [], {"provider": str(provider)}, {str(provider): ["spacing"]}
                );
            }
            if path == provider {
                if grown["pulled"] {
                    return module(
                        ["palette", "spacing"],
                        {"nested": str(nested), "extra": str(extra)},
                        {str(nested): ["base", "gap"], str(extra): ["tool"]}
                    );
                }
                return module(
                    ["palette"], {"nested": str(nested)}, {str(nested): ["base"]}
                );
            }
            if path == extra {
                return module(["tool"], {}, {});
            }
            return module(["base", "gap"] if grown["pulled"] else ["base"], {}, {});
        }
        def same(path: Path) -> Path {
            return path;
        }
        visited: set[Path] = set();
        first = collect_client_graph([layout], artifact_of, same, set(), visited);
        second = collect_client_graph([page], artifact_of, same, set(), visited);
    }
    assert [u.path for u in first.modules] == [layout, provider, nested];
    assert [u.path for u in second.modules] == [page, extra] , (
        "a module the grown provider newly imports must be compiled and emitted"
    );
    assert [u.path for u in second.refreshed] == [provider, nested] , (
        "the modules the first page emitted must be re-emitted with what the second "
        "page pulled, including the provider's own dependency"
    );
    assert second.refreshed[0].artifact.js == "palette,spacing";
    assert second.refreshed[1].artifact.js == "base,gap";
}
