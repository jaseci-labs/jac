"""Loop-exit narrowing: a loop body may run zero times.

After a loop, a variable reassigned in the body must widen to the union of the
pre-loop (entry) type and the body's assigned type. A `for`/`while` body that
assigns `fb = 5` to a `int | None` variable must leave `fb` as `int | None`
after the loop (zero-trip keeps None), so an `is not None` guard then narrows
it to `int` and the return is valid.

Previously the post-loop type was read from the loop header, which drops the
body back-edge, leaving `fb` stuck at `NoneType`; the `is not None` guard then
failed to narrow and the returns raised a false `int | None` vs `int` error.
"""

def for_widen(items: list[int]) -> int {
    fb: int | None = None;
    for it in items {
        fb = 5;
    }
    if fb is not None {
        return fb;          # fb narrows to int -> valid
    }
    return 0;
}

def while_widen(n: int) -> int {
    x: int | None = None;
    while n > 0 {
        x = 5;
        n = n - 1;
    }
    if x is not None {
        return x;           # x narrows to int -> valid
    }
    return 0;
}

def nested_widen(rows: list[list[int]]) -> int {
    acc: int | None = None;
    for row in rows {
        for v in row {
            acc = v;
        }
    }
    if acc is not None {
        return acc;         # acc narrows to int -> valid
    }
    return 0;
}

with entry {
    for_widen([1, 2, 3]);
    while_widen(3);
    nested_widen([[1, 2], [3]]);
}
