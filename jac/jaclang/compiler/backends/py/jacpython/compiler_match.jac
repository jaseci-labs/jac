obj match_pat_ctx {
    has stores: list[str],
        on_top: int,
        cleanup_blocks: list[basicblock],
        max_cleanup: int,
        allow_irrefutable: bool;
}

def match_subject_use_load_fast(g: cfg_builder, m: Match) -> bool;

def match_emit_subject(g: cfg_builder, m: Match);

obj match_case_start {
    has ctx: match_pat_ctx,
        next_arm: basicblock;
}

def match_begin_case(g: cfg_builder) -> match_case_start;

def match_ensure_cleanup_blocks(g: cfg_builder, ctx: match_pat_ctx, n: int);

def match_jump_to_fail(
    g: cfg_builder, ctx: match_pat_ctx, next_arm: basicblock, jump_op: int, loc: cloc
);

def match_emit_reset_fail_pop(
    g: cfg_builder, ctx: match_pat_ctx, next_arm: basicblock, loc: cloc
);

def match_pattern_rotate(g: cfg_builder, loc: cloc, count: int);

def match_pattern_helper_store_name(
    g: cfg_builder, name: str | None, ctx: match_pat_ctx, loc: cloc
) -> bool;

def match_emit_case_stores(g: cfg_builder, ctx: match_pat_ctx, loc: cloc);

def emit_match_pattern_sub(
    g: cfg_builder, p: pattern, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool;

def emit_match_pattern_value(
    g: cfg_builder, mv: MatchValue, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool;

def emit_match_pattern_singleton(
    g: cfg_builder,
    ms: MatchSingleton,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    ploc: cloc
) -> bool;

def emit_match_pattern_as(
    g: cfg_builder, ma: MatchAs, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool;

def emit_match_sequence_subscr(
    g: cfg_builder,
    patterns: list[pattern],
    star_idx: int,
    next_arm: basicblock,
    ctx: match_pat_ctx,
    ploc: cloc
) -> bool;

def emit_match_pattern_sequence(
    g: cfg_builder,
    ms: MatchSequence,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    ploc: cloc
) -> bool;

def emit_match_pattern_class(
    g: cfg_builder, mc: MatchClass, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool;

def emit_match_pattern_mapping(
    g: cfg_builder,
    mm: MatchMapping,
    ctx: match_pat_ctx,
    next_arm: basicblock,
    ploc: cloc
) -> bool;

def emit_match_pattern_or(
    g: cfg_builder, mo: MatchOr, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool;

def emit_match_pattern(
    g: cfg_builder, p: pattern, ctx: match_pat_ctx, next_arm: basicblock, ploc: cloc
) -> bool;

def match_is_irrefutable(pat: pattern) -> bool;

def visit_match(
    g: cfg_builder,
    m: Match,
    more_code_follows: bool,
    tail: list[stmt] | None = None,
    tail_idx: int = 0,
    tail_join: basicblock | None = None,
    ann_ctx: ann_scope_plan | None = None
) -> stmt_cont;
