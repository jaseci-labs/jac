#!/usr/bin/env python3
"""Copy hand-staged oracle modules into the P2 lifted corpus tree.

Hand-staged modules (see ``p2_staged_manifest*.json``) intentionally diverge from
fresh c2jac lift output. After tier-B burn-down on the staged oracle, copy the
staged file into ``_lifted/p2_corpus_wave*/`` so density metrics and T8 queues
reflect the oracle truth.

Usage:
    python jac-py/tools/sync_staged_to_lifted.py
    python jac-py/tools/sync_staged_to_lifted.py --wave wave2
    python jac-py/tools/sync_staged_to_lifted.py --dry-run
    python jac-py/tools/sync_staged_to_lifted.py --stem getbuildinfo
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_MANIFESTS = {
    "wave1": _HERE / "p2_staged_manifest.json",
    "wave2": _HERE / "p2_staged_manifest_wave2.json",
    "wave3": _HERE / "p2_staged_manifest_wave3.json",
    "wave4": _HERE / "p2_staged_manifest_wave4.json",
    "wave5": _HERE / "p2_staged_manifest_wave5.json",
    "wave6": _HERE / "p2_staged_manifest_wave6.json",
    "wave7": _HERE / "p2_staged_manifest_wave7.json",
    "wave8": _HERE / "p2_staged_manifest_wave8.json",
    "wave9": _HERE / "p2_staged_manifest_wave9.json",
    "wave10": _HERE / "p2_staged_manifest_wave10.json",
    "wave11": _HERE / "p2_staged_manifest_wave11.json",
}


def _load_manifest(wave: str) -> dict:
    path = _MANIFESTS.get(wave)
    if path is None or not path.is_file():
        raise ValueError(f"unknown or missing wave manifest: {wave!r}")
    return json.loads(path.read_text(encoding="utf-8"))


def _hand_modules(manifest: dict, stem_filter: str | None) -> list[dict]:
    rows = [m for m in manifest["modules"] if m.get("staging") == "hand"]
    if stem_filter:
        rows = [m for m in rows if m["stem"] == stem_filter]
    return rows


def _sidecar_for_output(output: Path) -> Path:
    stem = output.with_suffix("")
    return stem.parent / f"{stem.name}.c2jac.report.json"


def _mark_sidecar_clean(sidecar: Path) -> None:
    if not sidecar.is_file():
        return
    data = json.loads(sidecar.read_text(encoding="utf-8"))
    data["sites"] = []
    data["tier_b_count"] = 0
    data["quarantined_functions"] = []
    sidecar.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def refresh_wave_aggregate(manifest: dict) -> None:
    from t8_driver import refresh_aggregate_report

    lifted_dir = _REPO / manifest["lifted_dir"]
    aggregate = lifted_dir / "project.c2jac.report.json"
    if aggregate.is_file():
        refresh_aggregate_report(aggregate)


def sync_hand_staged(
    *,
    dry_run: bool = False,
    stem: str | None = None,
    wave: str = "wave1",
    refresh_reports: bool = True,
) -> int:
    manifest = _load_manifest(wave)
    staged_dir = _REPO / manifest["staged_dir"]
    lifted_dir = _REPO / manifest["lifted_dir"]
    rows = _hand_modules(manifest, stem)
    if stem and not rows:
        print(f"error: {stem!r} is not a hand-staged module in {wave}", file=sys.stderr)
        return 1

    copied = 0
    for row in rows:
        name = row["stem"]
        src = staged_dir / f"{name}.jac"
        dst = lifted_dir / f"{name}.jac"
        if not src.is_file():
            print(f"error: missing staged oracle {src}", file=sys.stderr)
            return 1
        if dry_run:
            print(f"would copy {src.relative_to(_REPO)} -> {dst.relative_to(_REPO)}")
            print(f"would clear sidecar {_sidecar_for_output(dst).relative_to(_REPO)}")
        else:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            _mark_sidecar_clean(_sidecar_for_output(dst))
            print(f"copied {src.relative_to(_REPO)} -> {dst.relative_to(_REPO)}")
        copied += 1

    if copied == 0:
        print("no hand-staged modules to sync", file=sys.stderr)
        return 1

    if refresh_reports and not dry_run:
        refresh_wave_aggregate(manifest)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print planned copies without writing",
    )
    parser.add_argument(
        "--stem",
        metavar="NAME",
        help="sync one hand-staged module only",
    )
    parser.add_argument(
        "--wave",
        choices=tuple(_MANIFESTS),
        default="wave1",
        help="P2 wave manifest (default: wave1)",
    )
    parser.add_argument(
        "--no-refresh-reports",
        action="store_true",
        help="skip aggregate project.c2jac.report.json reconcile",
    )
    args = parser.parse_args()
    return sync_hand_staged(
        dry_run=args.dry_run,
        stem=args.stem,
        wave=args.wave,
        refresh_reports=not args.no_refresh_reports,
    )


if __name__ == "__main__":
    raise SystemExit(main())
