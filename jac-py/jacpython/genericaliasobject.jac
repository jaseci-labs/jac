# P3.2e — GenericAlias helpers.
# Lift: Objects/_lifted/genericaliasobject_core.jac

def genericalias_has_args(has_args: bool) -> bool {
    return has_args;
}

def genericalias_nargs(n: int) -> int {
    return n;
}

def genericalias_repr_sep -> str {
    return "[";
}
