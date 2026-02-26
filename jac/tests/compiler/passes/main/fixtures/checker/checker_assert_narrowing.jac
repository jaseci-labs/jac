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
