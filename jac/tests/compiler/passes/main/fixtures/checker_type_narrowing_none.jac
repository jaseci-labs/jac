"""Fixture: Type narrowing error - accessing None attributes in else branch."""

def error_none_attr(value: int | None) {
    if value is not None {
        print(value);
    } else {
        print(value.bit_length());  # <-- Error: None has no .bit_length()
    }
}

def error_nested_none(data: dict | None) {
    if data is not None {
        print(data.keys());
    } else {
        print(data.keys());  # <-- Error: None has no .keys()
    }
}
