#!/usr/bin/env bash
# The kit manifest. Run from jac/ on both sides of the artifact:
#
#   manifest.sh write <kit paths...>   (build-kit, right before the upload)
#   manifest.sh check                  (the jac-kit action, after the download)
#
# `write` hashes every file under the kit paths into zig-out/kit.sha256 and
# hashes that file into zig-out/kit.sha256.sha256, so a manifest cut short by
# the same truncation it exists to catch cannot vouch for the files after it.
# `check` verifies both, strictly: a short, unreadable, or improperly
# formatted line fails the check instead of warning past it.
set -euo pipefail

if command -v sha256sum >/dev/null 2>&1; then
  SUM=(sha256sum)
else
  SUM=(shasum -a 256)
fi
MANIFEST=zig-out/kit.sha256

case "${1:-}" in
  write)
    shift
    [ $# -gt 0 ] || { echo "manifest.sh write: no kit paths given" >&2; exit 2; }
    find "$@" -type f -print0 | LC_ALL=C sort -z | xargs -0 "${SUM[@]}" > "$MANIFEST"
    "${SUM[@]}" "$MANIFEST" > "$MANIFEST.sha256"
    echo "kit manifest: $(wc -l < "$MANIFEST" | tr -d ' ') files"
    ;;
  check)
    "${SUM[@]}" --strict --quiet -c "$MANIFEST.sha256"
    "${SUM[@]}" --strict --quiet -c "$MANIFEST"
    echo "kit verified: $(wc -l < "$MANIFEST" | tr -d ' ') files"
    ;;
  *)
    echo "usage: manifest.sh write <kit paths...> | check" >&2
    exit 2
    ;;
esac
