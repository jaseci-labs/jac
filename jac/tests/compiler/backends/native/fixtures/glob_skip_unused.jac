"""A schema-style glob no native code touches; py-side consumers only.
The `any` key lowers to jacval, which native dicts cannot hash, so the
layout stays non-lowerable."""

glob SCHEMA: dict[any, tuple[str, complex]] = {
         1: ("a", complex(1, 2), ),
         2: ("b", complex(3, 4), )
     };


def double(n: int) -> int {
    return n * 2;
}
