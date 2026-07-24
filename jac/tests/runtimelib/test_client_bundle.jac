"""Tests for the core client bundle builder base.

The base `ClientBundleBuilder` provides the shared compile-to-JS + manifest
extraction + caching used by the built-in client framework's Vite/Bun builder.
Concrete bundling (`_compile_bundle`) is provided by the built-in client
framework that ships with jaclang core; invoked standalone the base raises,
since there is a single client pathway (Vite/Bun) and no bare-serve inline
bundler anymore.
"""

import from pathlib { Path }
import from jaclang { JacRuntime as Jac }
import from jaclang.runtimelib.client_bundle { ClientBundleBuilder, ClientBundleError }

glob FIXTURES = str(Path(__file__).parent / "fixtures");

test "base builder compiles a client module to JS and extracts its manifest surface" {
    (module, ) = Jac.jac_import("client_app", FIXTURES);
    builder = ClientBundleBuilder();
    source_path = Path(module.__file__.replace(".py", ".jac")).resolve();
    (js, mod) = builder._compile_to_js(source_path);
    assert js;  # ES output was generated
    manifest = mod.gen.client_manifest if mod else None;
    exports = builder._extract_client_exports(manifest);
    assert isinstance(exports, list);
    globals_map = builder._extract_client_globals(manifest, module);
    assert isinstance(globals_map, dict);
}

test "base builder bundling requires the built-in client framework" {
    (module, ) = Jac.jac_import("client_app", FIXTURES);
    builder = ClientBundleBuilder();
    source_path = Path(module.__file__.replace(".py", ".jac")).resolve();
    raised = False;
    try {
        builder._compile_bundle(module, source_path);
    } except ClientBundleError as err {
        raised = True;
        assert "built-in client framework" in str(err);
    }
    assert raised , "base _compile_bundle should raise ClientBundleError without the plugin";
}

test "dev vite config registers the port reporter; build config does not" {
    import tempfile;
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
    with tempfile.TemporaryDirectory() as tmp {
        bundler = ViteBundler(Path(tmp));
        entry = Path(tmp) / "main.js";
        dev_config = bundler.create_vite_config(entry, is_dev=True);
        dev_content = dev_config.read_text();
        # The plugin writes the bound port to .dev-port on "listening" —
        # the jac CLI reads it instead of parsing Vite's stdout.
        assert "jac-port-reporter" in dev_content;
        assert ".dev-port" in dev_content;
        # Build errors surface through Vite's native overlay in dev mode
        assert "jac-build-error-overlay" in dev_content;
        assert ".jac-build-error.json" in dev_content;
        # Force-reload plugin: rescues export-set edits that Fast Refresh would
        # otherwise swallow, reloading (jacTriggered) when the jac dev server
        # bumps .jac-force-reload
        assert "jacForceReload()," in dev_content;
        assert ".jac-force-reload" in dev_content;
        assert 'type: "full-reload", path: "*", jacTriggered: true' in dev_content;
        build_content = bundler.create_vite_config(entry, is_dev=False).read_text();
        assert "jac-port-reporter" not in build_content;
        assert "jac-build-error-overlay" not in build_content;
        assert "jacForceReload" not in build_content;
    }
}

test "dev vite config registers error reporter; overlay is gated to module-load errors only" {
    import tempfile;
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
    with tempfile.TemporaryDirectory() as tmp {
        bundler = ViteBundler(Path(tmp));
        entry = Path(tmp) / "main.js";
        dev_cfg = bundler.create_vite_config(entry, is_dev=True);
        dev_content = dev_cfg.read_text();
        assert "jac-error-reporter" in dev_content;
        # Overlay must only fire for module-load failures, not every runtime error
        assert 'phase === "load"' in dev_content;
        build_cfg = bundler.create_vite_config(entry, is_dev=False);
        build_content = build_cfg.read_text();
        assert "jac-error-reporter" not in build_content;
    }
}

test "dev index.html loads entry via dynamic import and tags load errors with phase flag" {
    import tempfile;
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
    with tempfile.TemporaryDirectory() as tmp {
        bundler = ViteBundler(Path(tmp));
        bundler._ensure_dev_index_html(Path(tmp));
        content = (Path(tmp) / "index.html").read_text();
        # Entry must load via dynamic import so the error handler is installed first
        assert 'import("/compiled/_entry.js")' in content;
        assert '<script type="module" src="/compiled/_entry.js">' not in content;
        assert 'import.meta.hot' in content;
        assert 'window.addEventListener("error"' in content;
        assert 'window.addEventListener("unhandledrejection"' in content;
        # Load errors must carry the phase flag so the overlay is not triggered
        # for unrelated runtime errors that fire after the app has loaded
        assert 'phase: "load"' in content;
        assert '.catch(function() {})' in content;
    }
}

test "dev config wires fast refresh and index.html installs the hook before the entry" {
    import tempfile;
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
    with tempfile.TemporaryDirectory() as tmp {
        bundler = ViteBundler(Path(tmp));
        entry = Path(tmp) / "main.js";
        dev_cfg = bundler.create_vite_config(entry, is_dev=True);
        dev_content = dev_cfg.read_text();
        assert 'import jacFastRefresh from "./jac-fast-refresh.js"' in dev_content;
        assert "jacFastRefresh()," in dev_content;
        plugin_js = (dev_cfg.parent / "jac-fast-refresh.js").read_text();
        # Boundary mirrors @vitejs/plugin-react: register exports, self-accept,
        # invalidate (full reload) when the new exports are not swap-safe
        assert "registerExportsForReactRefresh" in plugin_js;
        assert "import.meta.hot.accept" in plugin_js;
        assert "validateRefreshBoundaryAndEnqueueUpdate" in plugin_js;
        assert "import.meta.hot.invalidate" in plugin_js;
        # Only modules the compiler stamped as component-only are instrumented;
        # unstamped modules (globs, helpers, router wiring) keep full reload
        assert '/*jac:refresh-boundary*/' in plugin_js;
        bundler._ensure_dev_index_html(Path(tmp));
        html = (Path(tmp) / "index.html").read_text();
        assert "injectIntoGlobalHook" in html;
        # The refresh hook must install before React loads with the app entry
        assert html.index('"/@react-refresh"') < html.index(
            'import("/compiled/_entry.js")'
        );
        build_content = bundler.create_vite_config(entry, is_dev=False).read_text();
        assert "jacFastRefresh" not in build_content;
    }
}

test "dev config wires the layered dev-status bridge; build config does not" {
    import tempfile;
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
    with tempfile.TemporaryDirectory() as tmp {
        bundler = ViteBundler(Path(tmp));
        entry = Path(tmp) / "main.js";
        dev_cfg = bundler.create_vite_config(entry, is_dev=True);
        dev_content = dev_cfg.read_text();
        assert 'import jacDevStatus, { reportClientLoad } from "./jac-dev-status.js"' in dev_content;
        assert "jacDevStatus()," in dev_content;
        # Browser load-phase failures feed the client slot via the reporter
        assert "reportClientLoad(data)" in dev_content;
        plugin_js = (dev_cfg.parent / "jac-dev-status.js").read_text();
        # Vite slot: set from Vite's own error payloads, cleared on recovery
        # payloads; jac-layer payloads are excluded (tracked in-process)
        assert '".jac-dev-status.json"' in plugin_js;
        assert '.startsWith("jac")' in plugin_js;
        assert '"full-reload"' in plugin_js;
        # Jac-recovery reloads must not clear a still-broken Vite layer, and
        # clearing needs a connected client to re-arm a persisting error
        assert "!payload.jacTriggered" in plugin_js;
        assert "server.ws.clients.size > 0" in plugin_js;
        assert "jacTriggered: true" in dev_content;
        # Client slot clears only on the browser's clean-load beacon
        assert '"jac:client-ready"' in plugin_js;
        bundler._ensure_dev_index_html(Path(tmp));
        html = (Path(tmp) / "index.html").read_text();
        assert 'import.meta.hot.send("jac:client-ready")' in html;
        build_content = bundler.create_vite_config(entry, is_dev=False).read_text();
        assert "jacDevStatus" not in build_content;
    }
}

"""Lay out a build dir the way `bun install` does: the real package plus the
`node_modules/.bin/vite` shim, which carries Vite's `#!/usr/bin/env node`
shebang."""
def _stub_vite_install(build_dir: Path) {
    bin_dir = build_dir / "node_modules" / "vite" / "bin";
    bin_dir.mkdir(parents=True);
    entry = bin_dir / "vite.js";
    entry.write_text("#!/usr/bin/env node\nconsole.log('vite-stub ok');\n");
    entry.chmod(0o755);
    (bin_dir.parent / "package.json").write_text(
        '{"name": "vite", "version": "0.0.0", "bin": {"vite": "bin/vite.js"}}'
    );
    shim_dir = build_dir / "node_modules" / ".bin";
    shim_dir.mkdir(parents=True);
    (shim_dir / "vite").symlink_to("../vite/bin/vite.js");
}

test "vite builds run under bun with no node on PATH" {
    import os;
    import subprocess;
    import sys;
    import tempfile;
    import pytest;
    import from jaclang.runtimelib.client { get_bun }
    import from jaclang.runtimelib.client.vite_bundler { _build_vite_command }

    if sys.platform == "win32" {
        pytest.skip("shebang dispatch is POSIX-only");
    }
    if get_bun() is None {
        pytest.skip("bun is required but could not be located/installed");
    }
    with tempfile.TemporaryDirectory() as tmp {
        build_dir = Path(tmp) / "client";
        build_dir.mkdir();
        _stub_vite_install(build_dir);
        # Jac provisions bun and never provisions node, so a client build has to
        # work on a machine that has no node at all.
        empty_dir = Path(tmp) / "empty-path";
        empty_dir.mkdir();
        env = dict(os.environ);
        env["PATH"] = str(empty_dir);
        result = subprocess.run(
            _build_vite_command(build_dir, ["build"]),
            cwd=build_dir,
            env=env,
            capture_output=True,
            text=True
        );
        assert result.returncode == 0 , (
            f"vite build needs node on PATH: {result.stderr or result.stdout}"
        );
        assert "vite-stub ok" in result.stdout;
    }
}

test "vite commands address vite's js entry, not the bunx shim" {
    import tempfile;
    import pytest;
    import from jaclang.runtimelib.client { get_bun }
    import from jaclang.runtimelib.client.vite_bundler {
        _build_vite_command,
        _build_vite_dev_command
    }

    if get_bun() is None {
        pytest.skip("bun is required but could not be located/installed");
    }
    with tempfile.TemporaryDirectory() as tmp {
        build_dir = Path(tmp) / "client";
        build_dir.mkdir();
        _stub_vite_install(build_dir);
        build_cmd = _build_vite_command(build_dir, ["build", "--config", "c.js"]);
        # `bun x vite` hands off to the .bin shim and its node shebang; naming
        # the entry keeps the run inside bun.
        assert "x" not in build_cmd;
        assert build_cmd[1].endswith("vite.js");
        assert build_cmd[2:] == ["build", "--config", "c.js"];
        dev_cmd = _build_vite_dev_command(
            build_dir, Path("configs/vite.dev.config.js"), 3000
        );
        assert "x" not in dev_cmd;
        assert dev_cmd[1].endswith("vite.js");
        assert "--port" in dev_cmd;
    }
}
