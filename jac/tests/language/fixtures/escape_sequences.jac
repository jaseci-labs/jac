"""Test escape sequence handling in strings and f-strings."""

with entry {
    # Test 1: Regular string with \x escape (hex)
    esc_x = "\x1b[31m";
    print(f"hex_escape_len:{len(esc_x)}");
    print(f"hex_escape_first_ord:{ord(esc_x[0])}");

    # Test 2: Regular string with \033 escape (octal) - distinct parsing path from hex
    esc_oct = "\033[32m";
    print(f"octal_escape_len:{len(esc_oct)}");
    print(f"octal_escape_first_ord:{ord(esc_oct[0])}");

    # Test 3: F-string with \x escape - f-strings use a different AST node (JoinedStr)
    code = "1;33";
    fstr_x = f"\x1b[{code}m";
    print(f"fstring_hex_len:{len(fstr_x)}");
    print(f"fstring_hex_first_ord:{ord(fstr_x[0])}");

    # Test 5: Standard escapes in regular strings
    standard = "\n\t\r";
    print(f"newline_ord:{ord(standard[0])}");
    print(f"tab_ord:{ord(standard[1])}");
    print(f"carriage_ord:{ord(standard[2])}");

    # Test 7: Escaped backslash - must NOT be treated as ESC
    escaped_bs = "\\x1b";
    print(f"escaped_backslash_first_ord:{ord(escaped_bs[0])}");

    # Test 9: Unicode escape \u - third distinct escape syntax
    unicode_esc = "\u001b[35m";
    print(f"unicode_escape_first_ord:{ord(unicode_esc[0])}");
}
