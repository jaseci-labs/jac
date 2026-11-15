"""A release target is one TargetSpec, named by osarch or by any triple."""
import from jaclang.compiler.target_spec {
    RELEASE_TARGETS,
    UnknownTarget,
    target_spec,
    triple_osarch
}

test "a target is found by osarch or by any spelling of its triple" {
    assert target_spec("linux-aarch64").triple == "aarch64-unknown-linux-gnu";
    assert target_spec("aarch64-unknown-linux-gnu").osarch == "linux-aarch64";
    assert target_spec("arm64-apple-darwin25.5.0").triple == "arm64-apple-macosx11.0.0";
    assert target_spec("x86_64-apple-macosx10.15.0").osarch == "macos-x86_64";
    assert target_spec("x86_64-pc-windows-msvc").cpython_platform == "win32";
    assert triple_osarch("x86_64-unknown-linux-gnu") == "linux-x86_64";
}

test "every release target has its own osarch" {
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
