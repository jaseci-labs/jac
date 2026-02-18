"""Grammar extraction pass for Jac parser.

Analyzes parser implementation AST to automatically extract grammar rules
in EBNF/Lark format. Walks compiled ImplDef nodes, recognizes token
consumption and control-flow patterns, and produces grammar rules.
"""

import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }
import from jaclang.jac0core.parser.tokens { TokenKind }

# ---------------------------------------------------------------------------
# Grammar Expression Types
# ---------------------------------------------------------------------------
"""Base class for grammar expressions."""
obj GExpr {
    def __eq__(other: object) -> bool;
    def __repr__ -> str;
}

"""Sequence: A B C."""
obj GSeq(GExpr) {
    has items: list;

    def __eq__(other: object) -> bool;
    def __repr__ -> str;
}

"""Alternatives: A | B | C."""
obj GAlt(GExpr) {
    has choices: list;

    def __eq__(other: object) -> bool;
    def __repr__ -> str;
}

"""Optional: (A)?."""
obj GOpt(GExpr) {
    has inner: GExpr;

    def __eq__(other: object) -> bool;
    def __repr__ -> str;
}

"""Zero-or-more: (A)*."""
obj GStar(GExpr) {
    has inner: GExpr;

    def __eq__(other: object) -> bool;
    def __repr__ -> str;
}

"""Terminal token reference."""
obj GTok(GExpr) {
    has name: str;

    def __eq__(other: object) -> bool;
    def __repr__ -> str;
    def __hash__ -> int;
}

"""Non-terminal rule reference."""
obj GRef(GExpr) {
    has name: str;

    def __eq__(other: object) -> bool;
    def __repr__ -> str;
    def __hash__ -> int;
}

"""A grammar production rule."""
obj GrammarRule {
    has name: str,
        body: GExpr;

    def to_ebnf -> str;
    def to_lark -> str;
    def __repr__ -> str;
}

# ---------------------------------------------------------------------------
# Grammar Extraction Pass
# ---------------------------------------------------------------------------
"""Extracts grammar rules from parser implementation AST.

Finds all ``impl <target>.parse_*`` methods and extracts grammar rules
by analysing token-consumption patterns (expect / match_tok / check)
and control-flow (if / while).
"""
obj GrammarExtractPass(UniPass) {
    has rules: list = [],
        target_class: str = "Parser";

    def init(ir_in: uni.Module, prog: Any, cancel_token: Any = None) -> None;
    # UniPass hooks
    def before_pass -> None;
    def enter_impl_def(nd: uni.ImplDef) -> None;
    def after_pass -> None;
    # Formatting (static-like helpers, called with self)
    def format_ebnf(expr: GExpr) -> str;
    def format_lark(expr: GExpr) -> str;
    def simplify_expr(expr: GExpr) -> GExpr;
    # Body extraction
    def extract_from_stmts(stmts: list) -> GExpr | None;
    def extract_from_stmt(stmt: uni.UniNode) -> GExpr | None;
    def analyze_func_call(call: uni.FuncCall) -> GExpr | None;
    def analyze_if_stmt(stmt: uni.IfStmt) -> GExpr | None;
    def analyze_while_stmt(stmt: uni.WhileStmt) -> GExpr | None;
    def find_break_match_tok(stmts: list) -> tuple | None;
    def find_break_none_check(stmts: list) -> tuple | None;
    def analyze_condition(cond: uni.Expr) -> tuple | None;
    def collect_elif_chain(stmt: uni.IfStmt) -> list;
    def has_early_return(stmts: list) -> bool;
    def is_negated_check_condition(cond: uni.Expr) -> bool;
    def expr_contains_tok(expr: GExpr, tok_name: str) -> bool;
    # AST helpers
    def extract_token_kind(expr: uni.Expr) -> str | None;
    def get_self_method(nd: uni.Expr) -> str | None;
    def get_token_args(call: uni.FuncCall) -> list;
    def get_call_from_expr(expr: uni.Expr) -> uni.FuncCall | None;
    def get_impl_target_names(nd: uni.ImplDef) -> list;
    # Output
    def format_rule_pretty(
        rule: GrammarRule, sep: str = "::=", max_line: int = 88
    ) -> str;

    def format_expr_pretty(expr: GExpr, indent: int, max_line: int) -> str;
    def format_alt_pretty(choices: list, indent: int, max_line: int) -> str;
    def format_seq_pretty(items: list, indent: int, max_line: int) -> str;
    def format_group_pretty(
        inner: GExpr, indent: int, max_line: int, suffix: str
    ) -> str;

    def emit_ebnf -> str;
    def emit_lark -> str;
}
