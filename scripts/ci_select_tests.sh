#!/usr/bin/env bash
# Test selection for pull requests.
#
#   ci_select_tests.sh scope <base> <head>
#     Prints `scope=full` or `scope=tests`, then (for `tests`) the selected
#     test files, one per line, relative to the repository root. `tests` is
#     only chosen when every changed path is a test file, a fixture, a release
#     note, or an archwire.jac edit confined to test-module wiring; anything
#     else, or anything this script cannot place, selects the full suite.
#
#   ci_select_tests.sh filter [--ignore "<paths>"] -- <lane paths...>
#     Reads the selected files (repository-relative, one per line) on stdin and
#     prints the ones a lane owns: equal to or under one of its paths and not
#     under an ignored one. Paths resolve against the current directory.
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

scope() {
  local base=$1 head=$2 status old new path wired selected=""
  while IFS=$'\t' read -r status old new; do
    [ -n "$old" ] || continue
    # A rename is judged on both sides: moving source into a tests tree
    # still removes it from where it was.
    for path in "$old" ${new:+"$new"}; do
      case "$path" in
        release_notes/*) continue ;;
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

filter() {
  local ignore="" arg f abs p hit
  if [ "${1:-}" = "--ignore" ]; then ignore=$2; shift 2; fi
  [ "${1:-}" = "--" ] && shift
  local -a owned=() skipped=()
  for arg in "$@"; do owned+=("$(realpath -m "$arg")"); done
  for arg in $ignore; do skipped+=("$(realpath -m "$arg")"); done
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    abs=$(realpath -m "$root/$f")
    hit=""
    for p in "${owned[@]}"; do
      if [ "$abs" = "$p" ] || [[ "$abs" == "$p"/* ]]; then hit=1; break; fi
    done
    [ -n "$hit" ] || continue
    for p in "${skipped[@]+"${skipped[@]}"}"; do
      if [ "$abs" = "$p" ] || [[ "$abs" == "$p"/* ]]; then hit=""; break; fi
    done
    if [ -n "$hit" ]; then realpath -m --relative-to="$PWD" "$abs"; fi
  done
  return 0
}

case "${1:-}" in
  scope) shift; scope "$@" ;;
  filter) shift; filter "$@" ;;
  *) echo "usage: $0 scope <base> <head> | filter [--ignore \"<paths>\"] -- <paths...>" >&2; exit 2 ;;
esac
