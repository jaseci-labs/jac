"""Factory module for the getattr-alias regression tests.

`f = na_alias_factory_lib.make_doubler()` is an ordinary module call whose
result is a callable, not a literal getattr alias: the alias resolver must
leave both the call and `f(...)` alone so the factory runs and its result is
what gets invoked.
"""

def:pub make_doubler -> Callable[[int], int] {
    return doubler;
}

def doubler(x: int) -> int {
    return x * 2;
}
