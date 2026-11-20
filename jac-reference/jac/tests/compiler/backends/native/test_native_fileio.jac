"""The bundled `io.FileIO` must read exactly what CPython's raw file reads.

One fixture runs on both pathways from a scratch directory: `import io` binds
CPython's `io` on the sv pathway and `na_stdlib/io.jac` on the na pathway, so
identical stdout is the congruence contract for `read(n)`, `read()`,
`readall()`, `seek` over every `whence`, `tell`, and the closed and missing
file errors.
"""
import os;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { jac_command }

glob FIXTURE = str(
         Path(__file__).resolve().parent / "fixtures" / "fileio_probe.jac"
     );

test "the native FileIO answers what CPython's FileIO answers" {
    with tempfile.TemporaryDirectory() as directory {
        binary = os.path.join(directory, "fileio.bin");
        build = subprocess.run(
            jac_command("build", "--native", FIXTURE, "-o", binary),
            capture_output=True,
            text=True,
            timeout=900
        );
        assert build.returncode == 0 , (build.stdout + build.stderr)[-3000:];
        native = subprocess.run(
            [binary], cwd=directory, capture_output=True, text=True, timeout=120
        );
        server = subprocess.run(
            jac_command("run", "--backend", "python", FIXTURE),
            cwd=directory,
            capture_output=True,
            text=True,
            timeout=900
        );
        assert native.returncode == 0 , native.stdout + native.stderr;
        assert server.returncode == 0 , server.stdout + server.stderr;
        assert server.stdout.strip() , "sv pathway produced no output";
        assert native.stdout == server.stdout , f"na:\n{native.stdout}\nsv:\n{server.stdout}";
    }
}
