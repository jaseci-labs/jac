"""P2 conformance manifest gate (PLAN.md §6.6 T6 / §7 P2 exit).

Verifies ``jac-py/tests/conformance_manifest.json`` lists all ten P2 wave modules
with status ``gated``.
"""

from __future__ import annotations

import io
import json
import sys
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_MANIFEST = _REPO / "jac-py" / "tests" / "conformance_manifest.json"
_CORPUS = _HERE / "p2_corpus" / "manifest.json"
_EXPECTED_COUNT = 10
_ALLOWED_GATE_TYPES = frozenset({"oracle", "libtest", "deferred"})
# Stems with ``jacpython_capable`` snippets in ``libtest_snippets.jac``.
_JACPYTHON_CAPABLE_LIBTEST = frozenset({"getplatform", "_bisectmodule", "_heapqmodule"})


class P2ConformanceGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not _MANIFEST.is_file():
            raise unittest.SkipTest(
                f"missing {_MANIFEST} — run jac-py/tests/run_conformance.jac first"
            )

    def test_corpus_manifest_has_ten_modules(self) -> None:
        corpus = json.loads(_CORPUS.read_text(encoding="utf-8"))
        self.assertEqual(len(corpus.get("files", [])), _EXPECTED_COUNT)

    def test_conformance_manifest_lists_ten_gated_modules(self) -> None:
        manifest = json.loads(_MANIFEST.read_text(encoding="utf-8"))
        modules = manifest.get("modules", [])
        self.assertEqual(len(modules), _EXPECTED_COUNT, manifest)
        self.assertEqual(manifest.get("module_count"), _EXPECTED_COUNT)

        corpus = json.loads(_CORPUS.read_text(encoding="utf-8"))
        expected_stems = {row["stem"] for row in corpus["files"]}
        seen_stems: set[str] = set()

        for row in modules:
            stem = row["stem"]
            seen_stems.add(stem)
            self.assertIn(
                row.get("gate_type"),
                _ALLOWED_GATE_TYPES,
                f"{stem}: bad gate_type",
            )
            self.assertEqual(
                row.get("status"),
                "gated",
                f"{stem}: expected status gated, got {row.get('status')!r}",
            )

        self.assertEqual(seen_stems, expected_stems)

    def test_libtest_modules_record_host_results(self) -> None:
        manifest = json.loads(_MANIFEST.read_text(encoding="utf-8"))
        libtest_results = manifest.get("libtest_results", {})
        for row in manifest.get("modules", []):
            if row.get("gate_type") != "libtest":
                continue
            stem = row["stem"]
            self.assertIn(stem, libtest_results, f"missing libtest_results for {stem}")
            summary = libtest_results[stem]
            self.assertGreater(summary.get("total", 0), 0, stem)
            self.assertEqual(summary.get("failed", -1), 0, summary)

    def test_libtest_modules_record_jac_differential_results(self) -> None:
        manifest = json.loads(_MANIFEST.read_text(encoding="utf-8"))
        jac_results = manifest.get("jac_differential_results")
        if not jac_results:
            self.skipTest("manifest has no jac_differential_results yet")
        for row in manifest.get("modules", []):
            if row.get("gate_type") != "libtest":
                continue
            stem = row["stem"]
            self.assertIn(
                stem, jac_results, f"missing jac_differential_results for {stem}"
            )
            summary = jac_results[stem]
            self.assertEqual(summary.get("failed", -1), 0, summary)

    def test_libtest_modules_record_jacpython_results(self) -> None:
        manifest = json.loads(_MANIFEST.read_text(encoding="utf-8"))
        jp_results = manifest.get("jacpython_results")
        self.assertIsNotNone(jp_results, "manifest must record jacpython_results")
        for row in manifest.get("modules", []):
            if row.get("gate_type") != "libtest":
                continue
            stem = row["stem"]
            self.assertIn(stem, jp_results, f"missing jacpython_results for {stem}")
            summary = jp_results[stem]
            self.assertEqual(summary.get("failed", -1), 0, summary)
            if stem in _JACPYTHON_CAPABLE_LIBTEST:
                self.assertGreater(summary.get("passed", 0), 0, summary)
                self.assertEqual(summary.get("skipped", 0), 0, summary)


def run_conformance_gate() -> tuple[bool, str]:
    """Run the conformance gate unittest module; return (passed, detail)."""
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    buf = io.StringIO()
    runner = unittest.TextTestRunner(stream=buf, verbosity=2)
    result = runner.run(suite)
    detail = buf.getvalue()
    if result.wasSuccessful():
        return True, detail
    if not detail:
        detail = (
            f"{len(result.failures)} failure(s), "
            f"{len(result.errors)} error(s)"
        )
    return False, detail


if __name__ == "__main__":
    unittest.main()
