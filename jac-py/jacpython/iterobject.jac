# P3.2c — seqiter length_hint helpers.
# Lift: Objects/_lifted/iterobject_core.jac

def seqiter_length_hint(seqsize: int, it_index: int, has_seq: bool) -> int {
    if not has_seq {
        return 0;
    }
    length = seqsize - it_index;
    if length >= 0 {
        return length;
    }
    return 0;
}

def seqiter_exhausted(has_seq: bool) -> bool {
    return not has_seq;
}

def seqiter_next_index(it_index: int) -> int {
    return it_index + 1;
}
