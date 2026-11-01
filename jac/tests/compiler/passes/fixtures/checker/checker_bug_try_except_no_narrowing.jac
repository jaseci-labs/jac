"""Bug #30: Try/except does not type-check exception types.

The type checker has no exit_try_stmt or related methods. Exception
variables in except blocks get no type narrowing, and raising
non-exceptions is not detected.

Expected: `except ValueError as e:` should narrow e to ValueError, and
`except (A, B) as e:` to `A | B`. A raised value must be an exception (E1090)
and a `from` cause an exception or None (E1161); `any` is accepted.
"""

import from types { NoneType }

obj NotAnError {}

with entry {
    try {
        x = int("not_a_number");
    } except ValueError as e {
        # e should be narrowed to ValueError
        bad: int = e;  # <-- Should be Error (ValueError not assignable to int)
    }

    # Raising a non-exception should be an error
    try {
        raise 42;  # <-- Should be Error (int is not an exception type)
    } except Exception as e {}
}

# Accepted: each of these raises an exception (or `any`, which may be one).
def raise_any_subscript(b: dict[str, any]) {
    raise b["error"];
}

def raise_any_param(e: any) {
    raise e;
}

def raise_exception_class(t: type[ValueError]) {
    raise t;
}

def raise_any_class(c: type) {
    raise c;
}

def raise_exception_union(e: ValueError | TypeError) {
    raise e;
}

def raise_narrowed_optional(e: ValueError | None) {
    if e is not None {
        raise e;
    }
}

def raise_bounded_type_var[T: Exception](e: T) {
    raise e;
}

def raise_from_optional_exception(c: Exception | None) {
    raise ValueError("a") from c;
}

def raise_from_any(c: any) {
    raise ValueError("b") from c;
}

def raise_from_none {
    raise ValueError("c") from None;
}

def reraise_from_tuple_handler {
    try {
        raise TimeoutError("slow");
    } except (TimeoutError, RuntimeError) as exc {
        print(exc.args);
        raise RuntimeError("wrapped") from exc;
    }
}

def reraise_tuple_handler {
    try {
        raise KeyError("k");
    } except (KeyError, ValueError) as exc {
        raise exc;
    }
}

# Rejected: each raise below is an error.
def raise_non_exception_instance {
    raise NotAnError();  # <-- E1090
}

def raise_optional(e: ValueError | None) {
    raise e;  # <-- E1090
}

def raise_mixed_union(e: ValueError | int) {
    raise e;  # <-- E1090
}

def raise_from_int {
    raise ValueError("x") from 5;  # <-- E1161
}

def raise_from_nonetype_class {
    raise ValueError("y") from NoneType;  # <-- E1161
}
