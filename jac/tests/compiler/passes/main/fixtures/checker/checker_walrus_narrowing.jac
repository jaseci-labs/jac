"""Test walrus operator (:=) type narrowing.

When a walrus operator is used with an `is not None` check,
the type should be narrowed inside the if block.
"""

def get_optional_int() -> int | None {
    return 42;
}

def get_optional_str() -> str | None {
    return "hello";
}

# Test 1: Basic walrus narrowing with is not None
def test_walrus_is_not_none() -> int {
    if (x := get_optional_int()) is not None {
        # x should be narrowed to int here
        return x;  # Should NOT error
    }
    return 0;
}

# Test 2: Walrus narrowing in compound condition
def test_walrus_compound_condition(flag: bool) -> int {
    if flag and ((x := get_optional_int()) is not None) {
        # x should be narrowed to int here
        return x;  # Should NOT error
    }
    return 0;
}

# Test 3: Walrus narrowing with function that returns union with None
obj Result {
    has value: int;
}

def get_optional_result() -> Result | None {
    return Result(value=10);
}

def test_walrus_object_narrowing() -> int {
    if (result := get_optional_result()) is not None {
        # result should be narrowed to Result here
        return result.value;  # Should NOT error
    }
    return 0;
}

# Test 4: Nested walrus narrowing
def test_nested_walrus() -> int {
    if (outer := get_optional_int()) is not None {
        if (inner := get_optional_int()) is not None {
            return outer + inner;  # Should NOT error
        }
    }
    return 0;
}

# Test 5: Walrus with isinstance narrowing (two-step)
def test_walrus_isinstance() -> str {
    val: int | str | None = "test";
    if (x := val) is not None and isinstance(x, str) {
        # x should be narrowed to str here
        return x.upper();  # Should NOT error
    }
    return "";
}

# Test 6: isinstance with walrus inside - isinstance((x := expr), Type)
obj Anchor {
    has access: int = 0;
}

def get_optional_anchor() -> Anchor | None {
    return Anchor();
}

def test_isinstance_walrus() -> int {
    if isinstance((anchor := get_optional_anchor()), Anchor) {
        # anchor should be narrowed to Anchor here, not Anchor | None
        return anchor.access;  # Should NOT error
    }
    return -1;
}

# Test 7: isinstance walrus in compound condition
def test_isinstance_walrus_compound(flag: bool) -> int {
    if flag and isinstance((anchor := get_optional_anchor()), Anchor) {
        return anchor.access;  # Should NOT error
    }
    return -1;
}
