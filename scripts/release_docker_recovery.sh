#!/usr/bin/env bash
# Read-only: verify an otherwise-complete release and print its original plan.
# The caller runs release_publish_guard.sh only after this and Docker succeed.
set -euo pipefail

fail() { echo "::error::$*" >&2; exit 1; }
TAG="${1:-}"
RUN_ID="${2:-}"
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Recovery needs a versioned tag."
[[ "$RUN_ID" =~ ^[1-9][0-9]*$ ]] || fail "Recovery needs the original Release run ID."
ENDPOINT="repos/${GH_REPO:?}/actions/runs/$RUN_ID"
RUN="$(gh api "$ENDPOINT")"
jq -e '.path == ".github/workflows/release.yml" and .status == "completed"' \
    <<<"$RUN" >/dev/null || fail "Expected a completed run of release.yml."
# Pin the attempt so a concurrent rerun cannot mix two attempts' jobs.
ATTEMPT="$(jq -r .run_attempt <<<"$RUN")"
JOBS="$(gh api --paginate --slurp "$ENDPOINT/attempts/$ATTEMPT/jobs?per_page=100" \
    | jq '[.[].jobs[]]')"
successful_job() {
    jq -er --arg name "$1" '
      map(select(.name == $name))
      | if length == 1 and .[0].conclusion == "success" then .[0].id
        else error("Original release job did not succeed: " + $name) end
    ' <<<"$JOBS"
}
for job in resolve approve tag-and-release "build-binaries / admin-dist"; do
    successful_job "$job" >/dev/null
done
PLAN_ID="$(successful_job 'build-binaries / plan')"
# Newer gh versions reject ANSI escapes even when stdout is captured. Logs
# contain shell highlighting; allow it for parsing, never terminal display.
log_flags=()
if gh api --help | grep -q -- '--allow-escape-sequences'; then
    log_flags+=(--allow-escape-sequences)
fi
PLAN="$(gh api "${log_flags[@]}" "repos/$GH_REPO/actions/jobs/$PLAN_ID/logs")"
# Raw job logs prefix every line with a timestamp. Expired/missing logs fail;
# never guess a platform list or accept an operator-supplied subset.
plan_value() {
    sed -E 's/^[^ ]+ *//' <<<"$PLAN" | awk -v prefix="$1" '
      index($0, prefix) == 1 {
        value = substr($0, length(prefix) + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        count++
      }
      END { if (count != 1) exit 1; print value }
    ' || fail "Could not identify original plan field: $1"
}
[[ "$(plan_value tag:)" == "$TAG" ]] || fail "Original plan has a different tag."
[[ "$(plan_value channel:)" == release ]] || fail "Original plan is not a release."
# Assign before comparing: command-substitution failure must not look like an
# empty (valid) platform filter.
ONLY="$(plan_value only:)"
[[ -z "$ONLY" ]] || fail "Original plan is filtered."
COMMIT="$(gh api "repos/$GH_REPO/commits/$TAG" --jq .sha)"
[[ "$(plan_value commit:)" == "$COMMIT" ]] || fail "Tag no longer matches the approved build commit."
REQUIRED="$(plan_value 'Required to publish:')"
read -r -a platforms <<<"$REQUIRED"
[[ "${#platforms[@]}" -gt 0 ]] || fail "Original plan has no required platforms."
for platform in "${platforms[@]}"; do
    [[ "$platform" =~ ^[a-z0-9]+([-_][a-z0-9]+)*$ ]] || fail "Invalid platform in original plan."
    successful_job "build-binaries / $platform" >/dev/null
done
ASSETS="$(gh release view "$TAG" --json assets)"
# All required binaries AND admin packaging must still have their checksum
# sidecars. The image builder additionally verifies both Linux checksums.
jq -e --arg version "${TAG#v}" --arg required "$REQUIRED" '
  (.assets | map(.name)) as $actual
  | ($required | split(" ") | map("jac-" + $version + "-" + .))
    + ["jac-" + $version + "-admin-dist.tar.gz"]
  | map(., . + ".sha256") - $actual
  | if length == 0 then true else error("Missing release assets: " + join(", ")) end
' <<<"$ASSETS" >/dev/null
printf '%s\n' "$REQUIRED"
