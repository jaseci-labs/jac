#!/usr/bin/env bash
# A release becomes "latest" only once it carries every binary it is required
# to carry, and it publishes without the ones it is not.
#
# Usage: release_publish_guard.sh <version> <required-platform>...
# Each required suffix identifies a compiler variant, e.g. linux-x86_64 or
# linux-x86_64-jacpython; build-binaries.yml emits both from its build matrix.
#
#   every required asset attached -> flip the draft to published
#   a required asset missing      -> refuse; the draft stays a draft
#   a platform not on the list    -> ignored; the release publishes without it
#
# The platform list comes from build-binaries.yml's `plan` job, which derives it
# from the same array the build matrix comes from. That is the point: `publish`
# used to restate the list inline, under a comment asking whoever edited one
# copy to remember the other. A leg that stops being required in the matrix
# would still have been demanded here, and the release would have hung on an
# asset nothing was building any more.
#
# Refusing matters as much as publishing. install.sh resolves whatever
# /releases/latest points at, so revealing a draft that is missing a binary
# hands that platform's users a release they cannot install from.
#
# RELEASE_ASSET_TIMEOUT / RELEASE_ASSET_POLL tune the poll that absorbs the
# few-second lag between an upload and the assets API reporting it.

set -euo pipefail

VERSION="${1:-}"
[ "$#" -eq 0 ] || shift
REQUIRED_COUNT="$#"
REQUIRED=("$@")

TIMEOUT="${RELEASE_ASSET_TIMEOUT:-120}"
POLL="${RELEASE_ASSET_POLL:-5}"

fail() {
    echo "::error::$1"
    shift
    [ "$#" -eq 0 ] || printf '%s\n' "$@"
    exit 1
}

[ -n "$VERSION" ] || fail "release_publish_guard.sh: no version given."

# An empty list would make every check below vacuous and publish whatever the
# draft happens to hold, including nothing at all. The caller losing the list
# is a wiring bug, not a green release.
[ "$REQUIRED_COUNT" -gt 0 ] || fail \
    "release_publish_guard.sh: no required platforms given, so there is nothing to verify." \
    "The caller must pass the platform list build-binaries.yml's \`plan\` job emits" \
    "as its \`required_platforms\` output. Publishing against an empty list would" \
    "reveal a release without checking that anything is attached to it." \
    "Nothing was published."

VTAG="v${VERSION}"

echo "Required for ${VTAG}: ${REQUIRED[*]}"

deadline=$(( SECONDS + TIMEOUT ))
while :; do
    # 2>&1 folds gh's error text into $assets on failure, so a transient
    # release-API error (auth/throttle) is reported as such instead of being
    # mistaken for assets that are genuinely still missing.
    if ! assets="$(gh release view "$VTAG" --json assets --jq '.assets[].name' 2>&1)"; then
        if [ "$SECONDS" -ge "$deadline" ]; then
            fail "Could not query $VTAG assets within ${TIMEOUT}s (last error: ${assets})" \
                "Nothing was published."
        fi
        echo "release view failed, will retry: ${assets}"
        sleep "$POLL"
        continue
    fi

    missing=""
    for p in "${REQUIRED[@]}"; do
        printf '%s\n' "$assets" | grep -qxF "jac-${VERSION}-${p}" \
            || missing="${missing} jac-${VERSION}-${p}"
    done
    missing="${missing# }"

    if [ -z "$missing" ]; then
        break
    fi
    if [ "$SECONDS" -ge "$deadline" ]; then
        fail "Draft $VTAG is still missing after ${TIMEOUT}s: ${missing}; refusing to publish." \
            "" \
            "These platforms are required, so a release without them would hand" \
            "their users a \`latest\` they cannot install from. The draft has NOT" \
            "been published and can be re-run once the missing legs upload." \
            "" \
            "If a platform is expected to be absent for a while, mark its leg" \
            "\`\"optional\": true\` in the \`plan\` job of" \
            ".github/workflows/build-binaries.yml. That drops it from this list" \
            "and from the matrix's blocking set in one edit."
    fi
    echo "Waiting for assets: ${missing}"
    sleep "$POLL"
done

# What the release actually ships, named out loud: a platform that quietly went
# missing is the thing this whole gate exists to make visible.
shipped="$(printf '%s\n' "$assets" \
    | grep -E "^jac-${VERSION}-[a-z0-9_-]+$" \
    | sed "s/^jac-${VERSION}-//" \
    | sort \
    | tr '\n' ' ' || true)"
echo "Platform binaries attached to ${VTAG}: ${shipped:-none}"

is_draft="$(gh release view "$VTAG" --json isDraft --jq '.isDraft' 2>/dev/null || echo true)"
if [ "$is_draft" != "true" ]; then
    echo "$VTAG is already published; leaving the latest pointer untouched."
    exit 0
fi

# `--latest` must never move backwards: install.sh resolves latest, so a re-run
# or a backport release (0.34.8 after 0.35.0) would silently downgrade users.
# The draft is invisible to /releases/latest, so whatever that reports now is
# the published newest.
if [ -n "${GH_REPO:-}" ]; then
    latest_endpoint="repos/${GH_REPO}/releases/latest"
else
    latest_endpoint="repos/{owner}/{repo}/releases/latest"
fi
latest_tag="$(gh api "$latest_endpoint" --jq .tag_name 2>/dev/null || echo "")"
if [ "$(printf '%s\n%s\n' "${latest_tag#v}" "$VERSION" | sort -V | tail -1)" = "$VERSION" ]; then
    latest_flag="--latest"
else
    latest_flag="--latest=false"
    echo "Backport: ${latest_tag} stays latest, ${VTAG} publishes without the pointer."
fi

gh release edit "$VTAG" \
    --verify-tag \
    --draft=false \
    "$latest_flag"
echo "Published ${VTAG} (${latest_flag}) with every required binary attached."
