"""Tests for the Jac desktop target + config.

These exercise the direct target registration and config surface. The native
webview binding has a dependency-free test alongside this one:
`test_desktop_binding.jac`.
"""

"""register_targets() registers one desktop target in the registry.

The desktop target ships with core and registers directly via
`register_targets()` instead of a secondary `jac_client` pluggy plugin group.
The renderer engine (native webview or CEF) is not a separate target: it is
picked per project through `[desktop] engine`.
"""
test "register_targets registers the desktop target" {
    import from pathlib { Path }
    import from jaclang.client.targets.register { register_targets }
    import from jaclang.client.targets.registry {
        KIND_TARGET,
        get_target_registry,
        target_for_kind
    }
    import from jaclang.client.targets.desktop.desktop_target { DesktopTarget }
    import from jaclang.client.targets.web_target { WebTarget }

    register_targets();
    registry = get_target_registry();
    target = registry.get("desktop");
    assert target is not None , "desktop target should be registered";
    assert target.name == "desktop" , "target name should be 'desktop'";
    assert isinstance(target, DesktopTarget);
    assert isinstance(target, WebTarget) , "the desktop build wraps the web bundle";
    # The native target needs no scaffolding (unlike the old PyTauri target).
    assert target.requires_setup == False , "native desktop needs no setup step";
    assert str(target.output_dir) == str(Path(".jac/client/desktop"));
    # The desktop kind is what selects it.
    assert KIND_TARGET["desktop"] == "desktop";
    assert target_for_kind("desktop", Path(".")) is target;
    # CEF is an engine of this one target, not a second registered target.
    assert registry.get("cef") is None , "'cef' is not a client target any more";
    assert registry.get("native-desktop") is None;
}

"""DesktopTarget.engine() reads `[desktop] engine` and dispatches on it: the
default is the native webview, and `engine = "cef"` selects the CEF shell.
The two shells are helper modules, not targets of their own."""
test "desktop target dispatches on the configured engine" {
    import tempfile;
    import unittest.mock;
    import from pathlib { Path }
    import from jaclang.client.desktop_config { reset_desktop_config }
    import from jaclang.client.targets.desktop.desktop_target { DesktopTarget }
    import jaclang.client.targets.desktop.cef_shell as cef_shell;
    import jaclang.client.targets.desktop.webview_shell as webview_shell;

    target = DesktopTarget();
    with tempfile.TemporaryDirectory() as d {
        proj = Path(d);
        reset_desktop_config();
        (proj / "jac.toml").write_text(
            '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
            'kind = "desktop"\n'
        );
        assert target.engine(proj) == "native" , "engine defaults to the native webview";
        reset_desktop_config();
        (proj / "jac.toml").write_text(
            '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
            'kind = "desktop"\n\n[desktop]\nengine = "cef"\n'
        );
        assert target.engine(proj) == "cef" , "[desktop] engine = cef selects CEF";
        # dev: the CEF shell has no dev loop; the native one does. Stub both
        # shells so no bundle is built and no window opens.
        calls: list[str] = [];
        def _cef_dev_unsupported {
            calls.append("cef_dev_unsupported");
            raise RuntimeError("cef dev unsupported (stub)");
        }
        def _webview_dev(
            entry_file: Path,
            project_dir: Path,
            out_dir: Path,
            port: int = 8000,
            api_port: int = 0
        ) {
            calls.append("webview_dev");
        }
        with unittest.mock.patch.object(
            cef_shell, "cef_dev_unsupported", _cef_dev_unsupported
        ), unittest.mock.patch.object(webview_shell, "webview_dev", _webview_dev) {
            raised = False;
            try {
                target.dev(proj / "main.jac", proj);
            } except RuntimeError as e {
                raised = True;
                assert "cef dev unsupported" in str(e);
            }
            assert raised , "under engine = cef, dev must refuse via cef_dev_unsupported";
            assert calls == ["cef_dev_unsupported"];
            reset_desktop_config();
            (proj / "jac.toml").write_text(
                '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
                'kind = "desktop"\n'
            );
            target.dev(proj / "main.jac", proj);
            assert calls == ["cef_dev_unsupported", "webview_dev"] , (
                "under the native engine, dev runs the webview dev loop"
            );
        }
        reset_desktop_config();
    }
}

"""Window geometry is read from [desktop.window]."""
test "desktop window config loads from jac.toml" {
    import from jaclang.client.desktop_config {
        get_desktop_config,
        reset_desktop_config
    }
    import from pathlib { Path }
    import tempfile;

    with tempfile.TemporaryDirectory() as d {
        reset_desktop_config();
        with open(Path(d) / "jac.toml", "w") as f {
            f.write(
                '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
                '[desktop.window]\ntitle = "Hi"\nwidth = 640\nheight = 480\n'
            );
        }
        cfg = get_desktop_config(project_dir=Path(d));
        win = cfg.get_window_config();
        assert win.title == "Hi" , "window title should load from jac.toml";
        assert win.width == 640 , "window width should load from jac.toml";
        assert win.height == 480 , "window height should load from jac.toml";
        reset_desktop_config();
    }
}

"""Engine defaults to 'native' and validates 'native'/'cef'."""
test "desktop engine config defaults to native" {
    import from jaclang.client.desktop_config {
        get_desktop_config,
        reset_desktop_config
    }
    import from pathlib { Path }
    import tempfile;

    with tempfile.TemporaryDirectory() as d {
        reset_desktop_config();
        with open(Path(d) / "jac.toml", "w") as f {
            f.write(
                '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
            );
        }
        cfg = get_desktop_config(project_dir=Path(d));
        engine = cfg.get_engine();
        assert engine == "native" , "engine should default to 'native'";
        reset_desktop_config();
    }
}

"""In-process dispatch tuning is read from [desktop.dispatch], with
sensible defaults when the section is absent (P1-A, issue #6596)."""
test "desktop dispatch config loads from jac.toml" {
    import from jaclang.client.desktop_config {
        get_desktop_config,
        reset_desktop_config
    }
    import from pathlib { Path }
    import tempfile;

    with tempfile.TemporaryDirectory() as d {
        reset_desktop_config();
        # No [desktop.dispatch] -> documented defaults.
        with open(Path(d) / "jac.toml", "w") as f {
            f.write(
                '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
            );
        }
        cfg = get_desktop_config(project_dir=Path(d));
        d1 = cfg.get_dispatch_config();
        assert d1.timeout_s == 30.0 , "default dispatch timeout is 30s";
        assert d1.max_queue == 128 , "default dispatch queue depth is 128";
        # P1-C: debug (traceback gating) defaults OFF -- the release contract.
        assert d1.debug == False , "dispatch debug defaults off (no traceback leakage)";
        reset_desktop_config();
        # Explicit values override the defaults.
        with open(Path(d) / "jac.toml", "w") as f {
            f.write(
                '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
                '[desktop.dispatch]\ntimeout_s = 5.0\nmax_queue = 16\ndebug = true\n'
            );
        }
        cfg2 = get_desktop_config(project_dir=Path(d));
        d2 = cfg2.get_dispatch_config();
        assert d2.timeout_s == 5.0 , "dispatch timeout should load from jac.toml";
        assert d2.max_queue == 16 , "dispatch queue depth should load from jac.toml";
        assert d2.debug == True , "dispatch debug should load from jac.toml";
        reset_desktop_config();
    }
}

"""The host brings up the fused runtime through the fused runtime library
(engine_boot) instead of binding the build machine's libpython, and never bakes
build-machine state. All boot behavior lives in the host_boot runtime module; the generated
source only carries configuration plus the native bridge."""
test "host source boots the fused runtime and bakes no build-machine state" {
    import from jaclang.client.targets.desktop._host_bootstrap { _generate_host_source }

    src = _generate_host_source("T", 800, 600, "test-app");
    # Fused-runtime bring-up: the fused runtime library, not libpython-by-soname.
    assert "import from fused.bringup" in src , "host must import the fused runtime library";
    assert "engine_boot()" in src , "host must boot the fused runtime";
    assert "libpython" not in src , "host must not bind a libpython soname";
    # Thin boot contract: one BOOT_PY statement into the host_boot module.
    assert "BOOT_PY" in src , "host source must declare BOOT_PY";
    assert "host_boot.boot(" in src , "BOOT_PY must call host_boot.boot()";
    # No build-machine site-package baking (the old _builder_dep_site_dirs path).
    assert "getusersitepackages" not in src , "must not reference user-site packages";
    assert "getsitepackages" not in src , "must not bake interpreter site-packages";
    assert "_baked_dep_sites" not in src , "must not bake builder site dirs";
    assert "JAC_DESKTOP_SCALE_SRC" not in src , "separate scale-source seam is gone (scale is folded into jaclang)";
}

"""host_boot's deps seam is runtime-only and portable: it reads JAC_DESKTOP_DEPS
at boot time with no build-time baking. Exercise the real code path instead of
grepping generated strings."""
test "host_boot applies the runtime extra-deps seam" {
    import os;
    import sys;
    import from jaclang.client.targets.desktop.native { host_boot }

    _saved_path = list(sys.path);
    _saved_env = os.environ.get("JAC_DESKTOP_DEPS");
    fake_a = os.path.join(os.sep, "nonexistent-jac-deps-a");
    fake_b = os.path.join(os.sep, "nonexistent-jac-deps-b");
    try {
        os.environ["JAC_DESKTOP_DEPS"] = fake_a + os.pathsep + fake_b;
        host_boot._apply_extra_deps();
        assert fake_a in sys.path , "first JAC_DESKTOP_DEPS entry must join sys.path";
        assert fake_b in sys.path , "second JAC_DESKTOP_DEPS entry must join sys.path";
        # Idempotent: applying twice must not duplicate entries.
        host_boot._apply_extra_deps();
        assert sys.path.count(fake_a) == 1 , "deps seam must not duplicate sys.path entries";
    } finally {
        sys.path[:] = _saved_path;
        if _saved_env is None {
            os.environ.pop("JAC_DESKTOP_DEPS", None);
        } else {
            os.environ["JAC_DESKTOP_DEPS"] = _saved_env;
        }
    }
}

"""desktop_app_runtime_env and the generated launch script must wire the project
venv into JAC_DESKTOP_DEPS -- otherwise the fused desktop host cannot import
serve deps that `jac install` placed in `.jac/venv`."""
test "desktop launch wires JAC_DESKTOP_DEPS from the project venv" {
    import os;
    import tempfile;
    import shutil;
    import from pathlib { Path }
    import from jaclang.client.targets.desktop._dev_launch {
        desktop_app_runtime_env,
        jac_desktop_deps_shell_export,
        jac_desktop_webkit_shell_export
    }

    # Pin the launch-script contract on the shared shell fragments.
    webkit = jac_desktop_webkit_shell_export();
    assert "GDK_BACKEND" in webkit , "launch script must export GDK_BACKEND";
    assert "WEBKIT_DISABLE_DMABUF_RENDERER" in webkit;
    snippet = jac_desktop_deps_shell_export();
    assert "JAC_DESKTOP_DEPS" in snippet , "launch script must export JAC_DESKTOP_DEPS";
    assert "venv/lib" in snippet , "launch script must discover the sibling project venv";

    tmp = tempfile.mkdtemp(prefix="jac_desktop_deps_");
    _saved = os.environ.get("JAC_DESKTOP_DEPS");
    _cwd = os.getcwd();
    try {
        proj = Path(tmp);
        (proj / "jac.toml").write_text(
            "[project]\nname = \"d\"\nversion = \"0.1.0\"\n"
        );
        site = proj / ".jac" / "venv" / "lib" / "python3.14" / "site-packages";
        site.mkdir(parents=True);
        os.chdir(proj);
        os.environ.pop("JAC_DESKTOP_DEPS", None);
        env = desktop_app_runtime_env({});
        assert env.get("JAC_DESKTOP_DEPS") == str(site) , (
            f"desktop_app_runtime_env must set JAC_DESKTOP_DEPS to the project venv site, got {env.get(
                'JAC_DESKTOP_DEPS'
            )!r}"
        );
    } finally {
        os.chdir(_cwd);
        if _saved is None {
            os.environ.pop("JAC_DESKTOP_DEPS", None);
        } else {
            os.environ["JAC_DESKTOP_DEPS"] = _saved;
        }
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

"""Generated host source must stop the loopback server (_ctx.shutdown()) after
run_main_loop() and before Py_Finalize() so the transport tears down cleanly."""
test "generated host calls shutdown after run_main_loop()" {
    import from jaclang.client.targets.desktop._host_bootstrap { _generate_host_source }

    src = _generate_host_source("T", 800, 600, "test-app");
    assert "_ctx.shutdown()" in src , "host must stop the loopback server on exit";
    assert src.index("run_main_loop()") < src.index("_ctx.shutdown()") , "shutdown must run after the webview event loop exits";
    # Match the entry-block call ("Py_Finalize();"), not the FFI decl
    # ("Py_Finalize() -> None;") above it.
    assert src.index("_ctx.shutdown()") < src.index("Py_Finalize();") , "shutdown must run before Py_Finalize()";
}

"""na (LLVM) is first-class in the fused runtime a desktop app bundles.

The desktop host appends the CLI's `[payload][trailer]` (desktop_build.
_bundle_runtime), so an app materializes the SAME fused runtime the CLI uses --
which carries the LLVMPY shim the native backend ctypes-loads AND the na compiler
pass. So any app on this runtime can `jac nacompile` / run `na` exactly like the
CLI. This test runs in that runtime (the test interpreter), so locating the shim
+ the na pass here verifies na is first-class on desktop by construction."""
test "na/LLVM backend is first-class in the desktop fused runtime" {
    import os;
    import importlib.util;
    import from jaclang.compiler.backends.native.llvm.binding.ffi {
        _find_shim,
        _shim_name
    }

    shim = _find_shim();
    assert os.path.isfile(shim) , f"LLVMPY shim missing from the fused runtime: {shim}";
    assert shim.endswith(_shim_name()) , "resolved shim must be the platform LLVMPY shim";
    # The native compiler pass is importable, so `nacompile` is available to any
    # app running on this fused runtime (the one the desktop host bundles).
    spec = importlib.util.find_spec("jaclang.compiler.backends.native.na_compile_pass");
    assert spec is not None , "na compiler pass must be importable in the desktop runtime";
}

"""The desktop host imports its bootstrap modules from the fused runtime -- no
transpiled .py staged beside the binary. Prove it by running host_boot's plugin
bootstrap + the broker imports in THIS runtime (the same fused runtime a
desktop app boots): the closest dependency-free proxy for the embedded host,
catching an import-from-runtime regression without a display."""
test "host bootstrap modules import + run from the fused runtime" {
    import from jaclang.client.targets.desktop.native {
        broker_extension,
        host_boot,
        oauth_broker
    }

    # The bootstrap inserts the runtime plugin dir on sys.path and imports the
    # plugins as TOP-LEVEL modules (manifest, registry, built_in.*). Snapshot +
    # restore import state so it can't shadow other suites' staged plugin copies
    # in a shared worker (the integration suite stages its own to a tmp dir).
    import sys;
    _saved_path = list(sys.path);
    _saved_mods = set(sys.modules.keys());
    try {
        # The plugin bootstrap loads the plugins from the runtime + wires the
        # dispatch host (registry.bootstrap_plugins) in the fused runtime.
        _host = host_boot._bootstrap_plugin_host({"path": True});
        assert callable(_host.dispatch) , "plugin bootstrap must yield a dispatch callable from the runtime";
        # The broker pieces resolve from the runtime too (no staging).
        assert hasattr(oauth_broker, "build_sso_login_url") , "oauth_broker must import from the runtime";
        assert hasattr(broker_extension, "DesktopBrokerExtension") , "the broker extension must import from the runtime";
    } finally {
        sys.path[:] = _saved_path;
        for _k in list(sys.modules.keys()) {
            if _k not in _saved_mods {
                del sys.modules[_k];
            }
        }
    }
}

"""Editable worktree roots are auto-detected from __editable__.*.pth links."""
test "dev launch detects editable worktree roots" {
    import os;
    import from pathlib { Path }
    import from jaclang.client.targets.desktop._dev_launch { _editable_roots_from_site }

    roots = _editable_roots_from_site();
    if (Path(os.environ.get("JAC_DESKTOP_JAC_SRC", "")) / "jaclang").exists() {
        assert "JAC_DESKTOP_JAC_SRC" in roots , "editable jaclang root should be detected";
    }
    # Scale is folded into jaclang (jaclang.scale), so the editable jaclang root
    # carries it; there is no separate JAC_DESKTOP_SCALE_SRC root to detect.
    assert "JAC_DESKTOP_SCALE_SRC" not in roots , "no separate scale root (scale is part of jaclang)";
}
