"""Runtime edge classes must lower natively, including their constructors."""
import ctypes;
import from tests.support { compile_native, get_func }

test "runtime edge classes connect query and delete" {
    (engine, _) = compile_native("dynamic_edge_types.jac");
    probe = get_func(engine, "probe", ctypes.c_int64, ctypes.c_bool);
    assert probe(True) == 211;
    assert probe(False) == 211;
    for (name, expected) in [
        ("constructors", 71309),
        ("predicates", 71),
        ("evaluated_once", 11),
        ("invalid_constructor", 10),
        ("initializer_error", 10),
        ("unbounded_types", 1),
        ("invalid_type", 10),
        ("imported_types", 121),
        ("stored_types", 11),
        ("typed_endpoints", 42),
        ("typed_collections", 25)
    ] {
        actual = get_func(engine, name, ctypes.c_int64)();
        assert actual == expected , f"{name}: expected {expected}, got {actual}";
    }
}
