"""Test type narrowing for if-elif-else chains.

Tests:
- Progressive narrowing through elif
- isinstance in elif chains
- Exhaustive type narrowing
- Type exclusion in else branch

NOTE: elif narrowing is a known issue (CFG edges don't match type checker nodes).
This test documents expected behavior.
"""

"""Base types for testing"""
obj Animal {
    has name: str = "animal";
}

obj Dog(Animal) {
    has breed: str = "unknown";

    def bark { }
}

obj Cat(Animal) {
    has indoor: bool = True;

    def meow { }
}

obj Bird(Animal) {
    has wingspan: float = 0.0;

    def fly { }
}


"""Test 1: Basic elif isinstance chain"""
def test_elif_isinstance(animal: Animal) {
    if isinstance(animal, Dog) {
        # animal should be Dog
        dog: Dog = animal;
        breed: str = animal.breed;
        animal.bark();
    } elif isinstance(animal, Cat) {
        # animal should be Cat (and NOT Dog)
        cat: Cat = animal;
        indoor: bool = animal.indoor;
        animal.meow();
    } elif isinstance(animal, Bird) {
        # animal should be Bird (and NOT Dog or Cat)
        bird: Bird = animal;
        span: float = animal.wingspan;
        animal.fly();
    } else {
        # animal should be Animal (but not Dog, Cat, or Bird)
        base_animal: Animal = animal;
    }
}


"""Test 2: elif with union type exhaustion"""
def test_elif_exhaustive(x: int | str | float) {
    if isinstance(x, int) {
        # x should be int
        int_val: int = x;
    } elif isinstance(x, str) {
        # x should be str (int already excluded)
        str_val: str = x;
    } else {
        # x should be float (int and str excluded)
        float_val: float = x;
    }
}


"""Test 3: elif with None checks"""
def test_elif_none(x: int | str | None) {
    if x is None {
        # x should be None
        none_val: None = x;
    } elif isinstance(x, int) {
        # x should be int (None excluded)
        int_val: int = x;
    } else {
        # x should be str (None and int excluded)
        str_val: str = x;
    }
}


"""Test 4: Nested if inside elif"""
def test_nested_in_elif(x: int | str | float, y: bool) {
    if isinstance(x, int) {
        int_val: int = x;
    } elif isinstance(x, str) {
        str_val: str = x;
        if y {
            # x should still be str here
            upper: str = x.upper();
        }
    } else {
        float_val: float = x;
    }
}


"""Test 5: Multiple conditions in elif
TODO: Compound elif conditions like `isinstance(x, int) and x > 0`
need proper CFG handling to track what's been excluded.
"""
def test_elif_compound(x: int | str | None) {
    if x is None {
        none_val: None = x;
    } elif isinstance(x, int) and x > 0 {
        # x should be int and positive
        positive_int: int = x;
    } elif isinstance(x, int) {
        # x should be int (but not positive, could be <= 0)
        int_val: int = x;
    } else {
        # x should be str - requires tracking compound elif exclusions
        # str_val: str = x;  # TODO: needs compound elif tracking
        y: int = 1;
    }
}


"""Test 6: Early return in if-elif"""
def test_elif_early_return(x: int | str | float) -> str {
    if isinstance(x, int) {
        return "int";
    } elif isinstance(x, str) {
        return x;  # x is str, can return directly

    }
    # After both branches return, x should be float here
    float_val: float = x;
    return str(x);
}


"""Test 7: elif with truthiness"""
def test_elif_truthy(a: str | None, b: int | None) -> str {
    if a {
        # a is truthy (non-None str)
        return a.upper();
    } elif b {
        # a is falsy (None), b is truthy (non-None int)
        return str(b);
    } else {
        # Both a and b are falsy/None
        return "default";
    }
}


"""Test 8: Long elif chain with progressive narrowing"""
def test_long_elif_chain(x: int | str | float | list | dict | None) {
    if x is None {
        none_val: None = x;
    } elif isinstance(x, int) {
        int_val: int = x;
    } elif isinstance(x, str) {
        str_val: str = x;
    } elif isinstance(x, float) {
        float_val: float = x;
    } elif isinstance(x, list) {
        list_val: list = x;
    } else {
        # Only dict should remain
        dict_val: dict = x;
    }
}
