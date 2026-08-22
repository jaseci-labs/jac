#!/usr/bin/env python3
"""T8 acceptance: validate a Tier-B cleanup patch (jac-py/PLAN.md §6.8).

Acceptance criteria:
  - P2 module differential oracles pass
  - P2 libtest partial suite passes on host CPython
  - P2 conformance manifest gate passes
  - ``tier_b_total`` in the after report is <= before (ideally decreased)

Usage:
    .venv/bin/python jac-py/tools/t8_accept.py \\
        --report-before jac-py/Modules/_lifted/p2_corpus_wave1/project.c2jac.report.json \\
        --report-after /tmp/project.c2jac.report.json
    .venv/bin/python jac-py/tools/t8_accept.py \\
        --report-before before.json --report-after after.json \\
        --metrics-out /tmp/t8_metrics.json
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_JAC = _REPO / ".venv" / "bin" / "jac"
_ORACLE_TESTS = [
    "jac-py/tests/test_p2_module_oracles.jac",
    "jac-py/tests/test_rotatingtree_oracle.jac",
]
_LIBTEST = "jac-py/tests/test_p2_libtest_partial.jac"


def _resolve(path: Path) -> Path:
    return path if path.is_absolute() else _REPO / path


def read_tier_b_total(report: Path) -> int:
    data = json.loads(report.read_text(encoding="utf-8"))
    return int(data.get("tier_b_total", 0))


def tier_b_acceptable(sites_before: int, sites_after: int) -> tuple[bool, str | None]:
    if sites_after > sites_before:
        return False, (
            f"Tier-B regressed: {sites_after} > {sites_before} "
            f"(fixed={sites_before - sites_after})"
        )
    return True, None


def build_metrics(sites_before: int, sites_after: int, tests_passed: bool) -> dict:
    return {
        "sites_before": sites_before,
        "sites_after": sites_after,
        "sites_fixed": sites_before - sites_after,
        "tests_passed": tests_passed,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


def _run_jac_test(jac: Path, targets: list[str], label: str) -> tuple[bool, str]:
    if not jac.is_file():
        return False, f"missing jac executable: {jac}"
    cmd = [str(jac), "test", *targets]
    proc = subprocess.run(cmd, cwd=_REPO, capture_output=True, text=True)
    if proc.returncode == 0:
        return True, proc.stdout or ""
    detail = proc.stderr or proc.stdout or f"exit {proc.returncode}"
    return False, f"{label} tests failed:\n{detail.rstrip()}"


def run_oracle_tests(jac: Path | None = None) -> tuple[bool, str]:
    return _run_jac_test(jac or _JAC, _ORACLE_TESTS, "oracle")


def run_libtest_tests(jac: Path | None = None) -> tuple[bool, str]:
    return _run_jac_test(jac or _JAC, [_LIBTEST], "libtest")


def run_conformance_gate() -> tuple[bool, str]:
    from p2_conformance_gate import run_conformance_gate as _run

    ok, detail = _run()
    if ok:
        return True, detail
    return False, f"conformance gate failed:\n{detail.rstrip()}"


def run_acceptance_tests(jac: Path | None = None) -> tuple[bool, str]:
    failures: list[str] = []
    for runner in (
        lambda: run_oracle_tests(jac),
        lambda: run_libtest_tests(jac),
        run_conformance_gate,
    ):
        ok, detail = runner()
        if not ok:
            failures.append(detail.rstrip())
    if failures:
        return False, "\n\n".join(failures)
    return True, ""


def validate(
    report_before: Path,
    report_after: Path,
    *,
    run_tests: bool = True,
    jac: Path | None = None,
) -> tuple[dict, list[str]]:
    """Return (metrics, errors). Empty errors means acceptance passed."""
    errors: list[str] = []
    before = _resolve(report_before)
    after = _resolve(report_after)
    for label, path in ("before", before), ("after", after):
        if not path.is_file():
            errors.append(f"missing {label} report: {path}")
    if errors:
        return build_metrics(0, 0, False), errors

    sites_before = read_tier_b_total(before)
    sites_after = read_tier_b_total(after)
    ok_tier_b, tier_b_msg = tier_b_acceptable(sites_before, sites_after)
    if not ok_tier_b and tier_b_msg:
        errors.append(tier_b_msg)

    tests_passed = True
    if run_tests:
        tests_passed, detail = run_acceptance_tests(jac)
        if not tests_passed:
            errors.append(detail)

    metrics = build_metrics(sites_before, sites_after, tests_passed)
    return metrics, errors


def emit_metrics(metrics: dict, metrics_out: Path | None) -> None:
    payload = json.dumps(metrics, indent=2, sort_keys=True) + "\n"
    if metrics_out:
        out = _resolve(metrics_out)
        out.write_text(payload, encoding="utf-8")
    else:
        sys.stdout.write(payload)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--report-before",
        type=Path,
        required=True,
        help="project.c2jac.report.json before the patch",
    )
    parser.add_argument(
        "--report-after",
        type=Path,
        required=True,
        help="project.c2jac.report.json after the patch",
    )
    parser.add_argument(
        "--metrics-out",
        type=Path,
        help="write acceptance metrics JSON here (default: stdout)",
    )
    parser.add_argument(
        "--skip-tests",
        action="store_true",
        help="skip oracle/libtest/conformance subprocess (tier-B ratchet only)",
    )
    args = parser.parse_args(argv)

    metrics, errors = validate(
        args.report_before,
        args.report_after,
        run_tests=not args.skip_tests,
    )
    emit_metrics(metrics, args.metrics_out)
    if errors:
        for msg in errors:
            print(f"t8_accept: {msg}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
