#!/usr/bin/env bash
# Decides which CI suites a pull_request run should execute, based on `/test`
# comments, and writes `<suite>=true|false` lines to $GITHUB_OUTPUT for the
# calling `plan` job to gate on.
#
# Usage:  ci-requested-suites.sh <suite> [<suite> ...]
#   e.g.  ci-requested-suites.sh core client scale ...
#
# Rules (see CONTRIBUTING.md "Running CI on your PR"):
#   - On push events: every listed suite is enabled (full post-merge coverage).
#   - On a pull_request: a suite is enabled only if the MOST RECENT `/test`
#     comment from a repo collaborator (read access or above) named it. `all`
#     expands to every suite. Nothing accumulates across comments.
#   - Only honored on a re-run (GITHUB_RUN_ATTEMPT > 1): the automatic run that
#     fires on PR open/push is attempt 1 and requests nothing, so a new commit
#     starts clean. Fail closed if the attempt can't be determined.
#
# Requires: gh (authenticated via GH_TOKEN/GITHUB_TOKEN), jq. Both are
# preinstalled on GitHub-hosted runners.
set -euo pipefail

SUITES=("$@")
out="${GITHUB_OUTPUT:-/dev/stdout}"

emit() { # emit <space-separated requested suites>
  local requested=" $1 "
  local s
  for s in "${SUITES[@]}"; do
    if [[ "$requested" == *" $s "* ]]; then echo "$s=true"; else echo "$s=false"; fi
  done >> "$out"
}

# push -> run everything listed.
if [[ "${GITHUB_EVENT_NAME:-}" == "push" ]]; then
  emit "${SUITES[*]}"
  exit 0
fi

# Only a /test re-run (attempt > 1) reads comments; fail closed otherwise.
attempt="${GITHUB_RUN_ATTEMPT:-0}"
if ! [[ "$attempt" =~ ^[0-9]+$ ]] || (( attempt <= 1 )); then
  emit ""
  exit 0
fi

# PR number from the event payload.
pr="$(jq -r '.pull_request.number // .issue.number // empty' "${GITHUB_EVENT_PATH:-/dev/null}" 2>/dev/null || true)"
if [[ -z "$pr" ]]; then emit ""; exit 0; fi

repo="${GITHUB_REPOSITORY:?}"

# All PR comments, oldest-first; walk newest-first and take the first valid
# collaborator `/test` comment. Output per line: "<login>\t<body-first-line>".
mapfile -t lines < <(
  gh api --paginate "repos/$repo/issues/$pr/comments" \
    --jq '.[] | [.user.login, (.body // "" | gsub("\r";"") | split("\n")[0])] | @tsv' \
  2>/dev/null || true
)

is_collaborator() { # is_collaborator <login>  -> exit 0 if read+ access
  local login="$1" perm
  perm="$(gh api "repos/$repo/collaborators/$login/permission" --jq '.permission' 2>/dev/null || echo none)"
  case "$perm" in admin|maintain|write|triage|read) return 0;; *) return 1;; esac
}

# Walk newest-first; the first valid collaborator `/test` comment wins. Build
# `requested` as a plain space-delimited list (no associative arrays).
requested=""
for (( i=${#lines[@]}-1; i>=0; i-- )); do
  IFS=$'\t' read -r login body <<< "${lines[$i]}"
  body="${body#"${body%%[![:space:]]*}"}"   # ltrim leading whitespace
  [[ "$body" == /test* ]] || continue
  is_collaborator "$login" || continue

  read -ra toks <<< "${body#/test}"          # tokens after `/test`
  for t in "${toks[@]}"; do
    t="${t,,}"
    if [[ "$t" == all ]]; then
      requested=" ${SUITES[*]} "
      break
    fi
    for s in "${SUITES[@]}"; do
      [[ "$t" == "$s" && "$requested" != *" $s "* ]] && requested="$requested $s "
    done
  done
  break   # honor only this latest /test comment
done

emit "$requested"
