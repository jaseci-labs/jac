"""Annex module loading pass for the Jac compiler.

This pass handles the discovery, loading, and attachment of annex modules to
their base modules.
Annex modules are specialized extension files (.impl.jac, .test.jac) that
provide
implementations or tests for a base module.

Annex files are discovered from:
- Same directory: foo.impl.jac for foo.jac
- Module-specific folder: foo.impl/bar.impl.jac for foo.jac
- Shared folder: impl/foo.impl.jac, test/foo.test.jac

This enables the separation of interface and implementation, as well as test
code organization.
"""
import from typing { TYPE_CHECKING }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.bccache { discover_annex_files }
import from jaclang.jac0core.passes.transform { Transform }

with entry {
    if TYPE_CHECKING {
        import from jaclang.jac0core.program { JacProgram }
    }
}

"""Handles loading and attaching of annex files (.impl.jac, .test.jac)."""
class JacAnnexPass(Transform[(uni.Module, uni.Module)]) {
    """Load and attach annex modules to the given module."""
    def transform(self: JacAnnexPass, ir_in: uni.Module) -> uni.Module;

    """Parse and attach annex modules to the node."""
    def _load_annexes(
        self: JacAnnexPass, jac_program: JacProgram, nd: uni.Module, mod_path: str
    ) -> None;
}
