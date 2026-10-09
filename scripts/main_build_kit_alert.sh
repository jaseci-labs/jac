#!/usr/bin/env bash
# Keeps one open issue while build-kit is red on main. A red build-kit saves
# none of the caches pull requests restore, so PRs drift to cold builds.
# DRY_RUN=1 prints the issue writes instead of making them.
set -euo pipefail
: "${GH_REPO:?}" "${RUN_ID:?}" "${HEAD_SHA:?}" "${ACTOR:?}"

title="build-kit is red on main"
run_url="https://github.com/$GH_REPO/actions/runs/$RUN_ID"
write() {
  if [ -n "${DRY_RUN:-}" ]; then printf 'DRY_RUN:'; printf ' %q' "$@"; echo; else "$@"; fi
}

job=$(gh api "repos/$GH_REPO/actions/runs/$RUN_ID/jobs" --paginate \
  --jq '.jobs[] | select(.name == "build-kit") | "\(.conclusion) \(.html_url)"' | head -1)
conclusion=${job%% *}
job_url=${job#* }
issue=$(gh issue list --repo "$GH_REPO" --state open --search "\"$title\" in:title" \
  --json number,title --jq "map(select(.title == \"$title\")) | .[0].number // empty")
echo "build-kit: ${conclusion:-absent}; open alert: ${issue:-none}"

case "$conclusion" in
  failure)
    body="build-kit failed on main at $HEAD_SHA (pushed by @$ACTOR): $job_url

Until main's build-kit is green again, main saves no new stage-0 unit, precompile or JacPython caches, so pull requests rebuild them cold (about 40 to 50 minutes per build-kit)."
    if [ -n "$issue" ]; then
      write gh issue comment "$issue" --repo "$GH_REPO" --body "$body"
    else
      write gh issue create --repo "$GH_REPO" --title "$title" --body "$body"
    fi
    ;;
  success)
    if [ -n "$issue" ]; then
      write gh issue close "$issue" --repo "$GH_REPO" --comment "build-kit is green on main again at $HEAD_SHA: $run_url"
    fi
    ;;
esac
