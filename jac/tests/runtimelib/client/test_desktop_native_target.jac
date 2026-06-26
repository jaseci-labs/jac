"""Tests for the Jac-native desktop target + config.

These exercise the direct target registration and config surface. The native
webview binding has a dependency-free test alongside this one:
`test_desktop_binding.jac`.
"""

"""register_targets() registers the native + CEF desktop targets in the registry.

The desktop targets ship with core now and register directly via
`register_targets()` instead of a secondary `jac_client` pluggy plugin group.
"""
test "register_targets registers the desktop targets" {
    import from jaclang.runtimelib.client.targets.register { register_targets }
    import from jaclang.runtimelib.client.targets.registry { get_target_registry }

    register_targets();
    registry = get_target_registry();
    target = registry.get("desktop");
    assert target is not None , "desktop target should be registered";
    assert target.name == "desktop" , "target name should be 'desktop'";
    # The native target needs no scaffolding (unlike the old PyTauri target).
    assert target.requires_setup == False , "native desktop needs no setup step";
    # The CEF renderer target registers alongside the native one.
    cef = registry.get("cef");
    assert cef is not None , "CEF desktop target should be registered";
    assert cef.name == "cef" , "CEF target name should be 'cef'";
}

"""Window geometry is read from [plugins.desktop.window]."""
test "desktop window config loads from jac.toml" {
    import from jaclang.runtimelib.client.desktop_config {
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
                '[plugins.desktop.window]\ntitle = "Hi"\nwidth = 640\nheight = 480\n'
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
    import from jaclang.runtimelib.client.desktop_config {
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

"""In-process dispatch tuning is read from [plugins.desktop.dispatch], with
sensible defaults when the section is absent (P1-A, issue #6596)."""
test "desktop dispatch config loads from jac.toml" {
    import from jaclang.runtimelib.client.desktop_config {
        get_desktop_config,
        reset_desktop_config
    }
    import from pathlib { Path }
    import tempfile;

    with tempfile.TemporaryDirectory() as d {
        reset_desktop_config();
        # No [plugins.desktop.dispatch] -> documented defaults.
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
                '[plugins.desktop.dispatch]\ntimeout_s = 5.0\nmax_queue = 16\ndebug = true\n'
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

"""The host brings up the fused runtime via the libjacpyembed shim (jac_engine_boot)
instead of binding the build machine's libpython, and never bakes build-machine
state. DISPATCH_PY's jac-scale seam is a slim runtime-only hook (no user-site/
getsitepackages baking)."""
test "host source boots the fused runtime and bakes no build-machine state" {
    import from jaclang.runtimelib.client.targets.desktop._host_bootstrap {
        _generate_host_source
    }

    src = _generate_host_source("T", 800, 600, "test-app");
    # Fused-runtime bring-up: the shim, not libpython-by-soname.
    assert "import from jacpyembed" in src , "host must import the libjacpyembed shim";
    assert "jac_engine_boot()" in src , "host must boot the fused runtime";
    assert "libpython" not in src , "host must not bind a libpython soname";
    assert "DISPATCH_PY" in src , "host source must declare DISPATCH_PY";
    assert "inprocess_dispatch.boot" in src , "DISPATCH_PY must call boot()";
    # No build-machine site-package baking (the old _builder_dep_site_dirs path).
    assert "getusersitepackages" not in src , "must not reference user-site packages";
    assert "getsitepackages" not in src , "must not bake interpreter site-packages";
    assert "_baked_dep_sites" not in src , "must not bake builder site dirs";
}

"""DISPATCH_PY's jac-scale seam is runtime-only and portable: it reads
JAC_DESKTOP_SCALE_SRC / JAC_DESKTOP_DEPS at runtime, with no build-time baking,
so the one binary stays portable until jac-scale is bundled into the runtime."""
test "DISPATCH_PY jac-scale hook is the slim runtime-only seam" {
    import from jaclang.runtimelib.client.targets.desktop._host_bootstrap {
        _generate_host_source
    }

    src = _generate_host_source("T", 800, 600, "test-app");
    assert "JAC_DESKTOP_SCALE_SRC" in src , "host must read the runtime jac-scale source seam";
    assert "JAC_DESKTOP_DEPS" in src , "host must read the runtime deps seam";
}

"""Generated host source must call inprocess_dispatch.shutdown() after run_main_loop()
and before Py_Finalize() so the dispatch worker and transport tear down cleanly."""
test "generated host calls shutdown after run_main_loop()" {
    import from jaclang.runtimelib.client.targets.desktop._host_bootstrap {
        _generate_host_source
    }

    src = _generate_host_source("T", 800, 600, "test-app");
    assert "inprocess_dispatch.shutdown()" in src , "host must tear down dispatch on exit";
    assert src.index("run_main_loop()") < src.index("inprocess_dispatch.shutdown()") , "shutdown must run after the webview event loop exits";
    # Match the entry-block call ("Py_Finalize();"), not the FFI decl
    # ("Py_Finalize() -> None;") above it.
    assert src.index("inprocess_dispatch.shutdown()") < src.index("Py_Finalize();") , "shutdown must run before Py_Finalize()";
}

"""Editable worktree roots are auto-detected from __editable__.*.pth links."""
test "dev launch detects editable worktree roots" {
    import os;
    import from pathlib { Path }
    import from jaclang.runtimelib.client.targets.desktop._dev_launch {
        _editable_roots_from_site
    }

    roots = _editable_roots_from_site();
    if (Path(os.environ.get("JAC_DESKTOP_JAC_SRC", "")) / "jaclang").exists() {
        assert "JAC_DESKTOP_JAC_SRC" in roots , "editable jaclang root should be detected";
    }
    if (
        Path(os.environ.get("JAC_DESKTOP_SCALE_SRC", "")) / "jac_scale" / "inprocess.jac"
    ).exists() {
        assert "JAC_DESKTOP_SCALE_SRC" in roots , "editable jac-scale root should be detected";
    }
}
