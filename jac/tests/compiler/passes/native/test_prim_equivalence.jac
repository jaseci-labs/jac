"""Cross-backend primitive equivalence tests for the native (LLVM) pathway.

Each fixture is a single .jac file containing a Python function (def foo_py)
and a native function (na { def foo_na }) returning dict[str, any].
The test imports the Python function, compiles the native function to LLVM IR,
runs both, and asserts the outputs match — mirroring the ES test pattern.
"""

import ctypes;
import importlib;
import json;
import os;
import struct;
import sys;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = str(
         Path(jaclang.__file__).parent.parent / "tests" / "compiler" / "passes" / "native" / "fixtures"
     );

"""Compile a .jac fixture and return the JIT engine for its na {} block."""
def compile_native(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: object, name: str, restype: type, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

"""Import a .jac fixture via the Jac import hook and call a function."""
def run_py_fixture(fixture_stem: str, func_name: str) -> dict {
    added = False;
    if FIXTURES not in sys.path {
        sys.path.insert(0, FIXTURES);
        added = True;
    }
    try {
        sys.modules.pop(fixture_stem, None);
        mod = importlib.import_module(fixture_stem);
        fn = getattr(mod, func_name);
        return json.loads(json.dumps(fn()));
    } finally {
        if added {
            sys.path.remove(FIXTURES);
        }
        sys.modules.pop(fixture_stem, None);
    }
}

# --- JacVal (tagged union) support for dict[str, any] ---
"""JacVal ctypes struct matching the native JacVal {i8 tag, i64 payload}."""
class JacVal(ctypes.Structure) {
    has _fields_: list = [("tag", ctypes.c_int8), ("payload", ctypes.c_int64)];
}

"""Unbox a JacVal tagged union to a Python value.

Tag 0 = int (payload is i64), Tag 1 = float (payload is f64 bitcast to i64),
Tag 2 = str (payload is i8* ptrtoint to i64).
"""
def unbox_jacval(jv: JacVal) -> object {
    if jv.tag == 0 {
        return jv.payload;
    } elif jv.tag == 1 {
        return struct.unpack('d', struct.pack('q', jv.payload))[0];
    } elif jv.tag == 2 {
        if jv.payload == 0 {
            return "";
        }
        return ctypes.cast(jv.payload, ctypes.c_char_p).value.decode("utf-8");
    }
    return None;
}

"""Read a dict[str, any] returned by a native function via ctypes.

The native function returns a pointer to Dict.ptr.jacval struct:
{i64 len, i64 cap, i8** keys, JacVal* vals}
"""
def run_native_function(eng: object, func_name: str) -> dict {
    class DictStruct(ctypes.Structure) {
        has _fields_: list = [
            ("len", ctypes.c_int64),
            ("cap", ctypes.c_int64),
            ("keys", ctypes.POINTER(ctypes.c_char_p)),
            ("vals", ctypes.POINTER(JacVal))
        ];
    }
    f = get_func(eng, func_name, ctypes.POINTER(DictStruct));
    dict_ptr = f();
    result: dict = {};
    for i in range(dict_ptr.contents.len) {
        key = dict_ptr.contents.keys[i].decode("utf-8");
        jv = dict_ptr.contents.vals[i];
        result[key] = unbox_jacval(jv);
    }
    return result;
}

"""Assert two result dicts are equivalent, with float tolerance."""
def compare_results(
    py_result: dict, native_result: dict, label: str, tolerance: float = 1e-9
) -> None {
    py_keys = set(py_result.keys());
    na_keys = set(native_result.keys());
    assert py_keys == na_keys , (
        f"[{label}] Key mismatch: py has {sorted(py_keys - na_keys)}, "
        f"native has {sorted(na_keys - py_keys)}"
    );
    for key in sorted(py_keys) {
        expected = py_result[key];
        actual = native_result[key];
        if isinstance(expected, float) {
            assert isinstance(actual, float) and abs(actual - expected) < tolerance , (
                f"[{label}] Float mismatch on '{key}': native={actual} py={expected}"
            );
        } elif isinstance(expected, str) {
            assert actual == expected , (
                f"[{label}] Str mismatch on '{key}': native={actual!r} py={expected!r}"
            );
        } else {
            assert actual == expected , (
                f"[{label}] Int mismatch on '{key}': native={actual} py={expected}"
            );
        }
    }
}

# --- Tests ---
test "numeric operators match across backends" {
    py_result = run_py_fixture("prim_numeric", "numeric_py");
    (eng, _) = compile_native("prim_numeric.jac");
    na_result = run_native_function(eng, "numeric_na");
    compare_results(py_result, na_result, "numeric");
}

test "builtin functions match across backends" {
    py_result = run_py_fixture("prim_builtins", "builtins_py");
    (eng, _) = compile_native("prim_builtins.jac");
    na_result = run_native_function(eng, "builtins_na");
    compare_results(py_result, na_result, "builtins");
}

test "string methods match across backends" {
    py_result = run_py_fixture("prim_str_methods", "str_methods_py");
    (eng, _) = compile_native("prim_str_methods.jac");
    na_result = run_native_function(eng, "str_methods_na");
    compare_results(py_result, na_result, "str_methods");
}

test "list methods match across backends" {
    py_result = run_py_fixture("prim_list_methods", "list_methods_py");
    (eng, _) = compile_native("prim_list_methods.jac");
    na_result = run_native_function(eng, "list_methods_na");
    compare_results(py_result, na_result, "list_methods");
}

test "dict methods match across backends" {
    py_result = run_py_fixture("prim_dict_methods", "dict_methods_py");
    (eng, _) = compile_native("prim_dict_methods.jac");
    na_result = run_native_function(eng, "dict_methods_na");
    compare_results(py_result, na_result, "dict_methods");
}

test "string advanced methods match across backends" {
    py_result = run_py_fixture("prim_str_advanced", "str_advanced_py");
    (eng, _) = compile_native("prim_str_advanced.jac");
    na_result = run_native_function(eng, "str_advanced_na");
    compare_results(py_result, na_result, "str_advanced");
}

test "float comparisons match across backends" {
    py_result = run_py_fixture("prim_float_cmp", "float_cmp_py");
    (eng, _) = compile_native("prim_float_cmp.jac");
    na_result = run_native_function(eng, "float_cmp_na");
    compare_results(py_result, na_result, "float_cmp");
}

test "extra builtin functions match across backends" {
    py_result = run_py_fixture("prim_builtins_extra", "builtins_extra_py");
    (eng, _) = compile_native("prim_builtins_extra.jac");
    na_result = run_native_function(eng, "builtins_extra_na");
    compare_results(py_result, na_result, "builtins_extra");
}

test "int methods match across backends" {
    py_result = run_py_fixture("prim_int_methods", "int_methods_py");
    (eng, _) = compile_native("prim_int_methods.jac");
    na_result = run_native_function(eng, "int_methods_na");
    compare_results(py_result, na_result, "int_methods");
}

test "float methods match across backends" {
    py_result = run_py_fixture("prim_float_methods", "float_methods_py");
    (eng, _) = compile_native("prim_float_methods.jac");
    na_result = run_native_function(eng, "float_methods_na");
    compare_results(py_result, na_result, "float_methods");
}

test "string comparisons match across backends" {
    py_result = run_py_fixture("prim_str_cmp", "str_cmp_py");
    (eng, _) = compile_native("prim_str_cmp.jac");
    na_result = run_native_function(eng, "str_cmp_na");
    compare_results(py_result, na_result, "str_cmp");
}

test "string extra methods match across backends" {
    py_result = run_py_fixture("prim_str_extra", "str_extra_py");
    (eng, _) = compile_native("prim_str_extra.jac");
    na_result = run_native_function(eng, "str_extra_na");
    compare_results(py_result, na_result, "str_extra");
}

test "set methods match across backends" {
    py_result = run_py_fixture("prim_set_methods", "set_methods_py");
    (eng, _) = compile_native("prim_set_methods.jac");
    na_result = run_native_function(eng, "set_methods_na");
    compare_results(py_result, na_result, "set_methods");
}

test "list extra methods match across backends" {
    py_result = run_py_fixture("prim_list_extra", "list_extra_py");
    (eng, _) = compile_native("prim_list_extra.jac");
    na_result = run_native_function(eng, "list_extra_na");
    compare_results(py_result, na_result, "list_extra");
}

test "bool conversion matches across backends" {
    py_result = run_py_fixture("prim_bool_conv", "bool_conv_py");
    (eng, _) = compile_native("prim_bool_conv.jac");
    na_result = run_native_function(eng, "bool_conv_na");
    compare_results(py_result, na_result, "bool_conv");
}

test "string index methods match across backends" {
    py_result = run_py_fixture("prim_str_index", "str_index_py");
    (eng, _) = compile_native("prim_str_index.jac");
    na_result = run_native_function(eng, "str_index_na");
    compare_results(py_result, na_result, "str_index");
}

test "list remove matches across backends" {
    py_result = run_py_fixture("prim_list_remove", "list_remove_py");
    (eng, _) = compile_native("prim_list_remove.jac");
    na_result = run_native_function(eng, "list_remove_na");
    compare_results(py_result, na_result, "list_remove");
}

test "dict copy and clear match across backends" {
    py_result = run_py_fixture("prim_dict_copy", "dict_copy_py");
    (eng, _) = compile_native("prim_dict_copy.jac");
    na_result = run_native_function(eng, "dict_copy_na");
    compare_results(py_result, na_result, "dict_copy");
}

test "string operators match across backends" {
    py_result = run_py_fixture("prim_str_ops", "str_ops_py");
    (eng, _) = compile_native("prim_str_ops.jac");
    na_result = run_native_function(eng, "str_ops_na");
    compare_results(py_result, na_result, "str_ops");
}

test "list operators match across backends" {
    py_result = run_py_fixture("prim_list_ops", "list_ops_py");
    (eng, _) = compile_native("prim_list_ops.jac");
    na_result = run_native_function(eng, "list_ops_na");
    compare_results(py_result, na_result, "list_ops");
}

test "set remove and pop match across backends" {
    py_result = run_py_fixture("prim_set_ops", "set_ops_py");
    (eng, _) = compile_native("prim_set_ops.jac");
    na_result = run_native_function(eng, "set_ops_na");
    compare_results(py_result, na_result, "set_ops");
}

test "dict extra methods match across backends" {
    py_result = run_py_fixture("prim_dict_extra", "dict_extra_py");
    (eng, _) = compile_native("prim_dict_extra.jac");
    na_result = run_native_function(eng, "dict_extra_na");
    compare_results(py_result, na_result, "dict_extra");
}

test "set algebra matches across backends" {
    py_result = run_py_fixture("prim_set_algebra", "set_algebra_py");
    (eng, _) = compile_native("prim_set_algebra.jac");
    na_result = run_native_function(eng, "set_algebra_na");
    compare_results(py_result, na_result, "set_algebra");
}

test "string join matches across backends" {
    py_result = run_py_fixture("prim_str_join", "str_join_py");
    (eng, _) = compile_native("prim_str_join.jac");
    na_result = run_native_function(eng, "str_join_na");
    compare_results(py_result, na_result, "str_join");
}

test "list sort matches across backends" {
    py_result = run_py_fixture("prim_list_sort", "list_sort_py");
    (eng, _) = compile_native("prim_list_sort.jac");
    na_result = run_native_function(eng, "list_sort_na");
    compare_results(py_result, na_result, "list_sort");
}
