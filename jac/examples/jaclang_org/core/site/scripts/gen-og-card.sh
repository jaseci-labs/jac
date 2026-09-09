#!/usr/bin/env bash
# Regenerates the raster social card (og:image / twitter:image) from the
# site's vector assets. Run at deploy time; the committed PNG is this
# script's output, never hand-edited.
#
#   core/site/scripts/gen-og-card.sh
set -euo pipefail
cd "$(dirname "$0")"
jac browse -s og-card -v 1200x630 open "file://$(pwd)/og-card.html"
jac browse -s og-card screenshot ../assets/og-card.png
jac browse -s og-card close
echo "wrote assets/og-card.png"
