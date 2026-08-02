#!/usr/bin/env python3
"""Controlled payload-cardinality sweep for xop_feed_payload.

Re-captures the family-2 payload sweep (loopback sv->sv RPC returning list[N]
ints vs in-process, fit t(N)=t0+b*N) under a PINNED CPU governor + disabled
turbo, superseding the earlier uncontrolled single run. Drives the real harness
one size at a time (``jac run harness/xbench.jac --experimental --kernels
xop_feed_payload --sizes pN --invocations 20``) and aggregates the per-size
direct/rpc medians into one document.

Output schema mirrors the archived payload_sweep_results.json enough for the
paper's fit: cells.xop_feed_payload.per_size.<pN>.{direct,rpc}.

Usage:
    python3 scripts/payload_sweep_controlled.py --reps 1 \
        --out results/controlled/payload_noturbo.json
"""

from __future__ import annotations

import argparse
import json
import statistics
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path

BENCH = Path(__file__).resolve().parents[1] / "jac" / "examples" / "interopbench"

# the 16 design points p1..p100000 defined in harness/xbench.jac CATALOG
SIZES = [
    "p1",
    "p10",
    "p50",
    "p100",
    "p250",
    "p500",
    "p1000",
    "p2000",
    "p5000",
    "p10000",
    "p20000",
    "p30000",
    "p40000",
    "p50000",
    "p75000",
    "p100000",
]
SIZE_N = {s: int(s[1:]) for s in SIZES}


def governor() -> dict:
    g = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
    t = "/sys/devices/system/cpu/intel_pstate/no_turbo"
    try:
        gov = Path(g).read_text().strip()
        tur = Path(t).read_text().strip() if Path(t).exists() else None
    except OSError:
        gov, tur = None, None
    return {"governor": gov, "turbo_disabled": tur}


def run_size(size: str, invocations: int, timeout_s: int) -> dict | None:
    """Run one payload size, return {'direct': median_ns, 'rpc': median_ns}."""
    out = BENCH / f"_paysweep_{size}.json"
    cmd = [
        "jac",
        "run",
        "harness/xbench.jac",
        "--experimental",
        "--kernels",
        "xop_feed_payload",
        "--sizes",
        size,
        "--invocations",
        str(invocations),
        "--out",
        str(out),
    ]
    try:
        subprocess.run(
            cmd, cwd=str(BENCH), capture_output=True, timeout=timeout_s, check=True
        )
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError) as e:
        print(f"  {size}: FAILED ({type(e).__name__})", file=sys.stderr)
        return None
    doc = json.loads(out.read_text())
    out.unlink(missing_ok=True)
    variants = doc["cells"]["xop_feed_payload"]["variants"]
    res = {}
    for v in ("direct", "rpc"):
        vc = variants[v]
        res[v] = {
            "median_ns": vc["median_ns"],
            "per_call_ns": vc.get("metrics", {}).get("per_call_ns"),
            "min_ns": vc["min_ns"],
            "max_ns": vc["max_ns"],
            "digest": vc["digest"],
            "canonical_digest": vc.get("canonical_digest"),
            # RAW per-invocation samples so bootstrap CIs are reconstructible
            # from the canonical artifact alone (interop-bench#7).
            "samples_ns": vc.get("samples_ns"),
            "metric_samples_per_call_ns": vc.get("metric_samples", {}).get(
                "per_call_ns"
            ),
        }
    res["identical"] = variants["direct"]["digest"] == variants["rpc"]["digest"]
    return res


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sizes", default=",".join(SIZES))
    ap.add_argument("--invocations", type=int, default=20)
    ap.add_argument("--reps", type=int, default=3)
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    sizes = [s.strip() for s in args.sizes.split(",") if s.strip()]

    gov = governor()
    if gov["governor"] and gov["governor"] != "performance":
        print(
            f"ABORT: governor is '{gov['governor']}' (not 'performance').",
            file=sys.stderr,
        )
        sys.exit(2)
    if gov["turbo_disabled"] not in ("1", None):
        print(
            "WARNING: turbo is NOT disabled (no_turbo != 1); absolutes will "
            "drift over the sweep.",
            file=sys.stderr,
        )

    per_size: dict = {}
    for rep in range(args.reps):
        for size in sizes:
            r = run_size(size, args.invocations, args.timeout)
            if r is None:
                continue
            slot = per_size.setdefault(size, {"N": SIZE_N[size], "reps": []})
            slot["reps"].append(r)
            print(
                f"  rep{rep + 1} {size:8s} direct={r['direct']['per_call_ns']}ns "
                f"rpc={r['rpc']['per_call_ns']}ns identical={r['identical']}",
                file=sys.stderr,
            )

    # collapse reps -> median of rep medians per variant, but RETAIN the full raw
    # per-invocation sample pool (all reps x all invocations) + per-rep medians +
    # the canonical digest, so the reported point and its CI are independently
    # reconstructible from this file (interop-bench#5,#7).
    for slot in per_size.values():
        for v in ("direct", "rpc"):
            reps = slot["reps"]
            pcs = [
                rp[v]["per_call_ns"] for rp in reps if rp[v]["per_call_ns"] is not None
            ]
            raw_pool: list[int] = []
            for rp in reps:
                ms = rp[v].get("metric_samples_per_call_ns")
                if ms:
                    raw_pool.extend(ms)
            digs = {
                rp[v].get("canonical_digest")
                for rp in reps
                if rp[v].get("canonical_digest")
            }
            slot[v] = {
                "per_call_ns": statistics.median(pcs) if pcs else None,
                "reps_per_call_ns": pcs,
                "n_reps": len(pcs),
                "raw_per_call_ns": raw_pool,
                "n_raw": len(raw_pool),
                "canonical_digest": next(iter(digs))
                if len(digs) == 1
                else sorted(digs),
                "raw_samples_ns": [rp[v].get("samples_ns") for rp in reps],
            }
        slot["identical"] = all(rp["identical"] for rp in slot["reps"])
        del slot["reps"]

    doc = {
        "schema_version": 1,
        "kind": "controlled_payload_sweep",
        "captured_utc": datetime.now(UTC).isoformat(),
        "invocations": args.invocations,
        "reps": args.reps,
        "sizes": sizes,
        "machine_control": gov,
        "note": "CPU governor pinned to performance, turbo disabled. See "
        "results/controlled/env.json for full provenance.",
        "cells": {"xop_feed_payload": {"per_size": per_size}},
    }
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(doc, indent=1))
    print(f"wrote {out}", file=sys.stderr)


if __name__ == "__main__":
    main()
