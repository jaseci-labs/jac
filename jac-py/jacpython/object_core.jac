# P3.2e — object identity richcompare helpers.
# Lift: Objects/_lifted/object_core.jac
import from objects { PyObj, Py_EQ, Py_NE, }

def object_richcompare_is(a: PyObj, b: PyObj) -> bool {
    return a is b;
}

def object_eq_identity(a: PyObj, b: PyObj, op: int) -> int {
    same = a is b;
    if op == Py_EQ {
        return 1 if same else 0;
    }
    if op == Py_NE {
        return 0 if same else 1;
    }
    return -1;
}
