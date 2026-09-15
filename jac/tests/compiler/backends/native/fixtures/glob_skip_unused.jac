"""A schema-style glob no native code touches; py-side consumers only."""

glob SCHEMA: dict[int, tuple[str, complex]] = {
         1: ("a", complex(1, 2), ),
         2: ("b", complex(3, 4), )
     };


def double(n: int) -> int {
    return n * 2;
}
