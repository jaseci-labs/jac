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

def rounds(x: float, i: int) -> None {
    a: int = round(x);
    b: float = round(x, 1);
    c: int = round(i);
    d: str = str(round(x, 2)) + " avg fps";
}

def clone_toggle(c: dict[str, bool], k: str) -> dict[str, bool] {
    nc = {**c};
    nc[k] = not c.get(k, False);
    return nc;
}

def combine(a: dict[str, int], b: dict[str, int]) -> dict[str, int] {
    return {**a, **b, "extra": 1};
}
