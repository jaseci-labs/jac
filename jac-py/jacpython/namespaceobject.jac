# P3.2e — SimpleNamespace helpers.
# Lift: Objects/_lifted/namespaceobject_core.jac

def namespace_has_dict(has_dict: bool) -> bool {
    return has_dict;
}

def namespace_repr_prefix -> str {
    return "namespace(";
}
