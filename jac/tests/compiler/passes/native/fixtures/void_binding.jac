"""Fixture: a void-typed value bound to a variable.

`sink` returns None (native `void`); binding its call result to `y` has no
storage. The native backend must surface this as an E5090 diagnostic, not crash
in `_entry_alloca` -> `PointerType.as_pointer()` on a void pointee.
"""

def sink(x: int) -> None { }

def caller(x: int) -> int {
    y = sink(x);
    return x;
}
