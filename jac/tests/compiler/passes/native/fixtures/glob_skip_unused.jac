"""A schema-style glob no native code touches; py-side consumers only."""

glob SCHEMA: dict[int, tuple] = {1: ("a", True, ), 2: ("b", False, )};


def double(n: int) -> int {
    return n * 2;
}
