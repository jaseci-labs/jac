"""Tests for assignment-based type narrowing."""

def add_one(x: int) -> int {
    return x + 1;
}

def test_assignment_narrows_union(a: int | None) -> int {
    a = 90;
    return add_one(a);  # Ok

}

def test_multiple_reassignments(x: int | None) -> int {
    x = 1;
    x = 2;
    return add_one(x);  # Ok

}

def test_no_widen_list -> int {
    l: list[int] = [];
    for i in l {
        x: int = i;  # Ok
    }
    return 0;
}
