"""Grammar extraction pass tests – migrated from test_grammar_extract_pass.py.

Tests for grammar model types (GTok, GRef, GSeq, GAlt, GOpt, GStar),
EBNF/Lark formatting, simplification, and integration with the real
Jac parser module. Also validates grammar matches jac.spec.
"""

import from pathlib { Path }
import os;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.compiler.tools.grammar_extract_pass {
    GAlt,
    GOpt,
    GPlus,
    GrammarExtractPass,
    GrammarRule,
    GRef,
    GSeq,
    GStar,
    GTok,
    MethodSemantics,
    ConditionResult,
    METHOD_TABLE,
    SPECIAL_LOOKAHEAD_TOKENS
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.pass_driver { run_pass }

glob PARSER_PATH = str(
         Path(jaclang.__file__).parent
             / "compiler"
             / "frontend"
             / "parser"
             / "parser.jac"
     ),
     SPEC_PATH = os.path.join(JAC_ROOT, "jaclang", "jac.spec");

"""Helper: format a GExpr as EBNF."""
def fmt(expr: any) -> str {
    return GrammarExtractPass.format_ebnf(expr);
}

"""Helper: simplify a GExpr."""
def simplify(expr: any) -> any {
    return GrammarExtractPass.simplify_expr(expr);
}

"""Parse EBNF text into {rule_name: rule_body} dict."""
def parse_spec(text: str) -> dict[str, str] {
    rules: dict[str, str] = {};
    current_name: str | None = None;
    current_body: str = "";
    for line in text.strip().splitlines() {
        line = line.rstrip();
        lead = line.lstrip();
        if not lead or lead.startswith("#") or lead.startswith("//") {
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
# (case, expression, its EBNF)
glob EBNF_CASES: list[tuple[str, any, str]] = [
         ("gtok ebnf", GTok(name="KW_IF"), '"if"'),
         ("gref ebnf", GRef(name="expression"), "expression"),
         (
             "gseq ebnf",
             GSeq(items=[GTok(name="KW_IF"), GRef(name="expression")]),
             '"if" expression'
         ),
         (
             "galt ebnf",
             GAlt(choices=[GRef(name="elif_stmt"), GRef(name="else_stmt")]),
             "elif_stmt | else_stmt"
         ),
         ("gopt ebnf", GOpt(inner=GRef(name="else_stmt")), "else_stmt?"),
         (
             "gopt alt ebnf",
             GOpt(inner=GAlt(choices=[GRef(name="elif_stmt"), GRef(name="else_stmt")])),
             "(elif_stmt | else_stmt)?"
         ),
         (
             "gstar ebnf",
             GStar(inner=GSeq(items=[GTok(name="BW_OR"), GRef(name="bitwise_xor")])),
             '("|" bitwise_xor)*'
         ),
         (
             "alt inside seq gets parens",
             GSeq(
                 items=[GTok(name="A"), GAlt(choices=[GTok(name="B"), GTok(name="C")])]
             ),
             "A (B | C)"
         )
     ],
     SIMPLIFY_CASES: list[tuple[str, any, str]] = [
         (
             "simplify nested seq",
             GSeq(items=[GTok(name="A"), GSeq(items=[GTok(name="B"), GTok(name="C")])]),
             "A B C"
         ),
         ("simplify single item seq", GSeq(items=[GTok(name="A")]), "A"),
         (
             "simplify nested alt",
             GAlt(
                 choices=[
                     GTok(name="A"),
                     GAlt(choices=[GTok(name="B"), GTok(name="C")])
                 ]
             ),
             "A | B | C"
         ),
         (
             "alt collapses bare choice into optional twin",
             GAlt(choices=[GTok(name="SEMI"), GOpt(inner=GTok(name="SEMI"))]),
             '";"?'
         ),
         (
             "alt collapses bare choice into star twin",
             GAlt(choices=[GStar(inner=GTok(name="COMMA")), GTok(name="COMMA")]),
             '","*'
         ),
         (
             "opt hoist skips outer opt when a star choice exists",
             GAlt(
                 choices=[
                     GStar(inner=GTok(name="COMMA")),
                     GOpt(inner=GTok(name="SEMI"))
                 ]
             ),
             '","* | ";"'
         )
     ];

# (case, expression, its EBNF after simplify)
test "each grammar expression formats to its EBNF" {
    failed = [
        f"{label}: got {fmt(expr)!r}, expected {want!r}"
        for (label, expr, want) in EBNF_CASES
        if fmt(expr) != want
    ]
        + [
            f"{label}: got {fmt(simplify(expr))!r}, expected {want!r}"
            for (label, expr, want) in SIMPLIFY_CASES
            if fmt(simplify(expr)) != want
        ];
    assert not failed , "\n".join(failed);
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
    assert ebnf == 'bitwise_or ::= bitwise_xor ("|" bitwise_xor)*';
}

test "equality" {
    assert GTok(name="X") == GTok(name="X");
    assert GRef(name="foo") == GRef(name="foo");
    assert GTok(name="X") != GTok(name="Y");
    assert GTok(name="X") != GRef(name="X");
}

# ── Mini-parser fixture: behaviors of interpretation itself ──────────────
glob MINI_PARSER_SRC = """
import from jaclang.compiler.frontend.parser.tokens { TokenKind }

obj Parser {
    def check(kind: TokenKind) -> bool { return True; }
    def match_tok(kind: TokenKind) -> bool { return True; }
    def expect(kind: TokenKind) -> int { return 0; }
    def consume_uni(kind: TokenKind, value: str | None = None) -> int { return 0; }
    def advance -> int { return 0; }
    def flagged -> bool { return True; }
    def parse_module;
    def parse_loopy;
    def parse_optish;
    def parse_choice;
    def parse_outer;
    def parse_inner_if;
    def parse_fallback;
    def parse_rec;
    def parse_leaf;
    def parse_marker;
    def parse_marker2 -> int | None;
    def parse_maybe;
    def parse_listy;
    def parse_either;
    def parse_covered;
    def parse_wrapped;
    def parse_trying;
    def parse_contextual;
}

impl Parser.parse_module {
    self.parse_loopy();
    self.parse_optish();
    self.parse_choice();
    self.parse_outer();
    self.parse_rec();
    self.parse_marker();
    self.parse_maybe();
    self.parse_listy();
    self.parse_either();
    self.parse_covered();
    self.parse_trying();
    self.parse_contextual();
}

impl Parser.parse_loopy {
    while self.match_tok(TokenKind.DOT) or self.match_tok(TokenKind.DOT_FWD) {
        self.expect(TokenKind.NAME);
    }
}

impl Parser.parse_optish {
    if self.match_tok(TokenKind.DOT) or self.match_tok(TokenKind.DOT_BKWD) {
        self.expect(TokenKind.NAME);
    }
}

impl Parser.parse_choice {
    if self.flagged() {
        self.expect(TokenKind.SEMI);
    } else {
        self.expect(TokenKind.COMMA);
    }
}

impl Parser.parse_outer {
    if self.check(TokenKind.KW_IF) {
        x = self.parse_inner_if();
        return x;
    }
    return self.parse_fallback();
}

impl Parser.parse_inner_if {
    self.expect(TokenKind.KW_IF);
    self.expect(TokenKind.NAME);
}

impl Parser.parse_fallback {
    self.expect(TokenKind.NAME);
}

impl Parser.parse_rec {
    if self.check(TokenKind.MINUS) {
        op = self.advance();
        val = self.parse_rec();
        return val;
    }
    return self.parse_leaf();
}

impl Parser.parse_leaf {
    self.expect(TokenKind.NAME);
}

impl Parser.parse_marker {
    if self.check(TokenKind.KW_OWN) {
        self.expect(TokenKind.KW_OWN);
        return;
    }
    if self.check(TokenKind.KW_IMM) {
        self.expect(TokenKind.KW_IMM);
        return;
    }
}

impl Parser.parse_marker2 -> int | None {
    if self.check(TokenKind.KW_OWN) {
        self.expect(TokenKind.KW_OWN);
        return 1;
    }
    if self.check(TokenKind.KW_IMM) {
        self.expect(TokenKind.KW_IMM);
        return 2;
    }
    return None;
}

impl Parser.parse_maybe {
    val = self.parse_leaf() if self.check(TokenKind.NAME) else None;
    self.expect(TokenKind.SEMI);
}

impl Parser.parse_listy {
    while not self.check(TokenKind.RPAREN) {
        self.parse_leaf();
        if not self.match_tok(TokenKind.COMMA) {
            break;
        }
        self.check(TokenKind.SEMI);
    }
}

impl Parser.parse_either {
    if self.check(TokenKind.KW_IF) {
        self.expect(TokenKind.KW_IF);
        return 1;
    } else {
        self.expect(TokenKind.NAME);
        return 2;
    }
}

impl Parser.parse_covered {
    if self.check(TokenKind.KW_IF) {
        x = self.parse_wrapped();
        self.expect(TokenKind.SEMI);
        return x;
    }
    return self.parse_leaf();
}

impl Parser.parse_wrapped {
    y = self.parse_inner_if();
    self.expect(TokenKind.COMMA);
}

impl Parser.parse_trying {
    m = self.parse_marker2();
    if m is not None {
        return m;
    }
    return self.parse_leaf();
}

impl Parser.parse_contextual {
    try {
        kid = [self.consume_uni(TokenKind.NAME, "graph"), self.expect(TokenKind.LBRACE)];
    } finally {
        self.expect(TokenKind.SEMI);
    }
}
""";

"""Compile the mini parser fixture and run extraction on it."""
glob _MINI_PASS: dict[str, GrammarExtractPass] = {};

"""Every caller only reads the mini parser's extraction, so it is compiled once
per file."""
def mini_pass -> GrammarExtractPass {
    import tempfile;
    if "pass" not in _MINI_PASS {
        with tempfile.TemporaryDirectory() as td {
            path = os.path.join(td, "mini_parser.jac");
            with open(path, "w", encoding="utf-8") as f {
                f.write(MINI_PARSER_SRC);
            }
            prog = JacProgram();
            mod = prog.compile(path, no_cgen=True);
            _MINI_PASS["pass"] = run_pass(GrammarExtractPass, mod, prog);
        }
    }
    return _MINI_PASS["pass"];
}

def mini_rules -> dict[str, any] {
    return {r.name: r for r in mini_pass().rules};
}

# (case, mini parser rule, its extracted EBNF)
glob MINI_RULE_CASES: list[tuple[str, str, str]] = [
         (
             "contextual tokens and finally blocks retain their grammar",
             "contextual",
             '"graph" "{" ";"'
         ),
         (
             "or merged match_tok loop emits full token set",
             "loopy",
             '(("." | ".>") NAME)*'
         ),
         (
             "or merged match_tok opt emits full token set",
             "optish",
             '(("." | "<.") NAME)?'
         ),
         ("opaque if else becomes alternation", "choice", '";" | ","'),
         (
             "guard suppressed when child rule consumes it",
             "outer",
             "inner_if | fallback"
         ),
         ("self recursive guard is kept", "rec", '"-" rec | leaf'),
         (
             "genuinely nullable dispatch keeps its optionality",
             "marker",
             '("own" | "imm")?'
         ),
         (
             "none returning dispatcher loses redundant optionality",
             "marker2",
             '"own" | "imm"'
         ),
         ("ternary with none branch is optional", "maybe", 'leaf? ";"'),
         ("mid loop separator break emits optional separator", "listy", '(leaf ","?)*'),
         ("exhaustive if else chain is not optional", "either", '"if" | NAME'),
         ("guard covered by deep first set is elided", "covered", 'wrapped ";" | leaf'),
         ("try parse idiom becomes ordered choice", "trying", "marker2 | leaf")
     ];

test "each mini parser rule extracts to its expected grammar" {
    rules = mini_rules();
    failed = [
        f"{label}: {rule} gave {fmt(rules[rule].body)!r}, expected {want!r}"
        for (label, rule, want) in MINI_RULE_CASES
        if fmt(rules[rule].body) != want
    ];
    assert not failed , "\n".join(failed);
}

test "strict diagnostics flag invisible constructs" {
    p = mini_pass();
    kinds = {d["kind"] for d in p.diagnostics};
    assert "bare-advance" in kinds;
    assert "unknown-method" in kinds;
    diag_text = p.emit_diagnostics();
    assert "finding" in diag_text;
    assert "flagged" in diag_text;
}

# ── Integration: extract rules from the real parser ──────────────────────
glob _REAL_PASS: dict[str, GrammarExtractPass] = {};

"""The real parser takes minutes to compile, and every test below only reads
the extraction, so it is compiled once per file."""
def real_parser_pass -> GrammarExtractPass {
    if "pass" not in _REAL_PASS {
        prog = JacProgram();
        mod = prog.compile(PARSER_PATH, no_cgen=True);
        assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";
        _REAL_PASS["pass"] = run_pass(GrammarExtractPass, mod, prog);
    }
    return _REAL_PASS["pass"];
}

test "rules extracted" {
    extracted = real_parser_pass();
    assert len(extracted.rules) > 20 , (
        f"Expected >20 rules, got {len(extracted.rules)}"
    );
}

test "known rule names" {
    extracted = real_parser_pass();
    rule_names = {r.name for r in extracted.rules};
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
        "factor"
    };
    missing = expected - rule_names;
    assert len(missing) == 0 , f"Missing rules: {missing}";
}

# (case, real parser rule, text its EBNF must contain, text it must not contain)
glob STRUCTURE_CASES: list[tuple[str, str, list[str], list[str]]] = [
         ("bitwise or structure", "bitwise_or", ["bitwise_xor", '"|"'], []),
         ("if stmt structure", "if_stmt", ['"if"', "expression", '"{"', '"}"'], []),
         ("while stmt structure", "while_stmt", ['"while"', "expression"], []),
         # forever has no condition and no else clause
         (
             "forever stmt structure",
             "forever_stmt",
             ['"forever"', "code_block_stmts"],
             ["expression", "else_stmt"]
         )
     ];

test "each real parser rule has its expected structure" {
    rule_map = {r.name: r for r in real_parser_pass().rules};
    failed: list[str] = [];
    for (label, rule, present, absent) in STRUCTURE_CASES {
        if rule not in rule_map {
            failed.append(f"{label}: no {rule} rule");
            continue;
        }
        ebnf = fmt(rule_map[rule].body);
        missing = [
            s
            for s in present
            if s not in ebnf
        ];
        leaked = [
            s
            for s in absent
            if s in ebnf
        ];
        if missing or leaked {
            failed.append(f"{label}: missing {missing}, unexpected {leaked} in {ebnf}");
        }
    }
    assert not failed , "\n".join(failed);
}


test "ebnf output nonempty" {
    extracted = real_parser_pass();
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

test "no duplicate rules" {
    extracted = real_parser_pass();
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
    extracted = real_parser_pass();
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
        } elif isinstance(expr, (GOpt, GStar, GPlus)) {
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

# ── Ratchet: strict findings may only go down ────────────────────────────
glob STRICT_FINDING_BUDGET = 37;

test "strict finding budget" {
    extracted = real_parser_pass();
    count = len(extracted.diagnostics);
    assert count <= STRICT_FINDING_BUDGET , (
        f"grammar strict findings grew to {count} (budget {STRICT_FINDING_BUDGET}).\n"
        "New parser code consumes tokens invisibly to the grammar extractor.\n"
        "Use expect()/expect_any()/match_tok()/match_any() instead of bare "
        "advance(), keep TokenKind arguments literal, and put error recovery in "
        "_-prefixed helpers. Run `jac tool grammar --strict` to see findings.\n"
        "If you fixed findings, lower STRICT_FINDING_BUDGET to the new count."
    );
}

# ── Snapshot test: grammar matches jac.spec ──────────────────────────────
test "spec file exists" {
    spec_path = Path(SPEC_PATH);
    assert spec_path.exists() , (
        f"Grammar spec file missing: {SPEC_PATH}\n"
        f"Generate it with: jac tool grammar -o {SPEC_PATH}"
    );
}

test "grammar matches spec" {
    spec_path = Path(SPEC_PATH);
    if not spec_path.exists() {
        return;
    }
    extracted = real_parser_pass();

    spec_rules = parse_spec(spec_path.read_text());
    current_rules = parse_spec(extracted.emit_ebnf());

    # Check for rules in spec that disappeared
    missing = set(spec_rules) - set(current_rules);
    assert not missing , (
        f"Rules in jac.spec but no longer extracted: {missing}\n"
        f"If intentional: jac tool grammar -o {SPEC_PATH}"
    );

    # Check for new rules not in spec
    added = set(current_rules) - set(spec_rules);
    assert not added , (
        f"New rules not in jac.spec: {added}\n"
        f"If intentional: jac tool grammar -o {SPEC_PATH}"
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
        f"{len(changed)} rule(s) changed:\n"
        + "\n".join(changed)
        + f"\n\nIf intentional: jac tool grammar -o {SPEC_PATH}"
    );
}
