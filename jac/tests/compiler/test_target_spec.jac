"""A release target is one TargetSpec, named by osarch or by any triple.

The kernel build reads its target from this table rather than the host, so a
host's default triple (which carries its OS version) never reaches an
artifact, and a kernel for another target lands beside, not over, the
host's own.
"""
import os;
import from jaclang.compiler.target_spec {
    RELEASE_TARGETS,
    UnknownTarget,
    host_target_spec,
    target_spec,
    triple_osarch
}
import from jaclang.compiler.backends.native.kernel_resolve {
    kernel_path_for,
    source_tree_kernel_path
}

test "a target is found by osarch or by any spelling of its triple" {
    assert target_spec("linux-aarch64").triple == "aarch64-unknown-linux-gnu";
    assert target_spec("aarch64-unknown-linux-gnu").osarch == "linux-aarch64";
    assert target_spec("arm64-apple-darwin25.5.0").triple == "arm64-apple-macosx11.0.0";
    assert target_spec("x86_64-apple-macosx10.15.0").osarch == "macos-x86_64";
    assert target_spec("x86_64-pc-windows-msvc").cpython_platform == "win32";
    assert triple_osarch("x86_64-unknown-linux-gnu") == "linux-x86_64";
}

test "every release target names its kernel the way its loader looks for it" {
    names = {spec.osarch: spec.kernel_file_name() for spec in RELEASE_TARGETS};
    assert names["linux-x86_64"] == "libjac_compiler.so";
    assert names["macos-aarch64"] == "libjac_compiler.dylib";
    assert names["windows-x86_64"] == "jac_compiler.dll";
    osarches = [spec.osarch for spec in RELEASE_TARGETS];
    assert len(osarches) == len(set(osarches));
}

test "an unknown target is refused, not guessed" {
    for name in [
        "plan9-mips",
        "riscv64-unknown-linux-gnu",
        "wasm32-unknown-unknown",
        ""
    ] {
        raised = False;
        try {
            target_spec(name);
        } except UnknownTarget {
            raised = True;
        }
        assert raised , name;
    }
}

test "the host's kernel stays in place and another target's lands beside it" {
    host = host_target_spec();
    assert kernel_path_for(host) == source_tree_kernel_path();
    other = target_spec(
        "linux-aarch64" if host.osarch != "linux-aarch64" else "linux-x86_64"
    );
    path = kernel_path_for(other);
    assert path.endswith(
        os.path.join("compiler", "kernels", other.osarch, other.kernel_file_name())
    ) , path;
}
