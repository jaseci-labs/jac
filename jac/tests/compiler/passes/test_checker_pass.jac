"""Type checker pass tests -- migrated from test_checker_pass.py."""

import os;
import from pathlib { Path }
import from tests.support { JAC_ROOT }
import jaclang;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.testing.test { parametrize }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "passes", "fixtures"),
     CHECKER_FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "fixtures", "checker"
     ),
     LANG_FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures"),
     NO_TC = CompileOptions(default_codespace='server');

def assert_error_pretty_found(needle: str, haystack: str) {
    for line in [
        line.strip()
        for line in needle.splitlines()
        if line.strip()
    ] {
        assert line in haystack , f"Expected line '{line}' not found in:\n{haystack}";
    }
}

# (case, fixture dir, fixture, expected error count, skip type-check, pretty checks)
# `pretty checks` are (error index, expected pretty_print excerpt) pairs. These
# 103 cases were one hand-written test each; the body was always the same four
# steps, so it is a table and `parametrize` still registers a named test per row.
glob CHECKER_DIRS: dict[(str, str)] = {
         "checker": CHECKER_FIXTURES,
         "main": FIXTURES,
         "lang": LANG_FIXTURES
     },
     CHECKER_CASES: list[tuple] = [
         (
             "explicit_type_annotation_in_assignment",
             "main",
             "type_annotation_assignment.jac",
             2,
             False,
             [
                 (
                     0,
                     """
        glob should_fail1: int = "foo";
             ^^^^^^^^^^^^^^^^^^^^^^^^^
    """
                 ),
                 (
                     1,
                     """
        glob should_fail2: str = 42;
             ^^^^^^^^^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "list_assignment_to_int",
             "checker",
             "checker_list_assignment.jac",
             1,
             True,
             [
                 (
                     0,
                     """
        foo = [1,2,3];  # <-- Error
        ^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "float_types",
             "checker",
             "checker_float.jac",
             1,
             True,
             [
                 (
                     0,
                     """
        f: float = pi;  # <-- OK
        s: str = pi;  # <-- Error
        ^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "infer_type_of_assignment",
             "main",
             "infer_type_assignment.jac",
             1,
             True,
             [
                 (
                     0,
                     """
      assigning_to_str: str = some_int_inferred;
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "bug_in_walker_ability",
             "checker",
             "checker_bug_return_in_walker_ability.jac",
             0,
             True,
             []
         ),
         (
             "member_access_type_resolve",
             "main",
             "member_access_type_resolve.jac",
             1,
             True,
             [(0, """
      s: str = f.bar.baz;
      ^^^^^^^^^^^^^^^^^^^
    """)]
         ),
         (
             "member_access_type_infered",
             "main",
             "member_access_type_inferred.jac",
             1,
             True,
             [(0, """
      s = f.bar;
      ^^^^^^^^^
    """)]
         ),
         (
             "inherited_symbol",
             "checker",
             "checker_sym_inherit.jac",
             1,
             True,
             [
                 (
                     0,
                     """
      c.val = 42;  # <-- Ok
      c.val = "str";  # <-- Error
      ^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "import_symbol_type_infer",
             "main",
             "import_symbol_type_infer.jac",
             1,
             True,
             [
                 (
                     0,
                     """
        i: int = m.sys.prefix;
        ^^^^^^^^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "from_import",
             "checker",
             "checker_importer.jac",
             1,
             True,
             [(0, """
      glob s: str = alias;
           ^^^^^^^^^^^^^^
    """)]
         ),
         (
             "call_expr",
             "checker",
             "checker_expr_call.jac",
             1,
             True,
             [(0, """
      s: str = foo();
      ^^^^^^^^^^^^^^
    """)]
         ),
         (
             "call_expr_magic",
             "checker",
             "checker_magic_call.jac",
             1,
             True,
             [
                 (
                     0,
                     """
        b: Bar = fn()();  # <-- Ok
        f: Foo = fn()();  # <-- Error
        ^^^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "arity",
             "checker",
             "checker_arity.jac",
             3,
             True,
             [
                 (
                     0,
                     """
        f.first_is_self(f);  # <-- Error
                        ^
    """
                 ),
                 (
                     1,
                     """
        f.with_default_args(1, 2, 3);  # <-- Error
                                  ^
    """
                 ),
                 (
                     2,
                     """
        f.with_default_args();  # <-- Error
        ^^^^^^^^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "param_types",
             "checker",
             "checker_param_types.jac",
             1,
             True,
             [
                 (
                     0,
                     """
        foo(A());  # <-- Ok
        foo(B());  # <-- Error
            ^^^
    """
                 )
             ]
         ),
         (
             "self_type_inference",
             "checker",
             "checker_self_type.jac",
             1,
             True,
             [
                 (
                     0,
                     """
      x: str = self.i;  # <-- Error
      ^^^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "binary_op",
             "checker",
             "checker_binary_op.jac",
             2,
             True,
             [
                 (
                     0,
                     """
        r2: A = a + a,  # <-- Error
        ^^^^^^^^^^^^^
    """
                 ),
                 (
                     1,
                     """
        r4: str = (a + a) * B(),  # <-- Error
        ^^^^^^^^^^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "checker_call_expr_class",
             "checker",
             "checker_call_expr_class.jac",
             1,
             True,
             [
                 (
                     0,
                     """
        inst.i = 'str';  # <-- Error
        ^^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         ("type_ref_resolution", "checker", "checker_type_ref.jac", 0, True, []),
         (
             "checker_mod_path",
             "checker",
             "checker_mod_path.jac",
             1,
             True,
             [
                 (
                     0,
                     """
        a: int = os.path;  # <-- Error
        ^^^^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "checker_cat_is_animal",
             "checker",
             "checker_cat_is_animal.jac",
             1,
             True,
             [
                 (
                     0,
                     """
        animal_func(cat);  # <-- Ok
        animal_func(lion);  # <-- Ok
        animal_func(not_animal);  # <-- Error
                    ^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "checker_react_router_props",
             "checker",
             "checker_react_router_props.jac",
             0,
             True,
             []
         ),
         ("cyclic_symbol", "checker", "checker_cyclic_symbol.jac", 0, True, []),
         (
             "get_type_of_iife_expression",
             "checker",
             "checker_iife_expression.jac",
             1,
             True,
             []
         ),
         ("connect_typed", "checker", "checker_connect_typed.jac", 3, True, []),
         ("connect_any_type", "checker", "checker_connect_any_type.jac", 0, True, []),
         (
             "connect_node_collection",
             "checker",
             "checker_connect_node_collection.jac",
             0,
             True,
             []
         ),
         (
             "union_reassignment",
             "checker",
             "checker_union_reassignment.jac",
             3,
             True,
             [
                 (0, """
        fb = 42;  # <-- Error
        ^^^^^^^^
    """),
                 (1, """
        a = "";  # <-- Error
        ^^^^^^^
    """),
                 (2, """
        a = Foo();  # <-- Error
        ^^^^^^^^^^
    """)
             ]
         ),
         (
             "unannotated_reassignment_frozen",
             "checker",
             "checker_none_sentinel_reassignment.jac",
             3,
             True,
             [
                 (
                     0,
                     """
        typed_binding = 99;  # <-- Error
        ^^^^^^^^^^^^^^^^^^^
    """
                 ),
                 (1, """
        strict = 7;  # <-- Error
        ^^^^^^^^^^^
    """),
                 (
                     2,
                     """
        count = "bad";  # <-- Error
        ^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "protocol",
             "checker",
             "checker_protocol.jac",
             2,
             True,
             [
                 (0, """
        len(Foo());  # <-- Error
            ^^^^^
    """),
                 (1, """
        run(Foo());  # <-- Error
            ^^^^^
    """)
             ]
         ),
         ("datetime_now", "checker", "checker_datetime_now.jac", 0, True, []),
         (
             "any_type_works_with_any_type",
             "checker",
             "checker_any_type_works.jac",
             0,
             True,
             []
         ),
         (
             "jac any keyword works as annotation",
             "checker",
             "checker_jac_any_keyword_annotation.jac",
             1,
             True,
             [
                 (
                     0,
                     """
        builtin_any_bad: str = `any([0]);  # Error: Python any() returns bool.
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "dict_pop",
             "checker",
             "checker_dict_pop.jac",
             3,
             True,
             [
                 (
                     0,
                     """
        d.pop(); # <-- Error: Missing argument
        ^^^^^^^
    """
                 ),
                 (
                     1,
                     """
        d.pop(1); # <-- Error: Key type mismatch
              ^
    """
                 ),
                 (
                     2,
                     """
        d.pop("key", 1, 2); # <-- Error: Too many arguments
        ^^^^^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "final_type_checking",
             "checker",
             "checker_final.jac",
             1,
             True,
             [
                 (
                     0,
                     """
        z: str = x; # <-- Error: incompatible types
        ^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "list_iteration_type_checking",
             "checker",
             "checker_list_iteration.jac",
             1,
             True,
             [(0, """
        y: str = i;  # <-- Error
        ^^^^^^^^^^^
    """)]
         ),
         ("object_type_assignment", "lang", "object_type_assignment.jac", 0, True, []),
         (
             "builtin_constructors",
             "checker",
             "checker_builtin_constructors.jac",
             0,
             True,
             []
         ),
         (
             "union_type_annotation",
             "checker",
             "checker_union_type_annotation.jac",
             1,
             True,
             [
                 (
                     0,
                     """
        a: int | None = get_int_or_str();  # <-- Error: int | str is not subset of int | None
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "union_callable_member",
             "checker",
             "checker_union_callable_member.jac",
             0,
             True,
             []
         ),
         ("union_never_arm", "checker", "checker_union_never_arm.jac", 0, True, []),
         (
             "union_member_access",
             "checker",
             "checker_union_member_access.jac",
             1,
             True,
             [
                 (
                     0,
                     """
        return x.legs;  # <-- Error: Bird doesn't have .legs
                 ^^^^
    """
                 )
             ]
         ),
         ("list_indexing", "checker", "checker_list_indexing.jac", 0, True, []),
         ("range_function", "checker", "checker_range.jac", 0, True, []),
         (
             "slice_type_checking",
             "checker",
             "checker_slice.jac",
             1,
             True,
             [
                 (
                     0,
                     """
        z: int = x[0:2];  # <-- Error
        ^^^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "numeric_type_promotion",
             "checker",
             "checker_numeric_promotion.jac",
             3,
             True,
             [
                 (
                     0,
                     """
        err1: int = 1 + 2.0;  # <-- Error: float cannot be assigned to int
        ^^^^^^^^^^^^^^^^^^^^
    """
                 ),
                 (
                     1,
                     """
        err2: int = 4 / 2;    # <-- Error: division always returns float
        ^^^^^^^^^^^^^^^^^^
    """
                 ),
                 (
                     2,
                     """
        err3: int = 2.0 * 3;  # <-- Error: float cannot be assigned to int
        ^^^^^^^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "property_type_checking",
             "checker",
             "checker_property.jac",
             6,
             True,
             [
                 (
                     0,
                     """
        wrong: str = foo.bar;  # <-- Error (int assigned to str)
    """
                 ),
                 (
                     1,
                     """
        wrong_name: int = foo.name;  # <-- Error (str assigned to int)
    """
                 ),
                 (
                     2,
                     """
        wrong_cached: int = foo.cached_val;  # <-- Error (str assigned to int)
    """
                 ),
                 (
                     3,
                     """
        method: int = foo.regular_method;  # <-- Error (FunctionType assigned to int)
    """
                 ),
                 (
                     4,
                     """
        wrong_val: str = bar_obj.value;  # <-- Error (int assigned to str)
    """
                 ),
                 (
                     5,
                     """
        wrong_cached_num: str = bar_obj.cached_num;  # <-- Error (int assigned to str)
    """
                 )
             ]
         ),
         (
             "property_self_return_type_resolution",
             "checker",
             "checker_property_self_return.jac",
             2,
             True,
             [
                 (
                     0,
                     """
        wrong: int = p.parent;  # <-- Error (Path assigned to int)
    """
                 ),
                 (
                     1,
                     """
        wrong_chained: int = p.parent.parent;  # <-- Error (Path assigned to int)
    """
                 )
             ]
         ),
         (
             "property_cfg_narrowing",
             "checker",
             "checker_property_narrowing.jac",
             0,
             True,
             []
         ),
         ("expr_narrowing", "checker", "checker_expr_narrowing.jac", 0, True, []),
         (
             "reassign_in_branch",
             "checker",
             "checker_reassign_in_branch.jac",
             0,
             True,
             []
         ),
         (
             "impl_body_global_reassignment_keeps_declared_type",
             "checker",
             "checker_impl_global_reassign.jac",
             0,
             True,
             []
         ),
         (
             "super_init_with_has_vars",
             "checker",
             "checker_super_init_has_vars.jac",
             3,
             True,
             [
                 (0, """Cannot assign int to parameter 'shape_type' of type str"""),
                 (1, """Too many positional arguments"""),
                 (
                     2,
                     """Not all required parameters were provided in the function call: 'shape_type'"""
                 )
             ]
         ),
         (
             "super_init_with_explicit_init",
             "checker",
             "checker_super_init_explicit.jac",
             4,
             True,
             [
                 (0, """Cannot assign int to parameter 'name' of type str"""),
                 (
                     1,
                     """Cannot assign Literal["five"] to parameter 'age' of type int"""
                 ),
                 (
                     2,
                     """Not all required parameters were provided in the function call: 'skill'"""
                 ),
                 (3, """Cannot assign int to parameter 'owner' of type str""")
             ]
         ),
         (
             "nested_functions_in_impl_blocks",
             "checker",
             "checker_nested_impldef.jac",
             0,
             True,
             []
         ),
         (
             "callable_type_annotation",
             "checker",
             "checker_callable.jac",
             8,
             True,
             [
                 (
                     0,
                     """
        e1: Callable[[int], str] = str_to_str;  # Error: expects int, got str
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """
                 ),
                 (
                     1,
                     """
        e2: int = takes_callback(int_to_str);  # Error: returns str, not int
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """
                 ),
                 (
                     2,
                     """
        e3: Callable[[int, int], int] = wrong_order;  # Error: [str,int] vs [int,int]
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """
                 ),
                 (
                     3,
                     """
        e4: Callable[[int, int], str] = add_two;  # Error: returns int, not str
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """
                 ),
                 (
                     4,
                     """
        e5: Callable[[int], str] = calc.double;  # Error: returns int, not str
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """
                 ),
                 (
                     5,
                     """
        e6: Callable[[str], int] = Calculator.class_double;  # Error: expects int
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """
                 ),
                 (
                     6,
                     """
        e7: Callable[[Animal], str] = handle_dog;  # Error: Dog doesn't accept Cat
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """
                 ),
                 (
                     7,
                     """
        e8: Callable[[int, int], int] = without_default;  # Error: c has no default
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "callable_param_drop",
             "checker",
             "checker_callable_param_drop.jac",
             1,
             True,
             [
                 (
                     0,
                     """
        bad: Callable[[], None] = two_ints;  # Error: extra src params have no defaults
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "unbound_method_call",
             "checker",
             "checker_unbound_method_call.jac",
             2,
             True,
             [
                 (0, """Cannot assign int to parameter 'name' of type str"""),
                 (
                     1,
                     """Not all required parameters were provided in the function call: 'name'"""
                 )
             ]
         ),
         (
             "parameterless_init_with_args",
             "main",
             "checker_parameterless_init.jac",
             3,
             True,
             [
                 (1, """Named argument 'name' does not match any parameter"""),
                 (2, """Too many positional arguments""")
             ]
         ),
         (
             "type_param_assignment",
             "checker",
             "checker_type_param.jac",
             1,
             True,
             [(0, """Cannot assign Animal to parameter 'cls' of type type""")]
         ),
         (
             "bare_dot_relative_import",
             "checker",
             "checker_bare_dot_import.jac",
             1,
             True,
             [(0, """
      err: str = checker_imported.some_int;
    """)]
         ),
         (
             "type_narrowing_none_assignment_errors",
             "checker",
             "checker_type_narrowing_none.jac",
             2,
             True,
             [
                 (
                     0,
                     """
        y: int = value;  # <-- Error: None cannot be assigned to int
    """
                 ),
                 (
                     1,
                     """
        b: str = data;  # <-- Error: None cannot be assigned to str
    """
                 )
             ]
         ),
         (
             "match_type_narrowing",
             "checker",
             "checker_match_type_narrowing.jac",
             2,
             True,
             [
                 (
                     0,
                     """
        i: IntVal = val;  # <-- Error: StringVal cannot assign to IntVal
    """
                 ),
                 (
                     1,
                     """
        s: StringVal = val;  # <-- Error: StringVal | IntVal cannot assign to StringVal
    """
                 )
             ]
         ),
         (
             "union_subclass_to_base_assignment",
             "checker",
             "checker_match_narrowing.jac",
             1,
             True,
             [
                 (
                     0,
                     """
        c: Cat = animal;  # <-- Error: Dog cannot assign to Cat
    """
                 )
             ]
         ),
         (
             "compound_and_narrowing",
             "checker",
             "checker_and_narrowing.jac",
             2,
             True,
             []
         ),
         (
             "assignment_narrowing",
             "checker",
             "checker_assignment_narrowing.jac",
             0,
             True,
             []
         ),
         (
             "parenthesized_bool_cond",
             "checker",
             "checker_parenthesized_bool_cond.jac",
             0,
             True,
             []
         ),
         (
             "pre_expr_narrowing",
             "checker",
             "checker_pre_expr_narrowing.jac",
             0,
             True,
             []
         ),
         (
             "ternary_bool_cond_narrowing",
             "checker",
             "checker_ternary_bool_cond_narrowing.jac",
             0,
             True,
             []
         ),
         ("guard_narrowing", "checker", "checker_guard_narrowing.jac", 0, True, []),
         (
             "loop_exit_narrowing",
             "checker",
             "checker_loop_exit_narrowing.jac",
             0,
             True,
             []
         ),
         (
             "union_and_optional_special_forms",
             "checker",
             "checker_union_special_form.jac",
             3,
             True,
             [
                 (
                     0,
                     """
        y: int = x;  # <-- Error: int | str not assignable to int
        ^^^^^^^^^^^
    """
                 ),
                 (
                     1,
                     """
        z: int = x;  # <-- Error: int | str not assignable to int
        ^^^^^^^^^^^
    """
                 ),
                 (
                     2,
                     """
        y: int = x;  # <-- Error: str | None not assignable to int
        ^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "union_string_forward_refs",
             "checker",
             "checker_union_forward_ref.jac",
             0,
             True,
             []
         ),
         (
             "stdlib_pyi_relative_reexport",
             "checker",
             "checker_stdlib_pyi_relative_reexport.jac",
             0,
             True,
             []
         ),
         ("classvar_type_annotation", "checker", "checker_classvar.jac", 0, True, []),
         (
             "final_union_type_no_crash",
             "checker",
             "checker_final_union_type.jac",
             0,
             True,
             []
         ),
         (
             "walrus_operator_narrowing",
             "checker",
             "checker_walrus_narrowing.jac",
             0,
             True,
             []
         ),
         (
             "type_subscript_member_access",
             "checker",
             "checker_type_subscript_member.jac",
             0,
             True,
             []
         ),
         (
             "isinstance_ternary_narrowing",
             "checker",
             "checker_isinstance_ternary.jac",
             0,
             False,
             []
         ),
         (
             "list_generator_type_inference",
             "checker",
             "checker_list_generator_inference.jac",
             0,
             True,
             []
         ),
         (
             "bug_lambda_return_type_checks_against_enclosing_function",
             "checker",
             "checker_bug_lambda_return_type.jac",
             1,
             True,
             []
         ),
         ("function_type_attrs", "checker", "checker_function_attrs.jac", 0, True, []),
         (
             "any_vs_object_attr_access",
             "checker",
             "checker_bug_typing_any_attr.jac",
             1,
             True,
             [
                 (
                     0,
                     """
        val.nonexistent;  # <-- Error: object has no attribute "nonexistent"
            ^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "typevar_union_return_types",
             "checker",
             "checker_typevar_union_return.jac",
             0,
             True,
             []
         ),
         (
             "typevar_overload_inference",
             "checker",
             "checker_typevar_overload_inference.jac",
             0,
             True,
             []
         ),
         (
             "typing_cast_special_form",
             "checker",
             "checker_typing_cast.jac",
             0,
             True,
             []
         ),
         (
             "match_case_narrowing",
             "checker",
             "checker_match_case_narrowing.jac",
             0,
             True,
             []
         ),
         (
             "enum_static_method",
             "checker",
             "checker_enum_static_method.jac",
             0,
             True,
             []
         ),
         (
             "generic_self_member_type_propagation",
             "checker",
             "checker_generic_self_member.jac",
             0,
             True,
             []
         ),
         (
             "narrowing_gaps_total_error_count",
             "checker",
             "checker_narrowing_gaps.jac",
             0,
             True,
             []
         ),
         ("runtime_errors_total", "checker", "checker_runtime_errors.jac", 0, True, []),
         (
             "mro_reexport_through_init",
             "checker",
             "checker_mro_reexport.jac",
             0,
             True,
             []
         ),
         (
             "scope_narrowing_isolation_between_impl_bodies",
             "checker",
             "checker_static_method_inherit.jac",
             0,
             True,
             []
         ),
         (
             "bare_generic_any_propagates_through_operations",
             "checker",
             "checker_bare_generic_any_propagation.jac",
             0,
             True,
             []
         ),
         (
             "callable_narrowing",
             "checker",
             "checker_callable_narrowing.jac",
             4,
             True,
             [
                 (
                     0,
                     """
        fail: Callable[[int], str] = handler;  # <-- Error (union cannot assign to Callable)
    """
                 ),
                 (
                     1,
                     """
        fail: str = handler;  # <-- Error (union cannot assign to str)
    """
                 ),
                 (
                     2,
                     """
        s: str = handler;  # <-- Error: handler is Callable here, not str
    """
                 ),
                 (
                     3,
                     """
        cb: Callable[[int], str] = handler;  # <-- Error: handler is str here
    """
                 )
             ]
         ),
         (
             "hasattr_narrowing",
             "checker",
             "checker_hasattr_narrowing.jac",
             5,
             True,
             [
                 (
                     0,
                     """
        return x.foo;  # <-- Error: attribute is missing from NoFoo
    """
                 ),
                 (
                     1,
                     """
        return x.bar;  # <-- Error: x is WithFoo here, no `bar`
    """
                 ),
                 (
                     3,
                     """
        return x.foo;  # <-- Error: x is NoFoo here, no `foo`
    """
                 )
             ]
         ),
         (
             "type_alias_narrowing",
             "checker",
             "checker_type_alias_narrowing.jac",
             2,
             True,
             [
                 (
                     0,
                     """
        f: Foo = val;  # Error: Foo | None cannot assign to Foo
    """
                 ),
                 (
                     1,
                     """
        fail: Callable[[int], str] = handler;  # Error: union cannot assign to Callable
    """
                 )
             ]
         ),
         (
             "param_isinstance_narrowing",
             "checker",
             "checker_param_isinstance_narrowing.jac",
             2,
             True,
             [
                 (
                     0,
                     """
        return other.bark();  # <-- Error: object has no attribute "bark"
                     ^^^^
    """
                 ),
                 (
                     1,
                     """
        return other.bark();  # <-- Error: object has no attribute "bark"
        ^^^^^^^^^^^^^^^^^^^^
    """
                 )
             ]
         ),
         (
             "walker_reports_attribute_resolves",
             "checker",
             "checker_walker_reports.jac",
             0,
             True,
             []
         ),
         (
             "component_impl_scope_resolves_has_vars",
             "checker",
             "checker_component_impl_scope.jac",
             0,
             True,
             []
         ),
         (
             "generator_yield_return_type_check",
             "checker",
             "checker_generator_yield_return.jac",
             2,
             True,
             [
                 (0, """
        yield "hello";
        ^^^^^^^^^^^^^
    """),
                 (1, """
        return 42;
        ^^^^^^^^^^
    """)
             ]
         ),
         (
             "uniform_gradual_any_in_jac_modules",
             "checker",
             "checker_strict_any_jac.jac",
             0,
             True,
             []
         ),
         (
             "comprehension_in_ternary_narrowing",
             "checker",
             "checker_comprehension_in_ternary.jac",
             1,
             True,
             []
         ),
         (
             "spread_with_explicit_kwarg_no_false_positive",
             "checker",
             "checker_spread_with_kwarg.jac",
             0,
             True,
             []
         )
     ];

def _checker_case(row: tuple) {
    (name, dirkey, fixture, count, no_tc, pretty) = row;
    program = JacProgram();
    program.compile(
        os.path.join(CHECKER_DIRS[dirkey], fixture), options=(NO_TC if no_tc else None)
    );
    assert len(program.errors_had) == count , (
        f"{name}: expected {count} error(s), got {len(program.errors_had)}:\n  "
        + "\n  ".join(str(e) for e in program.errors_had)
    );
    for (idx, needle) in pretty {
        assert_error_pretty_found(needle, program.errors_had[idx].pretty_print());
    }
}

with entry {
    parametrize(
        "checker", CHECKER_CASES, _checker_case, id_fn=lambda (c: tuple) { c[0]; }
    );
}

test "return_value_in_ability_warns" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_return_in_ability.jac"), options=NO_TC
    );
    assert len(program.errors_had) == 0;
    w2014_warnings = [
        w
        for w in program.warnings_had
        if w.code and w.code.code == "W2014"
    ];
    assert len(w2014_warnings) == 2 , f"Expected 2 W2014 warnings, got {len(
        w2014_warnings
    )}: {w2014_warnings}";
}

test "explicit_self_in_archetype_errors" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_explicit_self.jac"), options=NO_TC
    );
    e2015_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E2015"
    ];
    # 4 errors: one each for obj, node, edge, walker bad_method
    # No errors for: good_method (no self), static_method (static), PyClass methods (class)
    assert len(e2015_errors) == 4 , f"Expected 4 E2015 errors, got {len(e2015_errors)}: {e2015_errors}";
}

test "imported_sym" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(FIXTURES, "checker", "import_sym_test.jac"), options=NO_TC
    );
    assert len(program.errors_had) == 1;
    assert_error_pretty_found(
        """
      a: str = foo();  # <-- Ok
      b: int = foo();  # <-- Error
      ^^^^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );
}

"""Calling an @overload-ed function imported through a re-export chain matches
the later overload. Overloads must be gathered at the definition scope, not the
single-symbol re-export scope (regression: SQLAlchemy `create_engine`)."""
test "imported_overloaded_function_call_resolves" {
    path = os.path.join(CHECKER_FIXTURES, "checker_imported_overload.jac");
    program = JacProgram();
    program.compile(path);
    assert program.errors_had == [] , (
        "make(\"a\") matches the no-strict overload; expected no errors, got: "
        + str([e.pretty_print() for e in program.errors_had])
    );
}

test "dunder_new_direct_call" {
    path = os.path.join(CHECKER_FIXTURES, "checker_dunder_new_direct.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    # object.__new__(self.__class__) and object.__new__(cls) should NOT error.
    # Only the call with too many args should produce errors (one per extra arg).
    e1051_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1051"
    ];
    assert len(e1051_errors) == 2 , f"Expected 2 E1051 errors, got {len(
        e1051_errors
    )}: "
        + "\n".join(e.pretty_print() for e in e1051_errors);
    # Both errors should be on the too-many-args line
    for e in e1051_errors {
        assert e.loc and e.loc.first_line == 32 , f"Expected error on line 32, got line {e.loc.first_line
            if e.loc
            else '?'}";
    }
}

test "param_arg_match" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_arg_param_match.jac");
    mod = program.compile(path, options=NO_TC);
    assert len(program.errors_had) == 13;

    expected_errors = [
        """
        Not all required parameters were provided in the function call: 'a'
                 f = Foo();
                 f.bar();
                 ^^^^^^^
        """,
        """
        Too many positional arguments
                 f.bar();
                 f.bar(1);
                 f.bar(1, 2);
                          ^
        """,
        """
        Not all required parameters were provided in the function call: 'self', 'a'
                 f.bar(1, 2);
                 f.baz();
                 ^^^^^^^
        """,
        """
        Not all required parameters were provided in the function call: 'a'
                 f.baz();
                 f.baz(1);
                 ^^^^^^^^
        """,
        """
        Not all required parameters were provided in the function call: 'f'
                 foo(1, 2, d=3, e=4, f=5, c=4);  # order does not matter for named
                 foo(1, 2, 3, d=4, e=5, g=7, h=8);  # missing argument 'f'
                 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        """,
        """
        Positional only parameter 'b' cannot be matched with a named argument
                 foo(1, 2, 3, d=4, e=5, g=7, h=8);  # missing argument 'f'
                 foo(1, b=2, c=3, d=4, e=5, f=6);  # b is positional only
                        ^^^
        """,
        """
        Too many positional arguments
                 bar(1, 2, 3, 4, 5, f=6);
                 bar(1, 2, 3, 4, 5, 6, 7, 8, 9);  # too many args
                                       ^
        """,
        """
        Too many positional arguments
                 bar(1, 2, 3, 4, 5, f=6);
                 bar(1, 2, 3, 4, 5, 6, 7, 8, 9);  # too many args
                                          ^
        """,
        """
        Too many positional arguments
                 bar(1, 2, 3, 4, 5, f=6);
                 bar(1, 2, 3, 4, 5, 6, 7, 8, 9);  # too many args
                                             ^
        """,
        """
        Parameter 'c' already matched
                 bar(1, 2, 3, 4, 5, f=6);
                 bar(1, 2, 3, 4, 5, 6, 7, 8, 9);  # too many args
                 bar(1, 2, 3, 4, 5, 6, c=3);  # already matched
                                       ^^^
        """,
        """
        Named argument 'h' does not match any parameter
                 bar(1, 2, 3, 4, 5, 6, 7, 8, 9);  # too many args
                 bar(1, 2, 3, 4, 5, 6, c=3);  # already matched
                 bar(1, 2, 3, 4, 5, 6, h=1);  # h is not matched
                                       ^^^
        """,
        """
        Too many positional arguments
                 baz(a=1, b=2);
                 baz(1, b=2);  # a can be both positional and keyword
                 baz(1, 2);  # 'b' can only be keyword arg
                        ^
        """,
        """
        Not all required parameters were provided in the function call: 'b'
                 baz(a=1, b=2);
                 baz(1, b=2);  # a can be both positional and keyword
                 baz(1, 2);  # 'b' can only be keyword arg
                 ^^^^^^^^^
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "class_construct" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_class_construct.jac");
    mod = program.compile(path, options=NO_TC);
    assert len(program.errors_had) == 3;

    square_sym = mod.sym_tab.lookup("Square");
    assert square_sym is not None;
    assert square_sym.decl is not None;
    square_ty: any = square_sym.decl.type;
    assert square_ty is not None;
    assert square_ty.shared is not None;
    square_shared: any = square_ty.shared;
    square_mro: list = list(square_shared.mro);
    mro_class_names = [
        cls.shared.class_name
        for cls in square_mro
        if cls.shared is not None
    ];
    assert "object" in mro_class_names , f"Expected 'object' in MRO, got: {mro_class_names}";

    expected_errors = [
        """
        Cannot assign float to parameter 'color' of type str
                with entry {
                    c1 = Circle1(RAD);
                                ^^^
        """,
        """
        Not all required parameters were provided in the function call: 'age'
                with entry {
                c2 = Square(length);
                     ^^^^^^^^^^^^^^
        """,
        """
        Not all required parameters were provided in the function call: 'name'
                c = Person(name=name, age=25);
                c = Person();
                    ^^^^^^^^
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "checker_member_access" {
    path = os.path.join(FIXTURES, "symtab_build.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    assert len(mod.sym_tab.names_in_scope.values()) == 2;
    mod_scope_symbols = ["Symbol(alice", "Symbol(Person"];
    for sym in mod_scope_symbols {
        assert sym in str(mod.sym_tab.names_in_scope.values());
    }
    # obj archetypes only have declared 'has' fields and abilities in scope —
    # dynamic self.attr assignments (self.name in greet) are NOT added.
    assert len(mod.sym_tab.kid_scope[0].names_in_scope.values()) == 4;
    kid_scope_symbols = [
        "Symbol(age",
        "Symbol(greet",
        "Symbol(create_person",
        "Symbol(class_info"
    ];
    for sym in kid_scope_symbols {
        assert sym in str(mod.sym_tab.kid_scope[0].names_in_scope.values());
    }
    age_sym = mod.sym_tab.kid_scope[0].lookup("age");
    assert age_sym is not None;
    assert "(NAME, age, 22:11 - 22:14)" in str(age_sym.uses);
    # 5 errors: 'has no attribute name' (obj can't have dynamic attrs),
    # 3 Unknown self in static/classmethod, 1 type mismatch (alice.age = '909').
    # Note: `self.type = "Human"` in @classmethod no longer produces a spurious
    # E1001 (assigning to builtin `type`) because `.type` is now correctly
    # deferred to the AtomTrailer's member-access resolution, where `self` is
    # Unknown in a classmethod context.
    assert len(program.errors_had) == 5;
    assert_error_pretty_found(
        """
        alice.age = '909';  # <-- Error
        ^^^^^^^^^^^^^^^^^^
    """,
        program.errors_had[4].pretty_print()
    );
}

test "checker_import_missing_module" {
    path = os.path.join(CHECKER_FIXTURES, "checker_import_missing_module.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    # Each missing module is reported once (W1100). The Unknowns that flow
    # from an already-diagnosed import are poisoned and no longer cascade
    # into hard errors (E1032 attribute access, E1001/E1002 assignments) at
    # every use site -- one actionable diagnostic per root cause.
    w1100s = [
        w
        for w in program.warnings_had
        if w.code is not None and w.code.code == "W1100"
    ];
    assert len(w1100s) == 4 , f"expected 4 W1100s, got {len(w1100s)}";
    assert len(program.errors_had) == 0 , f"diagnosed-import Unknowns must not cascade: {[
        e.pretty_print() for e in program.errors_had
    ]}";
}

test "checker_jac_runtime_alias" {
    # `@jac/runtime` is a virtual module resolved by the bundler to
    # jaclang/client/client_runtime.jac. The type checker must use the
    # same mapping so imported symbols keep their declared types (e.g.
    # jacIsLoggedIn -> bool) instead of decaying to Unknown and producing
    # spurious assignment errors.
    path = os.path.join(CHECKER_FIXTURES, "checker_jac_runtime_alias.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    assert len(program.errors_had) == 0 , f"unexpected errors: {[
        e.pretty_print() for e in program.errors_had
    ]}";
    assert len(program.warnings_had) == 0 , f"unexpected warnings: {[
        w.pretty_print() for w in program.warnings_had
    ]}";
}

test "generics" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_generics.jac");
    mod = program.compile(path, options=NO_TC);
    assert len(program.errors_had) == 9;

    expected_errors = [
        """
        Cannot assign Foo to str
            for it in tl {
                tifoo: Foo = it;
                tistr: str = it;  # <-- Error
                ^^^^^^^^^^^^^^^^
            }
        }
        """,
        """
        Cannot assign Foo to str
            lst: list[Foo] = [Foo(), Foo()];
            f: Foo = lst[0];  # <-- Ok
            s: str = lst[0];  # <-- Error
            ^^^^^^^^^^^^^^^^

            for it in lst {
        """,
        """
        Cannot assign Foo to str
            for it in lst {
                tifoo: Foo = it;  # <-- Ok
                tistr: str = it;  # <-- Error
                ^^^^^^^^^^^^^^^^
            }

        """,
        """
        Cannot assign int to str
            m: list[int] = [1, 2, 3];
            n: int = m[0];
            p: str = m[0];  # <-- Error
            ^^^^^^^^^^^^^^

            x: list[str] = ["a", "b", "c"];
        """,
        """
        Cannot assign str to int
            x: list[str] = ["a", "b", "c"];
            y: str = x[1];
            z: int = x[1];  # <-- Error
            ^^^^^^^^^^^^^^

            d: dict[int, str] = {1: "one", 2: "two"};
        """,
        """
        Cannot assign str to int
            d: dict[int, str] = {1: "one", 2: "two"};
            s: str = d[1];
            i: int = d[1];  # <-- Error
            ^^^^^^^^^^^^^^

            ht = HashTable[int, str]();
        """,
        """
        Cannot assign Literal["one"] to parameter 'key' of type int
            ht = HashTable[int, str]();
            ht.insert(1, "one");
            ht.insert("one", "one");  # <-- Error
                    ^^^^^
            ht.insert(1, 1);  # <-- Error

        """,
        """
        Cannot assign int to parameter 'value' of type str
            ht.insert(1, "one");
            ht.insert("one", "one");  # <-- Error
            ht.insert(1, 1);  # <-- Error
                        ^

            hv1: str = ht.get(1);
        """,
        """
        Cannot assign str to int

            hv1: str = ht.get(1);
            hv2: int = ht.get(1);  # <-- Error
            ^^^^^^^^^^^^^^^^^^^^^

        }
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "return_type" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_return_type.jac");
    mod = program.compile(path, options=NO_TC);
    assert len(program.errors_had) == 4;

    expected_errors = [
        """
        Return type annotation required when function returns a value
            return 1;  # <-- Error (no return annotation, but returning a value)
            ^^^^^^^^^
        """,
        """
        Return type annotation required when function returns a value
            return "";  # <-- Error (no return annotation, but returning a value)
            ^^^^^^^^^^
        """,
        """
        Cannot return Literal[""], expected int

        def bar()  -> int {
            return "";  # <-- Error
            ^^^^^^^^^^
        """,
        """
        Cannot return float, expected int
            return 1.1;  # <-- Error
            ^^^^^^^^^^
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "connect_filter" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_connect_filter.jac");
    mod = program.compile(path, options=NO_TC);
    assert len(program.errors_had) == 7;

    expected_errors = [
        """
        Connection type must be an edge instance
            a_inst +>: edge_inst :+> b_inst;  # Ok
            a_inst +>: NodeA :+> b_inst;  # Error
                       ^^^^^
        """,
        """
        Connection left operand must be a node instance
            a_inst +>: NodeA :+> b_inst;  # Error
            NodeA +>: MyEdge :+> b_inst;  # Error
            ^^^^^
        """,
        """
        Connection right operand must be a node instance
            NodeA +>: MyEdge :+> b_inst;  # Error
            a_inst +>: MyEdge :+> NodeB;  # Error
                                  ^^^^^
        """,
        """
        Member "not_mem" not found on type "MyEdge"
            # Assign compr in edges
            a_inst +>: MyEdge : id=1,not_mem="some" :+> b_inst;  # Error
                                     ^^^^^^^
        """,
        """
        Member "not_exist" not found on type "Book"
            lst(=title="Parry Potter",author="K.J. Bowling",year=1997);  # Ok
            lst(=not_exist="some");  # Error
                 ^^^^^^^^^
        """,
        """
        Type "Literal["Type Error"]" is not assignable to type "int"
            lst(=not_exist="some");  # Error
            lst(=year="Type Error");  # Error
                      ^^^^^^^^^^^^
        """,
        """
        Member "not_exists" not found on type "MyEdge"
            [->:MyEdge:id==1:->];  # Ok
            [->:MyEdge:not_exists>=1:->];  # Error
                       ^^^^^^^^^^
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "filter_compr_compare_types" {
    # Filter comparisons inside edge-ref filters must validate operand
    # types, not just field existence (issue #5885 gap 5). Matches the
    # statement-level CompareExpr behavior — `==` / `!=` are not flagged
    # for cross-type operands (Python returns False, not TypeError), but
    # ordered comparisons `<`, `<=`, `>`, `>=` are flagged with E1110.
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_filter_compr_compare.jac");
    mod = program.compile(path, options=NO_TC);
    assert len(program.errors_had) == 4;

    expected_errors = [
        """
        Operator ">=" not supported between types "int" and "Literal["x"]"
            # for `int >= str` etc. These should be flagged with E1110.
            [a_inst ->:MyEdge:weight>="x":-> ];              # Error: int >= str
                              ^^^^^^^^^^^
        """,
        """
        Operator "<" not supported between types "str" and "int"
            [a_inst ->:MyEdge:weight>="x":-> ];              # Error: int >= str
            [a_inst ->:MyEdge:label<1:-> ];                  # Error: str <  int
                              ^^^^^^^
        """,
        """
        Operator ">" not supported between types "int" and "Literal["x"]"
            [a_inst ->:MyEdge:label<1:-> ];                  # Error: str <  int
            [a_inst ->:MyEdge:weight>"x":-> ];               # Error: int >  str
                              ^^^^^^^^^^
        """,
        """
        Operator "<=" not supported between types "int" and "Literal["x"]"
            [a_inst ->:MyEdge:weight>"x":-> ];               # Error: int >  str
            a_inst del ->:MyEdge:weight<="x":-> b_inst;      # Error inside del
                                 ^^^^^^^^^^^
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "visit_collection_element_type" {
    # `visit` accepts node | edge | path | collection of (node | edge),
    # or any/unknown. Parameterized collections must have valid element
    # types; unions must have all members valid.
    # The `Bad` walker has 9 visits whose target is invalid (E1094).
    # The `Good` walker has only valid visits and must produce no E1094.
    path = os.path.join(CHECKER_FIXTURES, "checker_visit_collection_element.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    e1094 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1094"
    ];
    assert len(e1094) == 9 , f"Expected 9 E1094 (invalid visit target), got {len(
        e1094
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1094);
    other = [
        e
        for e in program.errors_had
        if e.code and e.code.code != "E1094"
    ];
    assert len(other) == 0 , f"Expected no other errors, got {len(other)}:\n"
        + "\n---\n".join(e.pretty_print() for e in other);
}

test "spawn_validation" {
    # `a spawn b` requires exactly one operand to be a walker; the other
    # operand must be a node, edge, or collection thereof.
    # The fixture has 4 cases where neither side is a walker (E1114) and
    # 5 cases where the non-walker side is not a valid spawn target
    # (E1115). The good cases must not emit either diagnostic.
    path = os.path.join(CHECKER_FIXTURES, "checker_spawn_validation.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    e1114 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1114"
    ];
    assert len(e1114) == 4 , f"Expected 4 E1114 (no walker in spawn), got {len(
        e1114
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1114);
    e1115 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1115"
    ];
    assert len(e1115) == 5 , f"Expected 5 E1115 (invalid spawn target), got {len(
        e1115
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1115);
}

test "disconnect_typed" {
    # `del a ->:T:-> b` requires T to be an edge type (or instance) — same
    # rule as connect's `+>: T :+>`. The fixture has 2 typed-disconnect
    # statements where T is a node (E1098). The Ok cases must not emit
    # E1098.
    path = os.path.join(CHECKER_FIXTURES, "checker_disconnect_typed.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    e1098 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1098"
    ];
    assert len(e1098) == 2 , f"Expected 2 E1098 (typed-disconnect not edge), got {len(
        e1098
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1098);
}

test "disconnect_op_no_w1051" {
    # Issue #5885 gap 9: `del a --> b` (and its typed/reverse forms) used
    # to fall through `apply_connect_or_disconnect` without setting a
    # result type, so every disconnect site emitted a spurious W1051.
    # The runtime returns `bool`, so the typed result is `bool` — and bare
    # disconnect statements must produce no W1051 noise.
    path = os.path.join(CHECKER_FIXTURES, "checker_disconnect_op_no_w1051.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    w1051 = [
        w
        for w in program.warnings_had
        if w.code and w.code.code == "W1051"
    ];
    assert len(w1051) == 0 , f"Expected no W1051 on disconnect ops, got {len(w1051)}:\n"
        + "\n---\n".join(w.pretty_print() for w in w1051);
    # Disconnect must type as `bool` so that `removed: bool = a del --> b`
    # is a clean assignment, not E1001 (Unknown -> bool).
    assert len(program.errors_had) == 0 , f"Unexpected errors: {[
        e.pretty_print() for e in program.errors_had
    ]}";
}

test "named_entry_no_w1051" {
    # Regression: a named entry block (`with entry:__main__`, `with entry:foo`)
    # emitted a spurious W1051 on the entry-point label. A ModuleCode's `name`
    # is a Name node that is a label, not a variable reference -- it has no
    # symbol -- but exit_name type-evaluated it, got Unknown, and warned. This
    # fired on the idiomatic `with entry:__main__` guard of nearly every program.
    path = os.path.join(CHECKER_FIXTURES, "checker_named_entry_no_w1051.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    w1051 = [
        w
        for w in program.warnings_had
        if w.code and w.code.code == "W1051"
    ];
    assert len(w1051) == 0 , f"Expected no W1051 on named entry labels, got {len(
        w1051
    )}:\n"
        + "\n---\n".join(w.pretty_print() for w in w1051);
    assert len(program.errors_had) == 0 , f"Unexpected errors: {[
        e.pretty_print() for e in program.errors_had
    ]}";
}

test "lambda_param_inferred_from_expected_callable" {
    # Unannotated lambda params infer from the key= callable, so no E1054/W1051.
    path = os.path.join(CHECKER_FIXTURES, "checker_lambda_param_inference.jac");
    program = JacProgram();
    program.compile(path);
    assert len(program.errors_had) == 0 , f"Unexpected errors: {[
        e.pretty_print() for e in program.errors_had
    ]}";
    w1051 = [
        w
        for w in program.warnings_had
        if w.code and w.code.code == "W1051"
    ];
    assert len(w1051) == 0 , f"Expected no W1051 on inferred lambdas, got {len(
        w1051
    )}:\n"
        + "\n---\n".join(w.pretty_print() for w in w1051);
}

test "lambda_param_unresolved_requires_annotation" {
    path = os.path.join(CHECKER_FIXTURES, "checker_lambda_unresolved_param.jac");
    program = JacProgram();
    program.compile(path);
    e1119 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1119"
    ];
    assert len(e1119) == 3 , f"Expected 3 E1119, got {len(e1119)}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1119);
}

test "ability_trigger_archetype" {
    # Walker abilities must trigger on a node/edge/Root; node/edge
    # abilities must trigger on a walker. Tuple and union triggers are
    # validated element-wise. Untyped triggers (`with entry`) are valid.
    # The fixture has 7 walker-side bad cases (E1116) and 5 node/edge
    # bad cases (E1117); the good cases must produce neither diagnostic.
    path = os.path.join(CHECKER_FIXTURES, "checker_ability_trigger_archetype.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    e1116 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1116"
    ];
    assert len(e1116) == 7 , f"Expected 7 E1116 (invalid walker trigger), got {len(
        e1116
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1116);
    e1117 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1117"
    ];
    assert len(e1117) == 5 , f"Expected 5 E1117 (invalid node/edge trigger), got {len(
        e1117
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1117);
}

test "root_keyword_as_walker_trigger" {
    path = os.path.join(CHECKER_FIXTURES, "checker_root_keyword_trigger.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    e1116 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1116"
    ];
    assert len(e1116) == 8 , f"Expected 8 E1116 (3 root keyword + 1 backtick `root + 3 variable instance, bare/union/tuple, + 1 call-expr instance), got {len(
        e1116
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1116);
    var_errors = [
        e
        for e in e1116
        if "my_node" in e.pretty_print()
    ];
    # `N()` call-expr instance: no name leaf, so diagnostic uses the type name `N`.
    call_errors = [
        e
        for e in e1116
        if 'got "N"' in e.pretty_print()
    ];
    root_errors = [
        e
        for e in e1116
        if e not in var_errors and e not in call_errors
    ];
    assert len(var_errors) == 3 , "Expected 3 E1116 for `my_node` variable instance (bare, union, tuple)";
    assert len(root_errors) == 4 , "Expected 4 E1116 for `root` keyword (bare, backtick `root, union, tuple)";
    assert len(call_errors) == 1 , "Expected 1 E1116 for `N()` call-expr instance trigger";
}

test "undefined_osp_position" {
    # Issue #5885 gap 7: undefined names in OSP-shape positions
    # (connect/disconnect typed-edge, ability trigger) must promote
    # from `W2001` to `E2018`. The fixture has 5 such positions —
    # 3 ability triggers (one bare, one tuple element, one union
    # member) and 2 typed edge ops. The Ok cases must not emit
    # E2018, and W2001 must not duplicate any of the promoted spans.
    path = os.path.join(CHECKER_FIXTURES, "checker_undefined_osp_position.jac");
    program = JacProgram();
    program.compile(path);
    e2018 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E2018"
    ];
    assert len(e2018) == 5 , f"Expected 5 E2018 (undefined name in OSP position), got {len(
        e2018
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e2018);
    promoted_spans = {(e.loc.first_line, e.loc.col_start) for e in e2018};
    duplicate_w2001 = [
        w
        for w in program.warnings_had
        if w.code
            and w.code.code == "W2001"
            and (w.loc.first_line, w.loc.col_start) in promoted_spans
    ];
    assert len(duplicate_w2001) == 0 , f"W2001 must not duplicate promoted E2018 spans, got: {[
        w.pretty_print() for w in duplicate_w2001
    ]}";
}

test "connect_unparameterized_collection" {
    # Issue #5885 gap 8: `a ++> b` (and disconnect / typed-edge forms)
    # used to silently accept bare `list` / `tuple` / `set` / `frozenset`
    # operands because the runtime accepts any collection of nodes; the
    # checker can't verify the element types. Each unparameterized
    # operand now reports `E1118`. The fixture has 13 such positions
    # (8 right-side connect, 2 left-side connect, 3 disconnect — one of
    # which uses the typed-edge form). Good cases (parameterized list,
    # list literal, single node) must produce no E1118.
    path = os.path.join(CHECKER_FIXTURES, "checker_connect_unparameterized.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    e1118 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1118"
    ];
    assert len(e1118) == 13 , f"Expected 13 E1118 (unparameterized connect operand), got {len(
        e1118
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1118);
}

test "edge_ref_typed_result" {
    # Issue #5885 gap 6: typed `[edge ... ->:T:-> ...]` traversals must
    # propagate `T` as the list element type instead of degrading to
    # `list[<Any>]`. The Ok line assigns into list[MyEdge]; the Error
    # line assigns the same expression into list[OtherEdge] so the
    # checker can prove the propagated element type at the use site.
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_edge_ref_typed_result.jac");
    mod = program.compile(path, options=NO_TC);
    e1001 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1001"
    ];
    assert len(e1001) == 1 , f"Expected 1 E1001 (typed edge-ref result mismatch), got {len(
        e1001
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1001);
    expected_error = """
        Cannot assign list[MyEdge] to list[OtherEdge]
            # list[MyEdge], not list[OtherEdge].
            bad_edges: list[OtherEdge] = [edge a ->:MyEdge:-> b];         # Error
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        """;
    assert_error_pretty_found(expected_error, e1001[0].pretty_print());
}

test "root_type" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_root_type.jac");
    mod = program.compile(path, options=NO_TC);
    assert len(program.errors_had) == 1;
    expected_error = """
            root ++> c;
            x: str = root;  # <- error
            ^^^^^^^^^^^^^^
            """;
    assert_error_pretty_found(expected_error, program.errors_had[0].pretty_print());
}

test "inherit_method_lookup" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_inherit_method_lookup.jac"),
        options=NO_TC
    );
    user_errors = [
        e
        for e in program.errors_had
        if "/site-packages/" not in e.loc.mod_path
            and "/lib/python" not in e.loc.mod_path
            and "/Lib/python" not in e.loc.mod_path
    ];
    assert len(user_errors) == 0;
}

test "inherit_init_params" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_inherit_init_params.jac"), options=NO_TC
    );
    assert len(program.errors_had) == 2;

    expected_errors = [
        """
        Not all required parameters were provided in the function call: 'age'
            c0 = Child("Alice", 30);  # <-- Ok
            c1 = Child(name="Alice", age=30);  # <-- Ok
            c2 = Child("Bob");  # <-- Error: missing age
                 ^^^^^^^^^^^^
        """,
        """
        Not all required parameters were provided in the function call: 'name'
            c2 = Child("Bob");  # <-- Error: missing age
            c3 = Child(age=25);  # <-- Error: missing name
                 ^^^^^^^^^^^^^
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "agentvisitor_connect_no_errors" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "connect_agentvisitor.jac");
    mod = program.compile(path, options=NO_TC);
    assert len(program.errors_had) == 0;
    # TODO: W1051 (unresolved expression type) currently fires on the
    # `with AgentVisitor entry` event-type reference and on nodes reached
    # inside typeshed stubs. Filtered here until evaluator coverage gaps
    # and the stub-file false positives are addressed in a follow-up PR.
    non_w1051 = [
        w
        for w in program.warnings_had
        if w.code is None or w.code.code != "W1051"
    ];
    assert len(non_w1051) == 0;
}

test "inferred_local_type_frozen" {
    # An unannotated local is frozen to the type inferred at its first
    # binding; reassigning an incompatible type is an error. The
    # `None`-sentinel pattern is the one exception (the type evolves).
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_inferred_type_frozen.jac"),
        options=NO_TC
    );
    assert len(program.errors_had) == 1 , f"Expected 1 type error, but got {len(
        program.errors_had
    )}: "
        + "\n".join([err.pretty_print() for err in program.errors_had]);
    _first_code = program.errors_had[0].code;
    assert _first_code is not None;
    assert _first_code.code == "E1001";
    assert_error_pretty_found(
        """
        a = "some str";  # <-- Error
    """,
        program.errors_had[0].pretty_print()
    );
}

test "inferred_local_type_widens_literals" {
    # Only the cross-type reassignment errors, and the message reports the
    # widened base type (`str`), not a leaked `Literal[...]`.
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_literal_widening_reassignment.jac"),
        options=NO_TC
    );
    assert len(program.errors_had) == 1 , f"Expected 1 type error, but got {len(
        program.errors_had
    )}: "
        + "\n".join([err.pretty_print() for err in program.errors_had]);
    _first_code = program.errors_had[0].code;
    assert _first_code is not None;
    assert _first_code.code == "E1001";
    msg = program.errors_had[0].pretty_print();
    assert "Cannot assign int to str" in msg , f"Expected widened-base message, got: {msg}";
    assert "Literal[" not in msg , f"Frozen type should not leak a literal: {msg}";
    assert_error_pretty_found(
        """
        name = 5;  # <-- Error
        ^^^^^^^^
    """, msg
    );
}

test "classmethod" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_classmethod.jac"), options=NO_TC
    );
}

test "overload_decorator" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_overload.jac"), options=NO_TC
    );
    assert len(program.errors_had) == 2;

    error_messages = [err.pretty_print() for err in program.errors_had];

    do_something_error = next(
        (
            err
            for err in error_messages
            if "do_something" in err and "hello" in err
        ),
        None
    );
    assert do_something_error is not None , 'Expected error for foo.do_something("hello")';
    assert_error_pretty_found(
        """
        foo.do_something("hello");  # <-- Error
        ^^^^^^^^^^^^^^^^^^^^^^^^^
    """,
        do_something_error
    );

    add_error = next(
        (
            err
            for err in error_messages
            if "__add__" in err and "hello" in err
        ),
        None
    );
    assert add_error is not None , 'Expected error for foo + "hello"';
    assert_error_pretty_found(
        """
        foo + "hello";  # <-- Error
        ^^^^^^^^^^^^^
    """, add_error
    );
}

test "function_overload_decorator" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_function_overload.jac"), options=NO_TC
    );
    assert len(program.errors_had) == 2;

    error_messages = [err.pretty_print() for err in program.errors_had];

    cast_error = next(
        (
            err
            for err in error_messages
            if "cast" in err and "hello" in err
        ),
        None
    );
    assert cast_error is not None , 'Expected error for cast("hello")';
    assert_error_pretty_found(
        """
        z: str = cast("hello");  # <-- Error
              ^^^^^^^^^^^^^
    """,
        cast_error
    );
}

test "walrus_operator" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_walrus_operator.jac"), options=NO_TC
    );
    assert len(program.errors_had) == 5;

    expected_errors = [
        """
        glob result3: str = result1;
        ^^^^^^^^^^^^^^^^^^^^^^
        """,
        """
        glob result4: str = z;
        ^^^^^^^^^^^^^^^^
        """,
        """
        y = "hello";
        ^^^^^^^^^^^^
        """,
        """
        p: AnotherNode = n;
        ^^^^^^^^^^^^^^^^^^^
        """,
        """
        a = AnotherNode();
        ^^^^^^^^^^^^^^^^^^
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

"""Test member access on union types."""
test "varargs_type_checking" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_varargs_type.jac"), options=NO_TC
    );
    assert len(program.errors_had) == 4;

    expected_errors = [
        """
        y: int = b;  # <-- Error
        ^^^^^^^^^^^
        """,
        """
        z: str = c;  # <-- Error
        ^^^^^^^^^^^
        """,
        """
        i: str = b[1]; # <-- Error
        ^^^^^^^^^^^^^
        """,
        """
        k: int = c["a"]; # <-- Error
        ^^^^^^^^^^^^^^^
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "property_assignment_type_checking" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_property_assignment.jac"), options=NO_TC
    );
    # Expected errors (5 total):
    #   1. b.cached_val = 99            — int to str  (@cached_property wrong type)
    #   2. b.cached_num = "not_an_int"  — str to int  (@cached_property wrong type)
    #   3. b.readonly_val = 1           — read-only   (@property no setter)
    #   4. h.base.cached_num = "wrong"  — str to int  (chained @cached_property)
    #   5. h.base.readonly_val = 2      — read-only   (chained @property no setter)
    assert len(program.errors_had) == 5 , "Expected 5 errors, got "
        + f"{len(program.errors_had)}:\n"
        + "\n---\n".join(err.pretty_print() for err in program.errors_had);

    # --- @cached_property wrong-type assignments ---
    # LHS must resolve to the getter return type (str / int), NOT a function type.
    assert_error_pretty_found(
        """
        b.cached_val = 99;                         # <-- Error (int to str)
    """,
        program.errors_had[0].pretty_print()
    );
    assert "str" in program.errors_had[0].pretty_print();
    assert "<function" not in program.errors_had[0].msg;

    assert_error_pretty_found(
        """
        b.cached_num = "not_an_int";               # <-- Error (str to int)
    """,
        program.errors_had[1].pretty_print()
    );
    assert "int" in program.errors_had[1].pretty_print();
    assert "<function" not in program.errors_had[1].msg;

    # --- @property (no setter): dedicated read-only diagnostic (E1005) ---
    assert_error_pretty_found(
        """
        b.readonly_val = 1;                        # <-- Error (read-only)
    """,
        program.errors_had[2].pretty_print()
    );
    assert "read-only" in program.errors_had[2].pretty_print();
    assert "readonly_val" in program.errors_had[2].pretty_print();

    # --- Chained @cached_property wrong-type ---
    assert_error_pretty_found(
        """
        h.base.cached_num = "wrong";               # <-- Error (str to int)
    """,
        program.errors_had[3].pretty_print()
    );
    assert "int" in program.errors_had[3].pretty_print();
    assert "<function" not in program.errors_had[3].msg;

    # --- Chained read-only @property ---
    assert_error_pretty_found(
        """
        h.base.readonly_val = 2;                   # <-- Error (read-only)
    """,
        program.errors_had[4].pretty_print()
    );
    assert "read-only" in program.errors_had[4].pretty_print();
}

test "native_property_setter_type_checking" {
    # Fulfills the deferred-test TODO in checker_property_assignment.jac.
    # Native `has x: T { getter; setter; }` syntax bypasses the @<name>.setter
    # path entirely, so setter assignment + read-only enforcement should
    # both type-check cleanly via the HasVar.accessors codepath.
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_property_native_setter.jac"),
        options=NO_TC
    );
    assert len(program.errors_had) == 2 , "Expected 2 errors, got "
        + f"{len(program.errors_had)}:\n"
        + "\n---\n".join(err.pretty_print() for err in program.errors_had);
    # 1. assignment of str to a float-typed writable property
    assert "wrong" in program.errors_had[0].pretty_print();
    assert "float" in program.errors_had[0].pretty_print();
    # 2. read-only diagnostic for the setterless `area` property
    assert "read-only" in program.errors_had[1].pretty_print();
    assert "area" in program.errors_had[1].pretty_print();
}

test "type_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_type_narrowing.jac"), options=NO_TC
    );

    # 13 errors: partial union member access now returns resolved types
    # instead of Unknown, preventing one cascading E1002 error.
    assert len(program.errors_had) == 13 , "Expected exactly 13 type errors, but got "
        + f"{len(program.errors_had)}:\n"
        + "\n---\n".join(err.pretty_print() for err in program.errors_had);

    expected_errors = [
        """
        fail: Dog = animal;  # <-- Error (Dog | Cat cannot assign to Dog)
        ^^^^^^^^^^^^^^^^^^^
        """,
        """
        c: Cat = animal;  # <-- Error: Dog cannot be assigned to Cat
        ^^^^^^^^^^^^^^^^
        """,
        """
        wrong: Dog = animal;  # <-- Error: Dog | Cat cannot assign to Dog
        ^^^^^^^^^^^^^^^^^^^^
        """,
        """
        d: Dog = animal;  # <-- Error: Cat cannot assign to Dog
        ^^^^^^^^^^^^^^^^
        """,
        """
        d: Dog = animal;  # <-- Error: Cat cannot assign to Dog
        ^^^^^^^^^^^^^^^^
        """,
        """
        s: str = val;  # <-- Error: str | int cannot assign to str
        ^^^^^^^^^^^^^
        """,
        """
        d: Dog = animal;  # <-- Error: Dog | Cat cannot assign to Dog
        ^^^^^^^^^^^^^^^^
        """,
        """
        d: Dog = animal;  # <-- Error: Dog | Cat cannot assign to Dog
        ^^^^^^^^^^^^^^^^
        """,
        """
        d: Dog = animal;  # <-- Error: Cat cannot assign to Dog
        ^^^^^^^^^^^^^^^^
        """,
        """
        r: Reptile = creature;  # <-- Error: Lion cannot assign to Reptile
        ^^^^^^^^^^^^^^^^^^^^^^
        """,
        """
        to_connect.append(nd);  # <-- Error: BaseNode cannot assign to CFGNode
                          ^^
        """,
        """
        return x.bark();  # <-- Error: x is still Dog | None here
               ^^^^
        """,
        # The E1002 "Cannot return <Unknown>" for x.bark() is eliminated
        # because partial union member access now returns the resolved type
        # (from Dog.bark) instead of Unknown.
        """
        result: Dog = x if (x is None) else Dog(name="d");  # <-- Error: x is NoneType in true branch
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        """
    ];

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

test "postinit_fields_not_required_in_constructor" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_postinit_fields.jac");
    mod = program.compile(path, options=NO_TC);
    assert len(program.errors_had) == 0 , f"Expected no type checking errors, but got {len(
        program.errors_had
    )}: "
        + "\n".join([err.pretty_print() for err in program.errors_had]);
    # `postinit` must not emit W1051 on the postinit name.
    w1051 = [
        w
        for w in program.warnings_had
        if w.code and w.code.code == "W1051"
    ];
    assert len(w1051) == 0 , f"Expected no W1051 warnings, but got {len(w1051)}: "
        + "\n".join([w.pretty_print() for w in w1051]);
}

test "impl_body_type_checking" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_impl_body.jac");
    mod = program.compile(path, options=NO_TC);

    assert len(program.errors_had) == 3 , f"Expected 3 type errors, but got {len(
        program.errors_had
    )}: "
        + "\n".join([err.pretty_print() for err in program.errors_had]);
    # Order-independent: all three impl-body errors are reported from the impl
    # file. The order they fire in (an enum member is checked eagerly when its
    # decl is typed, a function/method body when its merged impl is traversed)
    # is an implementation detail, not a contract.
    all_pretty = "\n".join([err.pretty_print() for err in program.errors_had]);
    assert_error_pretty_found(
        """x = "wrong";  # <-- Error: Cannot assign str to int
        ^^^^^^^^^^^^""",
        all_pretty
    );
    assert_error_pretty_found(
        """result = "wrong";  # <-- Error: Cannot assign str to int
        ^^^^^^^^^^^^^^^^^""",
        all_pretty
    );
    assert_error_pretty_found(
        """PENDING: int = "wrong",  # <-- Error: Cannot assign str to int
        ^^^^^^^^^^^^^^^^^^^^^^""",
        all_pretty
    );
    for err in program.errors_had {
        assert "checker_impl_body.impl.jac" in err.loc.mod_path , (
            f"Error not from the impl file: {err.loc.mod_path}"
        );
    }
}

"""Test that self.x = value in impl files creates valid archetype attributes."""
test "impl_self_member_assignment" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_impl", "checker_impl_self_member.jac");
    mod = program.compile(path, options=NO_TC);

    assert len(program.errors_had) == 0 , f"Expected 0 type errors, but got {len(
        program.errors_had
    )}: "
        + "\n".join([err.pretty_print() for err in program.errors_had]);
}

test "super_init_dataclass_no_w1051" {
    # Regression: `super.init(...)` on a parent whose constructor is
    # dataclass-synthesized from `has` fields was emitting a spurious W1051
    # (Unknown expression type) and an E1001 when the call result was assigned
    # to a None-annotated slot. Root cause: _create_dataclass_init_method
    # returned a FunctionType with return_type=UnknownType. Since an implicit
    # __init__ returns None, the synthesized init must reflect that so member
    # calls through `super.init(...)` type cleanly.
    path = os.path.join(CHECKER_FIXTURES, "checker_super_init_dataclass_no_w1051.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    w1051 = [
        w
        for w in program.warnings_had
        if w.code and w.code.code == "W1051"
    ];
    assert len(w1051) == 0 , f"Expected no W1051 on super.init() with synthesized parent init, got {len(
        w1051
    )}:\n"
        + "\n---\n".join(w.pretty_print() for w in w1051);
    assert len(program.errors_had) == 0 , f"Unexpected errors: {[
        e.pretty_print() for e in program.errors_had
    ]}";
}

test "enum_type_checking" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_enum.jac"), options=NO_TC
    );

    expected_errors = [
        "B = \"jac\"",
        "name_err: int = Color.RED.name",
        "value_err: str = Color.BLUE.value",
        "value_status_val_err: int = Status.ACTIVE.value",
        "auto_val_err: str = AutoValueTest.THIRD.value",
        "impl_shape_name_err: int = ShapeType.SQUARE.name",
        "func_wrong_type: str = process_color"
    ];

    assert len(program.errors_had) == len(expected_errors) , f"Expected {len(
        expected_errors
    )} errors, got {len(program.errors_had)}: "
        + "\n".join([err.pretty_print() for err in program.errors_had]);

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

"""Enum metaclass data-attributes resolve to real types, not Unknown.

`__members__`, `_member_names_`, `_member_map_` live on the enum metaclass
(EnumType), not in the enum's MRO. The checker synthesizes their types so
valid usage type-checks (iterating `__members__` yields `str`) while misuse is
still caught. The fixture has exactly one deliberate type error.
"""
test "enum_metaclass_attr_type_checking" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_enum_metaclass_attrs.jac"),
        options=NO_TC
    );

    expected_errors = ["bad: int = Tokens.__members__"];

    assert len(program.errors_had) == len(expected_errors) , f"Expected {len(
        expected_errors
    )} errors, got {len(program.errors_had)}: "
        + "\n".join([err.pretty_print() for err in program.errors_had]);

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

"""Enum member declaration sites should resolve to EnumMemberType.

A Name node declared inside an enum body (e.g. `PERSONAL` in
`enum Category { WORK, PERSONAL, ... }`) represents a specific member of
the enum, not the enum class itself. When the type evaluator is asked for
the type of the symbol, it must return EnumMemberType so that hover info,
assignment checks, and attribute access all see the correct per-member
type. Previously the declaration site fell through to the generic Name
case, producing the enum's ClassType (or Unknown), which caused the IDE
to render `PERSONAL: <Unknown>`.
"""
test "enum_member_declaration_resolves_to_enum_member_type" {
    import from jaclang.compiler.types.types { EnumMemberType }
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_enum_member_decl_type.jac"),
        options=NO_TC
    );

    category_sym = mod.sym_tab.lookup("Category");
    assert category_sym is not None , "Category enum not found in sym_tab";

    # The enum has its own scope containing its members.
    enum_scope: any = category_sym.decl.name_of;
    expected_members = ["WORK", "PERSONAL", "SHOPPING", "HEALTH", "OTHER"];
    for member_name in expected_members {
        member_sym = enum_scope.lookup(member_name, deep=False);
        assert member_sym is not None , f"Member {member_name} not found";
        member_type = program.get_type_evaluator().get_type_of_symbol(member_sym);
        assert isinstance(member_type, EnumMemberType) , (
            f"Expected EnumMemberType for {member_name}, got {type(
                member_type
            ).__name__}: {member_type}"
        );
        assert member_type.member_info is not None;
        assert member_type.member_info.member_name == member_name;
        assert member_type.enum_class is not None;
        assert member_type.enum_class.shared.class_name == "Category";
    }
}

"""Impl-based enum member declarations resolve to EnumMemberType.

Ensures the enum-member detection also works when members are declared
in a separate `impl Color { ... }` block. DeclImplMatchPass links the
ImplDef to its declaring Enum via decl_link, so the type evaluator can
resolve the owning enum from either form uniformly.
"""
test "enum_member_impl_declaration_resolves_to_enum_member_type" {
    import from jaclang.compiler.types.types { EnumMemberType }
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_enum_member_impl_decl_type.jac"),
        options=NO_TC
    );

    color_sym = mod.sym_tab.lookup("Color");
    assert color_sym is not None , "Color enum not found in sym_tab";

    enum_scope: any = color_sym.decl.name_of;
    expected_members = ["RED", "GREEN", "BLUE"];
    for member_name in expected_members {
        member_sym = enum_scope.lookup(member_name, deep=False);
        assert member_sym is not None , f"Member {member_name} not found";
        member_type = program.get_type_evaluator().get_type_of_symbol(member_sym);
        assert isinstance(member_type, EnumMemberType) , (
            f"Expected EnumMemberType for {member_name}, got {type(
                member_type
            ).__name__}: {member_type}"
        );
        member_info = member_type.member_info;
        assert member_info is not None;
        assert member_info.member_name == member_name;
        enum_class = member_type.enum_class;
        assert enum_class is not None;
        assert enum_class.shared.class_name == "Color";
    }
}

test "class_based_enum_type_checking" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_class_enum.jac"), options=NO_TC
    );

    expected_errors = [
        "Cannot assign <Tokens.FLOAT> to int",
        "Cannot assign Literal[\"1\"] to int",
        "Cannot assign Literal[\"LSQUARE\"] to int",
        "Cannot assign Literal[\"RSQUARE\"] to int",
        "Cannot assign <AccessLevel.READ> to str",
        "Cannot assign AccessLevel | NoneType to int",
        "Cannot assign int to str",
        "Cannot assign <Priority.HIGH> to str"
    ];

    assert len(program.errors_had) == len(expected_errors) , f"Expected {len(
        expected_errors
    )} errors, got {len(program.errors_had)}: "
        + "\n".join([err.pretty_print() for err in program.errors_had]);

    for i in range(len(expected_errors)) {
        assert_error_pretty_found(
            expected_errors[i], program.errors_had[i].pretty_print()
        );
    }
}

"""Test assert isinstance type narrowing."""
test "assert_isinstance_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_assert_narrowing.jac"), options=NO_TC
    );

    # Expect exactly 1 error: the failure case where truthy assert doesn't narrow union
    assert len(program.errors_had) == 1 , "Expected 1 type error (truthy assert failure case), but got "
        + f"{len(program.errors_had)}:\n"
        + "\n---\n".join(err.pretty_print() for err in program.errors_had);

    # Verify the error is about accessing .value on a string literal type
    err_msg = program.errors_had[0].pretty_print();
    assert 'has no attribute "value"' in err_msg , f"Expected attribute error, got: {err_msg}";
}

"""Assignment barrier: strict narrowing, widening reset, in-branch re-narrow."""
test "assignment_barrier" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_assignment_barrier.jac"), options=NO_TC
    );
    # The widening reassignment in `widen_via_reassign` resets `x` to
    # `int | None`, so `return x` against the `int` return type is the
    # only expected error.
    assert len(program.errors_had) == 1 , "Expected 1 type error, but got "
        + f"{len(program.errors_had)}:\n"
        + "\n---\n".join(err.pretty_print() for err in program.errors_had);
    msg = program.errors_had[0].pretty_print();
    assert 'Cannot return int | NoneType' in msg , f"Expected widening-reset error, got: {msg}";
}

"""Starred-unpack assignment acts as a narrowing barrier."""
test "starred_unpack_barrier" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_starred_unpack_barrier.jac"),
        options=NO_TC
    );
    # After `(head, *rest) = ...` inside `if rest is not None`, rest
    # must reset to list[int] | None. The typed-local assignment then
    # fails because list[int] | None is not assignable to list[int].
    assert len(program.errors_had) == 1 , "Expected 1 type error, but got "
        + f"{len(program.errors_had)}:\n"
        + "\n---\n".join(err.pretty_print() for err in program.errors_had);
    msg = program.errors_had[0].pretty_print();
    assert 'Cannot assign list[int] | NoneType to list[int]' in msg , f"Expected starred-unpack reset error, got: {msg}";
}

"""Tuple-unpacking assignment acts as a narrowing barrier."""
test "tuple_unpack_barrier" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_tuple_unpack_barrier.jac"),
        options=NO_TC
    );
    # After `(x, _) = reset_pair()` inside `if x is not None`, x must
    # reset to int | None. `return x` then fails against int.
    assert len(program.errors_had) == 1 , "Expected 1 type error, but got "
        + f"{len(program.errors_had)}:\n"
        + "\n---\n".join(err.pretty_print() for err in program.errors_had);
    msg = program.errors_had[0].pretty_print();
    assert 'Cannot return int | NoneType' in msg , f"Expected widening-reset error, got: {msg}";
}

"""Destructuring assignment narrows by RHS element type when available."""
test "destructure_element_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_destructure_element_narrowing.jac"),
        options=NO_TC
    );
    # Four narrowing cases must succeed; only `no_narrow_non_strict`
    # should error because its RHS element type matches the declared
    # type and therefore fails the strict-narrowing check.
    assert len(program.errors_had) == 1 , "Expected 1 type error, but got "
        + f"{len(program.errors_had)}:\n"
        + "\n---\n".join(err.pretty_print() for err in program.errors_had);
    msg = program.errors_had[0].pretty_print();
    assert 'Cannot return int | str' in msg , f"Expected non-strict-narrow error, got: {msg}";
}

"""Per-position tuple index typing + variadic destructuring (issue #7238)."""
test "tuple_index_typing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_tuple_index_typing.jac"), options=NO_TC
    );
    # Only `per_position_mismatch` errors: `t[1]` is bytes, assigned to str.
    assert len(program.errors_had) == 1 , "Expected 1 type error, but got "
        + f"{len(program.errors_had)}:\n"
        + "\n---\n".join(err.pretty_print() for err in program.errors_had);
    msg = program.errors_had[0].pretty_print();
    assert 'Cannot assign bytes to str' in msg , f"Expected per-position mismatch, got: {msg}";
}

"""Match-case narrowing is killed by a later assignment to the subject."""
test "match_case_reassign_reset" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_match_case_reassign_reset.jac"),
        options=NO_TC
    );
    assert len(program.errors_had) == 4 , "Expected 4 type errors, but got "
        + f"{len(program.errors_had)}:\n"
        + "\n---\n".join(err.pretty_print() for err in program.errors_had);
    assert 'Cannot assign int to Shape' in program.errors_had[0].pretty_print();
    for i in [1, 2, 3] {
        msg = program.errors_had[i].pretty_print();
        assert 'has no attribute "sides"' in msg , f"Expected attribute error at index {i}, got: {msg}";
    }
}

"""Test impl files can access imports from their parent .jac file."""
test "impl_imports_from_parent" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_impl_imports.jac");
    mod = program.compile(path, options=NO_TC);

    # Should have 3 errors for type mismatches with jaclang types (not Python stdlib)
    assert len(program.errors_had) == 3 , f"Expected 3 type errors, but got {len(
        program.errors_had
    )}: "
        + "\n".join([err.pretty_print() for err in program.errors_had]);

    # Verify errors reference jaclang types (ClassType, FunctionType), not Python stdlib
    assert_error_pretty_found(
        """x: types.ClassType = 90;  # <-- Error: Cannot assign int to ClassType""",
        program.errors_had[0].pretty_print()
    );
    assert "checker_impl_imports.impl.jac" in program.errors_had[0].loc.mod_path;

    assert_error_pretty_found(
        """y: types.FunctionType = "wrong";  # <-- Error: Cannot assign str to FunctionType""",
        program.errors_had[1].pretty_print()
    );
    assert "checker_impl_imports.impl.jac" in program.errors_had[1].loc.mod_path;
}

"""Unresolvable Union[('A', 'B')] strings still degrade to Literal (safety net)."""
test "union_string_forward_refs_unresolved" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_union_forward_ref_unresolved.jac"),
        options=NO_TC
    );
    user_errors = [
        err
        for err in program.errors_had
        if "vendor" not in err.loc.mod_path and "typeshed" not in err.loc.mod_path
    ];
    assert len(user_errors) == 1 , (
        f"Expected 1 error for int return to Literal union, got {len(user_errors)}: "
        + "\n".join([e.pretty_print() for e in user_errors])
    );
    assert user_errors[0].code and user_errors[0].code.code == "E1002" , (
        f"Expected E1002 return mismatch, got {user_errors[0].code.code
            if user_errors[0].code
            else '?'}"
    );
}

"""Test __getattr__ support: dynamic attrs use __getattr__ return type."""
test "getattr_support" {
    program = JacProgram();
    path = os.path.join(FIXTURES, "checker_getattr_support.jac");
    mod = program.compile(path, options=NO_TC);

    user_errors = [
        err
        for err in program.errors_had
        if "vendor" not in err.loc.mod_path and "typeshed" not in err.loc.mod_path
    ];

    # Expect 2 errors:
    # 1. assigning str to int (proves __getattr__ return type is enforced)
    # 2. NoGetAttr.nonexistent (correct: class has no __getattr__ and no such attribute)
    assert len(user_errors) == 2 , f"Expected 2 errors, got {len(user_errors)}";
    assert "Cannot assign" in user_errors[0].pretty_print();
    assert "has no attribute" in user_errors[1].pretty_print();
}

"""Test NamedTuple type checking: constructor accepts positional arguments for fields."""
test "namedtuple_constructor" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_namedtuple.jac");
    mod = program.compile(path, options=NO_TC);

    user_errors = [
        err
        for err in program.errors_had
        if "vendor" not in err.loc.mod_path and "typeshed" not in err.loc.mod_path
    ];

    # NamedTuple should accept positional arguments for fields - no errors expected
    assert len(user_errors) == 0 , f"Expected 0 errors for NamedTuple, got {len(
        user_errors
    )}: "
        + "\n".join([err.pretty_print() for err in user_errors]);
}

"""Test overload resolution prefers concrete types over Unknown in type_args.

When a method has multiple overloads (e.g., str.split), and one returns
list[LiteralString] (Unknown) and another returns list[str], the type
checker should prefer the concrete list[str] overload.
"""
test "overload_resolution_concrete_types" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_overload_resolution.jac");
    mod = program.compile(path, options=NO_TC);

    user_errors = [
        err
        for err in program.errors_had
        if "vendor" not in err.loc.mod_path and "typeshed" not in err.loc.mod_path
    ];

    # str.split() -> list[str], list[str][0] -> str, str + str -> str
    # No errors expected when overload resolution picks concrete types
    assert len(user_errors) == 0 , f"Expected 0 errors, got {len(user_errors)}: "
        + "\n".join([err.pretty_print() for err in user_errors]);
}

test "literal_string_type_checking" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_literal_string.jac");
    mod = program.compile(path, options=NO_TC);

    user_errors = [
        err
        for err in program.errors_had
        if "vendor" not in err.loc.mod_path and "typeshed" not in err.loc.mod_path
    ];

    assert len(user_errors) == 2 , f"Expected 2 errors, got {len(user_errors)}: "
        + "\n".join([err.pretty_print() for err in user_errors]);

    assert_error_pretty_found(
        """Cannot assign Literal["not an int"] to int""", user_errors[0].pretty_print()
    );
    assert_error_pretty_found(
        """Cannot assign Literal["wrong"] to parameter 'n' of type int""",
        user_errors[1].pretty_print()
    );
}

"""Test module-level function overload resolution.

Module-level functions like math.floor have multiple @overload signatures.
The type checker must collect all overloads and try each one when checking
argument compatibility. This ensures that math.floor(3.7) resolves to the
_SupportsFloatOrIndex overload (returning int) rather than failing on the
_SupportsFloor protocol overload.
"""
test "module_level_overload" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_module_level_overload.jac");
    mod = program.compile(path, options=NO_TC);

    user_errors = [
        err
        for err in program.errors_had
        if "vendor" not in err.loc.mod_path and "typeshed" not in err.loc.mod_path
    ];

    # Expect 1 error: assigning math.sin(float) -> float to int
    assert len(user_errors) == 1 , f"Expected 1 error, got {len(user_errors)}: "
        + "\n".join([err.pretty_print() for err in user_errors]);

    assert_error_pretty_found(
        """Cannot assign float to int""", user_errors[0].pretty_print()
    );
}

"""Verifies two import resolution fixes:
- MyClass: arrived via star re-export chain fix (modresolver local-first for relative imports)
- subpkg: resolved as ModuleType fix (subpackage __init__.py treated correctly)
"""
test "py_pkg_imports" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_py_pkg_imports.jac"), options=NO_TC
    );
    assert len(program.errors_had) == 0;
    assert mod.sym_tab.lookup("MyClass") is not None , "MyClass not in sym_tab - star re-export chain broken";
    assert mod.sym_tab.lookup("subpkg") is not None , "subpkg not in sym_tab - subpackage resolution broken";
}

"""Test stdlib star re-export resolution (e.g., asyncio.Queue from asyncio.queues).

Ensures the type checker follows star imports in stub files so that
symbols like Queue, SimpleQueue are not Unknown.
"""
test "stdlib_star_reexport" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_stdlib_star_reexport.jac"),
        options=NO_TC
    );
    assert len(program.errors_had) == 0 , f"Expected no type errors, but got {len(
        program.errors_had
    )}:\n"
        + "\n---\n".join(err.pretty_print() for err in program.errors_had);
    assert mod.sym_tab.lookup("Queue") is not None , "Queue not resolved - asyncio star re-export broken";
    assert mod.sym_tab.lookup("SimpleQueue") is not None , "SimpleQueue not resolved - queue star re-export broken";
}

# =============================================================================
# Generic Type Inference Tests (Pyright-style)
# =============================================================================
test "enumerate_type_inference" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_gap_enumerate_type.jac");
    mod = program.compile(path, options=NO_TC);
    assert len(program.errors_had) == 2 , f"Expected 2 type errors, got {len(
        program.errors_had
    )}";
    errors_str = "\n".join(e.pretty_print() for e in program.errors_had);
    assert "Cannot assign int to str" in errors_str;
    assert "Cannot assign Item to int" in errors_str;
}

test "generic_call_inference" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_gap_generic_call_inference.jac");
    mod = program.compile(path, options=NO_TC);
    assert len(program.errors_had) == 2 , f"Expected 2 type errors, got {len(
        program.errors_had
    )}";
    errors_str = "\n".join(e.pretty_print() for e in program.errors_had);
    assert "Cannot assign Item to str" in errors_str;
    assert "Cannot assign Item to int" in errors_str;
}

"""Test bidirectional type inference for container literals and type[X] covariance."""
test "bidirectional_container_inference" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_bidirectional_container.jac");
    mod = program.compile(path, options=NO_TC);
    # 5 errors: bad_list return, bad_dict return, bad_set return,
    # bad list assignment, bad type[int] assignment
    assert len(program.errors_had) == 5 , f"Expected 5 type errors, got {len(
        program.errors_had
    )}:\n"
        + "\n".join(e.pretty_print() for e in program.errors_had);

    errors_str = "\n".join(e.pretty_print() for e in program.errors_had);
    # Container literal mismatches show parameterized types in error messages
    assert "list[Dog | Cat], expected list[int]" in errors_str , "Expected parameterized list error";
    assert "dict[" in errors_str and "expected dict[str, int]" in errors_str , "Expected parameterized dict error";
    assert "set[Dog], expected set[int]" in errors_str , "Expected parameterized set error";
    # Assignment mismatch with parameterized types
    assert "list[Dog] to list[int]" in errors_str , "Expected parameterized list assign error";
    # type[X] covariance: Dog is not subclass of int
    assert "Dog to type[int]" in errors_str , "Expected type[int] covariance error";
}

"""Test Self type resolution in method return types."""
test "self_type_resolution" {
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_gap_self_type.jac");
    mod = program.compile(path, options=NO_TC);
    # Should have 3 errors for enumerate, list, and dict Self returns
    assert len(program.errors_had) == 3 , f"Expected 3 type errors, got {len(
        program.errors_had
    )}";

    errors_str = "\n".join(e.pretty_print() for e in program.errors_had);
    assert "Cannot assign enumerate to int" in errors_str , "Expected error for enumerate.__iter__() Self return";
    assert "Cannot assign list" in errors_str and "to int" in errors_str , "Expected error for list.copy() Self return";
    assert "Cannot assign dict" in errors_str and "to str" in errors_str , "Expected error for dict.copy() Self return";
}

"""Typed-base enum syntax: members of `enum X: int` are int instances.

`enum X: int { ... }` desugars to `class X(IntEnum)` and members satisfy
`list[int]`/int positions without `.value`. `enum X: str` mirrors that
with str. Custom `enum X: T` uses Python's mixin pattern. Plain
`enum X { ... }` keeps the prior behavior — members are NOT int.
"""
test "enum_typed_base" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_enum_typed_base.jac"), options=NO_TC
    );
    # Exactly one error expected: `bad: list[int] = [Plain.A, Plain.B]`
    # (plain Enum members are not int instances).
    assert len(program.errors_had) == 1 , f"Expected 1 type error, got {len(
        program.errors_had
    )}:\n"
        + "\n".join(e.pretty_print() for e in program.errors_had);
    err_text = program.errors_had[0].pretty_print();
    assert "Plain" in err_text and "int" in err_text , (
        "Expected the single error to flag the Plain.A/Plain.B → list[int] "
        f"assignment; got: {err_text}"
    );
}

"""Attribute access on a `Self`-typed value resolves via the enclosing class.

Regression for the E1031 raised on `unloaded.id = self.id;` in
jac/jaclang/runtime/impl/archetype.impl.jac, where
`object.__new__(self.__class__)` returns Self and the checker treated Self as an
unbounded TypeVar with no member access. After the fix, attribute access on a
Self-typed value resolves via the enclosing class — Pyright behavior.
"""
test "self_typevar_attr_access_via_enclosing_class" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_self_type_attr_access.jac"),
        options=NO_TC
    );
    user_errors = [
        err
        for err in program.errors_had
        if "vendor" not in err.loc.mod_path and "typeshed" not in err.loc.mod_path
    ];
    assert len(user_errors) == 0 , f"Expected 0 user errors, got {len(user_errors)}:\n"
        + "\n".join(e.pretty_print() for e in user_errors);
    # Defensive: even any vendor-side errors must not still claim "type Self"
    # for the user fixture's positions — that would mean the fix didn't take.
    for err in program.errors_had {
        if "checker_self_type_attr_access" in err.loc.mod_path {
            assert "type \"Self\"" not in err.pretty_print() , f"Error should not refer to opaque Self type, got:\n{err.pretty_print()}";
        }
    }
}

"""Self-typed return values resolve via the receiver class for chained and
indirected access (issue #5688)."""
test "self_class_member_access_5688" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_self_class_member_access.jac"),
        options=NO_TC
    );
    user_errors = [
        err
        for err in program.errors_had
        if "vendor" not in err.loc.mod_path and "typeshed" not in err.loc.mod_path
    ];
    assert len(user_errors) == 0 , f"Expected 0 user errors, got {len(user_errors)}:\n"
        + "\n".join(e.pretty_print() for e in user_errors);
    for err in program.errors_had {
        if "checker_self_class_member_access" in err.loc.mod_path {
            assert "type \"Self\"" not in err.pretty_print() , f"Error should not refer to opaque Self type, got:\n{err.pretty_print()}";
        }
    }
}

# ============================================================================
# Narrowing gap exposure tests
#
# These tests document known type checker narrowing limitations.
# Each test asserts the CURRENT (broken) error count. When a gap is fixed,
# the error count should decrease — update the assertion accordingly.
# The fixture has ok_ functions (should pass) and fail_ functions (currently broken).
# ============================================================================
"""Gap A: Early return narrowing after nested if block join points.

After `if val is None { return; }`, val is narrowed to non-None for the entire
rest of the function. Fixed by propagating affected_symbols through already-linked
internal CFG nodes when sibling-to-sibling edges are created in _link_sequential.
"""
test "narrowing_gap_a_early_return_after_nested_if" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_gaps.jac"), options=NO_TC
    );

    # Gap A errors are on lines 85-129 (fail_early_return_* and fail_truthiness/isinstance variants)
    gap_a_errors = [
        e
        for e in program.errors_had
        if e.loc and 85 <= e.loc.first_line <= 129
    ];
    # FIXED: CFG affected_symbols propagation now reaches internal nodes
    assert len(gap_a_errors) == 0 , f"Gap A should have 0 errors (fixed), got {len(
        gap_a_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in gap_a_errors);
}

"""Gap B: Ternary narrowing applied to function arguments in ternary branches.

In `use_foo(val) if isinstance(val, Foo) else 0`, the ternary handler correctly
narrows `val` in the true branch. Fixed by eagerly evaluating the IfElseExpr in
enter_if_else_expr so narrowing scopes are active before children are visited.
"""
test "narrowing_gap_b_ternary_fn_arg" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_gaps.jac"), options=NO_TC
    );

    # Gap B errors are on lines 155-170 (fail_ternary_*_fn_arg functions)
    gap_b_errors = [
        e
        for e in program.errors_had
        if e.loc and 155 <= e.loc.first_line <= 170
    ];
    # FIXED: eagerly evaluating IfElseExpr in enter_if_else_expr caches narrowed
    # types on child nodes before the walker visits them.
    assert len(gap_b_errors) == 0 , f"Gap B should have 0 errors (fixed), got {len(
        gap_b_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in gap_b_errors);
}

"""Gap C: Ternary narrowing applied to attribute access on narrowed variable.

In `val.attr if val else 0`, the true branch correctly narrows `val` from T|None
to T. Fixed by eagerly evaluating IfElseExpr (same fix as Gap B).
"""
test "narrowing_gap_c_ternary_attr_access" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_gaps.jac"), options=NO_TC
    );

    # Gap C errors are on lines 180-196 (fail_ternary_attr_* functions)
    gap_c_errors = [
        e
        for e in program.errors_had
        if e.loc and 180 <= e.loc.first_line <= 196
    ];
    # FIXED: same root cause as Gap B — eagerly evaluating IfElseExpr resolves this.
    assert len(gap_c_errors) == 0 , f"Gap C should have 0 errors (fixed), got {len(
        gap_c_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in gap_c_errors);
}

"""Verify ok_ functions in narrowing gaps fixture produce no errors.

The ok_ prefixed functions test patterns that DO work correctly and should
never regress. This test ensures they remain error-free.
"""
test "narrowing_gaps_ok_functions_no_errors" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_gaps.jac"), options=NO_TC
    );

    # ok_ functions are on lines 64-82 — these should produce no errors
    ok_errors = [
        e
        for e in program.errors_had
        if e.loc and 64 <= e.loc.first_line <= 82
    ];
    assert len(ok_errors) == 0 , f"ok_ functions should produce no errors, got {len(
        ok_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in ok_errors);
}

"""Gap D: Assignment in if-body narrows type after the if block."""
test "narrowing_gap_d_assign_in_if_body" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_gaps.jac"), options=NO_TC
    );

    # Gap D ok_ functions: lines 210-300 (includes try/finally pattern)
    gap_d_errors = [
        e
        for e in program.errors_had
        if e.loc and 210 <= e.loc.first_line <= 300
    ];
    assert len(gap_d_errors) == 0 , f"Gap D should have 0 errors (fixed), got {len(
        gap_d_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in gap_d_errors);
}

# ============================================================================
# Runtime.impl.jac type checker issues
# These document false positive errors found in runtime.impl.jac.
# ============================================================================
"""Runtime narrowing: truthiness + isinstance on attribute access in `and` chains.

Tests that `obj.attr and isinstance(obj.attr, T)` correctly narrows obj.attr
from a multi-member union through both truthiness and isinstance. Uses AtomTrailer
nodes (attribute access) to match the real runtime.impl.jac patterns.
"""
test "runtime_attr_truthiness_and_isinstance_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_runtime_errors.jac"), options=NO_TC
    );

    # Issue 1 ok_ functions: lines 60-100 (attr truthiness, isinstance, loop patterns)
    i1_errors = [
        e
        for e in program.errors_had
        if e.loc and 60 <= e.loc.first_line <= 100
    ];
    assert len(i1_errors) == 0 , f"Attr truthiness/isinstance narrowing should produce 0 errors, got {len(
        i1_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in i1_errors);
}

"""Runtime narrowing: compound `or` guard on attribute access after early exit.

Tests that after `if (not obj or not obj.attr) { raise/return; }`, obj is narrowed
to non-None for subsequent attribute access. Uses AtomTrailer nodes to match the
real runtime.impl.jac `spec` pattern.
"""
test "runtime_compound_or_guard_attr_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_runtime_errors.jac"), options=NO_TC
    );

    # Issue 2 ok_ functions: lines 120-175 (compound or guard patterns)
    i2_errors = [
        e
        for e in program.errors_had
        if e.loc and 120 <= e.loc.first_line <= 175
    ];
    assert len(i2_errors) == 0 , f"Compound or guard narrowing should produce 0 errors, got {len(
        i2_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in i2_errors);
}

"""Ternary isinstance narrowing should exclude generic types (list[T]) from union."""
test "runtime_ternary_isinstance_generic_narrowing" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_runtime_errors.jac"), options=NO_TC
    );

    # Issue 3 ok_ functions: lines 195-230 (ternary isinstance with generic types)
    i3_errors = [
        e
        for e in program.errors_had
        if e.loc and 195 <= e.loc.first_line <= 230
    ];
    assert len(i3_errors) == 0 , f"Ternary isinstance generic narrowing should produce 0 errors, got {len(
        i3_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in i3_errors);
}

"""isinstance narrowing should preserve generic type parameters from union members."""
test "runtime_isinstance_preserves_generic_params" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_runtime_errors.jac"), options=NO_TC
    );

    # Issue 4 ok_ functions: lines 240-290 (isinstance preserving generics)
    i4_errors = [
        e
        for e in program.errors_had
        if e.loc and 240 <= e.loc.first_line <= 290
    ];
    assert len(i4_errors) == 0 , f"isinstance generic preservation should produce 0 errors, got {len(
        i4_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in i4_errors);
}

# ============================================================================
# Root cause tests for type checker limitations (from runtime.impl.jac)
#
# Each test documents a key type checker root cause with minimal reproduction.
# Tests assert the CURRENT (broken) error count. When a root cause is fixed,
# the error count should drop to 0 — update the assertion accordingly.
# ============================================================================
"""Root Cause 1: No narrowing after `raise`.

After `if obj.attr is None { raise ...; }`, obj.attr should be narrowed from
T|None to T. Currently the type checker doesn't narrow through raise, so
subsequent attribute access on obj.attr produces false positive E1099 errors.

Mirrors: runtime.impl.jac lines 1964-1978 (JacRuntime.program.mtir_map after
raise on None check).
"""
test "root_cause_1_raise_does_not_narrow" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );

    # ok_ function (line 96-101) must produce no errors
    ok_errors = [
        e
        for e in program.errors_had
        if e.loc
            and str(e.loc.mod_path).endswith("checker_narrowing_root_causes.jac")
            and 96 <= e.loc.first_line <= 101
    ];
    assert len(ok_errors) == 0 , f"ok_raise_narrowing_simple should have 0 errors, got {len(
        ok_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in ok_errors);

    # fail_ functions (lines 105-134) currently produce false positive errors
    rc1_errors = [
        e
        for e in program.errors_had
        if e.loc
            and str(e.loc.mod_path).endswith("checker_narrowing_root_causes.jac")
            and 105 <= e.loc.first_line <= 134
    ];
    # FIXED: Raise narrowing now promotes inverted narrowings to parent scope.
    assert len(rc1_errors) == 0 , f"Expected 0 raise-narrowing errors (fixed), got {len(
        rc1_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in rc1_errors);
}

"""Root Cause 2: Unknown type cascades into N errors.

When an attribute access resolves to Unknown (e.g., accessing a subclass-only
attribute through a base-class reference), every subsequent access on that
Unknown value produces another E1032 error. One root cause produces N errors.

Mirrors: runtime.impl.jac lines 933-952 (Memory.l3 -> Unknown -> .values()).
"""
test "root_cause_2_unknown_cascade" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );

    # fail_ functions (lines 148-162) — one root E1030 cascades into E1032s
    rc2_errors = [
        e
        for e in program.errors_had
        if e.loc and 148 <= e.loc.first_line <= 162
    ];
    # Cascading E1032 suppressed for chained AtomTrailer/FuncCall targets.
    # Name targets still report: persistence.some_attr, data.values() are first
    # attribute accesses on Unknown variables — each is a real diagnostic.
    # 5: 2 root E1030 + 2 E1032 on Name targets + 1 return mismatch.
    assert len(rc2_errors) == 5 , f"Expected 5 unknown-cascade errors, got {len(
        rc2_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in rc2_errors);
}

"""Root Cause 3: Callable type annotation resolves to _SpecialForm.

When a parameter is annotated as `Callable`, the checker resolves the type to
`_SpecialForm` (typing internal) instead of the actual callable protocol. This
means __name__ access fails and passing Callable to Callable[...] fails.

Mirrors: runtime.impl.jac lines 1204-1212 (test_fun: Callable -> __name__),
line 1837 (caller: Callable -> _SpecialForm).
"""
test "root_cause_3_callable_as_special_form" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );

    # fail_ functions (lines 175-193) — Callable resolves to _SpecialForm
    rc3_errors = [
        e
        for e in program.errors_had
        if e.loc and 175 <= e.loc.first_line <= 193
    ];
    # FIXED: Bare Callable now resolves to FunctionType (gradual form).
    assert len(rc3_errors) == 0 , f"Expected 0 callable errors (fixed), got {len(
        rc3_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in rc3_errors);
}

"""Root Cause 4: Assignment to narrowed-None field rejected.

Inside `if dest.nd is None { dest.nd = value; }`, the checker narrows dest.nd
to NoneType in the true branch. But reassignment with a valid value should be
accepted — the checker incorrectly rejects it as "Cannot assign T to NoneType".

Mirrors: runtime.impl.jac line 1353 (last.nd = post_filter after `is None` check).
"""
test "root_cause_4_assign_to_narrowed_none" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );

    # fail_ function (lines 208-216) — assign Callable to narrowed-NoneType field
    rc4_errors = [
        e
        for e in program.errors_had
        if e.loc and 208 <= e.loc.first_line <= 216
    ];
    # FIXED: Assignment now uses declared field type, not narrowed type.
    assert len(rc4_errors) == 0 , f"Expected 0 assign-to-narrowed-None errors (fixed), got {len(
        rc4_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in rc4_errors);
}

"""Root Cause 5: String slicing loses type information.

When a str is sliced (s[1:], s[:-3]) or indexed (s[0]), the type checker resolves
the result to Unknown instead of str. Subsequent string method calls fail with E1032.

Mirrors: runtime.impl.jac line 1096 (chomp_target = chomp_target[1:] -> .startswith fails).
"""
test "root_cause_5_string_slice_preserves_type" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );

    # Regression guard for the former "string slice loses type" root cause.
    # The pass_ functions exercise the three patterns that used to degrade
    # str to Unknown. They must type-check cleanly. See the fixture header
    # comment above the pass_string_* functions for the full fix summary.
    rc5_errors = [
        e
        for e in program.errors_had
        if e.loc and 239 <= e.loc.first_line <= 258
    ];
    assert len(rc5_errors) == 0 , f"Expected 0 string-slice errors, got {len(
        rc5_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in rc5_errors);
}

"""Root Cause 6: Stdlib return types resolve to Unknown.

When calling stdlib functions like importlib.util.spec_from_file_location,
the return type resolves to Unknown instead of ModuleSpec|None. All subsequent
attribute access (.origin, .loader, .submodule_search_locations) cascades.
This is the single largest source of errors in runtime.impl.jac (~20 errors).

Mirrors: runtime.impl.jac lines 1118-1165 (spec_from_file_location chain).
"""
test "root_cause_6_stdlib_returns_unknown" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );

    # fail_ functions (lines 267-305) — importlib.util returns Unknown
    rc6_errors = [
        e
        for e in program.errors_had
        if e.loc and 267 <= e.loc.first_line <= 305
    ];
    # 1 (down from 11): aliased stub re-exports are followed now, so
    # spec_from_file_location types as `ModuleSpec | None`, the truthiness
    # guards narrow it, and the Unknown cascades are gone. The one remaining
    # error is real fixture code: `exec_module(None)` passes NoneType where
    # a ModuleType parameter is declared.
    assert len(rc6_errors) == 1 , f"Expected 1 stdlib error, got {len(rc6_errors)}:\n"
        + "\n---\n".join(e.pretty_print() for e in rc6_errors);
}

"""Root Cause 7: Nullable attribute access without raise guard.

When a field is typed as T|None (like user_root: NodeAnchor|None) and code
accesses attributes on it without an explicit None check, or through a ternary
where one branch is nullable, the checker correctly flags it. These are real
bugs in runtime.impl.jac that produce E1099 errors.

Mirrors: runtime.impl.jac lines 930-952 (ranchor from ternary with nullable),
line 961 (user_root.archetype), line 1576 (user_root.id).
"""
test "root_cause_7_nullable_attr_access" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );

    # fail_ functions (lines 316-350) — nullable access without guard
    rc7_errors = [
        e
        for e in program.errors_had
        if e.loc and 316 <= e.loc.first_line <= 350
    ];
    # 4 errors: 4 E1099 (attr missing from NoneType). Previously 8 because
    # each E1099 returned Unknown, cascading to E1002 "return Unknown". Now
    # partial union member access returns the resolved type, eliminating cascades.
    assert len(rc7_errors) == 4 , f"Expected 4 nullable-access errors, got {len(
        rc7_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in rc7_errors);
}

"""Root Cause 8: Dynamic / runtime class attributes not recognized.

When code accesses attributes that are set dynamically at runtime (via setattr,
type(), or metaclass magic), the checker doesn't know about them. Also, accessing
attributes on object-typed params fails because object has a minimal interface.

Mirrors: runtime.impl.jac line 1001 (type[Archetype].reports),
line 1947 (JacByLLM._default_llm_instance), line 1888 (object.call_params),
line 2221 (ThreadPoolExecutor.submit).
"""
test "root_cause_8_dynamic_class_attrs" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );

    # fail_ functions (lines 360-390) — dynamic attrs and stdlib methods
    rc8_errors = [
        e
        for e in program.errors_had
        if e.loc and 360 <= e.loc.first_line <= 390
    ];
    # 3 errors: type[Archetype].reports, WalkerArchetype._instance,
    # object.call_params. The former 4th (executor.submit on a then-Unknown
    # ThreadPoolExecutor) went away after the relative .pyi re-export fix
    # loaded concurrent/futures stubs and typing/typing_extensions ParamSpec
    # parity let Callable[_P, _T] accept the lambda gradually.
    assert len(rc8_errors) == 3 , f"Expected 3 dynamic-attr errors, got {len(
        rc8_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in rc8_errors);
}

"""Root Cause 9: Union with Any blocks attribute access.

When a type is a union containing Any (e.g., Any | EdgeArchetype), the checker
reports that Any doesn't have the attribute, even though Any should be compatible
with all attribute access by definition.

Mirrors: runtime.impl.jac line ~1400 (__jac__ on Any | EdgeArchetype | GenericEdge).
"""
test "root_cause_9_any_in_union" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );

    # fail_ functions (lines 396-415) — Any in union blocks attr access
    rc9_errors = [
        e
        for e in program.errors_had
        if e.loc and 396 <= e.loc.first_line <= 415
    ];
    # 1 error. The any-in-union attr-access bug is fixed (#7158): `any`
    # absorbs, so no E1099 "missing from any" is emitted here.
    #
    # This was 2 while the fixture spelled the union member `Any` without
    # importing it: an unbound name made the whole union Unknown, so
    # `edge.__jac__` errored for a reason that had nothing to do with union
    # handling. Spelling it `any` lets the absorb actually run, and that
    # error is gone. What remains is one E1053 in fail_any_in_union_method:
    # `(any | str).upper()` yields Unknown rather than `str | any`, so it
    # cannot pass as Sized -- a real remaining gap, which is what this
    # fixture exists to pin.
    assert len(rc9_errors) == 1 , f"Expected 1 any-in-union error, got {len(
        rc9_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in rc9_errors);
}

"""Issue #7158: `Any` must absorb inside a union for attribute access.

`typing.Any` used as an annotation resolves to the `Any` class (not the
internal `AnyType`), so attribute-access handling must recognize that form as a
wildcard: access on `T | ... | Any` validates only the non-`Any` members and
yields `result | Any` instead of reporting the attribute missing from `Any`.
Assignability is intentionally left strict -- explicit `Any` in a union is held
to the same rule as bare explicit `Any -> Concrete` -- so the fixture exercises
the attribute-access path plus a no-`Any` concrete-union assignment; it is
entirely well-typed and must produce zero errors.
"""
test "any_in_union_is_wildcard" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_any_in_union.jac"), options=NO_TC
    );

    errors = [
        e
        for e in program.errors_had
        if e.code is not None and e.code.code in ("E1099", "E1053", "E1002", "E1032")
    ];
    assert len(errors) == 0 , f"Expected 0 any-in-union errors, got {len(errors)}:\n"
        + "\n---\n".join(e.pretty_print() for e in errors);
}

"""Root Cause 10: TypeVar in impl blocks.

A TypeVar defined at module level works in standalone def functions, but when
used in an impl block, the checker reports E1065: "Type variable T has no
meaning in this context."

Mirrors: runtime.jac line 76 (glob T = TypeVar('T')) and
runtime.impl.jac line 1506 (impl JacBasics.assign_all(target: list[T])).
"""
test "root_cause_10_typevar_in_impl" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_typevar_impl.jac"), options=NO_TC
    );

    # The impl file should NOT trigger E1065 — module-level TypeVars are valid
    rc10_errors = [
        e
        for e in program.errors_had
        if e.code is not None and e.code.code == "E1065"
    ];
    # FIXED: Module-level TypeVars are now recognized in impl blocks.
    assert len(rc10_errors) == 0 , f"Expected 0 TypeVar-in-impl errors (fixed), got {len(
        rc10_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in rc10_errors);
}

"""Baseline: TypeVar in standalone def should produce no E1065 errors."""
test "root_cause_10_typevar_in_def_ok" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );

    # ok_typevar_in_def (lines 420-425) — should have no E1065 errors
    ok_errors = [
        e
        for e in program.errors_had
        if e.loc
            and 420 <= e.loc.first_line <= 425
            and e.code is not None
            and e.code.code == "E1065"
    ];
    assert len(ok_errors) == 0 , f"TypeVar in def should have 0 E1065 errors, got {len(
        ok_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in ok_errors);
}

"""Total error count for root causes fixture."""
test "root_causes_total_error_count" {
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_narrowing_root_causes.jac"),
        options=NO_TC
    );

    # 24 errors located in the fixture itself (the count is scoped to the
    # fixture file: stub-evaluation diagnostics such as typeshed E0075 are
    # attributed to whichever program first evaluates the stub classes, so
    # an unscoped count is process-order-dependent). Down from 25: Root
    # Cause 9's union member is spelled `any` now instead of an `Any` the
    # fixture never imported, so the union absorbs instead of collapsing to
    # Unknown and one error there is gone (see root_cause_9_any_in_union).
    # 25 was down from 29: dotted stdlib submodules (`importlib.util`)
    # resolve through ModuleType attribute access, removing the
    # `.util`-on-Unknown errors from the Root Cause 6 corpus. Before that,
    # 29 was down from 35: partial union member access returning resolved
    # types instead of Unknown eliminated 6 cascading errors.
    _fixture_errors = [
        e
        for e in program.errors_had
        if e.loc and str(e.loc.mod_path).endswith("checker_narrowing_root_causes.jac")
    ];
    # Down from 24 to 14: Root Cause 6's spec_from_file_location chain
    # types as `ModuleSpec | None` now that aliased stub re-exports are
    # followed, so its ten Unknown cascades are gone; the member-miss fix
    # (inherited object.__getattribute__ no longer resolves every miss to
    # Any) restored the E1030s the dynamic-attr root causes always expected.
    assert len(_fixture_errors) == 14 , f"Expected 14 fixture errors, got {len(
        _fixture_errors
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in _fixture_errors);
}

"""MRO resolves correctly when base class imported through Python __init__.py re-export."""
test "bare_generic_iteration_yields_any" {
    # Bare generic types like `list` (no type args) should be treated as
    # list[Any] per PEP 484, so iterating yields Any (not Unknown).
    # Only the typed list[int] assignment mismatch should error.
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_bare_generic_iteration.jac"),
        options=NO_TC
    );

    assert len(program.errors_had) == 1 , f"Expected 1 error (int->str), got {len(
        program.errors_had
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in program.errors_had);
    assert_error_pretty_found(
        """
        b: str = t;   # <-- Error (int not assignable to str)
        ^^^^^^^^^^^
    """,
        program.errors_had[0].pretty_print()
    );

    # Bare generics should produce W1036 warnings nudging toward explicit type args
    bare_generic_warnings = [
        w
        for w in program.warnings_had
        if "W1036" in w.pretty_print()
    ];
    assert len(bare_generic_warnings) == 3 , f"Expected 3 W1036 warnings (list, dict, list), got {len(
        bare_generic_warnings
    )}:\n"
        + "\n---\n".join(w.pretty_print() for w in bare_generic_warnings);
}

test "bare_generic_in_signatures_emits_w1036" {
    # Bare generics in function/method return types and parameter types should
    # also produce W1036 — same as in `has` fields and assignments.
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_bare_generic_signatures.jac"),
        options=NO_TC
    );

    bare_generic_warnings = [
        w
        for w in program.warnings_had
        if "W1036" in w.pretty_print()
    ];
    # Expected sites (8 total):
    #   1. `-> list`              return type
    #   2. `x: dict`               param type
    #   3. `-> list | None`        union branch in return type
    #   4. `x: list`, `y: dict`,   two params + return type on `both_bare`
    #      `-> set`
    #   5. `-> tuple`              decl method return type
    #   6. `items: frozenset`      decl method param type
    # Properly-parameterized signatures and impl-side annotations (deduped
    # against the decl) should NOT warn.
    assert len(bare_generic_warnings) == 8 , f"Expected 8 W1036 warnings (signatures), got {len(
        bare_generic_warnings
    )}:\n"
        + "\n---\n".join(w.pretty_print() for w in bare_generic_warnings);
}

test "explicit_any_annotations_emit_w1037" {
    # Explicit `any` annotations disable type checking, so each one — on a
    # param, return type, field, assignment, or nested inside a generic or
    # union — should produce a W1037 warning. Specific types must not warn.
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_explicit_any.jac"), options=NO_TC
    );

    explicit_any_warnings = [
        w
        for w in program.warnings_had
        if "W1037" in w.pretty_print()
    ];
    # Expected sites (6 total):
    #   1. `x: any`          param type on `takes_any`
    #   2. `-> any`          return type on `takes_any`
    #   3. `y: any = 5`      annotated assignment
    #   4. `list[any]`       nested any in a generic param
    #   5. `any | None`      any branch of a union return type
    #   6. `payload: any`    field annotation
    assert len(explicit_any_warnings) == 6 , f"Expected 6 W1037 warnings, got {len(
        explicit_any_warnings
    )}:\n"
        + "\n---\n".join(w.pretty_print() for w in explicit_any_warnings);
}

test "explicit_typing_any_annotations_emit_w1037" {
    # `typing.Any` is the same gradual-typing escape hatch as the Jac `any`
    # keyword and must warn identically. Without this, `from typing { Any }`
    # would be a silent loophole around W1037.
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_explicit_typing_any.jac"), options=NO_TC
    );

    explicit_any_warnings = [
        w
        for w in program.warnings_had
        if "W1037" in w.pretty_print()
    ];
    # Expected sites (6 total), mirroring checker_explicit_any.jac:
    #   1. `x: Any`          param type on `takes_any`
    #   2. `-> Any`          return type on `takes_any`
    #   3. `y: Any = 5`      annotated assignment
    #   4. `list[Any]`       nested Any in a generic param
    #   5. `Any | None`      Any branch of a union return type
    #   6. `payload: Any`    field annotation
    assert len(explicit_any_warnings) == 6 , f"Expected 6 W1037 warnings, got {len(
        explicit_any_warnings
    )}:\n"
        + "\n---\n".join(w.pretty_print() for w in explicit_any_warnings);
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# JSX type safety tests (Steps 1-6)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test "jsx_step1_callable_annotation" {
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_step1_callable_annotation.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    e1053_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1053"
    ];
    assert len(e1053_errors) >= 1 , f"Expected E1053 for int->Callable mismatch, got {len(
        e1053_errors
    )} errors:\n"
        + "\n---\n".join(err.pretty_print() for err in program.errors_had);
}

test "jsx_step2_handler_aliases" {
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_step2_handler_aliases.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    e1053_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1053"
    ];
    assert len(e1053_errors) >= 1 , f"Expected E1053 for bad_handler->MouseEventHandler mismatch, got {len(
        e1053_errors
    )} errors:\n"
        + "\n---\n".join(err.pretty_print() for err in program.errors_had);
}

test "jsx_step3_jsx_prop_check" {
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_step3_jsx_prop_check.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    e1100_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1100"
    ];
    assert len(e1100_errors) >= 1 , f"Expected E1100 for JSX prop type mismatch, got {len(
        e1100_errors
    )} E1100 errors. All errors:\n"
        + "\n---\n".join(
            f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
            for err in program.errors_had
        );
}

test "jsx_step4_lambda_inference" {
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_step4_lambda_inference.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    # `e` is inferred as MouseEvent, so accessing `.nonexistent` is a no-such-
    # attribute error on a known type (E1030) -- stronger than E1032 (Unknown),
    # which would mean the param type was never inferred.
    attr_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code in ["E1030", "E1032"]
    ];
    assert len(attr_errors) >= 1 , f"Expected an attribute error for e.nonexistent on inferred MouseEvent, got {len(
        attr_errors
    )}. All errors:\n"
        + "\n---\n".join(
            f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
            for err in program.errors_had
        );
}

test "jsx_step5_intrinsic_props" {
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_step5_intrinsic_props.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    e1103_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1103"
    ];
    assert len(e1103_errors) >= 1 , f"Expected E1103 for intrinsic prop type mismatch, got {len(
        e1103_errors
    )} E1103 errors. All errors:\n"
        + "\n---\n".join(
            f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
            for err in program.errors_had
        );
}

test "jsx_step6_spread_props" {
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_step6_spread_props.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    e1104_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1104"
    ];
    assert len(e1104_errors) >= 1 , f"Expected E1104 for non-dict spread, got {len(
        e1104_errors
    )} E1104 errors. All errors:\n"
        + "\n---\n".join(
            f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
            for err in program.errors_had
        );
}

test "jsx_reserved_props_key_ref" {
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_reserved_props.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    e1101_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1101"
    ];
    # Only 'bogus' should trigger E1101. key and ref must be silently accepted.
    assert len(e1101_errors) == 1 , f"Expected exactly 1 E1101 (for 'bogus'), got {len(
        e1101_errors
    )}:\n"
        + "\n---\n".join(
            f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
            for err in e1101_errors
        );
    # Verify it's specifically the 'bogus' prop.
    assert "bogus" in e1101_errors[0].pretty_print() , f"Expected E1101 for 'bogus', got: {e1101_errors[
        0
    ].pretty_print()}";
}

test "jsx_props_bag_untyped_and_typed" {
    # A component with a single `props` parameter is the props-bag pattern.
    # Untyped (`props: any`) accepts arbitrary JSX attributes (no E1101) but
    # is flagged with W1052; a typed props bag is validated against the
    # members of the props object's type.
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_props_bag.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    # Only the typed bag's unknown 'bogus' prop should raise E1101 — the
    # untyped bag must accept its arbitrary attributes silently.
    e1101_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1101"
    ];
    assert len(e1101_errors) == 1 , f"Expected exactly 1 E1101 (TypedComp 'bogus'), got {len(
        e1101_errors
    )}:\n"
        + "\n---\n".join(
            f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
            for err in program.errors_had
        );
    assert "bogus" in e1101_errors[0].pretty_print() , f"Expected E1101 for 'bogus', got: {e1101_errors[
        0
    ].pretty_print()}";

    # The typed props bag validates attribute types — count="nope" is E1100.
    e1100_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1100"
    ];
    assert len(e1100_errors) >= 1 , f"Expected E1100 for TypedComp count type mismatch, got {len(
        e1100_errors
    )} E1100 errors. All errors:\n"
        + "\n---\n".join(
            f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
            for err in program.errors_had
        );

    # W1052 fires exactly once — for the untyped UntypedComp, not TypedComp.
    w1052 = [
        w
        for w in program.warnings_had
        if w.code and w.code.code == "W1052"
    ];
    assert len(w1052) == 1 , f"Expected exactly 1 W1052 (UntypedComp), got {len(
        w1052
    )}:\n"
        + "\n---\n".join(w.pretty_print() for w in w1052);
    assert "UntypedComp" in w1052[0].pretty_print() , f"Expected W1052 for 'UntypedComp', got: {w1052[
        0
    ].pretty_print()}";
}

test "jsx_children_must_be_declared_by_the_component" {
    # The codegen destructures declared parameter names out of `props` with no
    # rest element, so a component declaring no `children` drops them silently.
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_children_contract.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    w1053 = [
        w
        for w in program.warnings_had
        if w.code and w.code.code == "W1053"
    ];
    # Two on `Titled`, one each on `ZeroParam`, `TitledPage` and `Required`.
    assert len(w1053) == 5 , f"Expected exactly 5 W1053, got {len(w1053)}:\n"
        + "\n---\n".join(w.pretty_print() for w in program.warnings_had);
    flagged = sorted(w.msg for w in w1053);
    named = [
        name
        for name in [
            "Titled",
            "TitledPage",
            "Required",
            "WithChildren",
            "ZeroParam",
            "TypedBag"
        ]
        if any(f"Component '{name}'" in m for m in flagged)
    ];
    assert named == ["Titled", "TitledPage", "Required", "ZeroParam"] , f"Expected W1053 only on 'Titled', 'TitledPage', 'Required' and 'ZeroParam', got {named}:\n"
        + "\n".join(flagged);

    # Only the complete element is a call site; validating the opening or
    # closing tag node would report `Required`'s `title` as missing.
    e1102 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1102"
    ];
    assert not e1102 , f"A JSX tag node was validated as a call site:\n"
        + "\n---\n".join(e.pretty_print() for e in e1102);
    assert len(
        [
            m
            for m in flagged
            if "Component 'Titled'" in m
        ]
    )
        == 2 , f"Expected 2 W1053 on 'Titled':\n" + "\n".join(flagged);

    # Zero-parameter components are validated like any other.
    e1101 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1101"
    ];
    assert len(e1101) == 1 , f"Expected exactly 1 E1101 (ZeroParam 'bogus'), got {len(
        e1101
    )}:\n"
        + "\n---\n".join(
            f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
            for err in program.errors_had
        );
    assert "bogus" in e1101[0].pretty_print() , f"Expected E1101 for 'bogus', got: {e1101[
        0
    ].pretty_print()}";
}

test "jsx_props_are_checked_at_call_sites_passing_no_attribute" {
    # Prop validation used to return early on a call site with no attributes,
    # so a missing required prop went unreported exactly when the call site
    # passed nothing at all.
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_required_props.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    e1102 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1102"
    ];
    msgs = sorted(e.msg for e in e1102);
    # `<Plain/>` and `<Card>body</Card>` are missing `title`; `<Card title/>`
    # is missing `children`. The three call sites that satisfy their signature
    # -- including `<AllOptional/>`, which also passes nothing -- stay clean.
    assert len(e1102) == 3 , f"Expected exactly 3 E1102, got {len(e1102)}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1102);
    assert len(
        [
            m
            for m in msgs
            if "Component 'Plain'" in m
        ]
    )
        == 1 , f"Expected 1 E1102 on 'Plain':\n" + "\n".join(msgs);
    for name in ["title", "children"] {
        assert any(f"prop '{name}'" in m for m in msgs) , f"Expected an E1102 naming '{name}':\n"
            + "\n".join(msgs);
    }
    assert not any("Component 'AllOptional'" in m for m in msgs) , f"A fully optional signature must not be flagged:\n"
        + "\n".join(msgs);

    # Nested children count as the `children` prop, so a `children` parameter
    # with no default is satisfied by the content it exists to receive.
    assert len(
        [
            m
            for m in msgs
            if "prop 'children'" in m
        ]
    )
        == 1 , f"Expected `<Card title=\"ok\">body</Card>` to satisfy 'children':\n"
        + "\n".join(msgs);
}

test "jsx_props_bundle_must_be_the_only_parameter" {
    # A `props` bundle beside another parameter emits either invalid JavaScript
    # (`const {props, tone} = props`) or a positional signature React never
    # calls that way, pinning every other parameter to its default.
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_props_bundle_exclusive.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    e1109 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1109"
    ];
    msgs = sorted(e.msg for e in e1109);
    assert len(e1109) == 5 , f"Expected exactly 5 E1109, got {len(e1109)}:\n"
        + "\n---\n".join(
            f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
            for err in program.errors_had
        );
    # Every annotation the codegen lowers through the props protocol, not just
    # `JsxElement`: `pages/` modules return `JsxPage`/`JsxLayout`.
    for name in ["Mixed", "MixedKw", "MixedPage", "MixedLayout", "MixedUnion"] {
        assert any(f"'{name}'" in m for m in msgs) , f"Expected E1109 for '{name}':\n"
            + "\n".join(msgs);
    }
    # A lone bundle, named parameters, non-JSX functions and `__jac` runtime
    # helpers (called directly, not through the props protocol) are all fine.
    for name in ["Bag", "BagPage", "Named", "NotAComponent", "__jacMixedHelper"] {
        assert not any(f"'{name}'" in m for m in msgs) , f"'{name}' must not be flagged:\n"
            + "\n".join(msgs);
    }
}

glob PAGES_ROUTING_FIXTURES = os.path.join(
         os.path.dirname(__file__), "fixtures", "pages_routing"
     );

"""E1108 count for the `main.jac` of one `fixtures/pages_routing/` project."""
def _pages_entry_errors(project: str) -> list {
    path = os.path.join(PAGES_ROUTING_FIXTURES, project, "main.jac");
    program = JacProgram();
    program.compile(path);
    return [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1108"
    ];
}

test "pages_project_app_must_accept_children" {
    # The generated entry renders `app` with the route tree as its children,
    # from JavaScript the checker never sees -- so W1053 cannot catch this.
    e1108 = _pages_entry_errors("drops_children");
    assert len(e1108) == 1 , f"Expected 1 E1108 for a pages/ app dropping children, got {len(
        e1108
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1108);
    assert "children" in e1108[0].msg , f"Expected E1108 to name 'children', got: {e1108[
        0
    ].msg}";
}

test "pages_project_app_declaring_children_is_accepted" {
    # Same project shape, one declared parameter: nothing to report.
    e1108 = _pages_entry_errors("renders_children");
    assert len(e1108) == 0 , f"Expected no E1108 when `app` declares children, got {len(
        e1108
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1108);
}

test "pages_dir_without_routes_is_accepted" {
    # The directory alone is not the routing switch: `_scan_and_compile_pages`
    # also needs a route or a layout, and renders `app` directly without one.
    # The fixture's three modules are the ones a text scan gets wrong -- a
    # `JsxElement` return, `-> JsxPage` in a docstring, and a `JsxPage` method.
    e1108 = _pages_entry_errors("pages_without_routes");
    assert len(e1108) == 0 , f"Expected no E1108 when pages/ declares no route, got {len(
        e1108
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1108);
}

test "manual_routing_app_without_children_is_accepted" {
    # No `pages/` directory: the entry renders `app` directly, so the
    # no-argument form is the correct one and must stay unflagged.
    e1108 = _pages_entry_errors("no_pages");
    assert len(e1108) == 0 , f"Expected no E1108 without a pages/ directory, got {len(
        e1108
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1108);
}

test "jsx_intrinsic_tag_names_do_not_emit_w1051" {
    # Regression: Name nodes under a JsxElementName are resolved against the
    # _JsxIntrinsicElements registry by the JsxElement handler, not against
    # module scope. exit_name must skip these or it emits spurious W1051 on
    # every tag name (<div>, <button>, </div>, ...).
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_intrinsic_tag_resolution.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    w1051_warnings = [
        w
        for w in program.warnings_had
        if w.code and w.code.code == "W1051"
    ];
    assert len(w1051_warnings) == 0 , f"Expected no W1051 on intrinsic JSX tag names, got {len(
        w1051_warnings
    )}:\n"
        + "\n---\n".join(w.pretty_print() for w in w1051_warnings);
    # And the module itself must still type-check without errors.
    assert len(program.errors_had) == 0 , f"Unexpected errors: {[
        e.pretty_print() for e in program.errors_had
    ]}";
}

test "dom_browser_globals_resolve_to_storage" {
    # `localStorage` / `sessionStorage` are ambient browser globals typed as
    # `Storage` (dom_types.pyi). Their real API surface must type-check with
    # no E1032 (access on Unknown) and no W1051. The deliberate `getItm` typo
    # must raise exactly one E1030 (known type, missing attribute) — proving
    # the global is genuinely typed, not silenced as Unknown.
    path = os.path.join(CHECKER_FIXTURES, "checker_dom_browser_globals.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    e1032_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1032"
    ];
    assert len(e1032_errors) == 0 , f"Expected no E1032 (browser globals must not be Unknown), got {len(
        e1032_errors
    )}. All errors:\n"
        + "\n---\n".join(
            f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
            for err in program.errors_had
        );

    e1030_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1030"
    ];
    assert len(e1030_errors) == 1 , f"Expected exactly 1 E1030 (the `getItm` typo), got {len(
        e1030_errors
    )}. All errors:\n"
        + "\n---\n".join(
            f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
            for err in program.errors_had
        );
    assert "getItm" in e1030_errors[0].pretty_print() , f"Expected E1030 for `getItm`, got: {e1030_errors[
        0
    ].pretty_print()}";

    # The valid Storage API lines must be fully resolved. W1051 on the typo
    # line is expected downstream fallout of the E1030 above, so exclude it.
    typo_line = e1030_errors[0].loc.first_line;
    w1051_warnings = [
        w
        for w in program.warnings_had
        if w.code and w.code.code == "W1051" and w.loc and w.loc.first_line != typo_line
    ];
    assert len(w1051_warnings) == 0 , f"Expected no W1051 on the valid Storage API surface, got {len(
        w1051_warnings
    )}:\n"
        + "\n---\n".join(w.pretty_print() for w in w1051_warnings);
}

test "lambda_block_body_return_type_inference" {
    path = os.path.join(CHECKER_FIXTURES, "checker_lambda_block_body_return.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    all_errors = [
        e
        for e in program.errors_had
        if e.code and e.code.code.startswith("E")
    ];
    # Cases 1-5 should produce NO errors.
    # Case 6 should produce exactly 1 error (return type mismatch).
    assert len(all_errors) == 1 , f"Expected exactly 1 type error (Case 6: int vs str mismatch), got {len(
        all_errors
    )} errors:\n"
        + "\n---\n".join(
            f"{err.code.code if err.code else '?'}: {err.pretty_print()}"
            for err in all_errors
        );
}

test "root_special_var_returns_root_type" {
    # Bare `root` should resolve as a SpecialVarRef returning Root, so that
    # `root spawn Walker()` resolves the walker type and `.reports` is accessible.
    path = os.path.join(CHECKER_FIXTURES, "checker_root_call_type.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    assert len(program.errors_had) == 0 , f"Expected 0 errors, got {len(
        program.errors_had
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in program.errors_had);
    w1051 = [
        w
        for w in program.warnings_had
        if w.code is not None and w.code.code == "W1051"
    ];
    assert len(w1051) == 0 , f"Expected no W1051 warnings for bare `root`, got {len(
        w1051
    )}:\n"
        + "\n---\n".join(w.pretty_print() for w in w1051);
}

test "compare_operator_validation" {
    # Validates that comparison operators are type-checked against operand types.
    # Previously, CompareExpr only evaluated operands for side effects and returned
    # bool without checking operator validity (e.g. "hello" > 5 passed silently).
    path = os.path.join(CHECKER_FIXTURES, "checker_compare_operator_validation.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    # At least 7 errors expected (exact count may vary across Python/typeshed
    # versions due to differences in stub overload signatures):
    #   - "hello" > 5           — E1110: str vs int
    #   - "hello" < [1, 2, 3]  — E1110: str vs list
    #   - [1, 2] < {3: 4}      — E1110: list vs dict
    #   - 5 in 10               — E1111: int has no __contains__
    #   - "x" in 42             — E1111: int has no __contains__
    #   - "a" < 1  (chained)   — E1110: str vs int
    #   - 1 < "b"  (chained)   — E1110: int vs str
    assert len(program.errors_had) >= 7 , f"Expected >= 7 errors, got {len(
        program.errors_had
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in program.errors_had);

    # Collect all error pretty prints for flexible matching
    all_errors = [e.pretty_print() for e in program.errors_had];
    all_errors_str = "\n".join(all_errors);

    # Verify E1110 diagnostics for ordered comparison errors
    e1110_count = sum(
        1
        for e in all_errors
        if "E1110" in e
    );
    assert e1110_count >= 5 , f"Expected >= 5 E1110 errors, got {e1110_count}";

    # Verify E1111 diagnostics for membership test errors
    e1111_count = sum(
        1
        for e in all_errors
        if "E1111" in e
    );
    assert e1111_count >= 2 , f"Expected >= 2 E1111 errors, got {e1111_count}";
    assert "__contains__" in all_errors_str;

    # Verify specific error locations are present
    assert '"hello" > 5' in all_errors_str;
    assert "5 in 10" in all_errors_str;
}

test "undeclared_obj_attr_warns_w2080" {
    # W2080: annotated self-assignments in init/postinit of obj/node/edge/walker
    # should warn "declare as 'has' field" while still resolving the attribute
    # to prevent cascading E1030 errors.
    path = os.path.join(CHECKER_FIXTURES, "checker_undeclared_obj_attr.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    # Collect warnings
    all_warnings = [w.pretty_print() for w in program.warnings_had];
    w2080_warnings = [
        w
        for w in all_warnings
        if "W2080" in w
    ];

    # Should have W2080 for: y (Foo.init), count (Bar.postinit),
    # label (Bar.postinit), cached (MyNode.postinit)
    assert len(w2080_warnings) >= 4 , f"Expected >= 4 W2080 warnings, got {len(
        w2080_warnings
    )}:\n"
        + "\n---\n".join(w2080_warnings);

    # Verify the warning messages mention the attribute names
    w2080_str = "\n".join(w2080_warnings);
    assert "'y'" in w2080_str or "y" in w2080_str;
    assert "'count'" in w2080_str;
    assert "'label'" in w2080_str;
    assert "'cached'" in w2080_str;

    # Verify no E1030 on resolved attributes (f.y, b.count, b.label should NOT error)
    all_errors = [e.pretty_print() for e in program.errors_had];
    e1030_errors = [
        e
        for e in all_errors
        if "E1030" in e
    ];
    # Only Baz.secret (unannotated) should produce E1030
    e1030_names = [
        e
        for e in e1030_errors
        if "secret" in e
    ];
    assert len(e1030_names) >= 1 , f"Expected E1030 for 'secret', got: {e1030_errors}";
    # No E1030 for count, label, cached (resolved via W2080 path)
    for attr in ["count", "label", "cached"] {
        resolved_errors = [
            e
            for e in e1030_errors
            if attr in e
        ];
        assert len(resolved_errors) == 0 , f"Attribute '{attr}' should be resolved, but got E1030: {resolved_errors}";
    }
}

test "optional_chaining_no_false_e1030" {
    # Optional chaining (?.) should not emit E1030 for missing attributes.
    # The ?. operator returns None when the attribute doesn't exist.
    path = os.path.join(CHECKER_FIXTURES, "checker_optional_chaining.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    all_errors = [e.pretty_print() for e in program.errors_had];
    e1030_errors = [
        e
        for e in all_errors
        if "E1030" in e
    ];

    # Only the regular (non-?.) access `b.extra` should produce E1030
    assert len(e1030_errors) == 1 , f"Expected exactly 1 E1030 (for b.extra), got {len(
        e1030_errors
    )}:\n"
        + "\n---\n".join(e1030_errors);
    assert "extra" in e1030_errors[0] , f"Expected E1030 for 'extra', got: {e1030_errors[
        0
    ]}";

    # Only W1051 allowed is on the regular (non-?.) access line which cascades
    # from the E1030 Unknown result. No W1051 for ?. expressions themselves.
    w1051_warnings = [
        w
        for w in program.warnings_had
        if w.code is not None and w.code.code == "W1051"
    ];
    for w in w1051_warnings {
        # Any W1051 must be on the `b.extra` line (regular access), not ?. lines
        assert "b.extra" in w.pretty_print() or "bad" in w.pretty_print() , f"Unexpected W1051 on ?. expression: {w.pretty_print()}";
    }
}

test "annotated_self_assign_no_false_e1001" {
    # Annotated self-assignments (self.x: int = val) should NOT produce
    # false E1001 "Cannot assign int to int" errors.
    path = os.path.join(CHECKER_FIXTURES, "checker_annotated_self_assign.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    all_errors = [e.pretty_print() for e in program.errors_had];
    e1001_errors = [
        e
        for e in all_errors
        if "E1001" in e
    ];

    # Must have the 2 real E1001 errors (str assigned to int)
    e1001_str = "\n".join(e1001_errors);
    assert "wrong" in e1001_str , f"Expected E1001 for 'wrong', got:\n{e1001_str}";
    assert "bad" in e1001_str , f"Expected E1001 for 'bad', got:\n{e1001_str}";

    # No same-type false positives (e.g., "Cannot assign int to int")
    for err in e1001_errors {
        # Real errors mention mismatched types; false positives have same type on both sides
        assert not ("assign int to int" in err) , f"False positive E1001 same-type error: {err}";
        assert not ("assign str to str" in err) , f"False positive E1001 same-type error: {err}";
        assert not ("assign float to float" in err) , f"False positive E1001 same-type error: {err}";
    }
}

test "walker_typed_reports_validation" {
    # `has reports: list[T]` on a walker should:
    #   1. Reject non-list shapes (E1112).
    #   2. Type-check `report X` against the element type T (E1113).
    path = os.path.join(CHECKER_FIXTURES, "checker_walker_typed_reports.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    e1112 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1112"
    ];
    e1113 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1113"
    ];
    assert len(e1112) == 1 , f"Expected 1 E1112 (non-list reports shape), got {len(
        e1112
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1112);
    assert len(e1113) == 1 , f"Expected 1 E1113 (mismatched report element), got {len(
        e1113
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1113);
    # No spurious errors on the GoodWalker case.
    other = [
        e
        for e in program.errors_had
        if e.code and e.code.code not in ("E1112", "E1113")
    ];
    assert len(other) == 0 , f"Expected no other errors, got {len(other)}:\n"
        + "\n---\n".join(e.pretty_print() for e in other);
}

test "isinstance_and_narrowing" {
    # isinstance(x, T) in LHS of AND should narrow x to T for RHS operands.
    path = os.path.join(CHECKER_FIXTURES, "checker_isinstance_and_narrowing.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    # All functions use isinstance in AND conditions to guard attribute access.
    # No errors should be produced — the narrowing should resolve all attributes.
    assert len(program.errors_had) == 0 , f"Expected 0 errors (isinstance AND narrowing should resolve all attrs), got {len(
        program.errors_had
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in program.errors_had);

    # No W1051 warnings either
    w1051 = [
        w
        for w in program.warnings_had
        if w.code is not None and w.code.code == "W1051"
    ];
    assert len(w1051) == 0 , f"Expected no W1051 warnings, got {len(w1051)}:\n"
        + "\n---\n".join(w.pretty_print() for w in w1051);
}

test "pipe_forward_typing_matches_call_form" {
    path = os.path.join(CHECKER_FIXTURES, "checker_pipe_forward_typing.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    w1051 = [
        w
        for w in program.warnings_had
        if w.code and w.code.code == "W1051"
    ];
    assert len(w1051) == 0 , f"Expected no W1051 on pipe expressions, got {len(
        w1051
    )}:\n"
        + "\n---\n".join(w.pretty_print() for w in w1051);

    assert len(program.errors_had) == 1 , f"Expected exactly 1 error (the intentional negative case), got {len(
        program.errors_had
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in program.errors_had);
    err = program.errors_had[0];
    assert err.code and err.code.code == "E1053" , f"Expected E1053, got {err.code.code
        if err.code
        else 'no-code'}:\n{err.pretty_print()}";
}

test "as_cast_resolves_any_assignment" {
    # The `as` cast re-types an Any source so it lands in a declared concrete
    # type without tripping the strict-gradual rule (E1001).
    path = os.path.join(CHECKER_FIXTURES, "checker_as_cast.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    e1001 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1001"
    ];
    assert len(e1001) == 0 , f"Expected no E1001 — the `as` casts should satisfy the declared types, got {len(
        e1001
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1001);

    parse_errs = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E0002"
    ];
    assert len(parse_errs) == 0 , "`expr as Type` should parse, got E0002:\n"
        + "\n---\n".join(e.pretty_print() for e in parse_errs);
}

test "cast_target_must_be_a_type" {
    # A cast target that is not a type expression -- a comparison, a value
    # variable -- is diagnosed with E1044; unions and generics stay valid (#7885).
    path = os.path.join(CHECKER_FIXTURES, "checker_cast_target_not_type.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    e1044 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1044"
    ];
    assert len(e1044) == 2 , f"Expected 2 E1044 (bad_parens, bad_value), got {len(
        e1044
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in program.errors_had);
    lines = sorted(e.loc.first_line for e in e1044);
    assert lines == [4, 8] , f"E1044 on wrong lines: {lines}";

    others = [
        e
        for e in program.errors_had
        if not (e.code and e.code.code == "E1044")
    ];
    assert len(others) == 0 , "Only E1044 expected -- the union and generic casts"
    " must stay valid:\n"
        + "\n---\n".join(e.pretty_print() for e in others);
}

# ============================================================================
# Issue #6058 — TypeEvaluator correctness for patterns native code uses.
# Fixed-width primitives (iN, uN, fN) are width refinements of the same
# numeric kind as int / float, not unrelated subclasses. Same-kind
# assignment and arithmetic must typecheck.
# ============================================================================
test "numeric_kind_same_kind_assignment" {
    path = os.path.join(CHECKER_FIXTURES, "checker_numeric_kind_assign.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    typed_errs = [
        e
        for e in program.errors_had
        if e.code and e.code.code in ("E1001", "E1002", "E1053", "E1055")
    ];
    assert len(typed_errs) == 0 , f"Expected no E1001/E1002/E1053/E1055 for same-kind / IntKind→FloatKind / fixed-width arithmetic, got {len(
        typed_errs
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in typed_errs);
}

test "numeric_kind_disallows_float_to_int" {
    path = os.path.join(CHECKER_FIXTURES, "checker_numeric_kind_disallowed.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    # Each of the 4 functions performs a FloatKind -> IntKind move (3 returns,
    # 1 local assignment). All must remain type errors.
    typed_errs = [
        e
        for e in program.errors_had
        if e.code and e.code.code in ("E1001", "E1002")
    ];
    assert len(typed_errs) >= 4 , f"Expected ≥4 errors for FloatKind→IntKind moves, got {len(
        typed_errs
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in typed_errs);
}

test "comprehension_filter_narrows_head" {
    # `[x for x in xs if x is not None]` must type as `list[T]`, not
    # `list[T | None]` -- the filter proves the head value is non-None.
    # Generalises to subscript heads under stable loop-var indices.
    path = os.path.join(CHECKER_FIXTURES, "checker_compr_filter_narrowing.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    narrow_errs = [
        e
        for e in program.errors_had
        if e.code and e.code.code in ("E1099", "E1030", "E1001", "E1002")
    ];
    assert len(narrow_errs) == 0 , f"Expected comprehension filter narrowing to propagate to head, got {len(
        narrow_errs
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in narrow_errs);
}

test "subscript_narrowing_stable_indices" {
    # Repeated subscript expressions `x[i]` / `x[i][j]` must narrow as
    # aliases when neither `x` nor the indices are reassigned between
    # reads. Pyright's "narrowable expression" rule -- plain names,
    # int literals, and loop variables count.
    path = os.path.join(CHECKER_FIXTURES, "checker_subscript_narrowing_stable.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    narrow_errs = [
        e
        for e in program.errors_had
        if e.code and e.code.code in ("E1099", "E1030", "E1001", "E1002")
    ];
    assert len(narrow_errs) == 0 , f"Expected stable-index subscript narrowing to propagate, got {len(
        narrow_errs
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in narrow_errs);
}

test "enum_member_assignable_to_base_type" {
    # `enum Color { RED = 1 }` — `Color.RED` is the int value 1.
    # Returning / assigning it where the base type (int / str) is
    # expected must typecheck. Surfaced in native fixtures
    # string_enums.jac, ast.jac, na_enum_import.jac.
    path = os.path.join(CHECKER_FIXTURES, "checker_enum_member_as_base.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    enum_errs = [
        e
        for e in program.errors_had
        if e.code and e.code.code in ("E1001", "E1002", "E1053")
    ];
    assert len(enum_errs) == 0 , f"Expected enum-member-as-base assignments to typecheck, got {len(
        enum_errs
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in enum_errs);
}

test "local_module_shadows_stdlib_in_resolver" {
    # `import from ast { ... }` from a file alongside a local `ast.jac`
    # must resolve to the local file, not Python's stdlib ast.pyi. Without
    # this the imported symbols decay to Unknown and propagate cascade
    # errors (E1001 / E1030 / E1053). Symmetric with NaIRGenPass's
    # struct-registration fix; covered by fix_shadow_entry.jac in the
    # native fixture suite too.
    path = os.path.join(CHECKER_FIXTURES, "checker_local_shadows_stdlib", "entry.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);

    cascade = [
        e
        for e in program.errors_had
        if e.code and e.code.code in ("E1001", "E1002", "E1030", "E1053")
    ];
    assert len(cascade) == 0 , f"Expected no cascade errors when local ast.jac shadows stdlib, got {len(
        cascade
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in cascade);
}

test "duplicate_archetype_decl_is_hard_error" {
    # `obj Foo; obj Foo { ... }` is decl/decl — Jac only supports
    # decl/impl. The second `obj` header must emit E0077.
    path = os.path.join(CHECKER_FIXTURES, "checker_forward_decl_archetype.jac");
    program = JacProgram();
    program.compile(path, options=NO_TC);

    e0077 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E0077"
    ];
    assert len(e0077) == 2 , f"Expected exactly 2 E0077 (one per duplicate `obj` pair), got {len(
        e0077
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e0077);
    assert "Piece" in e0077[0].pretty_print() , f"first E0077 should name 'Piece': {e0077[
        0
    ].pretty_print()}";
    assert "Animal" in e0077[1].pretty_print() , f"second E0077 should name 'Animal': {e0077[
        1
    ].pretty_print()}";
}

test "circular_import_preserves_class_identity" {
    abs_entry = os.path.join(CHECKER_FIXTURES, "circular_import_identity", "entry.jac");
    rel_entry = os.path.relpath(abs_entry);
    program = JacProgram();
    program.compile(rel_entry);
    assert len(program.errors_had) == 0 , f"Circular import split the class identity, got {len(
        program.errors_had
    )} error(s):\n"
        + "\n---\n".join(e.pretty_print() for e in program.errors_had);
}

test "callable_null_default_rejected_outside_native" {
    # Issue #6569 allows `Callable[[...], ret] = 0` (a C NULL function
    # pointer) in native modules only. Regular Jac must keep rejecting it.
    path = os.path.join(CHECKER_FIXTURES, "checker_callable_null_default.jac");
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    assert len(program.errors_had) == 1 , "Expected exactly 1 error, got "
        + f"{len(program.errors_had)}:\n"
        + "\n---\n".join(e.pretty_print() for e in program.errors_had);
    _first_code = program.errors_had[0].code;
    assert _first_code is not None;
    assert _first_code.code == "E1001";
    assert_error_pretty_found(
        """
        has fn: Callable[[int], int] = 0;  # <-- Error
    """,
        program.errors_had[0].pretty_print()
    );
}

test "edge_endpoint_typing_narrows_neighbour_traversals" {
    # Issue #6657: an edge that declares `: Src --> Tgt` lets a neighbour
    # traversal infer the declared node type instead of `any`, with no
    # `[?:Type]` filter -- so a field read off the result resolves statically.
    program = JacProgram();
    mod = program.compile(os.path.join(CHECKER_FIXTURES, "edge_endpoint_typing.jac"));
    assert len(program.errors_had) == 0 , "Unexpected errors:\\n"
        + "\\n---\\n".join(e.pretty_print() for e in program.errors_had);
    expected = {
        "follow_out": "list[Profile]",  # ->:Follow:-> narrows to target
        "post_in": "list[Profile]",  # <-:Post:<- narrows to source
        "post_out": "list[Tweet]",  # ->:Post:-> narrows to target
        "untyped": "list[<any>]",  # bare edge stays gradual
        "inherited": "list[Profile]",  # subtype edge inherits endpoints
        "one": "Tweet",  # subscript element of a narrowed list
        "field_read": "str"  # field read off a narrowed element
    };
    seen: dict[str, str] = {};
    for nm in mod.get_all_sub_nodes(uni.Name) {
        if nm.value in expected and nm.type is not None {
            seen[nm.value] = str(nm.type);
        }
    }
    for (target, want) in expected.items() {
        assert seen.get(target) == want , f"{target}: expected {want}, got {seen.get(
            target
        )}";
    }
}

test "edge_endpoint_clause_rejected_on_non_edge" {
    # Issue #6657: the endpoint clause is edge-only; a node carrying one is an
    # E2027 rather than a silently-ignored declaration.
    program = JacProgram();
    program.compile(os.path.join(CHECKER_FIXTURES, "edge_endpoint_on_node.jac"));
    has_e2027 = False;
    for alrt in program.errors_had {
        if alrt.code is not None and alrt.code.code == "E2027" {
            has_e2027 = True;
        }
    }
    assert has_e2027 , "Expected E2027 for endpoint clause on a node, got:\\n"
        + "\\n---\\n".join(e.pretty_print() for e in program.errors_had);
}

test "mobui_project_forbids_html_intrinsic_tags" {
    # D17: in a mobui (React Native) project, raw HTML host tags are
    # forbidden — JsxIntrinsicGuardPass emits E1105 for each lowercase tag,
    # with a fix-it pointing at the @jac/mobui / RN component. Uppercase user
    # components (<Card>) are allowed. The pass runs in get_ir_gen_sched, so
    # it fires even with type_check=False (the .jac / build path).
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_mobui_html_forbidden.jac");
    program = JacProgram();
    program.compile(
        path, options=CompileOptions(ui="mobui", project_root=CHECKER_FIXTURES)
    );

    e1105 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1105"
    ];
    # Host tags: <span>, <div>, <button>, <img> => 4. <Card> is exempt.
    assert len(e1105) == 4 , f"Expected 4 E1105 (div/span/button/img), got {len(
        e1105
    )}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1105);

    # Assert against the diagnostic messages (not pretty_print, whose source
    # context would include nearby lines like the <Card .../> line).
    msgs = "\n".join(e.msg for e in e1105);
    # No component tag is ever flagged.
    assert "<Card>" not in msgs , f"<Card> must not be flagged:\n{msgs}";
    # The fix-it suggestions are present (div -> View, span -> Text, etc.).
    assert "View" in msgs , f"Expected a 'View' suggestion:\n{msgs}";
    assert "Text" in msgs , f"Expected a 'Text' suggestion:\n{msgs}";
}

test "web_project_allows_html_intrinsic_tags" {
    # The same fixture compiled as a plain web project (default kind) emits no
    # E1105 — host tags are allowed there.
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_mobui_html_forbidden.jac");
    program = JacProgram();
    program.compile(path, options=NO_TC);

    e1105 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1105"
    ];
    assert len(e1105) == 0 , f"Expected no E1105 in a web project, got {len(e1105)}:\n"
        + "\n---\n".join(e.pretty_print() for e in e1105);
}

test "mobui_project_allows_lowercase_component_in_scope" {
    # An in-scope lowercase component must NOT trigger E1105 — the guard
    # resolves it via scope lookup and recognises it as a user component.
    # The 4 HTML host tags in the same fixture still emit E1105 as expected.
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_mobui_html_forbidden.jac");
    program = JacProgram();
    program.compile(
        path, options=CompileOptions(ui="mobui", project_root=CHECKER_FIXTURES)
    );
    e1105 = [
        e
        for e in program.errors_had
        if e.code and e.code.code == "E1105"
    ];
    msgs = "\n".join(e.msg for e in e1105);
    assert "<myCard>" not in msgs , f"<myCard> is in scope and must not be flagged:\n{msgs}";
    assert len(e1105) == 4 , f"Expected 4 E1105 (div/span/button/img), got {len(
        e1105
    )}:\n{msgs}";
}

test "mobui_project_lowercase_component_no_w1050" {
    # Gap 3: in a mobui project, an in-scope lowercase component must not
    # produce W1050 ('Unknown intrinsic JSX element'). The type evaluator
    # routes it via scope resolution, not the _JsxIntrinsicElements registry.
    path = os.path.join(
        CHECKER_FIXTURES, "checker_jsx_lowercase_imported_component.jac"
    );
    program = JacProgram();
    program.compile(
        path, options=CompileOptions(ui="mobui", project_root=CHECKER_FIXTURES)
    );
    w1050 = [
        w
        for w in program.warnings_had
        if w.code and w.code.code == "W1050"
    ];
    assert len(w1050) == 0 , f"Expected no W1050 for in-scope lowercase component, got:\n"
        + "\n".join(w.pretty_print() for w in w1050);
}

test "mobui_kind_does_not_leak_outside_project_root" {
    # Regression: a consumer's ui="mobui" must not reach files
    # outside the project root. The real failure was client_runtime.jac
    # (from jac-client) being compiled into the user's JacProgram during
    # `jac build` and receiving E1105 for its HTML tags ("kind-leak").
    # We simulate it by passing an explicit project_root that does NOT contain
    # the fixture, mimicking a framework file outside the user's project.
    import tempfile;
    path = os.path.join(CHECKER_FIXTURES, "checker_jsx_cl_html_allowed.jac");
    with tempfile.TemporaryDirectory() as tmp_root {
        program = JacProgram();
        program.compile(
            path, options=CompileOptions(ui="mobui", project_root=tmp_root)
        );
        e1105 = [
            e
            for e in program.errors_had
            if e.code and e.code.code == "E1105"
        ];
        assert len(e1105) == 0 , (
            f"E1105 must not fire on files outside project_root (kind-leak regression), "
            f"got {len(e1105)}:\n"
            + "\n---\n".join(e.pretty_print() for e in e1105)
        );
    }
}

test "jac_toml_kind_mobui_round_trip" {
    # Verify the jac.toml → workspace reader → compile() code path for
    # `[apps.<name>] kind = "mobile"`: a mobile app is mobUI with no other
    # key. All other mobui-project tests set ui via CompileOptions directly;
    # this one writes a real project (jac.toml + module) and relies on the
    # guard pass discovering the kind from the module's own path -- no cwd,
    # no config singleton.
    import shutil;
    import tempfile;
    import from jaclang.project.config { JacConfig }

    toml_content = '[project]\nname = "test-proj"\n\n[apps.main]\nkind = "mobile"\n';

    with tempfile.TemporaryDirectory() as tmp_dir {
        toml_path = Path(tmp_dir) / "jac.toml";
        toml_path.write_text(toml_content);
        # Part 1: round-trip — JacConfig.load() must derive mobUI from the kind.
        cfg = JacConfig.load(toml_path);
        assert cfg.apps["main"].ui() == "mobui" , f"Expected ui='mobui' for app main, got '{cfg.apps[
            'main'
        ].ui()}'";
        # Part 2: per-path discovery -- a module inside the project picks up
        # "mobui" with a plain CompileOptions() (no explicit ui),
        # causing JsxIntrinsicGuardPass to emit E1105.
        fixture = os.path.join(tmp_dir, "main.jac");
        shutil.copyfile(
            os.path.join(CHECKER_FIXTURES, "checker_jsx_mobui_html_forbidden.jac"),
            fixture
        );
        program = JacProgram();
        program.compile(fixture, options=CompileOptions());
        e1105 = [
            e
            for e in program.errors_had
            if e.code and e.code.code == "E1105"
        ];
        assert len(e1105) == 4 , f"Expected 4 E1105 from [apps.main] kind=mobile, got {len(
            e1105
        )}:\n"
            + "\n---\n".join(e.pretty_print() for e in e1105);
    }
}

test "builtin_inference_regressions" {
    # Two regressions from the this_is_jac showcase QA (fixture documents
    # both): `round(...)` failed E1054 everywhere because typeshed declares
    # it against the PRIVATE protocols `_SupportsRound1/2`, which the
    # evaluator's structural-protocol table did not know by name; and
    # `{**c}` folded the spread dict in as a single entry VALUE, inferring
    # dict[<Unknown>, dict[K, V]] instead of dict[K, V].
    program = JacProgram();
    program.compile(os.path.join(CHECKER_FIXTURES, "checker_builtin_inference.jac"));
    pretty = "\n".join([e.pretty_print() for e in program.errors_had]);
    assert len(program.errors_had) == 0 , "round() results and **spread dict literals must infer cleanly, "
    f"got {len(program.errors_had)} diagnostic(s):\n{pretty}";
}

test "bare_list_flow_inference" {
    # Issue #6943 NA-7: an empty bare `list = []` defaulted its element type
    # (the native backend then locked in `List.i64` and a later `str.join`
    # mismatched). The declaration now flow-infers its element type from the
    # mutations that follow: append/insert args, extend/`+=` operands'
    # element types, and index-store values, widened out of literal types.
    # Only concrete scalar evidence refines: mixed scalars (or None beside a
    # scalar) collapse to the heterogeneous `any` element (backends lower
    # `list[any]` as the boxed layout; a union would silently lower as its
    # first member), while `any`/Unknown/object evidence aborts the
    # inference - a dynamic value is absence of information, not proof of
    # heterogeneity, and native code (the OSP kernel's handle lists) relies
    # on the bare default. Multi-target assignments pool evidence from every
    # bound name. No evidence leaves the list bare, and an explicit
    # `list[T]` annotation still wins over usage.
    program = JacProgram();
    mod = program.compile(
        os.path.join(CHECKER_FIXTURES, "checker_bare_list_flow_inference.jac"),
    );
    assert len(program.errors_had) == 0 , "Unexpected errors:\n"
        + "\n---\n".join(e.pretty_print() for e in program.errors_had);
    expected = {
        "flow_strs": "list[str]",
        "flow_ints": "list[int]",
        "flow_mixed": "list[Any]",
        "flow_ext": "list[str]",
        "flow_ins": "list[float]",
        "flow_aug": "list[str]",
        "flow_idx": "list[str]",
        "flow_unann": "list[str]",
        "flow_none": "list",
        "flow_nonemix": "list[Any]",
        "flow_dyn": "list",
        "flow_poison": "list",
        "flow_obj": "list",
        "flow_bare": "list",
        "flow_pinned": "list[int]",
        "flow_multi_a": "list[str]",
        "flow_multi_b": "list[str]",
        "flow_rebound": "list[Any]"
    };
    seen: dict[str, str] = {};
    for nm in mod.get_all_sub_nodes(uni.Name) {
        if nm.value in expected and nm.type is not None {
            seen[nm.value] = str(nm.type);
        }
    }
    for (target, want) in expected.items() {
        assert seen.get(target) == want , f"{target}: expected {want}, got {seen.get(
            target
        )}";
    }
}

test "none_equality_not_flagged" {
    # `==` / `!=` never fail to resolve in Python (object.__eq__ is the
    # universal identity fallback), so None-equality must not raise E1110.
    # typeshed's NoneType has no __eq__, which previously made every
    # `x == None` an error and steered users toward `is None` (#7922).
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_none_equality.jac");
    mod = program.compile(path, options=NO_TC);
    eq_errors = [
        e
        for e in program.errors_had
        if "not supported between" in str(e)
    ];
    assert not eq_errors , (
        "None equality must type-check; got: " + str([str(e) for e in eq_errors])
    );
}

test "match_wildcard_no_warning_noise" {
    # `case _:` is a binder, not an expression read: it must not draw
    # W2001 ("may be undefined") from static analysis or W1051 (unknown
    # expression type) from the checker (#7922).
    program = JacProgram();
    path = os.path.join(CHECKER_FIXTURES, "checker_match_wildcard.jac");
    mod = program.compile(path, options=NO_TC);
    noise = [
        w
        for w in program.warnings_had
        if ("'_'" in str(w))
            or ("may be undefined" in str(w))
            or ("could not be resolved" in str(w))
    ];
    assert not noise , (
        "case _ must not draw warning noise; got: " + str([str(w) for w in noise])
    );
}
