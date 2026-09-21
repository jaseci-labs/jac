"""Compiler-generated and native stdlib foreign calls share address representations."""
import tempfile;
import from pathlib { Path }
import from tests.support { NATIVE_FIXTURES, native_build, native_run }

test "native pathlib enumeration composes with lowered os.listdir" {
    with tempfile.TemporaryDirectory() as directory {
        (Path(directory) / "present.bin").write_bytes(b"\x00\xff");
        binary = str(Path(directory) / "probe");
        native_build(str(Path(NATIVE_FIXTURES) / "extern_directory_abi.jac"), binary);
        assert "EXTERN DIRECTORY ABI PASS" in native_run(binary, args=[directory]);
    }
}
