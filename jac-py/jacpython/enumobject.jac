# P3.2c — enumerate / reversed index helpers.
# Lift: Objects/_lifted/enumobject_core.jac

glob PY_SSIZE_T_MAX: int = 9223372036854775807;

def enum_index_at_max(en_index: int) -> bool {
    return en_index == PY_SSIZE_T_MAX;
}

def enum_advance_index(en_index: int) -> int {
    return en_index + 1;
}

def reversed_advance_index(index: int) -> int {
    return index - 1;
}

def reversed_start_index(n: int) -> int {
    return n - 1;
}
