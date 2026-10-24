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

impl _solver_remove_core(
    s: Solver, tag: Tag, strength: StrengthTier, jnl: MutationJournal
) -> SolveResult {
    _solver_remove_constraint_effects(s, tag, strength, jnl);
    marker = tag.marker;
    if marker in (s.rows as dict[int, Row]) {
        _journal_pop_row(s, marker, jnl);
    } else {
        leaving = _solver_get_marker_leaving_row(s, marker);
        if leaving == 0 {
            return SolveResult(
                ok=False,
                error=SolveError.INTERNAL_INVARIANT,
                message="failed to find leaving row",
            );
        }
        _solver_pivot(s, marker, leaving, jnl, reinsert=False);
    }

    return _solver_optimize_cost(s, jnl);
}

impl _solver_remove_constraint_effects(
    s: Solver, tag: Tag, strength: StrengthTier, jnl: MutationJournal,
) -> None {
    weight = strength_weight(strength);
    if lex_is_zero(weight) {
        return;
    }
    if _journal_kind_of(s, tag.marker) == SymbolKind.ERROR {
        _solver_remove_marker_effects(s, tag.marker, weight, jnl);
    }
    if _journal_kind_of(s, tag.other) == SymbolKind.ERROR {
        _solver_remove_marker_effects(s, tag.other, weight, jnl);
    }
}

impl _solver_remove_marker_effects(
    s: Solver, marker: int, weight: LexWeight, jnl: MutationJournal,
) {
    _journal_touch_objective(s, jnl);
    row = s.rows.get(marker);
    if row is not None {
        s.objective.insert_row(row, lex_neg(weight));
    } else {
        s.objective.insert_symbol(marker, lex_neg(weight));
    }
}

impl _solver_get_marker_leaving_row(s: Solver, marker: int) -> int {
    ratio1 = 1e308;
    ratio2 = 1e308;
    first = 0;
    second = 0;
    third = 0;
    for symbol in sorted(s.rows.keys()) {
        coeff = s.rows[symbol].coefficient_for(marker);
        if near_zero(coeff) {
            continue;
        }
        if _journal_kind_of(s, symbol) == SymbolKind.EXTERNAL {
            third = symbol;
        } elif coeff < 0.0 {
            r = -s.rows[symbol].constant / coeff;
            if r < ratio1 {
                ratio1 = r;
                first = symbol;
            }
        } else {
            r = s.rows[symbol].constant / coeff;
            if r < ratio2 {
                ratio2 = r;
                second = symbol;
            }
        }
    }
    if first != 0 {
        return first;
    }
    if second != 0 {
        return second;
    }
    return third;
}

impl _solver_dual_optimize(s: Solver, jnl: MutationJournal) -> SolveResult {
    while len(s.infeasible_rows) > 0 {
        leaving = s.infeasible_rows.pop();
        row = s.rows.get(leaving);
        if (row is None or near_zero(row.constant) or row.constant >= 0.0) {
            continue;
        }
        entering = _solver_get_dual_entering_symbol(s, row);
        if entering == 0 {
            return SolveResult(
                ok=False,
                error=SolveError.INTERNAL_INVARIANT,
                message="dual optimize failed",
            );
        }
        _solver_pivot(s, entering, leaving, jnl);
    }
    return SolveResult(ok=True);
}

impl _solver_get_dual_entering_symbol(s: Solver, row: Row) -> int {
    entering = 0;
    best_coeff = 0.0;
    for symbol in sorted(row.cells.keys()) {
        cell = row.cells[symbol];
        if cell <= 0.0 or _journal_kind_of(s, symbol) == SymbolKind.DUMMY {
            continue;
        }
        if entering == 0
            or _solver_dual_ratio_less(
                s,
                _solver_objective_weight(s, symbol),
                cell,
                _solver_objective_weight(s, entering),
                best_coeff,
            ) {
            entering = symbol;
            best_coeff = cell;
        }
    }
    return entering;
}

impl _solver_objective_weight(s: Solver, symbol: int) -> LexWeight {
    return s.objective.cells.get(symbol, lex_zero());
}

impl _solver_dual_ratio_less(
    s: Solver, w1: LexWeight, c1: float, w2: LexWeight, c2: float,
) -> bool {
    return lex_compare(lex_scale(w1, c2), lex_scale(w2, c1)) < 0;
}

impl _solver_apply_suggestion(
    s: Solver, info: EditInfo, delta: float, jnl: MutationJournal,
) -> None {
    marker = s.cns[info.key].marker;
    other = s.cns[info.key].other;
    row = s.rows.get(marker);
    if row is not None {
        _journal_touch_row(s, marker, jnl);
        if row.add(-delta) < 0.0 {
            s.infeasible_rows.append(marker);
        }
        return;
    }
    row = s.rows.get(other);
    if row is not None {
        _journal_touch_row(s, other, jnl);
        if row.add(delta) < 0.0 {
            s.infeasible_rows.append(other);
        }
        return;
    }
    for symbol in sorted(s.rows.keys()) {
        r = s.rows[symbol];
        coeff = r.coefficient_for(marker);
        if near_zero(coeff) {
            continue;
        }
        _journal_touch_row(s, symbol, jnl);
        if r.add(delta * coeff) < 0.0 {
            if _journal_kind_of(s, symbol) != SymbolKind.EXTERNAL {
                s.infeasible_rows.append(symbol);
            }
        }
    }
}
