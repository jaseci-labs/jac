"""Native iteration consumes types recorded for whole binding patterns."""

import ctypes;
import from tests.support { compile_native, get_func }

test "tuple iteration targets retain analysis types and execute natively" {
    (engine, _) = compile_native("iteration_facts.jac");
    for (name, expected) in [("comprehension", 21), ("loop", 17)] {
        assert get_func(engine, name, ctypes.c_int64)() == expected , name;
    }
}
