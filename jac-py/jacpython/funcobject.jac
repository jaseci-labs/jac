# P3.2c — function attribute helpers.
# Lift: Objects/_lifted/funcobject_core.jac

def func_repr_prefix(is_builtin: bool) -> str {
    if is_builtin {
        return "<built-in function ";
    }
    return "<function ";
}

def func_has_closure(has_closure: bool) -> bool {
    return has_closure;
}
