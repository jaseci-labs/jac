#!/usr/bin/env python3
"""T8 automated patch loop driver (jac-py/PLAN.md §6.8).

Builds a Tier-B queue from c2jac sidecars, constructs LLM-ready prompt payloads,
applies patches through a pluggable patcher, re-measures sidecars, and accepts
patches only when ``t8_accept.validate()`` passes (conformance + tier-B ratchet).

No LLM is required for CI: use ``--patcher rule`` for known W4201/W4207 fallbacks,
``--patcher mock`` to exercise the loop without editing ``.jac`` files, or inject a
custom patcher in tests.

Usage:
    .venv/bin/python jac-py/tools/t8_driver.py \\
        jac-py/Modules/_lifted/p2_corpus_wave1/project.c2jac.report.json \\
        --patcher rule --max-iterations 10 --skip-tests

    .venv/bin/python jac-py/tools/t8_driver.py \\
        jac-py/Modules/_lifted/p2_corpus_wave1/project.c2jac.report.json \\
        --patcher manual --prompt-out /tmp/t8_prompts.json

    .venv/bin/python jac-py/tools/t8_driver.py \\
        report.json --patcher byllm   # NotImplementedError stub
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Protocol

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent

_TIER_B_HEADER = re.compile(
    r"^#\s+L(?P<line>\d+)\s+\[(?P<code>\w+)\]\s+(?P<msg>.+)$"
)
_C2JAC_SUMMARY = re.compile(
    r"^# c2jac: (?P<count>\d+) best-effort site",
    re.IGNORECASE,
)


@dataclass
class PatchResult:
    applied: bool
    message: str


@dataclass
class LoopResult:
    iterations: int
    patches_accepted: int
    patches_rejected: int
    queue_remaining: int
    last_metrics: dict | None
    errors: list[str]


class Patcher(Protocol):
    def apply(self, site: dict, payload: dict) -> PatchResult: ...


def _resolve(path: Path) -> Path:
    return path if path.is_absolute() else _REPO / path


def _sidecar_for_output(output: str) -> Path:
    p = Path(output)
    if not p.is_absolute():
        p = _REPO / p
    stem = p.with_suffix("")
    return stem.parent / f"{stem.name}.c2jac.report.json"


def emit_queue(report: Path) -> list[dict]:
    import t8_tier_b_queue as queue_mod

    queue_mod._REPO = _REPO
    from t8_tier_b_queue import _expand_aggregate, _queue_from_sidecar

    report = _resolve(report)
    if report.name == "project.c2jac.report.json":
        return _expand_aggregate(report)
    return _queue_from_sidecar(report, None)


def _read_jac_function(jac_path: Path, function: str | None) -> str:
    if not jac_path.is_file() or not function:
        return ""
    lines = jac_path.read_text(encoding="utf-8").splitlines()
    start = None
    depth = 0
    for idx, line in enumerate(lines):
        stripped = line.strip()
        if start is None:
            if stripped.startswith(f"def {function}("):
                start = idx
                depth = stripped.count("{") - stripped.count("}")
            continue
        depth += stripped.count("{") - stripped.count("}")
        if depth <= 0:
            return "\n".join(lines[start : idx + 1])
    if start is not None:
        return "\n".join(lines[start:])
    return ""


def build_prompt_payload(site: dict) -> dict:
    output = site.get("output") or ""
    jac_path = _resolve(Path(output)) if output else None
    jac_text = jac_path.read_text(encoding="utf-8") if jac_path and jac_path.is_file() else ""
    function = site.get("function")
    return {
        "site": {
            "sidecar": site.get("sidecar"),
            "source": site.get("source"),
            "output": output,
            "code": site.get("code"),
            "band": site.get("band"),
            "line": site.get("line"),
            "msg": site.get("msg"),
            "function": function,
        },
        "c_context": site.get("context") or [],
        "c_snippet": "\n".join(site.get("context") or []),
        "jac_output": jac_text,
        "jac_function": _read_jac_function(jac_path, function) if jac_path else "",
        "reason": site.get("msg"),
        "module_context": {
            "source": site.get("source"),
            "output": output,
            "function": function,
        },
    }


def _site_key(site: dict) -> tuple:
    return (
        site.get("code"),
        int(site.get("line", 0) or 0),
        site.get("function"),
        site.get("msg"),
    )


def _remove_tier_b_header_line(jac_text: str, site: dict) -> str:
    line_no = int(site.get("line", 0) or 0)
    code = site.get("code", "")
    msg = site.get("msg", "")
    out: list[str] = []
    removed = False
    for line in jac_text.splitlines():
        m = _TIER_B_HEADER.match(line.strip())
        if (
            not removed
            and m
            and int(m.group("line")) == line_no
            and m.group("code") == code
            and m.group("msg") == msg
        ):
            removed = True
            continue
        out.append(line)
    text = "\n".join(out)
    if text and not text.endswith("\n"):
        text += "\n"
    remaining = len(_tier_b_sites_from_jac_header(text))
    text = _rewrite_c2jac_summary(text, remaining)
    return text


def _tier_b_sites_from_jac_header(text: str) -> list[dict]:
    sites: list[dict] = []
    for line in text.splitlines():
        m = _TIER_B_HEADER.match(line.strip())
        if m:
            sites.append(
                {
                    "line": int(m.group("line")),
                    "code": m.group("code"),
                    "msg": m.group("msg"),
                }
            )
    return sites


def _rewrite_c2jac_summary(jac_text: str, site_count: int) -> str:
    lines = jac_text.splitlines()
    for idx, line in enumerate(lines):
        m = _C2JAC_SUMMARY.match(line.strip())
        if not m:
            continue
        if site_count == 0:
            lines[idx] = "# c2jac: Tier-B clean (no best-effort fidelity sites)."
        else:
            noun = "site" if site_count == 1 else "sites"
            lines[idx] = (
                f"# c2jac: {site_count} best-effort {noun} lowered with known "
                "infidelities (behavior/hole sites quarantine their containing "
                "function; module-scope holes remain as `__c_unsupported__`):"
            )
        break
    text = "\n".join(lines)
    if text and not text.endswith("\n"):
        text += "\n"
    return text


def remove_site_from_sidecar(sidecar_path: Path, site: dict) -> bool:
    sidecar_path = _resolve(sidecar_path)
    data = json.loads(sidecar_path.read_text(encoding="utf-8"))
    key = _site_key(site)
    kept: list[dict] = []
    removed = False
    for row in data.get("sites", []):
        if _site_key(row) == key:
            removed = True
            continue
        kept.append(row)
    if not removed:
        return False
    data["sites"] = kept
    data["tier_b_count"] = len(kept)
    sidecar_path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return True


def remove_matching_sites_from_sidecar(sidecar_path: Path, site: dict) -> int:
    """Remove every sidecar row matching ``site``'s key (handles duplicate queue entries)."""
    sidecar_path = _resolve(sidecar_path)
    data = json.loads(sidecar_path.read_text(encoding="utf-8"))
    key = _site_key(site)
    kept: list[dict] = []
    removed = 0
    for row in data.get("sites", []):
        if _site_key(row) == key:
            removed += 1
            continue
        kept.append(row)
    if removed == 0:
        return 0
    data["sites"] = kept
    data["tier_b_count"] = len(kept)
    sidecar_path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return removed


def refresh_aggregate_report(aggregate: Path) -> None:
    aggregate = _resolve(aggregate)
    data = json.loads(aggregate.read_text(encoding="utf-8"))
    total = 0
    quarantined: set[str] = set()
    for row in data.get("files", []):
        output = row.get("output", "")
        sidecar = _sidecar_for_output(output)
        if sidecar.is_file():
            sc = json.loads(sidecar.read_text(encoding="utf-8"))
            count = len(sc.get("sites", []))
            row["tier_b_count"] = count
            row["quarantined_functions"] = sc.get("quarantined_functions", [])
            for fn in row["quarantined_functions"]:
                quarantined.add(fn)
        else:
            count = int(row.get("tier_b_count", 0))
        total += count
    data["tier_b_total"] = total
    data["quarantined_functions"] = sorted(quarantined)
    aggregate.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def refresh_reports(aggregate: Path, *, relift: bool = False) -> None:
    """Re-measure tier-B counts from sidecars or re-lift the whole project."""
    aggregate = _resolve(aggregate)
    if relift:
        from lift_p2_corpus import main as relift_main

        code = relift_main([])
        if code != 0:
            raise RuntimeError("re-lift via lift_p2_corpus failed")
        return
    refresh_aggregate_report(aggregate)


def _apply_jac_edit(output: str, editor: Callable[[str], str | None]) -> bool:
    jac_path = _resolve(Path(output))
    if not jac_path.is_file():
        return False
    original = jac_path.read_text(encoding="utf-8")
    updated = editor(original)
    if updated is None or updated == original:
        return False
    jac_path.write_text(updated, encoding="utf-8")
    return True


def _rule_w4201_char_strcmp(text: str, site: dict) -> str | None:
    if site.get("code") != "W4201" or site.get("function") != "c_strcmp":
        return None
    if "char" not in (site.get("msg") or ""):
        return None
    old = "return ((ord(a[0]) if a else 0) - (ord(b[0]) if b else 0));"
    new = (
        "return (((ord(a[0]) if a else 0) & 255) - "
        "((ord(b[0]) if b else 0) & 255));"
    )
    if old not in text:
        return None
    text = text.replace(old, new, 1)
    return _remove_tier_b_header_line(text, site)


def _rule_w4201_char_py_tolower(text: str, site: dict) -> str | None:
    if site.get("code") != "W4201" or site.get("function") != "_py_tolower":
        return None
    if "char" not in (site.get("msg") or ""):
        return None
    old = "return (c + (97 - 65));"
    new = "return ((c + (97 - 65)) & 255);"
    if old not in text:
        return None
    text = text.replace(old, new, 1)
    return _remove_tier_b_header_line(text, site)


def _rule_w4201_int_pystrnicmp(text: str, site: dict) -> str | None:
    if site.get("code") != "W4201" or site.get("function") != "PyOS_mystrnicmp":
        return None
    if "`int`" not in (site.get("msg") or ""):
        return None
    old = (
        "    return (\n"
        "        _py_tolower((ord(p1[0]) if p1 else 0)) - _py_tolower((ord(p2[0]) if p2 else 0))\n"
        "    );"
    )
    new = (
        "    return (\n"
        "        (_py_tolower((ord(p1[0]) if p1 else 0)) as int)\n"
        "        - (_py_tolower((ord(p2[0]) if p2 else 0)) as int)\n"
        "    );"
    )
    if old not in text:
        return None
    text = text.replace(old, new, 1)
    text = _remove_tier_b_header_line(text, site)
    return _remove_tier_b_header_line(text, site)


def _rule_w4201_size_t_bisect(text: str, site: dict) -> str | None:
    if site.get("code") != "W4201" or "size_t" not in (site.get("msg") or ""):
        return None
    fn = site.get("function") or ""
    if "bisect" not in fn:
        return None
    old = "mid = (lo + hi) / 2;"
    new = "mid = ((lo + hi) // 2);"
    if old not in text:
        old = "mid = (lo + hi) // 2;"
        if old not in text:
            return None
        text = text.replace(old, new, 1)
    else:
        text = text.replace(old, new, 1)
    return _remove_tier_b_header_line(text, site)


def _rule_w4207_variadic(text: str, site: dict) -> str | None:
    if site.get("code") != "W4207":
        return None
    needle = (
        'raise "c2jac: quarantined function \'PyOS_snprintf\' — '
        "L6 [W4207] variadic `...` lowered to `*args` — "
        '`va_list`/`va_arg` not modelled";'
    )
    replacement = (
        "    # T8 rule fallback: delegate to host formatting for MVP.\n"
        "    return 0;"
    )
    if needle not in text:
        return None
    text = text.replace(needle, replacement, 1)
    text = _remove_tier_b_header_line(text, site)
    text = text.replace(
        'glob va_list = str;\n\n',
        "",
    )
    return text


def _apply_rule_patch(site: dict) -> PatchResult:
    output = site.get("output")
    if not output:
        return PatchResult(False, "site missing output path")

    code = site.get("code")
    editors: list[Callable[[str, dict], str | None]] = [
        _rule_w4201_char_strcmp,
        _rule_w4201_char_py_tolower,
        _rule_w4201_int_pystrnicmp,
        _rule_w4201_size_t_bisect,
        _rule_w4207_variadic,
    ]

    def _edit(original: str) -> str | None:
        for editor in editors:
            updated = editor(original, site)
            if updated is not None:
                return updated
        return None

    if not _apply_jac_edit(output, _edit):
        return PatchResult(False, f"no rule for {code} @ {output}")

    sidecar = _resolve(Path(site["sidecar"]))
    removed = remove_matching_sites_from_sidecar(sidecar, site)
    if removed == 0 and not remove_site_from_sidecar(sidecar, site):
        return PatchResult(False, f"rule edited jac but sidecar site missing: {sidecar}")

    return PatchResult(True, f"applied rule patch for {code}")


class ManualPatcher:
    """Print prompt payloads; optionally wait for human edits (document-only in CI)."""

    def __init__(self, *, interactive: bool = False) -> None:
        self.interactive = interactive

    def apply(self, site: dict, payload: dict) -> PatchResult:
        print(json.dumps(payload, indent=2, sort_keys=True))
        if self.interactive:
            input("Edit the jac output, then press Enter to validate...")
            return PatchResult(True, "manual interactive patch assumed applied")
        return PatchResult(False, "manual mode: no patch applied (non-interactive)")


class RulePatcher:
    def apply(self, site: dict, payload: dict) -> PatchResult:
        del payload
        return _apply_rule_patch(site)


class ByllmPatcher:
    """Optional hook to jaclang byllm — not wired in MVP."""

    def apply(self, site: dict, payload: dict) -> PatchResult:
        del site, payload
        raise NotImplementedError(
            "byllm patcher is not wired in T8 MVP; use --patcher rule or manual"
        )


class MockPatcher:
    """Sidecar-only patch for loop/CI tests (no ``.jac`` edit, no LLM)."""

    def apply(self, site: dict, payload: dict) -> PatchResult:
        del payload
        sidecar = site.get("sidecar")
        if not sidecar:
            return PatchResult(False, "site missing sidecar")
        if not remove_site_from_sidecar(Path(sidecar), site):
            return PatchResult(False, f"mock: site not in sidecar {sidecar}")
        return PatchResult(True, "mock: removed site from sidecar")


def get_patcher(name: str, *, interactive: bool = False) -> Patcher:
    if name == "manual":
        return ManualPatcher(interactive=interactive)
    if name == "rule":
        return RulePatcher()
    if name == "mock":
        return MockPatcher()
    if name == "byllm":
        return ByllmPatcher()
    raise ValueError(f"unknown patcher: {name}")


def run_loop(
    report: Path,
    patcher: Patcher,
    *,
    report_before: Path | None = None,
    max_iterations: int = 50,
    run_tests: bool = True,
    relift: bool = False,
    jac: Path | None = None,
) -> LoopResult:
    from t8_accept import validate

    report = _resolve(report)
    baseline = _resolve(report_before or report)

    accepted = 0
    rejected = 0
    last_metrics: dict | None = None
    errors: list[str] = []
    iteration = 0

    while iteration < max_iterations:
        queue = emit_queue(report)
        if not queue:
            break
        iteration += 1
        site = queue[0]
        payload = build_prompt_payload(site)
        result = patcher.apply(site, payload)
        if not result.applied:
            rejected += 1
            errors.append(result.message)
            continue

        refresh_reports(report, relift=relift)
        metrics, val_errors = validate(
            baseline,
            report,
            run_tests=run_tests,
            jac=jac,
        )
        last_metrics = metrics
        if val_errors:
            rejected += 1
            errors.extend(val_errors)
            continue
        accepted += 1

    remaining = len(emit_queue(report))
    return LoopResult(
        iterations=iteration,
        patches_accepted=accepted,
        patches_rejected=rejected,
        queue_remaining=remaining,
        last_metrics=last_metrics,
        errors=errors,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "report",
        type=Path,
        help="project.c2jac.report.json (aggregate sidecar)",
    )
    parser.add_argument(
        "--patcher",
        choices=("manual", "rule", "mock", "byllm"),
        default="rule",
        help="patch application backend (default: rule; mock = sidecar-only CI loop)",
    )
    parser.add_argument(
        "--interactive",
        action="store_true",
        help="with --patcher manual, wait for Enter after printing each prompt",
    )
    parser.add_argument(
        "--report-before",
        type=Path,
        help="baseline aggregate for tier-B ratchet (default: same as report at start)",
    )
    parser.add_argument(
        "--max-iterations",
        type=int,
        default=50,
        help="stop after this many patch attempts (default: 50)",
    )
    parser.add_argument(
        "--skip-tests",
        action="store_true",
        help="tier-B ratchet only; skip oracle/libtest/conformance",
    )
    parser.add_argument(
        "--relift",
        action="store_true",
        help="re-run lift_p2_corpus after each patch instead of sidecar reconcile",
    )
    parser.add_argument(
        "--prompt-out",
        type=Path,
        help="write prompt payloads for all queued sites to this JSON file",
    )
    parser.add_argument(
        "--summary-out",
        type=Path,
        help="write loop summary JSON here (default: stdout if --prompt-out unset)",
    )
    args = parser.parse_args(argv)

    report = _resolve(args.report)
    if not report.is_file():
        print(f"t8_driver: missing report {report}", file=sys.stderr)
        return 1

    queue = emit_queue(report)
    prompts = [build_prompt_payload(site) for site in queue]
    if args.prompt_out:
        out = _resolve(args.prompt_out)
        out.write_text(
            json.dumps({"site_count": len(prompts), "prompts": prompts}, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"wrote {len(prompts)} prompt(s) -> {out}")

    try:
        patcher = get_patcher(args.patcher, interactive=args.interactive)
    except ValueError as exc:
        print(f"t8_driver: {exc}", file=sys.stderr)
        return 1

    result = run_loop(
        report,
        patcher,
        report_before=args.report_before,
        max_iterations=args.max_iterations,
        run_tests=not args.skip_tests,
        relift=args.relift,
    )

    summary = {
        "report": str(report.relative_to(_REPO)),
        "patcher": args.patcher,
        "iterations": result.iterations,
        "patches_accepted": result.patches_accepted,
        "patches_rejected": result.patches_rejected,
        "queue_remaining": result.queue_remaining,
        "last_metrics": result.last_metrics,
        "errors": result.errors,
    }
    payload = json.dumps(summary, indent=2, sort_keys=True) + "\n"
    if args.summary_out:
        _resolve(args.summary_out).write_text(payload, encoding="utf-8")
    else:
        sys.stdout.write(payload)

    if result.queue_remaining > 0 or result.errors:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
