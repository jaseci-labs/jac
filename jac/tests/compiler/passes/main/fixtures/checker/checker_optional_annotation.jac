"""Optional[X] type annotations resolve to Union[X, None].

Valid optional assignments and parameters; mismatched non-None values error.
Pattern follows Literal annotation testing.
"""
import from typing { Optional }

def take_optional_str(val: Optional[str]) -> str | None {
    return val;
}

def take_optional_int(val: Optional[int]) -> int | None {
    return val;
}

obj Container {
    has value: Optional[str] = None;
    has count: Optional[int] = None;
}

# --- Valid: None and matching type ---
def ok_none_arg() -> str | None {
    return take_optional_str(None);
}

def ok_str_arg() -> str | None {
    return take_optional_str("hello");
}

def ok_none_assign() -> None {
    x: Optional[str] = None;
    y: Optional[int] = None;
    z: Optional[bool] = True;
    return;
}

def ok_optional_access() -> str | None {
    c = Container();
    return c.value;
}

# --- Valid: Optional in containers ---
def ok_optional_list() -> list[str | None] {
    items: list[Optional[str]] = [None, "a", "b"];
    return items;
}

def ok_optional_dict() -> dict[str, int | None] {
    mapping: dict[str, Optional[int]] = {"x": None, "y": 42};
    return mapping;
}

# --- Invalid: Non-None value for Optional when None is expected ---
def bad_assign() -> None {
    # This should fail: assigning int to Optional[str]
    x: Optional[str] = 42;
    return;
}

def bad_param() -> str | None {
    # This should fail: passing int when Optional[str] expected
    return take_optional_str(123);
}

def bad_optional_int() -> None {
    # This should fail: assigning string to Optional[int]
    x: Optional[int] = "not an int";
    return;
}
