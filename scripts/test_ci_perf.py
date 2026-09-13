"""Exercise the CI budget wrapper with real, small subprocesses."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("ci_perf.py")


class PerformanceBudgetTests(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.budgets = self.root / "budgets.json"
        self.output = self.root / "results"
        self.set_budget()

    def set_budget(self, wall: float = 5, memory: float | None = 256) -> None:
        self.budgets.write_text(json.dumps({"probe": {
            "wall_seconds": wall, "max_rss_mib": memory,
        }}))

    def invoke(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--budgets", str(self.budgets),
             "--output", str(self.output), *args],
            text=True, capture_output=True, timeout=10,
            env={**os.environ, "GITHUB_STEP_SUMMARY": str(self.root / "summary.md")},
        )

    def run_probe(self, source: str) -> subprocess.CompletedProcess[str]:
        return self.invoke("run", "probe", "--", sys.executable, "-c", source)

    def test_success_runs_the_command_once_and_records_kernel_metrics(self) -> None:
        counter = self.root / "counter"
        result = self.run_probe(
            f"from pathlib import Path; p=Path({str(counter)!r}); "
            "p.write_text(p.read_text()+'x' if p.exists() else 'x')"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(counter.read_text(), "x")
        metrics = json.loads((self.output / "probe.json").read_text())
        self.assertGreater(metrics["max_rss_mib"], 0)
        self.assertGreaterEqual(metrics["cpu_seconds"], 0)
        self.assertEqual(self.invoke("report").returncode, 0)

    def test_slow_command_fails_and_keeps_its_measurement(self) -> None:
        self.set_budget(wall=0.05)
        result = self.run_probe("import time; time.sleep(2)")
        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertIn("wall", result.stdout)
        self.assertTrue((self.output / "probe.json").is_file())
        self.assertNotEqual(self.invoke("report").returncode, 0)

    def test_memory_regression_fails_even_when_command_succeeds(self) -> None:
        self.set_budget(memory=32)
        result = self.run_probe("data=bytearray(64*1024*1024)")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("RSS", result.stdout)
        metrics = json.loads((self.output / "probe.json").read_text())
        self.assertEqual(metrics["exit_code"], 0)
        self.assertGreater(metrics["max_rss_mib"], 32)

    def test_command_failure_is_preserved(self) -> None:
        result = self.run_probe("raise SystemExit(7)")
        self.assertEqual(result.returncode, 7, result.stderr)
        self.assertNotEqual(self.invoke("report").returncode, 0)

    def test_startup_deadline_cannot_be_hidden_by_readiness(self) -> None:
        self.set_budget(wall=0.01, memory=None)
        self.assertEqual(self.invoke("start", "probe").returncode, 0)
        # The next Python process starts after this very small deadline.
        result = self.invoke("ready", "probe")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("wall", result.stdout)

    def test_missing_measurements_and_unknown_phases_fail(self) -> None:
        self.assertNotEqual(self.invoke("report").returncode, 0)
        self.assertNotEqual(self.invoke("ready", "probe").returncode, 0)
        self.assertNotEqual(self.invoke("start", "typo").returncode, 0)


if __name__ == "__main__":
    unittest.main()
