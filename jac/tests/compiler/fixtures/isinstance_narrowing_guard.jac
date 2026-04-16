"""Fixture for inverted isinstance guard narrowing test.

After `if isinstance(pet, Dog) { } else { return ...; }` the type checker
must narrow `pet` to `Dog` — accessing `pet.breed` should produce no errors.
"""

obj Animal {
    has name: str;
}

obj Dog(Animal) {
    has breed: str;
}

obj Cat(Animal) {
    has indoor: bool;
}

def describe(pet: Dog | Cat) -> str {
    if isinstance(pet, Dog) { } else {
        return "cat";
    }
    return pet.breed;
}
