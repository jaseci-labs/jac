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

"""The desktop target provisions its webview host inline at build time, so the
universal readiness hook is a no-op here: `requires_setup` is off and
`ensure_ready` never reaches `setup()` (itself an explicit no-op)."""
test "desktop ensure_ready is a no-op" {
    import tempfile;
    import unittest.mock;
    import from pathlib { Path }
    import from jaclang.client.targets.registry { get_target_registry }

    target = get_target_registry().get("desktop");
    assert target is not None;
    assert target.requires_setup == False;
    calls: list[str] = [];

    def _fake_setup(project_dir: Path) {
        calls.append("setup");
    }

    with tempfile.TemporaryDirectory() as d {
        with unittest.mock.patch.object(target, "setup", _fake_setup) {
            target.ensure_ready(Path(d));
        }
        assert calls == [] , "desktop needs no setup step; ensure_ready must not call it";
        # And the real setup() is itself an explicit no-op: nothing is written.
        target.setup(Path(d));
        assert list(Path(d).iterdir()) == [] , "desktop setup writes nothing";
    }
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
            '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main"\n'
            'kind = "desktop"\n'
        );
        assert target.engine(proj) == "native" , "engine defaults to the native webview";
        reset_desktop_config();
        (proj / "jac.toml").write_text(
            '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main"\n'
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
                '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main"\n'
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
                '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main"\n'
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
            f.write('[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main"\n');
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
            f.write('[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main"\n');
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
                '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main"\n'
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
    import sys;
    import tempfile;
    import shutil;
    import from pathlib { Path }
    import from jaclang.client.targets.desktop._dev_launch {
        desktop_app_runtime_env,
        jac_desktop_deps_shell_export,
        jac_desktop_webkit_shell_export
    }

    # Pin the launch-script contract on the shared shell fragments: the
    # WebKitGTK knobs belong to the Linux host alone.
    webkit = jac_desktop_webkit_shell_export();
    if sys.platform.startswith("linux") {
        assert "GDK_BACKEND" in webkit , "launch script must export GDK_BACKEND";
        assert "WEBKIT_DISABLE_DMABUF_RENDERER" in webkit;
    } else {
        assert webkit == "" , "only the WebKitGTK host takes GDK/WebKit exports";
    }
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
        # realpath on both sides: macOS mounts its temp dir behind /private.
        assert os.path.realpath(env.get("JAC_DESKTOP_DEPS", ""))
            == os.path.realpath(str(site)) , (
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
pass. So any app on this runtime can `jac build --native` / run `na` exactly like the
CLI. This test runs in that runtime (the test interpreter), so locating the shim
+ the na pass here verifies na is first-class on desktop by construction."""
test "na/LLVM backend is first-class in the desktop fused runtime" {
    import os;
    import importlib.util;
    import from jaclang.compiler.backends.native.llvm.shim_path { shim_name, shim_path }

    shim = shim_path();
    assert os.path.isfile(shim) , f"LLVMPY shim missing from the fused runtime: {shim}";
    assert shim.endswith(shim_name()) , "resolved shim must be the platform LLVMPY shim";
    # The native compiler pass is importable, so `jac build --native` is available to any
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


"""The build lays the app out per host and the running host recovers the same
layout from its own executable, so the two never disagree about where the
client bundle, the image and libwebview live."""
test "the app layout is flat on Linux and a bundle on macOS" {
    import from pathlib { Path }
    import from jaclang.client.targets.desktop.app_layout { AppLayout }
    out = Path("/out");
    flat = AppLayout.for_host(out, "Notes", "linux-x64");
    assert flat.bundle is None;
    assert flat.executable == out / "Notes";
    assert flat.resources == out and flat.library_dir() == out;
    assert flat.launch_target() == "./Notes";
    assert flat.launcher() == out / "Notes-launch.sh";
    mac = AppLayout.for_host(out, "Notes", "mac-aarch64");
    assert mac.bundle == out / "Notes.app";
    assert mac.executable == out / "Notes.app" / "Contents" / "MacOS" / "Notes";
    assert mac.resources == out / "Notes.app" / "Contents" / "Resources";
    assert mac.library_dir() == mac.executable.parent;
    assert mac.launch_target() == "./Notes.app/Contents/MacOS/Notes";
    for built in [flat, mac] {
        again = AppLayout.from_executable(built.executable);
        assert again.directory == built.directory;
        assert again.resources == built.resources;
        assert again.bundle == built.bundle;
    }
}


test "the macOS bundle metadata names the app for Finder and the Dock" {
    import plistlib;
    import tempfile;
    import from pathlib { Path }
    import from jaclang.client.desktop_config { DesktopIdentity }
    import from jaclang.client.targets.desktop.app_layout { AppLayout }
    import from jaclang.client.targets.desktop.macos_bundle {
        bundle_info,
        write_bundle_metadata
    }
    import from jaclang.toolchains.desktop { MACOS_DESKTOP_MIN_VERSION }
    identity = DesktopIdentity(
        name="Notes", identifier="org.example.notes", version="2.1.0"
    );
    with tempfile.TemporaryDirectory() as tmp {
        layout = AppLayout.for_host(Path(tmp), "Notes", "mac-aarch64");
        layout.library_dir().mkdir(parents=True);
        icon = Path(tmp) / "icon.icns";
        icon.write_bytes(b"icns");
        info = write_bundle_metadata(layout, identity, "Notes Desktop", icon);
        with open(info, "rb") as f {
            plist = plistlib.load(f);
        }
        assert plist["CFBundleExecutable"] == "Notes";
        assert plist["CFBundleIdentifier"] == "org.example.notes";
        assert plist["CFBundleShortVersionString"] == "2.1.0";
        assert plist["CFBundleDisplayName"] == "Notes Desktop";
        assert plist["LSMinimumSystemVersion"] == MACOS_DESKTOP_MIN_VERSION;
        assert plist["CFBundleIconFile"] == "AppIcon";
        assert (layout.resources / "AppIcon.icns").read_bytes() == b"icns";
        assert (Path(tmp) / "Notes.app" / "Contents" / "PkgInfo").read_text()
            == "APPL????";
    }
    plain = bundle_info(identity, "Notes", "", False);
    assert "CFBundleIconFile" not in plain;
    assert plain["CFBundleDisplayName"] == "Notes";
}


test "desktop app state lives under a per-user, per-app data dir" {
    import os;
    import from unittest.mock { patch }
    import from jaclang.client.targets.desktop.native.host_boot { default_data_dir }

    mac = default_data_dir("Darwin", "org.example.notes", "Notes");
    assert mac.endswith("/Library/Application Support/org.example.notes");
    unnamed = default_data_dir("Darwin", "", "Notes");
    assert unnamed.endswith("/Library/Application Support/Notes");

    with patch.dict(os.environ, {"XDG_DATA_HOME": "/xdg"}) {
        assert default_data_dir("Linux", "org.example.notes", "Notes")
            == "/xdg/org.example.notes";
        assert default_data_dir("Linux", "", "Notes") == "/xdg/Notes";
        assert default_data_dir("Linux", "org.example.other", "Notes")
            != default_data_dir("Linux", "org.example.notes", "Notes");
    }
    with patch.dict(os.environ, {"LOCALAPPDATA": "/win/Local"}) {
        assert default_data_dir("Windows", "org.example.notes", "Notes")
            == os.path.join("/win/Local", "org.example.notes");
    }
}


test "the embedded store env scopes the cluster and points at the bundle" {
    import os;
    import from jaclang.client.targets.desktop.native.host_boot { embedded_store_env }
    env = embedded_store_env(
        "/apps/Notes.app/Contents/Resources", "/xdg/org.example.notes", "pgdist"
    );
    assert env["JAC_PG_HOME"] == "/xdg/org.example.notes";
    assert env["JAC_PG_DIST"]
        == os.path.join("/apps/Notes.app/Contents/Resources", "pgdist");
    remote = embedded_store_env("/apps/x", "/xdg/org.example.notes", "");
    assert "JAC_PG_DIST" not in remote;
}


test "the embedded stop path is the shared Postgres cluster dir" {
    import os;
    import from unittest.mock { patch }
    import from jaclang.client.targets.desktop.native.host_boot {
        _embedded_cluster_dir
    }
    import from jaclang.server.session { shared_pg_data_dir }
    with patch.dict(os.environ, {"JAC_PG_HOME": "/xdg/org.example.notes"}) {
        assert _embedded_cluster_dir("/xdg/org.example.notes") == shared_pg_data_dir();
    }
}


test "a remote-backend app vendors no postgres distribution" {
    import from pathlib { Path }
    import from jaclang.client.targets.desktop.desktop_build { stage_postgres }
    assert stage_postgres(Path("/tmp/nowhere"), "https://api.example.com") == "";
}


test "a dev build points the host at the shared cached distribution" {
    import from pathlib { Path }
    import from unittest.mock { patch }
    import from jaclang.client.targets.desktop.desktop_build { stage_postgres }
    cached = "/home/jac/.cache/jac/pg/dist/linux-amd64-19";
    with patch("jaclang.data.pg_dist.cached_dist_dir", return_value=cached) {
        assert stage_postgres(Path("/tmp/nowhere"), "embedded", vendor=False) == cached;
    }
    with patch("jaclang.data.pg_dist.cached_dist_dir", return_value="") {
        assert stage_postgres(Path("/tmp/nowhere"), "embedded", vendor=False) == "";
    }
}


test "the embedded store stops only when the last instance leaves" {
    import from tempfile { TemporaryDirectory }
    import from unittest.mock { patch }
    import from jaclang.client.targets.desktop.native.host_boot {
        _EMBEDDED_LOCKS,
        _EMBEDDED_STOPPED,
        _embedded_cluster_dir,
        _join_embedded_store,
        _stop_embedded_store
    }
    with TemporaryDirectory() as tmp {
        calls: list[str] = [];
        def _record(home: str) {
            calls.append(home);
        }
        with patch("jaclang.data.pgembed.stop_cluster", side_effect=_record) {
            _EMBEDDED_STOPPED.discard(tmp);
            _join_embedded_store(tmp);
            # Leaving once stops the cluster; a second leave (the shutdown hook
            # and the atexit backstop) is a no-op, not a second stop.
            _stop_embedded_store(tmp);
            _stop_embedded_store(tmp);
            assert calls == [_embedded_cluster_dir(tmp)] , calls;
            assert tmp not in _EMBEDDED_LOCKS;
        }
    }
}


test "a peer instance keeps the cluster alive on leave" {
    import fcntl;
    import os;
    import from tempfile { TemporaryDirectory }
    import from jaclang.client.targets.desktop.native.host_boot {
        _embedded_user_lock_path,
        _holds_last_embedded_user
    }
    with TemporaryDirectory() as tmp {
        path = _embedded_user_lock_path(tmp);
        os.makedirs(os.path.dirname(path), exist_ok=True);
        mine = open(path, "a");
        peer = open(path, "a");
        fcntl.flock(mine.fileno(), fcntl.LOCK_SH);
        fcntl.flock(peer.fileno(), fcntl.LOCK_SH);
        # Two instances hold the lock, so neither is the last user and neither
        # may stop the shared cluster.
        assert not _holds_last_embedded_user(mine);
        peer.close();
        # The peer is gone; the survivor is now the last user.
        assert _holds_last_embedded_user(mine);
        mine.close();
    }
}


test "an upgrade migrates state stored beside the app image" {
    import from pathlib { Path }
    import from tempfile { TemporaryDirectory }
    import from jaclang.client.targets.desktop.native.host_boot {
        _migrate_legacy_data_dir
    }
    with TemporaryDirectory() as tmp {
        app_dir = Path(tmp) / "app";
        legacy = app_dir / ".jac" / "desktop";
        legacy.mkdir(parents=True);
        (legacy / "session.json").write_text("{}");
        data_dir = str(Path(tmp) / "xdg" / "org.example.notes");
        _migrate_legacy_data_dir(data_dir, str(app_dir));
        migrated = Path(data_dir) / ".jac" / "desktop" / "session.json";
        assert migrated.is_file() , "legacy state must carry forward";
        # A populated new dir is never clobbered by a second migration.
        migrated.write_text('{"kept": true}');
        _migrate_legacy_data_dir(data_dir, str(app_dir));
        assert migrated.read_text() == '{"kept": true}';
        # Same old and new dir (macOS, Windows): nothing to do.
        _migrate_legacy_data_dir(str(app_dir), str(app_dir));
        assert migrated.is_file();
    }
}


test "booting an embedded host restores the process env" {
    import os;
    import from jaclang.client.targets.desktop.native.host_boot {
        _enter_embedded_env,
        _leave_embedded_env
    }
    os.environ.pop("JAC_PG_HOME", None);
    os.environ.pop("JAC_PG_DIST", None);
    try {
        _enter_embedded_env(
            {"JAC_PG_HOME": "/tmp/app-data", "JAC_PG_DIST": "/tmp/app-pg"}
        );
        assert os.environ["JAC_PG_HOME"] == "/tmp/app-data";
        _leave_embedded_env();
        assert "JAC_PG_HOME" not in os.environ;
        assert "JAC_PG_DIST" not in os.environ;
        os.environ["JAC_PG_HOME"] = "/tmp/prior";
        _enter_embedded_env({"JAC_PG_HOME": "/tmp/next"});
        assert os.environ["JAC_PG_HOME"] == "/tmp/next";
        _leave_embedded_env();
        assert os.environ["JAC_PG_HOME"] == "/tmp/prior";
    } finally {
        os.environ.pop("JAC_PG_HOME", None);
        os.environ.pop("JAC_PG_DIST", None);
    }
}

test "a failed migration leaves nothing behind and stops the boot" {
    import from pathlib { Path }
    import from tempfile { TemporaryDirectory }
    import from unittest.mock { patch }
    import from jaclang.client.targets.desktop.native.host_boot {
        _migrate_legacy_data_dir
    }
    with TemporaryDirectory() as tmp {
        app_dir = Path(tmp) / "app";
        legacy = app_dir / ".jac" / "desktop";
        legacy.mkdir(parents=True);
        (legacy / "session.json").write_text("{}");
        data_dir = str(Path(tmp) / "xdg" / "org.example.notes");
        current = Path(data_dir) / ".jac" / "desktop";
        def out_of_space(src: str, dst: str, **kwargs: any) {
            raise OSError("no space left on device");
        }
        failed: (RuntimeError | None) = None;
        with patch("shutil.copytree", out_of_space) {
            try {
                _migrate_legacy_data_dir(data_dir, str(app_dir));
            } except RuntimeError as e {
                failed = e;
            }
        }
        assert failed is not None , "a failed migration must stop the boot";
        assert not current.exists() , "no partial state may be published";
        leftovers = list((Path(data_dir) / ".jac").glob("desktop.migrating*"));
        assert not leftovers , f"staging must be cleaned, found {leftovers}";
        assert (legacy / "session.json").is_file() , "legacy stays readable";
        _migrate_legacy_data_dir(data_dir, str(app_dir));
        assert (current / "session.json").is_file() , "the next boot retries";
    }
}

test "a workspace app scopes its storage identity to the served app" {
    import from pathlib { Path }
    import from unittest.mock { patch }
    import from jaclang.client.targets.desktop.desktop_build {
        desktop_storage_identifier
    }
    entry_file = Path("/ws/app/main.jac");
    with patch("jaclang.project.config.get_config_for_dir", return_value=None), patch(
        "jaclang.client.targets.desktop.desktop_build.storage_app_for",
        return_value="notes"
    ) {
        assert desktop_storage_identifier(
            "org.example.notes", Path("/ws"), entry_file, "embedded"
        )
            == "org.example.notes.notes";
    }
    with patch("jaclang.project.config.get_config_for_dir", return_value=None), patch(
        "jaclang.client.targets.desktop.desktop_build.storage_app_for", return_value=""
    ) {
        assert desktop_storage_identifier(
            "org.example.notes", Path("/ws"), entry_file, "embedded"
        )
            == "org.example.notes";
    }
}

test "leaving while a peer holds the cluster still restores the env" {
    import fcntl;
    import os;
    import from tempfile { TemporaryDirectory }
    import from unittest.mock { patch }
    import from jaclang.client.targets.desktop.native.host_boot {
        _EMBEDDED_LOCKS,
        _EMBEDDED_STOPPED,
        _embedded_user_lock_path,
        _enter_embedded_env,
        _join_embedded_store,
        _stop_embedded_store
    }
    os.environ.pop("JAC_PG_HOME", None);
    with TemporaryDirectory() as tmp {
        path = _embedded_user_lock_path(tmp);
        os.makedirs(os.path.dirname(path), exist_ok=True);
        peer = open(path, "a");
        fcntl.flock(peer.fileno(), fcntl.LOCK_SH);
        calls: list[str] = [];
        def _record(home: str) {
            calls.append(home);
        }
        try {
            with patch("jaclang.data.pgembed.stop_cluster", side_effect=_record) {
                _EMBEDDED_STOPPED.discard(tmp);
                _enter_embedded_env({"JAC_PG_HOME": tmp});
                _join_embedded_store(tmp);
                _stop_embedded_store(tmp);
                # The peer keeps the cluster alive...
                assert calls == [] , calls;
                # ...but this host hands the process environment back, so
                # later work here cannot reach the peer's storage.
                assert "JAC_PG_HOME" not in os.environ;
            }
        } finally {
            peer.close();
            os.environ.pop("JAC_PG_HOME", None);
            _EMBEDDED_LOCKS.pop(tmp, None);
            _EMBEDDED_STOPPED.discard(tmp);
        }
    }
}

test "a rebooted embedded host cleans up on its second leave" {
    import from tempfile { TemporaryDirectory }
    import from unittest.mock { patch }
    import from jaclang.client.targets.desktop.native.host_boot {
        _EMBEDDED_LOCKS,
        _EMBEDDED_STOPPED,
        _embedded_cluster_dir,
        _join_embedded_store,
        _stop_embedded_store
    }
    with TemporaryDirectory() as tmp {
        calls: list[str] = [];
        def _record(home: str) {
            calls.append(home);
        }
        with patch("jaclang.data.pgembed.stop_cluster", side_effect=_record) {
            _EMBEDDED_STOPPED.discard(tmp);
            # First lifetime: join, leave. Second lifetime: join, leave --
            # the stop recorded by the first must not swallow the second.
            _join_embedded_store(tmp);
            _stop_embedded_store(tmp);
            _join_embedded_store(tmp);
            _stop_embedded_store(tmp);
            cluster = _embedded_cluster_dir(tmp);
            assert calls == [cluster, cluster] , calls;
            assert tmp not in _EMBEDDED_LOCKS;
        }
    }
}

test "the last embedded user holds the exclusive lock through cluster stop" {
    import fcntl;
    import os;
    import from tempfile { TemporaryDirectory }
    import from unittest.mock { patch }
    import from jaclang.client.targets.desktop.native.host_boot {
        _EMBEDDED_LOCKS,
        _EMBEDDED_STOPPED,
        _embedded_user_lock_path,
        _join_embedded_store,
        _stop_embedded_store
    }
    with TemporaryDirectory() as tmp {
        path = _embedded_user_lock_path(tmp);
        attempts: list[bool] = [];
        def _probe_during_stop(home: str) {
            probe = open(path, "a");
            acquired = False;
            try {
                fcntl.flock(probe.fileno(), fcntl.LOCK_SH | fcntl.LOCK_NB);
                acquired = True;
            } except BlockingIOError {
                acquired = False;
            } finally {
                probe.close();
            }
            attempts.append(acquired);
        }
        with patch(
            "jaclang.data.pgembed.stop_cluster", side_effect=_probe_during_stop
        ) {
            _EMBEDDED_STOPPED.discard(tmp);
            _join_embedded_store(tmp);
            _stop_embedded_store(tmp);
            assert attempts == [False] , "new instances must wait until the old cluster stops";
            assert tmp not in _EMBEDDED_LOCKS;
            _EMBEDDED_STOPPED.discard(tmp);
        }
    }
}

test "a failed embedded boot releases its store lock" {
    import json;
    import os;
    import from tempfile { TemporaryDirectory }
    import from unittest.mock { patch }
    import jaclang.client.targets.desktop.native.host_boot as host_boot;
    with TemporaryDirectory() as data_dir {
        prior_home = os.environ.get("JAC_PG_HOME");
        prior_dist = os.environ.get("JAC_PG_DIST");
        prior_data = os.environ.get("JAC_DATA_PATH");
        os.environ["JAC_DATA_PATH"] = data_dir;
        os.environ["JAC_PG_HOME"] = "/prior/pg-home";
        os.environ["JAC_PG_DIST"] = "/prior/pg-dist";
        host_boot._EMBEDDED_STOPPED.discard(data_dir);
        failed = False;
        try {
            with patch.object(
                host_boot, "_apply_extra_deps", side_effect=RuntimeError("boot failed")
            ) {
                with patch("jaclang.data.pgembed.stop_cluster"), patch(
                    "atexit.register"
                ) {
                    try {
                        host_boot.boot(json.dumps({"backend": "embedded"}));
                    } except RuntimeError as e {
                        failed = True;
                        assert "boot failed" in str(e);
                    }
                }
            }
            assert failed , "the injected boot failure must propagate";
            assert data_dir not in host_boot._EMBEDDED_LOCKS , "failed boot must release its lock";
            assert os.environ["JAC_PG_HOME"] == "/prior/pg-home";
            assert os.environ["JAC_PG_DIST"] == "/prior/pg-dist";
        } finally {
            handle = host_boot._EMBEDDED_LOCKS.pop(data_dir, None);
            if handle is not None {
                handle.close();
            }
            host_boot._EMBEDDED_STOPPED.discard(data_dir);
            if prior_data is None {
                os.environ.pop("JAC_DATA_PATH", None);
            } else {
                os.environ["JAC_DATA_PATH"] = prior_data;
            }
            if prior_home is None {
                os.environ.pop("JAC_PG_HOME", None);
            } else {
                os.environ["JAC_PG_HOME"] = prior_home;
            }
            if prior_dist is None {
                os.environ.pop("JAC_PG_DIST", None);
            } else {
                os.environ["JAC_PG_DIST"] = prior_dist;
            }
        }
    }
}
