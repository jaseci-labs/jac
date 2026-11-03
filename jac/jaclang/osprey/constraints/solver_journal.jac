def _journal_expression_is_finite(s: Solver, e: Expression) -> bool;

def _journal_kind_of(s: Solver, symbol: int) -> SymbolKind;

def _journal_begin(s: Solver) -> MutationJournal;

def _journal_witness_for_key(s: Solver, key: str) -> list[str];

def _journal_witness_extra(s: Solver, extra: str) -> list[str];

def _journal_new_symbol(s: Solver, kind: SymbolKind) -> int;

def _journal_new_symbol_journaled(
    s: Solver, kind: SymbolKind, jnl: MutationJournal
) -> int;

def _journal_get_var_symbol(
    s: Solver, v: Variable, jnl: MutationJournal | None = None
) -> int;

def _journal_insert_row(s: Solver, symbol: int, row: Row, jnl: MutationJournal);

def _journal_touch_row(s: Solver, symbol: int, jnl: MutationJournal);

def _journal_touch_objective(s: Solver, jnl: MutationJournal);

def _journal_pop_row(s: Solver, symbol: int, jnl: MutationJournal) -> Row;

def _journal_rollback(s: Solver, jnl: MutationJournal);
