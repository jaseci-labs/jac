def _new_solver -> Solver;

obj Solver {
    has rows: dict[int, Row] = {},
        kinds: dict[int, SymbolKind] = {},
        var_symbols: dict[int, int] = {},
        cns: dict[str, Tag] = {},
        handle_keys: dict[int, str] = {},
        provenance: dict[int, str] = {},
        next_handle_id: int = 1,
        objective: CostRow = CostRow(),
        id_tick: int = 1,
        next_var_id: int = 1,
        history: list[StoredConstraint] = [],
        edits: dict[int, EditInfo] = {},
        infeasible_rows: list[int] = [],
        generation: int = 0;

    def new_variable -> Variable;
    def add_constraint(c_raw: Constraint, provenance: str = "") -> SolveResult;
    def has_constraint(handle: ConstraintHandle) -> bool;
    def provenance_of(handle: ConstraintHandle) -> str;
    def _replay_all(order: list[StoredConstraint]) -> Solver | None;
    def _adopt(bundle: Solver);
    def remove_constraint(handle: ConstraintHandle) -> SolveResult;
    def add_edit_variable(v: Variable, strength: StrengthTier) -> SolveResult;
    def remove_edit_variable(v: Variable) -> SolveResult;
    def has_edit_variable(v: Variable) -> bool;
    def suggest_value(v: Variable, value: float) -> SolveResult;
    def snapshot -> SolverSnapshot;
    def reset;
}

def solver_strength_for_key(s: Solver, key: str) -> StrengthTier;

impl _new_solver -> Solver {
    return Solver();
}

impl Solver.new_variable -> Variable {
    v = Variable(id=self.next_var_id);
    self.next_var_id += 1;
    return v;
}

impl Solver.add_constraint(c_raw: Constraint, provenance: str = "") -> SolveResult {
    if not _journal_expression_is_finite(self, c_raw.expression) {
        return SolveResult(ok=False, error=SolveError.NON_FINITE_VALUE);
    }
    c = Constraint(
        expression=normalize_expression(c_raw.expression),
        relation=c_raw.relation,
        strength=c_raw.strength,
    );
    key = constraint_key(c);
    if key in self.cns {
        return SolveResult(
            ok=False,
            error=SolveError.DUPLICATE_CONSTRAINT,
            witness_provenance=_journal_witness_for_key(self, key),
        );
    }

    jnl = _journal_begin(self);
    tag = Tag();
    res = _solver_add_core(self, c, tag, jnl);
    if not res.ok {
        _journal_rollback(self, jnl);
        if res.error != SolveError.UNSATISFIABLE {
            res.witness_provenance = _journal_witness_extra(self, provenance);
            return res;
        }

        rebuilt = _solver_rebuild_admitting(self, c, _new_solver);
        if rebuilt is None {
            return SolveResult(
                ok=False,
                error=SolveError.UNSATISFIABLE,
                message="required system inconsistent under all "
                    + "elimination orders",
                witness_provenance=_journal_witness_extra(self, provenance),
            );
        }
        _solver_adopt(self, rebuilt);
    }

    handle = ConstraintHandle(id=self.next_handle_id);
    self.next_handle_id += 1;
    if key not in self.cns {
        self.cns[key] = tag;
    }
    self.handle_keys[handle.id] = key;
    self.provenance[handle.id] = provenance;
    self.history.append(
        StoredConstraint(
            expression=c.expression,
            relation=c.relation,
            strength=c.strength,
            provenance=provenance,
            content_key=key,
        )
    );
    self.generation += 1;
    return SolveResult(ok=True, handle=handle);
}

impl Solver.has_constraint(handle: ConstraintHandle) -> bool {
    return handle.id in self.handle_keys;
}

impl Solver.provenance_of(handle: ConstraintHandle) -> str {
    return self.provenance.get(handle.id, "");
}

impl Solver._replay_all(order: list[StoredConstraint]) -> Solver | None {
    return _solver_replay_all(self, order, _new_solver);
}

impl Solver._adopt(bundle: Solver) {
    _solver_adopt(self, bundle);
}

impl Solver.remove_constraint(handle: ConstraintHandle) -> SolveResult {
    if handle.id not in self.handle_keys {
        return SolveResult(ok=False, error=SolveError.UNKNOWN_CONSTRAINT);
    }
    key = self.handle_keys[handle.id];
    if key not in self.cns {
        return SolveResult(ok=False, error=SolveError.UNKNOWN_CONSTRAINT);
    }
    tag = Tag(marker=self.cns[key].marker, other=self.cns[key].other);
    strength = solver_strength_for_key(self, key);
    jnl = _journal_begin(self);
    res = _solver_remove_core(self, tag, strength, jnl);
    if not res.ok {
        _journal_rollback(self, jnl);
        return res;
    }
    self.cns.pop(key);
    self.handle_keys.pop(handle.id);
    self.provenance.pop(handle.id);
    self.history = [
        st
        for st in self.history
        if st.content_key != key
    ];

    for vid in sorted(self.edits.keys()) {
        if self.edits[vid].key == key {
            self.edits.pop(vid);
        }
    }
    self.generation += 1;
    return res;
}

impl Solver.add_edit_variable(v: Variable, strength: StrengthTier) -> SolveResult {
    if v.id in self.edits {
        return SolveResult(ok=False, error=SolveError.DUPLICATE_EDIT_VARIABLE,);
    }
    if strength == StrengthTier.REQUIRED {
        return SolveResult(
            ok=False,
            error=SolveError.REQUIRED_EDIT_VARIABLE,
            message="edit variables cannot be required",
        );
    }

    c = Constraint(
        expression=normalize_expression(term(v)),
        relation=Relation.EQ,
        strength=strength,
    );
    res = self.add_constraint(c);
    if not res.ok {
        return res;
    }
    handle = res.handle;
    if handle is None {
        return SolveResult(
            ok=False,
            error=SolveError.INTERNAL_INVARIANT,
            message="accepted add returned no handle",
        );
    }
    self.edits[v.id] = EditInfo(
        var_id=v.id, key=self.handle_keys[handle.id], handle=handle,
    );
    return res;
}

impl Solver.remove_edit_variable(v: Variable) -> SolveResult {
    if v.id not in self.edits {
        return SolveResult(ok=False, error=SolveError.UNKNOWN_EDIT_VARIABLE);
    }
    info = self.edits[v.id];
    res = self.remove_constraint(info.handle);

    return res;
}

impl Solver.has_edit_variable(v: Variable) -> bool {
    return v.id in self.edits;
}

impl Solver.suggest_value(v: Variable, value: float) -> SolveResult {
    if not is_finite(value) {
        return SolveResult(ok=False, error=SolveError.NON_FINITE_VALUE);
    }
    if v.id not in self.edits {
        return SolveResult(ok=False, error=SolveError.UNKNOWN_EDIT_VARIABLE);
    }
    info = self.edits[v.id];
    if info.key not in self.cns {
        return SolveResult(ok=False, error=SolveError.UNKNOWN_EDIT_VARIABLE);
    }
    delta = value - info.constant;
    jnl = _journal_begin(self);
    _solver_apply_suggestion(self, info, delta, jnl);
    res = _solver_dual_optimize(self, jnl);
    if not res.ok {
        _journal_rollback(self, jnl);
        return res;
    }
    info.constant = value;
    self.generation += 1;
    return SolveResult(ok=True);
}

impl Solver.snapshot -> SolverSnapshot {
    vals: dict[int, float] = {};
    for vid in sorted(self.var_symbols.keys()) {
        symbol = self.var_symbols[vid];
        if symbol in self.rows {
            vals[vid] = self.rows[symbol].constant;
        } else {
            vals[vid] = 0.0;
        }
    }
    return SolverSnapshot(generation=self.generation, values=vals);
}

impl Solver.reset {
    self.rows = {};
    self.kinds = {};
    self.var_symbols = {};
    self.cns = {};
    self.handle_keys = {};
    self.provenance = {};
    self.next_handle_id = 1;
    self.objective = CostRow();
    self.id_tick = 1;
    self.next_var_id = 1;
    self.history = [];
    self.edits = {};
    self.infeasible_rows = [];
    self.generation = 0;
}

impl solver_strength_for_key(s: Solver, key: str) -> StrengthTier {
    for st in s.history {
        if st.content_key == key {
            return st.strength;
        }
    }
    return StrengthTier.REQUIRED;
}
