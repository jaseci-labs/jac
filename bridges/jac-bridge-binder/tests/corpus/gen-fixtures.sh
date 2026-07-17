#!/usr/bin/env bash
# Generate rustdoc JSON fixtures for the binder corpus.
# Run once after checking out; CI pins these files in tests/fixtures/.
#
# Usage: bash tests/corpus/gen-fixtures.sh [crate@version[:feat1,feat2] ...]
# Default: generates all entries in CRATES below.
#
# An entry may carry an optional `:features` suffix (a comma-separated cargo
# feature list, NOT `--all-features` -- chrono's rkyv size features are mutually
# exclusive and break the build). A featured entry is rendered with those crate
# features enabled (so its optional serde impls appear) and, because it carries a
# different feature set than the default-feature corpus, is written to a
# feature-named subdirectory (`serde/chrono-0.4.45-serde.json`) that the corpus
# glob (`corpus.rs`, non-recursive `*.json`) deliberately does NOT pick up -- a
# featured fixture would otherwise shift the default coverage baseline.
#
# Requires: cargo, rustup with a nightly toolchain installed.

set -euo pipefail

FIXTURES_DIR="$(dirname "$0")/../fixtures"
NIGHTLY="nightly"

CRATES=(
    "regex@1.12.4"
    "uuid@1.23.4"
    "sha2@0.11.0"
    "base64@0.22.1"
    "chrono@0.4.45"
    # A real derived-serde data crate (Phase 2.10). Default features (no serde
    # feature needed -- semver's serde impls are hand-written, so enabling serde
    # does not change coverage): guards serde DETECTION and the manual-impl gate
    # on genuine rustdoc JSON. Reaches 50% via the opaque lane, not the wide lane.
    "semver@1.0.27"
    # Feature-enabled fixtures (2.4 wide lane): serde impls are optional deps,
    # off by default, so the default-feature fixtures above contain ZERO serde
    # impls. These drive the binder serde-detection tests.
    "chrono@0.4.45:serde"
    "uuid@1.23.4:serde"
)

targets=("${@:-${CRATES[@]}}")

for entry in "${targets[@]}"; do
    crate="${entry%@*}"
    rest="${entry#*@}"           # version[:feat1,feat2]
    version="${rest%%:*}"
    if [[ "$rest" == *:* ]]; then
        features="${rest#*:}"
    else
        features=""
    fi

    if [[ -n "$features" ]]; then
        feat_slug="${features//,/_}"
        out_dir="${FIXTURES_DIR}/${feat_slug}"
        fixture="${out_dir}/${crate}-${version}-${feat_slug}.json"
        feat_args=(--features "$features")
        add_feat_args=(--features "$features")
        mkdir -p "$out_dir"
    else
        fixture="${FIXTURES_DIR}/${crate}-${version}.json"
        feat_args=()
        add_feat_args=()
    fi

    if [[ -f "$fixture" ]]; then
        echo "skip  $fixture (exists)"
        continue
    fi

    echo "gen   $crate $version ${features:+[$features] }→ $fixture"

    # Fetch source into cargo registry if not already present. A featured build
    # needs its optional dependencies (e.g. serde) fetched too, so when features
    # are requested we always route through the temp `cargo add --features`
    # project rather than relying on a possibly feature-less registry checkout.
    cargo fetch --quiet 2>/dev/null || true

    src_dir=""
    if [[ -z "$features" ]]; then
        src_dir=$(find ~/.cargo/registry/src -maxdepth 2 -type d -name "${crate}-${version}" 2>/dev/null | head -1)
    fi
    if [[ -z "$src_dir" ]]; then
        echo "  → downloading via 'cargo add' in a temp project"
        tmp=$(mktemp -d)
        trap "rm -rf $tmp" EXIT
        cd "$tmp"
        # Explicit --name: the mktemp dir name can contain `.`, which cargo
        # rejects as a package name.
        cargo init --lib --quiet --name fixturegen
        cargo add "${crate}@${version}" "${add_feat_args[@]}" --quiet
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
        "${feat_args[@]}" \
        --quiet 2>/dev/null

    cp "${src_dir}/target/doc/${crate}.json" "$fixture"
    echo "  → wrote $fixture"
done

echo "done"
