"""A C function imported through a module that re-exports it is still a C call.

js_engine's builtins/math imports `time` from ffi/libm, which imports it from
ffi/libc's `import from "libc.so.6"` block. The call carried no resolved
callee two imports away, so MIR lowered `time(0)` as a call through a Jac
function value: it loaded a code pointer out of the first bytes of libc's
`time` and jumped there (a segfault in js_engine's init_global). The call now
resolves the callee through the import chain and lowers as the C call.
"""

import os;
import tempfile;
import from pathlib { Path }
import from tests.support { native_build, native_run }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures";

test "a re-exported C function lowers as a direct C call" {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "clib_reexport");
        native_build(str(FIXTURES / "clib_reexport_main.jac"), out_bin, memory="rc");
        assert native_run(out_bin).strip() == "42 7";
    }
}
