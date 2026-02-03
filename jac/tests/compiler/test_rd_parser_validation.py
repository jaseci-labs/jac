"""Test harness for validating the hand-written recursive descent parser.

This module compares the output of the new RD parser against the Lark-based parser
to validate grammar coverage and correctness.

The comparison is done by:
1. Parsing files with both parsers
2. Converting ASTs to a canonical representation
3. Computing structural differences

Note: This test requires the RD parser to be bootstrapped first. Until then,
these tests serve as a specification for the expected behavior.
"""

import os
from collections.abc import Callable
from dataclasses import dataclass, field
from difflib import unified_diff
from pathlib import Path
from typing import Any

import pytest

from jaclang.pycore.jac_parser import JacParser
from jaclang.pycore.program import JacProgram
from jaclang.pycore.unitree import Source, UniNode
from tests.fixtures_list import MICRO_JAC_FILES

# =============================================================================
# AST Canonicalization
# =============================================================================


@dataclass
class CanonicalNode:
    """Canonical representation of an AST node for comparison."""

    node_type: str
    fields: dict[str, Any] = field(default_factory=dict)
    children: list["CanonicalNode"] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for comparison."""
        return {
            "type": self.node_type,
            "fields": self.fields,
            "children": [c.to_dict() for c in self.children],
        }

    def to_string(self, indent: int = 0) -> str:
        """Convert to string representation."""
        prefix = "  " * indent
        lines = [f"{prefix}{self.node_type}"]
        for key, value in sorted(self.fields.items()):
            lines.append(f"{prefix}  {key}: {value}")
        for child in self.children:
            lines.append(child.to_string(indent + 1))
        return "\n".join(lines)


def canonicalize_lark_ast(node: UniNode) -> CanonicalNode:
    """Convert Lark parser AST to canonical form.

    This traverses the unitree AST and extracts a simplified
    representation suitable for comparison.
    """
    # Get node type name
    node_type = type(node).__name__

    # Extract relevant fields (excluding internal/parent references)
    fields: dict[str, Any] = {}
    excluded_fields = {
        "parent",
        "kid",
        "gen",
        "_sym_tab",
        "loc",
        "_sub_node_tab",
        "_jac_captured_",
    }

    for attr_name in dir(node):
        if attr_name.startswith("_") or attr_name in excluded_fields:
            continue
        if callable(getattr(node, attr_name, None)):
            continue

        try:
            value = getattr(node, attr_name)
            if value is None:
                continue
            if isinstance(value, UniNode):
                continue  # Will be in children
            if isinstance(value, list) and all(isinstance(v, UniNode) for v in value):
                continue  # Will be in children
            # Store simple values
            if isinstance(value, (str, int, float, bool)):
                fields[attr_name] = value
        except Exception:
            pass

    # Extract children
    children: list[CanonicalNode] = []
    if hasattr(node, "kid") and node.kid:
        for child in node.kid:
            if isinstance(child, UniNode):
                children.append(canonicalize_lark_ast(child))

    return CanonicalNode(node_type=node_type, fields=fields, children=children)


# =============================================================================
# Parser Comparison
# =============================================================================


@dataclass
class ComparisonResult:
    """Result of comparing two parser outputs."""

    file_path: str
    lark_success: bool
    rd_success: bool
    lark_error: str | None = None
    rd_error: str | None = None
    structural_diff: str | None = None
    node_count_lark: int = 0
    node_count_rd: int = 0

    @property
    def is_match(self) -> bool:
        """Check if both parsers produced matching output."""
        return self.lark_success and self.rd_success and self.structural_diff is None

    def summary(self) -> str:
        """Return a summary string."""
        if self.is_match:
            return f"PASS: {self.file_path}"
        elif not self.lark_success:
            return f"LARK_FAIL: {self.file_path} - {self.lark_error}"
        elif not self.rd_success:
            return f"RD_FAIL: {self.file_path} - {self.rd_error}"
        else:
            return f"DIFF: {self.file_path} - structural mismatch"


def count_nodes(node: CanonicalNode) -> int:
    """Count total nodes in a canonical AST."""
    return 1 + sum(count_nodes(child) for child in node.children)


def parse_with_lark(
    source: str, file_path: str
) -> tuple[CanonicalNode | None, str | None]:
    """Parse source with Lark parser and return canonical AST."""
    try:
        prse = JacParser(
            root_ir=Source(source, mod_path=file_path),
            prog=JacProgram(),
        )
        if prse.errors_had:
            return None, str(prse.errors_had[0])
        return canonicalize_lark_ast(prse.ir_out), None
    except Exception as e:
        return None, str(e)


def parse_with_rd(
    source: str, file_path: str
) -> tuple[CanonicalNode | None, str | None]:
    """Parse source with RD parser and return canonical AST.

    NOTE: This is a placeholder. Once the RD parser is bootstrapped,
    this function will import and use the new parser.
    """
    # TODO: Import and use the RD parser once bootstrapped
    # from jaclang.parser.parser import parse
    # module, errors = parse(source, file_path)
    # if errors:
    #     return None, str(errors[0])
    # return canonicalize_rd_ast(module), None

    # For now, return a placeholder indicating RD parser not yet available
    return None, "RD parser not yet bootstrapped"


def compare_asts(lark_ast: CanonicalNode, rd_ast: CanonicalNode) -> str | None:
    """Compare two canonical ASTs and return diff if different."""
    lark_str = lark_ast.to_string()
    rd_str = rd_ast.to_string()

    if lark_str == rd_str:
        return None

    diff = "\n".join(
        unified_diff(
            lark_str.splitlines(),
            rd_str.splitlines(),
            fromfile="lark",
            tofile="rd",
            lineterm="",
        )
    )
    return diff


def compare_parsers(source: str, file_path: str) -> ComparisonResult:
    """Compare Lark and RD parser outputs for given source."""
    result = ComparisonResult(file_path=file_path, lark_success=False, rd_success=False)

    # Parse with Lark
    lark_ast, lark_error = parse_with_lark(source, file_path)
    if lark_ast:
        result.lark_success = True
        result.node_count_lark = count_nodes(lark_ast)
    else:
        result.lark_error = lark_error

    # Parse with RD
    rd_ast, rd_error = parse_with_rd(source, file_path)
    if rd_ast:
        result.rd_success = True
        result.node_count_rd = count_nodes(rd_ast)
    else:
        result.rd_error = rd_error

    # Compare if both succeeded
    if lark_ast and rd_ast:
        result.structural_diff = compare_asts(lark_ast, rd_ast)

    return result


# =============================================================================
# Test Utilities
# =============================================================================


def read_file_safe(file_path: str) -> str | None:
    """Read file with encoding detection."""
    try:
        from jaclang.runtimelib.utils import read_file_with_encoding

        return read_file_with_encoding(file_path)
    except Exception:
        return None


def get_test_files() -> list[str]:
    """Get list of test files from the micro suite."""
    base_dir = str(Path(__file__).parent.parent.parent)
    return [os.path.normpath(os.path.join(base_dir, f)) for f in MICRO_JAC_FILES]


# =============================================================================
# Lark Parser Validation Tests (These should always pass)
# =============================================================================


class TestLarkParserBaseline:
    """Baseline tests to ensure Lark parser works on test files."""

    def test_lark_parses_simple_code(self) -> None:
        """Test that Lark parser handles simple code."""
        source = """
obj MyClass {
    has value: int = 0;

    def get_value() -> int {
        return self.value;
    }
}
"""
        ast, error = parse_with_lark(source, "test.jac")
        assert ast is not None, f"Lark parse failed: {error}"
        assert ast.node_type == "Module"

    def test_lark_parses_expressions(self) -> None:
        """Test that Lark parser handles various expressions."""
        source = """
glob a = 1 + 2 * 3;
glob b = [1, 2, 3];
glob c = {"a": 1, "b": 2};
glob d = x if cond else y;
glob e = items |> filter |> map;
"""
        ast, error = parse_with_lark(source, "test.jac")
        assert ast is not None, f"Lark parse failed: {error}"

    def test_lark_parses_control_flow(self) -> None:
        """Test that Lark parser handles control flow."""
        source = """
def test_flow() {
    if x > 0 {
        print("positive");
    } elif x < 0 {
        print("negative");
    } else {
        print("zero");
    }

    for i in range(10) {
        if i == 5 {
            break;
        }
    }

    while running {
        process();
    }
}
"""
        ast, error = parse_with_lark(source, "test.jac")
        assert ast is not None, f"Lark parse failed: {error}"

    def test_lark_parses_graph_operations(self) -> None:
        """Test that Lark parser handles Jac graph operations."""
        source = """
walker MyWalker {
    can traverse with entry {
        visit [-->];
        report self.data;
    }
}

node MyNode {
    has data: str;
}

with entry {
    root ++> MyNode(data="hello");
}
"""
        ast, error = parse_with_lark(source, "test.jac")
        assert ast is not None, f"Lark parse failed: {error}"


# =============================================================================
# Parser Comparison Tests (Placeholder until RD parser is bootstrapped)
# =============================================================================


class TestRDParserComparison:
    """Tests comparing RD parser against Lark parser.

    These tests serve as specifications for the RD parser behavior.
    They will start passing once the RD parser is bootstrapped.
    """

    @pytest.mark.skip(reason="RD parser not yet bootstrapped")
    def test_simple_object(self) -> None:
        """Test parsing simple object declaration."""
        source = """
obj Point {
    has x: int = 0;
    has y: int = 0;
}
"""
        result = compare_parsers(source, "test.jac")
        assert result.is_match, result.summary()

    @pytest.mark.skip(reason="RD parser not yet bootstrapped")
    def test_expressions(self) -> None:
        """Test parsing various expressions."""
        source = """
glob a = 1 + 2 * 3 ** 4;
glob b = x and y or not z;
glob c = a < b <= c;
"""
        result = compare_parsers(source, "test.jac")
        assert result.is_match, result.summary()

    @pytest.mark.skip(reason="RD parser not yet bootstrapped")
    def test_f_strings(self) -> None:
        """Test parsing f-strings."""
        source = """
glob msg = f"Hello {name}!";
glob formatted = f"Value: {x:.2f}";
glob nested = f"Outer {f"inner {value}"}";
"""
        result = compare_parsers(source, "test.jac")
        assert result.is_match, result.summary()

    @pytest.mark.skip(reason="RD parser not yet bootstrapped")
    def test_pattern_matching(self) -> None:
        """Test parsing pattern matching."""
        source = """
match value {
    case [a, b, *rest]:
        print("list");
    case {"key": val}:
        print("dict");
    case Point(x=0, y=0):
        print("origin");
    case _:
        print("other");
}
"""
        result = compare_parsers(source, "test.jac")
        assert result.is_match, result.summary()


# =============================================================================
# Micro Suite Comparison (Placeholder)
# =============================================================================


@pytest.mark.skip(reason="RD parser not yet bootstrapped")
class TestMicroSuiteComparison:
    """Compare parsers on the full micro test suite."""

    @pytest.fixture
    def file_to_str(self) -> Callable[[str], str | None]:
        """Load file to string."""
        return read_file_safe

    def test_micro_suite_comparison(
        self, file_to_str: Callable[[str], str | None]
    ) -> None:
        """Compare parsers on all micro suite files."""
        results: list[ComparisonResult] = []
        test_files = get_test_files()

        for filepath in test_files[:10]:  # Limit for initial testing
            source = file_to_str(filepath)
            if source is None:
                continue
            result = compare_parsers(source, filepath)
            results.append(result)

        # Summary
        passed = sum(1 for r in results if r.is_match)
        lark_fail = sum(1 for r in results if not r.lark_success)
        rd_fail = sum(1 for r in results if not r.rd_success and r.lark_success)
        diff = sum(
            1 for r in results if r.lark_success and r.rd_success and r.structural_diff
        )

        print(
            f"\n\nResults: {passed} passed, {lark_fail} lark_fail, {rd_fail} rd_fail, {diff} diff"
        )

        # All should match once RD parser is complete
        assert passed == len(results), "Not all tests passed. Check individual results."


# =============================================================================
# Grammar Coverage Report
# =============================================================================


def generate_grammar_coverage_report() -> str:
    """Generate a report of grammar constructs found in test files.

    This helps identify which grammar rules are being tested.
    """
    from collections import Counter

    constructs: Counter[str] = Counter()
    test_files = get_test_files()

    for filepath in test_files:
        source = read_file_safe(filepath)
        if source is None:
            continue

        # Count key constructs
        if "obj " in source:
            constructs["obj"] += 1
        if "node " in source:
            constructs["node"] += 1
        if "edge " in source:
            constructs["edge"] += 1
        if "walker " in source:
            constructs["walker"] += 1
        if "can " in source:
            constructs["can/ability"] += 1
        if "has " in source:
            constructs["has"] += 1
        if "impl " in source:
            constructs["impl"] += 1
        if "enum " in source:
            constructs["enum"] += 1
        if "test " in source:
            constructs["test"] += 1
        if "match " in source:
            constructs["match"] += 1
        if "switch " in source:
            constructs["switch"] += 1
        if "|>" in source:
            constructs["pipe"] += 1
        if "-->" in source or "<--" in source:
            constructs["edge_op"] += 1
        if "spawn " in source:
            constructs["spawn"] += 1
        if "visit " in source:
            constructs["visit"] += 1
        if 'f"' in source or "f'" in source:
            constructs["f-string"] += 1
        if "::py::" in source:
            constructs["pynline"] += 1

    report = "Grammar Construct Coverage in Test Files:\n"
    report += "=" * 50 + "\n"
    for construct, count in constructs.most_common():
        report += f"  {construct}: {count} files\n"

    return report


if __name__ == "__main__":
    # Run coverage report when executed directly
    print(generate_grammar_coverage_report())
