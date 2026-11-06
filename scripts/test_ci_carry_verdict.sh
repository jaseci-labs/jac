#!/usr/bin/env bash
# Each case plants earlier runs on one commit behind a fake gh and checks the
# verdict ci_carry_verdict.sh carries.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/runs"
cat > "$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "run list") ls "$RUNS" | jq -R '{databaseId: tonumber}' | jq -s . ;;
  "run watch") exit 0 ;;
  "run view") cat "$RUNS/$3" ;;
  *) echo "fake gh: unexpected $*" >&2; exit 2 ;;
esac
EOF
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH" RUNS="$work/runs" GITHUB_REPOSITORY=o/r GITHUB_RUN_ID=100 SHA=abc

job() { printf '{"name":"%s","conclusion":"%s"}' "$1" "$2"; }
suite() {
  local id=$1 conclusion=$2; shift 2
  printf '{"conclusion":"%s","jobs":[%s,%s,%s,%s,%s,%s]}' "$conclusion" \
    "$(job changes success)" "$(job build-kit "${1:-success}")" \
    "$(job 'Contribution Checks' "${2:-success}")" "$(job test-scale-k8s "${3:-success}")" \
    "$(job 'test-compiler (passes-main)' "${4:-success}")" \
    "$(job 'Everything Passed' "$conclusion")" > "$RUNS/$id"
}
label_only() {
  printf '{"conclusion":"%s","jobs":[%s,%s,%s]}' "$2" "$(job changes skipped)" \
    "$(job build-kit skipped)" "$(job 'Everything Passed' "$2")" > "$RUNS/$1"
}
expect() {
  local want=$1 name=$2 got=pass
  bash "$repo/scripts/ci_carry_verdict.sh" > "$work/out" 2>&1 || got=fail
  if [ "$got" != "$want" ]; then
    echo "FAIL: $name: wanted $want, got $got" >&2
    cat "$work/out" >&2
    exit 1
  fi
  echo "ok: $name"
  rm -f "$RUNS"/*
  SKIP_K8S=false
}
export SKIP_K8S=false

suite 10 success
expect pass "a green suite run is carried"

suite 10 failure failure
expect fail "a failed build-kit is not carried"

suite 10 failure success success success failure
expect fail "a failed matrix lane is not carried"

suite 10 failure success failure
expect pass "an earlier Contribution Checks failure is judged again, not carried"

suite 10 failure success success failure
expect fail "a failed test-scale-k8s is not carried without skip-k8s"

suite 10 failure success success failure
SKIP_K8S=true
expect pass "a failed test-scale-k8s is waived with skip-k8s"

suite 10 failure failure
suite 20 cancelled success success success cancelled
expect fail "a cancelled run is passed over for the run before it"

suite 10 success
suite 20 cancelled success success success cancelled
expect pass "a cancelled run does not hide a green run before it"

suite 10 failure failure
label_only 20 success
expect fail "a label-only run is passed over, not carried as green"

suite 10 failure failure
suite 20 success
expect pass "the newest suite run is carried, not an older red one"

suite 10 success
suite 200 failure failure
expect pass "a run newer than this one is ignored"

label_only 20 success
expect fail "no earlier suite run fails the gate"

expect fail "no earlier run at all fails the gate"
