#!/usr/bin/env bash
# The test plan for a CI run.
#
#   ci_plan.sh scope <base> <head>
#     Prints `scope=full` or `scope=tests`, then (for `tests`) the selected
#     test files, one per line, relative to the repository root. `tests` is
#     only chosen when every changed path is a test file, a fixture, a release
#     note, an archwire.jac edit confined to test wiring, or a path no CI lane
#     reads; anything else, or anything this script cannot place, is `full`.
#
#   ci_plan.sh plan <lanes.json> [<base> <head>]
#     Prints the test matrix as JSON: one entry per lane in .github/ci/lanes.json
#     that has files to run, with those files listed. Without a base the plan is
#     the full suite. Every test file under the catalog's test roots must belong
#     to exactly one lane (or be listed under `excluded`), else it fails.
set -euo pipefail

root=$(git rev-parse --show-toplevel)

in_test_tree() { case "/$1" in */tests/*) return 0 ;; esac; return 1; }

# A test file by the runner's naming rule, inside a tests tree: the same name
# elsewhere (jaclang/testing/test_runner.jac, examples) is not test-only.
is_test_name() {
  in_test_tree "$1" || return 1
  case "$(basename "$1")" in
    test_*.jac | *.test.jac) return 0 ;;
  esac
  return 1
}

under_fixtures() {
  in_test_tree "$1" || return 1
  case "/$1" in */fixtures/*) return 0 ;; esac
  return 1
}

# Test files under a directory, outside fixtures.
tests_under() {
  git -C "$root" ls-files -- "$1" | while IFS= read -r f; do
    if is_test_name "$f" && ! under_fixtures "$f"; then printf '%s\n' "$f"; fi
  done
}

# Module names on the changed lines of an archwire.jac edit, with imported
# symbol lists ({ ... }) dropped. Blank and punctuation-only lines name none.
archwire_modules() {
  git -C "$root" diff --unified=0 "$1" "$2" -- jac/jaclang/archwire.jac |
    awk '/^(\+\+\+|---)/ { next }
         /^[+-]/ {
           line = substr($0, 2)
           gsub(/\{[^}]*\}/, " ", line)
           sub(/\{.*/, " ", line)
           n = split(line, tok, /[^A-Za-z0-9_.]+/)
           for (i = 1; i <= n; i++) if (tok[i] != "") print tok[i]
         }'
}

# The tests an archwire edit can reach. Every module named on a changed line
# must resolve only to files inside a tests tree: a test module selects
# itself, a test helper selects the tests of its tree. Anything else -- a
# symbol line, a source module, a keyword, a name with no file -- fails, and
# the caller picks the full suite.
archwire_tests() {
  local mod leaf files f
  while IFS= read -r mod; do
    leaf=${mod##*.}
    files=$(git -C "$root" ls-files -- "*/$leaf.jac")
    [ -n "$files" ] || return 1
    while IFS= read -r f; do
      in_test_tree "$f" || return 1
      if is_test_name "$f"; then
        printf '%s\n' "$f"
      else
        tests_under "$(dirname "$f")"
      fi
    done <<<"$files"
  done < <(archwire_modules "$1" "$2")
}

# Tests that a fixture change can reach: test files naming the fixture's stem,
# or every test in the tree of a helper that names it.
fixture_tests() {
  local path=$1 stem dir hits hit
  stem=$(basename "$path" .jac)
  dir=${path%%/fixtures/*}
  if [ ${#stem} -lt 4 ]; then tests_under "$dir"; return; fi
  hits=$(git -C "$root" grep -l -F -- "$stem" -- 'jac/*.jac' ':!*/fixtures/*' || true)
  if [ -z "$hits" ]; then tests_under "$dir"; return; fi
  while IFS= read -r hit; do
    if is_test_name "$hit"; then
      printf '%s\n' "$hit"
    else
      tests_under "$(dirname "$hit")"
    fi
  done <<<"$hits"
}

# Tests that import a changed test file: a test_* file can be a shared helper
# (tests/client/test_helpers.jac), so its importers run with it. A non-test
# file naming it selects that file's test tree; archwire.jac lists test
# modules as wiring targets, not importers, and is left out.
test_dependents() {
  local path=$1 stem hit
  stem=$(basename "$path" .jac)
  { git -C "$root" grep -l -w -F -- "$stem" -- 'jac/*.jac' ':!*/fixtures/*' ':!jac/jaclang/archwire.jac' || true; } |
    while IFS= read -r hit; do
      [ "$hit" = "$path" ] && continue
      if is_test_name "$hit"; then
        printf '%s\n' "$hit"
      elif in_test_tree "$hit"; then
        tests_under "$(dirname "$hit")"
      fi
    done
}

scope() {
  local base=$1 head=$2 status old new path wired selected=""
  while IFS=$'\t' read -r status old new; do
    [ -n "$old" ] || continue
    # A rename is judged on both sides: moving source into a tests tree
    # still removes it from where it was.
    for path in "$old" ${new:+"$new"}; do
      case "$path" in
        release_notes/*) continue ;;
        jac/* | jac.toml | .github/workflows/ci.yml | .github/workflows/build-binaries.yml | \
          .github/actions/* | .github/ci/* | scripts/ci_* | scripts/test_ci_*) ;;
        *) continue ;;
      esac
      case "$path" in
        jac/jaclang/archwire.jac)
          if wired=$(archwire_tests "$base" "$head"); then
            selected+="$wired"$'\n'
            continue
          fi
          echo "scope=full"; return ;;
      esac
      if under_fixtures "$path"; then
        selected+=$(fixture_tests "$path")$'\n'
      elif is_test_name "$path"; then
        if [ -e "$root/$path" ]; then selected+="$path"$'\n'; fi
        selected+=$(test_dependents "$path")$'\n'
      else
        echo "scope=full"; return
      fi
    done
  done < <(git -C "$root" diff --name-status -M "$base" "$head")
  echo "scope=tests"
  printf '%s' "$selected" | awk 'NF && !seen[$0]++' | while IFS= read -r f; do
    if [ -e "$root/$f" ]; then printf '%s\n' "$f"; fi
  done
}

plan() {
  local lanes base=${2:-} head=${3:-} out scope_name selected=""
  lanes="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  scope_name=full
  if [ -n "$base" ]; then
    out=$(scope "$base" "$head")
    scope_name=$(head -n 1 <<<"$out" | cut -d= -f2)
    selected=$(tail -n +2 <<<"$out")
  fi
  SCOPE=$scope_name SELECTED=$selected python3 - "$lanes" "$root/jac" <<'PY'
import fnmatch, json, os, subprocess, sys

cat = json.load(open(sys.argv[1]))
tracked = subprocess.run(
    ["git", "ls-files", "--", *cat["test_roots"]],
    cwd=sys.argv[2], capture_output=True, text=True, check=True
).stdout.split()

def is_test(path):
    parts = path.split("/")
    name = parts[-1]
    if "fixtures" in parts[:-1]:
        return False
    return (name.startswith("test_") and name.endswith(".jac")) or name.endswith(".test.jac")

tests = sorted(p for p in tracked if is_test(p))

def owns(pattern, path):
    if any(c in pattern for c in "*?["):
        return fnmatch.fnmatchcase(path, pattern) and "/" not in path[len(os.path.dirname(pattern)) + 1:]
    return path == pattern or path.startswith(pattern.rstrip("/") + "/")

owner = {}
lane_files = {}
for lane in cat["lanes"]:
    files = [
        t for t in tests
        if any(owns(p, t) for p in lane["paths"])
        and not any(owns(i, t) for i in lane.get("ignore", []))
    ]
    lane_files[lane["name"]] = files
    for f in files:
        owner.setdefault(f, []).append(lane["name"])

problems = [f"{f} is in lanes {', '.join(o)}" for f, o in owner.items() if len(o) > 1]
excluded = cat.get("excluded", {})
problems += [f"{t} belongs to no lane in .github/ci/lanes.json" for t in tests if t not in owner and t not in excluded]
if problems:
    sys.exit("ci_plan: " + "\n".join(problems))

wanted = None
if os.environ.get("SCOPE") == "tests":
    wanted = {l[len("jac/"):] for l in os.environ.get("SELECTED", "").split("\n") if l.startswith("jac/")}

matrix = []
for lane in cat["lanes"]:
    files = lane_files[lane["name"]]
    if wanted is not None:
        files = [f for f in files if f in wanted]
    if not files:
        continue
    specs = [s for d in lane.get("deps", []) for s in cat["deps"][d]]
    matrix.append({
        "name": lane["name"],
        "files": " ".join(files),
        "count": len(files),
        "jobs": lane.get("jobs", "auto"),
        "filter": lane.get("filter", ""),
        "deps": "\n".join(specs),
        "node": bool(lane.get("node")),
        "bun": bool(lane.get("bun")),
        "zig": bool(lane.get("zig")),
        "home": bool(lane.get("home")),
        "xdg": bool(lane.get("xdg")),
        "iface_verify": "1" if lane.get("iface_verify") else "",
        "submodules": bool(lane.get("submodules")),
        "artifacts": bool(lane.get("artifacts")),
    })
print(json.dumps(matrix, separators=(",", ":")))
PY
}

case "${1:-}" in
  scope) shift; scope "$@" ;;
  plan) shift; plan "$@" ;;
  *) echo "usage: $0 scope <base> <head> | plan <lanes.json> [<base> <head>]" >&2; exit 2 ;;
esac
