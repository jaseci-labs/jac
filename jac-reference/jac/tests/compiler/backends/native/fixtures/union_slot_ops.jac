"""Read, compare and select over a union-typed slot.

A union whose members do not share one lowering is stored boxed: a tagged
`jacval` carrying the member tag beside the payload. Three expression forms
have to work over that slot, and all three have a silent failure mode that
"did it compile?" cannot see.

`v is None` / `v is not None` is a tag comparison against the none tag, not
a null-pointer test: the payload of an `int` member is a perfectly ordinary
zero and a null test would call it None.

`if v` is truthiness, which is not the same question as "is the slot set".
`0`, `""` and `[]` are all present and all falsy, so a none-tag test
standing in for truthiness answers three of these six cases wrong.

`a if cond else b` selects between two slots that may not share a lowering,
and the arm shapes that matter are `T | None` (an option against a bare
`None`) and two distinct class pointers. A select that drops the payload
still produces a well-typed value, so every function here reads the payload
back out -- a field off the object, the member value, or the negated length
of a container -- rather than only asking whether the slot survived.

An all-pointer union (`Alpha | Beta | None`) keeps the first member's
pointer layout instead of boxing, so it exercises the same three forms
against the other storage the rule can pick.
"""

obj Alpha {
    has a: int = 0;
}


obj Beta {
    has b: int = 0;
}


obj Sub(Alpha) {
    has s: int = 0;
}


"""Build a boxed union: 0 -> int member, 1 -> str member, else None."""
def mk_scalar_union(flag: int) -> int | str | None {
    if flag == 0 {
        return 7;
    }
    if flag == 1 {
        return "abcd";
    }
    return None;
}


"""Read the payload back: the int as itself, the str as its negated length."""
def probe_scalar(v: int | str | None) -> int {
    if v is None {
        return -1;
    }
    if isinstance(v, int) {
        return v;
    }
    return 0 - len(v);
}


"""`is None` over a boxed union local, both when set and when None."""
def is_none_union(flag: int) -> int {
    v = mk_scalar_union(flag);
    if v is None {
        return 1;
    }
    return 0;
}


"""`is not None` over a boxed union local, reading the payload on the some arm."""
def is_not_none_union(flag: int) -> int {
    v = mk_scalar_union(flag);
    if v is not None {
        return probe_scalar(v);
    }
    return -9;
}


"""Every member of a boxed union, including the falsy ones."""
def mk_truthy(flag: int) -> int | str | list[int] | None {
    if flag == 0 {
        return 5;
    }
    if flag == 1 {
        return 0;
    }
    if flag == 2 {
        return "hi";
    }
    if flag == 3 {
        return "";
    }
    if flag == 4 {
        return [1, 2];
    }
    if flag == 5 {
        return [];
    }
    return None;
}


"""A bare read of a boxed union local in condition position."""
def truthy_union(flag: int) -> int {
    v = mk_truthy(flag);
    if v {
        return 1;
    }
    return 0;
}


"""`not` over the same boxed read, which routes through the same truth test."""
def not_truthy_union(flag: int) -> int {
    v = mk_truthy(flag);
    if not v {
        return 1;
    }
    return 0;
}


"""A ternary whose value is `T | None`; the field read proves the payload."""
def opt_ternary(flag: int) -> int {
    made = Alpha(a=42);
    r: Alpha | None = made if flag > 0 else None;
    if r is None {
        return -1;
    }
    return r.a;
}


"""A ternary over two distinct class pointers; each arm's field is read back."""
def cls_ternary(flag: int) -> int {
    r: Alpha | Beta = Alpha(a=3) if flag > 0 else Beta(b=9);
    if isinstance(r, Alpha) {
        return r.a;
    }
    return r.b;
}


"""A ternary whose arms are a boxed union and a bare `None`."""
def union_opt_ternary(flag: int) -> int {
    v: int | str | None = mk_scalar_union(flag) if flag < 2 else None;
    return probe_scalar(v);
}


"""The all-pointer union: same three forms against an unboxed slot."""
def multi_cls_none(flag: int) -> int {
    r: Alpha | Beta | None = None;
    if flag == 1 {
        r = Alpha(a=11);
    }
    if flag == 2 {
        r = Beta(b=22);
    }
    if r is None {
        return -1;
    }
    if isinstance(r, Alpha) {
        return r.a;
    }
    return r.b;
}


"""An option-valued source, the shape a parse method hands back."""
def src_opt(flag: int) -> Alpha | None {
    if flag == 1 {
        return Sub(a=4, s=17);
    }
    if flag == 2 {
        return Alpha(a=5);
    }
    return None;
}


"""`x if isinstance(x, T) else None`: an option arm against a bare `None`.

The narrowed arm and the `None` arm do not share a lowering, so the select
unifies them and the result is then coerced back to the declared option.
Both edges of that round trip can drop the payload silently.
"""
def narrow_ternary(flag: int) -> Sub | None {
    d = src_opt(flag);
    return d if isinstance(d, Sub) else None;
}


"""Read the field the narrowing promised, off the far side of the select."""
def use_narrow_ternary(flag: int) -> int {
    r = narrow_ternary(flag);
    if r is None {
        return -1;
    }
    return r.s;
}


"""An option flows through a plain return with no select in the way."""
def pass_through_opt(flag: int) -> int {
    d = src_opt(flag);
    if d is None {
        return -1;
    }
    return d.a;
}


"""A bool local joined from an option none-test and an ordinary compare.

The two operands of the `or` do not share a lowering (an option's none-test
and an integer compare are different widths), so the join itself lands in a
boxed slot and the `if` below is a bare read of it.
"""
def bool_join(flag: int) -> int {
    o = src_opt(flag);
    lst: list[int] = [1, 2] if flag > 1 else [];
    joined = (len(lst) > 0 and not isinstance(o, Sub)) or o is not None;
    if joined {
        return 1;
    }
    return 0;
}


"""Truthiness of the all-pointer union local in condition position."""
def multi_cls_truthy(flag: int) -> int {
    r: Alpha | Beta | None = None;
    if flag == 1 {
        r = Alpha(a=11);
    }
    if flag == 2 {
        r = Beta(b=22);
    }
    if r {
        return 1;
    }
    return 0;
}
