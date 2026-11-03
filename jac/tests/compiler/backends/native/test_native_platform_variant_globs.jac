"""A portable module's glob reads the selected platform variant's value.

The type checker binds a portable module such as errno_constants.jac, whose
globs are 0 for a platform without a variant; the build links the variant
for its target. A glob read, mutable or Final, takes the variant's value,
as JacPython's errno map does when it registers FileNotFoundError."""

import ctypes;
import errno;
import sys;
import platform;
import re;
import from tests.support { compile_native, compile_native_ir, get_func }

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

test "a constant-sized __alloca folds its platform variant's size" {
    # pthread_attr_t is 56 bytes on x86_64 Linux and 64 on aarch64 and macOS;
    # the portable layouts_platform holds 0, a one-word buffer that
    # pthread_attr_init overruns into the caller's saved registers.
    if not sys.platform.startswith("linux") and sys.platform != "darwin" {
        testskip("no platform variant for this host");
    }
    words = 7
        if sys.platform.startswith("linux")
            and platform.machine() in ("x86_64", "AMD64")
        else 8;
    text = str(compile_native_ir("platform_variant_globs.jac").gen.llvm_ir);
    body = text[text.index("attr_buffer"):];
    body = body[:body.index("\n}")];
    assert re.search(rf"alloca \[{words} x i64\]", body) , body;
}
