#!/usr/bin/env bash
# Bump the pinned typeshed commit and refresh the vendored stdlib stubs.
#
# Thin wrapper over fetch-typeshed.sh (which materializes the gitignored stdlib
# stubs). This just moves the PIN and rewrites PROVENANCE.md -- the only two
# tracked files that change on a bump.
#
#   launcher/update-typeshed.sh <commit-ish>     # e.g. a typeshed main commit SHA
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR="$SCRIPT_DIR/../jaclang/vendor/typeshed"

REF="${1:-}"
[ -n "$REF" ] || { echo "update-typeshed: usage: update-typeshed.sh <commit-ish>" >&2; exit 1; }

echo "==> materializing typeshed stdlib @ $REF"
rm -f "$VENDOR/stdlib/.typeshed-sha"      # force a fresh fetch even if unchanged
bash "$SCRIPT_DIR/fetch-typeshed.sh" "$REF"
SHA="$(cat "$VENDOR/stdlib/.typeshed-sha")"

echo "$SHA" > "$VENDOR/PIN"
cat > "$VENDOR/PROVENANCE.md" <<EOF
# Vendored typeshed (stdlib stubs only)

The Python standard-library type stubs from typeshed. They are NOT committed:
\`stdlib/\` is gitignored and rebuilt at the pinned commit by
\`launcher/fetch-typeshed.sh\` (which \`build.zig\` runs so the \`jac\` binary bundles
the stubs). Only this file, \`PIN\`, and \`LICENSE\` are tracked.

Third-party stubs are NOT shipped: install the matching \`types-*\` package
yourself (\`jac add types-foo\`); it is resolved via PEP 561 \`<pkg>-stubs\` from
the project venv.

- Source:  https://github.com/python/typeshed
- Commit:  $SHA
- License: Apache-2.0 (see LICENSE)

To bump, run \`launcher/update-typeshed.sh <commit>\` and commit PIN + PROVENANCE.md.
EOF

echo "==> typeshed pinned to $SHA"
echo "==> commit: $VENDOR/PIN $VENDOR/PROVENANCE.md"
