"""Slicing a list-typed object field (issue #6473).

Slicing an object field (`b.items[:pos]`) with a conditionally-computed
index used to fall through the slice handler and be mis-lowered as a plain
index (`b.items[pos]`), aborting with SIGABRT (out-of-bounds IndexError).
These fixtures exercise the object-field slice path against the equivalent
plain-local path, which has always worked.
"""

obj Box { has items: list; }

obj IntBox { has items: list[int]; }

obj Scope { has next: list; }

"""Slice an object field with a conditionally-computed index (the crashing shape)."""
def slice_field(b: Box, k: int) -> int {
    pos = k;
    if pos < 0 { pos = pos + len(b.items) + 1; }
    ys: list = b.items[:pos] + b.items[pos:];
    return len(ys);
}

"""Identical logic on a plain-list local (the always-working control)."""
def slice_local(xs: list, k: int) -> int {
    pos = k;
    if pos < 0 { pos = pos + len(xs) + 1; }
    ys: list = xs[:pos] + xs[pos:];
    return len(ys);
}

"""b.items[:pos] + b.items[pos:] on a field; total length is preserved."""
def field_roundtrip(k: int) -> int {
    b = Box(items=[1, 2, 3]);
    return slice_field(b, k);
}

"""Same on a plain-list local."""
def local_roundtrip(k: int) -> int {
    e: list = [1, 2, 3];
    return slice_local(e, k);
}

"""Sum the elements of a field slice to confirm the right elements are taken."""
def field_prefix_sum(n: int) -> int {
    b = IntBox(items=[10, 20, 30, 40]);
    pre: list[int] = b.items[:n];
    total = 0;
    for v in pre { total = total + v; }
    return total;
}

"""The portable OSP-kernel `osp_visit` shape: insert `filtered` at `pos` of a field."""
def osp_insert(insert_loc: int) -> int {
    scope = Scope(next=[1, 2, 3]);
    filtered: list = [9];
    pos = insert_loc;
    if pos < -len(scope.next) { pos = 0; }
    elif pos < 0 { pos = pos + len(scope.next) + 1; }
    scope.next = scope.next[:pos] + filtered + scope.next[pos:];
    return len(scope.next);
}
