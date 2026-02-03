"""Test valid docstring placement."""

"""This is a valid docstring before the class"""
obj Person {
    has name: str;

    """This is a valid docstring before the method"""
    def greet() -> str {
        return f"Hello, {self.name}!";
    }
}

"""Valid docstring before function"""
def standalone_func() -> None {
    print("test");
}

with entry {
    p = Person(name="Alice");
    print(p.greet());
}
