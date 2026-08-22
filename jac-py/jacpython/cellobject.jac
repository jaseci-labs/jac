# P3.2c — cell empty/filled ordering helpers.
# Lift: Objects/_lifted/cellobject_core.jac
import from objects { PyCell, }

def cell_is_empty(_cell: PyCell) -> bool {
    return False;
}

def cell_empty_before(a_empty: bool, b_empty: bool) -> int {
    if a_empty and b_empty {
        return 0;
    }
    if a_empty {
        return -1;
    }
    if b_empty {
        return 1;
    }
    return 2;
}

def cell_repr_kind(empty: bool) -> str {
    if empty {
        return "empty";
    }
    return "filled";
}
