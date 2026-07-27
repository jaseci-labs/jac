glob _NA_FMT_KERNEL_MOD: list = [];

def _write_native_fmt_source(core_dir: str, dest: str) {
    import os;
    _kernel = os.path.join(core_dir, "fmt_kernel.jac");
    with open(_kernel, "r") as _kf {
        _ktext = _kf.read();
    }
    with open(dest, "w") as _out {
        _out.write(_ktext);
    }
}

def _load_native_fmt_kernel_module -> (uni.Module | None) {
    if _NA_FMT_KERNEL_MOD {
        return _NA_FMT_KERNEL_MOD[0];
    }
    import os;
    import shutil;
    import tempfile;
    import jaclang;
    import from jaclang.jac0core.program { JacProgram }
    _core = os.path.join(os.path.dirname(jaclang.__file__), "jac0core");
    tmp_dir = tempfile.mkdtemp();
    na_copy = os.path.join(tmp_dir, "fmt_kernel.na.jac");
    mod = None;
    try {
        _write_native_fmt_source(_core, na_copy);
        prog = JacProgram();
        mod = prog.compile(na_copy, no_cgen=True, symtab_ir_only=True);
    } except Exception {
        mod = None;
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
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
    self._walk_imported_module_abilities(kernel_mod);
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
    self._walk_imported_module_abilities(_km);
    return self.func_symtab.get(name);
}
