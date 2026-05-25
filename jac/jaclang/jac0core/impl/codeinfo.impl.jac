"""Implementation for codeinfo constructs."""

"""True if the bridge is a single hop (e.g. sv→na)."""
impl InteropBinding.is_direct.getter -> bool {
    return (len(self.route) == 2);
}

"""True if the bridge requires multiple hops (e.g. cl→sv→na)."""
impl InteropBinding.is_composed.getter -> bool {
    return (len(self.route) > 2);
}

"""True if the function is imported from another module."""
impl InteropBinding.is_cross_module.getter -> bool {
    return (self.source_module is not None);
}

"""Server (Python) functions that native code calls."""
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

"""Native functions that server (Python) code calls."""
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

"""Native functions imported from other .na.jac modules."""
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

"""Server functions that client (JS) code calls."""
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

"""Server functions imported from another server module via sv import."""
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

impl CodeLocInfo.tok_range.getter -> tuple[(Token, Token)] {
    return (self.first_tok, self.last_tok);
}

impl CodeLocInfo.first_token.getter -> Token {
    return self.first_tok;
}

impl CodeLocInfo.last_token.getter -> Token {
    return self.last_tok;
}
