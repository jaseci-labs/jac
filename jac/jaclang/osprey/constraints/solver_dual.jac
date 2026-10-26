def _solver_remove_core(
    s: Solver, tag: Tag, strength: StrengthTier, jnl: MutationJournal
) -> SolveResult;

def _solver_remove_constraint_effects(
    s: Solver, tag: Tag, strength: StrengthTier, jnl: MutationJournal,
) -> None;

def _solver_remove_marker_effects(
    s: Solver, marker: int, weight: LexWeight, jnl: MutationJournal,
);

def _solver_get_marker_leaving_row(s: Solver, marker: int) -> int;

def _solver_dual_optimize(s: Solver, jnl: MutationJournal) -> SolveResult;

def _solver_get_dual_entering_symbol(s: Solver, row: Row) -> int;

def _solver_objective_weight(s: Solver, symbol: int) -> LexWeight;

def _solver_dual_ratio_less(
    s: Solver, w1: LexWeight, c1: float, w2: LexWeight, c2: float,
) -> bool;

def _solver_apply_suggestion(
    s: Solver, info: EditInfo, delta: float, jnl: MutationJournal,
) -> None;
