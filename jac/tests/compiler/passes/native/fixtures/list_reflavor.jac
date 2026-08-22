"""A list whose arms unify at `list[jacval]` still reaches a `list[ptr]` slot.

`([v] if v is not None else []) + list(extra)` is the shape: the ternary's two
arms unify at the boxed universal flavor, and the concatenation wants the
pointer flavor the other operand already has. The two layouts store elements
at different slot widths, so the answer is to rebuild the list element by
element rather than to cast the handle.

The sums are what prove the rebuild is real: a cast would leave the pointer
slots holding boxed words, and reading `.n` back off them would not add up.
"""

obj Node {
    has n: int = 1;
}


def sum_ptr_elems(flag: bool) -> int {
    v = Node(n=10) if flag else None;
    extra = [Node(n=3), Node(n=4)];
    names = ([v] if v is not None else []) + list(extra);
    total = 0;
    for x in names {
        total += x.n;
    }
    return total;
}


def count_ptr_elems(flag: bool) -> int {
    v = Node(n=10) if flag else None;
    extra = [Node(n=3), Node(n=4)];
    return len(([v] if v is not None else []) + list(extra));
}


def sum_scalar_elems(flag: bool) -> int {
    v = 10 if flag else None;
    extra = [3, 4];
    vals = ([v] if v is not None else []) + list(extra);
    total = 0;
    for x in vals {
        total += x;
    }
    return total;
}


def join_str_elems(flag: bool) -> int {
    v = "abc" if flag else None;
    extra = ["de", "f"];
    parts = ([v] if v is not None else []) + list(extra);
    total = 0;
    for s in parts {
        total += len(s);
    }
    return total;
}
