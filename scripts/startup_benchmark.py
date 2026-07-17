#!/usr/bin/env python3
"""Startup benchmark harness for the Jac CLI lazy-router refactor.

Two measurement axes:
  1. Import budget (stable CI gate) — counts command/feature modules and
     floor delta via scripts/_startup_probe.py after warming the Jac cache.
  2. Wall-clock timing (informational only) — median latency of the real
     ``jac`` binary; never gated.

Usage:
  python scripts/startup_benchmark.py [--mode dev|release] [--iterations N]
  python scripts/startup_benchmark.py --check
  python scripts/startup_benchmark.py --write-baseline
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import statistics
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JAC_DIR = ROOT / "jac"
SCRIPTS = Path(__file__).resolve().parent
PROBE = SCRIPTS / "_startup_probe.py"
BASELINES = SCRIPTS / "baselines"

COMMAND_PREFIX = "jaclang.cli.commands."
FEATURE_PREFIXES = (
    "jaclang.runtimelib.client",
    "jaclang.scale",
    "jaclang.byllm",
    "jaclang.cli.shadcn",
)

# Lazy-dispatch contract embedded in the harness (not compared to baselines).
BUDGETS: dict[str, dict[str, int]] = {
    "global": {"max_commands": 0, "max_features": 0, "max_delta": 0},
    "command_help": {"max_commands": 0, "max_features": 0, "max_delta": 4},
}

FLOOR_CASE = ("version", ["--version"])


@dataclass(frozen=True)
class Case:
    name: str
    argv: list[str]
    budget_class: str | None
    expect_exit: int


CASES: list[Case] = [
    Case("bare", [], "global", 0),
    Case("version", ["--version"], "global", 0),
    Case("help", ["--help"], "global", 0),
    Case("purge_help", ["purge", "--help"], "global", 0),
    Case("unknown", ["not-a-real-command"], "global", 2),
    Case("tombstone", ["add"], "global", 2),
    Case("run_help", ["run", "--help"], "command_help", 0),
    Case("check_help", ["check", "--help"], "command_help", 0),
    Case("setup_help", ["setup", "--help"], "command_help", 0),
    Case(
        "run_hello",
        ["run", str(JAC_DIR / "tests" / "language" / "fixtures" / "hello.jac")],
        None,
        0,
    ),
]


def _python_exe() -> str:
    base = getattr(sys, "_base_executable", None)
    if base and os.path.basename(base).startswith("python"):
        return base
    for candidate in (sys.executable, shutil.which("python3"), shutil.which("python")):
        if candidate and os.path.basename(candidate).startswith("python"):
            return candidate
    return sys.executable


def _jac_exe() -> str:
    jac = os.environ.get("JAC_BENCHMARK_BIN")
    if jac:
        return jac
    which = subprocess.run(["which", "jac"], capture_output=True, text=True)
    if which.returncode == 0 and which.stdout.strip():
        return which.stdout.strip()
    return "jac"


def _probe_env(mode: str) -> dict[str, str]:
    env = os.environ.copy()
    env["JAC_BENCH_ROOT"] = str(JAC_DIR)
    if mode == "release":
        env["JAC_NO_DEV_SOURCE"] = "1"
    return env


def _categorize(
    modules: list[str], *, floor_modules: set[str]
) -> tuple[list[str], list[str], list[str]]:
    above_floor = sorted(set(modules) - floor_modules)
    commands = sorted(
        m
        for m in above_floor
        if m.startswith(COMMAND_PREFIX) or m == "jaclang.cli.commands"
    )
    features = sorted(
        m
        for m in above_floor
        if any(m == prefix or m.startswith(prefix + ".") for prefix in FEATURE_PREFIXES)
    )
    return commands, features, above_floor


def _run_probe(argv: list[str], *, env: dict[str, str]) -> dict:
    proc = subprocess.run(
        [_python_exe(), str(PROBE), *argv],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
    )
    for line in proc.stdout.splitlines():
        if line.startswith("PROBE_RESULT="):
            payload = json.loads(line.split("=", 1)[1])
            payload["probe_rc"] = proc.returncode
            return payload
    raise RuntimeError(
        f"probe produced no PROBE_RESULT for argv={argv!r}\n"
        f"stdout tail: {proc.stdout[-500:]}\n"
        f"stderr tail: {proc.stderr[-500:]}"
    )


def _warm_cache(jac: str, *, env: dict[str, str]) -> None:
    """Compile Jac modules once so probe runs see steady-state imports."""
    for _ in range(3):
        subprocess.run(
            [jac, "--version"],
            cwd=JAC_DIR,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )


def _warm_command_help_paths(*, env: dict[str, str]) -> None:
    """Prime lazy command-help paths so the first budget probe is steady-state."""
    for argv in (["run", "--help"], ["check", "--help"], ["setup", "--help"]):
        for _ in range(2):
            _run_probe(argv, env=env)


def _establish_floor(
    floor_argv: list[str], *, env: dict[str, str]
) -> tuple[dict, set[str]]:
    """Capture a stable --version import floor after warm-cache probes."""
    min_modules = 100
    prev: set[str] | None = None
    for _ in range(8):
        probe = _run_probe(floor_argv, env=env)
        modules = set(probe["modules"])
        if prev is not None and modules == prev and len(modules) >= min_modules:
            return probe, modules
        prev = modules
    raise RuntimeError(
        f"floor probe did not stabilize (last count={len(modules)} modules)"
    )


def _time_jac(
    jac: str,
    argv: list[str],
    *,
    env: dict[str, str],
    iterations: int,
) -> dict[str, float]:
    samples: list[float] = []
    for _ in range(iterations):
        start = time.perf_counter()
        proc = subprocess.run(
            [jac, *argv],
            cwd=JAC_DIR,
            env=env,
            capture_output=True,
            text=True,
        )
        elapsed_ms = (time.perf_counter() - start) * 1000
        samples.append(elapsed_ms)
        _ = proc  # exit code checked separately via probe
    ordered = sorted(samples)
    p95_idx = max(0, int(len(ordered) * 0.95) - 1)
    return {
        "median_ms": statistics.median(samples),
        "p95_ms": ordered[p95_idx],
        "min_ms": ordered[0],
        "max_ms": ordered[-1],
    }


def _probe_case(case: Case, *, floor_modules: set[str], env: dict[str, str]) -> dict:
    probe = _run_probe(case.argv, env=env)
    commands, features, delta_modules = _categorize(
        probe["modules"], floor_modules=floor_modules
    )

    result = {
        "name": case.name,
        "argv": ["jac", *case.argv],
        "expect_exit": case.expect_exit,
        "budget_class": case.budget_class,
        "exit_code": probe["exit_code"],
        "import_budget": {
            "command_modules": commands,
            "feature_modules": features,
            "command_count": len(commands),
            "feature_count": len(features),
            "delta_modules": delta_modules,
            "delta_count": len(delta_modules),
            "total_modules": len(probe["modules"]),
        },
        "timing": None,
    }

    if case.budget_class is not None:
        budget = BUDGETS[case.budget_class]
        violations: list[str] = []
        if probe["exit_code"] != case.expect_exit:
            violations.append(
                f"exit_code {probe['exit_code']} != expected {case.expect_exit}"
            )
        if len(commands) > budget["max_commands"]:
            violations.append(
                f"command_count {len(commands)} > {budget['max_commands']}: {commands}"
            )
        if len(features) > budget["max_features"]:
            violations.append(
                f"feature_count {len(features)} > {budget['max_features']}: {features}"
            )
        if len(delta_modules) > budget["max_delta"]:
            violations.append(
                f"delta_count {len(delta_modules)} > {budget['max_delta']}: {delta_modules}"
            )
        result["budget"] = budget
        result["violations"] = violations

    return result


def _print_case(case: dict) -> None:
    budget = case["import_budget"]
    timing = case["timing"]
    status = "ok"
    if case.get("violations"):
        status = "FAIL"
    timing_part = ""
    if timing is not None:
        timing_part = f" median={timing['median_ms']:7.1f}ms"
    print(
        f"{case['name']:14} [{status:4}] "
        f"exit={case['exit_code']} "
        f"cmds={budget['command_count']} "
        f"feats={budget['feature_count']} "
        f"delta={budget['delta_count']:2d}"
        f"{timing_part}",
        flush=True,
    )
    for violation in case.get("violations", []):
        print(f"  ! {violation}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Jac CLI startup benchmark")
    parser.add_argument("--mode", choices=("dev", "release"), default="dev")
    parser.add_argument("--iterations", type=int, default=3)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Enforce embedded import budgets (CI gate)",
    )
    parser.add_argument(
        "--write-baseline",
        action="store_true",
        help="Write JSON report under scripts/baselines/",
    )
    args = parser.parse_args()

    jac = _jac_exe()
    env = _probe_env(args.mode)

    print(f"Warming Jac cache via {jac} --version ...", flush=True)
    _warm_cache(jac, env=env)

    floor_name, floor_argv = FLOOR_CASE
    floor_probe, floor_modules = _establish_floor(floor_argv, env=env)
    _warm_command_help_paths(env=env)
    print(
        f"Floor reference: {floor_name} ({len(floor_modules)} modules, "
        f"exit={floor_probe['exit_code']})",
        flush=True,
    )
    print(flush=True)

    time_wall = not args.check

    report: dict = {
        "mode": args.mode,
        "jac": jac,
        "iterations": args.iterations,
        "floor_case": floor_name,
        "floor_module_count": len(floor_modules),
        "budgets": BUDGETS,
        "cases": [],
    }

    failures: list[str] = []
    active_cases = (
        [c for c in CASES if c.budget_class is not None] if args.check else CASES
    )
    results: list[dict] = []
    for case in active_cases:
        result = _probe_case(case, floor_modules=floor_modules, env=env)
        results.append(result)
        for violation in result.get("violations", []):
            failures.append(f"{case.name}: {violation}")

    if time_wall:
        print("Measuring wall-clock timing (informational) ...", flush=True)
        for case, result in zip(active_cases, results, strict=True):
            result["timing"] = _time_jac(
                jac, case.argv, env=env, iterations=args.iterations
            )

    for result in results:
        _print_case(result)

    report["cases"] = results

    if args.write_baseline:
        BASELINES.mkdir(parents=True, exist_ok=True)
        out = BASELINES / f"startup_{args.mode}.json"
        out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"\nWrote baseline {out}")

    if args.check and failures:
        print("\nImport budget check FAILED:")
        for item in failures:
            print(f"  - {item}")
        return 1

    if args.check:
        print("\nImport budget check passed.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
