"""Fixture: test blocks in a pure .na.jac module (one passing, one failing)."""

def add(a: int, b: int) -> int {
    return a + b;
}

def scale(x: int) -> int {
    return x * GAIN;
}

glob GAIN: int = 3;

test "add works" {
    assert add(2, 3) == 5;
    assert add(-1, 1) == 0;
}

test "globals visible in tests" {
    assert scale(4) == 12;
}

test "deliberate failure" {
    assert add(2, 2) == 5;
}

with entry {}
