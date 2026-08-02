#!/usr/bin/env python3
"""Controlled multi-work sweep for interopbench iop_* kernels.

Reproduces the work-size sweep (per_call vs work -> slope/intercept) that fed
the paper's slope and callback-fixed-cost claims, but under a PINNED CPU
governor (recorded in env.json). Runs the REAL kernels as subprocesses
(``jac run kernels/<k>.jac <variant> <work> <calls>``) -- the exact path the
harness uses -- parallelised across invocations.

Output schema matches the archived sweep_results.json (cells.<k>.variants.<v>
.per_work.<w>.median_per_call_ns) so slopes are directly comparable.

Usage:
    python3 scripts/sweep_controlled.py --reps 20 \
        --out results/controlled/sweep_perf.json
"""

from __future__ import annotations

import argparse
import json
import re
import statistics
import subprocess
import sys
from datetime import UTC, datetime
from multiprocessing import Pool
from pathlib import Path

BENCH = Path(__file__).resolve().parents[1] / "jac" / "examples" / "interopbench"

# kernel -> variants (matches the kernels' with-entry dispatch)
VARIANTS = {
    "iop_call": ["free", "bridge"],
    "iop_cb": ["free", "bridge"],
    "iop_symmetric": ["sv_local", "sv_to_na", "na_local", "na_to_sv"],
}

# work sizes match the archived sweep design points (25..3200) for comparability
DEFAULT_WORKS = [25, 50, 100, 200, 400, 800, 1600, 3200]
DEFAULT_CALLS = 40
METRIC_RE = re.compile(rb"m:(?:per_call_ns|invoke_ns)=(\d+)")
# the kernel's correctness digest line, e.g. "call:199227369" / "sym:...".
# excludes the "m:..." metric lines (letters then '=' , not ':<digits>').
DIGEST_RE = re.compile(rb"(?m)^([a-z_]+):(\d+)$")


def run_one(task: tuple) -> tuple:
    kernel, variant, work, calls = task
    cmd = ["jac", "run", f"kernels/{kernel}.jac", variant, str(work), str(calls)]
    # A transient subprocess stall/timeout (e.g. a contended CI runner, where the
    # tiniest cell is most easily starved) yields no metric. Re-measure a bounded
    # number of times rather than dropping the sample and tripping the exact-reps
    # gate on runner flakiness. This never fires on a quiet pinned box, so
    # canonical results stay deterministic; it only rescues jitter. It does NOT
    # touch the digest-consistency check -- a real miscompile is still caught.
    for _ in range(3):
        try:
            p = subprocess.run(cmd, cwd=str(BENCH), capture_output=True, timeout=60)
        except subprocess.TimeoutExpired:
            continue
        m = METRIC_RE.findall(p.stdout)
        per_call = int(m[-1]) if m else None
        if per_call is None:
            continue
        dm = DIGEST_RE.search(p.stdout)
        digest = dm.group(0).decode() if dm else None
        return (task, per_call, digest)
    return (task, None, None)


def governor() -> dict:
    g = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
    t = "/sys/devices/system/cpu/intel_pstate/no_turbo"
    try:
        gov = Path(g).read_text().strip()
        tur = Path(t).read_text().strip() if Path(t).exists() else None
    except OSError:
        gov, tur = None, None
    return {"governor": gov, "turbo_disabled": tur}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernels", default=",".join(VARIANTS))
    ap.add_argument("--works", default=",".join(map(str, DEFAULT_WORKS)))
    ap.add_argument("--calls", type=int, default=DEFAULT_CALLS)
    ap.add_argument("--reps", type=int, default=20)
    ap.add_argument("--jobs", type=int, default=8)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    kernels = [k.strip() for k in args.kernels.split(",") if k.strip()]
    works = [int(w) for w in args.works.split(",") if w.strip()]
    out = Path(args.out)

    tasks = []
    for k in kernels:
        for v in VARIANTS.get(k, []):
            for w in works:
                for _ in range(args.reps):
                    tasks.append((k, v, w, args.calls))

    print(
        f"sweep: {len(tasks)} invocations "
        f"({len(kernels)} kernels x {sum(len(VARIANTS[k]) for k in kernels)} variants "
        f"x {len(works)} works x {args.reps} reps), jobs={args.jobs}",
        file=sys.stderr,
    )

    # guardrail: refuse to run unless governor is pinned
    gov = governor()
    if gov["governor"] and gov["governor"] != "performance":
        print(
            f"ABORT: governor is '{gov['governor']}' (not 'performance'). "
            f"Pin it first: echo performance | sudo tee "
            f"/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor",
            file=sys.stderr,
        )
        sys.exit(2)

    results: dict = {}
    digests: dict = {}
    failures: list[str] = []
    done = 0
    with Pool(args.jobs) as pool:
        for task, per_call, digest in pool.imap_unordered(run_one, tasks):
            k, v, w, _ = task
            done += 1
            if done % 50 == 0:
                print(f"  ...{done}/{len(tasks)}", file=sys.stderr)
            if per_call is None:
                # a failed/timed-out invocation is a hard error, not a silent skip
                failures.append(f"{k}.{v}[{w}] invocation produced no metric")
                continue
            results.setdefault(k, {}).setdefault(v, {}).setdefault(w, []).append(
                per_call
            )
            if digest is not None:
                digests.setdefault(k, {}).setdefault(v, {}).setdefault(w, set()).add(
                    digest
                )

    cells = {}
    for k in kernels:
        vcell = {}
        for v in VARIANTS.get(k, []):
            pw = {}
            for w in works:
                xs = results.get(k, {}).get(v, {}).get(w, [])
                # HARD GATE: every cell must have exactly `reps` samples. A short
                # cell means a subprocess failed -- refuse it rather than fitting
                # a slope through a silently-decimated cell (interop-bench#4).
                if len(xs) != args.reps:
                    failures.append(
                        f"{k}.{v}[{w}] n={len(xs)}, declared reps={args.reps}"
                    )
                dset = digests.get(k, {}).get(v, {}).get(w, set())
                if len(dset) > 1:
                    failures.append(
                        f"{k}.{v}[{w}] digest disagreement across reps: {sorted(dset)}"
                    )
                if not xs:
                    continue
                pw[str(w)] = {
                    "median_per_call_ns": statistics.median(xs),
                    "min": min(xs),
                    "max": max(xs),
                    "stdev": statistics.pstdev(xs) if len(xs) > 1 else 0.0,
                    "samples": xs,
                    "n": len(xs),
                    "digest": next(iter(dset)) if dset else None,
                }
            vcell[v] = {"per_work": pw}
        cells[k] = {"variants": vcell}

    if failures:
        print(
            f"ABORT: {len(failures)} incomplete/inconsistent cell(s); refusing to "
            f"write a decimated dataset:",
            file=sys.stderr,
        )
        for f in failures:
            print(f"  FAIL: {f}", file=sys.stderr)
        sys.exit(1)

    doc = {
        "schema_version": 1,
        "kind": "controlled_sweep",
        "captured_utc": datetime.now(UTC).isoformat(),
        "calls": args.calls,
        "reps": args.reps,
        "works": works,
        "kernels": kernels,
        "machine_control": gov,
        "note": "CPU governor pinned to performance. See results/controlled/env.json for full provenance.",
        "cells": cells,
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(doc, indent=1))
    print(f"wrote {out}", file=sys.stderr)


if __name__ == "__main__":
    main()
