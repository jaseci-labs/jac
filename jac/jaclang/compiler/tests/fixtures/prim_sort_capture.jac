"""Sort keys capture scalar locals and an object used by an aggregate key,
over empty, single-element and longer lists."""
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
    empty: list[int] = [];
    empty.sort(key=lambda (x: int) -> int { x * factor + bias; });
    single = sorted([9], key=lambda (x: int) -> int { abs(x - bias); });
    lone: list[list[int]] = [[6, 4]];
    lone_sorted = sorted(
        lone,
        key=lambda (cell: list[int]) -> (int, int) { (cell[0] - bounds.x, cell[1]); }
    );
    no_cells: list[list[int]] = [];
    no_cells_sorted = sorted(
        no_cells,
        key=lambda (cell: list[int]) -> (int, int) { (cell[0] - bounds.x, cell[1]); }
    );
    return {
        "near": by_distance[0],
        "far": by_distance[3],
        "first": values[0],
        "last": values[3],
        "edge": ordered[0][0],
        "middle": ordered[2][0],
        "reverse": reversed_cells[0][0],
        "empty": len(empty),
        "single": single[0],
        "lone": lone_sorted[0][0],
        "no_cells": len(no_cells_sorted)
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
    empty: list[int] = [];
    empty.sort(key=lambda (x: int) -> int { x * factor + bias; });
    single = sorted([9], key=lambda (x: int) -> int { abs(x - bias); });
    lone: list[list[int]] = [[6, 4]];
    lone_sorted = sorted(
        lone,
        key=lambda (cell: list[int]) -> (int, int) { (cell[0] - bounds.x, cell[1]); }
    );
    no_cells: list[list[int]] = [];
    no_cells_sorted = sorted(
        no_cells,
        key=lambda (cell: list[int]) -> (int, int) { (cell[0] - bounds.x, cell[1]); }
    );
    return {
        "near": by_distance[0],
        "far": by_distance[3],
        "first": values[0],
        "last": values[3],
        "edge": ordered[0][0],
        "middle": ordered[2][0],
        "reverse": reversed_cells[0][0],
        "empty": len(empty),
        "single": single[0],
        "lone": lone_sorted[0][0],
        "no_cells": len(no_cells_sorted)
    };
}
