"""Tests for unified ConditionalNode narrowing (IfStmt + CfgExpr via sc_true_target).

IfStmt now carries sc_true_target/sc_false_target (set by exit_if_stmt), so
the narrowing walker can use the same fast identity-check path for both ternary
(CfgExpr) and if-statement (IfStmt) predecessors.
"""

obj Inner {
    has value: str = "x";
}

obj Outer {
    has child: Inner | None = None;
}

def use_inner(i: Inner) -> str {
    return i.value;
}

# -- IfStmt sc_true_target narrowing --

def test_if_attr_access(o: Outer) -> str {
    # o.child narrowed to Inner via IfStmt sc_true_target: no E1099
    if o.child {
        return o.child.value;
    }
    return "none";
}

def test_if_call(o: Outer) -> str {
    # o.child narrowed to Inner — can be passed to use_inner: no E1053
    if o.child {
        return use_inner(o.child);
    }
    return "none";
}

def test_if_else_narrowing(o: Outer) -> Inner | None {
    # true branch: Inner; false branch: None (ok, return type allows None)
    if o.child {
        return o.child;
    } else {
        return o.child;
    }
}

# -- IfStmt sc_false_target narrowing --

def test_else_branch_narrowing(o: Outer) -> str {
    # false branch: o.child must be None; use None literal is fine
    if o.child {
        return o.child.value;
    } else {
        return "was_none";
    }
}

# -- Error case (expected errors, kept for negative testing) --

def test_unconditional_access(o: Outer) -> str {
    return o.child.value;  # Error: E1099 - Inner | None missing value on NoneType
}
