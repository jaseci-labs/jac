"""Bare generic types (e.g. list without type args) should be treated as
list[Any] per PEP 484, allowing attribute access on iteration variables
instead of producing Unknown type errors."""

obj Item {
    has name: str,
        value: int;
}

with entry {
    # Bare list (no type args) - iterating should yield Any, not Unknown
    items: list = [];
    for item in items {
        x = item.name;       # <-- Should be OK (Any allows attribute access)
        y = item.whatever;   # <-- Should be OK (Any allows any attribute)
    }

    # Bare dict - iterating should yield Any, not Unknown
    data: dict = {};
    for key in data {
        z = key.upper;  # <-- Should be OK (Any allows attribute access)
    }

    # Bare list in comprehension
    other: list = [];
    result = [o.name for o in other];  # <-- Should be OK

    # Bare list subscript should also work (not just iteration)
    first = items[0];
    w = first.whatever;  # <-- Should be OK (Any allows attribute access)

    # Typed list should still catch errors
    typed: list[int] = [1, 2, 3];
    for t in typed {
        a: int = t;   # <-- OK
        b: str = t;   # <-- Error (int not assignable to str)
    }
}
