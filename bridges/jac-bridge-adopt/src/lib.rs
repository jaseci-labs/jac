//! Adopt-shell reference crate (handle-soundness lane).
//!
//! This crate exercises the one opaque shape the na loader's static `_adopt`
//! shell exists for: a method that RETURNS a CONSTRUCTOR-BEARING opaque type.
//!
//! * `Counter` — a mutable `i64`, constructed with `new(v)`.
//! * `Snapshot` — an immutable `i64`, ALSO constructed with `new(v)`, and ALSO
//!   produced by `Counter::snapshot(&self) -> Snapshot` (a fresh, independent
//!   copy of the counter's current value).
//!
//! Because `Snapshot` owns a real constructor, the synthesized na wrapper's
//! `init(v: int)` slot is taken by that ctor — the adopt path cannot reuse
//! `init(raw)` (as a constructor-LESS "adoptable" type does).  So the synth
//! emits a distinct static shell instead:
//!
//! ```text
//! static def _adopt(raw: int) -> Snapshot {
//!     adopted = Snapshot.__new__(Snapshot);   // bare alloc, NO init
//!     adopted.__handle = raw;
//!     adopted.__closed = False;
//!     return adopted;
//! }
//! ```
//!
//! and `Counter::snapshot` returns `Snapshot._adopt(rh)`.  That shell RENDERED
//! before, but did not native-compile: NaIRGenPass could not lower `T.__new__(T)`
//! (nor the external-local field writes on its result), so the whole method
//! demoted to Python-only.  With `__new__` lowering in place, `snapshot` compiles
//! and runs on na.  `Snapshot` is returned as an owned value (a fresh
//! `Box::into_raw`), distinct from the receiver's box — no self-identity retain
//! is involved (that is the `&self -> &Self` case, a separate lane); each wrapper
//! owns its box and frees exactly once.

#![allow(clippy::missing_safety_doc)]

use jac_bridge::bridge;

#[bridge(module = "adopt")]
mod bridge_impl {
    /// A mutable counter, constructed directly with `new`.
    pub struct Counter {
        value: i64,
    }

    /// An immutable captured value.  Constructible on its own (`new`) AND minted
    /// by `Counter::snapshot` — the dual identity that forces the ctor-bearing
    /// adopt shell on the na loader.
    pub struct Snapshot {
        value: i64,
    }

    impl Counter {
        pub fn new(v: i64) -> Self {
            Counter { value: v }
        }

        /// Read the live value.
        pub fn get(&self) -> i64 {
            self.value
        }

        /// Increment and return the new value.
        pub fn bump(&mut self) -> i64 {
            self.value += 1;
            self.value
        }

        /// Capture the current value as a fresh, independent `Snapshot`.  The
        /// returned handle is a brand-new `Box`, NOT this counter's box, so it is
        /// adopted (via the `_adopt` shell) rather than sharing identity; later
        /// mutation of the counter does not change the snapshot.
        pub fn snapshot(&self) -> Snapshot {
            Snapshot { value: self.value }
        }
    }

    impl Snapshot {
        pub fn new(v: i64) -> Self {
            Snapshot { value: v }
        }

        /// Read the captured value.
        pub fn value(&self) -> i64 {
            self.value
        }
    }
}
