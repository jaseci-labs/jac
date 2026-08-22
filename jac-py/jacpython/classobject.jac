# P3.2c — bound-method EQ / repr helpers (complements methodobject.jac).
# Lift: Objects/_lifted/classobject_core.jac
import from objects { PyObj, }

def method_eq(a_func: PyObj, a_self: PyObj, b_func: PyObj, b_self: PyObj) -> bool {
    if a_func is not b_func {
        return False;
    }
    return a_self is b_self;
}

def method_repr_prefix -> str {
    return "<bound method ";
}
