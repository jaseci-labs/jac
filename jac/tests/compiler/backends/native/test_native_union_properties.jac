"""Union property access uses each concrete class's accessor and layout."""

import ctypes;
import from tests.support { compile_native }

test "unrelated union members dispatch their collection properties" {
    (engine, _) = compile_native("union_properties.jac");
    address = engine.get_function_address("probe");
    assert address != 0;
    probe = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(address);
    assert probe(0) == 7;
    assert probe(1) == 10;
    assert probe(2) == 22;
}
