# P3.2e — typing.Union arg helpers.
# Lift: Objects/_lifted/unionobject_core.jac

def union_args_len(n: int) -> int {
    return n;
}

def union_is_empty(n: int) -> bool {
    return n == 0;
}

def union_singleton(n: int) -> bool {
    return n == 1;
}
