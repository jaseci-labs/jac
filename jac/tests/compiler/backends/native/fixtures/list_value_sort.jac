"""Native value sorting scales without changing list ownership or scalar order."""
def:pub large_sort(count: int) -> i64 {
    values = [count - index for index in range(count)];
    values.sort();
    total: i64 = 0;
    for (index, value) in enumerate(values) {
        if value != index + 1 {
            return -1;
        }
        total += i64(value);
    }
    return total;
}

def:pub scalar_sorts -> bool {
    names = ["omega", "alpha", "beta", "alpha"];
    asc = sorted(names);
    names.sort(reverse=True);
    words_ok = asc == ["alpha", "alpha", "beta", "omega"]
        and names == ["omega", "beta", "alpha", "alpha"];
    numbers: list[u64] = [u64(18446744073709551615), u64(0), u64(9223372036854775808)];
    numbers.sort();
    booleans = [True, False, True];
    booleans.sort();
    small: list[f32] = [f32(2.5), f32(-1.5), f32(0)];
    small.sort();
    empty: list[int] = [];
    empty.sort();
    return words_ok
        and numbers[0] == u64(0)
        and numbers[2] == u64(18446744073709551615)
        and booleans == [False, True, True]
        and small[0] == f32(-1.5)
        and len(empty) == 0;
}
