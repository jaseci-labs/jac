"""RD parser validation tests – migrated from test_rd_parser_validation.py.

Validates the recursive descent parser on the full micro suite files and
gap coverage files. Also tests that the parser correctly rejects invalid
constructs.
"""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.unitree { Module }
import from jaclang.jac0core.unitree { Test as JacTest }
import from jaclang.runtimelib.utils { read_file_with_encoding }
import from jaclang.runtimelib.test { parametrize }
import from tests.fixtures_list { MICRO_JAC_FILES }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     GAP_DIR = os.path.join(
         JAC_ROOT, "tests", "compiler", "fixtures", "rd_parser_gaps"
     );

"""Parse source with the RD parser, returning a Module or None on error."""
def parse_with_rd(source: str, file_path: str) -> Module | None {
    try {
        import from jaclang.jac0core.parser.parser { parse }
        (module, parse_errors, lex_errors) = parse(source, file_path);
        if lex_errors or parse_errors {
            return None;
        }
        return module;
    } except Exception {
        return None;
    }
}

"""Verify RD parser can parse a single file without errors."""
def rd_parser_test(filename: str) -> None {
    source = read_file_with_encoding(filename);
    saved_test_count = JacTest.TEST_COUNT;
    rd_ast = parse_with_rd(source, filename);
    JacTest.TEST_COUNT = saved_test_count;
    assert rd_ast is not None , f"RD parser failed to parse {filename}";
}

def rd_parse_file_test(rel_path: str) -> None {
    filename = os.path.normpath(os.path.join(JAC_ROOT, rel_path));
    if not os.path.exists(filename) {
        return;
    }
    rd_parser_test(filename);
}

def rd_gap_test(gap_file: str) -> None {
    filepath = os.path.join(GAP_DIR, gap_file);
    assert os.path.exists(filepath) , f"Gap file missing: {filepath}";
    rd_parser_test(filepath);
}

glob GAP_FILES = [
         "skip_stmt.jac",
         "matmul_eq.jac",
         "native_ctx.jac",
         "typed_ctx_block.jac",
         "sem_def_is.jac",
         "impl_in_archetype.jac",
         "raw_fstrings.jac",
         "yield_in_parens.jac",
         "lambda_star_params.jac",
         "yield_in_assignment.jac",
         "async_with.jac",
         "async_compr.jac",
         "async_for.jac",
         "impl_event_clause.jac",
         "impl_by_expr.jac",
         "fstring_nested_fmt.jac",
         "match_multistring.jac",
         "enum_pynline.jac",
         "enum_free_code.jac",
         "trailing_comma_collections.jac",
         "safe_call_subscript.jac",
         "bool_operators_symbols.jac",
         "init_as_call.jac",
         "decorator_on_impl.jac",
         "rstring_concat.jac",
         "impl_in_code_block.jac",
         "enum_impl_typed.jac",
         "glob_chained_assign.jac",
         "edge_ref_subscript.jac",
         "lambda_typed_params.jac"
     ],
     MUST_REJECT: dict[str, str] = {
         "can_without_event_clause": "obj Foo { can bar { } }",
         "per_variable_access_tag": "obj Foo { has :pub x: int, :priv y: str; }",
         "pass_keyword": "with entry { match x { case 1: pass; } }",
         "with_exit_at_module_level": 'with exit { print("bye"); }',
         "abs_prefix_on_ability": "obj Foo { abs def bar(); }",
         "abs_prefix_decorated_ability": "@mydeco abs def bar() { }",
         "bare_expression_at_module_level": "5 + 3;",
         "bare_expression_in_archetype": "obj Foo { 5 + 3; }",
         "impl_bare_semicolon": "impl Foo.bar;",
         "bare_assignment_at_module_level": "x = 5;",
         "bare_if_at_module_level": "if true { }",
         "bare_while_at_module_level": "while true { }",
         "bare_for_at_module_level": "for x in [1,2,3] { }",
         "bare_try_at_module_level": "try { } except Exception e { }",
         "bare_return_at_module_level": "return 5;",
         "bare_yield_at_module_level": "yield 5;",
         "bare_break_at_module_level": "break;",
         "bare_continue_at_module_level": "continue;",
         "bare_del_at_module_level": "del x;",
         "walrus_at_module_level": "x := 5;",
         "has_without_type": "obj Foo { has x; }",
         "has_outside_archetype": "has x: int;",
         "has_with_var_keyword": "obj Foo { has var x: int; }",
         "has_missing_semi": "obj Foo { has x: int }",
         "has_multiple_colons": "obj Foo { has x: int: str; }",
         "can_with_parens": "obj Foo { can bar() with entry { } }",
         "ability_missing_body_or_semi": "obj Foo { def bar() }",
         "obj_missing_name": "obj { }",
         "double_inheritance": "obj Foo(Bar)(Baz) { }",
         "enum_with_has": "enum Color { has x: int; }",
         "import_from_missing_braces": "import from foo bar;",
         "import_star_no_from": "import *;",
         "static_static_def": "obj Foo { static static def bar() { } }",
         "override_override_def": "obj Foo { override override def bar() { } }",
         "async_async_def": "obj Foo { async async def bar() { } }",
         "double_access_tag": "obj Foo { has :pub :pub x: int; }",
         "double_walrus": "with entry { x := y := 5; }",
         "assignment_as_expression": "with entry { x = y = (a = 5); }",
         "match_case_no_colon": "with entry { match x { case 1 x = 1; } }",
         "for_missing_in": "with entry { for x [1,2,3] { } }",
         "for_to_missing_by": "with entry { for i = 0 to 10 { } }",
         "while_missing_body": "with entry { while true; }",
         "match_missing_expression": "with entry { match { case 1: x=1; } }",
         "for_empty_iter": "with entry { for x in { } }",
         "while_empty_condition": "with entry { while { } }",
         "test_with_semi": "test foo;",
         "impl_without_target": "impl { }",
         "impl_invalid_spec": "impl (int) -> int { }",
         "decorator_alone": "@foo",
         "decorator_on_has": "obj Foo { @bar has x: int; }",
         "decorator_on_glob": "@deco glob x: int = 5;",
         "glob_without_assign": "glob;",
         "visit_missing_expr": "with entry { visit; }",
         "spawn_as_statement": "with entry { spawn; }",
         "import_missing_semi": "import foo",
         "include_missing_semi": "include foo",
         "return_missing_semi": "with entry { return 5 }",
         "assert_missing_semi": "with entry { assert true }",
         "raise_missing_semi": "with entry { raise Exception() }",
         "delete_missing_semi": "with entry { del x }",
         "global_missing_semi": "with entry { global x }",
         "nonlocal_missing_semi": "with entry { nonlocal x }",
         "obj_missing_body_or_semi": "obj Foo",
         "elif_without_if": "with entry { elif true { } }",
         "else_without_if": "with entry { else { } }",
         "except_without_try": "with entry { except Exception e { } }",
         "finally_without_try": "with entry { finally { } }",
         "case_without_match": "with entry { case 1: x = 1; }",
         "empty_match_body": "with entry { match x { } }",
         "empty_switch_body": "with entry { switch x { } }",
         "try_no_except_no_finally": "with entry { try { } }",
         "break_with_value": "with entry { break 5; }",
         "continue_with_value": "with entry { continue 5; }",
         "double_else_on_if": "with entry { if true { } else { } else { } }",
         "from_import_empty_items": "import from foo { };",
         "bare_semi_at_module_level": ";",
         "enum_empty_body": "enum Color { }"
     };

def strictness_test(name_snippet: tuple) -> None {
    (name, snippet) = name_snippet;
    rd_ast = parse_with_rd(snippet, "/tmp/strictness_test.jac");
    assert rd_ast is None , f"RD parser must reject '{name}': {snippet}";
}

with entry {
    parametrize(
        "rd parse", MICRO_JAC_FILES, rd_parse_file_test, id_fn=lambda f : Path(f).stem
    );
    parametrize(
        "rd gap", GAP_FILES, rd_gap_test, id_fn=lambda f : f.replace(".jac", "")
    );
    parametrize(
        "rd strict", list(MUST_REJECT.items()), strictness_test, id_fn=lambda x : x[0]
    );
}
