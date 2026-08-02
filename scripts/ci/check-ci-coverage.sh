#!/usr/bin/env bash
# Verify ci-coverage.yml stays synchronized with .github/workflows/ci.yml.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Optional overrides let router-tests feed in a mutated manifest for the
# fail-closed negative case on event_excluded_jobs.
MANIFEST="${1:-${ROOT}/scripts/ci/ci-coverage.yml}"
WORKFLOW="${2:-${ROOT}/.github/workflows/ci.yml}"

python3 - "$MANIFEST" "$WORKFLOW" <<'PY'
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML required")

manifest_path = Path(sys.argv[1])
workflow_path = Path(sys.argv[2])
manifest = yaml.safe_load(manifest_path.read_text())
workflow_data = yaml.safe_load(workflow_path.read_text())
workflow_jobs = set(workflow_data.get("jobs", {}).keys())

metadata = set(manifest.get("metadata_jobs", []))
manifest_jobs = set(manifest.get("jobs", []))
expected = manifest_jobs | metadata | set(manifest.get("always_run_jobs", []))
missing_in_manifest = sorted(workflow_jobs - expected)
missing_in_workflow = sorted(manifest_jobs - workflow_jobs)

errors = []
if missing_in_manifest:
    errors.append(
        "Workflow jobs missing from manifest: " + ", ".join(missing_in_manifest)
    )
if missing_in_workflow:
    errors.append(
        "Manifest jobs missing from workflow: " + ", ".join(missing_in_workflow)
    )

# everything-passed needs must include every non-metadata job.
needs = set(workflow_data.get("jobs", {}).get("everything-passed", {}).get("needs", []))
gate_missing = sorted((workflow_jobs - metadata) - needs)
if gate_missing:
    errors.append(
        "everything-passed missing needs for: " + ", ".join(gate_missing)
    )

# ci-router must expose run_<job> for every routable manifest job.
# jac-check always runs independently (no router gate).
def job_to_run_output(job: str) -> str:
    return f"run_{job.replace('-', '_')}"

always_run = set(manifest.get("always_run_jobs", []))
routable_jobs = manifest_jobs - always_run - {"jac-check"}
router_outputs = set(
    workflow_data.get("jobs", {}).get("ci-router", {}).get("outputs", {}).keys()
)
router_metadata = {"full_ci", "audit_fail", "unknown", "selected_jobs"}
router_job_outputs = router_outputs - router_metadata

expected_outputs = {job_to_run_output(j) for j in routable_jobs}
missing_router = sorted(expected_outputs - router_job_outputs)
extra_router = sorted(router_job_outputs - expected_outputs)
if missing_router:
    errors.append(
        "ci-router missing run_* outputs for: " + ", ".join(missing_router)
    )
if extra_router:
    errors.append(
        "ci-router has run_* outputs with no manifest job: " + ", ".join(extra_router)
    )

# event_excluded_jobs: every job must exist in `jobs` and every event must be
# a real workflow trigger. PyYAML parses the bare `on:` key as boolean True.
event_excluded = manifest.get("event_excluded_jobs", {}) or {}
on_field = workflow_data.get("on")
if on_field is None:
    on_field = workflow_data.get(True)
triggers = set(on_field.keys()) if isinstance(on_field, dict) else set(on_field or [])
referenced = {j for jobs in event_excluded.values() for j in jobs}
bad_jobs = sorted(referenced - manifest_jobs)
bad_events = sorted(set(event_excluded) - triggers)
if bad_jobs:
    errors.append("event_excluded_jobs lists unknown jobs: " + ", ".join(bad_jobs))
if bad_events:
    errors.append("event_excluded_jobs lists unknown events: " + ", ".join(bad_events))

full_ci_excluded = set(manifest.get("full_ci_excluded_jobs", []))
bad_excluded = sorted(full_ci_excluded - manifest_jobs)
if bad_excluded:
    errors.append(
        "full_ci_excluded_jobs lists unknown jobs: " + ", ".join(bad_excluded)
    )

# --- Wiring: each ci-router run_<job> output must mirror steps.route.outputs.<name> ---
# A copied output pointing at the wrong step makes a routable job unselectable
# while every name-based check above still passes.
router_outputs = (
    workflow_data.get("jobs", {}).get("ci-router", {}).get("outputs", {}) or {}
)
for job in sorted(routable_jobs):
    out = job_to_run_output(job)
    expected_expr = "${{ steps.route.outputs.%s }}" % out
    actual = router_outputs.get(out)
    if actual is None:
        continue  # already reported as a missing output above
    if str(actual).strip() != expected_expr:
        errors.append(
            f"ci-router output {out} must be '{expected_expr}', got '{actual}'"
        )

# --- Wiring: each routable job must depend on ci-router and gate on its own run_* ---
for job in sorted(routable_jobs):
    job_def = workflow_data.get("jobs", {}).get(job)
    if not job_def:
        continue  # already reported as missing from the workflow
    needs_list = job_def.get("needs", [])
    if isinstance(needs_list, str):
        needs_list = [needs_list]
    if "ci-router" not in needs_list:
        errors.append(f"{job}: must list ci-router in needs:")
    out = job_to_run_output(job)
    if_clause = str(job_def.get("if") or "")
    if not if_clause:
        errors.append(f"{job}: routable job must define an if: gate")
    elif out not in if_clause:
        errors.append(
            f"{job}: if: gate must reference needs.ci-router.outputs.{out}"
        )

# --- Reference validity: manifest must only name real jobs / categories ---
known_jobs = manifest_jobs | metadata
known_categories = set(manifest.get("allowlist_categories", []))


def _bad_jobs(refs, where: str) -> None:
    bad = sorted({r for r in refs if r not in known_jobs})
    if bad:
        errors.append(f"{where} references unknown jobs: " + ", ".join(bad))


for cat, jobs in (manifest.get("category_jobs", {}) or {}).items():
    _bad_jobs(jobs, f"category_jobs[{cat}]")

for job, rule in (manifest.get("conditional_jobs", {}) or {}).items():
    if job not in known_jobs:
        errors.append(f"conditional_jobs lists unknown job: {job}")
    bad_cats = sorted(
        {c for c in (rule.get("categories") or []) if c not in known_categories}
    )
    if bad_cats:
        errors.append(
            f"conditional_jobs[{job}] references unknown categories: "
            + ", ".join(bad_cats)
        )

_bad_jobs(manifest.get("always_run_jobs", []), "always_run_jobs")

for label, jobs in (manifest.get("pr_label_skips", {}) or {}).items():
    _bad_jobs(jobs, f"pr_label_skips[{label}]")

for pattern, spec in (manifest.get("test_shard_globs", {}) or {}).items():
    _bad_jobs(
        spec if isinstance(spec, list) else [spec],
        f"test_shard_globs[{pattern}]",
    )

for seam in (manifest.get("cross_seam", []) or []):
    _bad_jobs(seam.get("add_jobs", []), "cross_seam add_jobs")

# --- Coverage: every named `jac test <file>.jac` command in a routable job must
# route to that job. Catches a test consumed by job X but mapped (via
# test_shard_globs) only to job Y -- the class of silent under-routing that a
# directory-only inventory cannot see. Always-run / metadata jobs are skipped:
# they run unconditionally and do not rely on shard selection.
import fnmatch as _fnmatch
import re as _re


def _glob_match(path: str, pattern: str) -> bool:
    if pattern.endswith("/**"):
        prefix = pattern[:-3]
        return path == prefix or path.startswith(prefix + "/")
    return _fnmatch.fnmatch(path, pattern)


_shard_entries = sorted(
    [
        (pat, jobs if isinstance(jobs, list) else [jobs])
        for pat, jobs in (manifest.get("test_shard_globs", {}) or {}).items()
    ],
    key=lambda kv: (-len(kv[0].replace("**", "")), kv[0]),
)


def _mapped_jobs(path: str) -> set:
    for pat, jobs in _shard_entries:
        if _glob_match(path, pat):
            return set(jobs)
    return set()


_jac_test = _re.compile(r"\bjac\s+test\b")
_token = _re.compile(r"[^\s;|&\"]+")
_non_routing = always_run | metadata

for _jname, _jdef in workflow_data.get("jobs", {}).items():
    if _jname in _non_routing:
        continue
    for _step in _jdef.get("steps", []) or []:
        _run = _step.get("run")
        if not isinstance(_run, str):
            continue
        for _line in _run.splitlines():
            _mj = _jac_test.search(_line)
            if not _mj:
                continue
            _prev_flag = None
            for _tok in _token.findall(_line[_mj.end():]):
                if _tok.startswith("-"):
                    _prev_flag = _tok
                    continue
                if _prev_flag == "--ignore":
                    _prev_flag = None
                    continue
                _prev_flag = None
                if not _tok.endswith(".jac"):
                    continue
                _mapped = _mapped_jobs(_tok)
                if _jname not in _mapped:
                    errors.append(
                        f"{_jname} runs `jac test {_tok}` but test_shard_globs "
                        f"maps it to {sorted(_mapped) or 'nothing'}; "
                        f"add {_jname} to its shard entry"
                    )

if errors:
    for e in errors:
        print(f"::error::{e}")
    raise SystemExit(1)

print("CI manifest and workflow are synchronized.")
PY
