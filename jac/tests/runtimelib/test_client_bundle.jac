"""Tests for the core client bundle builder base.

The base `ClientBundleBuilder` provides the shared compile-to-JS + manifest
extraction + caching used by the built-in client framework's Vite/Bun builder.
"""

import tempfile;
import from pathlib { Path }
import from jaclang { JacRuntime as Jac }
import from jaclang.runtimelib.client_bundle { ClientBundleBuilder, ClientBundleError }
import from jaclang.runtimelib.client.vite_bundler { ViteBundler }

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

test "dev vite config registers dev-only plugins; production config omits them" {
    with tempfile.TemporaryDirectory() as tmp {
        bundler = ViteBundler(Path(tmp));
        entry = Path(tmp) / "main.js";
        dev_plugins = {
            "jac-port-reporter",
            "jac-build-error-overlay",
            "jacForceReload",
            "jac-error-reporter",
            "jacFastRefresh",
            "jacDevStatus"
        };
        dev_content = bundler.create_vite_config(entry, is_dev=True).read_text();
        for plugin in dev_plugins {
            assert plugin in dev_content , f"dev config must register {plugin}";
        }
        build_content = bundler.create_vite_config(entry, is_dev=False).read_text();
        for plugin in dev_plugins {
            assert plugin not in build_content , f"build config must omit {plugin}";
        }
    }
}

test "dev index loads entry dynamically and reports load-phase failures" {
    with tempfile.TemporaryDirectory() as tmp {
        bundler = ViteBundler(Path(tmp));
        bundler._ensure_dev_index_html(Path(tmp));
        html = (Path(tmp) / "index.html").read_text();
        # Entry must load via dynamic import so the error handler is installed first
        assert 'import("/compiled/_entry.js")' in html;
        assert '<script type="module" src="/compiled/_entry.js">' not in html;
        assert 'phase: "load"' in html;
        assert 'import.meta.hot.send("jac:client-ready")' in html;
    }
}

test "dev fast refresh plugin is generated alongside the vite config" {
    with tempfile.TemporaryDirectory() as tmp {
        bundler = ViteBundler(Path(tmp));
        entry = Path(tmp) / "main.js";
        dev_cfg = bundler.create_vite_config(entry, is_dev=True);
        plugin_js = dev_cfg.parent / "jac-fast-refresh.js";
        assert plugin_js.is_file() , "jac-fast-refresh.js must be emitted in dev mode";
        assert "import.meta.hot.accept" in plugin_js.read_text();
    }
}
