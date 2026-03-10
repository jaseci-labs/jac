"""Bug #30: Try/except does not type-check exception types.

The type checker has no exit_try_stmt or related methods. Exception
variables in except blocks get no type narrowing, and raising
non-exceptions is not detected.

Expected: `except ValueError as e:` should narrow e to ValueError.
"""

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
    } except Exception as e {
        ;
    }
}
