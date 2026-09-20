"""Contextual Python arguments construct interpreter containers and builtin values."""
import ctypes;
import from tests.support { compile_native, get_func }

test "Python calls construct literal containers and preserve nested object identity" {
    (engine, _) = compile_native("python_literal_arguments.jac", required=True);
    for name in ["literal_arguments", "builtin_arguments", "slice_arguments"] {
        call = get_func(engine, name, ctypes.c_bool);
        for _ in range(100) {
            assert call() , name;
        }
    }
    invalid = get_func(engine, "invalid_slice", ctypes.c_int64);
    for _ in range(100) {
        try {
            invalid();
            assert False , "a zero slice step must preserve Python's ValueError";
        } except ValueError as error {
            assert "slice step" in str(error);
        }
    }
}
