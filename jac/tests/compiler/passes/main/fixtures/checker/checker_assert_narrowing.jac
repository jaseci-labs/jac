"""Tests for assert isinstance type narrowing."""

obj Base {
    has name: str = "base";
}

obj Derived(Base) {
    has value: int = 0;
}

obj SubDerived(Derived) {
    has flag: bool = True;
}

# 1. Basic assert isinstance narrowing
def test_assert_isinstance(x: Base) -> None {
    assert isinstance(x, Derived);
    x.value;  # <-- Ok after narrowing (x is Derived)
}

# 2. Assert narrows to most specific subclass
def test_assert_subclass(x: Base) -> None {
    assert isinstance(x, SubDerived);
    x.flag;  # <-- Ok after narrowing (x is SubDerived)
    x.value;  # <-- Ok (SubDerived inherits from Derived)
}

# 3. Multiple asserts chain narrowing
def test_assert_chain(x: Base) -> None {
    assert isinstance(x, Derived);
    x.value;  # <-- Ok
    assert isinstance(x, SubDerived);
    x.flag;  # <-- Ok after second narrowing
}

# 4. Assert is not None narrows optional type
def test_assert_not_none(x: Derived | None) -> None {
    assert x is not None;
    x.value;  # <-- Ok after narrowing (x is Derived)
}

# 5. Assert is not None with error message
def test_assert_not_none_msg(x: Derived | None) -> None {
    assert x is not None , "x must not be None";
    x.value;  # <-- Ok after narrowing
}

# 6. Assert is not None in test block
test "assert narrowing works in test blocks" {
    x: Derived | None = Derived();
    assert x is not None;
    x.value;  # <-- Ok after narrowing in test block
}

# 7. Assert isinstance in test block
test "assert isinstance narrowing in test blocks" {
    x: Base = Derived();
    assert isinstance(x, Derived);
    x.value;  # <-- Ok after narrowing to Derived
}

# ============================================================================
# FAILURE CASES - these should produce type errors
# ============================================================================

# 8. Truthy assert does NOT narrow union types (only removes None)
test "truthy assert does not narrow union types" {
    x: Derived | str = Derived();
    x = '896';
    assert x;  # <-- This only checks truthiness, doesn't narrow Derived | str
    x.value;  # <-- ERROR: x is still str after reassignment, no .value attribute
}
