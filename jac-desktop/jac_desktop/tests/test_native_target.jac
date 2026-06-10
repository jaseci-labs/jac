"""Tests for the Jac-native desktop target + config.

These exercise the plugin registration and config surface (need jac-client, so
they run in the client test job). The native webview binding has a
dependency-free test alongside this one: `test_binding.jac` (run in the lean
`test-desktop-native` CI job).
"""

"""The plugin registers both desktop targets (native + cef)."""
test "plugin registers desktop targets" {
    import from jac_desktop.plugin { JacDesktopPlugin }

    targets = JacDesktopPlugin.get_client_targets();
    assert isinstance(targets, list) , "get_client_targets should return a list";
    assert len(targets) == 2 , "two desktop targets expected (native + cef)";
    names = [t.name for t in targets];
    assert "desktop" in names , "native desktop target should be registered";
    assert "desktop-cef" in names , "CEF desktop target should be registered";
    # The native target needs no scaffolding.
    native = [
        t
        for t in targets
        if t.name == "desktop"
    ][0];
    assert native.requires_setup == False , "native desktop needs no setup step";
}

"""Window geometry is read from [plugins.desktop.window]."""
test "desktop window config loads from jac.toml" {
    import from jac_desktop.config_loader { get_desktop_config, reset_desktop_config }
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
    import from jac_desktop.config_loader { get_desktop_config, reset_desktop_config }
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
