# A `None` guard on a subscript narrows what the subscript READS as, not what
# the slot accepts: `x[k] = v` is `x.__setitem__(k, v)`, so the container's
# value type decides the assignment.
def fill(row: dict[str, any], title: str) -> dict[str, any] {
    if row["title"] is None {
        row["title"] = title or None;  # <-- Ok
    }
    return row;
}

def typed_slot(counts: dict[str, int | None]) {
    if counts["a"] is None {
        counts["a"] = 3;  # <-- Ok
        counts["b"] = "x";  # <-- Error
    }
}

# When the container is a union, every member must accept the write: one
# member taking a `str` does not make it valid for the member that takes `int`.
def union_container(box: dict[str, int | None] | dict[str, str | None]) {
    if box["k"] is None {
        box["k"] = "value";  # <-- Error
    }
}

# A container that may still be None is not written through.
def maybe_container(box: dict[str, int | None] | None) {
    if box["k"] is None {
        box["k"] = 3;  # <-- Error
    }
}

