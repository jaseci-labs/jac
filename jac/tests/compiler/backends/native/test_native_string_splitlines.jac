"""Native splitlines handles all line boundaries and dynamic keepends."""
import ctypes;
import tempfile;
import from pathlib { Path }
import from tests.support {
    compile_native,
    get_func,
    NATIVE_FIXTURES,
    native_build,
    native_run
}

test "native splitlines preserves Python line boundary semantics" {
    (engine, _) = compile_native("string_splitlines.jac");
    check = get_func(engine, "line_checks", ctypes.c_bool, ctypes.c_bool);
    for _ in range(30) {
        assert check(False);
        assert check(True);
    }
}


test "splitlines retains semantics in a standalone native binary" {
    with tempfile.TemporaryDirectory() as directory {
        binary = str(Path(directory) / "splitlines");
        native_build(str(Path(NATIVE_FIXTURES) / "string_splitlines.jac"), binary);
        assert "SPLITLINES PASS" in native_run(binary);
    }
}
