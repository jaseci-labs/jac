"""Fixture for Bug #22: Tuple unpacking in for loops returns UnknownType.

When iterating over list[tuple[A, B, C]] with destructuring like:
    for (a, b, c) in items { ... }

The type checker failed to infer types for a, b, c because it only
handled tuple unpacking for Assignment, not for InForStmt/InnerCompr.
"""

class Foo {
    has name: str = "test";
}

with entry {
    # Test 1: Basic tuple unpacking in for loop
    items: list[tuple[str, int, Foo]] = [("a", 1, Foo()), ("b", 2, Foo())];

    for (s, n, f) in items {
        # These should all be correctly typed now
        x: str = s;      # s should be str
        y: int = n;      # n should be int
        z: Foo = f;      # f should be Foo
        print(f.name);   # Should work - f is Foo

        # These should produce type errors
        bad1: int = s;   # Error: str not assignable to int
        bad2: str = n;   # Error: int not assignable to str
        bad3: str = f;   # Error: Foo not assignable to str
    }

    # Test 2: Tuple unpacking in list comprehension
    names = [name for (name, _, _) in items];
    check_name: str = names[0];  # Should work
    bad_name: int = names[0];    # Error: str not assignable to int

    # Test 3: Nested tuple unpacking (2-element tuple)
    pairs: list[tuple[int, str]] = [(1, "a"), (2, "b")];
    for (num, text) in pairs {
        a: int = num;    # Should work
        b: str = text;   # Should work
        c: str = num;    # Error: int not assignable to str
    }
}
