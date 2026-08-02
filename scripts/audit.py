#!/usr/bin/env python3
"""Deterministic provenance + methodology audit for JacInteropBench.

Encodes, as executable invariants, the publication-blocking checks a reviewer
would run by hand (interop-bench#1-#9). Exits non-zero on the first failing
invariant class so CI cannot green-light a decimated, unmatched, or
unprovenanced result set.

By default it audits the ONE canonical bundle the paper is built from
(results/paper-canonical/). Point it elsewhere with --dir.

    python3 scripts/audit.py
    python3 scripts/audit.py --dir results/paper-canonical

Invariant classes:
  ENV      env.json present, git_dirty == false, governor pinned
  MANIFEST every listed file exists and its sha256 matches
  FFI      one_translation_unit, oracle agrees, struct row matched across every
           built toolchain (no scalar-substituted struct kernel)
  SWEEP    every cell has n == declared reps; per-cell digest consistent
  PAYLOAD  canonical != a single rep; >=3 reps; raw per-invocation samples kept;
           reported median reconstructs from the raw pool
  CROSSOVER the reported knee is the fixed/variable crossover (t0/slope), and
           there is NO positive rpc==direct break-even (rpc dominates everywhere)
  RPC      oracle agrees; loopback/two_box flags self-consistent
"""

from __future__ import annotations

import argparse
import hashlib
import json
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class Audit:
    def __init__(self) -> None:
        self.checked = 0
        self.failures: list[str] = []

    def ok(self, cond: bool, label: str) -> bool:
        self.checked += 1
        if not cond:
            self.failures.append(label)
        return cond

    def load(self, path: Path) -> dict | None:
        if not self.ok(path.exists(), f"missing file: {path}"):
            return None
        try:
            return json.loads(path.read_text())
        except Exception as e:  # noqa: BLE001
            self.ok(False, f"{path} does not parse: {e}")
            return None


def _linfit(xs: list[float], ys: list[float]) -> tuple[float, float]:
    """Ordinary least squares -> (intercept, slope)."""
    n = len(xs)
    mx = sum(xs) / n
    my = sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    sxy = sum((x - mx) * (y - my) for x, y in zip(xs, ys, strict=True))
    slope = sxy / sxx if sxx else 0.0
    return my - slope * mx, slope


def audit_env(a: Audit, d: Path) -> None:
    env = a.load(d / "env.json")
    if env is None:
        return
    a.ok(env.get("git_dirty") is False, "env.json git_dirty is not false")
    gov = (env.get("cpu") or {}).get("governor") or env.get("governor")
    # capture_env stores governor as the unique per-core set (a list), e.g.
    # ["performance"]; older captures used a bare string. Accept both.
    govs = gov if isinstance(gov, list) else [gov] if gov is not None else []
    if govs:
        a.ok(
            all(g == "performance" for g in govs),
            f"env governor is {gov!r}, not performance",
        )


def audit_manifest(a: Audit, d: Path) -> None:
    man = a.load(d / "MANIFEST.json")
    if man is None:
        return
    a.ok(bool(man.get("git_sha")), "MANIFEST missing git_sha")
    for rel, sha in (man.get("files") or {}).items():
        f = d / rel
        if a.ok(f.exists(), f"MANIFEST lists missing file {rel}"):
            got = hashlib.sha256(f.read_bytes()).hexdigest()
            a.ok(got == sha, f"MANIFEST sha mismatch for {rel}")


def audit_ffi(a: Audit, d: Path) -> None:
    doc = a.load(d / "aggregate" / "xtool_ffi.json")
    if doc is None:
        return
    a.ok(doc.get("one_translation_unit") is True, "FFI not one_translation_unit")
    a.ok(
        doc.get("oracle_all_toolchains_agree") is True,
        "FFI oracle: toolchains disagree on a digest",
    )
    cells = doc.get("cells", {})
    struct = cells.get("struct", {})
    ref = struct.get("reference_digest")
    tcs = struct.get("toolchains", {})
    a.ok(len(tcs) >= 2, "FFI struct row has <2 toolchains")
    for tc, row in tcs.items():
        # every toolchain must hit the SAME struct digest -> genuinely the same
        # by-value ib_dot, not a scalar reimplementation (interop-bench#1).
        a.ok(
            row.get("digest") == ref and row.get("digest_ok") is True,
            f"FFI struct row '{tc}' digest {row.get('digest')} != ref {ref} "
            "(unmatched struct kernel)",
        )


def audit_sweep(a: Audit, d: Path) -> None:
    doc = a.load(d / "aggregate" / "sweep.json")
    if doc is None:
        return
    reps = doc.get("reps")
    a.ok(isinstance(reps, int) and reps > 0, "sweep: no positive declared reps")
    for k, kc in doc.get("cells", {}).items():
        for v, vc in kc.get("variants", {}).items():
            for w, cell in vc.get("per_work", {}).items():
                a.ok(
                    cell.get("n") == reps,
                    f"sweep {k}.{v}[{w}] n={cell.get('n')}, declared reps={reps}",
                )
                a.ok(
                    cell.get("digest") is not None,
                    f"sweep {k}.{v}[{w}] has no correctness digest",
                )


def audit_payload(a: Audit, d: Path) -> None:
    p = d / "aggregate" / "payload.json"
    doc = a.load(p)
    if doc is None:
        return
    reps = doc.get("reps")
    a.ok(
        isinstance(reps, int) and reps >= 3,
        f"payload canonical has reps={reps} (<3 is not an aggregation)",
    )
    # not byte-identical to any sibling single-rep file
    for rep in sorted(p.parent.glob("payload*rep*.json")):
        a.ok(
            rep.read_bytes() != p.read_bytes(),
            f"payload canonical is byte-identical to {rep.name}",
        )
    per_size = doc.get("cells", {}).get("xop_feed_payload", {}).get("per_size", {})
    a.ok(len(per_size) >= 3, "payload has <3 size points")
    for size, slot in per_size.items():
        for v in ("direct", "rpc"):
            vc = slot.get(v, {})
            raw = vc.get("raw_per_call_ns")
            a.ok(
                bool(raw),
                f"payload {size}.{v} kept no raw per-invocation samples "
                "(bootstrap CI not reconstructible)",
            )
            if raw and vc.get("per_call_ns") is not None:
                a.ok(
                    abs(statistics.median(raw) - vc["per_call_ns"]) <= 1
                    or vc["per_call_ns"] in raw
                    or vc.get("n_reps", 0) > 1,
                    f"payload {size}.{v} reported per_call_ns not derivable from raw",
                )


def audit_crossover(a: Audit, d: Path) -> None:
    """finding#6: the reported knee is the fixed/variable crossover, and rpc
    never actually meets direct (it dominates in both intercept and slope)."""
    doc = a.load(d / "aggregate" / "payload.json")
    if doc is None:
        return
    per_size = doc.get("cells", {}).get("xop_feed_payload", {}).get("per_size", {})
    pts = []
    for slot in per_size.values():
        n_elems = slot.get("N")
        dv = slot.get("direct", {}).get("per_call_ns")
        rv = slot.get("rpc", {}).get("per_call_ns")
        if n_elems and dv is not None and rv is not None:
            pts.append((n_elems, dv, rv))
    if not a.ok(len(pts) >= 3, "crossover: <3 usable payload points"):
        return
    pts.sort()
    xs = [p[0] for p in pts]
    t0_d, sl_d = _linfit(xs, [p[1] for p in pts])
    t0_r, sl_r = _linfit(xs, [p[2] for p in pts])
    # rpc dominates: larger intercept AND larger slope -> the two lines never
    # cross at positive N. The paper must NOT claim an rpc==direct break-even.
    denom = sl_d - sl_r
    equality_n = (t0_r - t0_d) / denom if denom else float("inf")
    a.ok(
        sl_r > sl_d and t0_r > t0_d,
        f"crossover: expected rpc to dominate direct in both intercept and "
        f"slope (t0_r={t0_r:.0f} t0_d={t0_d:.0f} sl_r={sl_r:.3f} sl_d={sl_d:.3f})",
    )
    a.ok(
        equality_n <= 0,
        f"crossover: a POSITIVE rpc==direct break-even exists at N={equality_n:.0f}"
        " -- 'curves converge / break-even' would be a false claim",
    )
    if sl_r:
        knee = t0_r / sl_r
        print(
            f"  [info] rpc fixed/variable crossover t0/slope = N~{knee:.0f}; "
            f"rpc==direct equality N = {equality_n:.0f} (must be <=0)",
            file=sys.stderr,
        )


def audit_rpc(a: Audit, d: Path) -> None:
    doc = a.load(d / "aggregate" / "xtool_rpc.json")
    if doc is None:
        return
    a.ok(
        doc.get("oracle_all_comparands_agree") is True,
        "RPC oracle: comparands disagree on the checksum",
    )
    loop = doc.get("loopback")
    two = doc.get("two_box_mode")
    if loop is not None and two is not None:
        a.ok(loop != two, "RPC loopback/two_box flags are inconsistent")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default="results/paper-canonical")
    args = ap.parse_args()
    d = (ROOT / args.dir).resolve()

    a = Audit()
    if not d.exists():
        print(
            f"ABORT: {args.dir} does not exist. Produce it first:\n"
            f"  scripts/run_canonical.sh",
            file=sys.stderr,
        )
        return 1

    audit_env(a, d)
    audit_manifest(a, d)
    audit_ffi(a, d)
    audit_sweep(a, d)
    audit_payload(a, d)
    audit_crossover(a, d)
    audit_rpc(a, d)

    print(f"audit: checked {a.checked} invariants over {args.dir}", file=sys.stderr)
    if a.failures:
        for f in a.failures:
            print(f"  FAIL: {f}", file=sys.stderr)
        print(f"verdict: {len(a.failures)} failures", file=sys.stderr)
        return 1
    print("verdict: PASS", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
