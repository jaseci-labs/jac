"""Binary-file decoding links and runs through the native stdlib without demotion."""
import tempfile;
import zlib;
import from pathlib { Path }
import from tests.support { NATIVE_FIXTURES, native_build, native_run }

test "native file and mutable zlib buffer compose in a standalone binary" {
    with tempfile.TemporaryDirectory() as directory {
        path = Path(directory) / "binary.z";
        path.write_bytes(zlib.compress(b"\x00\xffnative\r\n" * 500));
        binary = str(Path(directory) / "probe");
        native_build(str(Path(NATIVE_FIXTURES) / "path_zlib_probe.jac"), binary);
        assert "NATIVE FILE ZLIB PASS" in native_run(binary, args=[str(path)]);
    }
}
