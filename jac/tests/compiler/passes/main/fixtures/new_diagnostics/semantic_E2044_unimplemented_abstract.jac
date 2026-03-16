"""Fixture for E2044: Abstract archetype has unimplemented abstract abilities."""

@abstract
obj Animal {
    def speak(self: Animal) -> str;
    def move(self: Animal) -> str;
}

obj Dog(Animal) {
    def speak(self: Dog) -> str {
        return "Woof";
    }
    # Missing move()!  # <-- Error E2044: Dog does not implement 'move'
}

obj Cat(Animal) {
    def speak(self: Cat) -> str {
        return "Meow";
    }
    def move(self: Cat) -> str {
        return "slink";
    }
    # <-- Ok: all abstract methods implemented
}
