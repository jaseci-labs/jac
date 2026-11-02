enum SymbolKind {
    INVALID = "invalid",
    EXTERNAL = "external",
    SLACK = "slack",
    ERROR = "error",
    DUMMY = "dummy"
}


obj Tag {
    has marker: int = 0,
        other: int = 0;
}


obj Row {
    has constant: float = 0.0,
        cells: dict[int, float] = {};

    def insert_symbol(symbol: int, coefficient: float = 1.0);
    def insert_row(other: Row, coefficient: float = 1.0);
    def remove_symbol(symbol: int);
    def reverse_sign;
    def solve_for(symbol: int);
    def solve_for_symbols(lhs: int, rhs: int);
    def coefficient_for(symbol: int) -> float;
    def add(delta: float) -> float;
    def clone -> Row;
    def substitute(symbol: int, row: Row) -> None;
}


obj CostRow {
    has constant: LexWeight = LexWeight(),
        cells: dict[int, LexWeight] = {};

    def insert_symbol(symbol: int, coefficient: LexWeight) -> None;
    def insert_row(other: Row, coefficient: LexWeight);
    def remove_symbol(symbol: int);
    def clone -> CostRow;
    def substitute(symbol: int, row: Row) -> None;
}


obj MutationJournal {
    has id_tick_start: int = 0,
        allocated_symbols: list[int] = [],
        new_var_ids: list[int] = [],
        inserted_rows: list[int] = [],
        row_snapshots: dict[int, Row] = {},
        objective_snapshot: CostRow | None = None,
        infeasible_start: int = 0;
}


obj StoredConstraint {
    has expression: Expression,
        relation: Relation,
        strength: StrengthTier = StrengthTier.REQUIRED,
        provenance: str = "",
        content_key: str = "";
}


obj EditInfo {
    has var_id: int,
        key: str,
        handle: ConstraintHandle,
        constant: float = 0.0;
}
