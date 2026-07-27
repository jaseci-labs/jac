"""Fixture: test blocks in a markerless module that infers native."""

def double(x: int) -> int {
    return x * 2;
}

test "inferred double works" {
    assert double(21) == 42;
}

test "inferred deliberate failure" {
    assert double(2) == 5;
}
