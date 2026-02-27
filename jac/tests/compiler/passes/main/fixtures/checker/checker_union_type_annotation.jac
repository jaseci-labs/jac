def get_thing() -> int | None {
    return 1;
}

def get_int_or_str() -> int | str {
    return 1;
}

with entry {
    x: int | None = 21;  # <-- Ok
    y: int | None = get_thing();  # <-- Ok
    z: int | str | None = get_thing();  # <-- Ok: int | None is subset of int | str | None
    w: int | str | None = get_int_or_str();  # <-- Ok: int | str is subset of int | str | None
    a: int | None = get_int_or_str();  # <-- Error: int | str is not subset of int | None
}
