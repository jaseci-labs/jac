impl InteropBinding.is_cross_module.getter -> bool {
    return (self.source_module is not None);
}

impl InteropManifest.boundary_types_for(scope: str) -> dict[str, BoundaryTypeInfo] {
    return {
        name: self.boundary_types[type_id]
        for (name, type_id) in self.boundary_type_names.get(scope, {}).items()
    };
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

impl InteropManifest.native_dependency_sources.getter -> list[str] {
    sources = self.native_transitive_sources.copy();
    for binding in self.native_cross_module_imports {
        source = binding.source_module;
        if source is not None and source not in sources {
            sources.append(source);
        }
    }
    return sources;
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
        import jaclang.compiler.tools.doc_ir as doc;
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

impl ClientArtifact.to_bytes -> bytes {
    import pickle;
    return pickle.dumps(
        (
            3,
            self.js,
            self.manifest,
            list(self.native_import_sources),
            list(self.source_map),
            dict(self.dep_digests),
            self.framework,
            self.boundary_contracts
        ),
        int(pickle.HIGHEST_PROTOCOL)
    );
}

impl ClientArtifact.from_bytes(raw: bytes) -> (ClientArtifact | None) {
    import pickle;
    try {
        (
            version,
            js,
            manifest,
            native_import_sources,
            source_map,
            dep_digests,
            framework,
            boundary_contracts
        ) = pickle.loads(raw);
    } except Exception {
        return None;
    }
    if version != 3
        or not isinstance(js, str)
        or not isinstance(manifest, ClientManifest) {
        return None;
    }
    return ClientArtifact(
        js=js,
        manifest=manifest,
        native_import_sources=[str(s) for s in native_import_sources],
        source_map=[tuple(seg) for seg in source_map],
        dep_digests={str(k): str(v) for (k, v) in dict(dep_digests).items()},
        framework=str(framework),
        boundary_contracts=dict(boundary_contracts)
    );
}
