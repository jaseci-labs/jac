# P3.2d — module name/dict helpers.
# Lift: Objects/_lifted/moduleobject_core.jac

def module_repr_prefix -> str {
    return "<module '";
}

def module_has_dict(has_dict: bool) -> bool {
    return has_dict;
}
