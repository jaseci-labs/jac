"""Test lambda with *args and **kwargs parameters."""

with entry {
    f = lambda *args: int: sum(args);
    print(f(1, 2, 3));

    g = lambda **kwargs: str: str(kwargs);
    print(g(a=1, b=2));

    h = lambda x: int, *rest: int: x + sum(rest);
    print(h(10, 20, 30));
}
