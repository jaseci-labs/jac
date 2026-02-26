def fn(a: int, *b: int, **c: str) -> None {
    x: int = a;
    y: int = b;  # <-- Error
    z: str = c;  # <-- Error

    h: int = b[0]; # <-- Ok
    i: str = b[1]; # <-- Error

    j: str = c["a"]; # <-- Ok
    k: int = c["a"]; # <-- Error
}
