#!/usr/bin/env bash
# The release tag names one commit, and it never comes to name another.
#
# Usage: release_tag_guard.sh <version> <commit-sha> [remote]
#
#   no tag yet          -> create the annotated tag at <commit-sha> and push it
#   tag on <commit-sha> -> nothing to do; a recovery re-run converges
#   tag on some other   -> refuse, naming both commits
#
# The refusal is the whole point. Before it existed, "the tag already exists"
# was reported as success, and the build that followed checked out the tag --
# so re-cutting a version rebuilt whatever that tag still pointed at. The
# v0.37.0 re-run shipped a five-day-old tree that way and failed on a bug the
# approved commit had already fixed (#8793). A build that succeeded would have
# published binaries that did not correspond to the commit under review.
#
# Peeling matters: release tags are annotated, so `git ls-remote`'s first
# column is the tag OBJECT, not the commit. Comparing that against a commit
# never matches. The `^{}` entry is the commit, and asking for it explicitly
# is what makes the comparison mean anything.

set -euo pipefail

VERSION="${1:-}"
COMMIT="${2:-}"
REMOTE="${3:-origin}"
VTAG="v${VERSION}"

fail() {
    echo "::error::$1"
    shift
    [ "$#" -eq 0 ] || printf '%s\n' "$@"
    exit 1
}

[ -n "$VERSION" ] || fail "release_tag_guard.sh: no version given."

# A short or empty sha means the caller could not name the commit being
# released (an unresolved merge_commit_sha, say). Tagging something anyway is
# how a release ends up describing a tree nobody approved.
if [[ ! "$COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
    fail "release_tag_guard.sh: '${COMMIT}' is not a full commit sha, so there is no commit to release." \
        "The caller must pass the 40-character sha of the commit being released." \
        "Nothing was tagged."
fi

if ! listing="$(git ls-remote --tags "$REMOTE" \
    "refs/tags/${VTAG}" "refs/tags/${VTAG}^{}" 2>&1)"; then
    fail "Could not query ${REMOTE} for ${VTAG}: ${listing}"
fi

plain=""
peeled=""
while IFS=$'\t' read -r sha ref; do
    case "$ref" in
        "refs/tags/${VTAG}^{}") peeled="$sha" ;;
        "refs/tags/${VTAG}") plain="$sha" ;;
    esac
done <<<"$listing"

# Annotated tags carry both entries; the peel is the commit. A lightweight tag
# has only the plain entry, which already is the commit.
existing="${peeled:-$plain}"

if [ -z "$existing" ]; then
    if ! git rev-parse --verify --quiet "${COMMIT}^{commit}" >/dev/null; then
        git fetch --no-tags --quiet "$REMOTE" "$COMMIT" 2>/dev/null || true
    fi
    if ! git rev-parse --verify --quiet "${COMMIT}^{commit}" >/dev/null; then
        fail "The commit being released (${COMMIT}) is not in this checkout and could not be fetched from ${REMOTE}." \
            "Nothing was tagged."
    fi
    echo "Tagging ${VTAG} at ${COMMIT}"
    # --force only ever retargets a LOCAL tag, and only on the branch where the
    # remote has none: a stale tag left by an earlier fetch must not make the
    # release die on "tag already exists". The push below is not forced, so
    # nothing published can move.
    git tag --annotate --force --message="jac ${VERSION}" "$VTAG" "$COMMIT"
    git push "$REMOTE" "refs/tags/${VTAG}"
    echo "Tagged ${VTAG} at ${COMMIT} and pushed it to ${REMOTE}."
    exit 0
fi

if [ "$existing" = "$COMMIT" ]; then
    echo "Tag ${VTAG} already points at ${COMMIT}; leaving it in place."
    exit 0
fi

# Never move an existing tag: a published release's assets and notes describe
# the commit it was cut from, and install.sh hands users exactly those assets.
# So the tag stays, and the release stops here.
fail "Refusing to release ${VTAG}: the tag already exists and points at a different commit." \
    "" \
    "  tag ${VTAG} resolves to: ${existing}" \
    "  this release is cutting: ${COMMIT}" \
    "" \
    "The tag has NOT been moved. Building it anyway would ship a tree nobody" \
    "approved under a version that claims otherwise." \
    "" \
    "Two ways forward:" \
    "" \
    "  1. Bump the version and release that instead. This is the answer" \
    "     whenever ${VTAG} was ever published: its assets and notes describe" \
    "     ${existing}, and users who already installed it keep that build." \
    "" \
    "  2. If ${VTAG} was never published (its GitHub Release is still a draft," \
    "     with no assets attached), retire the stale tag and its draft, then" \
    "     re-run this release:" \
    "" \
    "       gh release delete ${VTAG} --cleanup-tag --yes"
