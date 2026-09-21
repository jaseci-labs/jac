"""Path.read_bytes preserves binary data and native filesystem error behavior."""
import ctypes;
import os;
import tempfile;
import from pathlib { Path }
import from tests.support { compile_native, native_str_func }

test "native Path.read_bytes preserves complete bytes and closes files on errors" {
    (engine, _) = compile_native("path_read_bytes.jac");
    read_error = native_str_func(engine, "read_error", ctypes.c_int64, ctypes.c_char_p);
    read_pattern = native_str_func(
        engine, "read_pattern", ctypes.c_bool, ctypes.c_char_p, ctypes.c_int64
    );
    with tempfile.TemporaryDirectory() as directory {
        folder = Path(directory);
        regular = folder / "binary-é.dat";
        for size in [0, 1, 256, 65535, 65536, 65537, 200003] {
            regular.write_bytes(bytes([i % 256 for i in range(size)]));
            assert read_pattern(str(regular), size);
        }
        regular.write_bytes(b"\x00\xff\x80\r\n");
        assert read_error(str(folder / "missing").encode()) == 1;
        assert read_error(str(regular / "child").encode()) == 2;
        assert read_error((str(regular) + "\x00suffix").encode()) == 4;
        before = os.open(str(regular), os.O_RDONLY);
        os.close(before);
        for _ in range(100) {
            assert read_error(directory.encode()) == 3;
            assert read_error(str(regular)) == 0;
        }
        after = os.open(str(regular), os.O_RDONLY);
        try {
            assert after == before , "read_bytes leaked a file descriptor";
        } finally {
            os.close(after);
        }
        if os.geteuid() != 0 {
            regular.chmod(0);
            try {
                assert read_error(str(regular).encode()) == 5;
            } finally {
                regular.chmod(0o600);
            }
        }
    }
}
