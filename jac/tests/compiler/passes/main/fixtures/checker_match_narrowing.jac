"""Tests for match statement type narrowing in the type checker.

These tests validate that after match cases, the type is correctly
handled - especially inside case blocks where the type should be
narrowed to the matched pattern.
"""

obj Animal {
    has name: str;
}

obj Dog(Animal) {
    def bark -> str {
        return "woof";
    }
}

obj Cat(Animal) {
    def meow -> str {
        return "meow";
    }
}

obj Fish(Animal) {
    def swim -> str {
        return "splash";
    }
}

# Helper function that expects base type Animal
def process_animal(a: Animal) -> str {
    return a.name;
}

# 1. Inside a match case, the type should be narrowed to the matched pattern
#    and should still be assignable to the base type parameter.
def test_match_case_narrowing(
    animal: Animal
) -> str {
    match animal {
        case Dog():
            # animal is narrowed to Dog here
            # But Dog is still an Animal, so this should work
            return process_animal(animal);  # <-- Should be Ok


        case Cat():
            return process_animal(animal);  # <-- Should be Ok


        case _:
            return process_animal(animal);  # <-- Should be Ok


    }
}

# 2. Multiple cases with same handling - type should work
def test_match_multiple_cases(
    animal: Animal
) -> str {
    match animal {
        case Dog() | Cat():
            # animal is Dog | Cat here, both are Animal
            return process_animal(animal);  # <-- Should be Ok


        case _:
            return animal.name;

    }
}

# 3. After match with all cases returning, code is unreachable
def test_match_exhaustive(
    animal: Dog | Cat
) -> str {
    match animal {
        case Dog():
            return "dog";

        case Cat():
            return "cat";

    }
    # This is unreachable if match is exhaustive
}

# 4. Code after match cases that don't all return
def test_match_fallthrough(
    animal: Animal
) -> str {
    result: str = "";
    match animal {
        case Dog():
            result = "dog";

        case Cat():
            result = "cat";

        case _:
            result = "other";

    }
    # After match, animal should still be Animal (or union of matched types)
    return process_animal(animal);  # <-- Should be Ok

}

# E1. Wrong type inside match case
def test_error_wrong_type_in_case(
    animal: Animal
) -> str {
    match animal {
        case Dog():
            c: Cat = animal;  # <-- Error: Dog cannot assign to Cat
            return c.meow();

        case _:
            return "";

    }
}
