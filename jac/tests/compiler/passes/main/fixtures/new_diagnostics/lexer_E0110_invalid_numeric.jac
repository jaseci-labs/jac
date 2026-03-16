"""Fixture for E0110: Invalid numeric literal."""

with entry {
    # Invalid binary literal (2 is not valid in binary)
    x = 0b102;  # <-- Error E0110

    # Invalid hex literal
    y = 0xGG;  # <-- Error E0110

    # Leading zeros in decimal (ambiguous octal)
    z = 007;  # <-- Error E0110
}
