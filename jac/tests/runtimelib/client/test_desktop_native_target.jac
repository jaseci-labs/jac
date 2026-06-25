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

"""Release-build generated host source must NOT reference user-site packages.
The `site.addsitedir(site.getusersitepackages())` call is dev-only (moved into
_dev_runtime_pin_py); release builds must not depend on ambient user-site state."""
test "release-build DISPATCH_PY has no site.getusersitepackages" {
    import from jaclang.runtimelib.client.targets.desktop._host_bootstrap {
        _generate_host_source
    }
    import os;

    saved_jac = os.environ.pop("JAC_DESKTOP_JAC_SRC", None);
    saved_scale = os.environ.pop("JAC_DESKTOP_SCALE_SRC", None);
    try {
        src = _generate_host_source("libpython3.12.so.1.0", "T", 800, 600, "test-app");
        assert "getusersitepackages" not in src , "release DISPATCH_PY must not reference user-site packages";
        assert "DISPATCH_PY" in src , "host source must declare DISPATCH_PY";
        assert "inprocess_dispatch.boot" in src , "DISPATCH_PY must call boot()";
    } finally {
        if saved_jac is not None {
            os.environ["JAC_DESKTOP_JAC_SRC"] = saved_jac;
        }
        if saved_scale is not None {
            os.environ["JAC_DESKTOP_SCALE_SRC"] = saved_scale;
        }
    }
}

"""Dev-build generated host source must contain the dev-pin block AND append
interpreter site dirs for third-party deps when JAC_DESKTOP_JAC_SRC/SCALE are set."""
test "dev-build DISPATCH_PY contains dev-pin and site deps append" {
    import from jaclang.runtimelib.client.targets.desktop._host_bootstrap {
        _generate_host_source
    }
    import os;

    saved_jac = os.environ.get("JAC_DESKTOP_JAC_SRC");
    saved_scale = os.environ.get("JAC_DESKTOP_SCALE_SRC");
    os.environ["JAC_DESKTOP_JAC_SRC"] = "/fake/jac";
    try {
        src = _generate_host_source("libpython3.12.so.1.0", "T", 800, 600, "test-app");
        assert "JAC_DESKTOP_JAC_SRC" in src , "dev build must embed the dev-pin block";
        assert "getusersitepackages" in src , "dev build must append user-site for deps";
        assert "getsitepackages" in src , "dev build must append interpreter site-packages for deps";
        assert "_baked_dep_sites" in src , "dev build must bake builder site-packages for jac-scale deps";
        assert "jaclang.meta_importer" not in src , "dev pin must not strip JacMetaImporter";
    } finally {
        if saved_jac is not None {
            os.environ["JAC_DESKTOP_JAC_SRC"] = saved_jac;
        } else {
            del os.environ["JAC_DESKTOP_JAC_SRC"];
        }
        if saved_scale is not None {
            os.environ["JAC_DESKTOP_SCALE_SRC"] = saved_scale;
        }
    }
}

"""Generated host source must call inprocess_dispatch.shutdown() after wv.run()
and before Py_Finalize() so the dispatch worker and transport tear down cleanly."""
test "generated host calls shutdown after wv.run()" {
    import from jaclang.runtimelib.client.targets.desktop._host_bootstrap {
        _generate_host_source
    }

    src = _generate_host_source("libpython3.12.so.1.0", "T", 800, 600, "test-app");
    assert "inprocess_dispatch.shutdown()" in src , "host must tear down dispatch on exit";
    assert src.index("wv.run()") < src.index("inprocess_dispatch.shutdown()") , "shutdown must run after the webview event loop exits";
    # Match the entry-block call, not the Py_Finalize FFI declaration above.
    assert src.index("inprocess_dispatch.shutdown()") < src.index(
        "    Py_Finalize();\n"
    ) , "shutdown must run before Py_Finalize()";
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
