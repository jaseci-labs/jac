"""Tests for the core client bundle builder base.

The base `ClientBundleBuilder` provides the shared compile-to-JS + manifest
extraction + caching used by the jac-client Vite/Bun builder. Concrete bundling
(`_compile_bundle`) lives in the jac-client plugin; invoked standalone the base
raises, since there is a single client pathway (Vite/Bun) and no bare-serve
inline bundler anymore.
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

test "base builder bundling requires the jac-client plugin" {
    (module, ) = Jac.jac_import("client_app", FIXTURES);
    builder = ClientBundleBuilder();
    source_path = Path(module.__file__.replace(".py", ".jac")).resolve();
    raised = False;
    try {
        builder._compile_bundle(module, source_path);
    } except ClientBundleError as err {
        raised = True;
        assert "jac-client" in str(err);
    }
    assert raised , "base _compile_bundle should raise ClientBundleError without the plugin";
}
