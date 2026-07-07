import from dataclasses { field }

obj CompileOptions {
    has type_check: bool = True,
        symtab_ir_only: bool = False,
        no_cgen: bool = False,
        skip_native_engine: bool = False,
        resolve_annex_parent: bool = False,
        force_target_program: bool = False,
        aot_mode: bool = False,
        suppress_codes: list[str] = field(default_factory=`list),
        project_kind: str = "web",
        project_root: (str | None) = None,
        cancel_token: any = None;
}
