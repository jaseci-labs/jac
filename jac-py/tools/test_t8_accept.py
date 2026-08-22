"""Unit tests for T8 acceptance validation (jac-py/PLAN.md §6.8)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from t8_accept import (
    build_metrics,
    run_acceptance_tests,
    run_conformance_gate,
    run_libtest_tests,
    run_oracle_tests,
    tier_b_acceptable,
    validate,
)


def _write_report(path: Path, tier_b_total: int) -> None:
    path.write_text(
        json.dumps({"tier_b_total": tier_b_total, "files": [], "version": 1}) + "\n",
        encoding="utf-8",
    )


class TierBMetricsTests(unittest.TestCase):
    def test_regression_fails_validation(self) -> None:
        ok, msg = tier_b_acceptable(4, 5)
        self.assertFalse(ok)
        self.assertIn("regressed", msg or "")

    def test_improvement_is_acceptable(self) -> None:
        ok, msg = tier_b_acceptable(4, 2)
        self.assertTrue(ok)
        self.assertIsNone(msg)

    def test_unchanged_is_acceptable(self) -> None:
        ok, msg = tier_b_acceptable(4, 4)
        self.assertTrue(ok)
        self.assertIsNone(msg)

    def test_sites_fixed_in_metrics(self) -> None:
        metrics = build_metrics(4, 1, True)
        self.assertEqual(metrics["sites_before"], 4)
        self.assertEqual(metrics["sites_after"], 1)
        self.assertEqual(metrics["sites_fixed"], 3)
        self.assertTrue(metrics["tests_passed"])
        self.assertIn("timestamp", metrics)


class AcceptanceTestsRunner(unittest.TestCase):
    @patch("t8_accept.run_conformance_gate", return_value=(True, ""))
    @patch("t8_accept.run_libtest_tests", return_value=(True, ""))
    @patch("t8_accept.run_oracle_tests", return_value=(True, ""))
    def test_runs_all_suites(
        self,
        mock_oracle: unittest.mock.MagicMock,
        mock_libtest: unittest.mock.MagicMock,
        mock_conformance: unittest.mock.MagicMock,
    ) -> None:
        ok, detail = run_acceptance_tests()
        self.assertTrue(ok)
        self.assertEqual(detail, "")
        mock_oracle.assert_called_once()
        mock_libtest.assert_called_once()
        mock_conformance.assert_called_once()

    @patch("t8_accept.run_conformance_gate", return_value=(True, ""))
    @patch("t8_accept.run_libtest_tests", return_value=(True, ""))
    @patch(
        "t8_accept.run_oracle_tests",
        return_value=(False, "oracle tests failed:\nboom"),
    )
    def test_aggregates_failures(
        self,
        mock_oracle: unittest.mock.MagicMock,
        mock_libtest: unittest.mock.MagicMock,
        mock_conformance: unittest.mock.MagicMock,
    ) -> None:
        ok, detail = run_acceptance_tests()
        self.assertFalse(ok)
        self.assertIn("oracle tests failed", detail)
        mock_libtest.assert_called_once()
        mock_conformance.assert_called_once()

    @patch("t8_accept.subprocess.run")
    def test_oracle_invokes_jac_test(self, mock_run: unittest.mock.MagicMock) -> None:
        mock_run.return_value = unittest.mock.MagicMock(returncode=0, stdout="", stderr="")
        with tempfile.TemporaryDirectory() as tmp:
            jac = Path(tmp) / "jac"
            jac.write_text("#!/bin/sh\n", encoding="utf-8")
            ok, _ = run_oracle_tests(jac)
        self.assertTrue(ok)
        cmd = mock_run.call_args[0][0]
        self.assertEqual(cmd[0], str(jac))
        self.assertEqual(cmd[1], "test")
        self.assertIn("jac-py/tests/test_p2_module_oracles.jac", cmd)

    @patch("t8_accept.subprocess.run")
    def test_libtest_invokes_partial_suite(self, mock_run: unittest.mock.MagicMock) -> None:
        mock_run.return_value = unittest.mock.MagicMock(returncode=0, stdout="", stderr="")
        with tempfile.TemporaryDirectory() as tmp:
            jac = Path(tmp) / "jac"
            jac.write_text("#!/bin/sh\n", encoding="utf-8")
            ok, _ = run_libtest_tests(jac)
        self.assertTrue(ok)
        cmd = mock_run.call_args[0][0]
        self.assertEqual(cmd[-1], "jac-py/tests/test_p2_libtest_partial.jac")

    @patch("p2_conformance_gate.run_conformance_gate", return_value=(True, "ok"))
    def test_conformance_delegates_to_gate(self, mock_gate: unittest.mock.MagicMock) -> None:
        ok, detail = run_conformance_gate()
        self.assertTrue(ok)
        self.assertEqual(detail, "ok")
        mock_gate.assert_called_once()


class ValidateReportsTests(unittest.TestCase):
    def test_regression_fails_without_running_tests(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            before = root / "before.json"
            after = root / "after.json"
            _write_report(before, 3)
            _write_report(after, 4)
            metrics, errors = validate(before, after, run_tests=False)
            self.assertEqual(metrics["sites_before"], 3)
            self.assertEqual(metrics["sites_after"], 4)
            self.assertEqual(metrics["sites_fixed"], -1)
            self.assertTrue(metrics["tests_passed"])
            self.assertTrue(errors)
            self.assertTrue(any("regressed" in e for e in errors))

    def test_improvement_passes_tier_b_without_tests(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            before = root / "before.json"
            after = root / "after.json"
            _write_report(before, 5)
            _write_report(after, 2)
            metrics, errors = validate(before, after, run_tests=False)
            self.assertEqual(metrics["sites_fixed"], 3)
            self.assertTrue(metrics["tests_passed"])
            self.assertEqual(errors, [])

    @patch("t8_accept.run_acceptance_tests", return_value=(True, ""))
    def test_runs_acceptance_tests_by_default(
        self, mock_run: unittest.mock.MagicMock
    ) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            before = root / "before.json"
            after = root / "after.json"
            _write_report(before, 4)
            _write_report(after, 4)
            metrics, errors = validate(before, after)
            self.assertEqual(errors, [])
            self.assertTrue(metrics["tests_passed"])
            mock_run.assert_called_once()

    @patch(
        "t8_accept.run_acceptance_tests",
        return_value=(False, "libtest tests failed:\noops"),
    )
    def test_test_failure_surfaces_in_errors(
        self, mock_run: unittest.mock.MagicMock
    ) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            before = root / "before.json"
            after = root / "after.json"
            _write_report(before, 4)
            _write_report(after, 3)
            metrics, errors = validate(before, after)
            self.assertFalse(metrics["tests_passed"])
            self.assertEqual(len(errors), 1)
            self.assertIn("libtest tests failed", errors[0])
            mock_run.assert_called_once()


if __name__ == "__main__":
    unittest.main()
