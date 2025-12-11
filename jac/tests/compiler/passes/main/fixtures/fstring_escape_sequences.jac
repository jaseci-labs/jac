"""Test for f-string escape sequences."""

with entry {
    name = "world";
    # Test escape sequences in f-strings
    result1 = f"hello\n{name}";
    result2 = f"tab\there";
    result3 = f"line1\nline2\nline3";
    result4 = f"{name}\t{name}\t{name}";

    # Print with repr to clearly show escape sequences are decoded
    print(repr(result1));
    print(repr(result2));
    print(repr(result3));
    print(repr(result4));
}
