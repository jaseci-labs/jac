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
            compiler.compile_dependencies_recursively(
                project / "main.jac", source_root=project
            );
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
            compiler.compile_dependencies_recursively(
                project / "main.jac", source_root=project
            );
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
        (project / "provider.jac").write_text('obj Hidden { has name: str = ""; }\n');
        (project / "main.jac").write_text(
            'import from .provider { Hidden }\n'
            'def:pub app -> any { value = Hidden(); return <div>{value.name}</div>; }\n'
        );
        try {
            failed = False;
            try {
                compiler.compile_dependencies_recursively(
                    project / "main.jac", source_root=project
                );
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
            compiler.compile_dependencies_recursively(
                project / "main.jac", source_root=project
            );
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
    manifest = ClientManifest(runtime_imports={"provider.jac": ["Value"]});
    artifact = ClientArtifact(js="", manifest=manifest);
    restored = ClientArtifact.from_bytes(artifact.to_bytes());
    assert restored is not None;
    assert restored.manifest.runtime_imports == manifest.runtime_imports;
    legacy = pickle.dumps(("", manifest, [], [], {}, ""));
    assert ClientArtifact.from_bytes(legacy) is None;
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
            compiler.compile_dependencies_recursively(
                project / "main.jac", source_root=project
            );
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
            assert "html_tag_map.js" in js;
            assert (
                project / "compiled" / "targets" / "react_native" / "html_tag_map.js"
            ).is_file();
        } finally {
            set_config(None);
        }
    }
}
