"""Unit tests for HMR (Hot Module Replacement) components.

Tests for the file watcher and HotReloader functionality.
"""

import os;
import tempfile;
import threading;
import time;
import from pathlib { Path }
import from unittest.mock { MagicMock, patch }

import watchdog;

import from jaclang.server.hmr { HotReloader }
import from jaclang.server.build_status { get_build_status }
import from jaclang.server.watcher {
    ChangeType,
    FileChangeEvent,
    JacFileWatcher,
    watch_roots,
    application_watch_roots
}

def _as_any(v: any) -> any {
    return v;
}

test "prepared namespaced modules reload through their source source_path" {
    import sys;
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.compiler.driver.application { prepare_application }
    import from jaclang.runtime.prepared {
        initialize_application,
        load_prepared_module,
        forget
    }
    with tempfile.TemporaryDirectory() as tmp {
        source_path = Path(tmp) / 'main.jac';
        source_path.write_text('def value -> int { return 1; }\n');
        application = prepare_application(str(source_path), Jac.get_program(), tmp);
        module = initialize_application(application);
        prefix = module.__name__.split('.')[0];
        try {
            reloader = HotReloader(
                base_path=tmp,
                module_name=module.__name__,
                entry_path=str(source_path),
                watcher=JacFileWatcher(watch_paths=[tmp])
            );
            source_path.write_text('def value -> int { return 2; }\n');
            reloader._process_change(str(source_path));
            assert not reloader.diagnostics();
            updated: any = load_prepared_module(str(source_path));
            assert updated.value() == 2;
            assert updated is not module;
        } finally {
            forget(str(source_path));
            for name in list(sys.modules) {
                if name == prefix or name.startswith(prefix + '.') {
                    sys.modules.pop(name, None);
                }
            }
        }
    }
}

test "a hot reload holds the preparation lock until the app is initialized again" {
    import sys;
    import threading;
    import jaclang.runtime.prepared as prepared_runtime;
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.compiler.driver.application { prepare_application }
    import from jaclang.runtime.prepared {
        initialize_application,
        load_prepared_module,
        forget
    }
    import from jaclang.runtime.preparation_lock { PREPARATION_LOCK }
    with tempfile.TemporaryDirectory() as tmp {
        source_path = Path(tmp) / 'main.jac';
        source_path.write_text('def value -> int { return 1; }\n');
        application = prepare_application(str(source_path), Jac.get_program(), tmp);
        module = initialize_application(application);
        prefix = module.__name__.split('.')[0];
        free_during: list[bool] = [];
        original = prepared_runtime.initialize_application;
        def observed_initialize(*args: any, **kwargs: any) -> any {
            took: list[bool] = [];
            def try_lock {
                got = PREPARATION_LOCK.acquire(timeout=0);
                took.append(got);
                if got {
                    PREPARATION_LOCK.release();
                }
            }
            other = threading.Thread(target=try_lock);
            other.start();
            other.join(30);
            free_during.extend(took);
            return original(*args, **kwargs);
        }
        try {
            reloader = HotReloader(
                base_path=tmp,
                module_name=module.__name__,
                entry_path=str(source_path),
                watcher=JacFileWatcher(watch_paths=[tmp])
            );
            source_path.write_text('def value -> int { return 2; }\n');
            with patch.object(
                prepared_runtime, 'initialize_application', observed_initialize
            ) {
                reloader._reload_server_module(str(source_path));
            }
            assert not reloader.diagnostics() , reloader.diagnostics();
            assert free_during == [False] , (
                "another thread could take the preparation lock while the reload re-initialized the app"
            );
            updated: any = load_prepared_module(str(source_path));
            assert updated.value() == 2;
        } finally {
            forget(str(source_path));
            for name in list(sys.modules) {
                if name == prefix or name.startswith(prefix + '.') {
                    sys.modules.pop(name, None);
                }
            }
        }
    }
}

test "a stylesheet change in a prepared app is copied, not re-prepared" {
    import io;
    import sys;
    import from contextlib { redirect_stderr }
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.compiler.driver.application { prepare_application }
    import from jaclang.runtime.prepared { initialize_application, forget }
    with tempfile.TemporaryDirectory() as tmp {
        source_path = Path(tmp) / 'main.jac';
        source_path.write_text('def value -> int { return 1; }\n');
        application = prepare_application(str(source_path), Jac.get_program(), tmp);
        module = initialize_application(application);
        prefix = module.__name__.split('.')[0];
        try {
            reloader = HotReloader(
                base_path=tmp,
                module_name=module.__name__,
                entry_path=str(source_path),
                watcher=JacFileWatcher(watch_paths=[tmp])
            );
            sheet = Path(tmp) / 'styles.css';
            sheet.write_text('.root { color: red; }');
            err = io.StringIO();
            with redirect_stderr(err) {
                reloader._process_change(str(sheet));
            }
            assert not reloader.diagnostics() , reloader.diagnostics();
            assert "Preparing application" not in err.getvalue() , (
                "a stylesheet change re-prepared the whole application"
            );
            copied = Path(tmp) / reloader._client_output_dir / 'styles.css';
            assert copied.read_text() == '.root { color: red; }';
            compiled = Path(tmp) / 'build' / 'web' / 'compiled';
            reloader.client_compiler = _FakeCompiler(
                jac_client_compiler=_FakeJcc(
                    out_path=compiled / 'main.js',
                    next_code='',
                    compiled_dir=str(compiled)
                )
            );
            sheet.write_text('.root { color: blue; }');
            reloader._process_change(str(sheet));
            served = compiled / 'styles.css';
            assert served.read_text() == '.root { color: blue; }' , (
                "the edit was not copied to the client compiler's output"
            );
            reloader._process_change(str(served));
            assert not (compiled / 'build').exists() , "a copied asset was copied again";
            sheet.unlink();
            reloader._process_change(str(sheet));
            assert not served.exists() , "a deleted stylesheet stayed in the served output";
        } finally {
            forget(str(source_path));
            for name in list(sys.modules) {
                if name == prefix or name.startswith(prefix + '.') {
                    sys.modules.pop(name, None);
                }
            }
        }
    }
}

# A workspace app's entry sits in its own directory while the modules it
# imports live in sibling directories under the application root. Watching
# only the entry's directory left edits to those modules unnoticed.
test "watch roots cover the directories the application's modules come from" {
    import os;
    with tempfile.TemporaryDirectory() as tmp {
        top = os.path.realpath(tmp);
        for rel in [
            "web/pages",
            "core/site/ui",
            "cli",
            ".jac/client",
            "node_modules/pkg"
        ] {
            os.makedirs(os.path.join(top, rel));
        }
        base = os.path.join(top, "web");
        sources = [
            os.path.join(top, "web", "main.jac"),
            os.path.join(top, "web", "pages", "index.jac"),
            os.path.join(top, "core", "site", "ui", "empty.jac"),
            os.path.join(top, "core", "life.jac"),
            os.path.join(top, ".jac", "client", "gen.jac"),
            os.path.join(top, "node_modules", "pkg", "x.jac"),
            "/elsewhere/lib.jac"
        ];
        assert watch_roots(base, top, sources) == [base, os.path.join(top, "core")];
        assert watch_roots(top, top, sources) == [top];
        shared = sources + [os.path.join(top, "shared.jac")];
        assert watch_roots(base, top, shared)
            == [base, os.path.join(top, "core"), os.path.join(top, "shared.jac")];
        nested = os.path.join(top, "web", "pages");
        assert watch_roots(nested, top, sources)
            == [os.path.join(top, "core"), os.path.join(top, "web")];
    }
}

test "a served workspace app watches the directories its prepared modules come from" {
    import os;
    import sys;
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.compiler.driver.application { prepare_application }
    import from jaclang.runtime.prepared { initialize_application, forget }
    with tempfile.TemporaryDirectory() as tmp {
        top = os.path.realpath(tmp);
        web = os.path.join(top, "web");
        for rel in ["web", "core", "svc"] {
            os.makedirs(os.path.join(top, rel));
        }
        Path(top, "core", "shared.jac").write_text('def value -> int { return 1; }\n');
        Path(top, "svc", "api.jac").write_text('def:pub ping -> int { return 1; }\n');
        source_path = os.path.join(web, "main.jac");
        Path(source_path).write_text(
            'import from core.shared { value }\n\ndef doubled -> int { return value() * 2; }\n'
        );
        service = os.path.join(top, "svc", "api.jac");
        expected = [web, os.path.join(top, "core"), os.path.join(top, "svc")];
        for attempt in ["prepared", "restored"] {
            application = prepare_application(
                source_path, Jac.get_program(), top, [service]
            );
            module = initialize_application(application);
            prefix = module.__name__.split('.')[0];
            try {
                roots = application_watch_roots(web, application, Jac.get_program());
                assert roots == expected , f"{attempt}: {roots}";
            } finally {
                forget(source_path);
                for name in list(sys.modules) {
                    if name == prefix or name.startswith(prefix + '.') {
                        sys.modules.pop(name, None);
                    }
                }
            }
        }
    }
}

test "a client-only sibling directory is watched on a fresh and a restored start" {
    import os;
    import sys;
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.compiler.driver.application { prepare_application }
    import from jaclang.runtime.prepared { initialize_application, forget }
    with tempfile.TemporaryDirectory() as tmp {
        top = os.path.realpath(tmp);
        web = os.path.join(top, "web");
        for rel in ["web", "ui"] {
            os.makedirs(os.path.join(top, rel));
        }
        Path(top, "jac.toml").write_text('[project]\nname = "client-sibling"\n');
        Path(top, "ui", "Badge.jac").write_text(
            'def:pub Badge -> JsxElement {\n    return <span>ok</span>;\n}\n'
        );
        source_path = os.path.join(web, "main.jac");
        Path(source_path).write_text(
            'import from ui.Badge { Badge }\n\ndef:pub app -> JsxElement {\n    return <Badge/>;\n}\n'
        );
        for attempt in ["prepared", "restored"] {
            application = prepare_application(
                source_path, Jac.get_program(), top, (), True
            );
            module = initialize_application(application);
            prefix = module.__name__.split('.')[0];
            try {
                assert os.path.join(top, "ui", "Badge.jac") not in application.code , (
                    "the client-only module is executable server code"
                );
                roots = application_watch_roots(web, application, Jac.get_program());
                assert roots == [web, os.path.join(top, "ui")] , f"{attempt}: {roots}";
            } finally {
                forget(source_path);
                for name in list(sys.modules) {
                    if name == prefix or name.startswith(prefix + '.') {
                        sys.modules.pop(name, None);
                    }
                }
            }
        }
    }
}

test "the compiler's own modules never make a watch root, wherever its checkout sits" {
    import copy;
    import os;
    import sys;
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.compiler.driver.application { prepare_application }
    import from jaclang.compiler.frontend.codeinfo {
        is_compiler_source_path,
        jaclang_pkg_root
    }
    import from jaclang.runtime.prepared { initialize_application, forget }
    import from jaclang.project.modresolver { resolve_jac_virtual_module_path }
    checkout = os.path.dirname(os.path.realpath(jaclang_pkg_root()));
    if not os.access(checkout, os.W_OK) {
        testskip("needs a writable directory around the jaclang source tree");
    }
    with tempfile.TemporaryDirectory(dir=checkout, prefix="watch-app-") as tmp {
        web = os.path.realpath(tmp);
        Path(web, "jac.toml").write_text('[project]\nname = "watch-app"\n');
        source_path = os.path.join(web, "main.jac");
        Path(source_path).write_text(
            'import from "@jac/runtime" { Navigate }\n\ndef:pub app -> JsxElement {\n    return <Navigate to="/"/>;\n}\n'
        );
        application = prepare_application(
            source_path, Jac.get_program(), web, (), True
        );
        module = initialize_application(application);
        prefix = module.__name__.split('.')[0];
        try {
            desktop_source = resolve_jac_virtual_module_path('@jac/desktop');
            assert desktop_source is not None;
            desktop = os.path.realpath(desktop_source);
            assert is_compiler_source_path(desktop) , desktop;
            enclosing: any = copy.copy(application);
            enclosing.`root = checkout;
            enclosing.sources = sorted({*application.sources, desktop});
            roots = application_watch_roots(web, enclosing, Jac.get_program());
            assert roots == [web] , str(roots);
        } finally {
            forget(source_path);
            for name in list(sys.modules) {
                if name == prefix or name.startswith(prefix + '.') {
                    sys.modules.pop(name, None);
                }
            }
        }
    }
}

test "a watch around the jac checkout reports no compiler source events" {
    import os;
    import from jaclang.compiler.frontend.codeinfo {
        is_compiler_source_path,
        jaclang_pkg_root
    }
    import from jaclang.cli.commands.execution { _count_jac_files }
    package = os.path.realpath(jaclang_pkg_root());
    checkout = os.path.dirname(package);
    compiler_module = os.path.join(package, "runtime", "prepared.jac");
    assert is_compiler_source_path(compiler_module);
    watcher = JacFileWatcher(watch_paths=[checkout]);
    for path in [compiler_module, os.path.join(checkout, "main.jac")] {
        watcher._on_change(path, ChangeType.MODIFIED);
    }
    watcher._on_change(os.path.join(package, "runtime"), ChangeType.CREATED, True);
    seen = sorted(watcher._pending_events);
    assert seen == [os.path.join(checkout, "main.jac")] , str(seen);
    assert _count_jac_files(package) == 0;
}

test "nothing under site-packages or a hidden directory becomes a watch root" {
    import os;
    with tempfile.TemporaryDirectory() as tmp {
        top = os.path.realpath(tmp);
        base = os.path.join(top, "web");
        os.makedirs(base);
        sources = [
            os.path.join(base, "main.jac"),
            os.path.join(
                top, "env", "lib", "python3.12", "site-packages", "pkg", "m.jac"
            ),
            os.path.join(top, ".venv", "lib", "site-packages", "pkg", "m.jac"),
            os.path.join(top, "venv", "lib", "pkg", "m.jac"),
            os.path.join(top, "core", "__pycache__", "m.jac")
        ];
        assert watch_roots(base, top, sources) == [base];
    }
}

test "a watched file reports itself and its annexes, not the files beside it" {
    with tempfile.TemporaryDirectory() as tmp {
        top = Path(tmp).resolve();
        (top / "core").mkdir();
        shared = top / "shared.jac";
        shared.write_text("glob x = 1;\n");
        watcher = JacFileWatcher(watch_paths=[str(top / "core"), str(shared)]);
        for name in [
            "other.jac",
            "shared.jac",
            "shared.impl.jac",
            "shared.extra.impl.jac",
            "shared.test.jac",
            "shared.extra.jac",
            "sharedness.jac",
            "core/inside.jac"
        ] {
            watcher._on_change(str(top / name), ChangeType.MODIFIED);
        }
        for name in ["shared.impl", "impl", "docs"] {
            watcher._on_change(str(top / name), ChangeType.CREATED, True);
        }
        seen = sorted(Path(p).name for p in watcher._pending_events);
        assert seen
            == [
                "impl",
                "inside.jac",
                "shared.extra.impl.jac",
                "shared.impl",
                "shared.impl.jac",
                "shared.jac",
                "shared.test.jac"
            ] , str(seen);
    }
}

test "a shared annex folder reports only the annexes of watched modules" {
    with tempfile.TemporaryDirectory() as tmp {
        top = Path(tmp).resolve();
        for rel in ["web", "impl", "test"] {
            (top / rel).mkdir();
        }
        shared = top / "shared.jac";
        shared.write_text("glob x = 1;\n");
        (top / "impl" / "local.jac").write_text("glob y = 1;\n");
        watcher = JacFileWatcher(
            watch_paths=[
                str(top / "web"),
                str(top / "impl"),
                str(top / "test"),
                str(shared)
            ]
        );
        for name in [
            "impl/other.impl.jac",
            "test/other.test.jac",
            "impl/shared.impl.jac",
            "impl/shared.extra.impl.jac",
            "test/shared.test.jac",
            "impl/local.impl.jac",
            "impl/local.extra.impl.jac",
            "impl/plain.jac",
            "web/page.impl.jac"
        ] {
            watcher._on_change(str(top / name), ChangeType.MODIFIED);
        }
        seen = sorted(str(Path(p).relative_to(top)) for p in watcher._pending_events);
        assert seen
            == [
                "impl/local.extra.impl.jac",
                "impl/local.impl.jac",
                "impl/plain.jac",
                "impl/shared.extra.impl.jac",
                "impl/shared.impl.jac",
                "test/shared.test.jac",
                "web/page.impl.jac"
            ] , str(seen);
    }
}

test "a module named like a shared annex folder keeps its annexes in that folder" {
    import from jaclang.jac0core.ext_registry { is_annex_path_of }
    with tempfile.TemporaryDirectory() as tmp {
        top = Path(tmp).resolve();
        for rel in ["impl", "test"] {
            (top / rel).mkdir();
        }
        for name in ["test.jac", "impl.jac"] {
            (top / name).write_text("glob x = 1;\n");
        }
        assert is_annex_path_of(
            str(top / "test" / "test.test.jac"), str(top / "test.jac")
        );
        assert is_annex_path_of(
            str(top / "impl" / "impl.impl.jac"), str(top / "impl.jac")
        );
        assert not is_annex_path_of(
            str(top / "test" / "other.test.jac"), str(top / "test.jac")
        );
        assert not is_annex_path_of(
            str(top / "testing.test.jac"), str(top / "test.jac")
        );
        watcher = JacFileWatcher(
            watch_paths=[
                str(top / "impl"),
                str(top / "test"),
                str(top / "test.jac"),
                str(top / "impl.jac")
            ]
        );
        for name in [
            "test/test.test.jac",
            "impl/impl.impl.jac",
            "test/other.test.jac"
        ] {
            watcher._on_change(str(top / name), ChangeType.MODIFIED);
        }
        seen = sorted(str(Path(p).relative_to(top)) for p in watcher._pending_events);
        assert seen == ["impl/impl.impl.jac", "test/test.test.jac"] , str(seen);
    }
}

test "a root-level module brings its annex folders into the watch roots" {
    import os;
    with tempfile.TemporaryDirectory() as tmp {
        top = os.path.realpath(tmp);
        base = os.path.join(top, "web");
        for rel in ["web", "shared.impl", "impl", "other.impl"] {
            os.makedirs(os.path.join(top, rel));
        }
        shared = os.path.join(top, "shared.jac");
        sources = [os.path.join(base, "main.jac"), shared];
        assert watch_roots(base, top, sources)
            == [
                base,
                os.path.join(top, "impl"),
                os.path.join(top, "shared.impl"),
                shared
            ];
    }
}

# --- TestJacFileWatcher ---
test "watcher can be instantiated" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        assert watcher is not None;
        assert watcher.watch_paths == [str(temp_dir)];
        assert watcher.pattern == "*.jac";
        assert watcher.additional_patterns
            == ["*.tsx", "*.js", "*.css", "*.scss", "*.png", "*.jpg", "*.jpeg"];
        assert watcher._running is False;
    }
}

test "pattern matches jac files" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        # Test main pattern (*.jac)
        assert watcher._matches_pattern("app.jac") is True;
        assert watcher._matches_pattern("component.jac") is True;
        # Test additional patterns
        assert watcher._matches_pattern("app.tsx") is True;
        assert watcher._matches_pattern("script.js") is True;
        assert watcher._matches_pattern("styles.css") is True;
        assert watcher._matches_pattern("styles.scss") is True;
        assert watcher._matches_pattern("image.png") is True;
        assert watcher._matches_pattern("photo.jpg") is True;
        assert watcher._matches_pattern("photo.jpeg") is True;
        # Test non-matching patterns
        assert watcher._matches_pattern("config.json") is False;
        assert watcher._matches_pattern("script.py") is False;
        assert watcher._matches_pattern("readme.md") is False;
    }
}

test "callback registration" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        callback = MagicMock();
        watcher.add_callback(_as_any(callback));
        assert callback in watcher._callbacks;
        watcher.remove_callback(_as_any(callback));
        assert callback not in watcher._callbacks;
    }
}

test "start and stop" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        assert watcher._running is False;
        watcher.start();
        assert watcher._running is True;
        watcher.stop();
        assert watcher._running is False;
    }
}

test "debounce consolidates rapid changes" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)], _debounce_ms=50);
        events: list[FileChangeEvent] = [];
        watcher.add_callback(lambda (e) { events.append(e); });
        watcher.start();
        # Simulate rapid changes to the same file
        test_file = str(temp_dir / "app.jac");
        for _ in range(5) {
            watcher._on_change(test_file, ChangeType.MODIFIED);
        }
        # Wait for debounce to flush
        time.sleep(0.2);
        watcher.stop();
        # Should consolidate to 1-2 events (not 5)
        assert len(events) <= 2 , f"Expected <=2 events, got {len(events)}";
    }
}

test "file change detection" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)], _debounce_ms=50);
        events: list[FileChangeEvent] = [];
        watcher.add_callback(lambda (e) { events.append(e); });
        # Create test file before starting watcher
        test_file = temp_dir / "test.jac";
        test_file.write_text("initial content");
        watcher.start();
        time.sleep(0.2);  # Let watcher initialize
        # Modify the file
        test_file.write_text("modified content");
        time.sleep(0.5);  # Wait for detection and debounce
        watcher.stop();
        # Should have detected the change
        assert len(events) >= 1 , "File change was not detected";
        assert any("test.jac" in e.path for e in events) , (
            f"no event named the changed file: {[e.path for e in events]}"
        );
    }
}

# --- TestHotReloader ---
test "hot reloader can be instantiated" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        assert reloader is not None;
        assert reloader.base_path == str(temp_dir);
        assert reloader.module_name == "test";
        assert reloader._running is False;
    }
}

test "start and stop reloader" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        assert reloader._running is False;
        reloader.start();
        assert reloader._running is True;
        reloader.stop();
        assert reloader._running is False;
    }
}

test "get js filename" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        # Test various input file names
        # Note: .jac files become .js (not .cl.js)
        assert reloader._get_js_filename("app.jac") == "app.js";
        assert reloader._get_js_filename("component.jac") == "component.js";
        assert reloader._get_js_filename("/path/to/module.jac") == "module.js";
    }
}

test "classify declarations server only" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        # Create a server-only jac file
        test_file = temp_dir / "server.jac";
        test_file.write_text(
            "walker greet {\n"
            "    can enter with Root entry {\n"
            "        return {\"message\": \"hello\"};\n"
            "    }\n"
            "}\n"
        );
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        (has_client, has_server, has_native) = reloader._classify_declarations(
            str(test_file)
        );
        # Server code should be detected
        assert has_server is True;
    }
}

test "client output dir default" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        assert reloader._client_output_dir == ".jac/client/compiled";
    }
}

# --- TestBuildStatus ---
test "build status records errors and recovers" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        # Fresh reloader is healthy
        assert reloader.build_status() == {"status": "ok", "diagnostics": []};
        # An error carries a located, rendered diagnostic value
        reloader.record_error("app.jac", "Missing ';'", line=2, column=9);
        status = reloader.build_status();
        assert status["status"] == "error";
        assert len(status["diagnostics"]) == 1;
        diag = status["diagnostics"][0];
        assert diag["file"] == "app.jac";
        assert diag["line"] == 2 and diag["column"] == 9;
        assert "Missing ';'" in diag["message"];
        assert diag["channel"] == "jac";
        assert diag["code"] == "E7005";
        # Recovery clears the error completely
        reloader.record_ok();
        assert reloader.build_status() == {"status": "ok", "diagnostics": []};
    }
}

test "build status folds in client events, with jac precedence" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        (temp_dir / ".jac" / "client" / "compiled").mkdir(parents=True);
        # A Vite resolve failure forwarded raw by the dev plugin surfaces even
        # though the Jac transpile layer is clean (#7286)
        reloader.record_client_event(
            "vite",
            {
                "message": 'Failed to resolve import "totally-missing-pkg"',
                "id": "compiled/pages/index.js",
                "plugin": "vite:import-analysis"
            }
        );
        status = reloader.build_status();
        assert status["status"] == "error";
        assert status["diagnostics"][0]["channel"] == "vite";
        assert "totally-missing-pkg" in status["diagnostics"][0]["message"];
        # A Jac build failure outranks the layers downstream of it
        reloader.record_error("app.jac", "syntax");
        assert reloader.build_status()["diagnostics"][0]["channel"] == "jac";
        reloader.record_ok();
        assert reloader.build_status()["diagnostics"][0]["channel"] == "vite";
        # Recovery: the plugin sends a null payload for the slot it cleared
        reloader.record_client_event("vite", None);
        assert reloader.build_status() == {"status": "ok", "diagnostics": []};
        # An unknown slot or a payload with no message is ignored
        reloader.record_client_event("nonsense", {"message": "x"});
        reloader.record_client_event("vite", {"message": ""});
        assert reloader.build_status() == {"status": "ok", "diagnostics": []};
    }
}

test "get build status reflects the active reloader" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        # No reloader running (non-dev mode) -> unavailable
        assert get_build_status() == {"status": "unavailable", "diagnostics": []};
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        reloader.start();
        # Running reloader's state is served, including errors
        assert get_build_status()["status"] == "ok";
        reloader.record_error("main.jac", "boom");
        assert get_build_status()["status"] == "error";
        reloader.stop();
        # Stopped -> unavailable again
        assert get_build_status() == {"status": "unavailable", "diagnostics": []};
    }
}

test "process change settles to ok unless an error was recorded" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        # A change whose rebuild records no error ends healthy,
        # even when the build was previously broken.
        reloader.record_error("app.jac", "old failure");
        reloader._dispatch_change = lambda (p, d) { None; };
        reloader._process_change("app.jac");
        assert reloader.build_status() == {"status": "ok", "diagnostics": []};
        # A change whose rebuild records an error stays broken.
        reloader._dispatch_change = lambda (p, d) { reloader.record_error(p, "boom"); };
        reloader._process_change("app.jac");
        status = reloader.build_status();
        assert status["status"] == "error";
        assert status["diagnostics"][0]["file"] == "app.jac";
    }
}

# --- TestExportChangeReload ---
# Fast Refresh boundaries hot-swap component edits silently, so an edit that
# changes a module's export set (removing `:pub`, renaming a component) leaves
# importers with a stale reference and no error. The reloader compares the
# emitted .js exports before/after a recompile and forces a full reload so the
# link error surfaces at load.
test "extract js exports reads the compiled export list" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        js = temp_dir / "mod.js";
        js.write_text(
            "function Page() {}\nconst page = Page;\nexport {page, Card as c};\n"
        );
        assert reloader._extract_js_exports(js) == {"page", "c"};
        # A module that dropped its export (e.g. `:pub` removed) reads as empty
        js.write_text("function Page() {}\n");
        assert reloader._extract_js_exports(js) == set();
        # Missing file is empty, never an exception
        assert reloader._extract_js_exports(temp_dir / "gone.js") == set();
    }
}

test "signal full reload bumps the watched nonce file" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        client_dir = temp_dir / ".jac" / "client";
        client_dir.mkdir(parents=True);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        signal = client_dir / ".jac-force-reload";
        reloader._signal_full_reload();
        first = signal.read_text();
        # Each signal writes a distinct value so the Vite watcher sees a change
        reloader._signal_full_reload();
        assert signal.read_text() != first;
    }
}

"""Client compiler stub: emits `next_code` as the module's compiled output."""
obj _FakeJcc {
    has out_path: Path,
        next_code: str,
        compiled_dir: str;

    def _output_path_for(source_path: any, base_dir: any) -> Path {
        return self.out_path;
    }

    def emit_dependencies(source_path: any, source_root: any = None) {
        self.out_path.write_text(self.next_code);
    }
}

obj _FakeCompiler {
    has jac_client_compiler: any;
}

test "recompile signals a full reload only when the export set changes" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        compiled = temp_dir / ".jac" / "client" / "compiled";
        compiled.mkdir(parents=True);
        src = temp_dir / "widget.jac";
        src.write_text("def:pub Widget() -> JsxElement { return <p>w</p>; }");
        js = compiled / "widget.js";
        with_export = "function Widget() {}\nexport {Widget};\n";
        js.write_text(with_export);
        jcc = _FakeJcc(out_path=js, next_code=with_export, compiled_dir=str(compiled));
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir),
            module_name="test",
            watcher=watcher,
            client_compiler=_FakeCompiler(jac_client_compiler=jcc)
        );
        signal = compiled.parent / ".jac-force-reload";
        # An edit that leaves the export set alone stays hot-swappable
        reloader._recompile_client_unified(str(src));
        assert not signal.exists() , "a body-only edit must not force a reload";
        # Dropping `:pub` removes the export: importers hold a stale reference,
        # so the reloader must force a reload for the error to surface
        jcc.next_code = "function Widget() {}\n";
        reloader._recompile_client_unified(str(src));
        assert signal.exists() , "a removed export must force a reload";
        # Renaming the component is a removal plus an addition
        signal.unlink();
        jcc.next_code = "function Renamed() {}\nexport {Renamed};\n";
        reloader._recompile_client_unified(str(src));
        assert signal.exists() , "a renamed export must force a reload";
    }
}

test "reloading a broken module reports its errors once per reload" {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.meta_importer { _module_scoped_alerts }
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        broken = temp_dir / "broken_reload.jac";
        broken.write_text("def broken_repro( -> {{{ SYNTAX ERROR\n");
        resolved = str(broken.resolve());
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="broken_reload", watcher=watcher
        );
        # `errors_had` is append-only and `_module_scoped_alerts` -- what the
        # overlay, /__build_status and editor diagnostics all read -- scans the
        # whole list. Without the eviction `_reload_server_module` performs,
        # saving a broken file three times reports the same syntax error 3x.
        counts = [];
        for _ in range(3) {
            reloader._reload_server_module(resolved);
            counts.append(len(_module_scoped_alerts(Jac.program, resolved)));
        }
        try {
            assert counts[0] > 0 , "a broken module must report at least one alert";
            assert counts == [counts[0], counts[0], counts[0]] , f"alerts accumulated across reloads: {counts}";
        } finally {
            # Long-lived global program: do not leak this file's alerts into
            # whatever else runs in this worker.
            _as_any(Jac.program).drop_module_alerts(resolved);
        }
    }
}

# --- TestHMRIntegration ---
test "file change triggers callback" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        # Create initial file
        test_file = temp_dir / "app.jac";
        test_file.write_text("with entry { print(\"v1\"); }");
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)], _debounce_ms=50);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        # Track if callback was called
        callback_called = threading.Event();
        def mock_callback(event: object) {
            callback_called.set();
        }
        reloader.on_file_change = mock_callback;
        reloader.start();
        time.sleep(0.2);  # Let watcher initialize
        # Modify file
        test_file.write_text("with entry { print(\"v2\"); }");
        time.sleep(0.5);
        reloader.stop();
        assert callback_called.is_set() , "File change callback was not triggered";
    }
}

test "multiple file changes handled" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        # Create multiple files
        file1 = temp_dir / "module1.jac";
        file2 = temp_dir / "module2.jac";
        file1.write_text("glob x = 1;");
        file2.write_text("glob y = 2;");
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)], _debounce_ms=50);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        changed_files: list[str] = [];
        def track_changes(event: FileChangeEvent) {
            changed_files.append(event.path);
        }
        reloader.on_file_change = track_changes;
        reloader.start();
        time.sleep(0.2);
        # Modify both files
        file1.write_text("glob x = 10;");
        time.sleep(0.3);
        file2.write_text("glob y = 20;");
        time.sleep(0.3);
        reloader.stop();
        # Both files should have been detected
        assert len(changed_files) >= 2 , f"Expected 2+ changes, got {len(
            changed_files
        )}";
    }
}

# --- TestWatcherMovesAndResilience ---
test "moves emit delete plus create; directories flagged, noise filtered" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        (temp_dir / "a.jac").write_text("glob x = 1;");
        (temp_dir / "pagesx").mkdir();
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)], _debounce_ms=50);
        events: list[FileChangeEvent] = [];
        watcher.add_callback(lambda (e) { events.append(e); });
        watcher.start();
        time.sleep(0.3);
        import os;
        os.rename(str(temp_dir / "a.jac"), str(temp_dir / "b.jac"));
        os.rename(str(temp_dir / "pagesx"), str(temp_dir / "pages"));
        (temp_dir / "node_modules").mkdir();
        (temp_dir / ".git").mkdir();
        time.sleep(0.6);
        watcher.stop();
        kinds = {(Path(e.path).name, e.change_type, e.is_directory) for e in events};
        assert ("a.jac", ChangeType.DELETED, False) in kinds , f"file rename must emit DELETED(old), got {kinds}";
        assert ("b.jac", ChangeType.CREATED, False) in kinds , f"file rename must emit CREATED(new), got {kinds}";
        assert ("pagesx", ChangeType.DELETED, True) in kinds , f"dir move must emit directory-flagged DELETED, got {kinds}";
        assert ("pages", ChangeType.CREATED, True) in kinds , f"dir move must emit directory-flagged CREATED, got {kinds}";
        noise = {
            n
            for (n, _, d) in kinds
            if d and n in {"node_modules", ".git"}
        };
        assert not noise , f"tooling directories must never reach callbacks, got {noise}";
    }
}

test "flush loop survives an exception and keeps delivering" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)], _debounce_ms=50);
        events: list[FileChangeEvent] = [];
        watcher.add_callback(lambda (e) { events.append(e); });
        original_flush = watcher._debounce_flush;
        def exploding_flush {
            raise RuntimeError("boom");
        }
        watcher._debounce_flush = exploding_flush;
        watcher.start();
        time.sleep(0.3);  # flush loop hits the exploding flush several times
        watcher._debounce_flush = original_flush;
        watcher._on_change(str(temp_dir / "late.jac"), ChangeType.MODIFIED);
        time.sleep(0.4);
        watcher.stop();
        assert len(events) >= 1 , "flush loop must survive an exception and keep delivering events";
    }
}
