"""Test py2jac escape sequence handling."""

# Hex escape in regular string
hex_str = "\x1b[31mRed\x1b[0m"

# Octal escape
oct_str = "\033[32mGreen\033[0m"

# Standard escapes
std_str = "line1\nline2\ttabbed"

# F-string with hex escape
color = "34"
fstr_hex = f"\x1b[{color}mBlue\x1b[0m"

# Unicode escape
uni_str = "\u001b[35m"
