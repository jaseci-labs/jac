"""A private helper whose name a different module also exports publicly."""

def:priv double(value: int) -> int {
    return value * 2;
}

def quadruple(value: int) -> int {
    return double(double(value));
}
