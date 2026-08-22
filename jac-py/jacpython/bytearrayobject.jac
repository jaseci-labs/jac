# P3.2d — bytearray index helpers.
# Lift: Objects/_lifted/bytearrayobject_core.jac

def bytearray_length(size: int) -> int {
    return size;
}

def bytearray_valid_index(i: int, size: int) -> bool {
    return i >= 0 and i < size;
}

def bytearray_adjust_index(i: int, size: int) -> int {
    if i < 0 {
        return i + size;
    }
    return i;
}

def bytearray_eq_lens(a: int, b: int) -> bool {
    return a == b;
}
