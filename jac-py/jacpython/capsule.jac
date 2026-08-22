# P3.2e — PyCapsule name/pointer helpers.
# Lift: Objects/_lifted/capsule_core.jac

def capsule_name_matches(a: str, b: str) -> bool {
    return a == b;
}

def capsule_pointer_is_null(is_null: bool) -> bool {
    return is_null;
}

def capsule_repr_prefix -> str {
    return "<capsule object ";
}
