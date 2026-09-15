"""Union property access uses each concrete class's accessor and layout."""

import ctypes;
import from tests.support { compile_native, get_func }

test "unrelated union members dispatch their collection properties" {
    (engine, _) = compile_native("union_properties.jac");
    probe = get_func(engine, "probe", ctypes.c_int64, ctypes.c_int64);
    assert probe(0) == 7;
    assert probe(1) == 10;
    assert probe(2) == 22;
}

test "union field writes respect concrete offsets and optional ownership" {
    (engine, _) = compile_native("union_field_assignment.jac");
    address = engine.get_function_address("probe");
    assert address != 0;
    probe = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(address);
    assert probe(0) == 59;
    assert probe(1) == 72;
}
