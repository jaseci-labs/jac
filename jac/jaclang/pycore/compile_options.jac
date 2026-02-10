"""Compilation options for the Jac compiler.

This module provides the CompileOptions dataclass which encapsulates
all options that control compilation behavior. Using a dedicated options
class instead of individual parameters provides:

- Type safety and documentation in one place
- Easy extension for new options
- Thread-safe compilation (each call has its own options instance)
- Clear API for passes to check compilation mode
"""
import from dataclasses { dataclass }
import from typing { Any }
"""Options controlling Jac compilation behavior.

    Attributes:
        minimal: Use minimal compilation mode (bytecode only, no JS/native).
                 Used for bootstrap-critical modules to avoid circular imports.
        type_check: Run type checking pass after compilation.
        symtab_ir_only: Only build symbol table, skip semantic analysis.
        no_cgen: Skip code generation entirely (AST only).
        skip_native_engine: Skip JIT engine creation for native code.
                           Used when compiling imported .na.jac modules
                           that will be linked into a parent module's IR.
        cancel_token: Optional threading.Event to cancel compilation.
    """
@dataclass
class CompileOptions {
    with entry {
        minimal: bool = False;
        type_check: bool = False;
        symtab_ir_only: bool = False;
        no_cgen: bool = False;
        skip_native_engine: bool = False;
        cancel_token: Any = None;
    }

    """Return a copy with skip_native_engine set.

        Useful for creating derived options for nested compilations.
        """
    def with_skip_native_engine(
        self: CompileOptions, `skip: bool = True
    ) -> CompileOptions {
        return CompileOptions(
            minimal=self.minimal,
            type_check=self.type_check,
            symtab_ir_only=self.symtab_ir_only,
            no_cgen=self.no_cgen,
            skip_native_engine=`skip,
            cancel_token=self.cancel_token
        );
    }
}

glob DEFAULT_OPTIONS = CompileOptions();
