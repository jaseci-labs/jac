def for_union(items: list[int]) -> int | str | None {
    fb: int | str | None = None;
    for it in items {
        if it > 5 {
            fb = 5;
        } else {
            fb = "s";
        }
    }
    return fb;
}

def while_union(n: int) -> int | None {
    x: int | None = None;
    while n > 0 {
        x = 5;
        n = n - 1;
    }
    return x;
}

def iter_for_union -> int | None {
    x: int | None = None;
    for i = 0 to i < 3 by i += 1 {
        x = i;
    }
    return x;
}
