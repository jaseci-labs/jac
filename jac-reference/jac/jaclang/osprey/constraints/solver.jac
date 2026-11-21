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
