#!/usr/bin/env bash
# Point the jaclang.org deploy branch at a release, once it is the latest one.
#
# Usage: release_site_branch.sh <version>
#
# jaclang.org (jac/examples/jaclang_org) is deployed by jachammer, which
# redeploys on every push to the branch it watches. Watching main would
# redeploy on every merge; this branch moves only here, so the site ships
# exactly once per release:
#
#   v<version> is /releases/latest  -> branch set to the tag's commit
#   anything else (backport, draft)  -> branch left alone
#
# Latest, not "any published release": a backport (0.34.20 after 0.37.21)
# publishes without the latest pointer, and following it would roll the site
# back. Tracking latest keeps the site on the same release install.sh serves.
#
# The branch lives under release/ because the forbid-repo-branches ruleset
# exempts release/**, which is what lets the workflow token create and
# force-move it. Re-running is harmless: a branch already at the commit is
# rewritten to the same SHA and jachammer skips a SHA it has deployed.
#
# SITE_BRANCH overrides the branch name.

set -euo pipefail

VERSION="${1:-}"
BRANCH="${SITE_BRANCH:-release/jaclang-org}"

fail() {
    echo "::error::$1"
    exit 1
}

[ -n "$VERSION" ] || fail "release_site_branch.sh: no version given."

VTAG="v${VERSION}"
if [ -n "${GH_REPO:-}" ]; then
    repo="repos/${GH_REPO}"
else
    repo="repos/{owner}/{repo}"
fi

# A failed lookup is an error, not "not latest": skipping silently would leave
# the site on the previous release with nothing to say why.
latest_tag="$(gh api "${repo}/releases/latest" --jq .tag_name)" \
    || fail "Could not read the latest release; ${BRANCH} was not moved."

if [ "$latest_tag" != "$VTAG" ]; then
    echo "${VTAG} is not the latest release (${latest_tag:-none}); leaving ${BRANCH} alone."
    exit 0
fi

# The tag, not the caller's idea of the commit: release_tag_guard.sh already
# refuses a tag that names anything but the approved commit.
commit="$(gh api "${repo}/commits/${VTAG}" --jq .sha)" \
    || fail "Could not resolve ${VTAG} to a commit; ${BRANCH} was not moved."
printf '%s' "$commit" | grep -Eq '^[0-9a-f]{40}$' \
    || fail "${VTAG} resolved to '${commit}', not a commit SHA; ${BRANCH} was not moved."

if gh api "${repo}/git/ref/heads/${BRANCH}" >/dev/null 2>&1; then
    gh api -X PATCH "${repo}/git/refs/heads/${BRANCH}" \
        -f sha="$commit" -F force=true >/dev/null
    echo "Moved ${BRANCH} to ${VTAG} (${commit})."
else
    gh api -X POST "${repo}/git/refs" \
        -f ref="refs/heads/${BRANCH}" -f sha="$commit" >/dev/null
    echo "Created ${BRANCH} at ${VTAG} (${commit})."
fi
