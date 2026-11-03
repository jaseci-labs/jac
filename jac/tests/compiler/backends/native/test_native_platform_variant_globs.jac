"""A portable module's glob reads the selected platform variant's value.

The type checker binds a portable module such as errno_constants.jac, whose
globs are 0 for a platform without a variant; the build links the variant
for its target. A glob read, mutable or Final, takes the variant's value,
as JacPython's errno map does when it registers FileNotFoundError."""

import ctypes;
import errno;
import sys;
import from tests.support { compile_native, get_func }

test "a portable glob reads its platform variant's value" {
    if not sys.platform.startswith("linux") and sys.platform != "darwin" {
        testskip("no platform variant for this host");
    }
    (engine, _) = compile_native("platform_variant_globs.jac");
    pair = get_func(engine, "errno_pair", ctypes.c_int64);
    layout = get_func(engine, "layout_eagain", ctypes.c_int64);
    assert pair() == errno.EAGAIN * 1000 + errno.ENOENT;
    assert layout() == errno.EAGAIN;
}
