"""Fixture: Type narrowing error - assigning None to non-None type in else branch."""

def error_none_assign(value: int | None) {
    if value is not None {
        x: int = value;  # OK: value is int here
    } else {
        y: int = value;  # <-- Error: None cannot be assigned to int
    }
}

def error_nested_none(data: str | None) {
    if data is not None {
        a: str = data;  # OK: data is str here
    } else {
        b: str = data;  # <-- Error: None cannot be assigned to str
    }
}
