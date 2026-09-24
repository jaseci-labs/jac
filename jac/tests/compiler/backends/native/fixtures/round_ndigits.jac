"""`round` keeps Python's results: halves to even, and ndigits keeps a float."""

def round_half_even_low -> int {
    return round(2.5);
}

def round_half_even_high -> int {
    return round(3.5);
}

def round_negative_half -> int {
    return round(-2.5);
}

def round_two_places -> float {
    return round(0.8347, 2);
}

def round_binary_half -> float {
    return round(2.675, 2);
}

def round_negative_places -> float {
    return round(1234.5678, -2);
}

def round_runtime_places(value: float, digits: int) -> float {
    return round(value, digits);
}

def round_int_places -> int {
    return round(7, 2);
}
