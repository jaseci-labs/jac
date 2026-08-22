impl InteropBinding.is_cross_module.getter -> bool {
    return (self.source_module is not None);
}

impl InteropManifest.native_imports.getter -> list[InteropBinding] {
    return [
        b
        for b in self.bindings.values()
        if (
            (b.source_context == InteropContext.SERVER)
            and (InteropContext.NATIVE in b.callers)
        )
    ];
}

impl InteropManifest.native_exports.getter -> list[InteropBinding] {
    return [
        b
        for b in self.bindings.values()
        if (
            (b.source_context == InteropContext.NATIVE)
            and (InteropContext.SERVER in b.callers)
        )
    ];
}

impl InteropManifest.native_cross_module_imports.getter -> list[InteropBinding] {
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

impl InteropManifest.client_native_imports.getter -> list[InteropBinding] {
    return [
        b
        for b in self.bindings.values()
        if (
            (b.source_context == InteropContext.NATIVE)
            and (InteropContext.CLIENT in b.callers)
        )
    ];
}

impl InteropManifest.server_exports_to_client.getter -> list[InteropBinding] {
    return [
        b
        for b in self.bindings.values()
        if (
            (b.source_context == InteropContext.SERVER)
            and (InteropContext.CLIENT in b.callers)
        )
    ];
}

impl InteropManifest.server_exports_to_server.getter -> list[InteropBinding] {
    return [
        b
        for b in self.bindings.values()
        if (
            (b.source_context == InteropContext.SERVER)
            and (InteropContext.SERVER in b.callers)
            and (b.source_module is not None)
        )
    ];
}

impl CodeGenTarget.doc_ir.getter -> Doc {
    if (self._doc_ir is None) {
        import jaclang.compiler.passes.tool.doc_ir as doc;
        self._doc_ir = doc.Text('');
    }
    return self._doc_ir;
}

impl CodeGenTarget.doc_ir.setter(value: Doc) {
    self._doc_ir = value;
}

impl CodeGenTarget.client_manifest.getter -> ClientManifest {
    if (self._client_manifest is None) {
        self._client_manifest = ClientManifest();
    }
    return self._client_manifest;
}

impl CodeGenTarget.client_manifest.setter(value: ClientManifest) -> None {
    self._client_manifest = value;
}

impl CodeGenTarget.interop_manifest.getter -> InteropManifest {
    if (self._interop_manifest is None) {
        self._interop_manifest = InteropManifest();
    }
    return self._interop_manifest;
}

impl CodeGenTarget.interop_manifest.setter(value: InteropManifest) -> None {
    self._interop_manifest = value;
}
