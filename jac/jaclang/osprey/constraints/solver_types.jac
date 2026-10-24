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

impl Row.insert_symbol(symbol: int, coefficient: float = 1.0) {
    self.cells[symbol] = self.cells.get(symbol, 0.0) + coefficient;
    if near_zero(self.cells[symbol]) {
        self.cells.pop(symbol);
    }
}

impl Row.insert_row(other: Row, coefficient: float = 1.0) {
    self.constant += other.constant * coefficient;
    for symbol in sorted(other.cells.keys()) {
        coeff = other.cells[symbol] * coefficient;
        if not near_zero(coeff) {
            self.insert_symbol(symbol, coeff);
        }
    }
}

impl Row.remove_symbol(symbol: int) {
    if symbol in self.cells {
        self.cells.pop(symbol);
    }
}

impl Row.reverse_sign {
    self.constant = -self.constant;
    for symbol in sorted(self.cells.keys()) {
        self.cells[symbol] = -self.cells[symbol];
    }
}

impl Row.solve_for(symbol: int) {
    coeff = -1.0 / self.cells[symbol];
    self.cells.pop(symbol);
    self.constant *= coeff;
    for s in sorted(self.cells.keys()) {
        self.cells[s] *= coeff;
    }
}

impl Row.solve_for_symbols(lhs: int, rhs: int) {
    self.insert_symbol(lhs, -1.0);
    self.solve_for(rhs);
}

impl Row.coefficient_for(symbol: int) -> float {
    return self.cells.get(symbol, 0.0);
}

impl Row.add(delta: float) -> float {
    self.constant += delta;
    return self.constant;
}

impl Row.clone -> Row {
    r = Row(constant=self.constant);
    r.cells = dict(self.cells);
    return r;
}

impl Row.substitute(symbol: int, row: Row) -> None {
    if symbol not in self.cells {
        return;
    }
    coefficient = self.cells.pop(symbol);
    self.insert_row(row, coefficient);
}


impl CostRow.insert_symbol(symbol: int, coefficient: LexWeight) -> None {
    if lex_is_zero(coefficient) {
        return;
    }
    current = self.cells.get(symbol, lex_zero());
    updated = lex_add(current, coefficient);
    if lex_is_zero(updated) {
        self.cells.pop(symbol);
    } else {
        self.cells[symbol] = updated;
    }
}

impl CostRow.insert_row(other: Row, coefficient: LexWeight) {
    self.constant = lex_add(self.constant, lex_scale(coefficient, other.constant),);
    for symbol in sorted(other.cells.keys()) {
        self.insert_symbol(symbol, lex_scale(coefficient, other.cells[symbol]),);
    }
}

impl CostRow.remove_symbol(symbol: int) {
    if symbol in self.cells {
        self.cells.pop(symbol);
    }
}

impl CostRow.clone -> CostRow {
    copy = CostRow(
        constant=LexWeight(
            tiers=[
                self.constant.tiers[0],
                self.constant.tiers[1],
                self.constant.tiers[2],

            ]
        )
    );
    for symbol in sorted(self.cells.keys()) {
        weight = self.cells[symbol];
        copy.cells[symbol] = LexWeight(
            tiers=[weight.tiers[0], weight.tiers[1], weight.tiers[2], ]
        );
    }
    return copy;
}

impl CostRow.substitute(symbol: int, row: Row) -> None {
    coefficient = self.cells.get(symbol);
    if coefficient is None {
        return;
    }
    self.cells.pop(symbol);
    self.insert_row(row, coefficient);
}
