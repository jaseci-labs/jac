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
# RD parser strictness tests
# =============================================================================

# Snippets the RD parser must reject.
_MUST_REJECT = {
    "can_without_event_clause": "obj Foo { can bar { } }",
    "per_variable_access_tag": "obj Foo { has :pub x: int, :priv y: str; }",
    "pass_keyword": "with entry { match x { case 1: pass; } }",
    "with_exit_at_module_level": 'with exit { print("bye"); }',
    "abs_prefix_on_ability": "obj Foo { abs def bar(); }",
    "abs_prefix_decorated_ability": "@mydeco abs def bar() { }",
    "bare_expression_at_module_level": "5 + 3;",
    "bare_expression_in_archetype": "obj Foo { 5 + 3; }",
    "impl_bare_semicolon": "impl Foo.bar;",
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
