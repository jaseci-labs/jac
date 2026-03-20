"""Bug #FINAL-1: Final[T] not unwrapped for attribute access.

Member lookup ran against Final instead of T, so Final[list[int]].count
raised E1030. Fix: unwrap Final[T] -> T at the start of is_class_instance()
attribute access (unwrapping already existed for assignment checks).
"""

import from typing { Final }

obj Container {
    has data: Final[list[int]] = [1, 2, 3];
}

def test_final_attr_access(c: Container) -> None {
    n = c.data.count(1);  # <-- Ok (was E1030 before fix)
    l = len(c.data);  # <-- Ok
}

def test_final_mapping(d: Final[dict[str, int]]) -> None {
    items = d.items();  # <-- Ok (was E1030 before fix)
    keys = d.keys();  # <-- Ok
}
