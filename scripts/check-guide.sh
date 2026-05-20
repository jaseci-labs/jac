#!/usr/bin/env bash
# Smoke-test `jac guide` against a freshly installed/built jac.
#
# Usage: check-guide.sh <jac-command>
#   e.g. check-guide.sh jac
#        check-guide.sh ./jac-test-binary
#
# Verifies the bundled reference guides ship with the wheel/binary and
# print as expected: the listing, a single guide body, JSON output, and
# the non-zero exit on an unknown topic.
set -euo pipefail

JAC="${1:?usage: check-guide.sh <jac-command>}"

fail() { echo "FAIL: $1"; exit 1; }

# --- jac guide: the listing ---
LIST="$("$JAC" guide)"
echo "$LIST" | grep -q "Jac reference guides" || fail "guide listing header missing"
echo "$LIST" | grep -q "jac-types" || fail "'jac-types' not in guide listing"
echo "$LIST" | grep -q "jac-core-cheatsheet" || fail "'jac-core-cheatsheet' not in guide listing"

# --- jac guide <topic>: a single guide body ---
BODY="$("$JAC" guide jac-types)"
[ "${#BODY}" -gt 200 ] || fail "'jac guide jac-types' body is too short (${#BODY} chars)"
case "$(echo "$BODY" | sed -e 's/^[[:space:]]*//' | head -c 3)" in
  "---") fail "'jac guide jac-types' leaked raw frontmatter" ;;
esac

# --- jac guide --json: a parseable guide list ---
"$JAC" guide --json | python3 -c '
import json, sys
guides = json.load(sys.stdin)
assert isinstance(guides, list), "guide --json must emit a list"
assert len(guides) >= 19, f"expected >= 19 guides, got {len(guides)}"
assert all("name" in g and "description" in g for g in guides), "a guide entry is missing name/description"
' || fail "'jac guide --json' did not emit a valid guide list"

# --- jac guide <unknown>: must exit non-zero ---
if "$JAC" guide does-not-exist >/dev/null 2>&1; then
  fail "'jac guide' on an unknown topic should exit non-zero"
fi

echo "PASS: jac guide prints as expected ($JAC)"
