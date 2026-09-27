"""A spawn's report list is handed to the walker, not pinned for the life of
the program: each spawn used to leak its list and everything reported."""

import ctypes;
import from tests.support { compile_native, get_func }

test "reports from every spawn are reclaimed with the walker" {
    (engine, _) = compile_native("spawn_reports_reclaim.jac");
    run = get_func(engine, "run", ctypes.c_int64, ctypes.c_int64);
    assert run(6) == 6;
    dropped = get_func(engine, "read_dropped", ctypes.c_int64);
    assert dropped() == 6;
}

test "a walker spawned again keeps the earlier list readable" {
    (engine, _) = compile_native("spawn_reports_reclaim.jac");
    respawn = get_func(engine, "respawn", ctypes.c_int64);
    assert respawn() == 11;
    dropped = get_func(engine, "read_dropped", ctypes.c_int64);
    assert dropped() == 2;
}

test "nested spawn reports still reach the outer walker" {
    (engine, _) = compile_native("spawn_reports_reclaim.jac");
    nested = get_func(engine, "nested", ctypes.c_int64);
    assert nested() == 1;
}
