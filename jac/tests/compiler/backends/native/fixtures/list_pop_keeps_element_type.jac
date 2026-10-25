"""Elements popped from lists of lists, objects, strings and dicts, bound to
locals with no annotation, keep their own types."""
obj Cell {
    has x: int = 0;
}

"""A depth-first walk over a list of lists, each cell popped into a local."""
def walk(limit: int) -> int {
    todo: list[list[int]] = [[0, 0]];
    seen = 0;
    total = 0;
    while todo and seen < limit {
        cell = todo.pop();
        seen += 1;
        total += cell[0] + cell[1];
        if cell[0] < 12 {
            todo.append([cell[0] + 1, cell[1]]);
            todo.append([cell[0] + 1, cell[1] + 1]);
        }
    }
    return total;
}

def firsts -> list[int] {
    rows: list[list[float]] = [[1.5, 2.0], [3.0, 4.0]];
    front = rows.pop(0);
    names: list[str] = ["a", "bc"];
    last = names.pop();
    cells: list[Cell] = [Cell(x=4), Cell(x=9)];
    got = cells.pop();
    lookups: list[dict[str, int]] = [{"k": 3}];
    found = lookups.pop();
    return [int(front[1]), len(last), got.x, found["k"], len(rows), len(cells)];
}

with entry {
    print(walk(5000));
    print(firsts());
}
