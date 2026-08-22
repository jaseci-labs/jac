# P3.2e — interpolation helpers.
# Lift: Objects/_lifted/interpolationobject_core.jac

def interpolation_has_expression(has_expr: bool) -> bool {
    return has_expr;
}

def interpolation_conversion_ok(conversion: int) -> bool {
    return conversion >= 0;
}
