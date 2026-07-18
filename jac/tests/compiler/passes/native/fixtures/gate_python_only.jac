"""Fixture: a plain Python/client module with no native-context statements."""

def greet(name: str) -> str {
    return f"hello {name}";
}

with entry {
    print(greet("world"));
}
