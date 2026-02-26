"""Tests for assignment-based type narrowing.

When a variable with a union type is assigned a more specific value,
the type should be narrowed to the assigned type for subsequent uses.
"""

def add_one(x: int) -> int {
    return x + 1;
}

# 1. Basic assignment narrowing: int | None -> int
def test_assignment_narrows_union(a: int | None) -> int {
    a = 90;
    return add_one(a);  # Ok - 'a' is narrowed to int

}

# 2. Multiple reassignments
def test_multiple_reassignments(x: int | None) -> int {
    x = 1;  # narrows to int
    x = 2;  # still int
    return add_one(x);  # Ok

}

# 3. Narrowing doesn't widen (list[int] stays list[int], not list[])
def test_no_widen_list -> int {
    l: list[int] = [];
    for i in l {
        x: int = i;  # Ok - i is int from list[int]
    }
    return 0;
}
