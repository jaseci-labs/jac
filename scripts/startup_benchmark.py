#!/usr/bin/env python3
"""Startup benchmark harness for the Jac CLI lazy-router refactor.

Measures wall time, peak RSS, and imported-module counts for common CLI paths.
Writes machine-readable JSON under scripts/baselines/.

Usage:
  python scripts/startup_benchmark.py [--mode dev|release] [--iterations N]
"""

from __future__ import annotations

import argparse
import json
import os
import statistics
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JAC_DIR = ROOT / "jac"
BASELINES = Path(__file__).resolve().parent / "baselines"

CASES: list[tuple[str, list[str]]] = [
    ("bare", []),
    ("version", ["--version"]),
    ("help", ["--help"]),
    ("purge_help", ["purge", "--help"]),
    ("unknown", ["not-a-real-command"]),
    ("tombstone", ["add"]),
    ("run_help", ["run", "--help"]),
    ("check_help", ["check", "--help"]),
    ("setup_help", ["setup", "--help"]),
]


def _jac_exe() -> str:
    jac = os.environ.get("JAC_BENCHMARK_BIN")
    if jac:
        return jac
    which = subprocess.run(["which", "jac"], capture_output=True, text=True)
    if which.returncode == 0 and which.stdout.strip():
        return which.stdout.strip()
    return sys.executable


def _runner_script(argv_tail: list[str], blocked: list[str]) -> str:
    blocked_repr = repr(blocked)
    argv_repr = repr(["jac"] + argv_tail)
    return f"""
import os, sys, time, json, runpy
ROOT = {JAC_DIR!r}
sys.path.insert(0, ROOT)
os.chdir(ROOT)

BLOCKED = set({blocked_repr})
real_import = __builtins__.__import__

def tracking_import(name, globals=None, locals=None, fromlist=(), level=0):
    top = name.split('.')[0]
    if top in BLOCKED or name in BLOCKED:
        raise ImportError(f"blocked import: {{name}}")
    return real_import(name, globals, locals, fromlist, level)

__builtins__.__import__ = tracking_import

t0 = time.perf_counter()
try:
    sys.argv = {argv_repr}
    runpy.run_module('jaclang', run_name='__main__', alter_sys=True)
    code = 0
except SystemExit as exc:
    code = int(exc.code) if isinstance(exc.code, int) else 1
except Exception:
    code = 1
elapsed_ms = (time.perf_counter() - t0) * 1000
print(json.dumps({{"elapsed_ms": elapsed_ms, "exit_code": code}}))
"""


def _run_case(
    jac: str,
    argv_tail: list[str],
    *,
    env: dict[str, str],
    blocked: list[str],
) -> dict:
    script = _runner_script(argv_tail, blocked)
    proc = subprocess.run(
        [jac, "-c", script],
        cwd=JAC_DIR,
        env=env,
        capture_output=True,
        text=True,
    )
    metrics: dict = {
        "exit_code": proc.returncode,
        "stderr": proc.stderr[-500:],
    }
    for line in reversed(proc.stdout.splitlines()):
        line = line.strip()
        if line.startswith("{"):
            try:
                metrics.update(json.loads(line))
                break
            except json.JSONDecodeError:
                pass
    return metrics


def _rss_kb(pid: int) -> int:
    try:
        with open(f"/proc/{pid}/status") as handle:
            for row in handle:
                if row.startswith("VmHWM:"):
                    return int(row.split()[1])
    except OSError:
        return 0
    return 0


def benchmark_case(
    name: str,
    argv_tail: list[str],
    *,
    jac: str,
    env: dict[str, str],
    iterations: int,
) -> dict:
    samples: list[float] = []
    peak_rss: list[int] = []
    exit_codes: list[int] = []

    for _ in range(iterations):
        script = _runner_script(argv_tail, blocked=[])
        start = time.perf_counter()
        proc = subprocess.Popen(
            [jac, "-c", script],
            cwd=JAC_DIR,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        out, err = proc.communicate()
        elapsed = (time.perf_counter() - start) * 1000
        samples.append(elapsed)
        peak_rss.append(_rss_kb(proc.pid))
        exit_codes.append(proc.returncode)
        for line in reversed(out.splitlines()):
            if line.strip().startswith("{"):
                try:
                    payload = json.loads(line.strip())
                    exit_codes[-1] = int(payload.get("exit_code", proc.returncode))
                    break
                except json.JSONDecodeError:
                    pass

    return {
        "name": name,
        "argv": ["jac", *argv_tail],
        "median_ms": statistics.median(samples),
        "p95_ms": sorted(samples)[max(0, int(len(samples) * 0.95) - 1)],
        "peak_rss_kb_max": max(peak_rss) if peak_rss else 0,
        "exit_codes": exit_codes,
        "stderr_tail": err[-200:] if err else "",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Jac CLI startup benchmark")
    parser.add_argument("--mode", choices=("dev", "release"), default="dev")
    parser.add_argument("--iterations", type=int, default=3)
    parser.add_argument("--write-baseline", action="store_true")
    args = parser.parse_args()

    jac = _jac_exe()
    env = os.environ.copy()
    if args.mode == "release":
        env["JAC_NO_DEV_SOURCE"] = "1"

    report: dict = {
        "mode": args.mode,
        "jac": jac,
        "iterations": args.iterations,
        "cases": [],
        "fast_path_import_blocks": {},
    }

    for name, argv_tail in CASES:
        case = benchmark_case(
            name,
            argv_tail,
            jac=jac,
            env=env,
            iterations=args.iterations,
        )
        report["cases"].append(case)
        print(
            f"{name:14} median={case['median_ms']:7.1f}ms "
            f"rss={case['peak_rss_kb_max']:7d}KB exit={case['exit_codes']}"
        )

    BASELINES.mkdir(parents=True, exist_ok=True)
    out = BASELINES / f"startup_{args.mode}.json"
    if args.write_baseline or not out.exists():
        out.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(f"Wrote baseline {out}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
