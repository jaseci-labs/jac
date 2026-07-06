//! Async-bridge demo (M6.3) — the hand-written exemplar for async fn bridging.
//!
//! Every `impl AsyncCalc` method is `async fn`. The `#[bridge]` macro detects
//! the `async` qualifier and emits a sync C shim that calls
//! `__jac_bridge_async_rt::block_on(fut)`, driving the future to completion
//! inside a module-owned, lazily-initialised Tokio runtime. No ABI change:
//! loaders still call an exported C symbol and read status + out-params exactly
//! as they do for sync functions.
//!
//! `tokio::time::sleep` in `seed()` proves a REAL Tokio multi-thread runtime is
//! running — a poll-once executor would deadlock on a Sleep future.
//!
//! Methods exercised:
//!   * constructor (`new`) — `Result<Self, _>` async ctor,
//!   * signed int return (`seed`) — proves negatives survive, uses sleep to
//!     prove a real reactor is running,
//!   * String return (`label`) — proves str marshaling composes with async,
//!   * fallible int return (`checked_div`) — `Result<i64, _>` async method,
//!   * Vec<i64> return (`counts`) — M6 tail container return + async,
//!   * `error_message` auto-shim — inherited from the existing machinery.
//!
//! This crate is loaded by the CPython conformance suite to assert both the
//! macro's async detection and the runtime round-trip are correct.

#![allow(clippy::missing_safety_doc)]

use jac_bridge::bridge;

#[bridge(module = "async")]
mod bridge_impl {
    /// Opaque handle carrying a signed seed value and a short text label.
    pub struct AsyncCalc(pub i64, pub String);

    /// Named error type for D2 metadata (error handles are `Box<String>`).
    #[jac_error]
    pub struct AsyncError;

    impl AsyncCalc {
        /// Async constructor: `Err` when seed is zero (tests Result async ctor).
        pub async fn new(seed: i64, label: &str) -> Result<Self, String> {
            if seed == 0 {
                return Err("seed must be non-zero".to_string());
            }
            Ok(Self(seed, label.to_string()))
        }

        /// Returns the signed seed.  Calls `tokio::time::sleep` for 1 ms to
        /// prove a real Tokio reactor is active — a poll-once executor would
        /// stall on the Sleep future and never return.
        pub async fn seed(&self) -> i64 {
            tokio::time::sleep(std::time::Duration::from_millis(1)).await;
            self.0
        }

        /// Returns the text label — proves String marshaling composes with async.
        pub async fn label(&self) -> String {
            self.1.clone()
        }

        /// Fallible async integer return: `Err` on divide-by-zero.
        pub async fn checked_div(&self, divisor: i64) -> Result<i64, String> {
            if divisor == 0 {
                return Err("divide by zero".to_string());
            }
            Ok(self.0 / divisor)
        }

        /// `Vec<i64>` return: proves M6 tail container return composes with async.
        pub async fn counts(&self, n: u32) -> Vec<i64> {
            (0..n as i64).map(|i| self.0 + i).collect()
        }
    }
}
