//! Runtime acceptance tests for the Phase-0 handle-soundness guards emitted by
//! `#[jac_bridge::bridge]`:
//!
//!   * 0.2.2 reentrancy guard — a `&mut self` shim try-locks the handle's `busy`
//!     latch; a callback that re-enters its own receiver (a second live `&mut`)
//!     gets a clean status-1 error instead of aliasing UB.  `&self`-only shims
//!     skip the latch.
//!   * 0.2.1 null-handle guard — a raw handle of 0 returns status 1 with the
//!     message "null handle (use after close?)" instead of dereferencing null.
//!   * 0.1.2 TAG_FN emit — a `JacCallback`-typed param carries TAG_FN in the
//!     emitted D2 blob (Track A reads this to marshal callbacks).
//!
//! The bridge below is shaped like the frozen `jac-bridge-reentrant` reference
//! vector (a mutable `Cell` whose `apply(&mut self, cb)` invokes a callback while
//! its exclusive borrow is live) but lives here so the guard has something to
//! catch without editing a frozen crate.

use jac_bridge::bridge;

#[bridge(module = "guardtest")]
mod b {
    pub struct Cell {
        value: i64,
    }

    #[jac_error]
    pub struct GuardError;

    impl Cell {
        pub fn new(v: i64) -> Self {
            Cell { value: v }
        }

        /// `&mut self` — guarded. A reentrant call must be rejected.
        pub fn bump(&mut self) -> i64 {
            self.value += 1;
            self.value
        }

        /// `&self` — must NOT be latched (shared access is reentrant-safe).
        pub fn get(&self) -> i64 {
            self.value
        }

        /// Holds a `&mut self` borrow live across a callback invocation.
        pub fn apply(&mut self, cb: JacCallback) -> Result<String, String> {
            let cur = self.value.to_string();
            let out = cb.call(&cur)?;
            Ok(out)
        }

        /// Phase S, Track B: a borrowed interior view. `#[jac(borrowed)]` must set
        /// TAG_BORROW_BIT on the emitted `Ref` return tag so the loader RC-pins
        /// the owner. (Constructor-less `View` → an adoptable opaque return.)
        #[jac(borrowed)]
        pub fn view(&self) -> View {
            View { p: (&self.value as *const i64) as usize }
        }
    }

    /// A borrowed view into a `Cell`'s interior; minted only by `Cell::view`.
    pub struct View {
        p: usize,
    }

    impl View {
        pub fn read(&self) -> i64 {
            unsafe { *(self.p as *const i64) }
        }
    }
}

// The rt module is emitted as a private sibling at crate root; its `JacBuf` is
// the exact type the callback ABI uses.
use __jac_bridge_guardtest_rt::JacBuf;
use std::ffi::c_void;
use std::ptr;

// Records the status the reentrant `bump` returned when it re-entered the busy
// receiver, so the test can assert the guard fired (status 1).
static mut REENTRY_STATUS: i32 = -99;

/// Callback thunk matching the bridge ABI. `ctx` carries the receiver handle; it
/// re-enters `bump` on that same handle — the aliasing shape the guard defeats.
unsafe extern "C" fn reentrant_cb(
    ctx: *mut c_void,
    _s: *const u8,
    _len: u32,
    out: *mut JacBuf,
    _err: *mut u64,
) -> i32 {
    let handle = ctx as u64;
    let mut slot = 0u64;
    let mut err = 0u64;
    let st = jac_guardtest_Cell_bump(handle, &mut slot, &mut err);
    REENTRY_STATUS = st;
    if err != 0 {
        jac_guardtest_error_drop(err);
    }
    // Hand back an empty (borrowed, cap==0) replacement buffer.
    *out = JacBuf { ptr: ptr::null_mut(), len: 0, cap: 0 };
    0
}

/// `{call, ctx}` record the Jac side hands across as a single u64 pointer.
#[repr(C)]
struct Raw {
    call: usize,
    ctx: usize,
}

fn make_handle(v: i64) -> u64 {
    let mut handle = 0u64;
    let mut err = 0u64;
    let st = unsafe { jac_guardtest_Cell_new(v as u64, &mut handle, &mut err) };
    assert_eq!(st, 0, "ctor status");
    assert_ne!(handle, 0, "ctor produced a null handle");
    handle
}

#[test]
fn reentrant_mut_call_is_rejected() {
    let handle = make_handle(10);

    let raw = Raw { call: reentrant_cb as *const () as usize, ctx: handle as usize };
    let cb_ptr = &raw as *const Raw as u64;

    let mut out_buf = JacBuf { ptr: ptr::null_mut(), len: 0, cap: 0 };
    let mut err = 0u64;
    let st = unsafe { jac_guardtest_Cell_apply(handle, cb_ptr, &mut out_buf, &mut err) };

    // apply itself succeeds; the reentrant bump inside the callback was rejected.
    assert_eq!(st, 0, "apply should succeed");
    unsafe { jac_guardtest_free_buf(out_buf) };
    assert_eq!(
        unsafe { REENTRY_STATUS },
        1,
        "reentrant &mut bump must be rejected with status 1, not aliased"
    );

    // The rejected bump must NOT have mutated the cell.
    let mut slot = 0u64;
    let mut e = 0u64;
    let gst = unsafe { jac_guardtest_Cell_get(handle, &mut slot, &mut e) };
    assert_eq!(gst, 0);
    assert_eq!(slot, 10, "reentrant bump was rejected, value unchanged");

    // Latch was released: a normal bump after apply works.
    let mut slot2 = 0u64;
    let bst = unsafe { jac_guardtest_Cell_bump(handle, &mut slot2, &mut e) };
    assert_eq!(bst, 0, "latch released after apply");
    assert_eq!(slot2, 11);

    unsafe { jac_guardtest_Cell_drop(handle) };
}

#[test]
fn null_handle_returns_status_1() {
    // 0.2.1: a &mut method on a null handle.
    let mut slot = 0u64;
    let mut err = 0u64;
    let st = unsafe { jac_guardtest_Cell_bump(0, &mut slot, &mut err) };
    assert_eq!(st, 1, "null handle must return status 1");
    assert_ne!(err, 0, "status 1 must set an error message handle");

    // The error message must be the null-handle diagnostic.
    let mut msg_buf = JacBuf { ptr: ptr::null_mut(), len: 0, cap: 0 };
    let mut merr = 0u64;
    let mst = unsafe { jac_guardtest_error_message(err, &mut msg_buf, &mut merr) };
    assert_eq!(mst, 0);
    let msg = unsafe {
        let bytes = std::slice::from_raw_parts(msg_buf.ptr, msg_buf.len as usize);
        String::from_utf8_lossy(bytes).into_owned()
    };
    assert_eq!(msg, "null handle (use after close?)");
    unsafe {
        jac_guardtest_free_buf(msg_buf);
        jac_guardtest_error_drop(err);
    }

    // A &self method on a null handle is also guarded.
    let mut gslot = 0u64;
    let mut gerr = 0u64;
    let gst = unsafe { jac_guardtest_Cell_get(0, &mut gslot, &mut gerr) };
    assert_eq!(gst, 1, "null handle on &self method must return status 1");
    if gerr != 0 {
        unsafe { jac_guardtest_error_drop(gerr) };
    }

    // error_message on a null error handle is itself guarded (0.2.1).
    let mut nb = JacBuf { ptr: ptr::null_mut(), len: 0, cap: 0 };
    let mut ne = 0u64;
    let nst = unsafe { jac_guardtest_error_message(0, &mut nb, &mut ne) };
    assert_eq!(nst, 1, "error_message(null) must return status 1, not deref null");
    if ne != 0 {
        unsafe { jac_guardtest_error_drop(ne) };
    }
}

#[test]
fn callback_param_carries_tag_fn() {
    // 0.1.2: the emitted D2 blob must tag a JacCallback param as TAG_FN, and an
    // integer param as its scalar tag — proving the callback tagging is universal
    // (driven by the param type, not the crate/module).
    let blob: &[u8] = &__JAC_BRIDGE_META;

    let rd_u32 = |o: usize| -> u32 {
        u32::from_le_bytes([blob[o], blob[o + 1], blob[o + 2], blob[o + 3]])
    };

    let fns_off = rd_u32(48) as usize;
    let n_fns = rd_u32(52) as usize;

    let mut fn_tags = 0u32; // TAG_FN param count
    let mut int_tags = 0u32; // TAG_INT/TAG_UINT param count
    for i in 0..n_fns {
        let foff = fns_off + i * 44;
        let params_off = rd_u32(foff + 36) as usize;
        let n_params = rd_u32(foff + 40) as usize;
        for j in 0..n_params {
            let poff = params_off + j * 12;
            let tag = rd_u32(poff + 8);
            if tag == jac_bridge_schema::TAG_FN {
                fn_tags += 1;
            }
            if tag == jac_bridge_schema::TAG_INT || tag == jac_bridge_schema::TAG_UINT {
                int_tags += 1;
            }
        }
    }

    // Exactly one callback param (apply's `cb`) → TAG_FN.
    assert_eq!(fn_tags, 1, "the JacCallback param must be tagged TAG_FN");
    // And the ctor's integer param proves non-callback params keep their scalar tag.
    assert_eq!(int_tags, 1, "the i64 ctor param must be tagged TAG_INT");
}

#[test]
fn borrowed_return_carries_borrow_bit() {
    // Phase S, Track B (S.1.4): a `#[jac(borrowed)]` method's return tag must OR in
    // TAG_BORROW_BIT on top of the Ref bit, while every other opaque return stays
    // owned (no ownership bit) — proving the class rides the tag append-only and
    // the default path is untouched.
    let blob: &[u8] = &__JAC_BRIDGE_META;
    let rd_u32 = |o: usize| -> u32 {
        u32::from_le_bytes([blob[o], blob[o + 1], blob[o + 2], blob[o + 3]])
    };
    let fns_off = rd_u32(48) as usize;
    let n_fns = rd_u32(52) as usize;

    let mut borrowed = 0u32;
    let mut shared = 0u32;
    let mut owned_refs = 0u32; // Ref returns with neither ownership bit
    for i in 0..n_fns {
        let ret = rd_u32(fns_off + i * 44 + 32);
        if ret == jac_bridge_schema::TAG_VOID {
            continue; // all-bits-set sentinel — not a Ref
        }
        if ret & jac_bridge_schema::TAG_REF_BIT == 0 {
            continue;
        }
        let b = ret & jac_bridge_schema::TAG_BORROW_BIT != 0;
        let s = ret & jac_bridge_schema::TAG_SHARED_BIT != 0;
        if b {
            borrowed += 1;
        } else if s {
            shared += 1;
        } else {
            owned_refs += 1;
        }
    }

    // Exactly `Cell::view` is borrowed; `Cell::new` (the `-> Self` ctor) is an
    // owned Ref; nothing is shared.
    assert_eq!(borrowed, 1, "Cell::view must carry TAG_BORROW_BIT");
    assert_eq!(shared, 0, "no method is annotated shared");
    assert!(owned_refs >= 1, "the ctor's Self return must stay owned (no bit)");
}
