"""Bare `tuple`-annotated local tuple-literal assignment (issue #6964 / P2).

Before the fix, `t: tuple = (10, 20)` resolved the bare annotation to the i64
default and the value-struct `{i64, i64}` failed to store ("cannot store
{i64,i64} to i64*"). Parameterized `tuple[int, int]` and the un-annotated form
already worked; this pins the bare form, for both homogeneous and
heterogeneous element types.
"""

def homo_first() -> int {
    t: tuple = (10, 20);
    return t[0];
}

def homo_second() -> int {
    t: tuple = (10, 20);
    return t[1];
}

def hetero_str() -> str {
    t: tuple = ("a", 1);
    return t[0];
}

def hetero_int() -> int {
    t: tuple = ("a", 1);
    return t[1];
}
