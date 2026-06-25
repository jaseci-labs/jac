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
