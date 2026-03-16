"""Fixture for E0057: return used outside of a function body."""

# return at module level
with entry {
    return 5;  # <-- Error E0057
}
