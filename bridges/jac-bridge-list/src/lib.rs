//! Vec→list bridge demo (M6, Vec tail) — the hand-written exemplar for the list
//! return tag before the binder emits it for arbitrary crates.
//!
//! The map tail (M6.2) added `TAG_MAP_BIT` for `HashMap<String, V>` returns; this
//! crate adds the sibling `TAG_LIST_BIT`, OR'd with an element tag, so a `Vec<V>`
//! return marshals as a real Jac `list[V]` for V in {int, uint, str, bool}. The
//! shim serializes the whole vector into one owned `JacBuf` (`[u32 count]` then per
//! element `[value]`, all little-endian) and the loader deep-copies it into a fresh
//! list.
//!
//! This crate proves the round-trip on the Rust side and is loaded by the CPython
//! conformance suite (the na loader skips list returns — list-return codegen is not
//! yet supported on the native backend, a tracked follow-up):
//!   * list[int]  — signed values incl. negatives,
//!   * list[int]  — unsigned wire slot decoded signed (u64 high bit),
//!   * list[str]  — nested length-prefixed string values, incl. unicode + empty,
//!   * list[bool] — single-byte values,
//!   * an empty list, and
//!   * a fallible list return (`Result<Vec<..>, _>` → list-or-raise).

#![allow(clippy::missing_safety_doc)]

use jac_bridge::bridge;

#[bridge(module = "listdemo")]
mod bridge_impl {
    /// Opaque handle carrying a seed count used to shape the returned vectors.
    pub struct Store(pub u32);

    /// Named error type for D2 metadata (error handles are `Box<String>`).
    #[jac_error]
    pub struct StoreError;

    impl Store {
        /// Constructor: `n` seeds how many entries the count-shaped vectors carry.
        pub fn new(n: u32) -> Self {
            Self(n)
        }

        /// list[int]: values `0, 2, 4, ..` then a negative to prove signed values
        /// survive the u64 slot in order.
        pub fn counts(&self) -> Vec<i64> {
            let mut v: Vec<i64> = (0..self.0).map(|i| (i as i64) * 2).collect();
            v.push(-7);
            v
        }

        /// list[int] carrying an unsigned value whose high bit is set — proves the
        /// element decodes per its tag. `u64::MAX` reaches the na-signed image `-1`
        /// on both runtimes; here the CPython loader reads it unsigned.
        pub fn big(&self) -> Vec<u64> {
            vec![u64::MAX, 0]
        }

        /// list[str]: length-prefixed string values, with a unicode and an empty
        /// element to prove UTF-8 round-trips byte-for-byte and order is preserved.
        pub fn labels(&self) -> Vec<String> {
            vec!["héllo".to_string(), "café".to_string(), String::new()]
        }

        /// list[bool]: single-byte values.
        pub fn flags(&self) -> Vec<bool> {
            vec![true, false, true]
        }

        /// An empty list — proves a zero count parses to an empty list.
        pub fn none(&self) -> Vec<i64> {
            Vec::new()
        }

        /// Fallible list return: `Err` when the store was seeded empty, else a list.
        pub fn checked(&self) -> Result<Vec<u64>, String> {
            if self.0 == 0 {
                Err("store is empty".to_string())
            } else {
                Ok((0..self.0 as u64).collect())
            }
        }
    }
}
