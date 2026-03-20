"""Compilation options for the Jac compiler.

This module provides the CompileOptions obj which encapsulates
all options that control compilation behavior.
"""
import from typing { Any }

"""Options controlling Jac compilation behavior."""
obj CompileOptions {
    has type_check: bool = True,
        symtab_ir_only: bool = False,
        no_cgen: bool = False,
        skip_native_engine: bool = False,
        resolve_annex_parent: bool = False,
        force_target_program: bool = False,
        aot_mode: bool = False,
        cancel_token: Any = None;

    """Return a copy with skip_native_engine set."""
    def with_skip_native_engine(`skip: bool = True) -> CompileOptions;

    """Return a copy with aot_mode set."""
    def with_aot_mode(mode: bool = True) -> CompileOptions;
}

glob DEFAULT_OPTIONS = CompileOptions();
