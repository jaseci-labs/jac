"""Regression tests for WebTarget.dev() -- the web/static/desktop dev flow.

Bug (#7660): WebTarget.dev() started Vite without compiling the .jac
client entry first, so a fresh project's first `jac run -d` failed
with "Failed to resolve import /compiled/_entry.js". StaticTarget inherits
this method (and DesktopTarget's native-engine dev loop builds on the same
compile step), so those were affected too.

Tests mock prepare_vite_dev_compilation() rather than calling it for
real, since it resolves output paths via ambient project config that
won't match an isolated temp project in this test runner.
"""

import unittest.mock;
import from pathlib { Path }


obj _FakeBundler {
    has calls: list;

    def create_vite_config(entry_file: any, **kw: dict) -> any {
        return None;
    }

    def start_dev_server(**kw: dict) -> any {
        self.calls.append("serve");
        return None;
    }
}


obj _FakeWatcher {
    has events: list;

    def add_callback(cb: any) {
        self.events.append("callback");
    }

    def start {
        self.events.append("start");
    }

    def stop {
        self.events.append("stop");
    }
}


"""Runs target.dev() with the compile step and the watchdog probe stubbed out,
and returns the steps the flow actually took, in order. Passing a watcher makes
ensure_watchdog_common() report watchdog as available, so the HMR path runs."""
def _record_dev_calls(target: any, watcher: any = None) -> list {
    calls: list = [];
    fake_bundler = _FakeBundler(calls=calls);

    def _fake_prepare(project_dir: any, entry_file: any) -> tuple {
        calls.append("compile");
        return (fake_bundler, object());
    }

    def _fake_ensure_watchdog(label: str) -> bool {
        return watcher is not None;
    }

    def _fake_watcher_cls(**kw: dict) -> any {
        return watcher;
    }

    with unittest.mock.patch(
        "jaclang.client.targets.client_dev_common.prepare_vite_dev_compilation",
        _fake_prepare
    ), unittest.mock.patch(
        "jaclang.client.targets.client_dev_common.ensure_watchdog_common",
        _fake_ensure_watchdog
    ), unittest.mock.patch(
        "jaclang.server.watcher.JacFileWatcher", _fake_watcher_cls
    ) {
        target.dev(Path("app.jac"), Path("."), port=0, api_port=0);
    }
    return calls;
}


"""WebTarget.dev() must compile the client entry (prepare_vite_dev_compilation)
before starting the Vite dev server (start_dev_server) -- the exact ordering
the bug violated (server started first; compile step never ran at all)."""
test "web target dev compiles client entry before starting vite" {
    import from jaclang.client.targets.web_target { WebTarget }

    calls = _record_dev_calls(WebTarget());

    assert calls == ["compile", "serve"] , (
        "WebTarget.dev() must call prepare_vite_dev_compilation() before "
        f"start_dev_server(); got call order: {calls}"
    );
}


"""The HMR watcher must be wired to the recompile callback, started, and then
stopped on the way out -- including when start_dev_server hands back a falsy
process, which skips the wait/interrupt block entirely and would otherwise
leak the watcher thread."""
test "web target dev wires up the hmr watcher and always stops it" {
    import from jaclang.client.targets.web_target { WebTarget }

    watcher = _FakeWatcher(events=[]);
    _record_dev_calls(WebTarget(), watcher=watcher);

    assert watcher.events == ["callback", "start", "stop"] , (
        "the HMR watcher must be given its recompile callback, started, and "
        f"stopped even when no dev server process comes back; got: {watcher.events}"
    );
}


"""`jac run -d` on a `kind = "web-static"` project (the bug's original repro)
runs StaticTarget.dev(), which is WebTarget's inherited one. A PWA is no
longer a target of its own -- `[client.pwa]` decorates the web build -- so a
PWA project's dev loop is WebTarget.dev() itself, with the same fix."""
test "static and pwa dev flows inherit the compile-before-serve fix" {
    import os;
    import tempfile;
    import from jaclang.client.targets.static_target { StaticTarget }
    import from jaclang.client.targets.web_target { WebTarget }

    assert _record_dev_calls(StaticTarget()) == ["compile", "serve"] , (
        "StaticTarget must inherit WebTarget.dev(), so web-static projects "
        "compile before Vite starts"
    );
    with tempfile.TemporaryDirectory() as tmp {
        (Path(tmp) / "jac.toml").write_text(
            '[project]\nname = "pwa-app"\nversion = "1.0.0"\n'
            'entry-point = "main.jac"\nkind = "web-app"\n\n'
            '[client.pwa]\ntheme_color = "#000000"\n',
            encoding="utf-8"
        );
        old_cwd = os.getcwd();
        os.chdir(tmp);
        try {
            assert _record_dev_calls(WebTarget()) == ["compile", "serve"] , (
                "a [client.pwa] project runs WebTarget.dev(), so PWA projects "
                "compile before Vite starts"
            );
        } finally {
            os.chdir(old_cwd);
        }
    }
}


"""The dev server writes its own index.html rather than going through
HeaderBuilder, so `[client.app_meta_data] scripts` has to be injected there too.
Without it an SDK the app depends on is present in `jac build` output but
silently missing under `jac run --dev`, which reads as a bug.

Only the plugin lookup is patched, on the real config class: replacing
`get_config` wholesale with a stand-in breaks whatever else reads the config
while the patch is active (CompileOptions reads `gc` and `build.native` when a
module compiles lazily inside the window, which is what happens when the
compiler runs from source rather than the sealed payload)."""
test "configured scripts reach the dev server index.html" {
    import tempfile;
    import from jaclang.project.config { JacConfig }
    import from jaclang.client.vite_bundler { ViteBundler }

    def _fake_plugin_config(self: JacConfig, name: str) -> dict {
        return {
            "app_meta_data": {
                "title": "ignored in dev",
                "scripts": [{"src": "https://js.stripe.com/v3", "defer": True}]
            }
        };
    }

    with tempfile.TemporaryDirectory() as tmp {
        build_dir = Path(tmp);
        bundler = ViteBundler(project_dir=build_dir);
        with unittest.mock.patch.object(
            JacConfig, "get_plugin_config", _fake_plugin_config
        ) {
            bundler._ensure_dev_index_html(build_dir);
        }
        page = (build_dir / "index.html").read_text(encoding="utf-8");
    }

    assert '<script src="https://js.stripe.com/v3" defer></script>' in page , (
        "scripts configured in jac.toml must be injected into the dev "
        f"index.html; got:\n{page}"
    );
    assert page.index("js.stripe.com") < page.index("</head>") , (
        "the injected script must land inside the head, not after it"
    );
    assert "ignored in dev" not in page , (
        "only the scripts key is injected in dev; the dev index keeps its own "
        "title and meta tags"
    );
}


test "dev HTML and runtime aliases resolve in the selected workspace app" {
    import re;
    import tempfile;
    import from jaclang.project.config { JacConfig, get_config, set_config }
    import from jaclang.runtime.runtime { JacRuntime }
    import from jaclang.client.vite_bundler { ViteBundler }

    previous = get_config();
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        manifest = (
            '[project]\nname = "dev-paths"\ndefault-app = "web"\n'
            '[apps.web]\nkind = "web-app"\npath = "web"\n'
            '[apps.desktop]\nkind = "desktop"\npath = "shell"\n'
            '[apps.desktop.dependencies.npm]\nreact-native-web = "^0.19.13"\n'
            '[client.pwa]\nenabled = true\n'
            '[client.vite]\nplugins = ["tailwindcss()"]\n'
            'lib_imports = ["import tailwindcss from \'@tailwindcss/vite\'"]\n'
        );
        (project / "jac.toml").write_text(manifest);
        config = JacConfig.from_toml_str(manifest, project / "jac.toml");
        try {
            set_config(config);
            for (app_name, app_path) in [("web", "web"), ("desktop", "shell")] {
                target = project / app_path / "main.jac";
                target.parent.mkdir();
                with unittest.mock.patch.object(
                    JacRuntime, "get_full_target_path", return_value=str(target)
                ) {
                    bundler = ViteBundler(target.parent);
                    assert bundler.project_dir == project;
                    build_dir = bundler._get_client_dir();
                    compiled = build_dir / app_name / "compiled";
                    compiled.mkdir(parents=True);
                    for filename in [
                        "_entry.js",
                        "client_runtime.js",
                        "client_mobui.js",
                        "desktop_api.js",
                        "wasm_host.js",
                        "pwa_runtime.js"
                    ] {
                        (compiled / filename).write_text("export {};\n");
                    }
                    (compiled / "assets").mkdir();
                    # Fullstack dev passes a build entry; client-only targets
                    # pass Jac source. Both must resolve the compiled app.
                    for entry_file in [build_dir / "build" / "main.js", target] {
                        config_path = bundler.create_vite_config(
                            entry_file,
                            is_dev=True,
                            for_desktop_dev=app_name == "desktop"
                        );
                        bundler._ensure_dev_index_html(build_dir);
                        page = (build_dir / "index.html").read_text();
                        imports = re.findall(r'import\("(/[^\"]*_entry.js)"\)', page);
                        assert imports == [f"/{app_name}/compiled/_entry.js"] * 2;
                        assert all(
                            (build_dir / url.lstrip("/")).is_file() for url in imports
                        );
                        generated = config_path.read_text();
                        assert '"react-native": "react-native-web"' in generated;
                        assert "import tailwindcss from '@tailwindcss/vite'"
                            in generated;
                        assert "tailwindcss()" in generated;
                        for filename in [
                            "client_runtime.js",
                            "client_mobui.js",
                            "desktop_api.js",
                            "wasm_host.js",
                            "pwa_runtime.js",
                            "assets"
                        ] {
                            assert f'path.resolve(buildDir, "{app_name}/compiled/{filename}")'
                                in generated;
                        }
                        if app_name == "desktop" {
                            assert 'const compiled = path.resolve(buildDir, "desktop/compiled")'
                                in generated;
                        }
                    }
                }
            }
        } finally {
            set_config(previous);
        }
    }
}


test "single app dev keeps the unscoped compiled entry and aliases" {
    import tempfile;
    import from jaclang.project.config { JacConfig, get_config, set_config }
    import from jaclang.client.vite_bundler { ViteBundler }

    previous = get_config();
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        manifest = '[project]\nname = "single"\nkind = "web-app"\n';
        (project / "jac.toml").write_text(manifest);
        try {
            set_config(JacConfig.from_toml_str(manifest, project / "jac.toml"));
            bundler = ViteBundler(project);
            build_dir = bundler._get_client_dir();
            config_path = bundler.create_vite_config(project / "main.jac", is_dev=True);
            bundler._ensure_dev_index_html(build_dir);
            page = (build_dir / "index.html").read_text();
            assert page.count('import("/compiled/_entry.js")') == 2;
            assert 'path.resolve(buildDir, "compiled/client_runtime.js")'
                in config_path.read_text();
        } finally {
            set_config(previous);
        }
    }
}
