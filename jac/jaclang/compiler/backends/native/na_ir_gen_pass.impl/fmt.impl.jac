glob _NA_FMT_KERNEL_MOD: list = [];

def _load_native_fmt_kernel_module -> (uni.Module | None) {
    if _NA_FMT_KERNEL_MOD {
        return _NA_FMT_KERNEL_MOD[0];
    }
    import from jaclang.compiler.backends.common.kernel_units { fmt_kernel_unit_path }
    import from jaclang.compiler.driver.program { JacProgram }
    mod = None;
    try {
        import from jaclang.compiler.driver.compile_options {
            CompileOptions as _KernelOpts
        }
        prog = JacProgram();
        mod = prog.compile(
            fmt_kernel_unit_path('na'),
            options=_KernelOpts(
                no_cgen=True,
                symtab_ir_only=True,
                aot_mode=True,
                default_codespace='native',
                force_codespace='native',
                force_target_program=True
            )
        );
    } except Exception {
        mod = None;
    }
    if mod is not None {
        _NA_FMT_KERNEL_MOD.append(mod);
    }
    return mod;
}

impl NaIRGenPass._ensure_fmt_kernel -> bool {
    if self._fmt_kernel_mod is not None {
        return True;
    }
    kernel_mod = _load_native_fmt_kernel_module();
    if kernel_mod is None {
        return False;
    }
    self._walk_imported_module_abilities(kernel_mod, with_fn_verdicts=False);
    self._fmt_kernel_mod = kernel_mod;

    _manifest = self.ir_in.gen.interop_manifest if (self.ir_in?.gen) else None;
    if (_manifest is not None)
        and ("fmt_kernel" not in _manifest.native_transitive_sources) {
        _manifest.native_transitive_sources.append("fmt_kernel");
    }
    return True;
}

impl NaIRGenPass._get_fmt_kernel_fn(name: str) -> (ir.Function | None) {
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
