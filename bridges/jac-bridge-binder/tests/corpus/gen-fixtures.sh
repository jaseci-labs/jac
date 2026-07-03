#!/usr/bin/env bash
# Generate rustdoc JSON fixtures for the binder corpus.
# Run once after checking out; CI pins these files in tests/fixtures/.
#
# Usage: bash tests/corpus/gen-fixtures.sh [crate@version ...]
# Default: generates all entries in CRATES below.
#
# Requires: cargo, rustup with a nightly toolchain installed.

set -euo pipefail

FIXTURES_DIR="$(dirname "$0")/../fixtures"
NIGHTLY="nightly"

CRATES=(
    "regex@1.12.4"
    "uuid@1.17.0"
    "sha2@0.10.9"
    "base64@0.22.1"
    "chrono@0.4.41"
)

targets=("${@:-${CRATES[@]}}")

for entry in "${targets[@]}"; do
    crate="${entry%@*}"
    version="${entry#*@}"
    fixture="${FIXTURES_DIR}/${crate}-${version}.json"

    if [[ -f "$fixture" ]]; then
        echo "skip  $fixture (exists)"
        continue
    fi

    echo "gen   $crate $version → $fixture"

    # Fetch source into cargo registry if not already present.
    cargo fetch --quiet 2>/dev/null || true

    src_dir=$(find ~/.cargo/registry/src -maxdepth 2 -type d -name "${crate}-${version}" 2>/dev/null | head -1)
    if [[ -z "$src_dir" ]]; then
        echo "  → downloading via 'cargo add' in a temp project"
        tmp=$(mktemp -d)
        trap "rm -rf $tmp" EXIT
        cd "$tmp"
        # Explicit --name: the mktemp dir name can contain `.`, which cargo
        # rejects as a package name.
        cargo init --lib --quiet --name fixturegen
        cargo add "${crate}@${version}" --quiet
        cargo fetch --quiet
        src_dir=$(find ~/.cargo/registry/src -maxdepth 2 -type d -name "${crate}-${version}" 2>/dev/null | head -1)
        cd - >/dev/null
    fi

    if [[ -z "$src_dir" ]]; then
        echo "  ERROR: could not locate source for ${crate}-${version}" >&2
        exit 1
    fi

    cargo +"$NIGHTLY" rustdoc \
        -Z unstable-options \
        --output-format json \
        --manifest-path "${src_dir}/Cargo.toml" \
        --quiet 2>/dev/null

    cp "${src_dir}/target/doc/${crate}.json" "$fixture"
    echo "  → wrote $fixture"
done

echo "done"
