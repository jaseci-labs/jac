"""Regression test: multi-file `jac fmt` must actually engage its process
pool.

The pool wrapper used to be built as `lambda (**kw) { ... }`, which compiled
to a lambda that accepts no keyword arguments; constructing the pool then
raised TypeError inside a broad `except`, silently degrading every multi-file
format run to serial on any platform where a "fork" context is selected
(macOS/Linux). The parallel path is observable only through its progress
message format (`Formatting [N/M] completed...` vs the serial
`Formatting <path>...`), so that is what is pinned here, along with the
absence of the explicit fallback notice.
"""

import contextlib;
import io;
import shutil;
import tempfile;
import from pathlib { Path }

import from jaclang.cli.commands.analysis { format }

glob FORMATTED = "def f(x: int) -> int {\n    return x + 1;\n}\n";

test "multi-file fmt engages the parallel pool" {
    tmp = tempfile.mkdtemp(prefix="jac-fmt-parallel-test-");
    try {
        for i in range(3) {
            (Path(tmp) / f"f{i}.jac").write_text(FORMATTED);
        }
        buf = io.StringIO();
        with contextlib.redirect_stdout(buf) {
            ret = format([tmp], check=True);
        }
        out = buf.getvalue();
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
    assert ret == 0 , f"clean formatted files must pass --check: {out}";
    assert "falling back to serial" not in out , "pool construction failed and fmt "
    "silently degraded to serial";
    assert "completed..." in out , "parallel progress marker missing -- the "
    "process pool did not engage";
}
