"""Test bidirectional type inference for container literals.

Validates that container literals adopt the declared type's type_args
when all elements are compatible, and fall back to bottom-up inference
(producing type errors) when elements don't match.
"""

import from typing { TypeVar, Generic }

obj Animal {
    has name: str = "";
}

obj Dog(Animal) {}
obj Cat(Animal) {}

obj Unrelated {
    has x: int = 0;
}

glob T = TypeVar('T');

obj Box(Generic[T]) {
    has data: T;

    def get_data -> T {
        return self.data;
    }
}

# --- list bidirectional inference ---

def good_list -> list[Animal] {
    return [Dog(), Cat()];  # Ok: Dog and Cat are both Animals
}

def bad_list -> list[int] {
    return [Dog(), Cat()];  # Error: Dog/Cat not assignable to int
}

# --- dict bidirectional inference ---

def good_dict -> dict[str, Animal] {
    return {"d": Dog(), "c": Cat()};  # Ok
}

def bad_dict -> dict[str, int] {
    return {"d": Dog()};  # Error: Dog not assignable to int
}

# --- set bidirectional inference ---

def good_set -> set[Animal] {
    return {Dog(), Cat()};  # Ok
}

def bad_set -> set[int] {
    return {Dog()};  # Error: Dog not assignable to int
}

# --- assignment bidirectional inference ---

with entry {
    ok_list: list[Animal] = [Dog(), Cat()];  # Ok
    bad_assign: list[int] = [Dog()];  # Error

    # type[X] covariance
    ok_type: type[Animal] = Dog;  # Ok: Dog is subclass of Animal
    bad_type: type[int] = Dog;  # Error: Dog is not subclass of int
}
