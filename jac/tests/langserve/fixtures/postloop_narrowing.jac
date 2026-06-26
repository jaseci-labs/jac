def for_loop(items: list[int]) {
    fb: int | str | None = None;
    for it in items {
        if it > 5 {
            fb = 5;
        } else {
            fb = "s";
        }
    }
    out = fb;
}

def while_loop(n: int) {
    x: int | None = None;
    while n > 0 {
        x = 5;
        n = n - 1;
    }
    res = x;
}
