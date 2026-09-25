"""Exception classes raised here and caught by `exc_binding_main.jac`.

`StoreError` and `BindError` have no fields, so `raise BindError("...")`
raises the message itself; `CodedError` has a field, so its raise builds the
struct.
"""

obj:pub StoreError(Exception) {}

obj:pub BindError(StoreError) {}

obj:pub CodedError(Exception) {
    has code: int;
}

def:pub bind_value(kind: int) -> int {
    if kind == 0 {
        raise BindError("cannot bind " + str(kind));
    }
    if kind == 1 {
        raise CodedError(404);
    }
    return kind;
}
