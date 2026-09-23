impl NaIRGenPass._ensure_fmt_kernel -> bool {
    if self._fmt_kernel_mod is not None {
        return True;
    }
    import from jaclang.compiler.frontend.codeinfo { FMT_KERNEL_REL, kernel_unit_path }
    kernel_mod = self._load_native_unit_module(kernel_unit_path(FMT_KERNEL_REL));
    if kernel_mod is None {
        return False;
    }
    self._walk_imported_module_abilities(kernel_mod, with_fn_verdicts=False);
    self._fmt_kernel_mod = kernel_mod;
    if kernel_mod?.loc and kernel_mod.loc.mod_path {
        self._note_native_dep(kernel_mod.loc.mod_path);
    }
    return True;
}

impl NaIRGenPass._get_fmt_kernel_fn(name: str) -> (ir.Function | None) {
    if not self._ensure_fmt_kernel() {
        return None;
    }
    module = self._fmt_kernel_mod;
    assert isinstance(module, uni.Module);
    return self._module_functions.get((os.path.realpath(module.loc.mod_path), name));
}
