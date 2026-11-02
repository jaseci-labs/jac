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

# list[own T] += moves the elements: the borrowed source drains to empty so
# each own Cell still has exactly one owner.
def extend_moves_source -> int {
    xs: list[own Cell] = [Cell(a=1, b=1)];
    ys: list[own Cell] = [Cell(a=2, b=2), Cell(a=3, b=3)];
    xs += ys;
    total: int = 0;
    for c in xs {
        total = total + c.a * 100 + c.b;
    }
    for c in ys {
        total = total + c.a * 100 + c.b;
    }
    return total * 10 + len(ys);
}

obj Empty {}

def repeat_zero_sized -> int {
    es: list[own Empty] = [Empty(), Empty()];
    es *= 2;
    return len(es);
}

def self_extend_zero_sized -> int {
    es: list[own Empty] = [
        Empty(),
        Empty(),
        Empty(),
        Empty(),
        Empty(),
        Empty(),
        Empty(),
        Empty(),
        Empty()
    ];
    es += es;
    return len(es);
}

def run {
    print(repeat_cells(9));
    print(clear_cells());
    print(reuse_after_clear());
    print(repeat_empty());
    print(self_extend_cells());
    print(overflow_repeat_raises());
    print(extend_moves_source());
    print(repeat_zero_sized());
    print(self_extend_zero_sized());
}

with entry {
    run();
    print("end");
}
