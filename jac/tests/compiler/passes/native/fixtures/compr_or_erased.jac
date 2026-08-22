"""A comprehension over an `or`-defaulted optional list.

`[p for p in (items or [])]` is `ownership_check_pass._partition_sugar_reason`
and three of its neighbours. The empty literal on the right used to have no
destination to take an element flavor from, so it picked one, differed from the
operand on its left, and the two unified at an erased `i8*`; the comprehension
then had a pointer it could not tell a list layout from, and refused.

Both halves of that are fixed now. The empty display reads its layout from the
operand beside it, and the two shapes that made the first attempt unsound --
an optional list produced by a ternary and held in a local, absent at run time
-- are covered here too, because a null container is now falsy rather than a
dereference.
"""

obj Nd {
    has n: int = 1;
}


def compr_over_or(items: list[Nd] | None) -> int {
    picked = [p for p in (items or [])];
    return len(picked);
}


def tern_local_or(flag: bool) -> int {
    xs = [Nd(n=3), Nd(n=4)] if flag else None;
    ys = xs or [];
    total = 0;
    for p in ys {
        total += p.n;
    }
    return total;
}


def tern_local_compr(flag: bool) -> int {
    xs = [Nd(n=3), Nd(n=4)] if flag else None;
    return len([p for p in (xs or [])]);
}


def tern_inline_or(flag: bool) -> int {
    total = 0;
    for p in (([Nd(n=7)] if flag else None) or []) {
        total += p.n;
    }
    return total;
}
