"""Annex module loading pass for the Jac compiler.

This pass handles the discovery, loading, and attachment of annex modules to their base modules.
Annex modules are specialized extension files (.impl.jac, .test.jac) that provide
implementations or tests for a base module.

Annex files are discovered from:
- Same directory: foo.impl.jac for foo.jac
- Module-specific folder: foo.impl/bar.impl.jac for foo.jac
- Shared folder: impl/foo.impl.jac, test/foo.test.jac

This enables the separation of interface and implementation, as well as test code organization.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

import jaclang.pycore.unitree as uni
from jaclang.pycore.bccache import discover_annex_files
from jaclang.pycore.passes.transform import Transform

if TYPE_CHECKING:
    from jaclang.pycore.program import JacProgram


class JacAnnexPass(Transform[uni.Module, uni.Module]):
    """Handles loading and attaching of annex files (.impl.jac, .test.jac)."""

    def transform(self, ir_in: uni.Module) -> uni.Module:
        """Load and attach annex modules to the given module."""
        mod_path = ir_in.loc.mod_path
        if ir_in.stub_only or not mod_path.endswith(".jac") or ir_in.annexable_by:
            return ir_in

        self._load_annexes(self.prog, ir_in, mod_path)
        return ir_in

    def _load_annexes(
        self, jac_program: JacProgram, node: uni.Module, mod_path: str
    ) -> None:
        """Parse and attach annex modules to the node."""
        for path in discover_annex_files(mod_path, ".impl.jac"):
            if mod := jac_program.compile(file_path=path, no_cgen=True, minimal=True):
                node.impl_mod.append(mod)

        for path in discover_annex_files(mod_path, ".test.jac"):
            if mod := jac_program.compile(file_path=path, no_cgen=True, minimal=True):
                node.test_mod.append(mod)
