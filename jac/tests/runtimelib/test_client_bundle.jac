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
        build_content = bundler.create_vite_config(entry, is_dev=False).read_text();
        assert "jac-port-reporter" not in build_content;
        assert "jac-build-error-overlay" not in build_content;
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
