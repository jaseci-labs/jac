"""Fixture for E0113: Unicode escape out of valid range."""

with entry {
    a = "\u0041";       # <-- Ok: 'A'
    b = "\U0010FFFF";   # <-- Ok: max valid Unicode
    c = "\U00110000";   # <-- Error E0113: beyond valid Unicode range
}
