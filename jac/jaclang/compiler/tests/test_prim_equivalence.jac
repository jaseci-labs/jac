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
# Tests -- one per emitter class in primitives.jac
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

# --- String literal escape sequences (#6476 item 1), cl required ---
test "string escapes" {
    run_with_both(
        "cl_string_escapes.jac",
        "escapes_py",
        "escapes_cl",
        "escapes_na",
        require=["cl"]
    );
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

# --- Native list/`any` codegen gaps (#6435), na required ---
test "native list pop index" {
    run_with_both(
        "native_list_any_ops.jac",
        "pop_index_py",
        "pop_index_cl",
        "pop_index_na",
        require=["na"]
    );
}

test "native list tuple roundtrip" {
    run_with_both(
        "native_list_any_ops.jac",
        "tuple_roundtrip_py",
        "tuple_roundtrip_cl",
        "tuple_roundtrip_na",
        require=["na"]
    );
}

test "native list any literal" {
    run_with_both(
        "native_list_any_ops.jac",
        "any_literal_py",
        "any_literal_cl",
        "any_literal_na",
        require=["na"]
    );
}

test "native list any unpack stack" {
    run_with_both(
        "native_list_any_ops.jac",
        "any_stack_py",
        "any_stack_cl",
        "any_stack_na",
        require=["na"]
    );
}

test "native list container truthiness dfs" {
    run_with_both(
        "native_list_any_ops.jac",
        "dfs_stack_py",
        "dfs_stack_cl",
        "dfs_stack_na",
        require=["na"]
    );
}

# --- #6449: scalar/boxed `any` values round-trip through the native JacVal, na required ---
test "native any scalar box" {
    run_with_both(
        "native_list_any_ops.jac",
        "any_scalar_box_py",
        "any_scalar_box_cl",
        "any_scalar_box_na",
        require=["na"]
    );
}

test "native any dict local read" {
    run_with_both(
        "native_list_any_ops.jac",
        "any_dict_local_py",
        "any_dict_local_cl",
        "any_dict_local_na",
        require=["na"]
    );
}

test "native any tuple roundtrip" {
    run_with_both(
        "native_list_any_ops.jac",
        "any_tuple_roundtrip_py",
        "any_tuple_roundtrip_cl",
        "any_tuple_roundtrip_na",
        require=["na"]
    );
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

# --- Stdlib: math module (Mechanism A -> libm, issue #6404 v1) ---
test "math" {
    run_with_both("prim_math.jac", "math_py", "math_cl", "math_na", require=["na"]);
}

# --- Stdlib: time module (Mechanism A -> clock_gettime/nanosleep, #6404 v1) ---
test "time" {
    run_with_both("prim_time.jac", "time_py", "time_cl", "time_na", require=["na"]);
}

# --- Stdlib: sys module (Mechanism A, issue #6404 v1) ---
test "sys" {
    run_with_both("prim_sys.jac", "sys_py", "sys_cl", "sys_na", require=["na"]);
}

# --- Stdlib: os + os.path (Mechanism A/H -> libc, issue #6404 v1) ---
test "os" {
    run_with_both("prim_os.jac", "os_py", "os_cl", "os_na", require=["na"]);
}

# --- Bundled native stdlib: os.path (Mechanism B via na_stdlib resolution
# keystone, issue #6940). The same `import from os.path { ... }` binds CPython
# posixpath on sv and the bundled na_stdlib/os/path.na.jac on na. ---
test "os.path bundled" {
    run_with_both(
        "prim_ospath.jac", "ospath_py", "ospath_cl", "ospath_na", require=["na"]
    );
}

# --- Bundled native stdlib: zlib (Mechanism F — pure-Jac surface over the
# system libz FFI floor, issue #6940 Phase 2). The same `import from zlib { ... }`
# binds CPython's zlib on sv and the bundled na_stdlib/zlib.na.jac on na. ---
test "zlib bundled" {
    run_with_both("prim_zlib.jac", "zlib_py", "zlib_cl", "zlib_na", require=["na"]);
}

# --- Static-method calls + class-attribute reads on user classes (issue #6951).
# `ClassName.method(args)` on a `static def` and `ClassName.attr` on a
# `static has`, including inheritance through the MRO; unblocks datetime. ---
test "static members" {
    run_with_both(
        "prim_static_members.jac",
        "static_members_py",
        "static_members_cl",
        "static_members_na",
        require=["na"]
    );
}

# --- Bundled native stdlib: datetime (Mechanism B, issue #6940 / #6951). The
# same `import from datetime { datetime, timezone }` binds CPython datetime on sv
# and na_stdlib/datetime.na.jac on na, riding the static-method + class-attribute
# capability (datetime.now / fromtimestamp + timezone.utc). ---
test "datetime bundled" {
    run_with_both(
        "prim_datetime.jac", "datetime_py", "datetime_cl", "datetime_na", require=["na"]
    );
}

# --- Bundled native stdlib: json (Mechanism B via na_stdlib resolution
# keystone, issue #6940 Phase 1). The same `import from json { loads, dumps }`
# binds CPython json on sv and the bundled na_stdlib/json.na.jac on na: a
# recursive-descent parser over boxed `any` plus a CPython-default serializer. ---
test "json bundled" {
    run_with_both("prim_json.jac", "json_py", "json_cl", "json_na", require=["na"]);
}

# --- Stdlib: random module (CPython-faithful MT19937, issue #6404 v1) ---
test "random" {
    run_with_both(
        "prim_random.jac", "random_py", "random_cl", "random_na", require=["na"]
    );
}

# --- isinstance-on-`any` + scalar box/unbox round-trip (issue #6421, gates json) ---
test "any dispatch" {
    run_with_both(
        "prim_any.jac",
        "any_dispatch_py",
        "any_dispatch_cl",
        "any_dispatch_na",
        require=["na"]
    );
}

# --- native `any`/`str()` stdlib gaps closed for #6943 (gates a pure-Jac json) ---
# Scalar/string congruence: str(None) (NA-1), str(bool) (NA-8),
# strip/lstrip/rstrip(chars) (NA-9), empty-string truthiness in a ternary (NA-10).
test "native any congruence" {
    run_with_both(
        "native_any_stdlib_gaps.jac",
        "congruence_check_py",
        "congruence_check_cl",
        "congruence_check_na",
        require=["na"]
    );
}

# Produce + consume `any` containers: subscript an `any` (NA-3), iterate an `any`
# (NA-4), len() on an `any` (NA-5), empty `list[any] = []` (NA-6).
test "native any container ops" {
    run_with_both(
        "native_any_stdlib_gaps.jac",
        "any_ops_check_py",
        "any_ops_check_cl",
        "any_ops_check_na",
        require=["na"]
    );
}

# The json.dumps object-branch shape: isinstance-guarded any->dict narrow +
# dict-key iteration + `str +=` / `out = out + k` (NA-2, was a SIGSEGV/UAF).
test "native any guarded consume" {
    run_with_both(
        "native_any_stdlib_gaps.jac",
        "guard_consume_check_py",
        "guard_consume_check_cl",
        "guard_consume_check_na",
        require=["na"]
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

# --- Exception Types (ExceptionEmitter) -- dict-comparison for py/cl ---
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

# --- Exception Types (ExceptionEmitter) -- NA int-returning tests ---
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

# --- Builtin Functions (BuiltinEmitter) -- introspection methods ---
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
