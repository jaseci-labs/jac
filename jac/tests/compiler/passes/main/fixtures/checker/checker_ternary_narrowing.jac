"""Tests for ternary (IfElseExpr) branch narrowing in the type checker.

Pattern: `expr if optional_field else default`
The checker should narrow `optional_field` to its non-None type inside the
true branch, and exclude the non-None type in the false branch.
"""

obj Inner {
    has value: str = "x";
}

obj Outer {
    has child: Inner | None = None;
}

# -- Basic truthiness narrowing --

def use_inner(i: Inner) -> str {
    return i.value;
}

def test_attr_access_in_true_branch(o: Outer) -> str {
    # o.child is narrowed to Inner in true branch: no E1099
    return o.child.value if o.child else "default";
}

def test_call_in_true_branch(o: Outer) -> str {
    # o.child narrowed to Inner — can be passed to use_inner: no E1053
    return use_inner(o.child) if o.child else "default";
}

def test_none_in_false_branch(o: Outer) -> Inner | None {
    # false branch: o.child is None (or at least could be None, return None ok)
    return None if o.child else o.child;
}

# -- Chained member ternary --

obj Middle {
    has leaf: Inner | None = None;
}

obj Root {
    has mid: Middle | None = None;
}

def test_nested_ternary(r: Root) -> str {
    # r.mid narrowed to Middle in outer true branch: no E1099
    mid_val = r.mid.leaf.value if r.mid and r.mid.leaf else "none";
    return mid_val;
}

# -- Multiple ternaries in same expression --

def test_two_ternaries(a: Outer, b: Outer) -> str {
    x = a.child.value if a.child else "a_default";
    y = b.child.value if b.child else "b_default";
    return x + y;
}

# -- Error cases (expected errors, kept for negative testing) --

def test_unconditional_access_errors(o: Outer) -> str {
    return o.child.value;  # Error: E1099 — Inner | None missing value on NoneType
}
