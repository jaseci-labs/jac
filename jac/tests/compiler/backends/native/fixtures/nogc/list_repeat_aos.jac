"""list[own Cell] *= n under enforced headerless codegen: the by-value AoS
buffer grows once up front so the copy loop never reads element pointers
out of a buffer push() has freed, `*= 0` clears in place, and repeating an
empty list is O(1). Managed modes keep pointer elements with
byte-identical output."""

obj Cell {
    has a: int = 0,
        b: int = 0;
}

def repeat_cells(n: int) -> int {
    cells: list[own Cell] = [Cell(a=7, b=11)];
    cells *= n;
    total: int = 0;
    for c in cells {
        total = total + c.a * 100 + c.b;
    }
    return total;
}

def clear_cells -> int {
    cells: list[own Cell] = [Cell(a=1, b=2), Cell(a=3, b=4)];
    cells *= 5;
    cells *= 0;
    return len(cells);
}

def reuse_after_clear -> int {
    cells: list[own Cell] = [Cell(a=9, b=9)];
    cells *= 0;
    cells.append(Cell(a=5, b=6));
    return cells[0].a * 100 + cells[0].b;
}

def repeat_empty -> int {
    cells: list[own Cell] = [];
    cells *= 1000000000;
    return len(cells);
}

def self_extend_cells -> int {
    cells: list[own Cell] = [
        Cell(a=1, b=1),
        Cell(a=2, b=1),
        Cell(a=3, b=1),
        Cell(a=4, b=1),
        Cell(a=5, b=1)
    ];
    cells += cells;
    total: int = 0;
    for c in cells {
        total = total + c.a * 100 + c.b;
    }
    return total;
}

def overflow_repeat_raises -> bool {
    cells: list[own Cell] = [Cell(a=1, b=1)];
    try {
        cells *= 1152921504606846976;
    } except MemoryError {
        return True;
    }
    return False;
}

def run {
    print(repeat_cells(9));
    print(clear_cells());
    print(reuse_after_clear());
    print(repeat_empty());
    print(self_extend_cells());
    print(overflow_repeat_raises());
}

with entry {
    run();
    print("end");
}
