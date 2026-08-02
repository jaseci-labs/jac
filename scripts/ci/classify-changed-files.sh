#!/usr/bin/env bash
# Classify changed paths into CI job selections (fail-closed).
# Usage: classify-changed-files.sh [--manifest PATH] [--mode MODE]
#   MODE: pr | full
# Reads NUL-delimited paths on stdin (or no paths for full mode).
# Writes GitHub Actions outputs when GITHUB_OUTPUT is set.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="${ROOT}/scripts/ci/ci-coverage.yml"
MODE="pr"

while [ $# -gt 0 ]; do
  case "$1" in
    --manifest) MANIFEST="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--manifest PATH] [--mode pr|full]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$MODE" in
  pr|full) ;;
  *) echo "::error::Invalid --mode '$MODE' (expected pr|full)" >&2; exit 2 ;;
esac

if [ ! -f "$MANIFEST" ]; then
  echo "::error::CI manifest missing: $MANIFEST" >&2
  exit 1
fi

PATHS_FILE="$(mktemp)"
trap 'rm -f "$PATHS_FILE"' EXIT

if [ "$MODE" = "full" ]; then
  : >"$PATHS_FILE"
else
  cat >"$PATHS_FILE"
fi

RESULT_JSON="$(python3 - "$MANIFEST" "$MODE" "$PATHS_FILE" <<'PY'
import fnmatch
import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("::error::PyYAML required for CI classifier", file=sys.stderr)
    sys.exit(1)

manifest_path = Path(sys.argv[1])
mode = sys.argv[2]
paths_file = Path(sys.argv[3])

manifest = yaml.safe_load(manifest_path.read_text())
if not isinstance(manifest, dict):
    raise SystemExit("manifest must be a mapping")

all_jobs = list(manifest.get("jobs", []))
always_jobs = list(manifest.get("always_run_jobs", []))
full_ci_excluded = set(manifest.get("full_ci_excluded_jobs", []))
allowlist = list(manifest.get("allowlist_categories", []))
full_globs = list(manifest.get("full_ci_globs", []))
full_exceptions = list(manifest.get("full_ci_exceptions", []))
category_globs = manifest.get("category_globs", {})
category_jobs = manifest.get("category_jobs", {})
conditional_jobs = manifest.get("conditional_jobs", {})
test_shard_globs = manifest.get("test_shard_globs", {})
cross_seam = manifest.get("cross_seam", [])

# Order matters: more specific test shards first. A value may be a single
# job or a list of jobs, because some tests are consumed by more than one CI
# environment (e.g. a native test run on both Linux and macOS lanes).
ordered_test_shards = sorted(
    [
        (pat, jobs if isinstance(jobs, list) else [jobs])
        for pat, jobs in test_shard_globs.items()
    ],
    key=lambda kv: (-len(kv[0].replace("**", "")), kv[0]),
)


def glob_match(path: str, pattern: str) -> bool:
    if pattern.endswith("/**"):
        prefix = pattern[:-3]
        return path == prefix or path.startswith(prefix + "/")
    if pattern.endswith("**"):
        prefix = pattern[:-2]
        return path.startswith(prefix)
    return fnmatch.fnmatch(path, pattern)


def any_glob(path: str, patterns: list[str]) -> bool:
    return any(glob_match(path, g) for g in patterns)


def classify_path(path: str) -> dict:
    tags: set[str] = set()
    jobs: set[str] = set()
    unknown = False
    full = False

    if any_glob(path, full_exceptions):
        for cat, globs in category_globs.items():
            if any_glob(path, globs):
                tags.add(cat)
        for pattern, shard_jobs in ordered_test_shards:
            if glob_match(path, pattern):
                jobs.update(shard_jobs)
                break
        return {"tags": tags, "jobs": jobs, "unknown": False, "full": False}

    if any_glob(path, full_globs):
        return {"tags": set(), "jobs": set(), "unknown": False, "full": True}

    matched = False
    for cat, globs in category_globs.items():
        if any_glob(path, globs):
            tags.add(cat)
            matched = True

    for pattern, shard_jobs in ordered_test_shards:
        if glob_match(path, pattern):
            jobs.update(shard_jobs)
            matched = True
            break

    if not matched:
        unknown = True

    return {"tags": tags, "jobs": jobs, "unknown": unknown, "full": False}


paths = [p for p in paths_file.read_text().split("\0") if p]

if mode == "full":
    selected = set(all_jobs)
    result = {
        "full_ci": True,
        "unknown": False,
        "unknown_paths": [],
        "mixed_categories": False,
        "audit_fail": False,
        "selected_jobs": sorted(selected),
        "source_categories": [],
        "mode": mode,
    }
    print(json.dumps(result))
    sys.exit(0)

per_path = [classify_path(p) for p in paths]
unknown_paths = [p for p, info in zip(paths, per_path) if info["unknown"]]
full_ci = any(info["full"] for info in per_path) or bool(unknown_paths)

source_categories: set[str] = set()
for info in per_path:
    source_categories.update(info["tags"])

mixed = len([c for c in allowlist if c in source_categories]) >= 2

if mixed:
    full_ci = True

selected: set[str] = set(always_jobs)
if full_ci:
    selected.update(all_jobs)
    selected -= full_ci_excluded
    for info in per_path:
        for tag in info["tags"]:
            selected.update(category_jobs.get(tag, []))
        selected.update(info["jobs"])
else:
    for info in per_path:
        for tag in info["tags"]:
            selected.update(category_jobs.get(tag, []))
        selected.update(info["jobs"])

    active_categories = set()
    for info in per_path:
        active_categories.update(info["tags"])

    for job, rule in conditional_jobs.items():
        globs = rule.get("globs", [])
        cats = rule.get("categories", [])

        if globs and any(any_glob(p, globs) for p in paths):
            selected.add(job)
        elif cats and any(c in active_categories for c in cats):
            selected.add(job)

    for seam in cross_seam:
        seam_paths = seam.get("paths", [])
        when_cats = seam.get("when_categories", [])
        if any(any_glob(p, seam_paths) for p in paths):
            if not when_cats or any(c in active_categories for c in when_cats):
                selected.update(seam.get("add_jobs", []))

    # No changed paths (empty diff) → fail-closed to full CI.
    if not paths:
        selected.update(all_jobs)
        full_ci = True

audit_fail = bool(unknown_paths)

result = {
    "full_ci": full_ci,
    "unknown": bool(unknown_paths),
    "unknown_paths": unknown_paths,
    "mixed_categories": mixed,
    "audit_fail": audit_fail,
    "selected_jobs": sorted(selected),
    "source_categories": sorted(source_categories),
    "mode": mode,
}
print(json.dumps(result))
PY
)"

if [ -z "$RESULT_JSON" ]; then
  echo "::error::Classifier produced no output (fail-closed)" >&2
  # Fail closed: select everything.
  RESULT_JSON='{"full_ci":true,"unknown":true,"unknown_paths":[],"mixed_categories":false,"audit_fail":true,"selected_jobs":[],"source_categories":[],"mode":"'"$MODE"'"}'
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  python3 - "$RESULT_JSON" <<'PY' >>"$GITHUB_OUTPUT"
import json, sys
result = json.loads(sys.argv[1])
for key, value in result.items():
    if isinstance(value, bool):
        out = "true" if value else "false"
    elif isinstance(value, list):
        out = json.dumps(value)
    else:
        out = str(value)
    print(f"{key}={out}")
PY
  # Per-job outputs for workflow if conditions.
  python3 - "$RESULT_JSON" "$MANIFEST" <<'PY' >>"$GITHUB_OUTPUT"
import json, sys, yaml
from pathlib import Path

result = json.loads(sys.argv[1])
manifest = yaml.safe_load(Path(sys.argv[2]).read_text())
selected = set(result.get("selected_jobs", []))
for job in manifest.get("jobs", []):
    run = job in selected
    print(f"run_{job.replace('-', '_')}={'true' if run else 'false'}")
PY
fi

echo "$RESULT_JSON"

if [ "$(python3 -c "import json,sys; print('true' if json.loads(sys.argv[1]).get('audit_fail') else 'false')" "$RESULT_JSON")" = "true" ]; then
  python3 -c "import json,sys; u=json.loads(sys.argv[1]).get('unknown_paths',[]); print('::error::Unclassified changed paths (fail-closed):', ', '.join(u) or '(classifier error)')" "$RESULT_JSON" >&2
fi
