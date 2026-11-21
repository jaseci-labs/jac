# Regression: integer enum members declared with hex/oct/bin literals must fold
# through the AST .lit_value getter (base-0), not base-10 int(value) parsing
# (which would raise on 0xFF / 0o17 / 0b1010).
enum Flags {
    A = 0xFF,
    B = 0o17,
    C = 0b1010
}

def flag_a() -> int {
    return Flags.A.value;
}

def flag_b() -> int {
    return Flags.B.value;
}

def flag_c() -> int {
    return Flags.C.value;
}

with entry {
    _x: int = 0;
}
