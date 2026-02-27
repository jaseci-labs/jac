"""Tests for compound AND narrowing in the type checker."""

obj Animal {
    has name: str = "animal";
}

obj Mammal(Animal) {
    has offspring: list[Mammal] | None = None;
}

obj Primate(Mammal) {
    has is_primate: bool = True;
}

def test_and_most_specific(x: Animal) -> None {
    if isinstance(x, Animal) and isinstance(x, Mammal) {
        x.offspring;  # Ok
    }
}

def test_and_with_not_isinstance(x: Animal) -> None {
    if isinstance(x, Mammal) and not isinstance(x, Primate) {
        x.offspring;  # Ok
    }
}

def test_and_three_types(x: Animal) -> None {
    if isinstance(x, Animal) and isinstance(x, Mammal) and isinstance(x, Primate) {
        x.is_primate;  # Ok
    }
}

def test_and_with_flag(x: Animal, flag: bool) -> None {
    if isinstance(x, Mammal) and flag {
        x.offspring;  # Ok
    }
}

def test_progressive_narrowing_method(x: Animal) -> None {
    if isinstance(x, Mammal) and x.offspring {
        return;  # Ok

    }
}

def test_progressive_narrowing_multi(x: Animal) -> None {
    if isinstance(x, Animal)
    and isinstance(x, Mammal)
    and isinstance(x, Primate)
    and x.is_primate {
        return;  # Ok

    }
}

obj Container {
    has field: Animal;
}

def test_progressive_narrowing_member_access(c: Container) -> None {
    if isinstance(c.field, Mammal) and c.field.offspring {
        return;  # Ok

    }
}

obj Dog(Animal) {
    has bark_count: int = 0;
}

obj Cat(Animal) {
    has meow_count: int = 0;
}

def use_dog_or_cat(x: Dog | Cat) -> str {
    return x.name;
}

def test_tuple_isinstance_in_and(x: Animal, flag: bool) -> str {
    if isinstance(x, (Dog, Cat)) and flag {
        return use_dog_or_cat(x);  # Ok

    }
    return "";
}

def use_mammal(m: Mammal) -> str {
    return m.name;
}

def test_is_not_none_in_and(x: Mammal | None, flag: bool) -> str {
    if x is not None and flag {
        return use_mammal(x);  # Ok

    }
    return "";
}

obj MaybeContainer {
    has field: Mammal | None = None;
}

def test_member_is_not_none_in_and(c: MaybeContainer, flag: bool) -> str {
    if c.field is not None and flag {
        return use_mammal(c.field);  # Ok

    }
    return "";
}

def test_parenthesized_isinstance_in_and(x: Animal, flag: bool) -> None {
    if (isinstance(x, Mammal)) and flag {
        x.offspring;  # Ok
    }
}

def use_none(n: None) -> str {
    return "none";
}

def test_is_none_narrowing(x: Mammal | None) -> str {
    if x is None {
        return use_none(x);  # Ok

    }
    return x.name;  # Ok

}

def test_is_none_in_and(x: Mammal | None, flag: bool) -> str {
    if x is None and flag {
        return use_none(x);  # Ok

    }
    return "";
}

obj NamedNode {
    has value: str = "";
}

obj ExprNode {
    has left: NamedNode | None = None;
}

def test_isinstance_then_member_access(expr: NamedNode | ExprNode) -> str {
    if isinstance(expr, NamedNode) and expr.value {
        return expr.value;  # Ok

    }
    return "";
}

obj Wrapper {
    has inner: Animal | None = None;
}

def test_nested_isinstance_member_narrowing(w: Wrapper) -> str {
    if isinstance(w.inner, Mammal) {
        if w.inner.offspring and len(w.inner.offspring) > 0 {
            return w.inner.name;  # Ok

        }
    }
    return "";
}

obj DeepWrapper {
    has data: Wrapper | None = None;
}

def test_deep_nested_narrowing(dw: DeepWrapper) -> str {
    if dw.data is not None {
        if isinstance(dw.data.inner, Mammal) and dw.data.inner.offspring {
            return dw.data.inner.name;  # Ok

        }
    }
    return "";
}

obj DualWrapper {
    has left: Animal | None = None,
        right: Animal | None = None;
}

def test_and_chain_multiple_members(dw: DualWrapper) -> str {
    if isinstance(dw.left, Mammal)
    and isinstance(dw.right, Primate)
    and dw.left.offspring
    and dw.right.is_primate {
        return dw.left.name + dw.right.name;  # Ok

    }
    return "";
}

def test_error_after_and_block(x: Animal) -> list[Mammal] | None {
    if isinstance(x, Mammal) {
        return x.offspring;  # Ok

    }
    return x.offspring;  # Error: Animal has no attribute offspring

}
