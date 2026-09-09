"""Native source paths must retain the OS variant through dependency linking."""

import os;
import from jaclang.compiler.frontend.codeinfo {
    native_stdlib_root,
    resolve_native_module,
    set_native_target_override
}

test "sibling native errno import retains its platform filename" {
    stdlib_dir = native_stdlib_root();
    assert stdlib_dir is not None;
    prior = set_native_target_override("aarch64-apple-darwin");
    try {
        for (target, filename) in [
            ("aarch64-apple-darwin", "_errno_platform.darwin.jac"),
            ("x86_64-unknown-linux-gnu", "_errno_platform.jac")
        ] {
            set_native_target_override(target);
            (source, resolved) = resolve_native_module("_errno_platform", stdlib_dir);
            assert source is not None and resolved is not None;
            assert os.path.basename(resolved) == filename;
            assert os.path.realpath(os.path.join(stdlib_dir, source))
                == os.path.realpath(resolved);
        }
    } finally {
        set_native_target_override(prior);
    }
}
