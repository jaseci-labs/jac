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
    def bark() -> str {
        return "woof";
    }
}

obj Cat {
    has name: str;
    def meow() -> str {
        return "meow";
    }
}

# ---------------------------------------------------------------------------
# 1. isinstance narrowing inside if-branch
#    Without narrowing: Dog | Cat cannot be assigned to Dog  -> Error
#    With narrowing:    Dog can be assigned to Dog            -> Ok
# ---------------------------------------------------------------------------
def test_isinstance_narrowing(animal: Dog | Cat) -> str {
    if isinstance(animal, Dog) {
        d: Dog = animal;           # <-- Ok after narrowing (Dog)
        return d.bark();
    }
    return animal.name;
}

# ---------------------------------------------------------------------------
# 2. isinstance narrowing with else — negative narrowing
#    True branch:  animal narrowed to Dog
#    Else branch:  animal narrowed to Cat (Dog excluded)
# ---------------------------------------------------------------------------
def test_isinstance_else_narrowing(animal: Dog | Cat) -> str {
    if isinstance(animal, Dog) {
        d: Dog = animal;           # <-- Ok after narrowing (Dog)
        return d.bark();
    } else {
        c: Cat = animal;           # <-- Ok after narrowing (Cat)
        return c.meow();
    }
}

# ---------------------------------------------------------------------------
# 3. None narrowing with `is not None`
#    Without narrowing: int | None cannot be assigned to int  -> Error
#    With narrowing:    int can be assigned to int             -> Ok
# ---------------------------------------------------------------------------
def test_none_narrowing(val: int | None) -> int {
    if val is not None {
        result: int = val;         # <-- Ok after narrowing (int)
        return result;
    }
    return 0;
}

# ---------------------------------------------------------------------------
# 4. None narrowing with `is None` + early return
#    After the if-block returns on None, val must be str.
#    Without narrowing: str | None cannot be assigned to str  -> Error
#    With narrowing:    str can be assigned to str             -> Ok
# ---------------------------------------------------------------------------
def test_none_else_narrowing(val: str | None) -> str {
    if val is None {
        return "default";
    }
    result: str = val;             # <-- Ok after narrowing (str)
    return result;
}

# ---------------------------------------------------------------------------
# 5. Narrowing does NOT persist past join points
#    After an if/else where both branches fall through, the type at the
#    join point must be the original union.
#    This assignment should ALWAYS fail (even with narrowing).
# ---------------------------------------------------------------------------
def test_narrowing_expires_at_join(animal: Dog | Cat) -> str {
    if isinstance(animal, Dog) {
        d: Dog = animal;           # <-- Ok inside branch
    } else {
        c: Cat = animal;           # <-- Ok inside branch
    }
    # At the join point: animal is Dog | Cat again.
    fail: Dog = animal;            # <-- Error (Dog | Cat cannot assign to Dog)
    return fail.bark();
}

# ---------------------------------------------------------------------------
# 6. Chained isinstance narrowing in elif
# ---------------------------------------------------------------------------
obj Fish {
    has name: str;
    def swim() -> str {
        return "splash";
    }
}

def test_elif_narrowing(animal: Dog | Cat | Fish) -> str {
    if isinstance(animal, Dog) {
        d: Dog = animal;           # <-- Ok after narrowing (Dog)
        return d.bark();
    } elif isinstance(animal, Cat) {
        c: Cat = animal;           # <-- Ok after narrowing (Cat)
        return c.meow();
    } else {
        f: Fish = animal;          # <-- Ok after narrowing (Fish)
        return f.swim();
    }
}
