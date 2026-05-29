# Native primitive method dispatch resolved via the emitter contract
# (the per-type method sets are derived from the emitter, not hardcoded tuples).

def int_bit_length() -> int {
    x: int = 255;
    return x.bit_length();
}

def int_bit_count() -> int {
    x: int = 7;
    return x.bit_count();
}

def float_is_integer() -> int {
    f: float = 4.0;
    return 1 if f.is_integer() else 0;
}
