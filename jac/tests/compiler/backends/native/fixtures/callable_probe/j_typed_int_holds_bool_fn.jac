def is_pos(x: int) -> bool {
    return x > 0;
}

def call1(f: Callable[[int], int], x: int) -> int {
    return f(x);
}

with entry {
    print(call1(is_pos, 3));
}
