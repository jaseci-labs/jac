"""A walker event ability named `drop` is not a destructor hook."""

import ctypes;
import from tests.support { compile_native, get_func }

test "event ability named drop lowers and runs natively" {
    (engine, _) = compile_native("walker_drop_ability.jac");
    fly_over = get_func(engine, "fly_over", ctypes.c_int64);
    assert fly_over() == 7;
    load_things = get_func(engine, "load_things", ctypes.c_int64, ctypes.c_int64);
    assert load_things(5) == 10;
}

test "def drop beside an event ability named drop still runs as a destructor" {
    (engine, _) = compile_native("walker_drop_ability.jac");
    release = get_func(engine, "release_crate", None);
    count = get_func(engine, "drop_count", ctypes.c_int64);
    before = count();
    release();
    assert count() == before + 5;
}
