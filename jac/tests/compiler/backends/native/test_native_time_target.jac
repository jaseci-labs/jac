"""Clock IDs follow the target libc even when cross compiling.

The bundled `time` module reads its clocks through a per-platform
`_time_native` unit; the variant is chosen by the native target, not the host,
so a cross build links the target libc's clock IDs.
"""
import os;
import re;
import from jaclang.compiler.frontend.codeinfo {
    native_stdlib_root,
    set_native_target_override,
    _native_variant_path
}

test "native clocks use the target libc clock IDs" {
    stdlib = native_stdlib_root();
    assert stdlib is not None;
    base = os.path.join(stdlib, "_time_native");
    for (target, variant, monotonic) in [
        ("x86_64-unknown-linux-gnu", "_time_native.linux.jac", "1"),
        ("aarch64-unknown-linux-gnu", "_time_native.linux.jac", "1"),
        ("x86_64-apple-darwin", "_time_native.darwin.jac", "6"),
        ("arm64-apple-darwin", "_time_native.darwin.jac", "6")
    ] {
        prev = set_native_target_override(target);
        try {
            chosen = _native_variant_path(base);
        } finally {
            set_native_target_override(prev);
        }
        assert chosen is not None and os.path.basename(chosen) == variant , (
            f"{target}: {chosen}"
        );
        with open(chosen) as handle {
            text = handle.read();
        }
        found = re.search(r"CLK_MONOTONIC: int = (\d+)", text);
        assert found is not None and found.group(1) == monotonic , (
            f"{target}: CLK_MONOTONIC in {variant}"
        );
    }
}
