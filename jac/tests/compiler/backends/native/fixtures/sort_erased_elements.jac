"""Sorting lists whose elements sit in erased `i8*` slots: tuples of every
element mix, bytes and nested lists. Each check compares against the order
Python produces; they used to come back in input order (or ordered by the
first byte of the first field) because every pointer compared as a string."""

def:pub float_int_tuples -> bool {
    ranked: list[tuple[float, int]] = [];
    for (value, index) in [(5.5, 0), (-2.0, 1), (9.25, 2), (0.0, 3)] {
        ranked.append((value, index));
    }
    return sorted(ranked) == [(-2.0, 1), (0.0, 3), (5.5, 0), (9.25, 2)]
        and sorted(ranked, reverse=True) == [(9.25, 2), (5.5, 0), (0.0, 3), (-2.0, 1)];
}

def:pub mixed_tuples -> bool {
    return sorted([(2.5, 1.0), (1.5, 2.0), (1.5, 1.0)])
        == [(1.5, 1.0), (1.5, 2.0), (2.5, 1.0)]
        and sorted([("b", 1), ("a", 2), ("a", 1)]) == [("a", 1), ("a", 2), ("b", 1)]
        and sorted([(0.5, "a"), (9.0, "b"), (3.0, "c")], reverse=True)
            == [(9.0, "b"), (3.0, "c"), (0.5, "a")]
        and sorted([(300, 1), (2, 5), (-7, 0), (256, 9)])
            == [(-7, 0), (2, 5), (256, 9), (300, 1)];
}

def:pub keyed_tuples -> bool {
    pairs = [(5.5, 0), (-2.0, 1), (9.25, 2), (0.0, 3)];
    by_index = sorted(pairs, key=lambda (t: tuple[float, int]) { t[1]; }, reverse=True);
    by_pair = sorted(pairs, key=lambda (t: tuple[float, int]) { (t[1] % 2, t[0]); });
    stable = sorted(
        [(1.0, "b"), (0.0, "z"), (1.0, "a")],
        key=lambda (t: tuple[float, str]) { t[0]; }
    );
    return by_index == [(0.0, 3), (9.25, 2), (-2.0, 1), (5.5, 0)]
        and by_pair == [(5.5, 0), (9.25, 2), (-2.0, 1), (0.0, 3)]
        and stable == [(0.0, "z"), (1.0, "b"), (1.0, "a")];
}

def:pub list_sort_tuples -> bool {
    xs = [(0.5, "a"), (9.0, "b"), (3.0, "c")];
    xs.sort();
    ascending = xs == [(0.5, "a"), (3.0, "c"), (9.0, "b")];
    xs.sort(reverse=True);
    return ascending and xs == [(9.0, "b"), (3.0, "c"), (0.5, "a")];
}

def:pub nested_tuples -> bool {
    nested = [(1.0, (2, "z")), (1.0, (1, "y")), (0.5, (9, "x"))];
    return sorted(nested) == [(0.5, (9, "x")), (1.0, (1, "y")), (1.0, (2, "z"))];
}

def:pub other_erased -> bool {
    rows = [[2.0, 1.0], [1.0, 5.0], [1.0, 2.0]];
    rows.sort();
    return sorted([b"b", b"a", b"ab"]) == [b"a", b"ab", b"b"]
        and rows == [[1.0, 2.0], [1.0, 5.0], [2.0, 1.0]]
        and sorted(["pear", "apple", "fig"], reverse=True) == ["pear", "fig", "apple"];
}

def:pub ragged_tuples -> bool {
    ragged = [(1, 2), (1, ), (0, 5, 1)];
    return sorted(ragged) == [(0, 5, 1), (1, ), (1, 2)]
        and sorted(ragged, reverse=True) == [(1, 2), (1, ), (0, 5, 1)];
}
