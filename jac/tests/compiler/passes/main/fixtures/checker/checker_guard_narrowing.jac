"""Test: Guard check should narrow optional types.

When `if obj.field` guards access, `obj.field` should be narrowed
from `T | None` to `T` inside the block.
"""

obj Prefetch {
    has list_class: int | None = None;
}

def use_int(x: int) -> int {
    return x + 1;
}

def test_guard_narrowing(prefetch: Prefetch) -> int {
    if prefetch.list_class {
        # prefetch.list_class should be narrowed to int here
        return use_int(prefetch.list_class);  # <-- Error: int | None to int

    }
    return 0;
}
