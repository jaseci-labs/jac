"""Sort keys that capture an object, over empty, single and longer lists."""

obj Origin {
    has x: int;
}

def ranked(n: int) -> int {
    origin = Origin(x=n % 5);
    cells: list[list[int]] = [];
    for k in range(n % 3) {
        cells.append([k * 7 % 5, k]);
    }
    ordered = sorted(
        cells, key=lambda (cell: list[int]) -> int { abs(cell[0] - origin.x); }
    );
    cells.sort(key=lambda (cell: list[int]) -> int { cell[1] - origin.x; });
    return len(ordered) + len(cells);
}

with entry {
    total = 0;
    for n in range(30) {
        total += ranked(n);
    }
    print(total);
    __rc_collect_cycles();
    __rc_debug_enable();
}
