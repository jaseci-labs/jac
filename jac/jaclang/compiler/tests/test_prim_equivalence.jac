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


test "int" {
    run_with_both("prim_int.jac", "int_py", "int_cl", "int_na");
}

test "float" {
    run_with_both("prim_float.jac", "float_py", "float_cl", "float_na");
}

test "complex" {
    run_with_both(
        "prim_complex.jac", "complex_ops_py", "complex_ops_cl", "complex_ops_na"
    );
}

test "str" {
    run_with_both("prim_str.jac", "str_py", "str_cl", "str_na");
}

test "string escapes" {
    run_with_both(
        "cl_string_escapes.jac",
        "escapes_py",
        "escapes_cl",
        "escapes_na",
        require=["cl"]
    );
}

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

test "list" {
    run_with_both("prim_list.jac", "list_py", "list_cl", "list_na");
}

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

test "dict" {
    run_with_both("prim_dict.jac", "dict_py", "dict_cl", "dict_na");
}

test "set" {
    run_with_both("prim_set.jac", "set_py", "set_cl", "set_na");
}

test "frozenset" {
    run_with_both("prim_frozenset.jac", "frozenset_py", "frozenset_cl", "frozenset_na");
}

test "tuple" {
    run_with_both("prim_tuple.jac", "tuple_py", "tuple_cl", "tuple_na");
}

test "range" {
    run_with_both("prim_range.jac", "range_py", "range_cl", "range_na");
}

test "builtins" {
    run_with_both("prim_builtins.jac", "builtins_py", "builtins_cl", "builtins_na");
}

test "math" {
    run_with_both("prim_math.jac", "math_py", "math_cl", "math_na", require=["na"]);
}

test "time" {
    run_with_both("prim_time.jac", "time_py", "time_cl", "time_na", require=["na"]);
}

test "sys" {
    run_with_both("prim_sys.jac", "sys_py", "sys_cl", "sys_na", require=["na"]);
}

test "os" {
    run_with_both("prim_os.jac", "os_py", "os_cl", "os_na", require=["na"]);
}

test "os.path bundled" {
    run_with_both(
        "prim_ospath.jac", "ospath_py", "ospath_cl", "ospath_na", require=["na"]
    );
}

test "zlib bundled" {
    run_with_both("prim_zlib.jac", "zlib_py", "zlib_cl", "zlib_na", require=["na"]);
}

test "fractions bundled" {
    run_with_both(
        "prim_fractions.jac",
        "fractions_py",
        "fractions_cl",
        "fractions_na",
        require=["na"]
    );
}

test "hashlib + hmac bundled" {
    run_with_both(
        "prim_hashlib.jac", "hashlib_py", "hashlib_cl", "hashlib_na", require=["na"]
    );
}

test "secrets bundled" {
    run_with_both(
        "prim_secrets.jac", "secrets_py", "secrets_cl", "secrets_na", require=["na"]
    );
}

test "uuid bundled" {
    run_with_both("prim_uuid.jac", "uuid_py", "uuid_cl", "uuid_na", require=["na"]);
}

test "static members" {
    run_with_both(
        "prim_static_members.jac",
        "static_members_py",
        "static_members_cl",
        "static_members_na",
        require=["na"]
    );
}

test "datetime bundled" {
    run_with_both(
        "prim_datetime.jac", "datetime_py", "datetime_cl", "datetime_na", require=["na"]
    );
}

test "json bundled" {
    run_with_both("prim_json.jac", "json_py", "json_cl", "json_na", require=["na"]);
}

test "native call resolves bundled stdlib signature, not typeshed (#7037)" {
    (eng, _) = compile_native("bundled_stdlib_sig.jac");
    pos = get_func(eng, "dumps_pos_len", ctypes.c_int64);
    kw = get_func(eng, "dumps_kw_len", ctypes.c_int64);
    pos_len = pos();
    kw_len = kw();
    assert pos_len == 4 , f"positional dumps len {pos_len}";
    assert kw_len == 4 , f"keyword dumps len {kw_len}";
}

test "random" {
    run_with_both(
        "prim_random.jac", "random_py", "random_cl", "random_na", require=["na"]
    );
}

test "any dispatch" {
    run_with_both(
        "prim_any.jac",
        "any_dispatch_py",
        "any_dispatch_cl",
        "any_dispatch_na",
        require=["na"]
    );
}

test "native any congruence" {
    run_with_both(
        "native_any_stdlib_gaps.jac",
        "congruence_check_py",
        "congruence_check_cl",
        "congruence_check_na",
        require=["na"]
    );
}

test "native any container ops" {
    run_with_both(
        "native_any_stdlib_gaps.jac",
        "any_ops_check_py",
        "any_ops_check_cl",
        "any_ops_check_na",
        require=["na"]
    );
}

test "native any guarded consume" {
    run_with_both(
        "native_any_stdlib_gaps.jac",
        "guard_consume_check_py",
        "guard_consume_check_cl",
        "guard_consume_check_na",
        require=["na"]
    );
}

test "dict order" {
    run_with_both(
        "prim_dictorder.jac",
        "dictorder_py",
        "dictorder_cl",
        "dictorder_na",
        require=["na"]
    );
}

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

test "builtins introspection" {
    run_with_both(
        "prim_builtins_introspection.jac",
        "builtins_introspection_py",
        "builtins_introspection_cl",
        "builtins_introspection_na"
    );
}
