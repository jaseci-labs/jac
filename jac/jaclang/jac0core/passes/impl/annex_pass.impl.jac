impl JacAnnexPass.transform(self: JacAnnexPass, ir_in: uni.Module) -> uni.Module {
    mod_path = ir_in.loc.mod_path;
    if (ir_in.stub_only or not mod_path.endswith('.jac') or ir_in.annexable_by) {
        return ir_in;
    }
    self._load_annexes(self.prog, ir_in, mod_path);
    return ir_in;
}

impl JacAnnexPass._load_annexes(
    self: JacAnnexPass, jac_program: JacProgram, nd: uni.Module, mod_path: str
) -> None {
    seen: set[str] = set();

    self._merge_annex_group(nd, mod_path, mod_path, seen);

    for variant_path in discover_variant_files(mod_path) {
        self._merge_annex(nd, variant_path, variant_path, seen);
        self._merge_annex_group(nd, variant_path, variant_path, seen);
    }
}

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

    (annex_mod, _had_error) = rd_parse(source_str, path, prog=self.prog);

    import from jaclang.jac0core.ext_registry { codespace_of }
    ctx_codespace = codespace_of(ctx_path);
    if (ctx_codespace == 'client') {
        _coerce_client_module(annex_mod);
    } elif (ctx_codespace == 'server') {
        _coerce_server_module(annex_mod);
    } elif (ctx_codespace == 'native') {
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
