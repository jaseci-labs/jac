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

# === Additional edge cases ===

# fmt: off
# Mixed quotes
mixed_quotes = "it's \"quoted\""
# fmt: on

# Backslashes
backslash_str = "path\\to\\file"

# Raw string (escapes should NOT be interpreted)
raw_str = r"\x1b[31m not an escape \n \t"

# Triple-quoted with actual newlines AND escape sequences
triple_with_escapes = """line1
line2\ttabbed\x1b[31mred\x1b[0m"""

# Triple-quoted f-string with escapes and actual newlines
name = "world"
triple_fstring = f"""Hello {name}
This has \x1b[31mcolor\x1b[0m
and tabs\there"""

# Other standard escapes
other_escapes = "\r\f\v\a\b"

# Null character
null_char = "before\x00after"

# Empty string
empty = ""

# Single character escapes
single_newline = "\n"
single_tab = "\t"

# Multiple hex escapes in sequence
multi_hex = "\x1b\x1b\x1b"

# Unicode with different formats
unicode_4 = "\u0041"  # A
unicode_8 = "\U00000041"  # A
unicode_named = "\N{LATIN SMALL LETTER A}"

# Bytes literal
bytes_lit = b"\x1b[31mRed\x1b[0m"

# F-string with braces that need escaping
fstr_braces = f"{{literal braces}} and {color}"

# String with hash (important for Jac)
hash_str = "# not a comment"
fstr_hash = f"# {color} not a comment"
