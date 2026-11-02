#!/usr/bin/env bash
# Fetch a test suite js_engine is checked against, at its pinned commit.
#
#   tools/fetch_test_deps.sh test262
#
# test262 goes to engine/tests/test262/vendor (gitignored) at the commit in
# engine/tests/test262/test262.sha, fetched alone (depth 1, about 50 MB instead
# of the full history). An existing checkout already at that commit is left as
# is; one at another commit is moved to it.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fetch_test262() {
    local dir="$root/engine/tests/test262/vendor"
    local pin_file="$root/engine/tests/test262/test262.sha"
    local sha
    sha="$(grep -v '^#' "$pin_file" | tr -d '[:space:]')"
    if [ -z "$sha" ]; then
        echo "fetch_test_deps: no commit in $pin_file" >&2
        exit 1
    fi
    if [ -e "$dir" ] && [ ! -d "$dir/.git" ]; then
        echo "fetch_test_deps: $dir exists but is not a git checkout; remove it and rerun" >&2
        exit 1
    fi
    if [ -d "$dir/.git" ] && [ "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" = "$sha" ]; then
        echo "test262 already at $sha"
        return
    fi
    if [ ! -d "$dir/.git" ]; then
        git init -q "$dir"
        git -C "$dir" remote add origin https://github.com/tc39/test262.git
    fi
    git -C "$dir" fetch -q --depth 1 origin "$sha"
    git -C "$dir" checkout -q --detach FETCH_HEAD
    echo "test262 at $sha"
}

case "${1:-}" in
    test262) fetch_test262 ;;
    *)
        echo "usage: $0 test262" >&2
        exit 2
        ;;
esac
