# P3.2c — range length / contains helpers.
# Lift: Objects/_lifted/rangeobject_core.jac

def get_len_of_range(lo: int, hi: int, step: int) -> int {
    if step > 0 and lo < hi {
        return 1 + (hi - 1 - lo) // step;
    }
    if step < 0 and lo > hi {
        return 1 + (lo - 1 - hi) // (-step);
    }
    return 0;
}

def range_contains_longs(start: int, stop: int, step: int, value: int) -> bool {
    if step > 0 {
        if value < start or value >= stop {
            return False;
        }
    } else {
        if value > start or value <= stop {
            return False;
        }
    }
    return ((value - start) % step) == 0;
}

def range_equals_longs(
    s0: int, e0: int, st0: int, s1: int, e1: int, st1: int
) -> bool {
    len0 = get_len_of_range(s0, e0, st0);
    len1 = get_len_of_range(s1, e1, st1);
    if len0 != len1 {
        return False;
    }
    if len0 == 0 {
        return True;
    }
    if s0 != s1 {
        return False;
    }
    if len0 == 1 {
        return True;
    }
    return st0 == st1;
}
