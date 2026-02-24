"""Fixture: Type narrowing error cases.

This file contains code that SHOULD produce type errors.
Used by test_type_narrowing.jac to verify error detection.
"""

# Error 1: Accessing attribute on None in else branch
def error_none_attr(value: int | None) {
    if value is not None {
        print(value);
    } else {
        print(value.bit_length());  # ERROR: None has no .bit_length()
    }
}

# Error 2: Accessing wrong type attribute after isinstance false branch
def error_wrong_type(value: int | str) {
    if isinstance(value, int) {
        print(value * 2);
    } else {
        print(value * 2);  # ERROR: str * int not valid (no __mul__ overload)
    }
}

# Error 3: Nested if with None check
def error_nested_none(data: dict | None) {
    if data is not None {
        print(data.keys());
    } else {
        print(data.keys());  # ERROR: None has no .keys()
    }
}
