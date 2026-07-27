"""The compiled runtime core must be able to resolve the JSX factory it calls.

The core's error boundary and dev overlay are the only JSX in the runtime core,
so they lower to `__jacJsx(...)` calls. The factory itself is React-specific and
lives in the platform runtime, which imports core -- core cannot import it back.
If the compile path stops injecting the factory import, the emitted core still
looks fine and every app still renders, but the error boundary dies with
`__jacJsx is not defined` the moment anything throws.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }

"""Drive the real client compile path over a throwaway project and return the
compiled runtime-core JS it writes to disk."""
def _compile_runtime_core_js(proj: Path) -> str {
    import from jaclang.runtimelib.client.vite_client_bundle { ViteClientBundleBuilder }

    (proj / "package.json").write_text('{"name":"t","version":"0.0.0"}');
    out_dir = proj / "out";

    builder = ViteClientBundleBuilder(vite_package_json=proj / "package.json");
    compiler = builder._get_compiler();
    compiler.runtime_path = proj / "package.json";
    compiler.compiled_dir = out_dir;
    compiler.jac_client_compiler.compiled_dir = out_dir;
    compiler.compile_runtime_utils();

    core_js = out_dir / "client_runtime_core.js";
    assert core_js.exists() , "compile path should emit client_runtime_core.js";
    return core_js.read_text();
}

test "compiled runtime core can resolve the jsx factory it calls" {
    with TemporaryDirectory() as tmp {
        js = _compile_runtime_core_js(Path(tmp));
        assert "__jacJsx(" in js , "runtime core should emit JSX factory calls";
        defines = "function __jacJsx(" in js;
        imports = "__jacJsx" in js.split("\n")[0] and "import" in js.split("\n")[0];
        assert defines or imports , "runtime core calls __jacJsx but neither defines nor imports it -- "
        "the error boundary will crash with '__jacJsx is not defined'";
    }
}

test "compiled runtime core does not re-import globals it defines" {
    with TemporaryDirectory() as tmp {
        js = _compile_runtime_core_js(Path(tmp));
        # Core defines __jacSpawn itself; importing it back would rebind the
        # local function.
        assert "function __jacSpawn(" in js;
        assert "{__jacJsx, __jacSpawn}" not in js;
    }
}
