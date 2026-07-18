//! Reentrancy + aliasing reference crate (Phase 0.0.2, rewritten in Phase S).
//!
//! This crate exposes the two opaque shapes the soundness guards exist to
//! exercise:
//!
//! 1. **Reentrancy** — a `&mut self` method (`Cell::apply`) invokes a
//!    `JacCallback` while its exclusive borrow is live.  If the Jac callback
//!    re-enters the SAME receiver (e.g. calls `bump`, another `&mut self` method,
//!    on the same handle), the generated shim would materialize a SECOND `&mut`
//!    from the same pointer: two live `&mut T`, instant UB.  The per-handle
//!    reentrancy guard (0.2.2) turns that second entry into a clean status-1
//!    error.  The crate itself carries no guard — it is the honest, dangerous
//!    shape the gate needs to catch.
//!
//! 2. **Aliasing (honestly shared)** — `Cell::alias(&self) -> CellAlias` mints a
//!    SECOND opaque wrapper over the SAME underlying counter.  Phase S rewrote
//!    this from the original `usize`-smuggled DOUBLE-OWN (two boxes each calling
//!    `Box::from_raw` on one address — a genuine double-free) into GENUINE shared
//!    ownership: the counter lives behind an `Arc<Mutex<i64>>`, and `alias`
//!    clones the `Arc`.  Two Jac wrappers, one refcounted inner: closing either
//!    wrapper drops only its `Arc` clone, and the counter is freed exactly once
//!    when the last clone drops.  This is the shape RC-safe handles (Phase S,
//!    Track A) make sound — `aliasing_conformance.jac` test 3 flips from a
//!    double-free abort to a clean result.
//!
//! `Mutex` also makes the shared inner `Send + Sync`, so the ABI's
//! `JacHandle<T>: Send` assertion holds without smuggling a raw pointer through
//! a `usize`.
//!
//! ABI NOTE (why the alias view is a distinct type, not `-> Self`).  The obvious
//! spelling is `Cell::alias(&self) -> Self`.  Because `Cell` has a constructor
//! (`new`), the real `init(v: int)` occupies the wrapper's ctor slot, so the
//! adopt path cannot reuse `init(raw)`; the synth loader instead emits a static
//! shell `_adopt(raw) { a = Cell.__new__(Cell); a.__handle = raw; ... }` that
//! bypasses the Rust ctor.  That shell renders and binds on both loaders, and na
//! now lowers `T.__new__(T)` + the external-local field writes it needs, so the
//! `-> Self`/ctor-bearing spelling IS na-runnable today -- exercised end-to-end
//! by the `jac-bridge-adopt` crate (`Counter::snapshot -> Snapshot`) via
//! `na/adopt_conformance.jac`, with the compiler-unit guard
//! `test_native_obj_new_adopt.jac`.  We nonetheless keep the alias view as its
//! own constructor-less type `CellAlias`: it is reachable ONLY via `Cell::alias`,
//! shares `Cell`'s `Arc`, and documents the "adoptable opaque type" shape
//! distinctly.  Two Jac wrappers, one refcounted object — the 0.0.2 shape, now
//! sound.

#![allow(clippy::missing_safety_doc)]

use jac_bridge::bridge;

#[bridge(module = "reentrant")]
mod bridge_impl {
    use std::sync::{Arc, Mutex};

    /// A mutable counter whose value lives behind a refcounted, `Send + Sync`
    /// cell.  `alias` clones the `Arc`, so a `Cell` and its `CellAlias` share one
    /// counter without either owning a raw pointer the other can free.
    pub struct Cell {
        shared: Arc<Mutex<i64>>,
    }

    /// A second wrapper over a `Cell`'s counter, minted by `Cell::alias`.  It has
    /// NO constructor — it can only be produced by adopting an existing shared
    /// `Arc`, which is exactly what makes it a legal na method return (an
    /// "adoptable" opaque type).  It holds an independent `Arc` clone of the same
    /// counter: the honest, RC-safe aliasing shape.
    pub struct CellAlias {
        shared: Arc<Mutex<i64>>,
    }

    #[jac_error]
    pub struct ReentrantError;

    impl Cell {
        pub fn new(v: i64) -> Self {
            Cell {
                shared: Arc::new(Mutex::new(v)),
            }
        }

        /// Read the shared value.
        pub fn get(&self) -> i64 {
            *self.shared.lock().unwrap()
        }

        /// Mutate through `&mut self` and return the new value.  A callback that
        /// calls this on its own receiver during `apply` is the reentrant alias
        /// the busy latch must reject.
        pub fn bump(&mut self) -> i64 {
            let mut g = self.shared.lock().unwrap();
            *g += 1;
            *g
        }

        /// Mint a SECOND wrapper (a `CellAlias`) over the SAME underlying counter
        /// by cloning the `Arc`.  `&self` (shared, so no busy latch).  Both
        /// wrappers now hold an independent reference to one refcounted counter;
        /// closing either drops only its clone, and the counter is freed exactly
        /// once when the last clone drops — no double-free (Phase S).
        pub fn alias(&self) -> CellAlias {
            CellAlias {
                shared: Arc::clone(&self.shared),
            }
        }

        /// Hold a `&mut self` borrow live across a Jac callback invocation.  The
        /// callback receives the current value as text and returns a replacement
        /// string; `apply` splices it with the (post-mutation) value.  If the
        /// callback re-enters `bump` on this same handle, that second `&mut self`
        /// aliases this one — the reentrancy guard (0.2.2) must convert it to a
        /// clean error rather than let both borrows go live.
        ///
        /// The mutex is locked ONLY to read/mutate the counter, never held across
        /// `cb.call`, so a `&self` callback (e.g. one that calls `get`) does not
        /// deadlock on the non-reentrant `Mutex`.
        pub fn apply(&mut self, cb: JacCallback) -> Result<String, String> {
            let cur = {
                let mut g = self.shared.lock().unwrap();
                *g += 1;
                g.to_string()
            };
            let from_cb = cb.call(&cur)?;
            let now = *self.shared.lock().unwrap();
            Ok(format!("{now}:{from_cb}"))
        }
    }

    impl CellAlias {
        /// Read the shared value.  Sound after the originating `Cell` (or a
        /// sibling alias) is closed: the `Arc` keeps the counter alive as long as
        /// this clone lives.
        pub fn get(&self) -> i64 {
            *self.shared.lock().unwrap()
        }

        /// Mutate the shared value through this alias.
        pub fn bump(&mut self) -> i64 {
            let mut g = self.shared.lock().unwrap();
            *g += 1;
            *g
        }
    }
}
