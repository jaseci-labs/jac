import ctypes;
import from tests.support { compile_native, get_func }

test "tagged object fields release their owned payloads" {
    (engine, module) = compile_native("any_field_lifetime.jac");
    release = get_func(engine, "release_field", None);
    count = get_func(engine, "drop_count", ctypes.c_int64);
    before = count();
    release();
    assert count() == before + 2;
}

test "cycle tracing follows tagged object fields" {
    (engine, module) = compile_native("any_field_lifetime.jac");
    address = engine.get_global_value_address("__rc_cycles_enabled");
    assert isinstance(address, int) and address;
    ctypes.cast(address, ctypes.POINTER(ctypes.c_uint8))[0] = 1;
    make_cycle = get_func(engine, "make_cycle", None);
    collect = get_func(engine, "collect", None);
    count = get_func(engine, "drop_count", ctypes.c_int64);
    before = count();
    make_cycle();
    collect();
    assert count() == before + 2;
}

test "tagged field replacement retains borrowed payloads before releasing old values" {
    (engine, module) = compile_native("any_field_lifetime.jac");
    run = get_func(engine, "borrowed_field", ctypes.c_int64);
    count = get_func(engine, "drop_count", ctypes.c_int64);
    before = count();
    assert run() == 1;
    assert count() == before + 2;
}
