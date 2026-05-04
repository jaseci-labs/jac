"""Negative cases: variable index and range slice must NOT narrow.

These patterns cannot produce a stable key, so narrowing is correctly
skipped and E1099 is reported. This fixture asserts the absence of
false negatives in the subscript key logic.
"""

obj Item {
    has value: str = "";
}

obj Other {
    has code: int = 0;
}

# Variable index: items[i] - key depends on runtime value of i.
# Must NOT narrow - E1099 expected on .value access.
def bad_variable_index(items: list[Item | Other], i: int) -> str {
    if isinstance(items[i], Item) {
        return items[i].value;  # E1099: items[i] not narrowed (variable index)
    }
    return "";
}

# Range slice: items[0:2] - not a single index.
# Must NOT narrow - E1099 expected.
def bad_range_slice(items: list[Item | Other]) -> str {
    if isinstance(items[0], Item) {
        return items[0:1][0].value;  # E1099: items[0:1] not narrowed (range)
    }
    return "";
}
