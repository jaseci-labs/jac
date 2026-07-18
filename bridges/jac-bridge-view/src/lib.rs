//! Borrowed-view reference crate (Phase S, Track B).
//!
//! This crate exercises the `borrowed` ownership class of the handle contract:
//! a live, NON-owning view into an owner's interior that must stay valid for as
//! long as the view is held, without copying the interior out.
//!
//! * `Doc` owns a heap-allocated `i64` (a `Box<i64>` — a stable address).
//! * `Doc::peek(&self) -> Peek`, marked **`#[jac(borrowed)]`**, mints a `Peek`
//!   that stores a RAW pointer into `Doc`'s heap `i64`.  A `Peek` owns nothing;
//!   it reads through that pointer (`read`), zero-copy.
//!
//! The pointer is sound ONLY while the `Doc` allocation lives.  The ownership
//! contract makes that guarantee at the handle layer: minting a `borrowed` view
//! RETAINS the owner handle (rc+1), so `Doc`'s box — and therefore its `Box<i64>`
//! — physically cannot be freed while any `Peek` is live.  Closing the `Doc`
//! first is merely a decref; the allocation is freed only when the last view
//! releases it (rc -> 0).  The retain is LOAD-BEARING: were it absent, closing
//! the `Doc` would drop the `Box<i64>` and `Peek::read` would read freed memory.
//!
//! `Doc::peek` takes `&self` (a shared borrow — no reentrancy latch), and `Peek`
//! is constructor-less (reachable only by adopting a `Doc`'s interior), which is
//! exactly the "adoptable opaque type" a method return must be on the na loader.
//!
//! Why a raw pointer and not an `Arc`: an `Arc<Mutex<i64>>` view (as in the
//! reentrant crate) is `shared` ownership — the inner is refcounted at the Rust
//! level, so the view keeps it alive regardless of the handle contract, and the
//! handle-layer retain would be redundant.  A raw interior pointer has no such
//! backstop, so it is the honest test that the ownership contract itself pins the
//! owner.  `Send` holds: `*const i64` is not `Send`, so `Peek` stores the address
//! as a `usize` and reconstitutes the pointer on read — the same discipline the
//! ABI's `JacHandle<T>: Send` assertion requires.

#![allow(clippy::missing_safety_doc)]

use jac_bridge::bridge;

#[bridge(module = "view")]
mod bridge_impl {
    /// An owner of a heap `i64`.  The `Box` gives the value a stable address a
    /// `Peek` can point into; mutating through `set` writes in place, so a live
    /// view observes the change.
    pub struct Doc {
        data: Box<i64>,
    }

    /// A borrowed, non-owning view into a `Doc`'s heap `i64`.  Stores the address
    /// as a `usize` (so the struct stays `Send`) and reads through it.  Owns
    /// nothing: it is kept valid purely by the owner-retain the `borrowed` handle
    /// contract performs on mint.  Constructor-less — minted only by `Doc::peek`.
    pub struct Peek {
        ptr: usize,
    }

    impl Doc {
        pub fn new(v: i64) -> Self {
            Doc { data: Box::new(v) }
        }

        /// Read the current value directly (owner-side).
        pub fn get(&self) -> i64 {
            *self.data
        }

        /// Mutate the heap value in place.  A live `Peek` reads the new value
        /// through its pointer, proving the view is a live window, not a copy.
        pub fn set(&mut self, v: i64) {
            *self.data = v;
        }

        /// Mint a borrowed view into this `Doc`'s interior.  The returned `Peek`
        /// holds a raw pointer to the heap `i64`; it is valid for as long as the
        /// `borrowed` contract keeps this `Doc` handle retained (which the loader
        /// guarantees by retaining the owner on mint and releasing on the view's
        /// close).
        #[jac(borrowed)]
        pub fn peek(&self) -> Peek {
            Peek {
                ptr: (&*self.data as *const i64) as usize,
            }
        }
    }

    impl Peek {
        /// Read the owner's live value through the borrowed pointer.  Sound while
        /// the owner is retained — the whole point of the `borrowed` class.
        pub fn read(&self) -> i64 {
            unsafe { *(self.ptr as *const i64) }
        }
    }
}
