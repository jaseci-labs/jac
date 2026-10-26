enum SolveError {
    OK = "ok",
    UNSATISFIABLE = "unsatisfiable",
    DUPLICATE_CONSTRAINT = "duplicate_constraint",
    UNKNOWN_CONSTRAINT = "unknown_constraint",
    FOREIGN_HANDLE = "foreign_handle",
    DUPLICATE_EDIT_VARIABLE = "duplicate_edit_variable",
    UNKNOWN_EDIT_VARIABLE = "unknown_edit_variable",
    REQUIRED_EDIT_VARIABLE = "required_edit_variable",
    NON_FINITE_VALUE = "non_finite_value",
    INVALID_EXPRESSION = "invalid_expression",
    INTERNAL_INVARIANT = "internal_invariant"
}


obj ConstraintHandle {
    has id: int;
}


obj SolverSnapshot {
    has generation: int,
        values: dict[int, float] = {};
}


obj SolveResult {
    has ok: bool = True,
        error: SolveError = SolveError.OK,
        message: str = "",
        handle: ConstraintHandle | None = None,
        witness_provenance: list[str] = [];
}
