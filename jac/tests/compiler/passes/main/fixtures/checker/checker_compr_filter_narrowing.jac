"""Comprehension `if` filter narrowing carries into the head expression.

For `[x for x in xs if x is not None]`, the element type of the result
must be `T` (not `T | None`) — the filter proves None can't reach the
head. Same rule for dict / set comprehensions, and for chained
subscripts under loop-var indices when the indices are stable.

Also covers the self-reassignment shape `out = [t for t in out ...]`:
the iteration source must resolve to its prior declared type, not
circularly to the in-progress assignment's RHS (which would otherwise
drop the comprehension's head to Unknown).
"""

obj Cell {
    has color: int = 0;
}

# Plain `for x in xs` over an Optional-element list.
def filter_iter_name(xs: list[Cell | None]) -> list[Cell] {
    return [x for x in xs if x is not None];
}

# Same shape with an extra attribute access in the filter.
def filter_iter_name_attr(xs: list[Cell | None]) -> list[int] {
    return [x.color for x in xs if x is not None];
}

# Dict comprehension on the value.
def filter_iter_dict(xs: list[Cell | None]) -> dict[int, Cell] {
    return {i: x for i in range(len(xs)) for x in [xs[i]] if x is not None};
}

# Set comprehension.
def filter_iter_set(xs: list[Cell | None]) -> set[int] {
    return {x.color for x in xs if x is not None};
}

# Self-reassignment: `out = [t for t in out if ...]`. The Name on the
# RHS of the comprehension must resolve through the assignment's
# predecessors, not through the in-progress write being typed.
def filter_self_reassign(items: list[Cell]) -> list[Cell] {
    out = items;
    out = [t for t in out if t.color > 0];
    return out;
}

# Subscript-head: the head expression reads the same subscript the
# filter narrows. Combined gap-1 + gap-2 case from chess.
obj Board {
    has squares: list[list[Cell | None]] = [];

    def all_pieces() -> list[Cell] {
        return [
            self.squares[r][c]
            for r in range(3)
            for c in range(3)
            if self.squares[r][c] is not None
        ];
    }

    def all_colors() -> list[int] {
        return [
            self.squares[r][c].color
            for r in range(3)
            for c in range(3)
            if self.squares[r][c] is not None
        ];
    }
}
