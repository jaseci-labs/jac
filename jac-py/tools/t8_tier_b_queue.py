#!/usr/bin/env python3
"""T8 MVP: queue Tier-B sites from c2jac sidecars for the AI cleanup loop.

Reads per-file ``*.c2jac.report.json`` sidecars (or a project aggregate), emits a
JSON queue of sites with source context for LLM prompts. Acceptance criteria for
automated patches (jac-py/PLAN.md §6.8):

  - module differential / conformance tests pass
  - ``tier_b_total`` decreases

This driver does not call an LLM; it prepares the work queue and can validate
ratchets after manual or scripted edits.

Usage:
    .venv/bin/python jac-py/tools/t8_tier_b_queue.py \\
        jac-py/Modules/_lifted/p2_corpus_wave1/project.c2jac.report.json
    .venv/bin/python jac-py/tools/t8_tier_b_queue.py --emit-queue /tmp/t8.json \\
        jac-py/Modules/_lifted/p2_corpus_wave1/project.c2jac.report.json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_CONTEXT_LINES = 3


def _sidecar_for_output(output: str) -> Path:
    p = Path(output)
    if not p.is_absolute():
        p = _REPO / p
    stem = p.with_suffix("")
    return stem.parent / f"{stem.name}.c2jac.report.json"


def _read_context(source: Path, line: int) -> list[str]:
    if not source.is_file():
        return []
    lines = source.read_text(encoding="utf-8").splitlines()
    if not lines:
        return []
    idx = max(0, line - 1)
    start = max(0, idx - _CONTEXT_LINES)
    end = min(len(lines), idx + _CONTEXT_LINES)
    return lines[start:end]


def _queue_from_sidecar(sidecar: Path, source_hint: Path | None) -> list[dict]:
    data = json.loads(sidecar.read_text(encoding="utf-8"))
    source = source_hint or Path(data.get("source", ""))
    if not source.is_absolute():
        source = _REPO / source
    queue: list[dict] = []
    for site in data.get("sites", []):
        line = int(site.get("line", 0) or 0)
        queue.append(
            {
                "sidecar": str(sidecar.relative_to(_REPO)),
                "source": str(source.relative_to(_REPO)) if source.is_file() else data.get("source"),
                "output": data.get("output"),
                "code": site.get("code"),
                "band": site.get("band"),
                "line": line,
                "msg": site.get("msg"),
                "function": site.get("function"),
                "context": _read_context(source, line),
            }
        )
    return queue


def _expand_aggregate(aggregate: Path) -> list[dict]:
    data = json.loads(aggregate.read_text(encoding="utf-8"))
    queue: list[dict] = []
    for row in data.get("files", []):
        output = row.get("output", "")
        sidecar = _sidecar_for_output(output)
        if not sidecar.is_file():
            continue
        source_hint = Path(row.get("source", ""))
        if not source_hint.is_absolute():
            source_hint = _REPO / source_hint
        queue.extend(_queue_from_sidecar(sidecar, source_hint))
    return queue


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "report",
        type=Path,
        help="project.c2jac.report.json or a single-file sidecar",
    )
    parser.add_argument(
        "--emit-queue",
        type=Path,
        help="write queue JSON to this path (default: print summary only)",
    )
    parser.add_argument(
        "--metrics",
        action="store_true",
        help=(
            "after queue generation, run t8_accept dry-run: compare current report "
            "to baseline tier_b_total and run oracle+libtest+conformance tests"
        ),
    )
    parser.add_argument(
        "--report-before",
        type=Path,
        default=_HERE / "p2_corpus" / "baseline" / "project.c2jac.report.json",
        help="baseline report for --metrics sites_before (default: p2_corpus baseline)",
    )
    parser.add_argument(
        "--metrics-out",
        type=Path,
        help="with --metrics, write acceptance metrics JSON here",
    )
    args = parser.parse_args(argv)
    report = args.report if args.report.is_absolute() else _REPO / args.report
    if not report.is_file():
        print(f"t8_tier_b_queue: missing {report}", file=sys.stderr)
        return 1

    if report.name == "project.c2jac.report.json":
        queue = _expand_aggregate(report)
    else:
        queue = _queue_from_sidecar(report, None)

    summary = {
        "report": str(report.relative_to(_REPO)),
        "site_count": len(queue),
        "sites": queue,
    }
    if args.emit_queue:
        out = args.emit_queue if args.emit_queue.is_absolute() else _REPO / args.emit_queue
        out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"queued {len(queue)} Tier-B site(s) -> {out.relative_to(_REPO)}")
    else:
        print(f"report: {summary['report']}")
        print(f"site_count: {summary['site_count']}")
        for row in queue:
            fn = row.get("function") or "<module>"
            print(f"  {row['code']} @ {row['source']}:{row['line']} in {fn}")

    if args.metrics:
        from t8_accept import emit_metrics, validate

        report_before = (
            args.report_before
            if args.report_before.is_absolute()
            else _REPO / args.report_before
        )
        metrics, errors = validate(report_before, report, run_tests=True)
        emit_metrics(metrics, args.metrics_out)
        if errors:
            for msg in errors:
                print(f"t8_tier_b_queue: {msg}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
