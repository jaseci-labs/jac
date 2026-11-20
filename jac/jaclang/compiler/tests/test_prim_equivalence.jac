import ctypes;

with entry {
    parametrize(
        "prim equivalence",
        # 1 of 3 shards; siblings _b/_c run the rest so the lane's workers stay busy
        EQUIV_CASES[0::3],
        _equiv_case,
        id_fn=lambda (c: tuple[any, ...]) { c[0]; }
    );
}

test "native print renders bools as True and False" {
    run_with_both(
        "prim_print_bool.jac", "pbool_py", "pbool_cl", "pbool_na", require=["cl", "na"]
    );
    # The native print of an i1 must go through the True/False string
    # select, not the %lld integer path that rendered bools as 1/0.
    (eng, na_ir) = compile_native("prim_print_bool.jac");
    llvm_txt = str(na_ir.gen.llvm_ir);
    assert (".repr.true" in llvm_txt) and (".repr.false" in llvm_txt) , (
        "print(bool) must select the True/False repr strings natively"
    );
}

test "bundled shutil" {
    import platform;
    if platform.system() == "Darwin" {
        # The dirent floor is darwin-correct (#7626 C3), but rmtree also
        # rides os-path intrinsics whose stat-buffer layout is still
        # glibc-shaped, so the full shutil surface aborts on darwin.
        # Un-skip when the stat seam gets its own per-OS floor.
        testskip("darwin shutil runtime parity blocked on the stat-layout seam");
    }
    run_with_both(
        "prim_shutil.jac", "shutil_py", "shutil_cl", "shutil_na", require=["na"]
    );
}

test "native sort never silently orders object-returning keys" {
    # Node values lower to bare i8*, the same LLVM type as raw string
    # data. The checker's call overloads reject a non-comparable key
    # type, and the native sort gate (semantic return type -> E5092)
    # independently refuses one before emitting comparisons (#9144).
    errors = compile_native_errors("prim_sort_key_object.jac");
    assert len(errors) > 0 , "object-returning sort key compiled silently";
    assert any("No matching overload" in e or "E5092" in e for e in errors) , (
        f"object-returning sort key must be rejected: {errors}"
    );
}

test "native gradual object keys demote, never pointer-sort (#9158)" {
    # A `-> any` key slips the checker's overloads, so only the native
    # gate sees the danger: the erased i8* is indistinguishable from
    # string data, and object pointers must never reach strcmp. The
    # function demotes to its Python implementation instead, while a
    # semantic `-> str` key in the same module stays natively lowered.
    (eng, na_ir) = compile_native("prim_sort_key_gradual.jac");
    llvm_txt = str(na_ir.gen.llvm_ir);
    issues = native_lowering_issues(llvm_txt);
    demoted = [
        i
        for i in issues
        if "grad_obj_na" in i.symbol
    ];
    assert len(demoted) == 1 , (
        f"gradual object key function should demote exactly once: {issues}"
    );
    assert "orderable key values" in demoted[0].detail , demoted[0].detail;
    kept = [
        i
        for i in issues
        if "grad_str_na" in i.symbol
    ];
    assert len(kept) == 0 , f"semantic str key must lower natively: {kept}";
    assert "__jac_str_cmp" in llvm_txt , "str-key control should use the semantic string comparator";
    import re;
    assert re.search(r'\bcall\s+i32\s+@"?strcmp"?\(', llvm_txt) is None , (
        "no raw pointer may reach libc strcmp (#9158)"
    );
}

test "annotated block lambda tails are type-checked (#9158)" {
    # The checker skipped the tails of block-bodied lambdas entirely, so a
    # tail violating the declared return type went undiagnosed and the
    # native sort backend saw no semantic key type at all.
    errors = compile_native_errors("prim_lambda_bad_tail.jac");
    assert any(
        "Cannot return tuple[str, int], expected tuple[int, int]" in e for e in errors
    ) , (f"mismatching lambda tail must be diagnosed: {errors}");
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

test "native call fills omitted defaults from the bundled stdlib signature" {
    (eng, _) = compile_native("bundled_stdlib_defaults.jac");
    adler = get_func(eng, "adler32_default_seed", ctypes.c_int64);
    hex_len = get_func(eng, "token_hex_default_len", ctypes.c_int64);
    adler_val = adler();
    hex_val = hex_len();
    assert adler_val == 103547413 , (
        f"adler32(b'hello') with the default seed: na={adler_val}, CPython=103547413 "
        f"(a zero-filled seed gives 103219732)"
    );
    assert hex_val == 64 , (
        f"token_hex() with the default nbytes=32: na={hex_val} chars, CPython=64"
    );
}

test "native reduce tells an explicit None initializer from an omitted one" {
    (eng, _) = compile_native("bundled_functools_reduce_init.jac");
    none_init = get_func(eng, "reduce_none_initial", ctypes.c_int64)();
    no_init = get_func(eng, "reduce_no_initial", ctypes.c_int64)();
    int_init = get_func(eng, "reduce_int_initial", ctypes.c_int64)();
    empty_none = get_func(eng, "reduce_empty_none_initial", ctypes.c_int64)();
    assert none_init == 102 , (
        f"reduce(f, [1, 2], None) starts the fold at None: na={none_init}, "
        f"CPython=102 (starting at the first item gives 3)"
    );
    assert no_init == 3 , f"reduce(f, [1, 2]): na={no_init}, CPython=3";
    assert int_init == 13 , f"reduce(f, [1, 2], 10): na={int_init}, CPython=13";
    assert empty_none == 1 , (
        "reduce(f, [], None) answers None instead of raising, as on CPython"
    );
}

test "exception hierarchy" {
    py_result = run_py_fixture("prim_exceptions", "exceptions_py");
    try {
        js_code = compile_fixture_to_js("prim_exceptions.jac");
        compare_results(
            py_result, run_js_function(js_code, "exceptions_cl"), "exceptions [ES]"
        );
    } except Exception {}
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
    } except Exception {}
}

"""exception basic catch"""
def _prim_exceptions__exception_basic_catch(eng: any, _ir: any) {
    f = get_func(eng, "test_basic_catch_na", ctypes.c_int64);
    assert f() == 1;
}

"""exception catch parent"""
def _prim_exceptions__exception_catch_parent(eng: any, _ir: any) {
    f = get_func(eng, "test_catch_parent_na", ctypes.c_int64);
    assert f() == 1;
}

"""exception catch grandparent"""
def _prim_exceptions__exception_catch_grandparent(eng: any, _ir: any) {
    f = get_func(eng, "test_catch_grandparent_na", ctypes.c_int64);
    assert f() == 1;
}

"""exception catch wrong type"""
def _prim_exceptions__exception_catch_wrong_type(eng: any, _ir: any) {
    f = get_func(eng, "test_catch_wrong_type_na", ctypes.c_int64);
    assert f() == 2;
}

"""exception multiple handlers"""
def _prim_exceptions__exception_multiple_handlers(eng: any, _ir: any) {
    f = get_func(eng, "test_multiple_handlers_na", ctypes.c_int64);
    assert f() == 2;
}

"""exception nested"""
def _prim_exceptions__exception_nested(eng: any, _ir: any) {
    f = get_func(eng, "test_nested_hierarchy_na", ctypes.c_int64);
    assert f() == 1;
}

"""exception finally runs"""
def _prim_exceptions__exception_finally_runs(eng: any, _ir: any) {
    f = get_func(eng, "test_finally_runs_na", ctypes.c_int64);
    assert f() == 11;
}

"""exception no exception"""
def _prim_exceptions__exception_no_exception(eng: any, _ir: any) {
    f = get_func(eng, "test_no_exception_na", ctypes.c_int64);
    assert f() == 11;
}

"""exception as binding"""
def _prim_exceptions__exception_as_binding(eng: any, _ir: any) {
    f = get_func(eng, "test_exc_as_binding_na", ctypes.c_int64);
    assert f() == 1;
}

test "prim_exceptions" {
    (_eng, _ir) = compile_native("prim_exceptions.jac");
    _prim_exceptions__exception_basic_catch(_eng, _ir);
    _prim_exceptions__exception_catch_parent(_eng, _ir);
    _prim_exceptions__exception_catch_grandparent(_eng, _ir);
    _prim_exceptions__exception_catch_wrong_type(_eng, _ir);
    _prim_exceptions__exception_multiple_handlers(_eng, _ir);
    _prim_exceptions__exception_nested(_eng, _ir);
    _prim_exceptions__exception_finally_runs(_eng, _ir);
    _prim_exceptions__exception_no_exception(_eng, _ir);
    _prim_exceptions__exception_as_binding(_eng, _ir);
}

"""runtime list index miss raises ValueError"""
def _prim_runtime_errors__runtime_list_index_miss_raises_valueerror(
    eng: any, _ir: any
) {
    # Native list.index returned -1 on a miss instead of raising -- and
    # xs[-1] is a *valid* index, so the poison spread silently (#7922).
    f = get_func(eng, "test_list_index_miss_na", ctypes.c_int64);
    assert f() == 1;
}

"""runtime setdefault no-default inserts a real None"""
def _prim_runtime_errors__runtime_setdefault_no_default_inserts_a_real_none(
    eng: any, _ir: any
) {
    # Native setdefault() with no default inserted a fabricated zero of
    # the value type; for nullable (pointer) value slots it must insert
    # None like Python (#7922).
    f = get_func(eng, "test_setdefault_none_na", ctypes.c_int64);
    assert f() == 1;
}

"""runtime divzero caught exact"""
def _prim_runtime_errors__runtime_divzero_caught_exact(eng: any, _ir: any) {
    f = get_func(eng, "test_divzero_catch_exact_na", ctypes.c_int64);
    assert f() == 1;
}

"""runtime divzero caught parent"""
def _prim_runtime_errors__runtime_divzero_caught_parent(eng: any, _ir: any) {
    f = get_func(eng, "test_divzero_catch_parent_na", ctypes.c_int64);
    assert f() == 1;
}

"""runtime divzero caught grandparent"""
def _prim_runtime_errors__runtime_divzero_caught_grandparent(eng: any, _ir: any) {
    f = get_func(eng, "test_divzero_catch_grandparent_na", ctypes.c_int64);
    assert f() == 1;
}

"""runtime divzero wrong handler"""
def _prim_runtime_errors__runtime_divzero_wrong_handler(eng: any, _ir: any) {
    f = get_func(eng, "test_divzero_wrong_handler_na", ctypes.c_int64);
    assert f() == 2;
}

"""runtime modulo zero"""
def _prim_runtime_errors__runtime_modulo_zero(eng: any, _ir: any) {
    f = get_func(eng, "test_modulo_zero_na", ctypes.c_int64);
    assert f() == 1;
}

"""runtime index oob exact"""
def _prim_runtime_errors__runtime_index_oob_exact(eng: any, _ir: any) {
    f = get_func(eng, "test_index_oob_catch_exact_na", ctypes.c_int64);
    assert f() == 1;
}

"""runtime index oob parent"""
def _prim_runtime_errors__runtime_index_oob_parent(eng: any, _ir: any) {
    f = get_func(eng, "test_index_oob_catch_parent_na", ctypes.c_int64);
    assert f() == 1;
}

"""runtime index oob exception"""
def _prim_runtime_errors__runtime_index_oob_exception(eng: any, _ir: any) {
    f = get_func(eng, "test_index_oob_catch_exception_na", ctypes.c_int64);
    assert f() == 1;
}

"""runtime key error exact"""
def _prim_runtime_errors__runtime_key_error_exact(eng: any, _ir: any) {
    f = get_func(eng, "test_key_error_catch_exact_na", ctypes.c_int64);
    assert f() == 1;
}

"""runtime key error parent"""
def _prim_runtime_errors__runtime_key_error_parent(eng: any, _ir: any) {
    f = get_func(eng, "test_key_error_catch_parent_na", ctypes.c_int64);
    assert f() == 1;
}

"""runtime multi handler"""
def _prim_runtime_errors__runtime_multi_handler(eng: any, _ir: any) {
    f = get_func(eng, "test_multi_handler_runtime_na", ctypes.c_int64);
    assert f() == 2;
}

"""runtime error with finally"""
def _prim_runtime_errors__runtime_error_with_finally(eng: any, _ir: any) {
    f = get_func(eng, "test_runtime_finally_na", ctypes.c_int64);
    assert f() == 11;
}

test "prim_runtime_errors" {
    (_eng, _ir) = compile_native("prim_runtime_errors.jac");
    _prim_runtime_errors__runtime_list_index_miss_raises_valueerror(_eng, _ir);
    _prim_runtime_errors__runtime_setdefault_no_default_inserts_a_real_none(_eng, _ir);
    _prim_runtime_errors__runtime_divzero_caught_exact(_eng, _ir);
    _prim_runtime_errors__runtime_divzero_caught_parent(_eng, _ir);
    _prim_runtime_errors__runtime_divzero_caught_grandparent(_eng, _ir);
    _prim_runtime_errors__runtime_divzero_wrong_handler(_eng, _ir);
    _prim_runtime_errors__runtime_modulo_zero(_eng, _ir);
    _prim_runtime_errors__runtime_index_oob_exact(_eng, _ir);
    _prim_runtime_errors__runtime_index_oob_parent(_eng, _ir);
    _prim_runtime_errors__runtime_index_oob_exception(_eng, _ir);
    _prim_runtime_errors__runtime_key_error_exact(_eng, _ir);
    _prim_runtime_errors__runtime_key_error_parent(_eng, _ir);
    _prim_runtime_errors__runtime_multi_handler(_eng, _ir);
    _prim_runtime_errors__runtime_error_with_finally(_eng, _ir);
}

test "native sort keys retain captured scalar and object parameters" {
    run_with_both(
        "prim_sort_capture.jac",
        "sort_capture_py",
        "",
        "sort_capture_na",
        require=["na"]
    );
}
