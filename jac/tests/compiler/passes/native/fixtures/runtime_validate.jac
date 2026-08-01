# Runtime validation tests — exercises patterns needed for chess game

# Test 1: For-over-list with literal
def test_for_list_literal() -> int {
    total: int = 0;
    for x in [10, 20, 30] {
        total = total + x;
    }
    return total;
}

# Test 2: For-over-list with variable
def test_for_list_var() -> int {
    items: list[int] = [1, 2, 3, 4, 5];
    total: int = 0;
    for x in items {
        total = total + x;
    }
    return total;
}

# Test 3: Nested list creation and indexing
def test_nested_list() -> int {
    rows: list[list[int]] = [];
    for i in range(3) {
        row: list[int] = [];
        for j in range(3) {
            row.append(i * 3 + j);
        }
        rows.append(row);
    }
    return rows[1][2];
}

# Test 4: Nested list set
def test_nested_set() -> int {
    rows: list[list[int]] = [];
    for i in range(2) {
        row: list[int] = [0, 0];
        rows.append(row);
    }
    rows[1][0] = 99;
    return rows[1][0];
}

# Test 5: For-over nested list (list[list[int]])
def test_for_nested() -> int {
    dirs: list[list[int]] = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    total: int = 0;
    for d in dirs {
        total = total + d[0] + d[1];
    }
    return total;
}

# Test 6: Object with postinit that creates a list
obj Grid {
    has cells: list[int] = [],
        size: int = 0;

    def postinit() {
        self.cells = [];
        for i in range(9) {
            self.cells.append(0);
        }
        self.size = 9;
    }

    def get(idx: int) -> int {
        return self.cells[idx];
    }

    def set_val(idx: int, val: int) -> None {
        self.cells[idx] = val;
    }
}

def test_grid_init() -> int {
    g: Grid = Grid();
    return g.size;
}

def test_grid_set_get() -> int {
    g: Grid = Grid();
    g.set_val(4, 42);
    return g.get(4);
}
