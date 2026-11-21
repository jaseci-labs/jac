"""Regression: `str()` on an owned `T | None` temp must not dangle.

`_emit_optional_str` returned the optional's raw i8* payload, but an owned
optional temp is released right after the builtin call -- the `str()` result
then aliased freed memory, and the next `_str_alloc` reused that exact chunk,
so `"p=" + str(opt_call())` printed garbage like "p=p=efined signal 1".
The payload now gets its own heap copy when the source optional is owned
(an RC retain is a no-op under nogc), and the resulting phi carries the
ownership forward so the copy is released exactly once.

The payload must be a runtime-built str so the released buffer is reusable
heap, not a static literal that masks the use-after-free.
"""

def describe(n: int) -> (str | None) {
    if n > 0 {
        return "signal " + str(n);
    }
    return None;
}

with entry {
    print("a=" + str(describe(10)));
    print("b=" + str(describe(0)));
    opt = describe(7);
    print("c=" + str(opt));
    print(str(describe(20)));
    print("d=" + str(describe(30)) + " tail");
}
