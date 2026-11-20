"""Test Final with union types - was crashing with 'UnionType' has no attribute 'shared'."""

import from typing { Final }

# This was crashing: Final[UnionType] when unwrapped loses ClassType
glob CONFIG: Final[int | str] = "hello";

# Assignment to Final union type
glob VALUE: Final[int | str] = 42;

# Function returning Final union
def get_value() -> Final[int | str] {
    return "test";
}
