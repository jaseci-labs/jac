#!/usr/bin/env bash
# Validate aggregate gate: reject unexpected skips in full mode.
# Usage: validate-expected-jobs.sh SELECTED_JSON NEEDS_JSON MODE [EVENT] [LABELS]
#   EVENT: github.event_name for the run. When set, jobs the workflow structurally
#          skips on that event (declared as event_excluded_jobs in ci-coverage.yml)
#          are not required to succeed in full mode. Optional for pr mode.
#   LABELS: JSON array of PR label names (or comma-separated). Jobs listed under
#           pr_label_skips for a matching label are not required to succeed.
set -euo pipefail

SELECTED_JSON="${1:?selected jobs json}"
NEEDS_JSON="${2:?needs json}"
MODE="${3:-pr}"
EVENT="${4:-}"
LABELS="${5:-}"
MANIFEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ci-coverage.yml"

python3 - "$SELECTED_JSON" "$NEEDS_JSON" "$MODE" "$EVENT" "$LABELS" "$MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

selected = set(json.loads(Path(sys.argv[1]).read_text()))
needs = json.loads(Path(sys.argv[2]).read_text())
mode = sys.argv[3]
event = sys.argv[4]
labels_arg = sys.argv[5]
manifest_path = Path(sys.argv[6])

# Metadata jobs (router/audit/gate/build) and per-event structural skips
# both live in scripts/ci/ci-coverage.yml so the rule stays in one place
# (not hardcoded here). Only full mode forces every job to run, so exclusions
# only matter there, but subtracting unconditionally is safe.
if not manifest_path.is_file():
    print(f"::error::CI manifest missing: {manifest_path}")
    sys.exit(1)
try:
    import yaml
except ImportError:
    print("::error::PyYAML required")
    sys.exit(1)
manifest = yaml.safe_load(manifest_path.read_text()) or {}

metadata = set(manifest.get("metadata_jobs", []))
if not metadata:
    print("::error::metadata_jobs missing from CI manifest")
    sys.exit(1)

excluded: set[str] = set()
if event:
    excluded = set((manifest.get("event_excluded_jobs", {}) or {}).get(event, []))

label_set: set[str] = set()
if labels_arg:
    try:
        parsed = json.loads(labels_arg)
        if isinstance(parsed, list):
            label_set = {str(x) for x in parsed}
    except json.JSONDecodeError:
        label_set = {x.strip() for x in labels_arg.split(",") if x.strip()}

label_excluded: set[str] = set()
for label, jobs in (manifest.get("pr_label_skips", {}) or {}).items():
    if label in label_set:
        label_excluded.update(jobs)

errors = []
for job, info in needs.items():
    if job in metadata:
        continue
    result = info.get("result", "skipped")
    # selected_jobs is authoritative in every mode. The router already subtracts
    # full_ci_excluded_jobs on path-escalated PRs and applies event/label skips,
    # so forcing every job on mode == "full" would wrongly require a job the
    # router intentionally excluded (e.g. installer-test under full_ci).
    should_run = (
        job in selected
        and job not in excluded
        and job not in label_excluded
    )
    if should_run and result != "success":
        errors.append(f"{job}: expected success, got {result}")
    if not should_run and mode != "full" and result not in ("skipped", "success"):
        errors.append(f"{job}: unexpected state {result}")

if errors:
    for e in errors:
        print(f"::error::{e}")
    sys.exit(1)

print("Aggregate job selection validated.")
PY
