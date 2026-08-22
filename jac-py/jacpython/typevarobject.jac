# P3.2e — TypeVar variance/bound helpers.
# Lift: Objects/_lifted/typevarobject_core.jac

def typevar_is_covariant(covariant: bool) -> bool {
    return covariant;
}

def typevar_is_contravariant(contravariant: bool) -> bool {
    return contravariant;
}

def typevar_has_bound(has_bound: bool) -> bool {
    return has_bound;
}

def typevar_has_constraints(has_constraints: bool) -> bool {
    return has_constraints;
}
