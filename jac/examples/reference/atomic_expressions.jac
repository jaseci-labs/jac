"""Atomic expressions: Atomic expressions and literals (strings, numbers, bools, None, types)."""

enum NumEnum { aa = 67, y = 68 }

with entry {
    # Literals
    s = "string";
    b1 = True;
    b2 = False;
    n = None;

    # Integer formats
    dec = 42;
    binary = 0b1100;
    octal = 0o755;
    hexa = 0xFF;

    # Float formats
    flt = 3.14;
    sci = 1.5e10;

    # Ellipsis
    ellip = ...;

    # Parenthesized expressions
    result = (5 + 3) * 2;

    # Named references
    var = 100;

    # Builtin types as values
    type1 = str;
    type2 = int;

    # Collections
    tpl = (1, 2, 3);
    lst = [1, 2, 3];
    dct = {"k": "v"};
    st = {1,2,3};

    # Multistring
    multi = "Hello " "World";

    # F-string
    name = "Alice";
    fstr = f"Hello {name}";

    print(dec, binary, octal, hexa, flt, sci, multi, fstr, NumEnum.aa.value);
}
