"""Regression tests for the jac2js runtime-globals emission bug class (#7540).

Any surface that emits client JavaScript for loading as ESM must prepend
required ``@jac/runtime`` imports (``__jacJsx``, ``__jacSpawn``) when the
generated code references them. Missing imports cause ``ReferenceError`` in
Node, Vite, and the desktop fused runtime.

This file pins every known emission path so a new consumer cannot silently
reintroduce the bug.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from tests.support { JAC_ROOT }
import from jaclang.cli.mcp.compiler_bridge { CompilerBridge }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.runtimelib.client_bundle { ClientBundleBuilder }
import from jaclang.runtimelib.client.jac_to_js { JacToJSCompiler }

glob FIXTURE = os.path.join(
         JAC_ROOT,
         "tests",
         "compiler",
         "passes",
         "ecmascript",
         "fixtures",
         "client_jsx.jac"
     ),
     _MINIMAL_JSX = 'cl def:pub render(items: list) -> any {\n    return <div>{items}</div>;\n}\n',
     _test_tmp_dir: str = tempfile.mkdtemp(prefix="jac_js_emission_");

"""Assert emission-ready JS includes required runtime globals."""
def assert_emission_ready_js(js: str, path_label: str) {
    assert js.strip() , f"{path_label}: expected non-empty JS output";
    assert "__jacJsx(" in js , f"{path_label}: JSX lowering must reference __jacJsx";
    assert "@jac/runtime" in js , (
        f"{path_label}: missing @jac/runtime import for __jacJsx/__jacSpawn"
    );
    assert "import {" in js and "} from \"@jac/runtime\";" in js , (
        f"{path_label}: expected ESM import from @jac/runtime, got:\n{js[:300]}"
    );
}

"""Write inline Jac to a temp file and return its path."""
def _write_temp_jac(code: str) -> str {
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".cl.jac", delete=False, dir=_test_tmp_dir
    ) as tmp {
        tmp.write(code);
        return tmp.name;
    }
}

"""Run ``jac tool jac2js`` against a fixture path."""
def _jac_tool_jac2js(fixture_path: str) -> str {
    env = os.environ.copy();
    env["PYTHONPATH"] = JAC_ROOT + (
        os.pathsep + env["PYTHONPATH"] if env.get("PYTHONPATH") else ""
    );
    result = subprocess.run(
        [sys.executable, "-m", "jaclang.cli.cli", "tool", "jac2js", fixture_path],
        capture_output=True,
        text=True,
        env=env,
    );
    assert result.returncode == 0 , (f"jac tool jac2js failed: {result.stderr}");
    return result.stdout;
}

test "finalize_js_for_emission prepends @jac/runtime for JSX" {
    import from jaclang.compiler.passes.ecmascript.js_runtime_globals {
        finalize_js_for_emission
    }
    raw = 'function render(items) {\n  return __jacJsx("div", {}, [items]);\n}\n';
    finalized = finalize_js_for_emission(raw);
    assert_emission_ready_js(finalized, "finalize_js_for_emission");
}

test "jac tool jac2js CLI emits runtime globals" {
    assert_emission_ready_js(_jac_tool_jac2js(FIXTURE), "jac tool jac2js");
}

test "JacProgram.compile gen.js path uses bundle finalize on emission" {
    prog = JacProgram();
    mod = prog.compile(file_path=FIXTURE);
    assert not prog.errors_had , f"compile errors: {prog.errors_had}";
    builder = ClientBundleBuilder();
    (js, _) = builder._compile_to_js(Path(FIXTURE));
    assert_emission_ready_js(js, "ClientBundleBuilder._compile_to_js");
}

test "MCP CompilerBridge.jac_to_js emits runtime globals" {
    result = CompilerBridge.jac_to_js(_MINIMAL_JSX);
    assert not result["warnings"] or result["js_code"].strip() , (
        f"MCP jac_to_js warnings: {result['warnings']}"
    );
    assert_emission_ready_js(result["js_code"], "CompilerBridge.jac_to_js");
}

test "JacToJSCompiler add_runtime_imports matches finalize helper" {
    temp_path = _write_temp_jac(_MINIMAL_JSX);
    try {
        compiler = JacToJSCompiler(
            compile_to_js_func=ClientBundleBuilder()._compile_to_js
        );
        (module_js, _, _) = compiler.compile_module(Path(temp_path));
        finalized = compiler.add_runtime_imports(module_js);
        assert_emission_ready_js(finalized, "JacToJSCompiler desktop path");
        # Idempotent: applying twice must not duplicate the import line.
        again = compiler.add_runtime_imports(finalized);
        assert again.count('from "@jac/runtime"') == finalized.count(
            'from "@jac/runtime"'
        ) , "runtime import injection must be idempotent";
    } finally {
        os.unlink(temp_path);
    }
}

test "runtime modules that define __jacJsx inline skip prepend" {
    # Runtime sources ship their own __jacJsx definition; prepending an import
    # would be wrong and these modules must compile cleanly through jac2js.
    import importlib;
    plugin = importlib.import_module("jaclang.runtimelib.client");
    paths = list(getattr(plugin, "__path__", []) or []);
    assert paths , "jaclang.runtimelib.client must be importable";
    core_src = os.path.join(paths[0], "client_runtime_core.cl.jac");
    if not os.path.isfile(core_src) {
        return;
    }
    js = _jac_tool_jac2js(core_src);
    assert "function __jacJsx" in js , "runtime core must define __jacJsx";
    assert 'import {__jacJsx' not in js , (
        "runtime core must not import __jacJsx from itself"
    );
}

test "known emission surfaces call finalize_js_for_emission" {
    # Static guard: every file that emits client JS must use the canonical
    # finalizer so new paths cannot skip runtime-global injection.
    jac_root = Path(JAC_ROOT);
    required_snippet = "finalize_js_for_emission";
    surfaces = [
        jac_root / "jaclang" / "cli" / "commands" / "impl" / "transform.impl.jac",
        jac_root / "jaclang" / "cli" / "mcp" / "impl" / "compiler_bridge.impl.jac",
        jac_root / "jaclang" / "runtimelib" / "impl" / "client_bundle.impl.jac",
        jac_root / "jaclang" / "publish" / "impl" / "runtime_npm.impl.jac",
        jac_root / "jaclang" / "publish" / "impl" / "npm_sources.impl.jac",

    ];
    for path in surfaces {
        text = path.read_text(encoding="utf-8");
        assert required_snippet in text , (
            f"{path.relative_to(jac_root)} must call {required_snippet}"
        );
    }
}
