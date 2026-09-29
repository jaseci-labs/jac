"""Native asset operations retain ordinary string, bytearray and os semantics."""
import ctypes;
import os;
import tempfile;
import from pathlib { Path }
import from tests.support { compile_native, get_func, native_str_func }

glob _ENGINES: list[any] = [];
def engine -> any {
    if not _ENGINES {
        (eng, _) = compile_native("asset_operations.jac");
        _ENGINES.append(eng);
    }
    return _ENGINES[0];
}

test "whitespace split handles limits Unicode and empty inputs" {
    check = get_func(engine(), "whitespace_checks", ctypes.c_bool);
    for _ in range(30) {
        assert check();
    }
}

test "bytearray indexed writes validate ordinary integers" {
    write = get_func(engine(), "byte_write", ctypes.c_int64, ctypes.c_int64);
    bad = get_func(engine(), "byte_bad", ctypes.c_bool, ctypes.c_int64);
    for value in [0, 1, 127, 128, 255] {
        assert write(value) == value * 2;
    }
    for value in [-1, 256, 65536] {
        assert bad(value);
    }
}

test "listdir copies names omits dots and handles filesystem errors" {
    check = native_str_func(
        engine(), "directory_checks", ctypes.c_bool, ctypes.c_char_p
    );
    error = native_str_func(
        engine(), "directory_error", ctypes.c_int64, ctypes.c_char_p
    );
    with tempfile.TemporaryDirectory() as temp {
        folder = Path(temp);
        for name in [".hidden", "PAK0.PAK", "é.txt"] {
            (folder / name).touch();
        }
        (folder / "subdir").mkdir();
        for _ in range(100) {
            assert check(temp.encode());
        }
        assert error(str(folder / "absent").encode()) == 1;
        assert error(str(folder / "PAK0.PAK").encode()) == 2;
        assert error((temp + "\x00ignored").encode()) == 3;
    }
    assert get_func(engine(), "directory_default", ctypes.c_bool)();
}
