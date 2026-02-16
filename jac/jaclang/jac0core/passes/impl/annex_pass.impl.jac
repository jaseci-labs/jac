"""Implementation for annex_pass constructs."""

"""Load and attach annex modules to the given module."""
impl JacAnnexPass.transform(self: JacAnnexPass, ir_in: uni.Module) -> uni.Module {
    mod_path = ir_in.loc.mod_path;
    if (ir_in.stub_only or not mod_path.endswith('.jac') or ir_in.annexable_by) {
        return ir_in;
    }
    self._load_annexes(self.prog, ir_in, mod_path);
    return ir_in;
}

"""Parse and attach annex modules to the node."""
impl JacAnnexPass._load_annexes(
    self: JacAnnexPass, jac_program: JacProgram, nd: uni.Module, mod_path: str
) -> None {
    for path in discover_annex_files(mod_path, '.impl.jac') {
        if (mod := jac_program.compile(file_path=path, no_cgen=True)) {
            nd.impl_mod.append(mod);
        }
    }
    for path in discover_annex_files(mod_path, '.test.jac') {
        if (mod := jac_program.compile(file_path=path, no_cgen=True)) {
            nd.test_mod.append(mod);
        }
    }
}
