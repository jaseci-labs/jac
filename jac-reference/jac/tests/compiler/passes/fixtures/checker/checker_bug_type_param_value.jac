"""A type parameter used as a value.

A type parameter names a type for the checker only. The Python backend
drops a function's type parameters, so `T` used as a value fails at runtime
with `NameError: name 'T' is not defined`, and inside a class it is a bare
`TypeVar`, not the class it stands for. Every value use of a type parameter
is E1163; type positions, values of type `T` or `type[T]`, and comptime
parameters are accepted.
"""

import from typing { cast }

# Accepted: type positions and values whose type is the type parameter.
def raise_type_param_value[T: Exception](e: T) {
    raise e;
}

def raise_type_param_class[T: Exception](t: type[T]) {
    raise t;
}

def raise_from_type_param_value[T: Exception](e: T) {
    raise ValueError("v") from e;
}

def annotated[T](e: T) -> list[T] {
    x: T = e;
    y = e as T;
    return [x, y];
}

obj Holder[T] {
    has item: T;
}

obj Child[T](Holder[T]) {}

type Pair[U] = tuple[U, U];

obj Grid[T, comptime cols: int] {
    def width -> int {
        return cols;
    }
}

# Rejected: the type parameter itself, wherever it is used as a value.
def raise_type_param[T: Exception](e: T) {
    raise T;  # <-- E1163
}

def raise_from_type_param[T: Exception](e: T) {
    raise ValueError("t") from T;  # <-- E1163
}

def raise_parenthesized_type_param[T: Exception](e: T) {
    raise (T);  # <-- E1163
}

def return_type_param[T: Exception](e: T) -> any {
    return T;  # <-- E1163
}

def assign_type_param[T: Exception](e: T) -> any {
    x = T;  # <-- E1163
    return x;
}

def isinstance_type_param[T: Exception](e: object) -> bool {
    return isinstance(e, T);  # <-- E1163
}

def raise_through_variable[T: Exception](e: T) {
    y = (T);  # <-- E1163
    raise y;
}

def cast_type_param[T](v: object) -> T {
    return cast(T, v);  # <-- E1163
}

obj Box[T: Exception] {
    def fail(e: T) {
        raise T;  # <-- E1163
    }

    def kind -> any {
        return T;  # <-- E1163
    }
}
