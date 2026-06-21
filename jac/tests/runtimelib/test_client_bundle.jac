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
        build_config = bundler.create_vite_config(entry, is_dev=False);
        assert "jac-port-reporter" not in build_config.read_text();
    }
}
