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

"""Window geometry is read from [desktop.window]."""
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

"""In-process dispatch tuning is read from [desktop.dispatch], with
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

"""The opt-in [desktop.http] sidecar config is read from jac.toml: defaults are
disabled/no-capabilities/random-port; explicit values load and validate; an
unknown capability or out-of-range port is rejected (Phase 4, doc §7)."""
test "desktop http sidecar config loads and validates from jac.toml" {
    import from jaclang.runtimelib.client.desktop_config {
        get_desktop_config,
        reset_desktop_config
    }
    import from pathlib { Path }
    import tempfile;

    with tempfile.TemporaryDirectory() as d {
        reset_desktop_config();
        # No [desktop.http] -> opt-in defaults (disabled).
        with open(Path(d) / "jac.toml", "w") as f {
            f.write(
                '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
            );
        }
        cfg = get_desktop_config(project_dir=Path(d));
        h1 = cfg.get_http_config();
        assert h1.enabled == False , "http sidecar defaults off";
        assert h1.capabilities == [] , "no capabilities by default";
        assert h1.port == 0 , "port defaults to 0 (random loopback)";
        reset_desktop_config();
        # Explicit values load, and to_dict round-trips for the boot config.
        with open(Path(d) / "jac.toml", "w") as f {
            f.write(
                '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
                '[desktop.http]\nenabled = true\n'
                'capabilities = ["multipart", "openapi"]\nport = 8123\n'
            );
        }
        cfg2 = get_desktop_config(project_dir=Path(d));
        h2 = cfg2.get_http_config();
        assert h2.enabled == True , "http sidecar enabled should load";
        assert h2.capabilities == ["multipart", "openapi"];
        assert h2.port == 8123;
        cfg2.validate();
        as_dict = h2.to_dict();
        assert as_dict["enabled"] == True and as_dict["port"] == 8123;
        assert as_dict["capabilities"] == ["multipart", "openapi"];
        reset_desktop_config();
        # Unknown capability is rejected by validate().
        with open(Path(d) / "jac.toml", "w") as f {
            f.write(
                '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
                '[desktop.http]\nenabled = true\ncapabilities = ["telepathy"]\n'
            );
        }
        cfg3 = get_desktop_config(project_dir=Path(d));
        rejected = False;
        try {
            cfg3.validate();
        } except ValueError as e {
            rejected = True;
            assert "telepathy" in str(e) and "[desktop.http]" in str(e);
        }
        assert rejected , "unknown [desktop.http] capability must be rejected";
        reset_desktop_config();
        # Out-of-range port is rejected.
        with open(Path(d) / "jac.toml", "w") as f {
            f.write(
                '[project]\nname = "t"\nversion = "1.0.0"\nentry-point = "main.jac"\n'
                '[desktop.http]\nport = 999999\n'
            );
        }
        cfg4 = get_desktop_config(project_dir=Path(d));
        bad_port = False;
        try {
            cfg4.validate();
        } except ValueError {
            bad_port = True;
        }
        assert bad_port , "out-of-range [desktop.http] port must be rejected";
        reset_desktop_config();
    }
}


"""The generated host threads [desktop.http] into the boot config and injects the
renderer-facing window.__JAC_HTTP__ discovery hook (read from _ctx at runtime),
and still tears the sidecar down on close via _ctx.close_http()."""
test "generated host wires the http sidecar config and __JAC_HTTP__ injection" {
    import from jaclang.runtimelib.client.targets.desktop._host_bootstrap {
        _generate_host_source
    }

    src = _generate_host_source(
        "T",
        800,
        600,
        "test-app",
        "",
        30.0,
        128,
        False,
        {},
        {"enabled": True, "capabilities": ["multipart"], "port": 0}
    );
    # The opt-in http config rides the frozen boot config into host_boot.boot().
    assert "http" in src , "boot config must carry the http section";
    assert "multipart" in src , "configured capability must be baked into boot config";
    # Renderer discovery: read _ctx.http_bootstrap_js() and inject via on_load.
    assert "http_bootstrap_js()" in src , "host must read the sidecar bootstrap js from _ctx";
    assert "__JAC_HTTP__" not in src or "http_js" in src , "sidecar js is injected at runtime, not baked";
    assert "http_js" in src , "host must inject the sidecar discovery script";
    # Sidecar is torn down on close before dispatch shutdown.
    assert "close_http" in src , "host must stop the sidecar on close";
    assert src.index("close_http") < src.index("inprocess_dispatch.shutdown()") , "sidecar stops before dispatch teardown";
}


"""The host brings up the fused runtime through the fused runtime library
(engine_boot) instead of binding the build machine's libpython, and never bakes
build-machine state. All boot behavior lives in the host_boot runtime module; the generated
source only carries configuration plus the native bridge."""
test "host source boots the fused runtime and bakes no build-machine state" {
    import from jaclang.runtimelib.client.targets.desktop._host_bootstrap {
        _generate_host_source
    }

    src = _generate_host_source("T", 800, 600, "test-app");
    # Fused-runtime bring-up: the fused runtime library, not libpython-by-soname.
    assert "import from fused.bringup" in src , "host must import the fused runtime library";
    assert "engine_boot()" in src , "host must boot the fused runtime";
    assert "libpython" not in src , "host must not bind a libpython soname";
    # Thin boot contract: one BOOT_PY statement into the host_boot module.
    assert "BOOT_PY" in src , "host source must declare BOOT_PY";
    assert "host_boot.boot(" in src , "BOOT_PY must call host_boot.boot()";
    # Native push streaming needs the stream-capable __jac SDK in BOOTSTRAP_JS.
    assert "__stream_next__" in src , "native bootstrap must expose __stream_next__";
    assert "__jac_stream" in src , "native bootstrap must buffer __jac_stream emits";
    # No build-machine site-package baking (the old _builder_dep_site_dirs path).
    assert "getusersitepackages" not in src , "must not reference user-site packages";
    assert "getsitepackages" not in src , "must not bake interpreter site-packages";
    assert "_baked_dep_sites" not in src , "must not bake builder site dirs";
    assert "JAC_DESKTOP_SCALE_SRC" not in src , "separate scale-source seam is gone (scale is folded into jaclang)";
}

"""host_boot honors JAC_DESKTOP_DEPS as the extra-deps seam (project venv
site-packages exported by the launch script). Entries join sys.path once."""
test "host_boot applies the runtime extra-deps seam" {
    import os;
    import sys;
    import from jaclang.runtimelib.client.targets.desktop.native { host_boot }

    _saved_path = list(sys.path);
    _saved_env = os.environ.get("JAC_DESKTOP_DEPS");
    fake_a = os.path.join(os.sep, "nonexistent-jac-deps-a");
    fake_b = os.path.join(os.sep, "nonexistent-jac-deps-b");
    try {
        os.environ["JAC_DESKTOP_DEPS"] = fake_a + os.pathsep + fake_b;
        host_boot._apply_extra_deps(os.sep);
        assert fake_a in sys.path , "first JAC_DESKTOP_DEPS entry must join sys.path";
        assert fake_b in sys.path , "second JAC_DESKTOP_DEPS entry must join sys.path";
        # Idempotent: applying twice must not duplicate entries.
        host_boot._apply_extra_deps(os.sep);
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
    import from jaclang.runtimelib.client.targets.desktop._dev_launch {
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

"""host_boot.runtime_payload is the single routing decision between the
in-process Jac runtime and the plugin host. Pin the wire forms it must accept:
raw payload dicts, and the webview bind form (a one-element argument array
holding the payload as a JSON string). Plugin-style requests fall through."""
test "host_boot routes runtime payloads and passes plugin requests through" {
    import json;
    import from jaclang.runtimelib.client.targets.desktop.native { host_boot }

    walker_req = json.dumps({"kind": "walker", "name": "w", "fields": {}});
    func_req = json.dumps({"kind": "function", "name": "f", "fields": {}});
    # Raw dict payloads route to the runtime as-is.
    assert host_boot.runtime_payload(walker_req) == walker_req;
    assert host_boot.runtime_payload(func_req) == func_req;
    # Webview bind form: one-element args array holding the payload string.
    wrapped = json.dumps([walker_req]);
    assert host_boot.runtime_payload(wrapped) == walker_req;
    # Plugin wire forms fall through to the plugin host (None = not runtime).
    assert host_boot.runtime_payload(json.dumps(["jac.fs", "read_file", {}])) is None;
    assert host_boot.runtime_payload(json.dumps({"plugin": "jac.fs"})) is None;
    # Garbage falls through too (the plugin host owns the error envelope).
    assert host_boot.runtime_payload("not json") is None;
    assert host_boot.runtime_payload(json.dumps(["not json either"])) is None;
}

"""host_boot.stream_control is the native endpoint for the client-disconnect /
backpressure protocol: a `{__jac_stream_ctl}` frame routes to cancel/ack, while
ordinary calls and non-control payloads fall through (None). The cancel/ack
effect on a live stream is covered in test_inprocess_dispatch; here we pin the
routing decision and envelope shape."""
test "host_boot routes stream-control frames to cancel/ack" {
    import json;
    import from jaclang.runtimelib.client.targets.desktop.native { host_boot }

    # Ordinary runtime/plugin payloads are NOT stream control.
    assert host_boot.stream_control(json.dumps({"kind": "walker", "name": "w"}))
        is None;
    assert host_boot.stream_control(json.dumps(["jac.fs", "read_file", {}])) is None;
    assert host_boot.stream_control("not json") is None;

    # A cancel frame is parsed and acked (cancel_stream is a safe no-op for an
    # unknown id, so this exercises the routing without a live stream).
    out = host_boot.stream_control(
        json.dumps({"__jac_stream_ctl": "cancel", "stream_id": "s-1"})
    );
    assert out["ok"] == True
        and out["__jac_stream_ctl"] == "cancel"
        and out["stream_id"] == "s-1";

    # Webview bind form (one-element string array) is also accepted, ack form.
    out2 = host_boot.stream_control(
        json.dumps(
            [json.dumps({"__jac_stream_ctl": "ack", "stream_id": "s-2", "n": 3})]
        )
    );
    assert out2["ok"] == True and out2["__jac_stream_ctl"] == "ack" and out2["n"] == 3;

    # Missing stream_id and unknown control verbs are stable errors, not crashes.
    bad = host_boot.stream_control(json.dumps({"__jac_stream_ctl": "cancel"}));
    assert bad["ok"] == False;
    unknown = host_boot.stream_control(
        json.dumps({"__jac_stream_ctl": "bogus", "stream_id": "s-3"})
    );
    assert unknown["ok"] == False;
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
    import from jaclang.compiler.passes.native.llvm.binding.ffi {
        _find_shim,
        _shim_name
    }

    shim = _find_shim();
    assert os.path.isfile(shim) , f"LLVMPY shim missing from the fused runtime: {shim}";
    assert shim.endswith(_shim_name()) , "resolved shim must be the platform LLVMPY shim";
    # The native compiler pass is importable, so `nacompile` is available to any
    # app running on this fused runtime (the one the desktop host bundles).
    spec = importlib.util.find_spec("jaclang.compiler.passes.native.na_compile_pass");
    assert spec is not None , "na compiler pass must be importable in the desktop runtime";
}

"""The desktop host imports its bootstrap modules from the fused runtime -- no
transpiled .py staged beside the binary. Prove it by running host_boot's plugin
bootstrap + the broker/dispatch imports in THIS runtime (the same fused runtime a
desktop app boots): the closest dependency-free proxy for the embedded host,
catching an import-from-runtime regression without a display."""
test "host bootstrap modules import + run from the fused runtime" {
    import from jaclang.runtimelib.client.targets.desktop.native {
        host_boot,
        oauth_broker,
        inprocess_dispatch
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
        # oauth_broker + inprocess_dispatch resolve from the runtime too (no staging).
        assert hasattr(oauth_broker, "make_handler") , "oauth_broker must import from the runtime";
        assert hasattr(inprocess_dispatch, "boot")
            and hasattr(inprocess_dispatch, "dispatch") , "inprocess_dispatch must import from the runtime";
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
    import from jaclang.runtimelib.client.targets.desktop._dev_launch {
        _editable_roots_from_site
    }

    roots = _editable_roots_from_site();
    if (Path(os.environ.get("JAC_DESKTOP_JAC_SRC", "")) / "jaclang").exists() {
        assert "JAC_DESKTOP_JAC_SRC" in roots , "editable jaclang root should be detected";
    }
    # Scale is folded into jaclang (jaclang.scale), so the editable jaclang root
    # carries it; there is no separate JAC_DESKTOP_SCALE_SRC root to detect.
    assert "JAC_DESKTOP_SCALE_SRC" not in roots , "no separate scale root (scale is part of jaclang)";
}
