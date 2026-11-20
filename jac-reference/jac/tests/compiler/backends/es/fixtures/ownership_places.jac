def exchange -> list[int | None] {
    a: int | None = 1;
    b: int | None = 2;
    swap(&mut a, &mut b);
    old = take(a);
    return [old, a, b];
}

obj Box {
    has value: int | None;
}

def field_places -> list[int | None] {
    a = Box(value=1);
    b = Box(value=2);
    seen: list[int] = [];
    def get_box(which: int) -> Box {
        seen.append(which);
        return a if which == 1 else b;
    }
    result = swap(&mut get_box(1).value, &mut get_box(2).value);
    old = take(get_box(1).value);
    return [old, a.value, b.value, result, len(seen), seen[0], seen[1], seen[2]];
}
