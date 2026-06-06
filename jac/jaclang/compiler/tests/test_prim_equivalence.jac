"""Unified cross-backend primitive equivalence tests.

One test per emitter class in primitives.jac. Each fixture exposes a
func_py / cl func_cl / na func_na returning a JSON-able dict; the shared
`xbackend_equiv` harness runs them across the sv/cl/na backends and compares
with intersection semantics (a backend that returns {} or fails to compile is
silently skipped).
"""

import ctypes;
import from jaclang.compiler.tests.xbackend_equiv {
    run_with_both,
    run_py_fixture,
    compile_fixture_to_js,
    run_js_function,
    compile_native,
    get_func,
    compare_results
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

# --- Stdlib: math module (Mechanism A → libm, issue #6404 v1) ---
test "math" {
    run_with_both("prim_math.jac", "math_py", "math_cl", "math_na", require=["na"]);
}

# --- Stdlib: time module (Mechanism A → clock_gettime/nanosleep, #6404 v1) ---
test "time" {
    run_with_both("prim_time.jac", "time_py", "time_cl", "time_na", require=["na"]);
}

# --- Stdlib: sys module (Mechanism A, issue #6404 v1) ---
test "sys" {
    run_with_both("prim_sys.jac", "sys_py", "sys_cl", "sys_na", require=["na"]);
}

# --- Stdlib: os + os.path (Mechanism A/H → libc, issue #6404 v1) ---
test "os" {
    run_with_both("prim_os.jac", "os_py", "os_cl", "os_na", require=["na"]);
}

# --- Stdlib: random module (CPython-faithful MT19937, issue #6404 v1) ---
test "random" {
    run_with_both(
        "prim_random.jac", "random_py", "random_cl", "random_na", require=["na"]
    );
}

# --- dict insertion-order lock (issue #6404 congruence #3, gates json) ---
test "dict order" {
    run_with_both(
        "prim_dictorder.jac",
        "dictorder_py",
        "dictorder_cl",
        "dictorder_na",
        require=["na"]
    );
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
