"""Opaque dictionary storage preserves tuple arity and declared element types."""
def singleton -> int {
    values: dict[str, tuple[int]] = {"value": (44, )};
    (only, ) = values["value"];
    return only;
}

def widened_numeric -> float {
    values: dict[str, tuple[float, float]] = {"value": (3, 4)};
    (first, second) = values["value"];
    return first + second;
}

def optional_elements -> int {
    values: dict[str, tuple[int | None, str]] = {
        "value": (5, "yes"),
        "empty": (None, "no")
    };
    (first, label) = values["value"];
    (empty, empty_label) = values["empty"];
    if first is not None and empty is None {
        return first + len(label) + len(empty_label);
    }
    return -1;
}
