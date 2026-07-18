//! Self-identity reference crate (Phase 1.2.4).
//!
//! This crate exercises the `self-identity` case of the handle-ownership
//! contract: a `&self` method that returns `&Self` — a second handle onto the
//! receiver's OWN box, not a fresh object.  It is the identity analog of
//! `jac-bridge-view` (which covers `borrowed`).
//!
//! * `Node` owns an `i64` and is minted by `Registry::make` (an owned return, a
//!   fresh box).  `Node` has NO public constructor of its own — deliberately: a
//!   type that is BOTH a public-ctor target and a method return is adopted on the
//!   na loader via a static `_adopt` shell (`__new__` + field writes) that the
//!   native compiler cannot yet lower.  A ctor-less adopted type instead adopts
//!   through the synthesized `init(raw)` (a field write on `self`, which na DOES
//!   lower), so the whole self-identity path compiles and runs natively.  A
//!   `Registry` factory supplies construction, keeping `Node` adoption-only.
//! * `Node::alias(&self) -> &Self` returns the receiver itself.  Because the
//!   return is a `&Self` borrow, the macro does NOT box it fresh; the shim writes
//!   the receiver's own handle integer straight back.  The na loader adopts that
//!   handle and, seeing `rh == self.__handle` at runtime, RETAINS the box (rc+1).
//!   Two wrappers (a node and its alias) now co-own one box; each `close()` is a
//!   decref, so the box — and its inner `Node` — drops exactly once, at rc 0.
//!
//! Why this is the ONLY sound producer of a retain-on-adopt handle: the retain is
//! justified purely by the runtime fact `rh == self.__handle`, which the loader
//! CHECKS — never by an author annotation it would have to trust.  A fresh box
//! that is retained but held by a single wrapper would leak (its one close drops
//! rc 2 -> 1, never 0); that is exactly the failure the retired `#[jac(shared)]`
//! annotation invited, and why a co-owned handle must be expressed as `&Self`.
//!
//! `Send` holds trivially: both types are plain `i64`, and the crossing handles
//! are `JacHandle<T>` (Send iff `T: Send`), which the ABI asserts at compile time.
//! `alias` takes `&self` (a shared borrow — no reentrancy latch), and the mutation
//! path `set` proves the alias is a live window onto one object: a write through
//! one handle is observed through the alias.

#![allow(clippy::missing_safety_doc)]

use jac_bridge::bridge;

#[bridge(module = "identity")]
mod bridge_impl {
    /// A factory for `Node`s.  Exists so `Node` itself needs no public ctor and
    /// stays adoption-only (see the module docs on the na `_adopt` gap).
    pub struct Registry {
        _seed: i64,
    }

    /// An owner of an `i64`.  Reachable fresh only via `Registry::make`, or as a
    /// second co-owning handle via `alias` (which hands back this same object).
    pub struct Node {
        val: i64,
    }

    impl Registry {
        pub fn new() -> Self {
            Registry { _seed: 0 }
        }

        /// Mint a fresh, owned `Node` — an ordinary owned-handle return.
        pub fn make(&self, v: i64) -> Node {
            Node { val: v }
        }
    }

    impl Node {
        /// Read the current value.
        pub fn get(&self) -> i64 {
            self.val
        }

        /// Mutate in place.  A live alias reads the new value, proving the two
        /// handles are one object, not a copy.
        pub fn set(&mut self, v: i64) {
            self.val = v;
        }

        /// Return a second handle onto THIS node — a self-identity return.  The
        /// `&Self` borrow lowers to the receiver's own handle integer; the loader
        /// RC-pins the shared box behind its `rh == self.__handle` guard, so the
        /// alias stays valid after the original handle closes.
        pub fn alias(&self) -> &Self {
            self
        }
    }
}
