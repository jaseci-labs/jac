"""Atomic expressions: Atomic expressions and literals (strings, numbers, bools, None, types)."""

enum NumEnum { aa = 67, y = 68 }

# Literals
glob s = "string",
     b1 = True,
     b2 = False,
     n = None,
     dec = 42,
     binary = 0b1100,
     octal = 0o755,
     hexa = 0xFF,
     flt = 3.14,
     sci = 1.5e10,
     ellip = ...,
     result = (5 + 3) * 2,
     var = 100,
     type1 = str,
     type2 = int,
     tpl = (1, 2, 3),
     lst = [1, 2, 3],
     dct = {"k": "v"},
     st = {1,2,3},
     multi = "Hello " "World",
     name = "Alice",
     fstr = f"Hello {name}";

with entry {
    print(dec, binary, octal, hexa, flt, sci, multi, fstr, NumEnum.aa.value);
}
# Integer formats

# Float formats

# Ellipsis

# Parenthesized expressions

# Named references

# Builtin types as values

# Collections

# Multistring

# F-string
