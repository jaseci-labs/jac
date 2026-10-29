"""Raising a bare type parameter.

`T` names a type, not an exception value or class: `raise T` fails at
runtime even when `T` is bound to an exception, so it is E1090, and as a
`from` cause it is E1161. A value of type `T` or `type[T]` is still raised
as before.
"""

# Accepted: values whose type is the type parameter.
def raise_type_param_value[T: Exception](e: T) {
    raise e;
}

def raise_type_param_class[T: Exception](t: type[T]) {
    raise t;
}

def raise_from_type_param_value[T: Exception](e: T) {
    raise ValueError("v") from e;
}

# Rejected: the type parameter itself.
def raise_type_param[T: Exception](e: T) {
    raise T;  # <-- E1090
}

def raise_from_type_param[T: Exception](e: T) {
    raise ValueError("t") from T;  # <-- E1161
}

obj Box[T: Exception] {
    def fail(e: T) {
        raise T;  # <-- E1090
    }
}
