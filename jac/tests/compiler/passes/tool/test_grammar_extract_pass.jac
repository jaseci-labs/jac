"""Grammar extraction pass tests – migrated from test_grammar_extract_pass.py.

Tests for grammar model types (GTok, GRef, GSeq, GAlt, GOpt, GStar),
EBNF/Lark formatting, simplification, and integration with the real
Jac parser module. Also validates grammar matches jac.spec.
"""

import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.tool.grammar_extract_pass {
    GAlt,
    GOpt,
    GrammarExtractPass,
    GrammarRule,
    GRef,
    GSeq,
    GStar,
    GTok
}
import from jaclang.jac0core.program { JacProgram }

glob PARSER_PATH = str(
         Path(jaclang.__file__).parent / "jac0core" / "parser" / "parser.jac"
     ),
     SPEC_PATH = str(Path(jaclang.__file__).parent.parent / "jaclang" / "jac.spec");

"""Helper: format a GExpr as EBNF."""
def fmt(expr: object) -> str {
    return GrammarExtractPass.format_ebnf(None, expr);
}

"""Helper: simplify a GExpr."""
def simplify(expr: object) -> object {
    return GrammarExtractPass.simplify_expr(None, expr);
}

"""Parse EBNF text into {rule_name: rule_body} dict."""
def parse_spec(text: str) -> dict[str, str] {
    rules: dict[str, str] = {};
    current_name: str | None = None;
    current_body: str = "";
    for line in text.strip().splitlines() {
        line = line.rstrip();
        if not line or line.startswith("#") or line.startswith("//") {
            continue;
        }
        if "::=" in line {
            if current_name is not None {
                rules[current_name] = " ".join(current_body.split());
            }
            (name, _, body) = line.partition("::=");
            current_name = name.strip();
            current_body = body.strip();
        } elif current_name is not None {
            stripped = line.strip();
            if stripped.startswith("| ") {
                current_body += " " + stripped;
            } else {
                current_body += " " + stripped;
            }
        }
    }
    if current_name is not None {
        rules[current_name] = " ".join(current_body.split());
    }
    return rules;
}

# ── Unit tests: grammar model and formatting ─────────────────────────────
test "gtok ebnf" {
    assert fmt(GTok(name="KW_IF")) == "KW_IF";
}

test "gref ebnf" {
    assert fmt(GRef(name="expression")) == "expression";
}

test "gseq ebnf" {
    seq = GSeq(items=[GTok(name="KW_IF"), GRef(name="expression")]);
    assert fmt(seq) == "KW_IF expression";
}

test "galt ebnf" {
    alt = GAlt(choices=[GRef(name="elif_stmt"), GRef(name="else_stmt")]);
    assert fmt(alt) == "elif_stmt | else_stmt";
}

test "gopt ebnf" {
    opt = GOpt(inner=GRef(name="else_stmt"));
    assert fmt(opt) == "else_stmt?";
}

test "gopt alt ebnf" {
    opt = GOpt(inner=GAlt(choices=[GRef(name="elif_stmt"), GRef(name="else_stmt")]));
    assert fmt(opt) == "(elif_stmt | else_stmt)?";
}

test "gstar ebnf" {
    star = GStar(inner=GSeq(items=[GTok(name="BW_OR"), GRef(name="bitwise_xor")]));
    assert fmt(star) == "(BW_OR bitwise_xor)*";
}

test "grammar rule ebnf" {
    rule = GrammarRule(
        name="bitwise_or",
        body=GSeq(
            items=[
                GRef(name="bitwise_xor"),
                GStar(inner=GSeq(items=[GTok(name="BW_OR"), GRef(name="bitwise_xor")]))
            ]
        )
    );
    ebnf = rule.to_ebnf();
    assert ebnf == "bitwise_or ::= bitwise_xor (BW_OR bitwise_xor)*";
}

test "alt inside seq gets parens" {
    seq = GSeq(items=[GTok(name="A"), GAlt(choices=[GTok(name="B"), GTok(name="C")])]);
    assert fmt(seq) == "A (B | C)";
}

test "simplify nested seq" {
    expr = GSeq(items=[GTok(name="A"), GSeq(items=[GTok(name="B"), GTok(name="C")])]);
    simplified = simplify(expr);
    assert fmt(simplified) == "A B C";
}

test "simplify single item seq" {
    expr = GSeq(items=[GTok(name="A")]);
    simplified = simplify(expr);
    assert fmt(simplified) == "A";
}

test "simplify nested alt" {
    expr = GAlt(
        choices=[GTok(name="A"), GAlt(choices=[GTok(name="B"), GTok(name="C")])]
    );
    simplified = simplify(expr);
    assert fmt(simplified) == "A | B | C";
}

test "equality" {
    assert GTok(name="X") == GTok(name="X");
    assert GRef(name="foo") == GRef(name="foo");
    assert GTok(name="X") != GTok(name="Y");
    assert GTok(name="X") != GRef(name="X");
}

# ── Integration: extract rules from the real parser ──────────────────────
test "rules extracted" {
    prog = JacProgram();
    mod = prog.compile(PARSER_PATH, no_cgen=True);
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";
    extracted = GrammarExtractPass(ir_in=mod, prog=prog);
    assert len(extracted.rules) > 20 , (
        f"Expected >20 rules, got {len(extracted.rules)}"
    );
}

test "known rule names" {
    prog = JacProgram();
    mod = prog.compile(PARSER_PATH, no_cgen=True);
    assert not prog.errors_had;
    extracted = GrammarExtractPass(ir_in=mod, prog=prog);
    rule_names = {r.name for r in extracted.rules};
    expected = {"if_stmt","while_stmt","expression","bitwise_or","bitwise_xor","bitwise_and","arithmetic","term","power","factor"};
    missing = expected - rule_names;
    assert len(missing) == 0 , f"Missing rules: {missing}";
}

test "bitwise or structure" {
    prog = JacProgram();
    mod = prog.compile(PARSER_PATH, no_cgen=True);
    assert not prog.errors_had;
    extracted = GrammarExtractPass(ir_in=mod, prog=prog);
    rule_map = {r.name: r for r in extracted.rules};
    assert "bitwise_or" in rule_map;
    ebnf = fmt(rule_map["bitwise_or"].body);
    assert "bitwise_xor" in ebnf;
    assert "BW_OR" in ebnf;
}

test "if stmt structure" {
    prog = JacProgram();
    mod = prog.compile(PARSER_PATH, no_cgen=True);
    assert not prog.errors_had;
    extracted = GrammarExtractPass(ir_in=mod, prog=prog);
    rule_map = {r.name: r for r in extracted.rules};
    assert "if_stmt" in rule_map;
    ebnf = fmt(rule_map["if_stmt"].body);
    assert "KW_IF" in ebnf;
    assert "expression" in ebnf;
    assert "LBRACE" in ebnf;
    assert "RBRACE" in ebnf;
}

test "while stmt structure" {
    prog = JacProgram();
    mod = prog.compile(PARSER_PATH, no_cgen=True);
    assert not prog.errors_had;
    extracted = GrammarExtractPass(ir_in=mod, prog=prog);
    rule_map = {r.name: r for r in extracted.rules};
    assert "while_stmt" in rule_map;
    ebnf = fmt(rule_map["while_stmt"].body);
    assert "KW_WHILE" in ebnf;
    assert "expression" in ebnf;
}

test "ebnf output nonempty" {
    prog = JacProgram();
    mod = prog.compile(PARSER_PATH, no_cgen=True);
    assert not prog.errors_had;
    extracted = GrammarExtractPass(ir_in=mod, prog=prog);
    ebnf = extracted.emit_ebnf();
    assert len(ebnf) > 100;
    assert "::=" in ebnf;
    for line in ebnf.strip().split("\n") {
        s = line.strip();
        if not s {
            continue;
        }
        assert "::=" in line or line.startswith(" ") , f"Malformed line: {line}";
    }
}

test "lark output nonempty" {
    prog = JacProgram();
    mod = prog.compile(PARSER_PATH, no_cgen=True);
    assert not prog.errors_had;
    extracted = GrammarExtractPass(ir_in=mod, prog=prog);
    lark = extracted.emit_lark();
    assert len(lark) > 100;
    for line in lark.strip().split("\n") {
        s = line.strip();
        if not s {
            continue;
        }
        assert ":" in line or line.startswith(" ") , f"Malformed line: {line}";
    }
}

test "no duplicate rules" {
    prog = JacProgram();
    mod = prog.compile(PARSER_PATH, no_cgen=True);
    assert not prog.errors_had;
    extracted = GrammarExtractPass(ir_in=mod, prog=prog);
    names = [r.name for r in extracted.rules];
    assert len(names) == len(set(names)) , (
        f"Duplicate rules: {[
            n
            for n in names
            if names.count(n) > 1
        ]}"
    );
}

test "rules reference valid names" {
    prog = JacProgram();
    mod = prog.compile(PARSER_PATH, no_cgen=True);
    assert not prog.errors_had;
    extracted = GrammarExtractPass(ir_in=mod, prog=prog);
    rule_names = {r.name for r in extracted.rules};

    def collect_refs(expr: object) -> set[str] {
        refs: set[str] = set();
        if isinstance(expr, GRef) {
            refs.add(expr.name);
        } elif isinstance(expr, GSeq) {
            for item in expr.items {
                refs.update(collect_refs(item));
            }
        } elif isinstance(expr, GAlt) {
            for choice in expr.choices {
                refs.update(collect_refs(choice));
            }
        } elif isinstance(expr, (GOpt, GStar)) {
            refs.update(collect_refs(expr.inner));
        }
        return refs;
    }

    all_refs: set[str] = set();
    for rule in extracted.rules {
        all_refs.update(collect_refs(rule.body));
    }
    resolved = all_refs & rule_names;
    assert len(resolved) > 10 , f"Only {len(resolved)} refs resolved to known rules";
}

# ── Snapshot test: grammar matches jac.spec ──────────────────────────────
test "spec file exists" {
    spec_path = Path(SPEC_PATH);
    assert spec_path.exists() , (
        f"Grammar spec file missing: {SPEC_PATH}\n"
        f"Generate it with: jac grammar -o {SPEC_PATH}"
    );
}

test "grammar matches spec" {
    spec_path = Path(SPEC_PATH);
    if not spec_path.exists() {
        return;
    }
    prog = JacProgram();
    mod = prog.compile(PARSER_PATH, no_cgen=True);
    assert not prog.errors_had;
    extracted = GrammarExtractPass(ir_in=mod, prog=prog);

    spec_rules = parse_spec(spec_path.read_text());
    current_rules = parse_spec(extracted.emit_ebnf());

    # Check for rules in spec that disappeared
    missing = set(spec_rules) - set(current_rules);
    assert not missing , (
        f"Rules in jac.spec but no longer extracted: {missing}\n"
        f"If intentional: jac grammar -o {SPEC_PATH}"
    );

    # Check for new rules not in spec
    added = set(current_rules) - set(spec_rules);
    assert not added , (
        f"New rules not in jac.spec: {added}\n"
        f"If intentional: jac grammar -o {SPEC_PATH}"
    );

    # Check each rule body matches
    changed: list[str] = [];
    for name in sorted(spec_rules) {
        if name not in current_rules {
            continue;
        }
        if spec_rules[name] != current_rules[name] {
            changed.append(
                f"  {name}:\n    spec:    {spec_rules[name]}\n    current: {current_rules[
                    name
                ]}"
            );
        }
    }
    assert not changed , (
        f"{len(changed)} rule(s) changed:\n" + "\n".join(changed) + f"\n\nIf intentional: jac grammar -o {SPEC_PATH}"
    );
}
