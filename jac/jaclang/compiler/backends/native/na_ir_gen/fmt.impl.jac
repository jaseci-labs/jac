"""The format kernel, `compiler/backends/fmt_kernel.jac`, is an ordinary
native unit: its abilities are declared from its AST under its own prefix
and a dependency edge carries it into the link plan."""
impl NaIRGenFmt._ensure_fmt_kernel -> bool {
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

impl NaIRGenFmt._get_fmt_kernel_fn(name: str) -> (ir.Function | None) {
    if not self._ensure_fmt_kernel() {
        return None;
    }
    fn = self.func_symtab.get(name);
    if fn is not None {
        return fn;
    }

    existing = self.llvm_module.globals.get(name);
    if isinstance(existing, ir.Function) {
        self.func_symtab[name] = existing;
        return existing;
    }
    _km: any = self._fmt_kernel_mod;
    self._walk_imported_module_abilities(_km, with_fn_verdicts=False);
    return self.func_symtab.get(name);
}
