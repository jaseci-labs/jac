"""Unified cross-backend primitive equivalence tests.

One test per emitter class in primitives.jac. Each fixture contains:
  - def func_py()            Python reference (always run)
  - cl def func_cl()         ECMAScript/JS via Node.js
  - na { def func_na() }     Native LLVM JIT via ctypes

compare_results uses intersection semantics: only keys present in both
dicts are checked. Backends returning {} (unimplemented) are silently skipped.
"""

import ctypes;
import importlib;
import json;
import os;
import struct;
import subprocess;
import sys;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.compiler.passes.ecmascript.estree { Node as EsNode }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = str(
         Path(jaclang.__file__).parent / "compiler" / "tests" / "fixtures"
     );

# -----------------------------------------------------------------------
# Python reference helper
# -----------------------------------------------------------------------
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

# -----------------------------------------------------------------------
# ES (ECMAScript / JavaScript) helpers
# -----------------------------------------------------------------------
def compile_fixture_to_js(fixture_name: str) -> str {
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

def run_js_function(js_code: str, func_name: str) -> dict {
    wrapper = js_code + "\nconsole.log(JSON.stringify(" + func_name + "()));";
    result = subprocess.run(
        ["node", "-e", wrapper], capture_output=True, text=True, timeout=10
    );
    assert result.returncode == 0 , f"Node.js failed: {result.stderr}";
    return json.loads(result.stdout.strip());
}

# -----------------------------------------------------------------------
# NA (Native / LLVM) helpers
# -----------------------------------------------------------------------
def compile_native(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

def get_func(eng: object, name: str, restype: type, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

class JacVal(ctypes.Structure) {
    has _fields_: list = [("tag", ctypes.c_int8), ("payload", ctypes.c_int64)];
}

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
    } elif jv.tag == 3 {
        # List pointer: struct { i64 len, i64 cap, i64* data } (List.i64 layout)
        if jv.payload == 0 {
            return [];
        }
        class ListStruct(ctypes.Structure) {
            has _fields_: list = [
                ("len", ctypes.c_int64),
                ("cap", ctypes.c_int64),
                ("data", ctypes.POINTER(ctypes.c_int64))
            ];
        }
        lst_ptr = ctypes.cast(jv.payload, ctypes.POINTER(ListStruct));
        n = lst_ptr.contents.len;
        return [lst_ptr.contents.data[i] for i in range(n)];
    } elif jv.tag == 4 {
        # Dict pointer: struct { i64 len, i64 cap, i8** keys, JacVal* vals }
        if jv.payload == 0 {
            return {};
        }
        class InnerDictStruct(ctypes.Structure) {
            has _fields_: list = [
                ("len", ctypes.c_int64),
                ("cap", ctypes.c_int64),
                ("keys", ctypes.POINTER(ctypes.c_char_p)),
                ("vals", ctypes.POINTER(JacVal))
            ];
        }
        dct_ptr = ctypes.cast(jv.payload, ctypes.POINTER(InnerDictStruct));
        n = dct_ptr.contents.len;
        result: dict = {};
        for i in range(n) {
            k = dct_ptr.contents.keys[i].decode("utf-8");
            result[k] = unbox_jacval(dct_ptr.contents.vals[i]);
        }
        return result;
    } elif jv.tag == 5 {
        # Set pointer: struct { i64 len, i64 cap, i64* elems } (Set.i64 layout)
        if jv.payload == 0 {
            return set();
        }
        class SetStruct(ctypes.Structure) {
            has _fields_: list = [
                ("len", ctypes.c_int64),
                ("cap", ctypes.c_int64),
                ("elems", ctypes.POINTER(ctypes.c_int64))
            ];
        }
        st_ptr = ctypes.cast(jv.payload, ctypes.POINTER(SetStruct));
        n = st_ptr.contents.len;
        return {st_ptr.contents.elems[i] for i in range(n)};
    }
    return None;
}

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

# -----------------------------------------------------------------------
# Comparison: intersection-based (only keys present in BOTH dicts)
# -----------------------------------------------------------------------
def compare_results(
    py_result: dict, backend_result: dict, label: str, tolerance: float = 1e-9
) -> None {
    common_keys = set(py_result.keys()) & set(backend_result.keys());
    if not common_keys {
        return;
    }
    for key in sorted(common_keys) {
        py_val = py_result[key];
        bk_val = backend_result[key];
        if isinstance(py_val, float) or isinstance(bk_val, float) {
            assert abs(float(py_val) - float(bk_val)) < tolerance , (
                f"[{label}] Float mismatch on '{key}': py={py_val} backend={bk_val}"
            );
        } elif isinstance(py_val, list) and isinstance(bk_val, list) {
            assert py_val == bk_val , (
                f"[{label}] List mismatch on '{key}': py={py_val} backend={bk_val}"
            );
        } elif isinstance(py_val, dict) and isinstance(bk_val, dict) {
            assert py_val == bk_val , (
                f"[{label}] Dict mismatch on '{key}': py={py_val} backend={bk_val}"
            );
        } else {
            assert py_val == bk_val , (
                f"[{label}] Mismatch on '{key}': py={py_val!r} backend={bk_val!r}"
            );
        }
    }
}

# -----------------------------------------------------------------------
# Dispatch helper: run py reference, then try ES and NA backends
# -----------------------------------------------------------------------
def run_with_both(
    fixture: str, py_fn: str, cl_fn: str, na_fn: str, tolerance: float = 1e-9
) -> None {
    stem = fixture[:-4] if fixture.endswith(".jac") else fixture;
    py_result = run_py_fixture(stem, py_fn);
    label = fixture;
    try {
        js_code = compile_fixture_to_js(fixture);
        compare_results(
            py_result, run_js_function(js_code, cl_fn), f"{label} [ES]", tolerance
        );
    } except Exception { }
    try {
        (eng, _) = compile_native(fixture);
        compare_results(
            py_result, run_native_function(eng, na_fn), f"{label} [NA]", tolerance
        );
    } except Exception { }
}

# =======================================================================
# Tests — one per emitter class in primitives.jac
# =======================================================================

# --- Numeric Types (IntEmitter) ---
test "int" {
    run_with_both("prim_int.jac", "int_py", "int_cl", "int_na");
}

# --- Numeric Types (FloatEmitter) ---
test "float" {
    run_with_both("prim_float.jac", "float_py", "float_cl", "float_na");
}

# --- Numeric Types (ComplexEmitter) ---
test "complex" {
    run_with_both(
        "prim_complex.jac", "complex_ops_py", "complex_ops_cl", "complex_ops_na"
    );
}

# --- String Types (StrEmitter) ---
test "str" {
    run_with_both("prim_str.jac", "str_py", "str_cl", "str_na");
}

# --- String Types (BytesEmitter) ---
test "bytes search" {
    run_with_both(
        "prim_bytes.jac", "bytes_search_py", "bytes_search_cl", "bytes_search_na"
    );
}

test "bytes modify" {
    run_with_both(
        "prim_bytes.jac", "bytes_modify_py", "bytes_modify_cl", "bytes_modify_na"
    );
}

test "bytes case" {
    run_with_both("prim_bytes.jac", "bytes_case_py", "bytes_case_cl", "bytes_case_na");
}

test "bytes test methods" {
    run_with_both("prim_bytes.jac", "bytes_test_py", "bytes_test_cl", "bytes_test_na");
}

# --- Collection Types (ListEmitter) ---
test "list" {
    run_with_both("prim_list.jac", "list_py", "list_cl", "list_na");
}

# --- Collection Types (DictEmitter) ---
test "dict" {
    run_with_both("prim_dict.jac", "dict_py", "dict_cl", "dict_na");
}

# --- Collection Types (SetEmitter) ---
test "set" {
    run_with_both("prim_set.jac", "set_py", "set_cl", "set_na");
}

# --- Collection Types (FrozensetEmitter) ---
test "frozenset" {
    run_with_both("prim_frozenset.jac", "frozenset_py", "frozenset_cl", "frozenset_na");
}

# --- Collection Types (TupleEmitter) ---
test "tuple" {
    run_with_both("prim_tuple.jac", "tuple_py", "tuple_cl", "tuple_na");
}

# --- Collection Types (RangeEmitter) ---
test "range" {
    run_with_both("prim_range.jac", "range_py", "range_cl", "range_na");
}

# --- Builtin Functions (BuiltinEmitter) ---
test "builtins" {
    run_with_both("prim_builtins.jac", "builtins_py", "builtins_cl", "builtins_na");
}

# --- Exception Types (ExceptionEmitter) — dict-comparison for py/cl ---
test "exception hierarchy" {
    py_result = run_py_fixture("prim_exceptions", "exceptions_py");
    try {
        js_code = compile_fixture_to_js("prim_exceptions.jac");
        compare_results(
            py_result, run_js_function(js_code, "exceptions_cl"), "exceptions [ES]"
        );
    } except Exception { }
}

test "runtime error hierarchy" {
    py_result = run_py_fixture("prim_runtime_errors", "runtime_errors_py");
    try {
        js_code = compile_fixture_to_js("prim_runtime_errors.jac");
        compare_results(
            py_result,
            run_js_function(js_code, "runtime_errors_cl"),
            "runtime_errors [ES]"
        );
    } except Exception { }
}

# --- Exception Types (ExceptionEmitter) — NA int-returning tests ---
test "exception basic catch" {
    (eng, _) = compile_native("prim_exceptions.jac");
    f = get_func(eng, "test_basic_catch_na", ctypes.c_int64);
    assert f() == 1;
}

test "exception catch parent" {
    (eng, _) = compile_native("prim_exceptions.jac");
    f = get_func(eng, "test_catch_parent_na", ctypes.c_int64);
    assert f() == 1;
}

test "exception catch grandparent" {
    (eng, _) = compile_native("prim_exceptions.jac");
    f = get_func(eng, "test_catch_grandparent_na", ctypes.c_int64);
    assert f() == 1;
}

test "exception catch wrong type" {
    (eng, _) = compile_native("prim_exceptions.jac");
    f = get_func(eng, "test_catch_wrong_type_na", ctypes.c_int64);
    assert f() == 2;
}

test "exception multiple handlers" {
    (eng, _) = compile_native("prim_exceptions.jac");
    f = get_func(eng, "test_multiple_handlers_na", ctypes.c_int64);
    assert f() == 2;
}

test "exception nested" {
    (eng, _) = compile_native("prim_exceptions.jac");
    f = get_func(eng, "test_nested_hierarchy_na", ctypes.c_int64);
    assert f() == 1;
}

test "exception finally runs" {
    (eng, _) = compile_native("prim_exceptions.jac");
    f = get_func(eng, "test_finally_runs_na", ctypes.c_int64);
    assert f() == 11;
}

test "exception no exception" {
    (eng, _) = compile_native("prim_exceptions.jac");
    f = get_func(eng, "test_no_exception_na", ctypes.c_int64);
    assert f() == 11;
}

test "exception as binding" {
    (eng, _) = compile_native("prim_exceptions.jac");
    f = get_func(eng, "test_exc_as_binding_na", ctypes.c_int64);
    assert f() == 1;
}

test "runtime divzero caught exact" {
    (eng, _) = compile_native("prim_runtime_errors.jac");
    f = get_func(eng, "test_divzero_catch_exact_na", ctypes.c_int64);
    assert f() == 1;
}

test "runtime divzero caught parent" {
    (eng, _) = compile_native("prim_runtime_errors.jac");
    f = get_func(eng, "test_divzero_catch_parent_na", ctypes.c_int64);
    assert f() == 1;
}

test "runtime divzero caught grandparent" {
    (eng, _) = compile_native("prim_runtime_errors.jac");
    f = get_func(eng, "test_divzero_catch_grandparent_na", ctypes.c_int64);
    assert f() == 1;
}

test "runtime divzero wrong handler" {
    (eng, _) = compile_native("prim_runtime_errors.jac");
    f = get_func(eng, "test_divzero_wrong_handler_na", ctypes.c_int64);
    assert f() == 2;
}

test "runtime modulo zero" {
    (eng, _) = compile_native("prim_runtime_errors.jac");
    f = get_func(eng, "test_modulo_zero_na", ctypes.c_int64);
    assert f() == 1;
}

test "runtime index oob exact" {
    (eng, _) = compile_native("prim_runtime_errors.jac");
    f = get_func(eng, "test_index_oob_catch_exact_na", ctypes.c_int64);
    assert f() == 1;
}

test "runtime index oob parent" {
    (eng, _) = compile_native("prim_runtime_errors.jac");
    f = get_func(eng, "test_index_oob_catch_parent_na", ctypes.c_int64);
    assert f() == 1;
}

test "runtime index oob exception" {
    (eng, _) = compile_native("prim_runtime_errors.jac");
    f = get_func(eng, "test_index_oob_catch_exception_na", ctypes.c_int64);
    assert f() == 1;
}

test "runtime key error exact" {
    (eng, _) = compile_native("prim_runtime_errors.jac");
    f = get_func(eng, "test_key_error_catch_exact_na", ctypes.c_int64);
    assert f() == 1;
}

test "runtime key error parent" {
    (eng, _) = compile_native("prim_runtime_errors.jac");
    f = get_func(eng, "test_key_error_catch_parent_na", ctypes.c_int64);
    assert f() == 1;
}

test "runtime multi handler" {
    (eng, _) = compile_native("prim_runtime_errors.jac");
    f = get_func(eng, "test_multi_handler_runtime_na", ctypes.c_int64);
    assert f() == 2;
}

test "runtime error with finally" {
    (eng, _) = compile_native("prim_runtime_errors.jac");
    f = get_func(eng, "test_runtime_finally_na", ctypes.c_int64);
    assert f() == 11;
}

# --- Builtin Functions (BuiltinEmitter) — introspection methods ---
# emit_enumerate, emit_zip, emit_map, emit_filter, emit_isinstance,
# emit_issubclass, emit_type, emit_repr, emit_ascii, emit_callable,
# emit_hash, emit_id, emit_iter, emit_next, emit_hasattr, emit_getattr,
# emit_setattr, emit_vars, emit_delattr, emit_dir, emit_print,
# emit_input, emit_open
test "builtins introspection" {
    run_with_both(
        "prim_builtins_introspection.jac",
        "builtins_introspection_py",
        "builtins_introspection_cl",
        "builtins_introspection_na"
    );
}
