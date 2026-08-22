"""Phase 6 VM opcode fixture gate tests (INTEGRATION_PLAN.md)."""

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
sys.path.insert(0, str(_HERE))

import vm_opcode_fixtures as vmf  # noqa: E402


class VmOpcodeFixturesTests(unittest.TestCase):
    def test_gate_passes(self) -> None:
        proc = subprocess.run(
            [sys.executable, str(_HERE / "vm_opcode_fixtures.py"), "--check"],
            cwd=_REPO,
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr or proc.stdout)

    def test_fixture_table_matches_emission_set(self) -> None:
        tagged = {fixture.opcode for fixture in vmf.FIXTURES}
        compiler_only = set(vmf.COMPILER_ONLY_OPCODES)
        cpython_ops = set(vmf.EMISSION_OPCODES) - compiler_only
        self.assertEqual(tagged, cpython_ops)

    def test_compiler_fixtures_cover_compiler_only_opcodes(self) -> None:
        tagged = {fixture.opcode for fixture in vmf.COMPILER_FIXTURES}
        self.assertEqual(tagged, set(vmf.COMPILER_ONLY_OPCODES))

    def test_codegen_sync_when_present(self) -> None:
        codegen = _REPO / "jac-py" / "jacpython" / "compiler_codegen.jac"
        if not codegen.is_file():
            self.skipTest("compiler_codegen.jac not present")
        errors = vmf.check_codegen_sync(codegen)
        self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main()
