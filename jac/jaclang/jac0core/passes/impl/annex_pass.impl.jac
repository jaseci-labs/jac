"""Implementation for annex_pass constructs."""

"""Load and merge annex modules into the given module."""
impl JacAnnexPass.transform(self: JacAnnexPass, ir_in: uni.Module) -> uni.Module {
    mod_path = ir_in.loc.mod_path;
    if (ir_in.stub_only or not mod_path.endswith('.jac') or ir_in.annexable_by) {
        return ir_in;
    }
    self._load_annexes(self.prog, ir_in, mod_path);
    return ir_in;
}

"""Discover and merge annex files into the head module.

    Annex bodies are spliced directly into the head module's `body`/`kid` so the
    result is a single unified tree: every generic walk covers annex content for
    free, and each spliced node keeps its own `loc.mod_path` for provenance
    (round-trip tooling uses that to write changes back to the right file).
"""
impl JacAnnexPass._load_annexes(
    self: JacAnnexPass, jac_program: JacProgram, nd: uni.Module, mod_path: str
) -> None {
    for path in discover_annex_files(mod_path, '.impl.jac') {
        self._merge_annex(nd, path);
    }
    for path in discover_annex_files(mod_path, '.test.jac') {
        self._merge_annex(nd, path);
    }
}

"""Parse one annex file and splice its body statements into the head module."""
impl JacAnnexPass._merge_annex(self: JacAnnexPass, nd: uni.Module, path: str) -> None {
    import from jaclang.jac0core.parser { parse as rd_parse }
    import from jaclang.jac0core.helpers { read_file_with_encoding }
    import from jaclang.jac0core.compiler {
        _coerce_client_module,
        _coerce_server_module,
        _coerce_native_module
    }
    source_str = read_file_with_encoding(path);
    # Splice even on recoverable parse errors: rd_parse already records its
    # diagnostics on the program (so they surface in the head's check) and its
    # error-recovered tree still carries the well-formed statements.
    (annex_mod, _had_error) = rd_parse(source_str, path, prog=self.prog);
    # The head's own body was context-coerced (in parse_str) before this pass
    # ran; spliced annex statements must inherit the same deployment context so
    # their name resolution lands in the same scope as the head's declarations.
    head_path = nd.loc.mod_path;
    if head_path.endswith('.cl.jac') {
        _coerce_client_module(annex_mod);
    } elif head_path.endswith('.sv.jac') {
        _coerce_server_module(annex_mod);
    } elif head_path.endswith('.na.jac') {
        _coerce_native_module(annex_mod);
    }
    stmts = list(annex_mod.body);
    if not stmts {
        return;
    }
    nd.body = [*nd.body, *stmts];
    nd.add_kids_right(stmts, pos_update=False, parent_update=True);
    for sub in annex_mod._in_mod_nodes {
        if sub is not annex_mod {
            nd._in_mod_nodes.append(sub);
        }
    }
}
