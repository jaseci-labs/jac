"""Test that @property resolves to return type on union types."""

obj Animal {
    @property
    def name -> str;
}

obj Dog(Animal) {}
obj Cat(Animal) {}

with entry {
    # Single type - property works
    d = Dog();
    ok1: str = d.name;
    wrong1: int = d.name;  # Error

    # Union type - property must also work
    pet: Animal = Dog();
    if isinstance(pet, (Dog, Cat)) {
        ok2: str = pet.name;
        wrong2: int = pet.name;  # Error
    }
}
