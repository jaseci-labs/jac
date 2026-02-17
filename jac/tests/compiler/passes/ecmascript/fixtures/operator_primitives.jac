"""Test fixture for operator primitive dispatch in JS codegen."""

cl def test_list_concat() -> list {
    a: list = [1, 2];
    b: list = a + [3];
    return b;
}

cl def test_str_repeat() -> str {
    s: str = "abc";
    return s * 3;
}

cl def test_list_contains() -> bool {
    items: list = [1, 2, 3];
    return 2 in items;
}
