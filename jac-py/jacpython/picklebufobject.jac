# P3.2e — pickle buffer view helpers.
# Lift: Objects/_lifted/picklebufobject_core.jac

def picklebuf_has_view(has_view: bool) -> bool {
    return has_view;
}

def picklebuf_released(has_view: bool) -> bool {
    return not has_view;
}
