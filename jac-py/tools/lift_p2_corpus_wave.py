#!/usr/bin/env python3
"""Lift a P2 wave corpus with ``jac tool c2jac`` (waves 2+).

Reads ``jac-py/tools/p2_corpus_wave<N>/manifest.json``. Run from repo root:

    .venv/bin/python jac-py/tools/lift_p2_corpus_wave.py --wave 7

Wave 1 has a different corpus layout and keeps its own driver
(``lift_p2_corpus.py``).
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import shutil
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_JAC = _REPO / ".venv" / "bin" / "jac"


def _run(cmd: list[str]) -> None:
    proc = subprocess.run(cmd, cwd=_REPO, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"command failed ({proc.returncode}): {' '.join(cmd)}")


def _corpus_dir(wave: int) -> Path:
    return _HERE / f"p2_corpus_wave{wave}"


def _post_lift_refresh_report(out_dir: Path, report: Path) -> None:
    """Refresh aggregate report after fresh c2jac lift."""
    if str(_HERE) not in sys.path:
        sys.path.insert(0, str(_HERE))
    from t8_driver import refresh_aggregate_report

    if report.is_file():
        refresh_aggregate_report(report)


def _post_lift_wave2_burn_down(out_dir: Path, report: Path) -> None:
    """Wave-2 post-lift burn-down (T8 rule pass + staged pystrnicmp sync).

    ``pystrnicmp`` is staging=lift in ``p2_staged_manifest_wave2.json``, so the
    staged oracle must stay byte-identical to fresh lift output (checked by
    ``tests/test_p2_waves_staged_sync.jac``).

    NOTE: committed wave-2 ``_lifted/{_opcode,_stat}.jac`` are hand-curated
    extracts (see c431159be), not full lifts: fresh c2jac output additionally
    emits C typedef globs and data tables (e.g. _PyOpcode_opcode_metadata)
    that the curated copies intentionally omit. Re-lifting wave 2 therefore
    leaves those two files dirty; only tier-B totals/density are gated on the
    fresh output, never byte-identity.
    """
    if str(_HERE) not in sys.path:
        sys.path.insert(0, str(_HERE))
    from t8_driver import RulePatcher, refresh_aggregate_report, run_loop

    if report.is_file():
        run_loop(
            report,
            RulePatcher(),
            max_iterations=20,
            run_tests=False,
        )
        refresh_aggregate_report(report)

    staged_pystrnicmp = _REPO / "jac-py/Modules/pystrnicmp.jac"
    lifted_pystrnicmp = out_dir / "pystrnicmp.jac"
    if lifted_pystrnicmp.is_file():
        shutil.copy2(lifted_pystrnicmp, staged_pystrnicmp)


_POST_LIFT = {
    2: _post_lift_wave2_burn_down,
}


def lift_wave(wave: int) -> int:
    manifest_path = _corpus_dir(wave) / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    out_dir = (_REPO / manifest["lift_output"]).resolve()
    if not _JAC.is_file():
        print(f"lift_p2_corpus_wave: missing {_JAC}", file=sys.stderr)
        return 1
    out_dir.mkdir(parents=True, exist_ok=True)
    staging = (_corpus_dir(wave) / "_staging").resolve()
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)

    for row in manifest["files"]:
        src = (_REPO / row["source"]).resolve()
        if not src.is_file():
            print(f"lift_p2_corpus_wave: missing source {src}", file=sys.stderr)
            return 1
        stem = row["stem"]
        (staging / f"{stem}.c").write_bytes(src.read_bytes())

    cmd = [
        str(_JAC),
        "tool",
        "c2jac",
        "--project",
        str(staging.relative_to(_REPO)),
        "-o",
        str(out_dir.relative_to(_REPO)),
    ]
    _run(cmd)

    report = out_dir / "project.c2jac.report.json"
    _POST_LIFT.get(wave, _post_lift_refresh_report)(out_dir, report)
    print(f"lifted corpus -> {out_dir.relative_to(_REPO)}")
    print(f"aggregate report -> {report.relative_to(_REPO)}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--wave",
        type=int,
        required=True,
        choices=range(2, 13),
        help="P2 wave number",
    )
    args = parser.parse_args(argv)
    return lift_wave(args.wave)


if __name__ == "__main__":
    raise SystemExit(main())
