# P3.2d — OrderedDict order helpers.
# Lift: Objects/_lifted/odictobject_core.jac

def odict_move_to_end_last(last: bool) -> bool {
    return last;
}

def odict_eq_requires_order -> bool {
    return True;
}

def odict_is_empty(size: int) -> bool {
    return size == 0;
}
