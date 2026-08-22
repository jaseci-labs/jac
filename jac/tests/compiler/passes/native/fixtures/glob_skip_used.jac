"""The same non-lowerable glob, but native code references it."""

glob SCHEMA: dict[int, tuple] = {1: ("a", True, ), 2: ("b", False, )};


def read_schema(n: int) -> int {
    row = SCHEMA[n];
    return len(row);
}
