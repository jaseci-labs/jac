"""Implementation for codeinfo constructs."""

"""True if the bridge is a single hop (e.g. sv→na)."""
@ property
impl InteropBinding.is_direct(self: InteropBinding) -> bool {
    return (len(self.route) == 2);
}

"""True if the bridge requires multiple hops (e.g. cl→sv→na)."""
@ property
impl InteropBinding.is_composed(self: InteropBinding) -> bool {
    return (len(self.route) > 2);
}

"""True if the function is imported from another module."""
@ property
impl InteropBinding.is_cross_module(self: InteropBinding) -> bool {
    return (self.source_module is not None);
}

"""Server (Python) functions that native code calls."""
@ property
impl InteropManifest.native_imports(self: InteropManifest) -> list[InteropBinding] {
    return [
        b
        for b in self.bindings.values()
        if (
            (b.source_context == InteropContext.SERVER)
            and (InteropContext.NATIVE in b.callers)
        )
    ];
}

"""Native functions that server (Python) code calls."""
@ property
impl InteropManifest.native_exports(self: InteropManifest) -> list[InteropBinding] {
    return [
        b
        for b in self.bindings.values()
        if (
            (b.source_context == InteropContext.NATIVE)
            and (InteropContext.SERVER in b.callers)
        )
    ];
}

"""Native functions imported from other .na.jac modules."""
@ property
impl InteropManifest.native_cross_module_imports(
    self: InteropManifest
) -> list[InteropBinding] {
    return [
        b
        for b in self.bindings.values()
        if (
            (b.source_context == InteropContext.NATIVE)
            and (InteropContext.NATIVE in b.callers)
            and (b.source_module is not None)
        )
    ];
}

"""Server functions that client (JS) code calls."""
@ property
impl InteropManifest.server_exports_to_client(
    self: InteropManifest
) -> list[InteropBinding] {
    return [
        b
        for b in self.bindings.values()
        if (
            (b.source_context == InteropContext.SERVER)
            and (InteropContext.CLIENT in b.callers)
        )
    ];
}
