"""Validate the RD parser against the Lark parser on the full micro suite.

Each .jac file in the micro suite becomes its own test case. For each file:
1. Parse with the Lark-based parser (reference)
2. Parse with the RD parser (under test)
3. Compare the AST structures

The comparison uses a recursive canonicalization that captures node types
and semantic field values while ignoring position/location info.
"""

import os
from difflib import unified_diff

import pytest

from conftest import get_micro_jac_files
from jaclang.pycore.jac_parser import JacParser
from jaclang.pycore.program import JacProgram
from jaclang.pycore.unitree import Module, Source, Token, UniNode
from jaclang.runtimelib.utils import read_file_with_encoding

# =============================================================================
# AST Canonicalization
# =============================================================================


def canonicalize(node: UniNode, indent: int = 0) -> str:
    """Produce a canonical string representation of a unitree AST.

    Captures node types and semantic values (names, literals, operators)
    while ignoring position info so that the two parsers can be compared
    purely on structural output.
    """
    prefix = "  " * indent
    if isinstance(node, Token):
        return f"{prefix}{node.__class__.__name__}: {node.value!r}\n"

    lines = f"{prefix}{node.__class__.__name__}\n"
    for child in node.kid:
        lines += canonicalize(child, indent + 1)
    return lines


# =============================================================================
# Parsing Helpers
# =============================================================================


def parse_with_lark(source: str, file_path: str) -> Module | None:
    """Parse source with the Lark parser, returning a Module or None on error."""
    try:
        prse = JacParser(
            root_ir=Source(source, mod_path=file_path),
            prog=JacProgram(),
        )
        if prse.errors_had:
            return None
        return prse.ir_out
    except Exception:
        return None


def parse_with_rd(source: str, file_path: str) -> Module | None:
    """Parse source with the RD parser, returning a Module or None on error."""
    try:
        from jaclang.parser.parser import parse

        module, parse_errors, lex_errors = parse(source, file_path)
        if lex_errors or parse_errors:
            return None
        return module
    except Exception:
        return None


# =============================================================================
# Core Comparison
# =============================================================================


def rd_parser_comparison_test(filename: str) -> None:
    """Compare Lark and RD parse trees for a single file."""
    source = read_file_with_encoding(filename)

    lark_ast = parse_with_lark(source, filename)
    if lark_ast is None:
        pytest.skip(f"Lark parser cannot parse {filename}")
        return  # unreachable, but helps mypy

    rd_ast = parse_with_rd(source, filename)
    assert rd_ast is not None, f"RD parser failed to parse {filename}"

    lark_canon = canonicalize(lark_ast)
    rd_canon = canonicalize(rd_ast)

    if lark_canon != rd_canon:
        diff = "\n".join(
            unified_diff(
                lark_canon.splitlines(),
                rd_canon.splitlines(),
                fromfile="lark",
                tofile="rd",
                lineterm="",
            )
        )
        raise AssertionError(f"AST mismatch in {os.path.basename(filename)}:\n{diff}")


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
    """Compare Lark and RD parse trees for a micro suite file."""
    rd_parser_comparison_test(micro_jac_file)
