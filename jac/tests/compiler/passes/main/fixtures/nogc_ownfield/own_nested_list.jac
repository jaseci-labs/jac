"""Nested lists of scalars: fresh inner literals move into the outer list."""

def work {
    grid: list[list[int]] = [[1, 2], [3]];
    grid.append([4, 5]);
    print(len(grid));
    print(grid[0][1]);
    print(grid[2][0]);
}

with entry {
    work();
    print("end");
}
