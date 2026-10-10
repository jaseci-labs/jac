#!/usr/bin/env bash
# Vendor a minimal IANA tzdata snapshot for js_engine Temporal tests.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/share/tzdata"
mkdir -p "$DEST"

minimal="${1:-}"
if [[ "${minimal}" == "--minimal" ]] || [[ "${minimal}" == "-m" ]]; then
  # UTC + one DST zone used heavily in test262.
  printf 'TZif2\n\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\nUTC0\n' > "$DEST/UTC"
  cp "$DEST/UTC" "$DEST/Factory"
  # America/New_York: copy from system zoneinfo when present, else UTC fallback.
  if [[ -f /usr/share/zoneinfo/America/New_York ]]; then
    cp /usr/share/zoneinfo/America/New_York "$DEST/America/New_York" 2>/dev/null || {
      mkdir -p "$DEST/America"
      cp /usr/share/zoneinfo/America/New_York "$DEST/America/New_York"
    }
  else
    mkdir -p "$DEST/America"
    cp "$DEST/UTC" "$DEST/America/New_York"
  fi
  echo "Installed minimal tzdata into $DEST"
  exit 0
fi

if command -v curl >/dev/null 2>&1; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  VER="${TZDATA_VERSION:-2025b}"
  URL="https://data.iana.org/time-zones/releases/tzdata${VER}.tar.gz"
  echo "Fetching $URL"
  curl -fsSL "$URL" -o "$TMP/tzdata.tar.gz"
  tar -xzf "$TMP/tzdata.tar.gz" -C "$TMP"
  mkdir -p "$DEST"
  cp -a "$TMP"/{Africa,Antarctica,Arctic,Asia,Atlantic,Australia,Europe,Indian,Pacific,etc} "$DEST/" 2>/dev/null || true
  cp "$TMP"/zone1970.tab "$DEST/" 2>/dev/null || true
  cp "$TMP"/iso3166.tab "$DEST/" 2>/dev/null || true
  echo "Installed full tzdata into $DEST"
else
  echo "curl not found; installing minimal tzdata" >&2
  exec "$0" --minimal
fi
