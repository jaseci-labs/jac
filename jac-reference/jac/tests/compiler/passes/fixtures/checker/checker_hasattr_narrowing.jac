"""hasattr() type narrowing fixture."""

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

def test_hasattr_basic(x: NoFoo | WithFoo) -> str {
    if hasattr(x, 'foo') {
        return x.foo;
    }
    return "default";
}

def test_hasattr_else(x: NoFoo | WithFoo) -> str {
    if hasattr(x, 'foo') {
        return x.foo;
    } else {
        return x.bar;
    }
}

def test_hasattr_early_return(x: NoFoo | WithFoo) -> str {
    if not hasattr(x, 'foo') {
        return x.bar;
    }
    return x.foo;
}

def test_hasattr_and(x: NoFoo | WithFoo | BothAttrs) -> int {
    if hasattr(x, 'foo') and hasattr(x, 'baz') {
        return x.baz;
    }
    return 0;
}

def test_hasattr_inherited(x: Child | Other) -> str {
    if hasattr(x, 'shared_attr') {
        return x.shared_attr;
    }
    return "fallback";
}

def test_hasattr_dynamic_name(x: NoFoo | WithFoo, name: str) -> bool {
    return hasattr(x, name);
}

def test_error_no_hasattr_guard(x: NoFoo | WithFoo) -> str {
    return x.foo;  # <-- Error: attribute is missing from NoFoo
}

def test_error_true_branch_wrong_attr(x: NoFoo | WithFoo) -> str {
    if hasattr(x, 'foo') {
        return x.bar;  # <-- Error: x is WithFoo here, no `bar`
    }
    return "default";
}

def test_error_else_branch_wrong_attr(x: NoFoo | WithFoo) -> str {
    if hasattr(x, 'foo') {
        return x.foo;
    } else {
        return x.foo;  # <-- Error: x is NoFoo here, no `foo`
    }
}
