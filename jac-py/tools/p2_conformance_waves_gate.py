"""P2 waves 2-11 conformance manifest gates.

One harness for all per-wave conformance manifests
(``jac-py/tests/conformance_manifest_wave<N>.json``), replacing the ten
copy-pasted ``p2_conformance_wave<N>_gate.py`` modules. Also validates that
every ``oracle_tests`` entry points at an existing file under ``jac-py/tests``
so manifest paths cannot rot silently.
"""

from __future__ import annotations

import json
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_TESTS_DIR = _REPO / "jac-py" / "tests"

_ALLOWED_GATE_TYPES = frozenset({"oracle", "libtest", "deferred"})


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


class P2ConformanceWavesGateTests(unittest.TestCase):
    def _wave_manifest(self, wave: int) -> dict:
        return _load(_TESTS_DIR / f"conformance_manifest_wave{wave}.json")

    def test_all_waves(self) -> None:
        for wave in range(2, 12):
            with self.subTest(wave=wave):
                self._check_wave(wave)

    def _check_wave(self, wave: int) -> None:
        manifest = self._wave_manifest(wave)
        corpus = _load(_HERE / f"p2_corpus_wave{wave}" / "manifest.json")
        staged = _load(_HERE / f"p2_staged_manifest_wave{wave}.json")
        self.assertEqual(manifest["module_count"], len(corpus["files"]))
        self.assertEqual(len(manifest["modules"]), len(corpus["files"]))

        manifest_stems = {row["stem"] for row in manifest["modules"]}
        corpus_stems = {row["stem"] for row in corpus["files"]}
        staged_stems = {row["stem"] for row in staged["modules"]}
        self.assertEqual(manifest_stems, corpus_stems)
        self.assertEqual(staged_stems, corpus_stems)

        modules_dir = _REPO / "jac-py" / "Modules"
        for row in manifest["modules"]:
            self.assertEqual(row.get("status"), "gated", row)
            self.assertIn(row.get("gate_type"), _ALLOWED_GATE_TYPES, row)
            oracle_tests = row.get("oracle_tests")
            self.assertTrue(oracle_tests, f"{row['stem']}: missing oracle_tests")
            for test_name in oracle_tests:
                test_path = _TESTS_DIR / test_name
                self.assertTrue(
                    test_path.is_file(),
                    f"{row['stem']}: oracle_tests entry not found: {test_path}",
                )
            if row.get("gate_type") != "oracle":
                continue
            path = modules_dir / f"{row['stem']}.jac"
            self.assertTrue(path.is_file(), f"missing staged oracle {path}")


if __name__ == "__main__":
    unittest.main()
