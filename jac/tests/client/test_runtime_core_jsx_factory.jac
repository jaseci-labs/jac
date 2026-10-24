"""The compiled runtime core must be able to resolve the JSX factory it calls.

The core's error boundary and dev overlay are the only JSX in the runtime core,
so they lower to `__jacJsx(...)` calls. The factory itself is React-specific and
lives in the platform runtime, which imports core -- core cannot import it back.
If the compile path stops injecting the factory import, the emitted core still
looks fine and every app still renders, but the error boundary dies with
`__jacJsx is not defined` the moment anything throws.
"""

import re;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

"""Drive the real client compile path over a throwaway project and return the
compiled runtime-core JS it writes to disk."""
def _compile_runtime_core_js(proj: Path) -> str {
    import from jaclang.client.vite_client_bundle { ViteClientBundleBuilder }

    (proj / "package.json").write_text('{"name":"t","version":"0.0.0"}');
    out_dir = proj / "out";

    builder = ViteClientBundleBuilder(vite_package_json=proj / "package.json");
    compiler = builder._get_compiler();
    compiler.runtime_path = proj / "package.json";
    compiler.compiled_dir = out_dir;
    compiler.jac_client_compiler.compiled_dir = out_dir;
    # A full compile emits the app's closure, which reaches the runtime through
    # @jac/runtime, before compile_runtime_utils writes it: both must agree.
    (proj / "app.jac").write_text(
        'def:pub app() -> any {\n    has count: int = 0;\n    return <div>{count}</div>;\n}\n'
    );
    compiler.jac_client_compiler.emit_dependencies(proj / "app.jac", visited=set());
    runtime_js = out_dir / "client_runtime.js";
    emitted = runtime_js.read_text();
    compiler.compile_runtime_utils();
    assert runtime_js.read_text() == emitted , "client_runtime.js has two writers that disagree";

    core_js = out_dir / "client_runtime_core.js";
    assert core_js.exists() , "compile path should emit client_runtime_core.js";
    return core_js.read_text();
}

test "compiled runtime core can resolve the jsx factory it calls" {
    with TemporaryDirectory() as tmp {
        js = _compile_runtime_core_js(Path(tmp));
        assert "__jacJsx(" in js , "runtime core should emit JSX factory calls";
        defines = "function __jacJsx(" in js;
        imports = re.search(
            r"(?m)^import\s+\{[^}]*\b__jacJsx\b[^}]*\}\s+from\s+[\"']@jac/runtime[\"']",
            js
        )
            is not None;
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

test "every framework's runtime is written where @jac/runtime resolves" {
    import jaclang.client.runtime_source as runtime_source;
    import from jaclang.client.vite_client_bundle { ViteClientBundleBuilder }

    original = runtime_source.client_runtime_cl_basename;
    try {
        for basename in ["client_runtime.jac", "solid_runtime.jac"] {
            runtime_source.client_runtime_cl_basename = lambda (
                framework: str = ""
            ) -> str { return basename; };
            with TemporaryDirectory() as tmp {
                proj = Path(tmp);
                (proj / "package.json").write_text('{"name":"t","version":"0.0.0"}');
                compiler = ViteClientBundleBuilder(
                    vite_package_json=proj / "package.json"
                )._get_compiler();
                compiler.runtime_path = proj / "package.json";
                compiler.compiled_dir = proj / "out";
                compiler.jac_client_compiler.compiled_dir = proj / "out";
                compiler.compile_runtime_utils();
                runtime_js = proj / "out" / "client_runtime.js";
                assert runtime_js.exists() , f"{basename} was not written to client_runtime.js";
                assert basename in runtime_js.read_text().split("\n", 1)[0];
            }
        }
    } finally {
        runtime_source.client_runtime_cl_basename = original;
    }
}
