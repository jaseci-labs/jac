"""os.environ is a mutable mapping natively, as on the Python backend.

`os.environ[key] = value` sets the process environment (a child shell sees
it), `del` and `pop` unset it, `in` tests membership, and a missing key, an
illegal name or an embedded null raises as CPython does. The launcher binds
its runtime through these (SSL_CERT_FILE, JAC_STANDALONE); getpid and rename
complete the os calls it makes."""

import os;
import tempfile;
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "os.environ mutation matches the Python backend" {
    fixture = str(
        Path(__file__).resolve().parent / "fixtures" / "os_environ_mutation.jac"
    );
    with tempfile.TemporaryDirectory() as directory {
        start = os.getcwd();
        os.chdir(directory);
        try {
            out = assert_native_identity(fixture, profiles=["rc"]);
        } finally {
            os.chdir(start);
        }
    }
    lines = out.splitlines();
    assert "read set set" in lines , out;
    assert "in True False" in lines , out;
    assert "child 0" in lines , out;
    assert "deleted gone" in lines , out;
    assert "pop popped default" in lines , out;
    assert "read KeyError" in lines
        and "delete KeyError" in lines
        and "pop KeyError" in lines , out;
    assert "name ValueError illegal environment variable name" in lines , out;
    assert "renamed True False" in lines , out;
    assert "rename missing [Errno 2] No such file or directory: 'rename_probe.src' -> 'rename_probe.dst'"
        in lines , out;
}
