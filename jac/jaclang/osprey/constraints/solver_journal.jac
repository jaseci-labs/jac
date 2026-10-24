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

impl _journal_expression_is_finite(s: Solver, e: Expression) -> bool {
    if not is_finite(e.constant) {
        return False;
    }
    for t in e.terms {
        if not is_finite(t.coefficient) {
            return False;
        }
    }
    return True;
}

impl _journal_kind_of(s: Solver, symbol: int) -> SymbolKind {
    if symbol <= 0 {
        return SymbolKind.INVALID;
    }
    return s.kinds.get(symbol, SymbolKind.INVALID);
}

impl _journal_begin(s: Solver) -> MutationJournal {
    return MutationJournal(
        id_tick_start=s.id_tick, infeasible_start=len(s.infeasible_rows),
    );
}

impl _journal_witness_for_key(s: Solver, key: str) -> list[str] {
    out: list[str] = [];
    for hid in sorted(s.handle_keys.keys()) {
        if s.handle_keys[hid] == key and s.provenance.get(hid, "") != "" {
            out.append(s.provenance[hid]);
        }
    }
    return out;
}

impl _journal_witness_extra(s: Solver, extra: str) -> list[str] {
    if extra == "" {
        return [];
    }
    return [extra];
}

impl _journal_new_symbol(s: Solver, kind: SymbolKind) -> int {
    symbol = s.id_tick;
    s.id_tick += 1;
    s.kinds[symbol] = kind;
    return symbol;
}

impl _journal_new_symbol_journaled(
    s: Solver, kind: SymbolKind, jnl: MutationJournal
) -> int {
    symbol = _journal_new_symbol(s, kind);
    jnl.allocated_symbols.append(symbol);
    return symbol;
}

impl _journal_get_var_symbol(
    s: Solver, v: Variable, jnl: MutationJournal | None = None
) -> int {
    var_symbols: dict[int, int] = s.var_symbols;
    if v.id in var_symbols {
        return var_symbols[v.id];
    }
    symbol = _journal_new_symbol(s, SymbolKind.EXTERNAL);
    s.var_symbols[v.id] = symbol;
    if jnl is not None {
        jnl.new_var_ids.append(v.id);
        jnl.allocated_symbols.append(symbol);
    }
    return symbol;
}

impl _journal_insert_row(s: Solver, symbol: int, row: Row, jnl: MutationJournal) {
    if (symbol not in jnl.inserted_rows and symbol not in jnl.row_snapshots) {
        jnl.inserted_rows.append(symbol);
    }
    s.rows[symbol] = row;
}

impl _journal_touch_row(s: Solver, symbol: int, jnl: MutationJournal) {
    rows: dict[int, Row] = s.rows;
    if (
        symbol in rows
        and symbol not in jnl.row_snapshots
        and symbol not in jnl.inserted_rows
    ) {
        jnl.row_snapshots[symbol] = rows[symbol].clone();
    }
}

impl _journal_touch_objective(s: Solver, jnl: MutationJournal) {
    if jnl.objective_snapshot is None {
        jnl.objective_snapshot = s.objective.clone();
    }
}

impl _journal_pop_row(s: Solver, symbol: int, jnl: MutationJournal) -> Row {
    _journal_touch_row(s, symbol, jnl);
    return s.rows.pop(symbol);
}

impl _journal_rollback(s: Solver, jnl: MutationJournal) {
    rows: dict[int, Row] = s.rows;

    for symbol in reversed(jnl.inserted_rows) {
        if symbol in rows {
            rows.pop(symbol);
        }
    }

    for symbol in sorted(jnl.row_snapshots.keys()) {
        rows[symbol] = jnl.row_snapshots[symbol].clone();
    }

    if jnl.objective_snapshot is not None {
        s.objective = jnl.objective_snapshot.clone();
    }

    for vid in reversed(jnl.new_var_ids) {
        s.var_symbols.pop(vid);
    }

    for symbol in reversed(jnl.allocated_symbols) {
        s.kinds.pop(symbol);
    }
    s.id_tick = jnl.id_tick_start;

    del s.infeasible_rows[jnl.infeasible_start:];
}
