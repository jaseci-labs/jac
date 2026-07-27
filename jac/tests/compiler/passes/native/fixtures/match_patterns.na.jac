"""Native fixture exercising structural match patterns.

Covers sequence patterns (fixed length, length dispatch, star head/tail/mid),
mapping patterns (key probe, missing key fall-through, **rest collection),
class patterns (keyword, positional, subclass dispatch via vtable), nested
sequence recursion, and guard interplay after structural binding.

Every expected value is pinned against real CPython `match` semantics.
Match captures type as Unknown in the checker, so captures are cast
(`(x as int)`) per the match_stmt.na.jac precedent; lists are built at
runtime via append loops so lengths are not compile-time constants.
"""

obj Point {
    has x: int,
        y: int;
}

obj Base {
    has tag: int;
}

obj Sub(Base) {
    has extra: int;
}

def seq_fixed(a: int, b: int) -> int {
    xs: list[int] = [a, b];
    match xs {
        case [1, 2]: return 1;
        case [x, y]: return (x as int) + (y as int);
        case _: return 0;
    }
}

def seq_lengths(n: int) -> int {
    xs: list[int] = [];
    for i in range(n) {
        xs.append(i);
    }
    match xs {
        case []: return 0;
        case [a]: return 1;
        case [a, b]: return 2;
        case _: return -1;
    }
}

def seq_star_head(n: int) -> int {
    xs: list[int] = [];
    for i in range(n) {
        xs.append(i + 10);
    }
    match xs {
        case [first, *rest]: return (first as int) * 100 + len((rest as list[int]));
        case _: return -1;
    }
}

def seq_star_tail(n: int) -> int {
    xs: list[int] = [];
    for i in range(n) {
        xs.append(i + 10);
    }
    match xs {
        case [*front, last]: return (last as int) * 100 + len(
            (front as list[int])
        );
        case _: return -1;
    }
}

def seq_star_mid(n: int) -> int {
    xs: list[int] = [];
    for i in range(n) {
        xs.append(i + 10);
    }
    match xs {
        case [first, *mid, last]: return (first as int) + (last as int) * 100 + len(
            (mid as list[int])
        );
        case _: return -1;
    }
}

def map_probe(k: int) -> int {
    d: dict[str, int] = {"a": 1, "b": 2};
    match d {
        case {"a": v} if k == 0: return (v as int);
        case {"a": v, "b": w}: return (v as int) + (w as int);
        case _: return -1;
    }
}

def map_missing() -> int {
    d: dict[str, int] = {"a": 1, "b": 2};
    match d {
        case {"z": v}: return 1;
        case _: return -1;
    }
}

def map_rest() -> int {
    d: dict[str, int] = {"a": 1, "b": 2, "c": 3};
    match d {
        case {"a": v, **rest}: return (v as int) * 100 + len(
            (rest as dict[str, int])
        );
        case _: return -1;
    }
}

def arch_kw(px: int, py2: int) -> int {
    p = Point(x=px, y=py2);
    match p {
        case Point(x=a, y=b): return (a as int) * 10 + (b as int);
        case _: return -1;
    }
}

def arch_pos(px: int, py2: int) -> int {
    p = Point(x=px, y=py2);
    match p {
        case Point(a, b): return (a as int) * 10 + (b as int);
        case _: return -1;
    }
}

def arch_subtype(sel: int) -> int {
    o: Base = Base(tag=7);
    if sel == 1 {
        o = Sub(tag=7, extra=9);
    }
    match o {
        case Sub(extra=e): return (e as int);
        case Base(tag=t): return (t as int);
        case _: return -1;
    }
}

def nested_seq() -> int {
    xss: list[list[int]] = [[1, 2], [3]];
    match xss {
        case [[a, b], [c]]: return (a as int) + (b as int) + (c as int);
        case _: return -1;
    }
}

def nested_seq_miss() -> int {
    xss: list[list[int]] = [[1, 2], [3, 4]];
    match xss {
        case [[a, b], [c]]: return (a as int) + (b as int) + (c as int);
        case _: return -1;
    }
}

def seq_guard(a: int, b: int) -> int {
    xs: list[int] = [a, b];
    match xs {
        case [x, y] if (x as int) > (y as int): return 1;
        case [x, y]: return 2;
        case _: return 3;
    }
}
