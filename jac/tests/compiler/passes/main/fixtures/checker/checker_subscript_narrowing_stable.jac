"""Repeated subscript expressions with stable indices narrow as aliases.

`x[i] is not None and x[i].attr` should narrow the second `x[i]` based on
the first when neither `x` nor `i` is reassigned in between. The same
holds for chained subscripts `x[i][j]`. Loop variables that don't change
within the narrowed scope (Pyright's "narrowable expression" rule) count.

Pure narrowing audit -- no list/dict comprehensions here; gap 2 covers
those.
"""

obj Cell {
    has color: int = 0;
}

obj Grid {
    has cells: list[list[Cell | None]] = [];
}

# Stable indices: plain int literal + plain name params.
def stable_lit(g: Grid) -> int {
    if g.cells[0][1] is not None {
        return g.cells[0][1].color;
    }
    return -1;
}

def stable_param(g: Grid, r: int, c: int) -> int {
    if g.cells[r][c] is not None and g.cells[r][c].color == 0 {
        return g.cells[r][c].color;
    }
    return -1;
}

# Loop variables are stable within a single iteration body -- they don't
# change between two reads inside the same `if`.
def loop_vars(g: Grid) -> int {
    total: int = 0;
    for r in range(3) {
        for c in range(3) {
            if g.cells[r][c] is not None and g.cells[r][c].color > 0 {
                total += g.cells[r][c].color;
            }
        }
    }
    return total;
}

# Chained subscript on a self attribute.
obj Board {
    has squares: list[list[Cell | None]] = [];

    def sum_colors() -> int {
        total: int = 0;
        for r in range(3) {
            for c in range(3) {
                if self.squares[r][c] is not None {
                    total += self.squares[r][c].color;
                }
            }
        }
        return total;
    }
}
