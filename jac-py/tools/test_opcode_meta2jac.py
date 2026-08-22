"""Phase 3 opcode metadata generator tests (INTEGRATION_PLAN.md)."""

from __future__ import annotations

import hashlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent


def _generator_python() -> str:
    """CPython for generator scripts; jac test sets sys.executable to jac."""
    exe = Path(sys.executable)
    if exe.name.startswith("python"):
        return str(exe)
    found = shutil.which("python3")
    if found is not None:
        return found
    return "python3"


class OpcodeMeta2JacTests(unittest.TestCase):
    def test_regeneration_matches_checked_in_output(self) -> None:
        proc = subprocess.run(
            [_generator_python(), str(_HERE / "opcode_meta2jac.py"), "--check"],
            cwd=_REPO,
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr or proc.stdout)

    def test_cache_defaults_are_zero_not_opcode_index(self) -> None:
        import os

        from opcode_meta2jac import _CPY, parse_defines, parse_sparse_array

        opcode_ids = parse_defines(
            open(os.path.join(_CPY, "Include", "opcode_ids.h")).read()
        )
        opmap = {
            name: val
            for name, val in opcode_ids.items()
            if name
            not in {
                "HAVE_ARGUMENT",
                "MIN_SPECIALIZED_OPCODE",
                "MIN_INSTRUMENTED_OPCODE",
            }
            and val >= 0
        }
        meta_text = open(
            os.path.join(_CPY, "Include", "internal", "pycore_opcode_metadata.h")
        ).read()
        caches = parse_sparse_array(meta_text, "_PyOpcode_Caches", opmap)
        self.assertEqual(caches[128], 0)  # RESUME has no inline cache

    def test_reproducible_across_checkout_paths(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            for name in ("repo_a", "repo_b"):
                root = Path(tmp) / name
                (root / "jac-py" / "tools").mkdir(parents=True)
                (root / "jac-py" / "jacpython").mkdir(parents=True)
                subprocess.run(
                    ["cp", "-r", str(_REPO / "reference"), str(root / "reference")],
                    check=True,
                )
                subprocess.run(
                    [
                        "cp",
                        str(_HERE / "opcode_meta2jac.py"),
                        str(root / "jac-py" / "tools" / "opcode_meta2jac.py"),
                    ],
                    check=True,
                )
            out_a = subprocess.run(
                [_generator_python(), "jac-py/tools/opcode_meta2jac.py", "--stdout"],
                cwd=Path(tmp) / "repo_a",
                capture_output=True,
                text=True,
                check=True,
            ).stdout
            out_b = subprocess.run(
                [_generator_python(), "jac-py/tools/opcode_meta2jac.py", "--stdout"],
                cwd=Path(tmp) / "repo_b",
                capture_output=True,
                text=True,
                check=True,
            ).stdout
            self.assertEqual(
                hashlib.sha256(out_a.encode()).hexdigest(),
                hashlib.sha256(out_b.encode()).hexdigest(),
            )


if __name__ == "__main__":
    unittest.main()
