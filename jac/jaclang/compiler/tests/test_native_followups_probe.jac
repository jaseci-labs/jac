import os;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.tests.xbackend_equiv {
    _fixture_shadow_dir,
    compare_results,
    remember_engine_unit,
    run_native_function,
    run_py_fixture
}

glob PROBES: list[tuple[str, list[tuple[str, str, str]]]] = [
         ("prim_int.jac", [("int", "int_py", "int_na")]),
         (
             "prim_float.jac",
             [
                 ("float", "float_py", "float_na"),
                 ("numparse", "numparse_py", "numparse_na")
             ]
         ),
         ("prim_list.jac", [("list", "list_py", "list_na")]),
         (
             "prim_dict.jac",
             [
                 ("dict", "dict_py", "dict_na"),
                 ("dict ctor", "dict_ctor_py", "dict_ctor_na"),
                 ("dict iteration", "dict_iter_py", "dict_iter_na")
             ]
         ),
         ("prim_frozenset.jac", [("frozenset", "frozenset_py", "frozenset_na")]),
         ("prim_tuple.jac", [("tuple", "tuple_py", "tuple_na")]),
         ("prim_range.jac", [("range", "range_py", "range_na")]),
         ("prim_builtins.jac", [("builtins", "builtins_py", "builtins_na")]),
         (
             "prim_builtins_introspection.jac",
             [
                 (
                     "builtins introspection",
                     "builtins_introspection_py",
                     "builtins_introspection_na"
                 )
             ]
         ),
         (
             "prim_bytes.jac",
             [
                 ("bytes modify", "bytes_modify_py", "bytes_modify_na"),
                 ("bytes case", "bytes_case_py", "bytes_case_na"),
                 ("bytes test methods", "bytes_test_py", "bytes_test_na")
             ]
         )
     ];

def clip(text: str, limit: int = 600) -> str;

def probe_fixture(fixture: str, rows: list[tuple[str, str, str]]) -> list[str];

def probe_report -> str;

test "native followups probe" {
    summary = probe_report();
    assert False , "\n" + summary;
}
