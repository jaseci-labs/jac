#!/usr/bin/env python3
"""D2 conformance dashboard + grow-only ratchet (PLAN.md §2, §9 M2/M3).

Reads the per-wave conformance manifests under ``jac-py/tests/``
(``conformance_manifest*.json``, produced by the P2/P3 gate pipeline) and
provides three modes over the same data the gates consume:

* ``report`` (default)  render a per-module pass table as markdown;
* ``check``             ratchet: exit non-zero if any entry recorded in the
                        baseline regresses (missing, un-gated, or fewer
                        passing jacpython cases than before); passing when
                        the pass-set only grows;
* ``update-baseline``   rewrite the pinned baseline from current manifests.

Stdlib-only, no suite execution — this tool never runs ``jac test``; it
consumes the manifests the gates already wrote.

Usage::

    python3 tools/conformance_dashboard.py                    # table
    python3 tools/conformance_dashboard.py --out dash.md      # table to file
    python3 tools/conformance_dashboard.py --check            # ratchet (CI)
    python3 tools/conformance_dashboard.py --update-baseline  # re-pin
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import sys
from pathlib import Path
from typing import Any

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_DEFAULT_TESTS_DIR = _REPO / "jac-py" / "tests"
_DEFAULT_BASELINE = _HERE / "conformance_baseline.json"
_MANIFEST_GLOB = "conformance_manifest*.json"

_SCHEMA_VERSION = 1


# --------------------------------------------------------------------------
# Manifest ingestion


def _load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def discover_manifests(tests_dir: Path) -> list[Path]:
    """All conformance manifests, ordered by wave number then name."""
    paths = sorted(tests_dir.glob(_MANIFEST_GLOB))
    def sort_key(path: Path) -> tuple[int, str]:
        name = path.stem.removeprefix("conformance_manifest")
        digits = "".join(ch for ch in name if ch.isdigit())
        return (int(digits) if digits else 0, path.name)
    return sorted(paths, key=sort_key)


def _case_summary(row: dict, doc: dict) -> tuple[int | None, int | None]:
    """(passed, total) jacpython case counts for one module row, if any."""
    summary = doc.get("jacpython_results", {}).get(row["stem"])
    if summary is None:
        return None, None
    return int(summary.get("passed", 0)), int(summary.get("total", 0))


def entries_from_doc(doc: dict) -> dict[str, dict]:
    """Extract ratchet entries keyed by module stem from one manifest.

    An entry is *passing* iff the gate pipeline marked it ``gated`` — the
    same condition the existing gates assert. Case counters ride along so
    the ratchet can catch silent coverage shrinkage inside a still-gated
    module.
    """
    wave = str(doc.get("wave", "unknown"))
    entries: dict[str, dict] = {}
    for row in doc.get("modules", []):
        stem = str(row["stem"])
        passed, total = _case_summary(row, doc)
        entries[stem] = {
            "wave": wave,
            "gate_type": row.get("gate_type"),
            "status": row.get("status"),
            "cases_passed": passed,
            "cases_total": total,
        }
    return entries


def collect_state(tests_dir: Path) -> tuple[dict[str, dict], list[str]]:
    """Current state across every manifest; returns (entries, warnings)."""
    warnings: list[str] = []
    state: dict[str, dict] = {}
    for path in discover_manifests(tests_dir):
        try:
            doc = _load_json(path)
        except (OSError, json.JSONDecodeError) as exc:
            warnings.append(f"{path.name}: unreadable ({exc})")
            continue
        state.update(entries_from_doc(doc))
    return state, warnings


# --------------------------------------------------------------------------
# Ratchet


def ratchet_regressions(
    baseline: dict[str, dict], current: dict[str, dict]
) -> list[str]:
    """Ways the current state violates the grow-only ratchet.

    A baseline entry regresses when it disappears, loses its ``gated``
    status, or drops below its previously-passing jacpython case count.
    New entries and higher counts are always allowed.
    """
    problems: list[str] = []
    for stem in sorted(baseline):
        want = baseline[stem]
        got = current.get(stem)
        if got is None:
            problems.append(f"{stem}: present in baseline, missing from manifests")
            continue
        if want.get("status") == "gated" and got.get("status") != "gated":
            problems.append(
                f"{stem}: status regressed {want['status']!r} -> {got.get('status')!r}"
            )
        b_passed = want.get("cases_passed")
        c_passed = got.get("cases_passed")
        if isinstance(b_passed, int) and isinstance(c_passed, int) and c_passed < b_passed:
            problems.append(f"{stem}: jacpython cases passed {b_passed} -> {c_passed}")
    return problems


def ratchet_new_entries(
    baseline: dict[str, dict], current: dict[str, dict]
) -> list[str]:
    """Passing entries not yet pinned in the baseline (ratchet can grow)."""
    known = set(baseline)
    return sorted(stem for stem in current if stem not in known)


def make_baseline_doc(state: dict[str, dict]) -> dict:
    entries = {
        stem: {
            "wave": e["wave"],
            "gate_type": e.get("gate_type"),
            "status": e.get("status"),
            "cases_passed": e.get("cases_passed"),
            "cases_total": e.get("cases_total"),
        }
        for stem, e in sorted(state.items())
    }
    return {
        "schema": _SCHEMA_VERSION,
        "updated": _dt.date.today().isoformat(),
        "description": (
            "Pinned D2 conformance pass-set (grow-only ratchet). Regenerate "
            "with: python3 tools/conformance_dashboard.py --update-baseline"
        ),
        "entry_count": len(entries),
        "entries": entries,
    }


# --------------------------------------------------------------------------
# Markdown rendering


def render_markdown(state: dict[str, dict], warnings: list[str]) -> str:
    total = len(state)
    gated = sum(1 for e in state.values() if e.get("status") == "gated")
    case_rows = [(e.get("cases_passed"), e.get("cases_total")) for e in state.values()]
    cases_passed = sum(p for p, _ in case_rows if p is not None)
    cases_total = sum(t for _, t in case_rows if t is not None)

    lines = [
        "# D2 Conformance Dashboard",
        "",
        f"Gated modules: **{gated}/{total}**",
        f" · JacPython libtest cases passed: **{cases_passed}/{cases_total}**",
        f" · Ratchet baseline: `{_DEFAULT_BASELINE.relative_to(_REPO)}`",
        "",
        "Generated by `tools/conformance_dashboard.py`; pass-set is grow-only.",
        "",
    ]
    if warnings:
        lines += ["## Warnings", ""]
        lines += [f"- {w}" for w in warnings]
        lines.append("")

    waves: dict[str, list[tuple[str, dict]]] = {}
    for stem, entry in sorted(state.items()):
        waves.setdefault(entry["wave"], []).append((stem, entry))

    lines.append("| Wave | Modules gated | JacPython cases |")
    lines.append("|---|---|---|")
    for wave in sorted(waves):
        rows = waves[wave]
        g = sum(1 for _, e in rows if e.get("status") == "gated")
        p = sum(e["cases_passed"] for _, e in rows if e["cases_passed"] is not None)
        t = sum(e["cases_total"] for _, e in rows if e["cases_total"] is not None)
        cases = f"{p}/{t}" if t else "—"
        lines.append(f"| {wave} | {g}/{len(rows)} | {cases} |")

    lines += ["", "## Per-module detail", ""]
    lines.append("| Module | Wave | Gate type | Status | JacPython cases |")
    lines.append("|---|---|---|---|---|")
    for wave in sorted(waves):
        for stem, entry in waves[wave]:
            p, t = entry["cases_passed"], entry["cases_total"]
            cases = f"{p}/{t}" if t is not None else "—"
            lines.append(
                f"| `{stem}` | {entry['wave']} | {entry.get('gate_type', '—')} "
                f"| {entry.get('status', '—')} | {cases} |"
            )
    lines.append("")
    return "\n".join(lines)


# --------------------------------------------------------------------------
# CLI


def _load_baseline(path: Path) -> dict[str, dict]:
    if not path.is_file():
        raise SystemExit(f"error: baseline missing at {path}; create one with --update-baseline")
    doc = _load_json(path)
    if doc.get("schema") != _SCHEMA_VERSION:
        raise SystemExit(
            f"error: unsupported baseline schema {doc.get('schema')!r} "
            f"(expected {_SCHEMA_VERSION}); regenerate with --update-baseline"
        )
    return doc.get("entries", {})


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--tests-dir", type=Path, default=_DEFAULT_TESTS_DIR,
                        help="directory holding conformance_manifest*.json")
    parser.add_argument("--baseline", type=Path, default=_DEFAULT_BASELINE,
                        help="pinned ratchet baseline JSON")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true",
                      help="ratchet mode: fail on any regression")
    mode.add_argument("--update-baseline", action="store_true",
                      help="re-pin baseline from current manifests")
    parser.add_argument("--out", type=Path,
                        help="write markdown report to this file instead of stdout")
    args = parser.parse_args(argv)

    state, warnings = collect_state(args.tests_dir)
    if not state:
        print(f"error: no modules found under {args.tests_dir}", file=sys.stderr)
        return 2

    if args.update_baseline:
        doc = make_baseline_doc(state)
        args.baseline.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
        print(f"baseline updated: {args.baseline} ({len(state)} entries)")
        return 0

    if args.check:
        baseline = _load_baseline(args.baseline)
        regressions = ratchet_regressions(baseline, state)
        new_entries = ratchet_new_entries(baseline, state)
        for problem in regressions:
            print(f"REGRESSION: {problem}", file=sys.stderr)
        if regressions:
            print(
                f"ratchet FAILED: {len(regressions)} regression(s) out of "
                f"{len(baseline)} pinned entries",
                file=sys.stderr,
            )
            return 1
        print(
            f"ratchet OK: {len(baseline)} pinned entries intact, "
            f"{len(state)} currently gated"
        )
        if new_entries:
            print(
                "note: unpinned passing entries — grow the baseline with "
                "--update-baseline: " + ", ".join(new_entries),
                file=sys.stderr,
            )
        return 0

    report = render_markdown(state, warnings)
    if args.out:
        args.out.write_text(report, encoding="utf-8")
        print(f"dashboard written: {args.out}")
    else:
        sys.stdout.write(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
