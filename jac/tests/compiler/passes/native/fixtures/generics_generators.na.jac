"""Generic generators monomorphize per element type (#7626 A3).

`pairs[T]` is instantiated at int and str from two call sites; the
generator transform must run under each active substitution with
spec-keyed resume/drop symbol names so the specializations do not
collide, and the element type resolves through the same TypeVar
interception the body already uses.
"""

def pairs[T](xs: list[T]) -> Iterator[T] {
    for x in xs {
        yield x;
    }
}

def sum_int_pairs -> int {
    t = 0;
    for x in pairs([1, 2, 3]) {
        t += x;
    }
    return t;
}

def count_str_pairs -> int {
    c = 0;
    for s in pairs(["ab", "c"]) {
        c += len(s);
    }
    return c;
}
