"""Tests for CFG-based type narrowing in the type checker.

These tests validate that the type checker uses the control flow graph to
narrow types inside conditional branches and correctly widens them at
join points, following Pyright's flow-sensitive type analysis approach.

Each narrowing scenario uses explicit typed assignments to verify the
narrowed type.  Without narrowing, these assignments produce type errors
because the checker sees the full union type.  With narrowing, the
checker should see the narrowed type and accept the assignment.
"""

obj Dog {
    has name: str;

    def bark -> str {
        return "woof";
    }
}

obj Cat {
    has name: str;

    def meow -> str {
        return "meow";
    }
}

# 1. isinstance narrowing inside if-branch
#    Without narrowing: Dog | Cat cannot be assigned to Dog  -> Error
#    With narrowing:    Dog can be assigned to Dog            -> Ok
def test_isinstance_narrowing(
    animal: Dog | Cat
) -> str {
    if isinstance(animal, Dog) {
        d: Dog = animal;  # <-- Ok after narrowing (Dog)
        return d.bark();
    }
    return animal.name;
}

# 2. isinstance narrowing with else — negative narrowing
#    True branch:  animal narrowed to Dog
#    Else branch:  animal narrowed to Cat (Dog excluded)
def test_isinstance_else_narrowing(
    animal: Dog | Cat
) -> str {
    if isinstance(animal, Dog) {
        d: Dog = animal;  # <-- Ok after narrowing (Dog)
        return d.bark();
    } else {
        c: Cat = animal;  # <-- Ok after narrowing (Cat)
        return c.meow();
    }
}

# 3. None narrowing with `is not None`
#    Without narrowing: int | None cannot be assigned to int  -> Error
#    With narrowing:    int can be assigned to int             -> Ok
def test_none_narrowing(
    val: int | None
) -> int {
    if val is not None {
        result: int = val;  # <-- Ok after narrowing (int)
        return result;
    }
    return 0;
}

# 4. None narrowing with `is None` + early return
#    After the if-block returns on None, val must be str.
#    Without narrowing: str | None cannot be assigned to str  -> Error
#    With narrowing:    str can be assigned to str             -> Ok
def test_none_else_narrowing(
    val: str | None
) -> str {
    if val is None {
        return "default";
    }
    result: str = val;  # <-- Ok after narrowing (str)
    return result;
}

# 5. Narrowing does NOT persist past join points
#    After an if/else where both branches fall through, the type at the
#    join point must be the original union.
#    This assignment should ALWAYS fail (even with narrowing).
def test_narrowing_expires_at_join(
    animal: Dog | Cat
) -> str {
    if isinstance(animal, Dog) {
        d: Dog = animal;  # <-- Ok inside branch
    } else {
        c: Cat = animal;  # <-- Ok inside branch
    }
    # At the join point: animal is Dog | Cat again.
    fail: Dog = animal;  # <-- Error (Dog | Cat cannot assign to Dog)
    return fail.bark();
}

# 6. Chained isinstance narrowing in elif
obj Fish {
    has name: str;

    def swim -> str {
        return "splash";
    }
}

def test_elif_narrowing(animal: Dog | Cat | Fish) -> str {
    if isinstance(animal, Dog) {
        d: Dog = animal;  # <-- Ok after narrowing (Dog)
        return d.bark();
    } elif isinstance(animal, Cat) {
        c: Cat = animal;  # <-- Ok after narrowing (Cat)
        return c.meow();
    } else {
        f: Fish = animal;  # <-- Ok after narrowing (Fish)
        return f.swim();
    }
}

# 7. Parenthesized isinstance narrowing (AtomUnit unwrap)
#    Handles: (isinstance(x, T)), ((isinstance(x, T)))
def test_parenthesized_isinstance(
    animal: Dog | Cat
) -> str {
    if (isinstance(animal, Dog)) {
        d: Dog = animal;  # <-- Ok after narrowing (Dog)
        return d.bark();
    }
    return animal.name;
}

def test_double_parenthesized(animal: Dog | Cat) -> str {
    if ((isinstance(animal, Dog))) {
        d: Dog = animal;  # <-- Ok after narrowing (Dog)
        return d.bark();
    }
    return animal.name;
}

# 8. NOT isinstance narrowing (UnaryExpr)
#    Handles: not isinstance(x, T) -> excludes T in true branch
def test_not_isinstance(
    animal: Dog | Cat
) -> str {
    if not isinstance(animal, Dog) {
        c: Cat = animal;  # <-- Ok after narrowing (Cat)
        return c.meow();
    } else {
        d: Dog = animal;  # <-- Ok after narrowing (Dog)
        return d.bark();
    }
}

def test_not_none(val: int | None) -> int {
    if not (val is None) {
        result: int = val;  # <-- Ok after narrowing (int)
        return result;
    }
    return 0;
}

# 9. Compound AND narrowing (BoolExpr with and)
#    Handles: isinstance(x, A) and isinstance(y, B)
#    Returns narrowing for the first matching symbol
def test_and_isinstance(
    animal: Dog | Cat, other: Dog | Cat
) -> str {
    if isinstance(animal, Dog) and isinstance(other, Cat) {
        d: Dog = animal;  # <-- Ok after narrowing (Dog)
        c: Cat = other;  # <-- Ok after narrowing (Cat)
        return d.bark() + c.meow();
    }
    return "";
}

def test_and_none_check(val: int | None, flag: bool) -> int {
    if val is not None and flag {
        result: int = val;  # <-- Ok after narrowing (int)
        return result;
    }
    return 0;
}

# 10. Compound OR narrowing (BoolExpr with or)
#     Handles: isinstance(x, A) or isinstance(x, B) -> narrows to A | B
def test_or_isinstance(
    animal: Dog | Cat | Fish
) -> str {
    if isinstance(animal, Dog) or isinstance(animal, Cat) {
        # animal is narrowed to Dog | Cat
        return animal.name;  # <-- Ok, both Dog and Cat have 'name'

    } else {
        f: Fish = animal;  # <-- Ok after narrowing (Fish)
        return f.swim();
    }
}

# 11. isinstance with tuple of types
#     Handles: isinstance(x, (A, B, C)) -> narrows to A | B | C
def test_isinstance_tuple(
    animal: Dog | Cat | Fish
) -> str {
    if isinstance(animal, (Dog, Cat)) {
        return animal.name;  # <-- Ok, both Dog and Cat have 'name'

    } else {
        f: Fish = animal;  # <-- Ok after narrowing (Fish)
        return f.swim();
    }
}

def test_isinstance_tuple_single(animal: Dog | Cat) -> str {
    if isinstance(animal, (Dog, )) {
        d: Dog = animal;  # <-- Ok after narrowing (Dog)
        return d.bark();
    }
    return animal.name;
}

# 12. Truthiness narrowing (if x:)
#     Handles: if x: -> excludes None in true branch
def test_truthiness_narrowing(
    val: str | None
) -> str {
    if val {
        result: str = val;  # <-- Ok after narrowing (str)
        return result;
    }
    return "default";
}

def test_truthiness_else(val: int | None) -> int {
    if val {
        return val;  # <-- Ok after narrowing (int)

    } else {
        return 0;  # val is None here

    }
}

# 13. Combined patterns - NOT with parentheses
def test_not_parenthesized(
    animal: Dog | Cat
) -> str {
    if not (isinstance(animal, Dog)) {
        c: Cat = animal;  # <-- Ok after narrowing (Cat)
        return c.meow();
    }
    return animal.name;
}

# 14. Nested compound expressions
def test_nested_and_or(
    animal: Dog | Cat | Fish, flag: bool
) -> str {
    if isinstance(animal, Dog) and flag {
        d: Dog = animal;  # <-- Ok after narrowing (Dog)
        return d.bark();
    }
    return "";
}

# 15. Inheritance-aware isinstance narrowing
#     When checking isinstance(x, Base), narrow to all subclasses of Base
#     that are in the original union type.
obj Animal {
    has species: str = "unknown";
}

obj Mammal(Animal) {
    has legs: int = 4;
}

obj Reptile(Animal) {
    has scales: bool = True;
}

obj Lion(Mammal) {
    def roar -> str {
        return "roar!";
    }
}

def test_inheritance_isinstance(creature: Animal | Lion | Reptile | str) -> str {
    if isinstance(creature, Mammal) {
        # creature should narrow to Lion (since Lion is a subclass of Mammal)
        # and any Mammal instances in the union
        return str(creature.legs);  # <-- Ok, Mammal has 'legs'

    }
    return "not a mammal";
}

def test_inheritance_isinstance_base(creature: Lion | Reptile | str) -> str {
    if isinstance(creature, Animal) {
        # creature should narrow to Lion | Reptile (both are subclasses of Animal)
        return creature.species;  # <-- Ok, Animal has 'species'

    }
    return "not an animal";
}

# E1. Wrong type assignment inside narrowed branch
#     Even with narrowing, assigning to the wrong type should error.
def test_error_wrong_type_in_branch(
    animal: Dog | Cat
) -> str {
    if isinstance(animal, Dog) {
        c: Cat = animal;  # <-- Error: Dog cannot be assigned to Cat
        return c.meow();
    }
    return "";
}

# E2. Narrowing expires at join point (same as test 5, but explicit error)
#     After if/else where both branches fall through, type is widened.
def test_error_narrowing_expired(
    animal: Dog | Cat
) -> str {
    if isinstance(animal, Dog) {
        d: Dog = animal;  # <-- Ok inside branch
    } else {
        c: Cat = animal;  # <-- Ok inside branch
    }
    # At join point: animal is Dog | Cat again
    wrong: Dog = animal;  # <-- Error: Dog | Cat cannot assign to Dog
    return wrong.bark();
}

# E3. After early return, type is narrowed but can't assign to wrong type
def test_error_after_early_return(
    animal: Dog | Cat
) -> str {
    if isinstance(animal, Dog) {
        return animal.bark();  # <-- Ok, Dog has bark()

    }
    # animal is Cat here (Dog was excluded by early return)
    d: Dog = animal;  # <-- Error: Cat cannot assign to Dog
    return d.bark();
}

# E4. Incorrect narrowing assumption in else branch
#     If we narrow to Dog, else should be Cat, not Dog.
def test_error_wrong_else_narrowing(
    animal: Dog | Cat
) -> str {
    if isinstance(animal, Dog) {
        return animal.bark();
    } else {
        d: Dog = animal;  # <-- Error: Cat cannot assign to Dog
        return d.bark();
    }
}

# E5. Truthiness narrowing doesn't help with non-None types
def test_error_truthiness_wrong_type(
    val: str | int
) -> str {
    if val {
        s: str = val;  # <-- Error: str | int cannot assign to str
        return s;
    }
    return "";
}

# E6. OR narrowing - can't assign to single type when narrowed to union
def test_error_or_narrowing_single(
    animal: Dog | Cat | Fish
) -> str {
    if isinstance(animal, Dog) or isinstance(animal, Cat) {
        d: Dog = animal;  # <-- Error: Dog | Cat cannot assign to Dog
        return d.bark();
    }
    return "";
}

# E7. Tuple isinstance - can't assign to single type
def test_error_tuple_isinstance_single(
    animal: Dog | Cat | Fish
) -> str {
    if isinstance(animal, (Dog, Cat)) {
        d: Dog = animal;  # <-- Error: Dog | Cat cannot assign to Dog
        return d.bark();
    }
    return "";
}

# E8. NOT narrowing - else branch has the positive type
def test_error_not_narrowing_wrong(
    animal: Dog | Cat
) -> str {
    if not isinstance(animal, Dog) {
        d: Dog = animal;  # <-- Error: Cat cannot assign to Dog
        return d.bark();
    }
    return "";
}

# E9. Inheritance narrowing - wrong subclass assignment
def test_error_inheritance_wrong_subclass(
    creature: Lion | Reptile | str
) -> str {
    if isinstance(creature, Mammal) {
        # creature is Lion (the only Mammal subclass in union)
        r: Reptile = creature;  # <-- Error: Lion cannot assign to Reptile
        return "wrong";
    }
    return "";
}
