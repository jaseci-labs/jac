glob x = 5,
     y = 2;

test "a" {
    assert almostEqual(5, x);
}

test "b" {
    assert "l" in "llm";
}

test "c" {
    assert x - y == 3;
}

test "d" {
    assert 1 == 2;
}
