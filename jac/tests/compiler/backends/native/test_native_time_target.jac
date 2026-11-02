"""Clock IDs come from the target's floor, not from a per-target unit.

The bundled `time` module is one unit on every target: `_time_native` asks the
runtime floor (posix_floor.c, win_floor.c) for the target libc's clock IDs at
run time, so a build for any target lowers the same unit and still reads the
clocks CPython names on that target.
"""
import os;
import from pathlib { Path }
import from jaclang.compiler.frontend.codeinfo {
    native_stdlib_root,
    set_native_target_override,
    _native_variant_path
}
import from tests.support { assert_native_identity }

test "the clock unit is the same file for every target" {
    stdlib = native_stdlib_root();
    assert stdlib is not None;
    base = os.path.join(stdlib, "_time_native");
    for target in [
        "x86_64-unknown-linux-gnu",
        "aarch64-unknown-linux-gnu",
        "x86_64-apple-macosx10.15.0",
        "arm64-apple-macosx11.0.0"
    ] {
        prev = set_native_target_override(target);
        try {
            chosen = _native_variant_path(base);
        } finally {
            set_native_target_override(prev);
        }
        assert chosen is not None and os.path.basename(chosen) == "_time_native.jac" , (
            f"{target}: {chosen}"
        );
    }
}

test "native clock IDs are the ones CPython names on this host" {
    source = str(Path(__file__).resolve().parent / "fixtures" / "time_clock_ids.jac");
    out = assert_native_identity(source, profiles=["managed"]);
    assert out.splitlines()[-1] == "True" , out;
}
