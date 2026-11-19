"""Builtin-call inference regressions surfaced by the this_is_jac showcase QA.

1. `round()`: typeshed declares it against the PRIVATE generic protocols
   `_SupportsRound1`/`_SupportsRound2` (not the public `SupportsRound`), so
   the evaluator's structural-protocol table must know those names too, or
   every `round(...)` call fails E1054. Python semantics pinned: one-arg
   rounds to int, two-arg float keeps float.

2. `{**spread}` dict literals: the spread must contribute the SPREAD DICT'S
   OWN key/value types to the literal's inference, not fold the whole dict
   in as one entry value (`{**collapsed}` inferred
   `dict[<Unknown>, dict[str, bool]]` in the SourceViewer).
"""

def rounds(x: float, i: int) {
    a: int = round(x);
    b: float = round(x, 1);
    c: int = round(i);
    d: str = str(round(x, 2)) + " avg fps";
}

def clone_toggle(c: dict[str, bool], k: str) -> dict[str, bool] {
    nc = {** c};
    nc[k] = not c.get(k, False);
    return nc;
}

def combine(a: dict[str, int], b: dict[str, int]) -> dict[str, int] {
    return {** a, ** b, "extra": 1};
}

def divmod_quot(a: int, b: int) -> int {
    return divmod(a, b)[0];
}

def divmod_rem(a: int, b: int) -> int {
    return divmod(a, b)[1];
}

# 3. `max`/`min` of numbers: ints give an int and a mix of ints and floats a
#    float. typeshed's one type variable bound to the first argument and
#    refused `max(0, w - 3)`; `builtin_overrides.pyi` adds the numeric overloads.
def extremes(w: float, xs: list[int], names: list[str]) -> float {
    a: float = max(0, w - 3);
    b: float = min(40.0, max(40, w + 1));
    c: int = max(1, 2, 3);
    d: int = max(xs);
    e: str = min(names, key=lambda (s: str) -> int { len(s) });
    g: int = max([], default=0);
    return a + b + c + d + g + len(e);
}

# 4. `flow f(...)` is a `Task[T]`, which a field can hold, and `wait` on it is a `T`.
obj Pending {
    has task: Task[int],
        n: int = 0;
}

def doubled(n: int) -> int {
    return n * 2;
}

def tasks -> int {
    p = Pending(task=flow doubled(2));
    v: int = wait p.task;
    s = flow str(v);
    w: str = wait s;
    return v + len(w);
}
