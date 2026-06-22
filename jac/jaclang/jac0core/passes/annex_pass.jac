"""Annex module loading pass for the Jac compiler.

This pass handles the discovery, loading, and merging of annex and variant
modules into their base (head) module.

Annex modules are specialized extension files (.impl.jac, .test.jac) that
provide implementations or tests for a base module. Variant modules
(.sv.jac, .cl.jac, .na.jac) provide deployment-specific declarations for the
same logical module.

Annex files are discovered from:
- Same directory: foo.impl.jac for foo.jac
- Module-specific folder: foo.impl/bar.impl.jac for foo.jac
- Shared folder: impl/foo.impl.jac, test/foo.test.jac

This enables the separation of interface and implementation, as well as test
code organization.
"""
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.bccache { discover_annex_files, discover_variant_files }
import from jaclang.jac0core.passes.transform { Transform }
import type from jaclang.jac0core.program { JacProgram }

"""Handles merging of annex (.impl.jac, .test.jac) and variant
(.sv.jac, .cl.jac, .na.jac) files into the head module."""
class JacAnnexPass(Transform[uni.Module, uni.Module]) {
    """Load and merge annex modules into the given module."""
    def transform(self: JacAnnexPass, ir_in: uni.Module) -> uni.Module;

    """Discover and merge annex and variant files into the head module."""
    def _load_annexes(
        self: JacAnnexPass, jac_program: JacProgram, nd: uni.Module, mod_path: str
    ) -> None;

    """Discover and merge the .impl.jac/.test.jac annexes that belong to
    `base_path`, coercing each to the deployment context of `ctx_path`."""
    def _merge_annex_group(
        self: JacAnnexPass,
        nd: uni.Module,
        base_path: str,
        ctx_path: str,
        seen: set[str]
    ) -> None;

    """Parse one annex/variant file and splice its body into the head module,
    coercing it to the deployment context implied by `ctx_path`."""
    def _merge_annex(
        self: JacAnnexPass, nd: uni.Module, path: str, ctx_path: str, seen: set[str]
    ) -> None;
}
