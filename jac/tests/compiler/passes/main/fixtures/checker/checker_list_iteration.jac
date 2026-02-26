
with entry {
    l: list[int] = [];

    for i in l {
        x: int = i;  # <-- Ok
        y: str = i;  # <-- Error
    }
}
