"""Tests for hasattr() type narrowing in the type checker.

hasattr(x, "name") should narrow a union type to only its members that
declare the attribute, in the true branch; and to members without the
attribute in the false branch. The attribute name must be a string literal
for narrowing to apply -- dynamic names produce no narrowing (and no error).
"""

obj NoFoo {
    has bar: str = "bar";
}

obj WithFoo {
    has foo: str = "foo";
}

obj BothAttrs {
    has foo: str = "foo",
        baz: int = 0;
}

obj Parent {
    has shared_attr: str = "p";
}

obj Child(Parent) {
    has extra: int = 0;
}

obj Other {
    has nope: str = "n";
}

# 1. Basic hasattr narrowing: true branch keeps members with the attr.
def test_hasattr_basic(x: NoFoo | WithFoo) -> str {
    if hasattr(x, 'foo') {
        return x.foo;
    }
    return "default";
}

# 2. Else branch: members without the attr remain.
def test_hasattr_else(x: NoFoo | WithFoo) -> str {
    if hasattr(x, 'foo') {
        return x.foo;
    } else {
        return x.bar;
    }
}

# 3. Early return promotes narrowing on fall-through.
def test_hasattr_early_return(x: NoFoo | WithFoo) -> str {
    if not hasattr(x, 'foo') {
        return x.bar;
    }
    return x.foo;
}

# 4. AND of two hasattr checks intersects the filters.
def test_hasattr_and(x: NoFoo | WithFoo | BothAttrs) -> int {
    if hasattr(x, 'foo') and hasattr(x, 'baz') {
        return x.baz;
    }
    return 0;
}

# 5. Inherited attribute survives the filter (MRO walk).
def test_hasattr_inherited(x: Child | Other) -> str {
    if hasattr(x, 'shared_attr') {
        return x.shared_attr;
    }
    return "fallback";
}

# 6. Dynamic attribute name: no narrowing, no crash, no false error.
def test_hasattr_dynamic_name(x: NoFoo | WithFoo, name: str) -> bool {
    return hasattr(x, name);
}

# === Error cases: these SHOULD produce type errors ===

# E1. Without hasattr guard, union access is rejected.
def test_error_no_hasattr_guard(x: NoFoo | WithFoo) -> str {
    return x.foo;  # <-- Error: attribute is missing from NoFoo
}

# E2. Inside true branch, the excluded variant is gone; accessing its
#     attribute is an error.
def test_error_true_branch_wrong_attr(x: NoFoo | WithFoo) -> str {
    if hasattr(x, 'foo') {
        return x.bar;  # <-- Error: x is WithFoo here, no `bar`
    }
    return "default";
}

# E3. Inside else branch, the kept variant is the one without the attr;
#     accessing the guarded attribute is an error.
def test_error_else_branch_wrong_attr(x: NoFoo | WithFoo) -> str {
    if hasattr(x, 'foo') {
        return x.foo;
    } else {
        return x.foo;  # <-- Error: x is NoFoo here, no `foo`
    }
}
