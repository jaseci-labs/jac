"""P1 c2jac corpus lift + Tier-B density ratchet (PLAN.md §7 P1 exit)."""

from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_MANIFEST = _HERE / "p1_corpus" / "manifest.json"
_BASELINE = _HERE / "p1_corpus" / "baseline" / "project.c2jac.report.json"
_LIFT = _HERE / "lift_p1_corpus.py"
_MEASURE = _HERE / "measure_tier_b.py"
_JAC = _REPO / ".venv" / "bin" / "jac"
_MAX_DENSITY = 0.15


def _run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=_REPO, capture_output=True, text=True, check=True)


class P1CorpusGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not _JAC.is_file():
            raise unittest.SkipTest(f"missing {_JAC} — run from repo with .venv")
        manifest = json.loads(_MANIFEST.read_text(encoding="utf-8"))
        cls.out_dir = _REPO / manifest["lift_output"]
        cls.aggregate = cls.out_dir / "project.c2jac.report.json"

    def test_baseline_manifest_is_present(self) -> None:
        self.assertTrue(_BASELINE.is_file(), f"missing baseline {_BASELINE}")
        baseline = json.loads(_BASELINE.read_text(encoding="utf-8"))
        manifest = json.loads(_MANIFEST.read_text(encoding="utf-8"))
        self.assertGreaterEqual(len(baseline.get("files", [])), 5)
        self.assertEqual(len(manifest.get("files", [])), len(baseline["files"]))

    def test_project_lift_and_density_ratchet(self) -> None:
        proc = subprocess.run(
            [sys.executable, str(_LIFT)],
            cwd=_REPO,
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr or proc.stdout)
        self.assertTrue(self.aggregate.is_file(), f"missing {self.aggregate}")

        baseline = json.loads(_BASELINE.read_text(encoding="utf-8"))
        current = json.loads(self.aggregate.read_text(encoding="utf-8"))
        baseline_total = int(baseline["tier_b_total"])
        current_total = int(current["tier_b_total"])
        self.assertLessEqual(
            current_total,
            baseline_total,
            f"Tier-B regressed: {current_total} > baseline {baseline_total}",
        )

        measure = subprocess.run(
            [sys.executable, str(_MEASURE), str(self.aggregate.relative_to(_REPO))],
            cwd=_REPO,
            capture_output=True,
            text=True,
            check=True,
        )
        density_line = next(
            (ln for ln in measure.stdout.splitlines() if ln.startswith("density:")),
            "",
        )
        self.assertTrue(density_line, measure.stdout)
        density = float(density_line.split(":")[1].strip())
        self.assertLess(
            density,
            _MAX_DENSITY,
            f"Tier-B density {density:.6f} >= {_MAX_DENSITY}",
        )


if __name__ == "__main__":
    unittest.main()
