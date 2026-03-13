"""Fixture for E0111: Invalid escape sequence in string."""

with entry {
    a = "hello\q world";  # <-- Error E0111: \q is not a valid escape
    b = "path\to\file";   # <-- Error E0111: \t is valid but \f is not a standard escape
    c = "\n\t\r";          # <-- Ok: valid escapes
}
