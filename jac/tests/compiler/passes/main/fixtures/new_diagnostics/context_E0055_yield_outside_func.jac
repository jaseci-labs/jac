"""Fixture for E0055: yield used outside of a function body."""

# yield at module level (inside with entry, but not in a function)
with entry {
    yield 5;  # <-- Error E0055
}
