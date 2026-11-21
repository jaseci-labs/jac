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

# In-body narrowing: `if r is not None { ... }` narrows `r` to `R` *inside
# the block*. The comprehension is wired to the if-stmt as a synthetic flow
# predecessor; that edge must be classified as the true branch so the head
# expression sees the narrowed type. The narrowing was previously dropped on
# the comprehension's false-branch misclassification (no else present),
# narrowing `r` to `None` and yielding `list[NoneType]` E1001 false positives.
def use_in_body_list(r: R | None) -> list[list[str]] {
    if r is not None {
        return [r.parts for _ in range(3)];
    }
    return [];
}

def use_in_body_set(r: R | None) -> set[int] {
    if r is not None {
        return {len(r.parts) for _ in range(3)};
    }
    return set();
}

def use_in_body_dict(r: R | None) -> dict[int, list[str]] {
    if r is not None {
        return {i: r.parts for i in range(3)};
    }
    return {};
}

# In-body narrowing inside the else branch: `if r is None {} else { ... }`
# narrows `r` to `R` in the else body, reached via the false edge.
def use_in_else(r: R | None) -> list[list[str]] {
    result: list[list[str]] = [];
    if r is None {
        result = [];
    } else {
        result = [r.parts for _ in range(3)];
    }
    return result;
}
