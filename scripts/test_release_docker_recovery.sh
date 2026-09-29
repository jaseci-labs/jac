#!/usr/bin/env bash
# Exercise recovery boundaries with a fake GitHub API; nothing is published.
set -euo pipefail
GUARD="$(cd "$(dirname "$0")" && pwd)/release_docker_recovery.sh"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT
export FIXTURE GH_REPO=jaseci-labs/jac
mkdir "$FIXTURE/bin"
export PATH="$FIXTURE/bin:$PATH"
cat >"$FIXTURE/bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  'api --help')
    if [[ ! -e "$FIXTURE/legacy-gh" ]]; then
      printf '%s\n' '--allow-escape-sequences'
    fi ;;
  *'/logs')
    if [[ -e "$FIXTURE/legacy-gh" ]]; then
      [[ "$*" != *'--allow-escape-sequences'* ]] || exit 1
    else
      [[ "$*" == *'--allow-escape-sequences'* ]] || exit 1
    fi
    [[ ! -e "$FIXTURE/expired" ]] || exit 1
    cat "$FIXTURE/plan" ;;
  *'/commits/'*) printf '%s\n' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;
  *'/attempts/2/jobs?per_page=100') cat "$FIXTURE/jobs" ;;
  'release view '*) cat "$FIXTURE/assets" ;;
  'api repos/jaseci-labs/jac/actions/runs/123') cat "$FIXTURE/run" ;;
  *) echo "Unexpected gh call: $*" >&2; exit 1 ;;
esac
SH
chmod +x "$FIXTURE/bin/gh"
cat >"$FIXTURE/run.original" <<'JSON'
{"path":".github/workflows/release.yml","status":"completed","run_attempt":2}
JSON
cat >"$FIXTURE/plan.original" <<'LOG'
2026-09-15T03:05:54.8042564Z   tag: v0.37.15
2026-09-15T03:05:54.8042564Z   commit: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
2026-09-15T03:05:54.8042564Z   channel: release
2026-09-15T03:05:54.8042564Z   only:
2026-09-15T03:05:54.8042564Z Required to publish: linux-x86_64 linux-aarch64 macos-aarch64
LOG
jq -n '
  ["resolve", "approve", "tag-and-release", "build-binaries / plan",
   "build-binaries / admin-dist", "build-binaries / linux-x86_64",
   "build-binaries / linux-aarch64", "build-binaries / macos-aarch64"]
  | to_entries | map({id:.key, name:.value, conclusion:"success"})
  | . + [{id:99, name:"build-binaries / docker-image", conclusion:"failure"}]
  | [{jobs:.[0:4]}, {jobs:.[4:]}]
' >"$FIXTURE/jobs.original"
jq -n '{assets:(["linux-x86_64", "linux-aarch64", "macos-aarch64", "admin-dist.tar.gz"]
  | map("jac-0.37.15-" + .) | map(., . + ".sha256") | map({name:.}))}' \
  >"$FIXTURE/assets.original"
reset_fixture() {
    for name in run plan jobs assets; do cp "$FIXTURE/$name.original" "$FIXTURE/$name"; done
}
checks=0
reject() {
    if bash "$GUARD" "${1:-v0.37.15}" "${2-123}" >"$FIXTURE/output" 2>"$FIXTURE/error"; then
        echo "Recovery unexpectedly accepted an incomplete/invalid release" >&2
        exit 1
    fi
    checks=$((checks + 1))
}
reset_fixture
[[ "$(bash "$GUARD" v0.37.15 123)" == 'linux-x86_64 linux-aarch64 macos-aarch64' ]]
checks=$((checks + 1))
touch "$FIXTURE/legacy-gh"
[[ "$(bash "$GUARD" v0.37.15 123)" == 'linux-x86_64 linux-aarch64 macos-aarch64' ]]
checks=$((checks + 1))
rm "$FIXTURE/legacy-gh"
for index in {0..7}; do
    jq --argjson i "$index" 'del(.assets[$i])' "$FIXTURE/assets.original" >"$FIXTURE/assets"
    reject
done
reset_fixture
for index in {0..7}; do
    jq --argjson i "$index" 'map(.jobs |= map(if .id == $i then .conclusion = "failure" else . end))' \
        "$FIXTURE/jobs.original" >"$FIXTURE/jobs"
    reject
done
reset_fixture
for change in 's/v0.37.15/v0.37.14/' 's/aaaaaaaa/bbbbbbbb/' \
    's/channel: release/channel: dev/' 's/only:/only: linux-x86_64/' \
    '/only:/d' '/Required to publish:/d' \
    's/linux-x86_64 linux-aarch64 macos-aarch64/(none)/'; do
    sed "$change" "$FIXTURE/plan.original" >"$FIXTURE/plan"
    reject
done
reset_fixture
for change in '.path = ".github/workflows/ci.yml"' '.status = "in_progress"'; do
    jq "$change" "$FIXTURE/run.original" >"$FIXTURE/run"
    reject
done
reset_fixture
reject dev
reject v0.37.15 ''
reject v0.37.15 linux-x86_64
touch "$FIXTURE/expired"
reject
printf '%s recovery checks passed\n' "$checks"
