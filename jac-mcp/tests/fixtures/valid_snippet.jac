"""A valid Jac snippet for testing."""

obj Animal {
    has name: str,
        species: str,
        age: int = 0;

    def describe -> str {
        return f"{self.name} is a {self.species}, age {self.age}";
    }
}

node Habitat {
    has biome: str,
        temperature: float = 20.0;
}

edge LivesIn {
    has since_year: int = 2024;
}

walker Observer {
    has notes: list[str] = [];

    can visit_habitat with Habitat entry {
        self.notes.append(f"Found habitat: {here.biome}");
        visit [-->];
    }
}

with entry {
    cat = Animal(name="Whiskers", species="cat", age=3);
    print(cat.describe());
}
