"""Tests for compound AND narrowing in the type checker.

When multiple isinstance checks on the SAME variable are combined with AND,
the type should be narrowed to the most specific (intersection) type.
"""

obj Animal {
    has name: str = "animal";
}

obj Mammal(Animal) {
    has offspring: list[Mammal] | None = None;
}

obj Primate(Mammal) {
    has is_primate: bool = True;
}

# 1. Multiple isinstance checks - most specific wins
def test_and_most_specific(x: Animal) -> None {
    if isinstance(x, Animal) and isinstance(x, Mammal) {
        # x should be Mammal here (most specific)
        x.offspring;  # <-- Ok after narrowing (Mammal has offspring)
    }
}

# 2. Order doesn't matter - most specific wins
def test_and_order_independent(x: Animal) -> None {
    if isinstance(x, Mammal) and isinstance(x, Animal) {
        # x should be Mammal here (most specific)
        x.offspring;  # <-- Ok after narrowing
    }
}

# 3. With negative isinstance - positive wins for narrowing
def test_and_with_not_isinstance(x: Animal) -> None {
    if isinstance(x, Mammal) and not isinstance(x, Primate) {
        # x should be Mammal here (Primate excluded but Mammal is the narrowed type)
        x.offspring;  # <-- Ok after narrowing
    }
}

# 4. Three-way inheritance narrowing
def test_and_three_types(x: Animal) -> None {
    if isinstance(x, Animal) and isinstance(x, Mammal) and isinstance(x, Primate) {
        # x should be Primate here (most specific)
        x.is_primate;  # <-- Ok after narrowing (Primate has is_primate)
    }
}

# 5. Mixed with other conditions
def test_and_with_flag(x: Animal, flag: bool) -> None {
    if isinstance(x, Mammal) and flag {
        # x should be Mammal here
        x.offspring;  # <-- Ok after narrowing
    }
}

# 6. Progressive narrowing - method call AFTER isinstance in same AND
def test_progressive_narrowing_method(x: Animal) -> None {
    if isinstance(x, Mammal) and x.offspring {
        # x.offspring sees x as Mammal due to preceding isinstance
        return;  # Ok

    }
}

# 7. Progressive narrowing - multiple isinstance then method
def test_progressive_narrowing_multi(x: Animal) -> None {
    if isinstance(x, Animal)
    and isinstance(x, Mammal)
    and isinstance(x, Primate)
    and x.is_primate {
        # x.is_primate sees x as Primate (most specific)
        return;  # Ok

    }
}

# 8. Progressive narrowing with member access
obj Container {
    has field: Animal;
}

def test_progressive_narrowing_member_access(c: Container) -> None {
    if isinstance(c.field, Mammal) and c.field.offspring {
        # c.field is narrowed to Mammal due to preceding isinstance
        return;  # Ok

    }
}

# 9. Progressive narrowing with chained member access
obj NestedContainer {
    has inner: Container;
}

def test_progressive_narrowing_chained_member(nc: NestedContainer) -> None {
    if isinstance(nc.inner.field, Mammal) and nc.inner.field.offspring {
        # nc.inner.field is narrowed to Mammal
        return;  # Ok

    }
}

# 10. Tuple isinstance in AND expression: isinstance(x, (A, B)) → A | B
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
        # x narrowed to Dog | Cat
        return use_dog_or_cat(x);  # <-- Ok, x is Dog | Cat

    }
    return "";
}

# 11. `x is not None` in AND expression
def use_mammal(m: Mammal) -> str {
    return m.name;
}

def test_is_not_none_in_and(x: Mammal | None, flag: bool) -> str {
    if x is not None and flag {
        # x narrowed from Mammal | None to Mammal
        return use_mammal(x);  # <-- Ok, x is Mammal

    }
    return "";
}

# 12. `x.field is not None` in AND expression
obj MaybeContainer {
    has field: Mammal | None = None;
}

def test_member_is_not_none_in_and(c: MaybeContainer, flag: bool) -> str {
    if c.field is not None and flag {
        # c.field narrowed from Mammal | None to Mammal
        return use_mammal(c.field);  # <-- Ok, c.field is Mammal

    }
    return "";
}

# 13. Parenthesized isinstance in AND expression
def test_parenthesized_isinstance_in_and(x: Animal, flag: bool) -> None {
    if (isinstance(x, Mammal)) and flag {
        # Parentheses are unwrapped, x narrowed to Mammal
        x.offspring;  # <-- Ok, x is Mammal
    }
}

# 14. Nested parentheses in AND expression
def test_nested_parentheses_in_and(x: Animal, flag: bool) -> None {
    if ((isinstance(x, Primate))) and flag {
        # Multiple parentheses unwrapped, x narrowed to Primate
        x.is_primate;  # <-- Ok, x is Primate
    }
}

# 15. `x is None` narrowing (narrows to NoneType)
def use_none(n: None) -> str {
    return "none";
}

def test_is_none_narrowing(x: Mammal | None) -> str {
    if x is None {
        # x narrowed from Mammal | None to None
        return use_none(x);  # <-- Ok, x is None

    }
    return x.name;  # <-- Ok, x is Mammal (None excluded in else branch via CFG)

}

# 16. `x is None` in AND expression
def test_is_none_in_and(x: Mammal | None, flag: bool) -> str {
    if x is None and flag {
        # x narrowed to None
        return use_none(x);  # <-- Ok, x is None

    }
    return "";
}

# 17. isinstance(expr, Type) and expr.member - simple Name narrowing in AND
#     This tests that after isinstance(expr, T), expr is narrowed when accessing expr.member
obj NamedNode {
    has value: str = "";
}

obj ExprNode {
    has left: NamedNode | None = None;
}

def test_isinstance_then_member_access(expr: NamedNode | ExprNode) -> str {
    if isinstance(expr, NamedNode) and expr.value {
        # expr narrowed to NamedNode, so expr.value is valid
        return expr.value;  # <-- Ok, expr is NamedNode

    }
    return "";
}

# 18. Multiple member accesses after isinstance in same AND
def test_isinstance_then_multiple_member_access(expr: NamedNode | ExprNode) -> str {
    if isinstance(expr, NamedNode) and expr.value and len(expr.value) > 0 {
        # expr narrowed to NamedNode for both expr.value accesses
        return expr.value;  # <-- Ok, expr is NamedNode

    }
    return "";
}

# 19. isinstance then method call with member access argument
def use_string(s: str) -> str {
    return s;
}

def test_isinstance_then_method_with_member(expr: NamedNode | ExprNode) -> str {
    if isinstance(expr, NamedNode) and use_string(expr.value) {
        # expr narrowed to NamedNode when passing expr.value as argument
        return expr.value;  # <-- Ok, expr is NamedNode

    }
    return "";
}

# 20. Nested isinstance: outer if + inner AND with member access narrowing
obj Wrapper {
    has inner: Animal | None = None;
}

def test_nested_isinstance_member_narrowing(w: Wrapper) -> str {
    if isinstance(w.inner, Mammal) {
        # w.inner narrowed to Mammal by outer if (CFG-based)
        if w.inner.offspring and len(w.inner.offspring) > 0 {
            # w.inner still Mammal, offspring access valid
            return w.inner.name;  # <-- Ok

        }
    }
    return "";
}

# 21. Outer if narrows base, inner AND narrows member's member
obj DeepWrapper {
    has data: Wrapper | None = None;
}

def test_deep_nested_narrowing(dw: DeepWrapper) -> str {
    if dw.data is not None {
        # dw.data narrowed to Wrapper (CFG-based)
        if isinstance(dw.data.inner, Mammal) and dw.data.inner.offspring {
            # dw.data.inner narrowed to Mammal (scope-based in AND)
            return dw.data.inner.name;  # <-- Ok

        }
    }
    return "";
}

# 22. Combined: outer isinstance + inner isinstance on different member + AND access
obj ComplexContainer {
    has first: Animal | None = None,
        second: Animal | None = None;
}

def test_complex_multi_member_narrowing(cc: ComplexContainer) -> str {
    if cc.first is not None {
        # cc.first narrowed to Animal (CFG)
        if isinstance(cc.second, Mammal) and cc.second.offspring {
            # cc.second narrowed to Mammal (scope-based)
            # cc.first is still Animal (from outer if)
            return cc.first.name + cc.second.name;  # <-- Ok

        }
    }
    return "";
}

# 23. Triple nesting: if -> if -> AND with member narrowing
def test_triple_nested_narrowing(w: Wrapper) -> str {
    if w.inner is not None {
        # w.inner narrowed to Animal (CFG)
        if isinstance(w.inner, Mammal) {
            # w.inner narrowed to Mammal (CFG)
            if w.inner.offspring and len(w.inner.offspring) > 0 {
                # Still Mammal, accessing offspring in AND
                first_offspring: Mammal = w.inner.offspring[0];
                return first_offspring.name;  # <-- Ok

            }
        }
    }
    return "";
}

# 24. AND chain with multiple member narrowings
obj DualWrapper {
    has left: Animal | None = None,
        right: Animal | None = None;
}

def test_and_chain_multiple_members(dw: DualWrapper) -> str {
    if isinstance(dw.left, Mammal)
    and isinstance(dw.right, Primate)
    and dw.left.offspring
    and dw.right.is_primate {
        # dw.left narrowed to Mammal, dw.right narrowed to Primate (both scope-based)
        return dw.left.name + dw.right.name;  # <-- Ok

    }
    return "";
}

# 25. Combined NOT, OR, AND with member access
def test_not_or_and_combined(x: Animal, y: Mammal | Primate, z: Animal) -> str {
    if not isinstance(x, Mammal)
    and (isinstance(y, Mammal) or isinstance(y, Primate))
    and isinstance(z, Primate)
    and z.is_primate {
        # x: Animal (not Mammal), y: Mammal|Primate, z: Primate
        return x.name + y.name + z.name;  # <-- Ok

    }
    return "";
}

# 26. Parallel ifs with NOT, OR, AND each
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

# E1. After AND block, type reverts
def test_error_after_and_block(x: Animal) -> list[Mammal] | None {
    if isinstance(x, Mammal) {
        return x.offspring;  # Ok inside

    }
    return x.offspring;  # <-- Error: Animal has no attribute offspring

}
