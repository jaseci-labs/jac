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

"""Discover and merge annex and variant files into the head module.

    Annex (.impl/.test) and variant (.sv/.cl/.na) bodies are spliced directly
    into the head module's `body`/`kid` so the result is a single unified tree:
    every generic walk covers their content for free, and each spliced node
    keeps its own `loc.mod_path` for provenance (round-trip tooling uses that to
    write changes back to the right file).

    Variants are merged alongside annexes so a plain `.jac` head can host
    server- and client-only declarations side by side in one symbol table.
    Cross-variant impl matching (e.g. a head `.impl.jac` implementing a `.cl.jac`
    declaration) then falls out of the single same-module connect that
    DeclImplMatchPass runs over the merged tree. Each variant — and the annexes
    that belong to it — is coerced to the *variant's* own deployment context
    (not the head's), so codegen's context filter keeps each variant's
    statements on the right side of the cl/sv/na split.
"""
impl JacAnnexPass._load_annexes(
    self: JacAnnexPass, jac_program: JacProgram, nd: uni.Module, mod_path: str
) -> None {
    # `seen` guards against a bare annex (no variant suffix) being claimed by
    # more than one variant when no plain `.jac` head exists to own it.
    seen: set[str] = set();
    # The head's own annexes inherit the head's deployment context.
    self._merge_annex_group(nd, mod_path, mod_path, seen);
    # Each lower-precedence variant: splice the variant body, then its own
    # annexes, all coerced to the variant's context.
    for variant_path in discover_variant_files(mod_path) {
        self._merge_annex(nd, variant_path, variant_path, seen);
        self._merge_annex_group(nd, variant_path, variant_path, seen);
    }
}

"""Discover and merge the .impl.jac/.test.jac annexes belonging to base_path."""
impl JacAnnexPass._merge_annex_group(
    self: JacAnnexPass, nd: uni.Module, base_path: str, ctx_path: str, seen: set[str]
) -> None {
    for path in discover_annex_files(base_path, '.impl.jac') {
        self._merge_annex(nd, path, ctx_path, seen);
    }
    for path in discover_annex_files(base_path, '.test.jac') {
        self._merge_annex(nd, path, ctx_path, seen);
    }
}

"""Parse one annex/variant file and splice its body statements into the head."""
impl JacAnnexPass._merge_annex(
    self: JacAnnexPass, nd: uni.Module, path: str, ctx_path: str, seen: set[str]
) -> None {
    import from jaclang.jac0core.parser { parse as rd_parse }
    import from jaclang.jac0core.helpers { read_file_with_encoding }
    import from jaclang.jac0core.compiler {
        _coerce_client_module,
        _coerce_server_module,
        _coerce_native_module
    }
    if path in seen {
        return;
    }
    seen.add(path);
    source_str = read_file_with_encoding(path);
    # Splice even on recoverable parse errors: rd_parse already records its
    # diagnostics on the program (so they surface in the head's check) and its
    # error-recovered tree still carries the well-formed statements.
    (annex_mod, _had_error) = rd_parse(source_str, path, prog=self.prog);
    # Spliced statements must carry their owning variant's deployment context so
    # their name resolution lands in the same scope as the matching declarations
    # and codegen's context filter routes them correctly. `ctx_path` is the head
    # path for the head's own annexes and the variant path for a variant and its
    # annexes.
    if ctx_path.endswith('.cl.jac') {
        _coerce_client_module(annex_mod);
    } elif ctx_path.endswith('.sv.jac') {
        _coerce_server_module(annex_mod);
    } elif ctx_path.endswith('.na.jac') {
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
