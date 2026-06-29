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
        # Client UI target scope ("web" | "universal"). Drives JSX host-tag
        # enforcement (E1105): universal projects forbid raw HTML intrinsic
        # tags. Normally resolved from jac.toml `[project] client_kind`; set
        # here to override.
        project_kind: str = "web",
        # Absolute path to the consumer project's root directory (the folder
        # containing jac.toml). When set, kind-sensitive passes only guard
        # files that live inside this directory; framework and library files
        # compiled into the same JacProgram are left untouched. Normally
        # auto-detected from the entry file's jac.toml; set here to override.
        project_root: (str | None) = None,
        cancel_token: any = None;
}
