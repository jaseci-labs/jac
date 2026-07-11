import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }
import from jaclang.jac0core.parser.tokens { TokenKind }

obj GExpr {
    def __eq__(other: object) -> bool;
    def __repr__ -> str;
}

obj GSeq(GExpr) {
    has items: list;

    def __eq__(other: object) -> bool;
    def __repr__ -> str;
}

obj GAlt(GExpr) {
    has choices: list;

    def __eq__(other: object) -> bool;
    def __repr__ -> str;
}

obj GOpt(GExpr) {
    has inner: GExpr;

    def __eq__(other: object) -> bool;
    def __repr__ -> str;
}

obj GStar(GExpr) {
    has inner: GExpr;

    def __eq__(other: object) -> bool;
    def __repr__ -> str;
}

obj GPlus(GExpr) {
    has inner: GExpr;

    def __eq__(other: object) -> bool;
    def __repr__ -> str;
}

obj GTok(GExpr) {
    has name: str;

    def __eq__(other: object) -> bool;
    def __repr__ -> str;
    def __hash__ -> int;
}

obj GRef(GExpr) {
    has name: str;

    def __eq__(other: object) -> bool;
    def __repr__ -> str;
    def __hash__ -> int;
}

obj GrammarRule {
    has name: str,
        body: GExpr;

    def to_ebnf -> str;
    def __repr__ -> str;
}

obj MethodSemantics {
    has kind: str,
        token_args: bool;
}

glob METHOD_TABLE: dict[str, MethodSemantics] = {
         "expect": MethodSemantics(kind="consume", token_args=True),
         "consume_uni": MethodSemantics(kind="consume", token_args=True),
         "match_tok": MethodSemantics(kind="consume_opt", token_args=True),
         "expect_name": MethodSemantics(kind="consume_name", token_args=False),
         "advance": MethodSemantics(kind="consume_raw", token_args=False),
         "check": MethodSemantics(kind="lookahead", token_args=True),
         "check_any": MethodSemantics(kind="lookahead_any", token_args=True),
         "check_peek": MethodSemantics(kind="lookahead", token_args=True),
         "check_peek_any": MethodSemantics(kind="lookahead_any", token_args=True),
         "check_name": MethodSemantics(kind="lookahead", token_args=False),
         "is_keyword_token": MethodSemantics(kind="lookahead", token_args=False),
         "at_end": MethodSemantics(kind="lookahead", token_args=False),
         "error": MethodSemantics(kind="ignore", token_args=False),
         "make_uni_token": MethodSemantics(kind="ignore", token_args=False),
         "make_name": MethodSemantics(kind="ignore", token_args=False),
         "make_special_name": MethodSemantics(kind="ignore", token_args=False),
         "make_name_or_special": MethodSemantics(kind="ignore", token_args=False),
         "make_string": MethodSemantics(kind="ignore", token_args=False),
         "make_string_from_value": MethodSemantics(kind="ignore", token_args=False),
         "make_int": MethodSemantics(kind="ignore", token_args=False),
         "make_float": MethodSemantics(kind="ignore", token_args=False),
         "make_bool": MethodSemantics(kind="ignore", token_args=False),
         "make_null": MethodSemantics(kind="ignore", token_args=False),
         "make_ellipsis": MethodSemantics(kind="ignore", token_args=False),
         "make_semi": MethodSemantics(kind="ignore", token_args=False),
         "previous": MethodSemantics(kind="ignore", token_args=False),
         "current": MethodSemantics(kind="ignore", token_args=False),
         "peek": MethodSemantics(kind="ignore", token_args=False),
         "get_source": MethodSemantics(kind="ignore", token_args=False),
         "synchronize": MethodSemantics(kind="ignore", token_args=False),
         "prune": MethodSemantics(kind="ignore", token_args=False)
     },
     SPECIAL_LOOKAHEAD_TOKENS: dict[str, list] = {
         "check_name": ["NAME", "KWESC_NAME"],
         "is_keyword_token": ["NAME"]
     };

obj ConditionResult {
    has method: str,
        kind: str,
        tokens: list;
}

obj GrammarExtractPass(UniPass) {
    has rules: list = [],
        target_class: str = "Parser";

    def before_pass -> None;
    def enter_impl_def(nd: uni.ImplDef) -> None;
    def after_pass -> None;
    def format_ebnf(expr: GExpr) -> str;
    def simplify_expr(expr: GExpr) -> GExpr;
    def interpret_stmts(stmts: list) -> GExpr | None;
    def interpret_stmt(stmt: uni.UniNode) -> GExpr | None;
    def interpret_call(call: uni.FuncCall) -> GExpr | None;
    def interpret_if(stmt: uni.IfStmt) -> GExpr | None;
    def interpret_while(stmt: uni.WhileStmt) -> GExpr | None;
    def interpret_condition(cond: uni.Expr) -> ConditionResult | None;
    def collect_dispatch_chain(stmt: uni.IfStmt) -> list;
    def has_early_return(stmts: list) -> bool;
    def is_negated_check(cond: uni.Expr) -> bool;
    def find_break_match_tok(stmts: list) -> tuple | None;
    def find_break_none_check(stmts: list) -> tuple | None;
    def _is_self_pos_access(expr: uni.Expr) -> bool;
    def _extract_savepoint_delegation(stmts: list) -> GExpr | None;
    def _find_post_restore_delegation(stmts: list) -> GExpr | None;
    def compute_first_set(expr: GExpr) -> tuple;
    def all_paths_start_with(expr: GExpr, tok_set: set) -> bool;
    def should_suppress_guard(
        guard_tokens: set, body: GExpr, body_stmt_count: int
    ) -> bool;

    def _stage_simplify(rules: list) -> list;
    def _stage_unwrap_top_opt(rules: list) -> list;
    def _stage_dedup_tokens(rules: list) -> list;
    def _stage_remove_errors(rules: list) -> list;
    def _is_redundant_slot_wrap_recovery(expr: GExpr) -> bool;
    def _stage_remove_unreachable(rules: list) -> list;
    def _dedup_parent_child_tokens(expr: GExpr, rule_map: dict) -> GExpr;
    def _collect_refs(body: GExpr) -> set;
    def expr_contains_tok(expr: GExpr, tok_name: str) -> bool;
    def _resolve_tokens(method: str, call: uni.FuncCall | None) -> list;
    def _merge_or_conditions(exprs: list) -> ConditionResult | None;
    def extract_token_kind(expr: uni.Expr) -> str | None;
    def get_self_method(nd: uni.Expr) -> str | None;
    def get_token_args(call: uni.FuncCall) -> list;
    def get_call_from_expr(expr: uni.Expr) -> uni.FuncCall | None;
    def get_impl_target_names(nd: uni.ImplDef) -> list;
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
}
