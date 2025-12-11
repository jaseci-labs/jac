obj Base {
    has name: str;
}

obj Child(Base) {
    has age: int;
}

with entry {
    c0 = Child("Alice", 30);  # <-- Ok
    c1 = Child(name="Alice", age=30);  # <-- Ok
    c2 = Child("Bob");  # <-- Error: missing age
    c3 = Child(age=25);  # <-- Error: missing name
}
