"""P2 waves 2-11 c2jac corpus lifts + Tier-B density ratchets.

One harness for all per-wave lift gates, replacing the ten copy-pasted
``test_p2_corpus_wave<N>_gate.py`` modules. Each wave re-lifts its corpus,
asserts the Tier-B total did not regress against the committed baseline, and
keeps Tier-B density under the ratchet.
"""

from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_MEASURE = _HERE / "measure_tier_b.py"
_LIFT_DRIVER = _HERE / "lift_p2_corpus_wave.py"
_JAC = _REPO / ".venv" / "bin" / "jac"
_MAX_DENSITY = 0.15
_EXPECTED_COUNT = 4


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


class P2CorpusWavesGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not _JAC.is_file():
            raise unittest.SkipTest(f"missing {_JAC} - run from repo with .venv")

    def test_all_waves(self) -> None:
        for wave in range(2, 12):
            with self.subTest(wave=wave):
                self._check_wave(wave)

    def _check_wave(self, wave: int) -> None:
        manifest = _load(_HERE / f"p2_corpus_wave{wave}" / "manifest.json")
        baseline_path = (
            _HERE / f"p2_corpus_wave{wave}" / "baseline" / "project.c2jac.report.json"
        )
        self.assertTrue(baseline_path.is_file(), f"missing baseline {baseline_path}")
        baseline = _load(baseline_path)
        self.assertEqual(len(manifest.get("files", [])), _EXPECTED_COUNT)
        self.assertEqual(len(baseline.get("files", [])), _EXPECTED_COUNT)

        proc = subprocess.run(
            [sys.executable, str(_LIFT_DRIVER), "--wave", str(wave)],
            cwd=_REPO,
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr or proc.stdout)

        out_dir = _REPO / manifest["lift_output"]
        aggregate = out_dir / "project.c2jac.report.json"
        self.assertTrue(aggregate.is_file(), f"missing {aggregate}")

        current = _load(aggregate)
        baseline_total = int(baseline["tier_b_total"])
        current_total = int(current["tier_b_total"])
        self.assertLessEqual(
            current_total,
            baseline_total,
            f"wave{wave}: Tier-B regressed: {current_total} > baseline {baseline_total}",
        )

        measure = subprocess.run(
            [sys.executable, str(_MEASURE), str(aggregate.relative_to(_REPO))],
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
            f"wave{wave}: Tier-B density {density:.6f} >= {_MAX_DENSITY}",
        )


if __name__ == "__main__":
    unittest.main()
