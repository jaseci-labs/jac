#!/usr/bin/env bash
# Handles a `/test ...` PR comment: reacts to it and re-runs the latest
# pull_request run of each affected test workflow so their `plan` jobs
# re-evaluate the request (see ci-requested-suites.sh). Posts NO comments and
# creates NO status/check rows - the only acknowledgement is an emoji reaction.
#
# Invoked by ci-command.yml on `issue_comment`. Requires: gh (authenticated via
# GH_TOKEN), jq. Reads the event from $GITHUB_EVENT_PATH.
set -euo pipefail

repo="${GITHUB_REPOSITORY:?}"
event="${GITHUB_EVENT_PATH:?}"

comment_id="$(jq -r '.comment.id' "$event")"
pr="$(jq -r '.issue.number' "$event")"
commenter="$(jq -r '.comment.user.login' "$event")"
body="$(jq -r '.comment.body' "$event")"

react() { # react <content>  (best-effort; never fails the job)
  gh api -X POST "repos/$repo/issues/comments/$comment_id/reactions" \
    -f "content=$1" >/dev/null 2>&1 || echo "::warning::reaction '$1' failed"
}

# suite -> space-separated workflow file(s). `core` spans test-binary.yml
# (compiler/runtime) and test-jaseci.yml (solid-jsdom).
suite_workflows() {
  case "$1" in
    core)      echo "test-binary.yml test-jaseci.yml" ;;
    client|scale|mcp|byllm|docs|desktop|macos) echo "test-jaseci.yml" ;;
    k8s)       echo "k8s-microservice-real-e2e.yml" ;;
    check)     echo "jac-check.yml" ;;
    contrib)   echo "contribution-checks.yml" ;;
    installer) echo "test-installer.yml" ;;
    *)         echo "" ;;
  esac
}
ALL="core client scale mcp byllm docs desktop macos k8s check contrib installer"

# tokens after `/test`, lowercased
read -ra toks <<< "${body#*/test}"
args=()
for t in "${toks[@]}"; do args+=("${t,,}"); done

# `/test` or `/test help`: just acknowledge.
if [[ ${#args[@]} -eq 0 || "${args[0]}" == help ]]; then
  react eyes
  exit 0
fi

# Authorize: repo collaborator, read access or above.
perm="$(gh api "repos/$repo/collaborators/$commenter/permission" --jq '.permission' 2>/dev/null || echo none)"
case "$perm" in
  admin|maintain|write|triage|read) ;;
  *) react "-1"; exit 0 ;;
esac

# Resolve requested suites.
requested=""
for a in "${args[@]}"; do
  if [[ "$a" == all ]]; then requested="$ALL"; break; fi
  [[ " $ALL " == *" $a "* && " $requested " != *" $a "* ]] && requested="$requested $a"
done
requested="${requested## }"
if [[ -z "$requested" ]]; then react confused; exit 0; fi

react rocket

sha="$(gh api "repos/$repo/pulls/$pr" --jq '.head.sha')"

# Affected workflows (deduped).
workflows=""
for s in $requested; do
  for wf in $(suite_workflows "$s"); do
    [[ " $workflows " == *" $wf "* ]] || workflows="$workflows $wf"
  done
done

# Re-run each affected workflow's latest pull_request run for this commit so its
# plan job re-reads the comments. A run that's still in progress can't be re-run
# yet, so wait briefly for it to finish first.
any_rerun=false
for wf in $workflows; do
  rerun=false
  for _ in $(seq 1 12); do
    read -r run_id status < <(
      gh api "repos/$repo/actions/workflows/$wf/runs?head_sha=$sha&event=pull_request&per_page=1" \
        --jq '.workflow_runs[0] | "\(.id // "") \(.status // "")"' 2>/dev/null || echo " "
    )
    if [[ -z "$run_id" ]]; then sleep 5; continue; fi          # run not created yet
    if [[ "$status" != "completed" ]]; then sleep 5; continue; fi  # wait for it to finish
    if gh api -X POST "repos/$repo/actions/runs/$run_id/rerun" >/dev/null 2>&1; then
      rerun=true; any_rerun=true; break
    fi
    echo "::warning::re-run of $wf (#$run_id) failed"
    sleep 5
  done
  $rerun || echo "::warning::could not re-run $wf for ${sha:0:7} (no completed run yet)"
done

# Nothing could be re-triggered (e.g. no pull_request run exists yet): swap the
# rocket for a confused reaction so the user knows nothing started.
$any_rerun || react confused
