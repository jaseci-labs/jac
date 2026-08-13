#!/usr/bin/env python3
"""Assemble payload_sweep_results.json with bootstrap confidence intervals.

Reads the per-size JSONs emitted by rerun_payload_sweep.sh (each carrying raw
per-invocation `metric_samples.per_call_ns` for `direct` and `rpc`), then
computes percentile-bootstrap 95% CIs for:

  * per-point median per-call ns (within-point resample of the raw samples),
  * the paired rpc/direct ratio (resample rounds, preserving the interleaved
    pairing the harness buys us),
  * the OLS fit coefficients fixed_ns / slope_ns_per_el (pairs-bootstrap over
    the sweep points), for the same four regimes the original fit reported.

Small n (5-9 per point) makes the median bootstrap coarse; the CIs are meant to
be read as order-of-magnitude, and are deliberately wide. RNG is seeded for
reproducibility; B and seed are recorded in the output.

Usage: python3 assemble_cis.py --raw <dir> --out <path> [--B 10000] [--seed 0]
"""
import argparse
import json
from pathlib import Path

import numpy as np

SIZES = ["p1", "p10", "p50", "p100", "p250", "p500", "p1000", "p2000",
         "p5000", "p10000", "p20000", "p30000", "p40000", "p50000",
         "p75000", "p100000"]

# Fit regimes: (key, predicate on N, human note)
REGIMES = [
    ("direct_full", "direct", lambda n: True, "in-process twin, all points"),
    ("rpc_full", "rpc", lambda n: True, "crossing, all points"),
    ("rpc_N_ge_1000", "rpc", lambda n: n >= 1000, "crossing, N>=1000"),
    ("rpc_N_ge_30000", "rpc", lambda n: n >= 30000,
     "post-crossing observed-slope regime"),
]


def ols(xs, ys):
    xs = np.asarray(xs, float)
    ys = np.asarray(ys, float)
    A = np.vstack([np.ones_like(xs), xs]).T
    (fixed, slope), *_ = np.linalg.lstsq(A, ys, rcond=None)
    resid = ys - (fixed + slope * xs)
    ss_res = float(resid @ resid)
    ss_tot = float(((ys - ys.mean()) ** 2).sum())
    r2 = 1 - ss_res / ss_tot if ss_tot else 1.0
    return float(fixed), float(slope), r2


def pct_ci(samples, lo=2.5, hi=97.5):
    a = np.percentile(samples, [lo, hi])
    return [float(a[0]), float(a[1])]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", required=True, type=Path,
                    help="dir of pay_<size>.json files")
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--B", type=int, default=10000)
    ap.add_argument("--seed", type=int, default=0)
    args = ap.parse_args()
    rng = np.random.default_rng(args.seed)
    B = args.B

    points = []
    for size in SIZES:
        p = args.raw / f"pay_{size}.json"
        doc = json.loads(p.read_text())
        cell = doc["cells"]["xop_feed_payload"]
        dv = cell["variants"]["direct"]
        rv = cell["variants"]["rpc"]
        n = int(dv["args"][0])
        d_raw = np.asarray(dv["metric_samples"]["per_call_ns"], float)
        r_raw = np.asarray(rv["metric_samples"]["per_call_ns"], float)
        if "metric_samples" not in dv:
            raise SystemExit(
                f"{p} lacks metric_samples -- re-run the sweep with the patched "
                "harness (common.jac aggregate_runs)")

        # per-point median CI (within-point resample)
        d_meds = np.median(rng.choice(d_raw, (B, d_raw.size), replace=True), 1)
        r_meds = np.median(rng.choice(r_raw, (B, r_raw.size), replace=True), 1)

        # paired ratio CI (resample rounds; interleaving pairs the two sides)
        m = min(d_raw.size, r_raw.size)
        idx = rng.integers(0, m, (B, m))
        ratio_boot = (np.median(r_raw[idx], 1) / np.median(d_raw[idx], 1))

        points.append({
            "n": n,
            "direct": {
                "per_call_ns": int(np.median(d_raw)),
                "per_call_ns_ci95": pct_ci(d_meds),
                "samples": int(d_raw.size),
                "digest": dv["digest"],
            },
            "rpc": {
                "per_call_ns": int(np.median(r_raw)),
                "per_call_ns_ci95": pct_ci(r_meds),
                "samples": int(r_raw.size),
                "digest": rv["digest"],
            },
            "ratio": float(np.median(r_raw) / np.median(d_raw)),
            "ratio_ci95": pct_ci(ratio_boot),
            "digest_identical": dv["canonical_digest"] == rv["canonical_digest"],
        })

    # Fit CIs: pairs-bootstrap over the points in each regime.
    fits = {}
    for key, which, pred, note in REGIMES:
        pts = [p for p in points if pred(p["n"])]
        xs = np.array([p["n"] for p in pts], float)
        ys = np.array([p[which]["per_call_ns"] for p in pts], float)
        fixed, slope, r2 = ols(xs, ys)
        k = len(pts)
        bi = rng.integers(0, k, (B, k))
        bfix, bslope = np.empty(B), np.empty(B)
        for j in range(B):
            f, s, _ = ols(xs[bi[j]], ys[bi[j]])
            bfix[j], bslope[j] = f, s
        fits[key] = {
            "fixed_ns": fixed,
            "fixed_ns_ci95": pct_ci(bfix),
            "slope_ns_per_el": slope,
            "slope_ns_per_el_ci95": pct_ci(bslope),
            "r2": r2,
            "note": note,
        }

    # Break-even N where slope term overtakes fixed cost (full rpc fit), with CI.
    rf = fits["rpc_full"]
    be = rf["fixed_ns"] / rf["slope_ns_per_el"]

    out = {
        "schema": "payload_cardinality_sweep_v2_ci",
        "kernel": "xop_feed_payload",
        "scenario": ("loopback sv-to-sv RPC returning list[N] ints vs in-process "
                     "direct dispatch; N swept 1..100000"),
        "bootstrap": {"B": B, "seed": args.seed, "method": "percentile",
                      "ratio": "paired round resample",
                      "fits": "pairs bootstrap over points"},
        "sizes_N": [p["n"] for p in points],
        "all_digests_identical": all(p["digest_identical"] for p in points),
        "points": points,
        "fits_per_call_ns": fits,
        "break_even_N_slope_overtakes_fixed": be,
    }
    args.out.write_text(json.dumps(out, indent=2) + "\n")
    print(f"wrote {args.out}")
    for k, f in fits.items():
        print(f"  {k:16s} slope={f['slope_ns_per_el']:8.1f} "
              f"CI{f['slope_ns_per_el_ci95']}  R2={f['r2']:.3f}")
    print(f"  break-even N = {be:.0f}")


if __name__ == "__main__":
    main()
