import from dataclasses { field }

obj CompileOptions {
    has type_check: bool = True,
        emit_diagnostics: bool = True,
        symtab_ir_only: bool = False,
        no_cgen: bool = False,
        skip_native_engine: bool = False,
        resolve_annex_parent: bool = False,
        force_target_program: bool = False,
        aot_mode: bool = False,
        na_gc_mode: str = "cycles",
        nogc_enforce_all: bool = False,
        nogc_cli_target: str = "",
        nogc_enforce_modules: list[str] = field(default_factory=`list),
        nogc_grandfathered: list[str] = field(default_factory=`list),
        suppress_codes: list[str] = field(default_factory=`list),
        default_codespace: str = "",
        project_kind: str = "web",
        project_root: (str | None) = None,
        cancel_token: any = None;

    def nogc_enforced_for(mod_name: str) -> bool {
        if self.nogc_enforce_all {
            return True;
        }
        if not self.nogc_enforce_modules {
            return False;
        }
        import fnmatch;
        for _pat in self.nogc_grandfathered {
            if fnmatch.fnmatchcase(mod_name, _pat) {
                return False;
            }
        }
        for _pat in self.nogc_enforce_modules {
            if fnmatch.fnmatchcase(mod_name, _pat) {
                return True;
            }
        }
        return False;
    }
}
