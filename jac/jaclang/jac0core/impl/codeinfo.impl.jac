impl InteropBinding.is_direct.getter -> bool {
    return (len(self.route) == 2);
}

impl InteropBinding.is_composed.getter -> bool {
    return (len(self.route) > 2);
}

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

impl CodeLocInfo.orig_src.getter -> Source {
    return self.first_tok.orig_src;
}

impl CodeLocInfo.mod_path.getter -> str {
    return self.first_tok.orig_src.file_path;
}

impl CodeLocInfo.first_line.getter -> int {
    return self.first_tok.line_no;
}

impl CodeLocInfo.last_line.getter -> int {
    return self.last_tok.end_line;
}

impl CodeLocInfo.col_start.getter -> int {
    return self.first_tok.c_start;
}

impl CodeLocInfo.col_end.getter -> int {
    return self.last_tok.c_end;
}

impl CodeLocInfo.pos_start.getter -> int {
    return self.first_tok.pos_start;
}

impl CodeLocInfo.pos_end.getter -> int {
    return self.last_tok.pos_end;
}
