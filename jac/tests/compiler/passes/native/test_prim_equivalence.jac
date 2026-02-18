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
