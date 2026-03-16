"""Fixture for E0077: f-string expression part is empty."""

with entry {
    name = "world";
    a = f"hello {name}";   # <-- Ok
    b = f"hello {}";       # <-- Error E0077: empty f-string expression
}
