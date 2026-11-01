#!/usr/bin/env bash
# Fails when a tracked file names stock CPython as a build or runtime
# dependency. The patterns and the exemptions live in
# scripts/no_stock_cpython.allow.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
rules=scripts/no_stock_cpython.allow
deny=()
paths=()
lines=()
while IFS= read -r raw || [ -n "$raw" ]; do
  case "$raw" in '' | '#'*) continue ;; esac
  kind=${raw%%[[:space:]]*}
  value=${raw#"$kind"}
  value=${value#"${value%%[![:space:]]*}"}
  case "$kind" in
    deny) deny+=(-e "$value") ;;
    allow-path) paths+=(":(exclude,glob)$value") ;;
    allow-line) lines+=(-e "$value") ;;
    *)
      echo "$rules: unknown rule '$kind'" >&2
      exit 2
      ;;
  esac
done <"$rules"
[ "${#deny[@]}" -gt 0 ] || {
  echo "$rules: no deny rules" >&2
  exit 2
}
hits=$(git grep -nIE "${deny[@]}" -- . "${paths[@]}" || true)
if [ -n "$hits" ] && [ "${#lines[@]}" -gt 0 ]; then
  hits=$(grep -vE "${lines[@]}" <<<"$hits" || true)
fi
if [ -z "$hits" ]; then
  echo "No tracked file names stock CPython as a build or runtime dependency."
  exit 0
fi
while IFS= read -r hit; do
  file=${hit%%:*}
  rest=${hit#*:}
  line=${rest%%:*}
  echo "::error file=$file,line=$line::names stock CPython as a build or runtime dependency: ${rest#*:}"
done <<<"$hits"
count=$(wc -l <<<"$hits" | tr -d ' ')
echo "$count line(s) name stock CPython as a build or runtime dependency." >&2
echo "JacPython is the only Python. If a line is ABI identity, the pinned source" >&2
echo "archive or history, add it to $rules." >&2
exit 1
