import from jaclang.runtimelib.utils { release_arch, host_arch, triple_arch }


test "release_arch normalizes GOARCH aliases to release names" {
    assert release_arch("amd64") == "x86_64";
    assert release_arch("x86_64") == "x86_64";
    assert release_arch("arm64") == "aarch64";
    assert release_arch("aarch64") == "aarch64";
}


test "release_arch is case-insensitive and strips whitespace" {
    assert release_arch("  ARM64 ") == "aarch64";
    assert release_arch("X86_64") == "x86_64";
}


test "release_arch passes unknown arches through, lowercased" {
    assert release_arch("Windows-ARM64") == "windows-arm64";
    assert release_arch("riscv64") == "riscv64";
}


test "release_arch is a pure normalizer: empty in, empty out" {
    # It must NOT fall back to the host arch on empty input -- callers rely on
    # "" to drop nodes with missing architecture info (scale cluster_node_archs).
    assert release_arch("") == "";
    assert release_arch("   ") == "";
}


test "host_arch reports the running machine's arch" {
    assert host_arch() in ("x86_64", "aarch64");
}


test "triple_arch reads the arch out of a target triple" {
    assert triple_arch("aarch64-apple-darwin") == "aarch64";
    assert triple_arch("arm64-apple-darwin") == "aarch64";
    assert triple_arch("x86_64-unknown-linux-gnu") == "x86_64";
}


test "triple_arch defaults to x86_64 when no arch token is present" {
    assert triple_arch("unknown-triple") == "x86_64";
}
