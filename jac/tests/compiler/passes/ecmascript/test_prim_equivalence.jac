"""Cross-backend primitive equivalence tests.

Each fixture has paired functions: a regular `def` (runs in Python) and a
`cl def` (compiles to JS).  The test imports the Python function, compiles
the cl function to JS, runs it in Node, and asserts the outputs match.
"""

import importlib;
import json;
import os;
import subprocess;
import sys;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.compiler.passes.ecmascript.estree { Node as EsNode }
import from jaclang.jac0core.program { JacProgram }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "ecmascript", "fixtures"
     );

def compile_fixture_to_js(fixture_name: str) -> str {
    """Compile a Jac fixture to JavaScript and return the emitted source."""
    fixture_path = os.path.join(FIXTURES, fixture_name);
    prog = JacProgram();
    ir = prog.compile(file_path=fixture_path, no_cgen=True);
    assert not prog.errors_had , (
        f"Compilation errors in {fixture_name}: {[str(e) for e in prog.errors_had]}"
    );
    es_pass = EsastGenPass(ir, prog);
    es_ir = es_pass.ir_out;
    assert isinstance(es_ir.gen.es_ast, EsNode) , "es_ast should be an EsNode";
    return es_to_js(es_ir.gen.es_ast);
}

def run_py_fixture(fixture_stem: str, func_name: str) -> dict {
    """Import a Jac fixture via the Jac import hook and call a function."""
    added = False;
    if FIXTURES not in sys.path {
        sys.path.insert(0, FIXTURES);
        added = True;
    }
    try {
        sys.modules.pop(fixture_stem, None);
        mod = importlib.import_module(fixture_stem);
        fn = getattr(mod, func_name);
        # JSON roundtrip normalizes tuples→lists, ensures consistent types
        return json.loads(json.dumps(fn()));
    } finally {
        if added {
            sys.path.remove(FIXTURES);
        }
        sys.modules.pop(fixture_stem, None);
    }
}

def run_js_function(js_code: str, func_name: str) -> dict {
    """Run a JS function in Node and return the parsed JSON result."""
    wrapper = js_code + "\nconsole.log(JSON.stringify(" + func_name + "()));";
    result = subprocess.run(
        ["node", "-e", wrapper], capture_output=True, text=True, timeout=10
    );
    assert result.returncode == 0 , f"Node.js failed: {result.stderr}";
    return json.loads(result.stdout.strip());
}

def compare_results(
    py_result: dict, js_result: dict, label: str, tolerance: float = 1e-9
) -> None {
    """Assert two result dicts are equivalent, with float tolerance."""
    py_keys = set(py_result.keys());
    js_keys = set(js_result.keys());
    assert py_keys == js_keys , (
        f"[{label}] Key mismatch: py={sorted(py_keys - js_keys)} js={sorted(
            js_keys - py_keys
        )}"
    );
    for key in sorted(py_result.keys()) {
        py_val = py_result[key];
        js_val = js_result[key];
        if isinstance(py_val, float) or isinstance(js_val, float) {
            assert abs(float(py_val) - float(js_val)) < tolerance , (
                f"[{label}] Float mismatch on '{key}': py={py_val} js={js_val}"
            );
        } elif isinstance(py_val, list) and isinstance(js_val, list) {
            assert py_val == js_val , (
                f"[{label}] List mismatch on '{key}': py={py_val} js={js_val}"
            );
        } elif isinstance(py_val, dict) and isinstance(js_val, dict) {
            assert py_val == js_val , (
                f"[{label}] Dict mismatch on '{key}': py={py_val} js={js_val}"
            );
        } else {
            assert py_val == js_val , (
                f"[{label}] Mismatch on '{key}': py={py_val!r} js={js_val!r}"
            );
        }
    }
}

test "numeric operators match across backends" {
    py_result = run_py_fixture("prim_numeric", "numeric_py");
    js_code = compile_fixture_to_js("prim_numeric.jac");
    js_result = run_js_function(js_code, "numeric_cl");
    compare_results(py_result, js_result, "numeric");
}

test "container operators match across backends" {
    py_result = run_py_fixture("prim_containers", "containers_py");
    js_code = compile_fixture_to_js("prim_containers.jac");
    js_result = run_js_function(js_code, "containers_cl");
    compare_results(py_result, js_result, "containers");
}

test "string methods match across backends" {
    py_result = run_py_fixture("prim_str_methods", "str_methods_py");
    js_code = compile_fixture_to_js("prim_str_methods.jac");
    js_result = run_js_function(js_code, "str_methods_cl");
    compare_results(py_result, js_result, "str_methods");
}

test "list methods match across backends" {
    py_result = run_py_fixture("prim_list_methods", "list_methods_py");
    js_code = compile_fixture_to_js("prim_list_methods.jac");
    js_result = run_js_function(js_code, "list_methods_cl");
    compare_results(py_result, js_result, "list_methods");
}

test "dict methods match across backends" {
    py_result = run_py_fixture("prim_dict_methods", "dict_methods_py");
    js_code = compile_fixture_to_js("prim_dict_methods.jac");
    js_result = run_js_function(js_code, "dict_methods_cl");
    compare_results(py_result, js_result, "dict_methods");
}

test "builtin functions match across backends" {
    py_result = run_py_fixture("prim_builtins", "builtins_py");
    js_code = compile_fixture_to_js("prim_builtins.jac");
    js_result = run_js_function(js_code, "builtins_cl");
    compare_results(py_result, js_result, "builtins");
}

test "jac runtime int methods match across backends" {
    py_result = run_py_fixture("prim_jac_runtime", "jac_rt_int_py");
    js_code = compile_fixture_to_js("prim_jac_runtime.jac");
    js_result = run_js_function(js_code, "jac_rt_int_cl");
    compare_results(py_result, js_result, "jac_rt_int");
}

test "jac runtime float methods match across backends" {
    py_result = run_py_fixture("prim_jac_runtime", "jac_rt_float_py");
    js_code = compile_fixture_to_js("prim_jac_runtime.jac");
    js_result = run_js_function(js_code, "jac_rt_float_cl");
    compare_results(py_result, js_result, "jac_rt_float");
}

test "jac runtime str methods match across backends" {
    py_result = run_py_fixture("prim_jac_runtime", "jac_rt_str_py");
    js_code = compile_fixture_to_js("prim_jac_runtime.jac");
    js_result = run_js_function(js_code, "jac_rt_str_cl");
    compare_results(py_result, js_result, "jac_rt_str");
}

test "jac runtime list methods match across backends" {
    py_result = run_py_fixture("prim_jac_runtime", "jac_rt_list_py");
    js_code = compile_fixture_to_js("prim_jac_runtime.jac");
    js_result = run_js_function(js_code, "jac_rt_list_cl");
    compare_results(py_result, js_result, "jac_rt_list");
}

test "jac runtime dict methods match across backends" {
    py_result = run_py_fixture("prim_jac_runtime", "jac_rt_dict_py");
    js_code = compile_fixture_to_js("prim_jac_runtime.jac");
    js_result = run_js_function(js_code, "jac_rt_dict_cl");
    compare_results(py_result, js_result, "jac_rt_dict");
}

test "jac runtime set methods match across backends" {
    py_result = run_py_fixture("prim_jac_runtime", "jac_rt_set_py");
    js_code = compile_fixture_to_js("prim_jac_runtime.jac");
    js_result = run_js_function(js_code, "jac_rt_set_cl");
    compare_results(py_result, js_result, "jac_rt_set");
}

test "jac runtime tuple methods match across backends" {
    py_result = run_py_fixture("prim_jac_runtime", "jac_rt_tuple_py");
    js_code = compile_fixture_to_js("prim_jac_runtime.jac");
    js_result = run_js_function(js_code, "jac_rt_tuple_cl");
    compare_results(py_result, js_result, "jac_rt_tuple");
}

test "jac runtime builtin functions match across backends" {
    py_result = run_py_fixture("prim_jac_runtime", "jac_rt_builtin_py");
    js_code = compile_fixture_to_js("prim_jac_runtime.jac");
    js_result = run_js_function(js_code, "jac_rt_builtin_cl");
    compare_results(py_result, js_result, "jac_rt_builtin");
}

test "bool truthiness matches Python semantics" {
    py_result = run_py_fixture("prim_new_primitives", "bool_truthiness_py");
    js_code = compile_fixture_to_js("prim_new_primitives.jac");
    js_result = run_js_function(js_code, "bool_truthiness_cl");
    compare_results(py_result, js_result, "bool_truthiness");
}

test "range builtin matches across backends" {
    py_result = run_py_fixture("prim_new_primitives", "range_builtin_py");
    js_code = compile_fixture_to_js("prim_new_primitives.jac");
    js_result = run_js_function(js_code, "range_builtin_cl");
    compare_results(py_result, js_result, "range_builtin");
}

test "bool bitwise operators match across backends" {
    py_result = run_py_fixture("prim_new_primitives", "bool_bitwise_py");
    js_code = compile_fixture_to_js("prim_new_primitives.jac");
    js_result = run_js_function(js_code, "bool_bitwise_cl");
    compare_results(py_result, js_result, "bool_bitwise");
}

test "format builtin matches across backends" {
    py_result = run_py_fixture("prim_new_primitives", "format_builtin_py");
    js_code = compile_fixture_to_js("prim_new_primitives.jac");
    js_result = run_js_function(js_code, "format_builtin_cl");
    compare_results(py_result, js_result, "format_builtin");
}

test "slice builtin matches across backends" {
    py_result = run_py_fixture("prim_new_primitives", "slice_builtin_py");
    js_code = compile_fixture_to_js("prim_new_primitives.jac");
    js_result = run_js_function(js_code, "slice_builtin_cl");
    compare_results(py_result, js_result, "slice_builtin");
}
