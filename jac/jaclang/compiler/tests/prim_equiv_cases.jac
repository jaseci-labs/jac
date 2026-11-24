"""The prim equivalence case table, shared by the test_prim_equivalence*
files. Each file registers every fourth row so the cases spread over four
test workers instead of one."""
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
             "complex_ops_na",
             ["na"]
         ),
         ("cmath", "prim_cmath.jac", "cmath_py", "cmath_cl", "cmath_na", ["na"]),
         (
             "complex mixed scalar ops",
             "prim_complex_mixed.jac",
             "cmixed_py",
             "cmixed_cl",
             "cmixed_na",
             ["na"]
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
             "bytes_search_na",
             ["na"],
             ["hex", "from_hex"]
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
             "bytes constructors",
             "prim_bytearray.jac",
             "bytes_ctor_py",
             "bytes_ctor_cl",
             "bytes_ctor_na",
             ["na"]
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
         (
             "bytearray unpack",
             "prim_bytearray.jac",
             "bytearray_unpack_py",
             "bytearray_unpack_cl",
             "bytearray_unpack_na",
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
             "bundled functools",
             "prim_functools.jac",
             "functools_py",
             "functools_cl",
             "functools_na",
             ["na"],
             ["cmp_sort", "wraps_name"]
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
             "errno bundled",
             "prim_errno.jac",
             "errno_py",
             "errno_cl",
             "errno_na",
             ["na"]
         ),
         (
             "fcntl bundled",
             "prim_fcntl.jac",
             "fcntl_py",
             "fcntl_cl",
             "fcntl_na",
             ["na"]
         ),
         (
             "termios bundled",
             "prim_termios.jac",
             "termios_py",
             "termios_cl",
             "termios_na",
             ["na"]
         ),
         ("tty bundled", "prim_tty.jac", "tty_py", "tty_cl", "tty_na", ["na"]),
         (
             "select bundled",
             "prim_select.jac",
             "select_py",
             "select_cl",
             "select_na",
             ["na"]
         ),
         ("glob bundled", "prim_glob.jac", "glob_py", "glob_cl", "glob_na", ["na"]),
         ("stat bundled", "prim_stat.jac", "stat_py", "stat_cl", "stat_na", ["na"]),
         (
             "platform bundled",
             "prim_platform.jac",
             "platform_py",
             "platform_cl",
             "platform_na",
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
             "colorsys bundled",
             "prim_colorsys.jac",
             "colorsys_py",
             "colorsys_cl",
             "colorsys_na",
             ["na"]
         ),
         (
             "sched bundled",
             "prim_sched.jac",
             "sched_py",
             "sched_cl",
             "sched_na",
             ["na"]
         ),
         (
             "ipaddress bundled",
             "prim_ipaddress.jac",
             "ipaddress_py",
             "ipaddress_cl",
             "ipaddress_na",
             ["na"]
         ),
         (
             "mimetypes bundled",
             "prim_mimetypes.jac",
             "mimetypes_py",
             "mimetypes_cl",
             "mimetypes_na",
             ["na"]
         ),
         (
             "locale bundled",
             "prim_locale.jac",
             "locale_py",
             "locale_cl",
             "locale_na",
             ["na"]
         ),
         (
             "gettext bundled",
             "prim_gettext.jac",
             "gettext_py",
             "gettext_cl",
             "gettext_na",
             ["na"]
         ),
         (
             "logging bundled",
             "prim_logging.jac",
             "logging_py",
             "logging_cl",
             "logging_na",
             ["na"]
         ),
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
             "itertools bundled",
             "prim_itertools.jac",
             "itertools_py",
             "itertools_cl",
             "itertools_na",
             ["na"]
         ),
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
         (
             "sqlite3 bundled",
             "prim_sqlite3.jac",
             "sqlite3_py",
             "sqlite3_cl",
             "sqlite3_na",
             ["na"]
         ),
         (
             "string bundled",
             "prim_string.jac",
             "string_py",
             "string_cl",
             "string_na",
             ["na"]
         ),
         ("re bundled", "prim_re.jac", "re_py", "re_cl", "re_na", ["na"]),
         ("re pins bundled", "prim_re.jac", "pins_py", "pins_cl", "pins_na", ["na"]),
         (
             "re fuzz bundled",
             "prim_re_fuzz.jac",
             "re_fuzz_py",
             "re_fuzz_cl",
             "re_fuzz_na",
             ["na"]
         ),
         (
             "reprlib bundled",
             "prim_reprlib.jac",
             "reprlib_py",
             "reprlib_cl",
             "reprlib_na",
             ["na"]
         ),
         ("random", "prim_random.jac", "random_py", "random_cl", "random_na", ["na"]),
         (
             "bare from-imported stdlib names",
             "prim_from_imports.jac",
             "from_imports_py",
             "from_imports_cl",
             "from_imports_na",
             ["na"]
         ),
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
             "type identity",
             "prim_builtins_introspection.jac",
             "type_identity_py",
             "type_identity_cl",
             "builtins_introspection_na",
             ["cl"]
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
         (
             "sort key str comparator",
             "prim_sort_key.jac",
             "sort_key_py",
             "sort_key_cl",
             "sort_key_na",
             ["na"]
         ),

     ];

def equiv_case(row: tuple[any, ...]) {
    require = row[5] if len(row) > 5 else [];
    waived = row[6] if len(row) > 6 else None;
    run_with_both(
        row[1], row[2], row[3], row[4], require=require, allow_missing=waived
    );
}
