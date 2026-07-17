//! HashMap→dict bridge demo (M6.2) — the hand-written exemplar for the map return
//! tag before the binder emits it for arbitrary crates.
//!
//! ABI v1 (through M6.1) could move scalars, strings, opaque handles and
//! callbacks across the boundary, but not a keyed collection. M6.2 adds one
//! additive tag — `TAG_MAP_BIT`, OR'd with a value tag — so a
//! `HashMap<String, V>` return marshals as a real Jac `dict[str, V]` for
//! V in {int, uint, str, bool}. Keys are implicitly UTF-8 strings in v1. The
//! shim serializes the whole map into one owned `JacBuf`
//! (`[u32 count]` then per entry `[u32 key_len][key bytes][value]`, all
//! little-endian) and the loader deep-copies it into a fresh dict.
//!
//! This crate proves the round-trip on the Rust side and is loaded by both the
//! CPython and the native (na) conformance suites — the na synthesizer now builds
//! and returns a real `dict[str, V]` (see `na/map_conformance.jac` for the runtime
//! na<->CPython equivalence proof):
//!   * dict[str, int]  — signed values incl. negatives,
//!   * dict[str, int]  — unsigned wire slot decoded signed (u64 high bit),
//!   * dict[str, str]  — nested length-prefixed string values, unicode keys,
//!   * dict[str, bool] — single-byte values,
//!   * an empty map, and
//!   * a fallible map return (`Result<HashMap<..>, _>` → dict-or-raise).

#![allow(clippy::missing_safety_doc)]

use jac_bridge::bridge;

#[bridge(module = "mapdemo")]
mod bridge_impl {
    use std::collections::HashMap;

    /// Opaque handle carrying a seed count used to shape the returned maps.
    pub struct Store(pub u32);

    /// Named error type for D2 metadata (error handles are `Box<String>`).
    #[jac_error]
    pub struct StoreError;

    impl Store {
        /// Constructor: `n` seeds how many entries the count-shaped maps carry.
        pub fn new(n: u32) -> Self {
            Self(n)
        }

        /// dict[str, int]: keys `k0..k{n-1}`, value = signed index doubled, with
        /// a negative entry to prove signed values survive the u64 slot.
        pub fn counts(&self) -> HashMap<String, i64> {
            let mut m = HashMap::new();
            for i in 0..self.0 {
                m.insert(format!("k{i}"), (i as i64) * 2);
            }
            m.insert("neg".to_string(), -7);
            m
        }

        /// dict[str, int] carrying an unsigned value whose high bit is set —
        /// proves the value decodes per its tag. `u64::MAX` reaches the na-signed
        /// image `-1` on both runtimes; here the CPython loader reads it unsigned.
        pub fn big(&self) -> HashMap<String, u64> {
            let mut m = HashMap::new();
            m.insert("max".to_string(), u64::MAX);
            m.insert("zero".to_string(), 0);
            m
        }

        /// dict[str, str]: length-prefixed string values, with a unicode key to
        /// prove UTF-8 keys round-trip byte-for-byte.
        pub fn labels(&self) -> HashMap<String, String> {
            let mut m = HashMap::new();
            m.insert("greeting".to_string(), "héllo".to_string());
            m.insert("naïve".to_string(), "café".to_string());
            m.insert("empty".to_string(), String::new());
            m
        }

        /// dict[str, bool]: single-byte values.
        pub fn flags(&self) -> HashMap<String, bool> {
            let mut m = HashMap::new();
            m.insert("on".to_string(), true);
            m.insert("off".to_string(), false);
            m
        }

        /// An empty map — proves a zero count parses to an empty dict.
        pub fn none(&self) -> HashMap<String, i64> {
            HashMap::new()
        }

        /// Fallible map return: `Err` when the store was seeded empty, else a map.
        pub fn checked(&self) -> Result<HashMap<String, u64>, String> {
            if self.0 == 0 {
                Err("store is empty".to_string())
            } else {
                let mut m = HashMap::new();
                m.insert("n".to_string(), self.0 as u64);
                Ok(m)
            }
        }
    }
}
