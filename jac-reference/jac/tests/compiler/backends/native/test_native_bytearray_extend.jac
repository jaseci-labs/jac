"""Regression coverage for checked list-to-bytearray extension."""
import ctypes;
import from tests.support { compile_native, get_func }

glob _ENGINES: list[any] = [];
def engine -> any {
    if not _ENGINES {
        (eng, _) = compile_native("bytearray_extend.jac");
        _ENGINES.append(eng);
    }
    return _ENGINES[0];
}

test "bytearray extend accepts ordinary and sized integer lists" {
    extend = get_func(engine(), "extend_values", ctypes.c_int64, ctypes.c_int64);
    for value in [0, 1, 127, 128, 255] {
        assert extend(value) == value;
    }
    assert get_func(engine(), "typed_and_inline", ctypes.c_bool)();
}

test "bytearray extend checks the entire list before mutation" {
    invalid = get_func(engine(), "invalid_values", ctypes.c_bool, ctypes.c_int64);
    for value in [-9223372036854775807, -256, -1, 256, 65536, 9223372036854775807] {
        assert invalid(value);
    }
}

test "bytearray extend evaluates an owned source exactly once" {
    check = get_func(engine(), "source_once", ctypes.c_bool);
    for _ in range(100) {
        assert check();
    }
}

test "bytearray extend preserves raw buffers and self aliases" {
    check = get_func(engine(), "buffers_and_aliases", ctypes.c_bool);
    for _ in range(100) {
        assert check();
    }
}
