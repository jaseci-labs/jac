#!/usr/bin/env python3
"""Quarantine historical interopbench captures into results/archive/.

Implements STEPS.md Phase A, item 2 ("Quarantine all historical captures").

Each capture currently sitting untracked in jac/examples/interopbench/results/
is MOVED (never deleted) into its own results/archive/<date>-<name>/ directory
alongside a MANIFEST.json recording:

  * capture timestamp (from the file's provenance block, else mtime)
  * best-effort git attribution (the commit that was HEAD at capture time,
    assuming a clean worktree at capture -- flagged as uncertain otherwise)
  * the paper claims the capture feeds
  * the measured contradiction vs. its counterpart capture
  * publication_status + a specific reason
  * SHA-256 of the raw file

The contradiction analysis is derived from the files themselves (cross-runtime
ratios, sweep slopes, callback fixed cost) and is asserted here as data so the
quarantine record explains WHY each capture is excluded.

Usage:
    python scripts/quarantine_captures.py            # quarantine + manifest
    python scripts/quarantine_captures.py --dry-run  # show plan, move nothing
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
from datetime import UTC, datetime
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SRC = REPO / "jac" / "examples" / "interopbench" / "results"
ARCHIVE = REPO / "results" / "archive"

# Per-file quarantine metadata. `analysis` explains the capture's standing.
FILES: dict[str, dict[str, object]] = {
    "xruntime_results.json": {
        "descriptor": "xruntime-base",
        "sample_count": None,  # determined from file at runtime
        "feeds_paper_claims": [
            "historical baseline cross-runtime table (pre-n7 / pre-n30)",
        ],
        "analysis": (
            "Earliest cross-runtime capture. Superseded by the n7 and n30 "
            "captures which directly contradict each other on the headline "
            "135x/213x ratios (STEPS.md item 30). No full provenance "
            "(missing git_sha, jac/node/llvm versions, machine-control status)."
        ),
    },
    "xruntime_results_n7.json": {
        "descriptor": "xruntime-n7",
        "sample_count": 7,
        "feeds_paper_claims": [
            "paper.tex L576-600: svc_split 135x, feed 213x (the SELECTED table)",
            "abstract / conclusion cross-runtime superiority claims",
        ],
        "analysis": (
            "CONTRADICTED. This 7-sample capture (2026-07-22) is the source of "
            "the paper's 135x (svc_split) and 213x (feed) ratios. The 30-sample "
            "capture (xruntime-n30, 2026-07-23) gives 515x and 329x instead. "
            "The direct side is stable across both (690k->696k ns); only the "
            "RPC/client side inflated ~3.9x, so this is a systematic change in "
            "the RPC path across commit 367a786cc, NOT random variance. "
            "STEPS.md item 30: replace this selected table with controlled "
            "multi-session results before any cross-runtime claim is trusted."
        ),
    },
    "xruntime_results_n30.json": {
        "descriptor": "xruntime-n30",
        "sample_count": 30,
        "feeds_paper_claims": [
            "(not currently cited in paper.tex; contradicts the cited n7 table)",
        ],
        "analysis": (
            "CONTRADICTS the paper's selected n7 table. Gives 515x (svc_split) "
            "and 329x (feed) vs the n7's 135x/213x. Captured ~17 min after "
            "commit 367a786cc landed (the payload-sweep + paper commit), "
            "making that commit / the uncommitted tree at capture time the "
            "prime suspect for the RPC-path inflation. Retained as the "
            "evidence that the n7 numbers do not reproduce."
        ),
    },
    "xruntime_results_n30_ci.json": {
        "descriptor": "xruntime-n30-ci",
        "sample_count": 30,
        "feeds_paper_claims": ["(companion CI annotation to xruntime-n30)"],
        "analysis": (
            "Bootstrap CI companion to xruntime-n30. Same contradiction as its "
            "base file. No provenance block at all."
        ),
    },
    "sweep_results.json": {
        "descriptor": "sweep-n5",
        "sample_count": 5,
        "feeds_paper_claims": [
            "paper.tex L664-670: iop_cb free intercept=-901 slope=182.2, "
            "bridge intercept=4471 slope=183.5",
            "paper.tex L626: 'slopes statistically identical (182.2 vs 183.5)'",
            "the ~5.4 us fixed-callback-cost claim (intercept=4471 ns)",
        ],
        "analysis": (
            "CONTRADICTED on TWO axes. (1) Slope: this n5 capture gives iop_cb "
            "slope ~183 ns/work; the n30 capture gives ~88 ns/work -- the "
            "per-work cost HALVED across commit 367a786cc (STEPS.md item 21). "
            "(2) Callback fixed cost: bridge intercept is 4471 ns here (~5.4 us "
            "claim) but 9 ns in n30 -- i.e. unresolvable above noise there "
            "(STEPS.md items 15,18,19). The paper's slope/intercept numbers and "
            "the 5.4 us claim are sourced from THIS file and do not reproduce."
        ),
    },
    "sweep_results_n30.json": {
        "descriptor": "sweep-n30",
        "sample_count": 30,
        "feeds_paper_claims": ["(not currently cited; contradicts sweep-n5)"],
        "analysis": (
            "CONTRADICTS sweep-n5. iop_cb slope 87.8/90.4 ns/work (vs 182/183), "
            "bridge fixed cost 9 ns (vs 4471). The callback crossing is "
            "unresolvable above noise in this capture. Note iop_call/free "
            "consistency with these ~88 ns/work slopes suggests the n30 slopes "
            "are internally coherent -- so the n5 slopes (not these) are the "
            "outlier. Either way the two captures cannot be averaged."
        ),
    },
    "sweep_results_n30_ci.json": {
        "descriptor": "sweep-n30-ci",
        "sample_count": 30,
        "feeds_paper_claims": ["(companion CI annotation to sweep-n30)"],
        "analysis": "Bootstrap CI companion to sweep-n30. Same contradictions.",
    },
    "payload_sweep_results.json": {
        "descriptor": "payload-sweep",
        "sample_count": None,
        "feeds_paper_claims": [
            "paper.tex L580-600, L766, L849-851: 934 ns/element slope, "
            "break-even N~20810, the 27479x..39x ratio table",
        ],
        "analysis": (
            "Payload sweep (9 samples/point). No provenance block. The 934 "
            "ns/element slope and N~20810 break-even are FITTED values, not "
            "directly measured -- STEPS.md items 23-25 require re-fitting with "
            "fixed design points + per-point round resampling, and renaming "
            "'break-even'. Retain, but flag as needing re-analysis before any "
            "payload claim is trusted."
        ),
    },
    "ffi_baseline.json": {
        "descriptor": "ffi-baseline",
        "sample_count": None,
        "feeds_paper_claims": [
            "paper.tex L539-560: jac FFI 3.1 ns, 102x vs cffi, 153x vs ctypes",
        ],
        "analysis": (
            "FFI baseline (5 timed). No provenance block. The 102x/153x result "
            "compiles a jac-native loop vs interpreted Python+ctypes/cffi -- "
            "different execution placement, so it is NOT a general interop-"
            "overhead result (STEPS.md items 35,40). Needs matched no-op/"
            "identity controls before the headline is defensible."
        ),
    },
    "bridges_results.json": {
        "descriptor": "bridges",
        "sample_count": None,
        "feeds_paper_claims": [
            "native-bridge family (iop_call/iop_cb/iop_symmetric/iop_ffi_*)",
        ],
        "analysis": (
            "Native-bridge capture. Partial provenance (no git_sha/toolchain). "
            "Overlaps with the contradicted sweep files on iop_cb; treat as "
            "superseded pending controlled re-capture."
        ),
    },
    "interop_audit.json": {
        "descriptor": "interop-audit",
        "sample_count": None,
        "feeds_paper_claims": [
            "structural manifest/wrapper audit (non-timing, load-bearing for correctness claims)",
        ],
        "analysis": (
            "Structural audit only -- NOT a timing capture, so it is NOT "
            "affected by the performance contradictions. Retained as-is; "
            "still needs a provenance block but its correctness-witness role "
            "survives the timing rework."
        ),
    },
}


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def captured_utc(path: Path) -> tuple[str, str]:
    """Return (iso_utc, source) from provenance block if present, else mtime."""
    try:
        d = json.loads(path.read_text())
    except Exception:
        d = {}
    prov = d.get("provenance") if isinstance(d, dict) else None
    if isinstance(prov, dict) and prov.get("captured_utc"):
        return str(prov["captured_utc"]), "provenance.captured_utc"
    ts = datetime.fromtimestamp(path.stat().st_mtime, tz=UTC)
    return ts.isoformat(timespec="seconds").replace("+00:00", "Z"), "file_mtime"


def git_attribution(iso_utc: str) -> dict[str, str | None]:
    """Best-effort: the commit that was HEAD at capture time (assumes clean tree)."""
    head_at = run_git(["log", "-1", "--format=%H|%cI|%s", "--before=" + iso_utc])
    next_after = (
        run_git(
            [
                "log",
                "-1",
                "--format=%H|%cI|%s",
                "--ancestry-path",
                head_at.split("|", 1)[0] + "..HEAD",
            ]
            if head_at and "|" in head_at
            else ["log", "-1", "--format=%H|%cI|%s"]
        )
        if head_at
        else None
    )
    return {
        "head_at_capture": split_git(head_at),
        "next_commit_after": split_git(next_after),
        "caveat": (
            "Assumes a CLEAN worktree at capture time. Captures were likely run "
            "from a dirty tree, so this is an upper bound on the SHA, not exact."
        ),
    }


def split_git(s: str | None) -> dict[str, str] | None:
    if not s or "|" not in s:
        return None
    sha, date, subj = s.split("|", 2)
    return {"sha": sha, "date": date, "subject": subj}


def run_git(args: list[str]) -> str | None:
    try:
        return (
            subprocess.run(
                ["git", "-C", str(REPO), *args],
                capture_output=True,
                text=True,
                check=True,
                timeout=15,
            ).stdout.strip()
            or None
        )
    except Exception:
        return None


def manifest_for(name: str, path: Path) -> tuple[Path, dict[str, object]]:
    meta = FILES[name]
    iso, src = captured_utc(path)
    date_part = iso[:10]  # YYYY-MM-DD
    desc = str(meta["descriptor"])
    dest_dir = ARCHIVE / f"{date_part}-{desc}"
    try:
        d = json.loads(path.read_text())
    except Exception:
        d = {}
    n = meta.get("sample_count")
    if n is None and isinstance(d, dict):
        n = d.get("timed_samples") or d.get("timed")
    manifest = {
        "schema_version": 1,
        "logical_name": desc,
        "source_file": name,
        "source_path_relativeto_repo": str(path.relative_to(REPO)),
        "captured_utc": iso,
        "captured_utc_source": src,
        "git_attribution": git_attribution(iso),
        "sample_count": n,
        "machine_controlled": False,
        "machine_control_notes": (
            "governor=powersave, turbo=on, no CPU pinning; NOT controlled"
        ),
        "provenance_completeness": assess_provenance(d),
        "feeds_paper_claims": meta["feeds_paper_claims"],
        "analysis": meta["analysis"],
        "publication_status": (
            "retained-correctness-only" if desc == "interop-audit" else "excluded"
        ),
        "publication_reason": (
            "Structural correctness audit, not a timing result; keep."
            if desc == "interop-audit"
            else (
                "Timing capture without full provenance AND contradicted by a "
                "counterpart capture (see analysis). Excluded until reproduced "
                "from a frozen revision under controlled conditions "
                "(STEPS.md items 1,9,15,30)."
            )
        ),
        "raw_file": name,
        "raw_file_sha256": sha256_file(path),
    }
    return dest_dir, manifest


def assess_provenance(d: object) -> str:
    if not isinstance(d, dict):
        return "none"
    prov = d.get("provenance")
    if not isinstance(prov, dict):
        return "none (no provenance block)"
    required = {"git_sha", "jac", "node", "llvm", "cc"}
    have = set(prov.keys())
    missing = sorted(required - have)
    if not missing:
        return "full"
    return f"partial (missing: {', '.join(missing)})"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not SRC.is_dir():
        sys_exit_err(f"source dir not found: {SRC}")
    ARCHIVE.mkdir(parents=True, exist_ok=True)

    moved: list[str] = []
    missing: list[str] = []
    for name in FILES:
        src = SRC / name
        if not src.exists():
            missing.append(name)
            continue
        dest_dir, manifest = manifest_for(name, src)
        plan = f"{name}  ->  {dest_dir.relative_to(REPO)}/  [{manifest['publication_status']}]"
        if args.dry_run:
            print("PLAN ", plan)
            continue
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest_file = dest_dir / name
        if dest_file.exists():
            print("SKIP  (already archived)", plan)
            continue
        shutil.move(str(src), str(dest_file))
        (dest_dir / "MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")
        moved.append(name)
        print("ARCHIVED", plan)

    print(f"\n{len(moved)} quarantined, {len(missing)} not present.")
    if missing:
        print("  missing (already moved?):", ", ".join(missing))
    return 0


def sys_exit_err(msg: str) -> None:
    raise SystemExit("ERROR: " + msg)


if __name__ == "__main__":
    raise SystemExit(main())
