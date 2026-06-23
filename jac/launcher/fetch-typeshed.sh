#!/usr/bin/env bash
# Materialize the vendored typeshed *stdlib* stubs into jaclang/vendor/typeshed/
# by shallow-fetching python/typeshed at the pinned commit. The stubs are NOT
# committed (gitignored); the build runs this (via build.zig) so the binary
# bundles them, and you run it once locally to enable from-source `jac check` /
# the test suite. Idempotent: a no-op when the stubs already match the pin.
#
# Integrity comes from git's content-addressing (we fetch an exact commit SHA),
# so no separate checksum is needed -- unlike GitHub archive tarballs, which are
# not byte-stable.
#
#   launcher/fetch-typeshed.sh [<commit-ish>]   # default: the PIN file
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR="$SCRIPT_DIR/../jaclang/vendor/typeshed"
REPO="https://github.com/python/typeshed"

REF="${1:-}"
[ -n "$REF" ] || REF="$(tr -d '[:space:]' < "$VENDOR/PIN" 2>/dev/null || true)"
[ -n "$REF" ] || { echo "fetch-typeshed: no commit given and no PIN file at $VENDOR/PIN" >&2; exit 1; }

# The stdlib stubs are gitignored, derived artifacts; (re)materialize them
# unless already present at the pin.
stamp="$VENDOR/stdlib/.typeshed-sha"
if [ -f "$VENDOR/stdlib/VERSIONS" ] && [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$REF" ]; then
  exit 0   # already materialized at the pinned commit
fi

command -v git >/dev/null 2>&1 || { echo "fetch-typeshed: git required" >&2; exit 1; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
echo "fetch-typeshed: fetching typeshed @ $REF"
git -C "$WORK" init -q
git -C "$WORK" remote add origin "$REPO"
git -C "$WORK" fetch -q --depth 1 origin "$REF"
git -C "$WORK" checkout -q FETCH_HEAD
SHA="$(git -C "$WORK" rev-parse HEAD)"

# stdlib stubs -> shipped in the binary
rm -rf "$VENDOR/stdlib"
cp -R "$WORK/stdlib" "$VENDOR/stdlib"
rm -rf "$VENDOR/stdlib/@tests"        # typeshed's own test suite -- not shipped
cp "$WORK/LICENSE" "$VENDOR/LICENSE"
echo "$SHA" > "$stamp"

echo "fetch-typeshed: ready ($(find "$VENDOR/stdlib" -name '*.pyi' | wc -l | tr -d ' ') stdlib stubs)"
