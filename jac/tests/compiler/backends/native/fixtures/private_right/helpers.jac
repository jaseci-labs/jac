import from ..private_left.helpers { LeftValue, left_adjust }
def:priv adjust(value: int) -> int {
    return value * 2;
}

def right_adjust(value: int) -> int {
    left = left_adjust(value);
    return left.adjusted() + adjust(value);
}
