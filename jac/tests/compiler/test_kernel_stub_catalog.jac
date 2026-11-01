"""The kernel reads typeshed only through the stub catalog, so the catalog is
one of the kernel's build inputs: `jac native build kernel` builds it first."""

import jaclang.artifacts.router as router;

test "building the kernel builds its stub catalog first" {
    import from jaclang.compiler.backends.native.kernel_resolve { KernelArtifact }
    assert "stubcat" in KernelArtifact().requires;
    assert router.build_order(["kernel"]).index("stubcat")
        < router.build_order(["kernel"]).index("kernel");
}
