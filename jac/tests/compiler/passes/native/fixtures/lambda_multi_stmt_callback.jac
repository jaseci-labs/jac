def map_multi_stmt_callback -> int {
    t = 0;
    for v in map(
        lambda (x: int) -> int {
            y = x + 1;
            return y * 2;
        },
        [1, 2, 3]
    ) {
        t = t + v;
    }
    return t;
}

def sort_multi_stmt_key -> int {
    items = [31, 12, 23];
    items.sort(
        key=lambda (x: int) -> int {
            t = x % 10;
            return t;
        }
    );
    return items[0] * 100 + items[1] * 10 + items[2];
}
