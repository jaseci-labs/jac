//! Scalar-integer bridge demo (M6.1) — the hand-written exemplar for the integer
//! boundary tags before the binder emits them for arbitrary crates.
//!
//! ABI v1 originally carried only `bool`, `str`/`String`, void, opaque handles
//! and callbacks; there was no way to move a plain integer across the boundary,
//! so every integer param/return was recorded as a skip. M6.1 adds two additive
//! tags — `TAG_INT` (signed) and `TAG_UINT` (unsigned) — each crossing as a
//! single 64-bit slot. Signedness is preserved in the tag (not the width) so a
//! full-range `u64` with its high bit set is never misread as negative.
//!
//! This crate proves the round-trip on the Rust side and is loaded by the
//! CPython and na conformance suites to assert both runtimes decode identically:
//!   * signed param + signed return, at full and narrow widths,
//!   * unsigned param + unsigned return, including `u64::MAX` (> `i64::MAX`),
//!   * negative values (two's-complement reinterpret), and
//!   * a fallible integer return (`Result<i64, _>` → int-or-raise).

#![allow(clippy::missing_safety_doc)]

use jac_bridge::bridge;

#[bridge(module = "scalar")]
mod bridge_impl {
    /// Opaque handle carrying a single signed seed value.
    pub struct Calc(pub i64);

    /// Named error type for D2 metadata (error handles are `Box<String>`).
    #[jac_error]
    pub struct ScalarError;

    impl Calc {
        /// Constructor with a signed integer param — the seed may be negative.
        pub fn new(seed: i64) -> Self {
            Self(seed)
        }

        /// Signed return: echoes the seed (proves negatives survive the slot).
        pub fn seed(&self) -> i64 {
            self.0
        }

        /// Signed param + signed return.
        pub fn add(&self, x: i64) -> i64 {
            self.0.wrapping_add(x)
        }

        /// Narrow unsigned return (`u8`) — proves widths <64 zero-extend cleanly.
        pub fn low_byte(&self) -> u8 {
            (self.0 & 0xff) as u8
        }

        /// Unsigned return that can exceed `i64::MAX` for a negative seed —
        /// proves `TAG_UINT` is decoded unsigned, not as a negative `TAG_INT`.
        pub fn magnitude(&self) -> u64 {
            self.0.unsigned_abs()
        }

        /// Unsigned param + unsigned return — the identity, so a caller can pass
        /// `u64::MAX` through and read it back bit-for-bit.
        pub fn echo_u64(&self, x: u64) -> u64 {
            x
        }

        /// The maximum `u64` — a constant whose high bit is set.
        pub fn max_u64(&self) -> u64 {
            u64::MAX
        }

        /// Float param + float return (`f64`): adds a double to the seed and
        /// returns the sum, proving an `f64` crosses each way as its exact bit
        /// pattern (not a numeric truncation).
        pub fn add_f64(&self, x: f64) -> f64 {
            self.0 as f64 + x
        }

        /// Narrow float round-trip (`f32`): echoes the value, proving an `f32`
        /// widens to the `f64` slot and comes back bit-for-bit.
        pub fn echo_f32(&self, x: f32) -> f32 {
            x
        }

        /// A float constant that only round-trips exactly under bit
        /// reinterpretation — a numeric `as u64` cast would corrupt it.
        pub fn pi(&self) -> f64 {
            std::f64::consts::PI
        }

        /// Float return from an integer param (`i64` in, `f64` out): the seed
        /// scaled by `n`, divided by 4 so the result is fractional. Proves the
        /// f64 return path independent of the f64 param path (which na skips).
        pub fn scaled(&self, n: i64) -> f64 {
            (self.0 * n) as f64 / 4.0
        }

        /// Fallible integer return: `Err` on divide-by-zero, else the quotient.
        /// (Param is `divisor`, not `by`: `by` is a Jac keyword, and the na
        /// loader emits the Rust param name verbatim as a Jac identifier.)
        pub fn checked_div(&self, divisor: i64) -> Result<i64, String> {
            if divisor == 0 {
                Err("divide by zero".to_string())
            } else {
                Ok(self.0 / divisor)
            }
        }
    }
}
