glob a = 5,
     b = 2;

test "t1" {
    assert almostEqual(a, 6);
}

test "t2" {
    assert a != b;
}

test "t3" {
    assert "d" in "abc";
}

test "t4" {
    assert a - b == 3;
}
