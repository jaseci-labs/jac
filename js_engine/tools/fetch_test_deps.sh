#!/usr/bin/env bash
# Fetch the external test sources at the commits the baselines were recorded
# against (they were git submodules before js_engine moved into the jac repo).
#   tools/fetch_test_deps.sh            # all three
#   tools/fetch_test_deps.sh test262    # or any of: test262 node rollup
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fetch() {   # fetch <dir> <url> <commit>
    local dir="$root/$1" url=$2 commit=$3
    if [ -d "$dir/.git" ] && [ "$(git -C "$dir" rev-parse HEAD)" = "$commit" ]; then
        echo "$1: already at $commit"; return
    fi
    rm -rf "$dir"; mkdir -p "$dir"
    git -C "$dir" init -q
    git -C "$dir" remote add origin "$url"
    git -C "$dir" fetch -q --depth 1 origin "$commit"
    git -C "$dir" checkout -q FETCH_HEAD
    echo "$1: $commit"
}

for dep in ${@:-test262 node rollup}; do
    case "$dep" in
        test262) fetch engine/tests/test262/vendor https://github.com/tc39/test262 7ab7fafa0003f73fc85c1b95d88094d33f7eb8bd ;;
        node)    fetch engine/tests/node/vendor https://github.com/nodejs/node.git 9de263aa8831941561f7e29aa1c13b03ceeba878 ;;
        rollup)  fetch apps/rollup/rollup https://github.com/rollup/rollup.git 78bfef0cb94479566f81012fafa372c84b90bd34 ;;
        *) echo "unknown test dependency: $dep (expected test262, node or rollup)" >&2; exit 2 ;;
    esac
done
