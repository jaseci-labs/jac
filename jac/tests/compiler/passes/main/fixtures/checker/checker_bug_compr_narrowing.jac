"""Fixture: `T | None` narrowing must propagate into comprehension iterators.

After `if r is None { return ...; }`, `r` is narrowed to `T` in the function body.
Pyright and mypy propagate that narrowing into every sub-expression of a
comprehension (out_expr, the iterator collection, and the conditional).
Jac previously dropped the narrowing as soon as the lookup walked into an
`InnerCompr` — an orphan UniCFGNode that is not wired into the CFG —
producing E1099 false positives on attribute access inside the comprehension.

After the fix, every attribute access below must type-check.
"""

obj R {
    has parts: list[str] = [];
}

# Iterator collection: `r.parts` inside `range(len(...))`.
def use_iter(r: R | None) -> list[str] {
    if r is None { return []; }
    return [str(i) for i in range(len(r.parts))];
}

# Out expression: `r.parts[i]` as the comprehension output.
def use_out(r: R | None) -> list[str] {
    if r is None { return []; }
    return [r.parts[i] for i in range(5)];
}

# Conditional clause: narrowed `r` referenced in `if` filter.
def use_cond(r: R | None) -> list[str] {
    if r is None { return []; }
    return [p for p in ["a", "b", "c"] if p in r.parts];
}

# Combined: all three positions in the same comprehension.
def use_all(r: R | None) -> list[str] {
    if r is None { return []; }
    return [r.parts[i] for i in range(len(r.parts)) if r.parts[i] != ""];
}

# Dict comprehension: narrowing propagates into kv_pair, iterator, and condition.
def use_dict(r: R | None) -> dict[int, str] {
    if r is None { return {}; }
    return {i: r.parts[i] for i in range(len(r.parts)) if r.parts[i] != ""};
}

# Set comprehension.
def use_set(r: R | None) -> set[str] {
    if r is None { return set(); }
    return {r.parts[i] for i in range(len(r.parts))};
}

# Generator comprehension.
def use_gen(r: R | None) -> list[str] {
    if r is None { return []; }
    return list(r.parts[i] for i in range(len(r.parts)));
}
