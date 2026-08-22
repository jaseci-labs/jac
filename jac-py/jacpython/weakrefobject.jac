# P3.2d — weakref alive/dead helpers.
# Lift: Objects/_lifted/weakrefobject_core.jac

def weakref_is_dead(alive: bool) -> bool {
    return not alive;
}

def weakref_has_callback(has_cb: bool) -> bool {
    return has_cb;
}
