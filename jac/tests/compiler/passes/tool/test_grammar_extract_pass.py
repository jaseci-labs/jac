"""Tests for GrammarExtractPass.

Validates that grammar rules can be extracted from parser implementation
AST and that the EBNF/Lark output is correct.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from jaclang.compiler.passes.tool.grammar_extract_pass import (
    GAlt,
    GOpt,
    GrammarExtractPass,
    GrammarRule,
    GRef,
    GSeq,
    GStar,
    GTok,
)
from jaclang.jac0core.program import JacProgram

PARSER_PATH = (
    Path(__file__).parent.parent.parent.parent.parent
    / "jaclang"
    / "jac0core"
    / "parser"
    / "parser.jac"
)

SPEC_PATH = Path(__file__).parent.parent.parent.parent.parent / "jaclang" / "jac.spec"


def _parse_spec(text: str) -> dict[str, str]:
    """Parse EBNF text into {rule_name: rule_body} dict.

    Handles multi-line rules by detecting lines without '::='.
    """
    rules: dict[str, str] = {}
    current_name: str | None = None
    current_body: str = ""
    for line in text.strip().splitlines():
        line = line.rstrip()
        if not line or line.startswith("#") or line.startswith("//"):
            continue
        if "::=" in line:
            # Flush previous rule
            if current_name is not None:
                rules[current_name] = _normalize_body(current_body)
            name, _, body = line.partition("::=")
            current_name = name.strip()
            current_body = body.strip()
        elif current_name is not None:
            # Continuation line (e.g. "| alt" or indented sequence)
            stripped = line.strip()
            if stripped.startswith("| "):
                current_body += " " + stripped
            else:
                current_body += " " + stripped
    # Flush last rule
    if current_name is not None:
        rules[current_name] = _normalize_body(current_body)
    return rules


def _normalize_body(body: str) -> str:
    """Normalize rule body by collapsing whitespace."""
    return " ".join(body.split())


def _fmt(expr: GSeq | GAlt | GOpt | GStar | GTok | GRef) -> str:
    """Helper: format a GExpr as EBNF using the pass method."""
    return GrammarExtractPass.format_ebnf(None, expr)  # type: ignore[arg-type]


def _simplify(
    expr: GSeq | GAlt | GOpt | GStar | GTok | GRef,
) -> GSeq | GAlt | GOpt | GStar | GTok | GRef:
    """Helper: simplify a GExpr using the pass method."""
    return GrammarExtractPass.simplify_expr(None, expr)  # type: ignore[arg-type]


# =========================================================================
# Unit tests for grammar model and formatting
# =========================================================================


class TestGrammarModel:
    """Test grammar expression types and EBNF formatting."""

    def test_gtok_ebnf(self) -> None:
        assert _fmt(GTok(name="KW_IF")) == "KW_IF"

    def test_gref_ebnf(self) -> None:
        assert _fmt(GRef(name="expression")) == "expression"

    def test_gseq_ebnf(self) -> None:
        seq = GSeq(items=[GTok(name="KW_IF"), GRef(name="expression")])
        assert _fmt(seq) == "KW_IF expression"

    def test_galt_ebnf(self) -> None:
        alt = GAlt(choices=[GRef(name="elif_stmt"), GRef(name="else_stmt")])
        assert _fmt(alt) == "elif_stmt | else_stmt"

    def test_gopt_ebnf(self) -> None:
        opt = GOpt(inner=GRef(name="else_stmt"))
        assert _fmt(opt) == "else_stmt?"

    def test_gopt_alt_ebnf(self) -> None:
        opt = GOpt(inner=GAlt(choices=[GRef(name="elif_stmt"), GRef(name="else_stmt")]))
        assert _fmt(opt) == "(elif_stmt | else_stmt)?"

    def test_gstar_ebnf(self) -> None:
        star = GStar(inner=GSeq(items=[GTok(name="BW_OR"), GRef(name="bitwise_xor")]))
        assert _fmt(star) == "(BW_OR bitwise_xor)*"

    def test_grammar_rule_ebnf(self) -> None:
        rule = GrammarRule(
            name="bitwise_or",
            body=GSeq(
                items=[
                    GRef(name="bitwise_xor"),
                    GStar(
                        inner=GSeq(items=[GTok(name="BW_OR"), GRef(name="bitwise_xor")])
                    ),
                ]
            ),
        )
        ebnf = rule.to_ebnf()
        assert ebnf == "bitwise_or ::= bitwise_xor (BW_OR bitwise_xor)*"

    def test_alt_inside_seq_gets_parens(self) -> None:
        seq = GSeq(
            items=[
                GTok(name="A"),
                GAlt(choices=[GTok(name="B"), GTok(name="C")]),
            ]
        )
        assert _fmt(seq) == "A (B | C)"

    def test_simplify_nested_seq(self) -> None:
        expr = GSeq(
            items=[
                GTok(name="A"),
                GSeq(items=[GTok(name="B"), GTok(name="C")]),
            ]
        )
        simplified = _simplify(expr)
        assert _fmt(simplified) == "A B C"

    def test_simplify_single_item_seq(self) -> None:
        expr = GSeq(items=[GTok(name="A")])
        simplified = _simplify(expr)
        assert _fmt(simplified) == "A"

    def test_simplify_nested_alt(self) -> None:
        expr = GAlt(
            choices=[
                GTok(name="A"),
                GAlt(choices=[GTok(name="B"), GTok(name="C")]),
            ]
        )
        simplified = _simplify(expr)
        assert _fmt(simplified) == "A | B | C"

    def test_equality(self) -> None:
        assert GTok(name="X") == GTok(name="X")
        assert GRef(name="foo") == GRef(name="foo")
        assert GTok(name="X") != GTok(name="Y")
        assert GTok(name="X") != GRef(name="X")


# =========================================================================
# Integration test: extract rules from the real parser
# =========================================================================


class TestGrammarExtraction:
    """Test grammar extraction from the actual Jac parser module."""

    @pytest.fixture(scope="class")
    def extracted(self) -> GrammarExtractPass:
        """Compile the parser module and run GrammarExtractPass."""
        prog = JacProgram()
        mod = prog.compile(str(PARSER_PATH), no_cgen=True)
        errors = [str(e) for e in prog.errors_had] if prog.errors_had else []
        assert not prog.errors_had, f"Compilation errors: {errors}"
        return GrammarExtractPass(ir_in=mod, prog=prog)

    def test_rules_extracted(self, extracted: GrammarExtractPass) -> None:
        """Verify that a significant number of rules were found."""
        assert len(extracted.rules) > 20, (
            f"Expected >20 rules, got {len(extracted.rules)}: "
            f"{[r.name for r in extracted.rules]}"
        )

    def test_known_rule_names(self, extracted: GrammarExtractPass) -> None:
        """Verify that known rule names are present."""
        rule_names = {r.name for r in extracted.rules}
        expected = {
            "if_stmt",
            "while_stmt",
            "expression",
            "bitwise_or",
            "bitwise_xor",
            "bitwise_and",
            "arithmetic",
            "term",
            "power",
            "factor",
        }
        missing = expected - rule_names
        assert len(missing) == 0, f"Missing rules: {missing}"

    def test_bitwise_or_structure(self, extracted: GrammarExtractPass) -> None:
        """Verify bitwise_or rule: bitwise_xor (BW_OR bitwise_xor)*."""
        rule_map = {r.name: r for r in extracted.rules}
        assert "bitwise_or" in rule_map
        ebnf = _fmt(rule_map["bitwise_or"].body)
        assert "bitwise_xor" in ebnf
        assert "BW_OR" in ebnf

    def test_if_stmt_structure(self, extracted: GrammarExtractPass) -> None:
        """Verify if_stmt contains expected terminals and non-terminals."""
        rule_map = {r.name: r for r in extracted.rules}
        assert "if_stmt" in rule_map
        ebnf = _fmt(rule_map["if_stmt"].body)
        assert "KW_IF" in ebnf
        assert "expression" in ebnf
        assert "LBRACE" in ebnf
        assert "RBRACE" in ebnf

    def test_while_stmt_structure(self, extracted: GrammarExtractPass) -> None:
        """Verify while_stmt contains expected elements."""
        rule_map = {r.name: r for r in extracted.rules}
        assert "while_stmt" in rule_map
        ebnf = _fmt(rule_map["while_stmt"].body)
        assert "KW_WHILE" in ebnf
        assert "expression" in ebnf

    def test_ebnf_output_nonempty(self, extracted: GrammarExtractPass) -> None:
        """Verify that full EBNF output is non-empty and well-formed."""
        ebnf = extracted.emit_ebnf()
        assert len(ebnf) > 100
        assert "::=" in ebnf
        for line in ebnf.strip().split("\n"):
            s = line.strip()
            if not s:
                continue
            # Either a rule definition or a continuation (| alt or indented seq)
            assert "::=" in line or line.startswith(" "), f"Malformed line: {line}"

    def test_lark_output_nonempty(self, extracted: GrammarExtractPass) -> None:
        """Verify that Lark output uses colon syntax."""
        lark = extracted.emit_lark()
        assert len(lark) > 100
        for line in lark.strip().split("\n"):
            s = line.strip()
            if not s:
                continue
            assert ":" in line or line.startswith(" "), f"Malformed line: {line}"

    def test_no_duplicate_rules(self, extracted: GrammarExtractPass) -> None:
        """Verify there are no duplicate rule names."""
        names = [r.name for r in extracted.rules]
        assert len(names) == len(set(names)), (
            f"Duplicate rules: {[n for n in names if names.count(n) > 1]}"
        )

    def test_rules_reference_valid_names(self, extracted: GrammarExtractPass) -> None:
        """Verify that GRef names mostly reference existing rules."""
        rule_names = {r.name for r in extracted.rules}

        def collect_refs(
            expr: GSeq | GAlt | GOpt | GStar | GTok | GRef,
        ) -> set[str]:
            refs: set[str] = set()
            if isinstance(expr, GRef):
                refs.add(expr.name)
            elif isinstance(expr, GSeq):
                for item in expr.items:
                    refs.update(collect_refs(item))
            elif isinstance(expr, GAlt):
                for choice in expr.choices:
                    refs.update(collect_refs(choice))
            elif isinstance(expr, (GOpt, GStar)):
                refs.update(collect_refs(expr.inner))
            return refs

        all_refs: set[str] = set()
        for rule in extracted.rules:
            all_refs.update(collect_refs(rule.body))

        # At least some refs should resolve to known rules
        resolved = all_refs & rule_names
        assert len(resolved) > 10, f"Only {len(resolved)} refs resolved to known rules"


# =========================================================================
# Snapshot test: grammar output matches jac.spec
# =========================================================================


class TestGrammarSpec:
    """Verify extracted grammar matches the checked-in jac.spec golden file."""

    @pytest.fixture(scope="class")
    def extracted(self) -> GrammarExtractPass:
        prog = JacProgram()
        mod = prog.compile(str(PARSER_PATH), no_cgen=True)
        assert not prog.errors_had
        return GrammarExtractPass(ir_in=mod, prog=prog)

    def test_spec_file_exists(self) -> None:
        assert SPEC_PATH.exists(), (
            f"Grammar spec file missing: {SPEC_PATH}\n"
            f"Generate it with: jac grammar -o {SPEC_PATH}"
        )

    def test_grammar_matches_spec(self, extracted: GrammarExtractPass) -> None:
        """Each extracted rule must match the corresponding rule in jac.spec.

        If this test fails, a parser change altered the grammar. Review the
        diff and, if intentional, update the spec:

            jac grammar -o jac/jaclang/jac.spec
        """
        if not SPEC_PATH.exists():
            pytest.skip("jac.spec not found")

        spec_rules = _parse_spec(SPEC_PATH.read_text())
        current_rules = _parse_spec(extracted.emit_ebnf())

        # Check for rules in spec that disappeared
        missing = set(spec_rules) - set(current_rules)
        assert not missing, (
            f"Rules in jac.spec but no longer extracted: {missing}\n"
            f"If intentional: jac grammar -o jac/jaclang/jac.spec"
        )

        # Check for new rules not in spec
        added = set(current_rules) - set(spec_rules)
        assert not added, (
            f"New rules not in jac.spec: {added}\n"
            f"If intentional: jac grammar -o jac/jaclang/jac.spec"
        )

        # Check each rule body matches
        changed: list[str] = []
        for name in sorted(spec_rules):
            if name not in current_rules:
                continue
            if spec_rules[name] != current_rules[name]:
                changed.append(
                    f"  {name}:\n"
                    f"    spec:    {spec_rules[name]}\n"
                    f"    current: {current_rules[name]}"
                )
        assert not changed, (
            f"{len(changed)} rule(s) changed:\n"
            + "\n".join(changed)
            + "\n\nIf intentional: jac grammar -o jac/jaclang/jac.spec"
        )
