"""Compilation options for the Jac compiler.

This module provides the CompileOptions obj which encapsulates
all options that control compilation behavior.
"""
import from dataclasses { field }

"""Options controlling Jac compilation behavior."""
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

    """Return a copy with skip_native_engine set."""
    def with_skip_native_engine(`skip: bool = True) -> CompileOptions;

    """Return a copy with aot_mode set."""
    def with_aot_mode(mode: bool = True) -> CompileOptions;
}

glob DEFAULT_OPTIONS = CompileOptions();
