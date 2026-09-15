"""The same non-lowerable glob, but native code references it."""

glob SCHEMA: dict[int, tuple[str, complex]] = {
         1: ("a", complex(1, 2), ),
         2: ("b", complex(3, 4), )
     };


def read_schema(n: int) -> int {
    row = SCHEMA[n];
    return len(row);
}
