def same(a: any, b: any) -> bool {
    return a == b;
}

glob x: any = 3;
with entry {
    print(same(3, 3.0), same(3.0, 3), same(True, 1), same(1.0, True), same(0, False));
    print(same(3, 3.5), same("3", 3), same(None, 0), same(2, True), same(3, 3));
    print((x as int as float == 3.0), x == 3.0, 3.0 == x, x != 3.0);
}

glob values: list[any] = [1, 2.0, True, "1", None];
with entry {
    print(1.0 in values, 2 in values, 7 in values);
}
