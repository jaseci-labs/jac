"""Minimal reproduction for prefix-chain narrowing.

When the condition/guard is a dotted chain like `obj.collection`, and
the NoneType is on the prefix `obj` (not `obj.collection` itself),
the checker should narrow `obj` to non-None in guarded contexts.

Three patterns to cover:
  1. Ternary prefix  — `[x for x in obj.items] if obj.items else []`
  2. AND if-guard    — `if obj and obj.items { use(obj.items) }`
  3. Early-return    — `if not obj.items: return; use(obj.items)`
"""

obj Inner {
    has items: list[str] = [];
}

obj Outer {
    has child: Inner | None = None;
}

def use_list(lst: list[str]) -> str {
    return lst[0] if lst else "";
}

# ---- Pattern 1: ternary with prefix-chain condition ----

def test_ternary_prefix(o: Outer) -> list[str] {
    # `o.child.items` truthy implies `o.child` is non-None.
    # Checker should NOT report E1099 on `o.child.items` in the true branch.
    return [x for x in o.child.items] if o.child.items else [];
}

# ---- Pattern 2: AND guard in if-statement ----

def test_and_guard_full(o: Outer) -> str {
    # `o.child and o.child.items` — first operand narrows o.child to Inner.
    # Checker should NOT report E1099 on `o.child.items` inside the body.
    if o.child and o.child.items {
        return use_list(o.child.items);
    }
    return "";
}

def test_and_guard_items_only(o: Outer) -> str {
    # `o.child.items` alone as condition implies `o.child` is non-None.
    # Checker should NOT report E1099 on `o.child.items` inside the body.
    if o.child.items {
        return use_list(o.child.items);
    }
    return "";
}

# ---- Intentional errors (keep at end, count must match test assertion) ----

def test_unconditional_error(o: Outer) -> list[str] {
    return [x for x in o.child.items];  # Error: E1099 - NoneType has no items
}
