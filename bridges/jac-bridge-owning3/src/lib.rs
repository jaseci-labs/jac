//! Third callback crate (Phase 0.1.1) — a further twin of `jac-bridge-owning`
//! and `jac-bridge-owning2` under a DISTINCT module name (`owning3`) and type
//! (`Regex3`), so all three coexist in one na module. Its only job is to
//! exercise a callback return path (`replace_all`) through its OWN generated
//! allocator `jac_owning3_make_buf` / `jac_owning3_free_buf`, guarded by a
//! DISTINCT global allocator so a cross-crate misroute aborts deterministically.
//! With three interleaved crates the pre-0.1.1 single-sink code has more ways to
//! misroute a callback return buffer; owning3's guard makes any such misroute
//! that reaches ITS free path a hard crash instead of silent heap corruption.
//!
//! Kept intentionally small: just `Regex3::new` + `Regex3::replace_all` (plus the
//! implicit drop/error shims the macro emits). The owning-wrapper machinery is
//! already proven in `jac-bridge-owning`; duplicating it would add no coverage.

#![allow(clippy::missing_safety_doc)]

use jac_bridge::bridge;

// ---------------------------------------------------------------------------
// Guarded per-crate allocator (task 0.1.1 enforcement)
// ---------------------------------------------------------------------------
// WHY THIS EXISTS: the three-crate conformance probe loads ALL THREE callback
// crates (`owning` + `owning2` + `owning3`) into one na-compiled binary and
// drives callbacks through each in mixed order. Each crate's macro-generated
// callback path mints its return buffer via `jac_<module>_make_buf` (a `Vec`,
// i.e. that crate's global allocator) and later frees it via that same crate's
// `JacCallback::call` (a `Vec::from_raw_parts` drop, i.e. that same crate's
// global allocator). The invariant task 0.1.1 demands: a buffer minted by
// crate X's make_buf is ALWAYS freed by crate X's allocator. The pre-0.1.1
// compiler has a single global callback-allocator sink, so it misroutes some
// crate's callback buffer through another crate's make_buf — a cross-allocator
// alloc/free.
//
// With crates on the same default system allocator that cross-free is BENIGN
// (both malloc), so the probe passes GREEN and proves nothing. To make the
// misroute observable we give `owning3` (like `owning2`) a distinct guarded
// global allocator with its OWN magic tag: every block it mints carries an
// 8-byte magic tag in a header just below the returned pointer. On free it
// re-checks the tag; a foreign (system-allocated or wrong-crate) pointer
// reaching owning3's free path fails the check and deterministically
// `abort()`s. A correct per-crate sink never hands owning3 a foreign buffer,
// so it keeps the tag consistent and the probe stays GREEN.
//
// `owning` is deliberately left on the system allocator; owning2 and owning3
// each carry a distinct guard with a distinct magic value so a misroute
// between the two guarded crates is also caught.
mod guarded_alloc {
    use std::alloc::{GlobalAlloc, Layout, System};

    // "OWN3GARD" — distinctive 8-byte tag stamped ahead of every owning3 block.
    // Distinct from owning2's "OWN2GARD" so a buffer minted by owning2 that
    // reaches owning3's free path (or vice versa) fails the tag check.
    const MAGIC: u64 = 0x4F574E33_47415244;

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
            .expect("owning3 guarded alloc: layout overflow");
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
                // A buffer that owning3 did NOT mint has reached owning3's free
                // path — exactly the cross-crate misroute task 0.1.1 forbids.
                // Fail loud and hard rather than corrupt the heap.
                eprintln!(
                    "jac-bridge-owning3: guarded allocator caught a cross-crate free \
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

#[bridge(module = "owning3")]
mod bridge_impl {
    /// Opaque handle wrapping a compiled `regex::Regex` — same shape as the
    /// `owning`/`owning2` crates', under a distinct module so the symbol names
    /// differ and a distinct type name so the merged na module has no collision.
    pub struct Regex3(pub regex::Regex);

    /// Named error type (error handles are `Box<String>`).
    #[jac_error]
    pub struct Owning3Error;

    impl Regex3 {
        /// Compile `pattern`. Returns STATUS_ERR on invalid syntax.
        pub fn new(pattern: &str) -> Result<Self, String> {
            regex::Regex::new(pattern).map(Self).map_err(|e| e.to_string())
        }

        /// Replace every match by invoking the Jac callback per match and
        /// splicing in the `String` it returns — the callback's replacement
        /// crosses back as a `JacBuf` minted by THIS crate's `jac_owning3_make_buf`
        /// and freed here with `jac_owning3_free_buf`. Identical contract to
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
