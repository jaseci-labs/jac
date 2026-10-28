def _solver_add_core(
    s: Solver, c: Constraint, tag: Tag, jnl: MutationJournal
) -> SolveResult;

def _solver_rebuild_admitting(
    s: Solver, candidate: Constraint, factory: Callable[[], Solver]
) -> Solver | None;

def _solver_terms_reversed(s: Solver, st: StoredConstraint) -> StoredConstraint;

def _solver_replay_all(
    s: Solver, order: list[StoredConstraint], factory: Callable[[], Solver]
) -> Solver | None;

def _solver_pivot(
    s: Solver,
    entering: int,
    leaving: int,
    jnl: MutationJournal,
    extra: Row | None = None,
    reinsert: bool = True,
);

def _solver_adopt(s: Solver, bundle: Solver);

def _solver_create_row(
    s: Solver, c: Constraint, tag: Tag, jnl: MutationJournal
) -> Row;

def _solver_choose_subject(s: Solver, row: Row, tag: Tag) -> int;

def _solver_all_dummies(s: Solver, row: Row) -> bool;

def _solver_any_pivotable_symbol(s: Solver, row: Row) -> int;

def _solver_add_with_artificial_variable(
    s: Solver, row: Row, jnl: MutationJournal
) -> bool;

def _solver_substitute(
    s: Solver, symbol: int, row: Row, jnl: MutationJournal, extra: Row | None = None,
);

def _solver_add_objective(
    s: Solver, symbol: int, weight: LexWeight, jnl: MutationJournal,
) -> None;

def _solver_optimize_cost(s: Solver, jnl: MutationJournal) -> SolveResult;

def _solver_optimize_toward(
    s: Solver, target: Row, jnl: MutationJournal, extra: Row | None = None,
) -> SolveResult;

def _solver_get_entering_symbol(s: Solver, objective: Row) -> int;

def _solver_get_entering_cost_symbol(s: Solver) -> int;

def _solver_get_leaving_row(s: Solver, entering: int) -> int;
