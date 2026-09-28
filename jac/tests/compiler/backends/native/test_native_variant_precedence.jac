"""A native module resolves to its most specific platform variant.

`<name>.<os>.<arch>.jac` wins over `<name>.<arch>.jac`, which wins over
`<name>.<os>.jac`, which wins over `<name>.jac`, all chosen by the native
target rather than the host.
"""
import os;
import tempfile;
import from jaclang.compiler.frontend.codeinfo {
    set_native_target_override,
    _native_variant_path
}

test "the most specific platform variant of a native module wins" {
    with tempfile.TemporaryDirectory() as scratch {
        base = os.path.join(scratch, "records");
        for suffix in ["", ".linux", ".x86_64", ".linux.x86_64"] {
            with open(base + suffix + ".jac", "w") as handle {
                handle.write("");
            }
        }
        for (target, variant) in [
            ("x86_64-unknown-linux-gnu", "records.linux.x86_64.jac"),
            ("aarch64-unknown-linux-gnu", "records.linux.jac"),
            ("x86_64-apple-darwin", "records.x86_64.jac"),
            ("arm64-apple-darwin", "records.jac")
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
        }
    }
}
