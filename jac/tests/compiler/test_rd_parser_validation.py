"""Validate the RD parser on the full micro suite and gap coverage files.

Each .jac file becomes its own test case. For each file:
1. Parse with the RD parser
2. Verify no errors are produced
"""

import os
from pathlib import Path

import pytest

from conftest import get_micro_jac_files
from jaclang.jac0core.unitree import Module
from jaclang.jac0core.unitree import (
    Test as JacTest,
)
from jaclang.runtimelib.utils import read_file_with_encoding

# =============================================================================
# Parsing Helpers
# =============================================================================


def parse_with_rd(source: str, file_path: str) -> Module | None:
    """Parse source with the RD parser, returning a Module or None on error."""
    try:
        from jaclang.jac0core.parser.parser import parse

        module, parse_errors, lex_errors = parse(source, file_path)
        if lex_errors or parse_errors:
            return None
        return module
    except Exception:
        return None


# =============================================================================
# Core Test
# =============================================================================


def rd_parser_test(filename: str) -> None:
    """Verify RD parser can parse a single file without errors."""
    source = read_file_with_encoding(filename)

    saved_test_count = JacTest.TEST_COUNT
    rd_ast = parse_with_rd(source, filename)
    JacTest.TEST_COUNT = saved_test_count
    assert rd_ast is not None, f"RD parser failed to parse {filename}"


# =============================================================================
# Auto-generated parametrized tests
# =============================================================================


def pytest_generate_tests(metafunc: pytest.Metafunc) -> None:
    """Generate one test case per micro suite file."""
    if "micro_jac_file" in metafunc.fixturenames:
        files = get_micro_jac_files()
        metafunc.parametrize(
            "micro_jac_file", files, ids=lambda f: f.replace(os.sep, "_")
        )


def test_micro_suite(micro_jac_file: str) -> None:
    """Verify RD parser can parse micro suite files."""
    rd_parser_test(micro_jac_file)


# =============================================================================
# RD parser gap coverage tests
# =============================================================================

_gap_base_dir = str(Path(__file__).parent.parent.parent)
_gap_files = [
    os.path.normpath(os.path.join(_gap_base_dir, f))
    for f in [
        "tests/compiler/fixtures/rd_parser_gaps/skip_stmt.jac",
        "tests/compiler/fixtures/rd_parser_gaps/matmul_eq.jac",
        "tests/compiler/fixtures/rd_parser_gaps/native_ctx.jac",
        "tests/compiler/fixtures/rd_parser_gaps/typed_ctx_block.jac",
        "tests/compiler/fixtures/rd_parser_gaps/sem_def_is.jac",
        "tests/compiler/fixtures/rd_parser_gaps/impl_in_archetype.jac",
        "tests/compiler/fixtures/rd_parser_gaps/raw_fstrings.jac",
        "tests/compiler/fixtures/rd_parser_gaps/yield_in_parens.jac",
        "tests/compiler/fixtures/rd_parser_gaps/lambda_star_params.jac",
        "tests/compiler/fixtures/rd_parser_gaps/yield_in_assignment.jac",
        "tests/compiler/fixtures/rd_parser_gaps/async_with.jac",
        "tests/compiler/fixtures/rd_parser_gaps/async_compr.jac",
        "tests/compiler/fixtures/rd_parser_gaps/async_for.jac",
        "tests/compiler/fixtures/rd_parser_gaps/impl_event_clause.jac",
        "tests/compiler/fixtures/rd_parser_gaps/impl_by_expr.jac",
        "tests/compiler/fixtures/rd_parser_gaps/fstring_nested_fmt.jac",
        "tests/compiler/fixtures/rd_parser_gaps/match_multistring.jac",
        "tests/compiler/fixtures/rd_parser_gaps/enum_pynline.jac",
        "tests/compiler/fixtures/rd_parser_gaps/enum_free_code.jac",
        "tests/compiler/fixtures/rd_parser_gaps/trailing_comma_collections.jac",
        "tests/compiler/fixtures/rd_parser_gaps/safe_call_subscript.jac",
        "tests/compiler/fixtures/rd_parser_gaps/bool_operators_symbols.jac",
        "tests/compiler/fixtures/rd_parser_gaps/init_as_call.jac",
        "tests/compiler/fixtures/rd_parser_gaps/decorator_on_impl.jac",
        "tests/compiler/fixtures/rd_parser_gaps/rstring_concat.jac",
        "tests/compiler/fixtures/rd_parser_gaps/impl_in_code_block.jac",
        "tests/compiler/fixtures/rd_parser_gaps/enum_impl_typed.jac",
        "tests/compiler/fixtures/rd_parser_gaps/glob_chained_assign.jac",
        "tests/compiler/fixtures/rd_parser_gaps/edge_ref_subscript.jac",
        "tests/compiler/fixtures/rd_parser_gaps/lambda_typed_params.jac",
    ]
]


@pytest.mark.parametrize(
    "gap_file",
    _gap_files,
    ids=lambda f: os.path.basename(f).replace(".jac", ""),
)
def test_rd_parser_gap_coverage(gap_file: str) -> None:
    """Verify RD parser correctly handles previously missing grammar constructs."""
    rd_parser_test(gap_file)


# =============================================================================
# RD parser strictness tests — currently enforced
# =============================================================================

# Snippets the RD parser must reject (parser already rejects these correctly).
_MUST_REJECT = {
    # --- Original tests ---
    "can_without_event_clause": "obj Foo { can bar { } }",
    "per_variable_access_tag": "obj Foo { has :pub x: int, :priv y: str; }",
    "pass_keyword": "with entry { match x { case 1: pass; } }",
    "with_exit_at_module_level": 'with exit { print("bye"); }',
    "abs_prefix_on_ability": "obj Foo { abs def bar(); }",
    "abs_prefix_decorated_ability": "@mydeco abs def bar() { }",
    "bare_expression_at_module_level": "5 + 3;",
    "bare_expression_in_archetype": "obj Foo { 5 + 3; }",
    "impl_bare_semicolon": "impl Foo.bar;",
    # --- Module-level: statements that belong inside code blocks ---
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
    # --- Has statement strictness ---
    "has_without_type": "obj Foo { has x; }",
    "has_outside_archetype": "has x: int;",
    "has_with_var_keyword": "obj Foo { has var x: int; }",
    "has_missing_semi": "obj Foo { has x: int }",
    "has_multiple_colons": "obj Foo { has x: int: str; }",
    # --- Ability/function strictness ---
    "can_with_parens": "obj Foo { can bar() with entry { } }",
    "ability_missing_body_or_semi": "obj Foo { def bar() }",
    # --- Archetype strictness ---
    "obj_missing_name": "obj { }",
    "double_inheritance": "obj Foo(Bar)(Baz) { }",
    "enum_with_has": "enum Color { has x: int; }",
    # --- Import strictness ---
    "import_from_missing_braces": "import from foo bar;",
    "import_star_no_from": "import *;",
    # --- Duplicate modifiers ---
    "static_static_def": "obj Foo { static static def bar() { } }",
    "override_override_def": "obj Foo { override override def bar() { } }",
    "async_async_def": "obj Foo { async async def bar() { } }",
    "double_access_tag": "obj Foo { has :pub :pub x: int; }",
    # --- Expression/assignment strictness ---
    "double_walrus": "with entry { x := y := 5; }",
    "assignment_as_expression": "with entry { x = y = (a = 5); }",
    # --- Structural requirements ---
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
    # --- Missing required semicolons (lark requires SEMI) ---
    "import_missing_semi": "import foo",
    "include_missing_semi": "include foo",
    "return_missing_semi": "with entry { return 5 }",
    "assert_missing_semi": "with entry { assert true }",
    "raise_missing_semi": "with entry { raise Exception() }",
    "delete_missing_semi": "with entry { del x }",
    "global_missing_semi": "with entry { global x }",
    "nonlocal_missing_semi": "with entry { nonlocal x }",
    # --- Missing required body/terminator ---
    "obj_missing_body_or_semi": "obj Foo",
    # --- Orphaned control-flow clauses (not valid as standalone statements) ---
    "elif_without_if": "with entry { elif true { } }",
    "else_without_if": "with entry { else { } }",
    "except_without_try": "with entry { except Exception e { } }",
    "finally_without_try": "with entry { finally { } }",
    "case_without_match": "with entry { case 1: x = 1; }",
    # --- Empty required blocks ---
    "empty_match_body": "with entry { match x { } }",
    "empty_switch_body": "with entry { switch x { } }",
    # --- try without except or finally ---
    "try_no_except_no_finally": "with entry { try { } }",
    # --- Control statements with spurious values ---
    "break_with_value": "with entry { break 5; }",
    "continue_with_value": "with entry { continue 5; }",
    # --- Double else ---
    "double_else_on_if": "with entry { if true { } else { } else { } }",
    # --- from-import with empty items ---
    "from_import_empty_items": "import from foo { };",
    # --- Bare semi at module level ---
    "bare_semi_at_module_level": ";",
    # --- enum with empty body ---
    "enum_empty_body": "enum Color { }",
}


@pytest.mark.parametrize(
    "snippet",
    list(_MUST_REJECT.values()),
    ids=list(_MUST_REJECT.keys()),
)
def test_rd_parser_strictness(snippet: str) -> None:
    """RD parser must reject invalid constructs."""
    rd_ast = parse_with_rd(snippet, "/tmp/strictness_test.jac")
    assert rd_ast is None, f"RD parser must reject: {snippet!r}"
