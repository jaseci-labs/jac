# ABI v1 reference vector

`regex.jacbridge` is the canonical D2 metadata blob for the `regex` bridge:
the 431-byte contents of the `.jac_bridge` section of the **hand-written** M0
crate (`jac-bridge-regex`). Per M1 (`docs/docs/internals/rust_bridge_abi.md`),
the M0 blob is the reference vector that all other producers must reproduce.

Two diff-tests pin it:

- `jac-bridge-regex` asserts its own blob equals this file (guards the reference
  against hand-written drift).
- `jac-bridge-regex-v2` asserts its `#[jac_bridge::bridge]` macro-generated blob
  equals this file (proves the M2 macro is ABI-identical to the hand-written
  reference, byte for byte).

Regenerate after an intentional ABI change:

    cargo build --release -p jac-bridge-regex
    objcopy -O binary --only-section=.jac_bridge \
        target/release/libjac_bridge_regex.so reference/regex.jacbridge

then bump `abi_version` and follow the append-only evolution rule.
