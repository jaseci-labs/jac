# serde-featured fixtures

rustdoc JSON generated **with serde impls enabled** -- the input for the 2.3
binder serde-detection tests (`classify::serde_lane_tests`). Kept in this
subdirectory (not `tests/fixtures/`) so the corpus glob
(`corpus.rs`, non-recursive `*.json`) does NOT pick them up: they carry a
different feature set than the default-feature corpus fixtures and would shift
its coverage baseline.

## Provenance

`chrono-0.4.45-serde.json` -- chrono at its exact corpus version, built with the
optional `serde` dependency-feature (which is otherwise off by default, so the
default-feature corpus fixture contains ZERO serde impls):

```sh
cargo add chrono@=0.4.45 --features serde    # in a throwaway crate
src=~/.cargo/registry/src/*/chrono-0.4.45
cargo +nightly rustdoc -Z unstable-options --output-format json \
    --manifest-path "$src/Cargo.toml" --features serde
cp "$src/target/doc/chrono.json" chrono-0.4.45-serde.json
```

The per-crate feature column that folds this into `gen-fixtures.sh` proper
(`chrono@0.4.45:serde`) is checklist item 2.4 (feature plumbing).

Note: at serde ≥ 1.0.220 the derive/traits moved to a `serde_core` crate, so the
canonical trait root here is `serde_core::ser::Serialize` (not `serde::...`) -- the
detection matcher accepts both roots for exactly this reason.
