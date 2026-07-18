//! Second callback crate (Phase 0.0.1) — the deliberate twin of
//! `jac-bridge-owning` under a DIFFERENT module name (`owning2`), so the two
//! coexist in one na module. Its only job is to exercise a callback return path
//! (`replace_all`) through its OWN generated allocator `jac_owning2_make_buf` /
//! `jac_owning2_free_buf`. When both crates' `replace_all` run in the same
//! compiled module, the na backend must route each trampoline's return-buffer
//! allocation to the callee crate's allocator; the pre-0.1.1 single-sink code
//! collapses both onto one crate's `make_buf`, a cross-allocator free = UB. This
//! crate is the second half of that test — nothing here is novel, only distinct.
//!
//! Kept intentionally small: just `Regex::new` + `Regex::replace_all` (plus the
//! implicit drop/error shims the macro emits). The owning-wrapper machinery is
//! already proven in `jac-bridge-owning`; duplicating it would add no coverage.

#![allow(clippy::missing_safety_doc)]

use jac_bridge::bridge;

// ---------------------------------------------------------------------------
// Guarded per-crate allocator (task 0.1.1 enforcement)
// ---------------------------------------------------------------------------
// WHY THIS EXISTS: the two-crate conformance probe loads BOTH callback crates
// (`owning` + `owning2`) into one na-compiled binary and drives a callback
// through each. Each crate's macro-generated callback path mints its return
// buffer via `jac_<module>_make_buf` (a `Vec`, i.e. that crate's global
// allocator) and later frees it via that same crate's `JacCallback::call`
// (a `Vec::from_raw_parts` drop, i.e. that same crate's global allocator).
// The invariant task 0.1.1 demands: a buffer minted by crate X's make_buf is
// ALWAYS freed by crate X's allocator. The pre-0.1.1 compiler has a single
// global callback-allocator sink, so it misroutes `owning2`'s callback buffer
// through `owning`'s make_buf — a cross-allocator alloc/free.
//
// With both crates on the same default system allocator that cross-free is
// BENIGN (both malloc), so the probe passes GREEN and proves nothing. To make
// the misroute observable we give `owning2` (and ONLY owning2) a distinct
// guarded global allocator: every block it mints carries an 8-byte magic tag
// in a header just below the returned pointer. On free it re-checks the tag;
// a foreign (system-allocated, tag-less) pointer reaching owning2's free path
// fails the check and deterministically `abort()`s instead of silently
// double-allocating. A correct per-crate sink never hands owning2 a foreign
// buffer, so it keeps the tag consistent and the probe stays GREEN.
//
// `owning` is deliberately left on the system allocator; only owning2 needs
// the guard to turn the misroute into a hard, reproducible crash.
mod guarded_alloc {
    use std::alloc::{GlobalAlloc, Layout, System};

    // "OWN2GARD" — distinctive 8-byte tag stamped ahead of every owning2 block.
    const MAGIC: u64 = 0x4F574E32_47415244;

    /// Bytes reserved ahead of the user pointer. Must be >= 8 (to hold the tag)
    /// and a multiple of `align` so the user pointer stays correctly aligned.
    #[inline]
    fn header_offset(align: usize) -> usize {
        if align <= 8 { 8 } else { align }
    }

    #[inline]
    fn padded(layout: Layout) -> (usize, Layout) {
        let offset = header_offset(layout.align());
        let l = Layout::from_size_align(layout.size() + offset, layout.align())
            .expect("owning2 guarded alloc: layout overflow");
        (offset, l)
    }

    pub struct Guarded;

    unsafe impl GlobalAlloc for Guarded {
        unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
            let (offset, l) = padded(layout);
            let base = unsafe { System.alloc(l) };
            if base.is_null() {
                return base;
            }
            let user = unsafe { base.add(offset) };
            // Stamp the tag in the 8 bytes immediately below the user pointer.
            unsafe { (user.sub(8) as *mut u64).write(MAGIC) };
            user
        }

        unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
            let tag = unsafe { (ptr.sub(8) as *const u64).read() };
            if tag != MAGIC {
                // A buffer that owning2 did NOT mint has reached owning2's free
                // path — exactly the cross-crate misroute task 0.1.1 forbids.
                // Fail loud and hard rather than corrupt the heap.
                eprintln!(
                    "jac-bridge-owning2: guarded allocator caught a cross-crate free \
                     (bad tag {tag:#018x}); a callback return buffer was minted by the \
                     WRONG crate's make_buf. See task 0.1.1 (per-crate callback sink)."
                );
                std::process::abort();
            }
            let (offset, l) = padded(layout);
            let base = unsafe { ptr.sub(offset) };
            unsafe { System.dealloc(base, l) };
        }
    }
}

#[global_allocator]
static ALLOC: guarded_alloc::Guarded = guarded_alloc::Guarded;

#[bridge(module = "owning2")]
mod bridge_impl {
    /// Opaque handle wrapping a compiled `regex::Regex` — same shape as the
    /// `owning` crate's, under a distinct module so the symbol names differ.
    pub struct Regex2(pub regex::Regex);

    /// Named error type (error handles are `Box<String>`).
    #[jac_error]
    pub struct Owning2Error;

    impl Regex2 {
        /// Compile `pattern`. Returns STATUS_ERR on invalid syntax.
        pub fn new(pattern: &str) -> Result<Self, String> {
            regex::Regex::new(pattern).map(Self).map_err(|e| e.to_string())
        }

        /// Replace every match by invoking the Jac callback per match and
        /// splicing in the `String` it returns — the callback's replacement
        /// crosses back as a `JacBuf` minted by THIS crate's `jac_owning2_make_buf`
        /// and freed here with `jac_owning2_free_buf`. Identical contract to
        /// `owning::Regex::replace_all`; the point is the distinct allocator.
        pub fn replace_all(&self, text: &str, rep: JacCallback) -> Result<String, String> {
            let err: std::cell::RefCell<Option<String>> = std::cell::RefCell::new(None);
            let out = self
                .0
                .replace_all(text, |caps: &regex::Captures| {
                    let m = caps.get(0).map_or("", |x| x.as_str());
                    match rep.call(m) {
                        Ok(s) => s,
                        Err(e) => {
                            if err.borrow().is_none() {
                                *err.borrow_mut() = Some(e);
                            }
                            String::new()
                        }
                    }
                })
                .into_owned();
            match err.into_inner() {
                Some(e) => Err(e),
                None => Ok(out),
            }
        }
    }
}
