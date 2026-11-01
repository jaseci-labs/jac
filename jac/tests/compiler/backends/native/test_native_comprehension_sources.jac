"""Native comprehensions iterate every source a native for-loop iterates."""

import ctypes;
import from tests.support { compile_native, native_address }

test "comprehensions over ranges, strings, bytes, sets and adapters run natively" {
    (engine, _) = compile_native("comprehension_sources.jac");
    expected = [
        ("stepped", 307),
        ("descending", 302),
        ("over_str", 31),
        ("over_glob_literal", 31),
        ("over_bytes", 306),
        ("over_set", 222),
        ("short_circuit", 104),
        ("enumerated", 135)
    ];
    for (name, want) in expected {
        address = native_address(engine, name);
        assert isinstance(address, int) and address != 0 , name;
        got = ctypes.CFUNCTYPE(ctypes.c_int64)(address)();
        assert got == want , f"{name}: {got} != {want}";
    }
}
