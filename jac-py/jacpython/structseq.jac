# P3.2e — struct sequence field helpers.
# Lift: Objects/_lifted/structseq_core.jac

def structseq_n_in_sequence(n: int) -> int {
    return n;
}

def structseq_n_fields(n: int) -> int {
    return n;
}

def structseq_index_ok(i: int, n: int) -> bool {
    return i >= 0 and i < n;
}
