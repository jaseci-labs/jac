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

def test_and_order_independent(x: Animal) -> None {
    if isinstance(x, Mammal) and isinstance(x, Animal) {
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

obj NestedContainer {
    has inner: Container;
}

def test_progressive_narrowing_chained_member(nc: NestedContainer) -> None {
    if isinstance(nc.inner.field, Mammal) and nc.inner.field.offspring {
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

def test_nested_parentheses_in_and(x: Animal, flag: bool) -> None {
    if ((isinstance(x, Primate))) and flag {
        x.is_primate;  # Ok
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

def test_isinstance_then_multiple_member_access(expr: NamedNode | ExprNode) -> str {
    if isinstance(expr, NamedNode) and expr.value and len(expr.value) > 0 {
        return expr.value;  # Ok

    }
    return "";
}

def use_string(s: str) -> str {
    return s;
}

def test_isinstance_then_method_with_member(expr: NamedNode | ExprNode) -> str {
    if isinstance(expr, NamedNode) and use_string(expr.value) {
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

obj ComplexContainer {
    has first: Animal | None = None,
        second: Animal | None = None;
}

def test_complex_multi_member_narrowing(cc: ComplexContainer) -> str {
    if cc.first is not None {
        if isinstance(cc.second, Mammal) and cc.second.offspring {
            return cc.first.name + cc.second.name;  # Ok

        }
    }
    return "";
}

def test_triple_nested_narrowing(w: Wrapper) -> str {
    if w.inner is not None {
        if isinstance(w.inner, Mammal) {
            if w.inner.offspring and len(w.inner.offspring) > 0 {
                first_offspring: Mammal = w.inner.offspring[0];
                return first_offspring.name;  # Ok

            }
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

def test_not_or_and_combined(x: Animal, y: Mammal | Primate, z: Animal) -> str {
    if not isinstance(x, Mammal)
    and (isinstance(y, Mammal) or isinstance(y, Primate))
    and isinstance(z, Primate)
    and z.is_primate {
        return x.name + y.name + z.name;  # Ok

    }
    return "";
}

def test_parallel_not_or_and(w1: Wrapper, w2: Wrapper, x: Mammal | Primate) -> str {
    r = "";
    if isinstance(w1.inner, Mammal) and w1.inner.offspring {
        r = r + w1.inner.name;
    }
    if not isinstance(x, Primate)
    and isinstance(w2.inner, Primate)
    and w2.inner.is_primate {
        r = r + x.name + w2.inner.name;
    }
    return r;
}

def test_error_after_and_block(x: Animal) -> list[Mammal] | None {
    if isinstance(x, Mammal) {
        return x.offspring;  # Ok

    }
    return x.offspring;  # Error: Animal has no attribute offspring

}
