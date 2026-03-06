"""Test fixture: function pointer passing and invocation.

Tests that functions can be passed as arguments (function pointers)
in the native pathway.
"""

def add(a: int, b: int) -> int {
    return a + b;
}

def mul(a: int, b: int) -> int {
    return a * b;
}

def negate(x: int) -> int {
    return -x;
}

def identity(x: int) -> int {
    return x;
}

"""Struct with various field types for layout contract testing."""
obj AllFields {
    has x: int = 0;
    has y: float = 0.0;
    has name: str = "";
    has flag: bool = False;
    has items: list[int] = [];
}

def make_all_fields(x: int, y: float, name: str) -> AllFields {
    return AllFields(x=x, y=y, name=name, flag=True, items=[1, 2, 3]);
}

def get_all_fields_x(af: AllFields) -> int {
    return af.x;
}

def get_all_fields_flag(af: AllFields) -> bool {
    return af.flag;
}

"""Optional field obj for testing T | None layout."""
obj MaybePoint {
    has x: int = 0;
    has y: int = 0;
    has label: str | None = None;
}

def make_maybe_point(x: int, y: int) -> MaybePoint {
    return MaybePoint(x=x, y=y);
}

def get_maybe_x(p: MaybePoint) -> int {
    return p.x;
}
