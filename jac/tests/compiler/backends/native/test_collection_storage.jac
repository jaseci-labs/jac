"""The production collection path executes the shared Jac storage kernel."""

import ctypes;
import from tests.support { compile_native, get_func }

test "Jac storage growth preserves values and releases each element once" {
    (engine, module) = compile_native("collection_storage.jac");
    assert "__jac_array_append" in str(module.gen.native_linked_ir);
    assert "__jac_array_grow" in str(module.gen.native_linked_ir);
    integers = get_func(engine, "integers", ctypes.c_int64);
    references = get_func(engine, "references", ctypes.c_int64);
    mixed = get_func(engine, "mixed", ctypes.c_int64);
    bytes_growth = get_func(engine, "bytes_growth", ctypes.c_int64);
    read_drops = get_func(engine, "read_drops", ctypes.c_int64);
    for _ in range(3) {
        assert integers() == 32640;
        assert references() == 8128;
        assert read_drops() == 128;
        assert mixed() == 4032;
        assert read_drops() == 64;
        assert bytes_growth() == 1022;
    }
}
