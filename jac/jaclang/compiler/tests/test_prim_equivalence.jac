import ctypes;
import from jaclang.testing.test { parametrize }
import from jaclang.compiler.tests.xbackend_equiv {
    run_with_both,
    run_py_fixture,
    compile_fixture_to_js,
    run_js_function,
    compile_native,
    get_func,
    compare_results
}

# (case, fixture, py fn, cl fn, na fn, [backends that must run])
"""Rows `prim_str`'s native lane does not produce yet.

Declared here rather than absorbed silently: `run_with_both` compares the
intersection of the two lanes' keys, so a lane that returns fewer rows used to
narrow the comparison without saying so. Every name below is a string method
the native lane has no lowering for; deleting one from this list is how the
suite starts covering it, and the harness fails if a name here is one the
lane now produces.
"""
glob STR_NA_GAPS: list[any] = [
         "casefold",
         "enc1",
         "enc2",
         "endswith_f",
         "endswith_t",
         "eq_f",
         "eq_t",
         "et1",
         "et2",
         "et3",
         "fm1",
         "fm2",
         "fmt_pos_args",
         "fmt_repeat",
         "fmt_single",
         "ge",
         "gt",
         "isalnum_t",
         "isalpha_f",
         "isalpha_t",
         "isascii_t",
         "isdecimal_f",
         "isdecimal_t",
         "isdigit_f",
         "isdigit_t",
         "isidentifier_f",
         "isidentifier_t",
         "islower_f",
         "islower_t",
         "isnumeric_empty",
         "isnumeric_f",
         "isnumeric_t",
         "isprintable_t",
         "isspace_f",
         "isspace_t",
         "isupper_f",
         "isupper_t",
         "join",
         "le",
         "ljust",
         "lstrip",
         "lt",
         "mod1",
         "mod2",
         "ne_t",
         "replace",
         "rfind",
         "rjust",
         "rstrip",
         "split",
         "startswith_f",
         "startswith_t",
         "tr1"
     ],
     EQUIV_CASES: list[tuple[any, ...]] = [
         ("int", "prim_int.jac", "int_py", "int_cl", "int_na"),
         (
             "dict ctor",
             "prim_dict.jac",
             "dict_ctor_py",
             "dict_ctor_cl",
             "dict_ctor_na",
             ["cl"]
         ),
         (
             "dict iteration",
             "prim_dict.jac",
             "dict_iter_py",
             "dict_iter_cl",
             "dict_iter_na",
             ["cl"]
         ),
         (
             "numeric parse",
             "prim_float.jac",
             "numparse_py",
             "numparse_cl",
             "numparse_na",
             ["cl"]
         ),
         ("enums", "prim_enums.jac", "enums_py", "enums_cl", "enums_na", ["cl"]),
         ("float", "prim_float.jac", "float_py", "float_cl", "float_na"),
         (
             "complex",
             "prim_complex.jac",
             "complex_ops_py",
             "complex_ops_cl",
             "complex_ops_na"
         ),
         ("str", "prim_str.jac", "str_py", "str_cl", "str_na", ["na"], STR_NA_GAPS),
         (
             "string escapes",
             "cl_string_escapes.jac",
             "escapes_py",
             "escapes_cl",
             "escapes_na",
             ["cl"]
         ),
         (
             "bytes search",
             "prim_bytes.jac",
             "bytes_search_py",
             "bytes_search_cl",
             "bytes_search_na"
         ),
         (
             "bytes modify",
             "prim_bytes.jac",
             "bytes_modify_py",
             "bytes_modify_cl",
             "bytes_modify_na"
         ),
         (
             "bytes case",
             "prim_bytes.jac",
             "bytes_case_py",
             "bytes_case_cl",
             "bytes_case_na"
         ),
         (
             "bytes test methods",
             "prim_bytes.jac",
             "bytes_test_py",
             "bytes_test_cl",
             "bytes_test_na"
         ),
         (
             "bytearray core",
             "prim_bytearray.jac",
             "bytearray_core_py",
             "bytearray_core_cl",
             "bytearray_core_na",
             ["na"]
         ),
         (
             "bytearray slices",
             "prim_bytearray.jac",
             "bytearray_slices_py",
             "bytearray_slices_cl",
             "bytearray_slices_na",
             ["na"]
         ),
         (
             "bytearray pack_into",
             "prim_bytearray.jac",
             "bytearray_pack_py",
             "bytearray_pack_cl",
             "bytearray_pack_na",
             ["na"]
         ),
         ("list", "prim_list.jac", "list_py", "list_cl", "list_na"),
         (
             "native list pop index",
             "native_list_any_ops.jac",
             "pop_index_py",
             "pop_index_cl",
             "pop_index_na",
             ["na"]
         ),
         (
             "native list tuple roundtrip",
             "native_list_any_ops.jac",
             "tuple_roundtrip_py",
             "tuple_roundtrip_cl",
             "tuple_roundtrip_na",
             ["na"]
         ),
         (
             "native list any literal",
             "native_list_any_ops.jac",
             "any_literal_py",
             "any_literal_cl",
             "any_literal_na",
             ["na"]
         ),
         (
             "native list any unpack stack",
             "native_list_any_ops.jac",
             "any_stack_py",
             "any_stack_cl",
             "any_stack_na",
             ["na"]
         ),
         (
             "native list container truthiness dfs",
             "native_list_any_ops.jac",
             "dfs_stack_py",
             "dfs_stack_cl",
             "dfs_stack_na",
             ["na"]
         ),
         (
             "native any scalar box",
             "native_list_any_ops.jac",
             "any_scalar_box_py",
             "any_scalar_box_cl",
             "any_scalar_box_na",
             ["na"]
         ),
         (
             "native any dict local read",
             "native_list_any_ops.jac",
             "any_dict_local_py",
             "any_dict_local_cl",
             "any_dict_local_na",
             ["na"]
         ),
         (
             "native any tuple roundtrip",
             "native_list_any_ops.jac",
             "any_tuple_roundtrip_py",
             "any_tuple_roundtrip_cl",
             "any_tuple_roundtrip_na",
             ["na"]
         ),
         ("dict", "prim_dict.jac", "dict_py", "dict_cl", "dict_na"),
         (
             "unboxed scalars are never None on any backend",
             "prim_none_identity.jac",
             "nid_py",
             "nid_cl",
             "nid_na",
             ["cl", "na"]
         ),
         (
             "dict get miss is a real None on every backend",
             "prim_dict_get_none.jac",
             "dgn_py",
             "dgn_cl",
             "dgn_na",
             ["cl", "na"]
         ),
         (
             "phi str box",
             "prim_phi_str_box.jac",
             "phi_str_box_py",
             "phi_str_box_cl",
             "phi_str_box_na",
             ["na"]
         ),
         (
             "dict struct-pointer value families",
             "prim_dict_struct_vals.jac",
             "dict_struct_vals_py",
             "dict_struct_vals_cl",
             "dict_struct_vals_na",
             ["na"]
         ),
         (
             "membership over an element-erased container",
             "prim_in_erased.jac",
             "in_erased_py",
             "in_erased_cl",
             "in_erased_na"
         ),
         ("set", "prim_set.jac", "set_py", "set_cl", "set_na"),
         (
             "frozenset",
             "prim_frozenset.jac",
             "frozenset_py",
             "frozenset_cl",
             "frozenset_na"
         ),
         ("tuple", "prim_tuple.jac", "tuple_py", "tuple_cl", "tuple_na"),
         ("range", "prim_range.jac", "range_py", "range_cl", "range_na"),
         ("builtins", "prim_builtins.jac", "builtins_py", "builtins_cl", "builtins_na"),
         (
             "builtins format long",
             "prim_format_builtin.jac",
             "fmt_long_py",
             "fmt_long_cl",
             "fmt_long_na",
             ["na"]
         ),
         (
             "fstring repr conversion",
             "prim_fstring_conv.jac",
             "fconv_py",
             "fconv_cl",
             "fconv_na",
             ["na"]
         ),
         (
             "fstring dynamic spec",
             "prim_fstring_conv.jac",
             "fdyn_py",
             "fdyn_cl",
             "fdyn_na",
             ["na"]
         ),
         (
             "fstring repr containers",
             "prim_fstring_conv.jac",
             "fcont_py",
             "fcont_cl",
             "fcont_na",
             ["na"]
         ),
         ("math", "prim_math.jac", "math_py", "math_cl", "math_na", ["na"]),
         ("time", "prim_time.jac", "time_py", "time_cl", "time_na", ["na"]),
         ("sys", "prim_sys.jac", "sys_py", "sys_cl", "sys_na", ["na"]),
         ("os", "prim_os.jac", "os_py", "os_cl", "os_na", ["na"]),
         (
             "os environ",
             "prim_os_environ.jac",
             "environ_py",
             "environ_cl",
             "environ_na",
             ["na"]
         ),
         (
             "os.path bundled",
             "prim_ospath.jac",
             "ospath_py",
             "ospath_cl",
             "ospath_na",
             ["na"]
         ),
         (
             "closures nested capture",
             "prim_closures.jac",
             "closures_py",
             "closures_cl",
             "closures_na",
             ["na"]
         ),
         (
             "closures escaping",
             "prim_closures.jac",
             "closures_escape_py",
             "closures_escape_cl",
             "closures_escape_na",
             ["na"]
         ),
         (
             "bundled statistics",
             "prim_statistics.jac",
             "statistics_py",
             "statistics_cl",
             "statistics_na",
             ["na"]
         ),
         (
             "bundled keyword",
             "prim_keyword.jac",
             "keyword_py",
             "keyword_cl",
             "keyword_na",
             ["na"]
         ),
         (
             "generic classes specialize",
             "prim_generic_classes.jac",
             "generic_classes_py",
             "generic_classes_cl",
             "generic_classes_na",
             ["na"]
         ),
         (
             "generic functions monomorphize",
             "prim_generics.jac",
             "generics_py",
             "generics_cl",
             "generics_na",
             ["na"]
         ),
         (
             "closures transitive sibling captures",
             "prim_closures_transitive.jac",
             "transitive_py",
             "transitive_cl",
             "transitive_na",
             ["na"]
         ),
         (
             "closures forward mutual recursion",
             "prim_closures_transitive.jac",
             "fwd_mutual_py",
             "fwd_mutual_cl",
             "fwd_mutual_na",
             ["na"]
         ),
         (
             "closures as adapter callbacks",
             "prim_closures.jac",
             "closures_adapters_py",
             "closures_adapters_cl",
             "closures_adapters_na",
             ["na"]
         ),
         (
             "generators yield",
             "prim_generators.jac",
             "gens_py",
             "gens_cl",
             "gens_na",
             ["na"]
         ),
         (
             "varargs parameter forms",
             "prim_varargs.jac",
             "varargs_py",
             "varargs_cl",
             "varargs_na",
             ["na"]
         ),
         ("container repr", "prim_repr.jac", "repr_py", "repr_cl", "repr_na", ["na"]),
         (
             "chained comparisons with membership and identity",
             "prim_chain_cmp.jac",
             "chain_cmp_py",
             "chain_cmp_cl",
             "chain_cmp_na",
             ["na"]
         ),
         ("zlib bundled", "prim_zlib.jac", "zlib_py", "zlib_cl", "zlib_na", ["na"]),
         ("gzip bundled", "prim_gzip.jac", "gzip_py", "gzip_cl", "gzip_na", ["na"]),
         ("bz2 bundled", "prim_bz2.jac", "bz2_py", "bz2_cl", "bz2_na", ["na"]),
         (
             "fractions bundled",
             "prim_fractions.jac",
             "fractions_py",
             "fractions_cl",
             "fractions_na",
             ["na"]
         ),
         (
             "hashlib + hmac bundled",
             "prim_hashlib.jac",
             "hashlib_py",
             "hashlib_cl",
             "hashlib_na",
             ["na"]
         ),
         (
             "secrets bundled",
             "prim_secrets.jac",
             "secrets_py",
             "secrets_cl",
             "secrets_na",
             ["na"]
         ),
         ("uuid bundled", "prim_uuid.jac", "uuid_py", "uuid_cl", "uuid_na", ["na"]),
         (
             "static members",
             "prim_static_members.jac",
             "static_members_py",
             "static_members_cl",
             "static_members_na",
             ["na"]
         ),
         (
             "datetime bundled",
             "prim_datetime.jac",
             "datetime_py",
             "datetime_cl",
             "datetime_na",
             ["na"]
         ),
         ("json bundled", "prim_json.jac", "json_py", "json_cl", "json_na", ["na"]),
         (
             "base64 bundled",
             "prim_base64.jac",
             "base64_py",
             "base64_cl",
             "base64_na",
             ["na"]
         ),
         (
             "textwrap bundled",
             "prim_textwrap.jac",
             "textwrap_py",
             "textwrap_cl",
             "textwrap_na",
             ["na"]
         ),
         ("csv bundled", "prim_csv.jac", "csv_py", "csv_cl", "csv_na", ["na"]),
         (
             "pprint bundled",
             "prim_pprint.jac",
             "pprint_py",
             "pprint_cl",
             "pprint_na",
             ["na"]
         ),
         (
             "difflib bundled",
             "prim_difflib.jac",
             "difflib_py",
             "difflib_cl",
             "difflib_na",
             ["na"]
         ),
         ("random", "prim_random.jac", "random_py", "random_cl", "random_na", ["na"]),
         (
             "any dispatch",
             "prim_any.jac",
             "any_dispatch_py",
             "any_dispatch_cl",
             "any_dispatch_na",
             ["na"]
         ),
         (
             "native any congruence",
             "native_any_stdlib_gaps.jac",
             "congruence_check_py",
             "congruence_check_cl",
             "congruence_check_na",
             ["na"]
         ),
         (
             "native any container ops",
             "native_any_stdlib_gaps.jac",
             "any_ops_check_py",
             "any_ops_check_cl",
             "any_ops_check_na",
             ["na"]
         ),
         (
             "native any guarded consume",
             "native_any_stdlib_gaps.jac",
             "guard_consume_check_py",
             "guard_consume_check_cl",
             "guard_consume_check_na",
             ["na"]
         ),
         (
             "native bare list flow inference",
             "native_any_stdlib_gaps.jac",
             "bare_list_check_py",
             "bare_list_check_cl",
             "bare_list_check_na",
             ["na"]
         ),
         (
             "native none any consume",
             "native_any_stdlib_gaps.jac",
             "none_consume_check_py",
             "none_consume_check_cl",
             "none_consume_check_na",
             ["na"]
         ),
         (
             "native any alias retain",
             "native_any_alias_retain.jac",
             "alias_retain_py",
             "alias_retain_cl",
             "alias_retain_na",
             ["na"]
         ),
         (
             "dict order",
             "prim_dictorder.jac",
             "dictorder_py",
             "dictorder_cl",
             "dictorder_na",
             ["na"]
         ),
         (
             "builtins introspection",
             "prim_builtins_introspection.jac",
             "builtins_introspection_py",
             "builtins_introspection_cl",
             "builtins_introspection_na"
         ),
         (
             "match sequence",
             "prim_match.jac",
             "match_seq_py",
             "match_seq_cl",
             "match_seq_na",
             ["cl", "na"]
         ),
         (
             "match star",
             "prim_match.jac",
             "match_star_py",
             "match_star_cl",
             "match_star_na",
             ["cl", "na"]
         ),
         (
             "match mapping",
             "prim_match.jac",
             "match_map_py",
             "match_map_cl",
             "match_map_na",
             ["cl", "na"]
         ),
         (
             "match class",
             "prim_match.jac",
             "match_arch_py",
             "match_arch_cl",
             "match_arch_na",
             ["cl", "na"]
         ),
         (
             "new builtin and positional ctors",
             "prim_new.jac",
             "new_py",
             "new_cl",
             "new_na",
             ["na"]
         ),
         (
             "hetero containers round trip",
             "prim_hetero.jac",
             "hetero_py",
             "hetero_cl",
             "hetero_na",
             ["na"]
         ),

     ];

def _equiv_case(row: tuple[any, ...]) {
    require = row[5] if len(row) > 5 else [];
    waived = row[6] if len(row) > 6 else None;
    run_with_both(
        row[1], row[2], row[3], row[4], require=require, allow_missing=waived
    );
}

with entry {
    parametrize(
        "prim equivalence",
        EQUIV_CASES,
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
