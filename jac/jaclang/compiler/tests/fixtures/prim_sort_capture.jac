"""Sort keys capture scalar locals and an object used by an aggregate key."""
obj SortBounds {
    has x: int,
        width: int;
}

def sort_capture_py -> dict[str, any] {
    bias = 5;
    factor = -1;
    values = [2, 7, 4, 1];
    by_distance = sorted(values, key=lambda (x: int) -> int { abs(x - bias); });
    values.sort(key=lambda (x: int) -> int { x * factor + bias; });
    bounds = SortBounds(x=3, width=12);
    cells: list[list[int]] = [[8, 1], [4, 2], [13, 3]];
    ordered = sorted(
        cells,
        key=lambda (cell: list[int]) -> (int, int) { (
            min(cell[0] - bounds.x, bounds.x + bounds.width - cell[0]),
            cell[1]
        ); }
    );
    reversed_cells = sorted(
        cells,
        key=lambda (cell: list[int]) -> (int, int) { (
            min(cell[0] - bounds.x, bounds.x + bounds.width - cell[0]),
            cell[1]
        ); },
        reverse=True
    );
    return {
        "near": by_distance[0],
        "far": by_distance[3],
        "first": values[0],
        "last": values[3],
        "edge": ordered[0][0],
        "middle": ordered[2][0],
        "reverse": reversed_cells[0][0]
    };
}

def sort_capture_na -> dict[str, any] {
    bias = 5;
    factor = -1;
    values = [2, 7, 4, 1];
    by_distance = sorted(values, key=lambda (x: int) -> int { abs(x - bias); });
    values.sort(key=lambda (x: int) -> int { x * factor + bias; });
    bounds = SortBounds(x=3, width=12);
    cells: list[list[int]] = [[8, 1], [4, 2], [13, 3]];
    ordered = sorted(
        cells,
        key=lambda (cell: list[int]) -> (int, int) { (
            min(cell[0] - bounds.x, bounds.x + bounds.width - cell[0]),
            cell[1]
        ); }
    );
    reversed_cells = sorted(
        cells,
        key=lambda (cell: list[int]) -> (int, int) { (
            min(cell[0] - bounds.x, bounds.x + bounds.width - cell[0]),
            cell[1]
        ); },
        reverse=True
    );
    return {
        "near": by_distance[0],
        "far": by_distance[3],
        "first": values[0],
        "last": values[3],
        "edge": ordered[0][0],
        "middle": ordered[2][0],
        "reverse": reversed_cells[0][0]
    };
}
