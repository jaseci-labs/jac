"""Bug #22: No type checking on destructuring RHS.

When destructuring with tuple/list targets like `(a, b) = expr`,
the type checker skips the whole-expression type check entirely.
This means assigning a non-iterable (e.g., an int) to a destructuring
target produces no error, even though it would crash at runtime.

Expected: `(a, b) = 5` should produce a type error because int is not iterable.
"""

with entry {
    # Valid destructuring — should be fine
    (x, y) = (1, 2);

    # Invalid: int is not iterable, cannot be destructured
    (a, b) = 5;  # <-- Should be Error (int is not iterable)

    # Invalid: str can be iterated but bool cannot be destructured
    [c, d] = True;  # <-- Should be Error (bool is not iterable)

    # Invalid: None is not iterable
    (e, f) = None;  # <-- Should be Error (NoneType is not iterable)
}
