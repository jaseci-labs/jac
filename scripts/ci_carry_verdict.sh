#!/usr/bin/env bash
# Repeats, for a label-only CI run, the verdict of the newest earlier run on
# the same commit that ran the suites. Cancelled runs and other label-only runs
# (their `changes` job skipped) are passed over. Contribution Checks is judged
# again by the label-only run, so the earlier result is dropped; so is
# test-scale-k8s when SKIP_K8S is true.
# Env: GITHUB_REPOSITORY, GITHUB_RUN_ID, SHA, SKIP_K8S.
set -euo pipefail

waived='^(Everything Passed|Contribution Checks)$'
if [ "${SKIP_K8S:-false}" = true ]; then
  waived='^(Everything Passed|Contribution Checks|test-scale-k8s)$'
fi

ids=$(gh run list --repo "$GITHUB_REPOSITORY" --workflow ci.yml --commit "$SHA" --limit 50 --json databaseId \
  | jq -r --argjson me "$GITHUB_RUN_ID" '[.[] | .databaseId | select(. < $me)] | sort | reverse | .[]')
for id in $ids; do
  gh run watch "$id" --repo "$GITHUB_REPOSITORY" --interval 60 > /dev/null || true
  run=$(gh run view "$id" --repo "$GITHUB_REPOSITORY" --json conclusion,jobs)
  [ "$(jq -r .conclusion <<<"$run")" = cancelled ] && continue
  [ "$(jq -r '.jobs[] | select(.name == "changes") | .conclusion' <<<"$run")" = success ] || continue
  bad=$(jq -r '.jobs[] | select(.conclusion != "success" and .conclusion != "skipped") | .name' <<<"$run" \
    | grep -Ev "$waived" || true)
  if [ -n "$bad" ]; then
    echo "::error::Run $id on $SHA did not pass:"
    echo "$bad"
    exit 1
  fi
  echo "Carried the verdict of run $id."
  exit 0
done
echo "::error::No earlier CI run on $SHA ran the suites to carry over; push or rerun CI."
exit 1
