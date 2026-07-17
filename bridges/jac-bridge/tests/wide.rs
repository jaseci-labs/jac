//! Runtime acceptance test for the serde wide lane (Phase 2, step 2.2).
//!
//! A `Wide<T>` param and a `Wide<T>` return cross the C boundary as a MessagePack
//! payload behind the single `TAG_WIDE` tag:
//!   * param  — `(payload_ptr, payload_len)`, decoded with `rmp_serde::from_slice`
//!              inside the shim's `catch_unwind` closure (a bad payload → status 1);
//!   * return — one owned `JacBuf`, produced by `rmp_serde::to_vec_named`, freed by
//!              the module's `free_buf` shim (same discipline as a `Vec<u8>` return).
//!
//! The bridge also carries a scalar (`i64`) param BESIDE the wide param to pin that
//! lane selection is per-value: the scalar stays a plain `u64` slot, unaffected by
//! its wide neighbour.
//!
//! Because `Wide<T>` is `#[serde(transparent)]`, the wire image of a `Wide<Point>`
//! is exactly `Point`'s own MessagePack document — so the test encodes/decodes plain
//! `Point` values and they interchange byte-for-byte with the bridge's `Wide<Point>`.

use jac_bridge::bridge;
use serde::{Deserialize, Serialize};

#[bridge(module = "widetest")]
mod b {
    use serde::{Deserialize, Serialize};

    #[derive(Serialize, Deserialize, Clone, PartialEq, Debug)]
    pub struct Point {
        pub x: i64,
        pub y: i64,
        pub label: String,
    }

    #[jac_error]
    pub struct WideError;

    pub struct Calc;

    impl Calc {
        pub fn new() -> Self {
            Calc
        }

        /// A `Wide<T>` param and a `Wide<T>` return, with a scalar param wedged
        /// between them to exercise per-value lane selection.
        pub fn shift(&self, p: Wide<Point>, dx: i64) -> Wide<Point> {
            let Point { x, y, label } = p.0;
            Wide(Point {
                x: x + dx,
                y: y + dx,
                label,
            })
        }

        /// A bulk wide param (`Vec<f64>`) reduced to a scalar return — the shape
        /// the 2.11 perf backstop times. `Vec<f64>` is the whitelisted wide std
        /// shape, so the whole vector crosses as one msgpack payload the shim
        /// decodes with `rmp_serde::from_slice`; the scalar `i64` return leaves on
        /// its own tag. Returns the element count so the caller can assert the
        /// full payload was decoded (not truncated).
        pub fn tally(&self, xs: Wide<Vec<f64>>) -> i64 {
            xs.0.len() as i64
        }
    }
}

// The rt module is emitted as a private sibling at crate root.
use __jac_bridge_widetest_rt::JacBuf;
use std::ptr;

#[derive(Serialize, Deserialize, Clone, PartialEq, Debug)]
struct Point {
    x: i64,
    y: i64,
    label: String,
}

// The `#[no_mangle] pub unsafe extern "C"` shims are emitted at this test crate's
// root by the `#[bridge]` macro, so they are called directly by name (no `extern`
// block — that would clash with the already-present definitions).

fn new_calc() -> u64 {
    let mut handle: u64 = 0;
    let mut err: u64 = 0;
    let st = unsafe { jac_widetest_Calc_new(&mut handle, &mut err) };
    assert_eq!(st, 0, "ctor status");
    assert_ne!(handle, 0, "ctor produced a null handle");
    handle
}

/// Copy a JacBuf's bytes out, then free it through the module's own free shim.
fn drain_buf(buf: JacBuf) -> Vec<u8> {
    let bytes = if buf.ptr.is_null() {
        Vec::new()
    } else {
        unsafe { std::slice::from_raw_parts(buf.ptr, buf.len as usize).to_vec() }
    };
    unsafe { jac_widetest_free_buf(buf) };
    bytes
}

#[test]
fn wide_roundtrip() {
    let handle = new_calc();

    let input = Point {
        x: 10,
        y: 20,
        // A non-ASCII, NUL-containing label proves the payload is length-delimited
        // binary (bin/str msgpack types), not a C string.
        label: "π\0é".to_string(),
    };
    let payload = rmp_serde::to_vec_named(&input).expect("encode input");

    let mut out_buf = JacBuf { ptr: ptr::null_mut(), len: 0, cap: 0 };
    let mut err: u64 = 0;
    let st = unsafe {
        jac_widetest_Calc_shift(
            handle,
            payload.as_ptr(),
            payload.len() as u32,
            5u64, // dx
            &mut out_buf,
            &mut err,
        )
    };
    assert_eq!(st, 0, "shift should succeed");
    assert_eq!(err, 0, "no error on success");

    let out_bytes = drain_buf(out_buf);
    let got: Point = rmp_serde::from_slice(&out_bytes).expect("decode output");
    assert_eq!(
        got,
        Point {
            x: 15,
            y: 25,
            label: "π\0é".to_string()
        },
        "wide param decoded, scalar applied, wide return re-encoded"
    );
}

#[test]
fn wide_bad_payload_is_status_1() {
    let handle = new_calc();

    // Not a valid MessagePack `Point`: 0xc1 is the reserved/never-used byte, which
    // rmp rejects immediately. The shim's `from_slice(..)?` must surface this as a
    // clean status-1 error handle — never a panic (status 2) or a bogus decode.
    let junk = [0xc1u8, 0x00, 0xff];

    let mut out_buf = JacBuf { ptr: ptr::null_mut(), len: 0, cap: 0 };
    let mut err: u64 = 0;
    let st = unsafe {
        jac_widetest_Calc_shift(handle, junk.as_ptr(), junk.len() as u32, 0u64, &mut out_buf, &mut err)
    };
    assert_eq!(st, 1, "malformed wide payload must be a graceful status 1");
    assert_ne!(err, 0, "status 1 must set an error message handle");
    assert!(out_buf.ptr.is_null(), "no output buffer on the error path");

    // The error message should name the msgpack decode failure.
    let mut msg_buf = JacBuf { ptr: ptr::null_mut(), len: 0, cap: 0 };
    let mut merr: u64 = 0;
    let mst = unsafe { jac_widetest_error_message(err, &mut msg_buf, &mut merr) };
    assert_eq!(mst, 0, "error_message status");
    let msg = String::from_utf8(drain_buf(msg_buf)).expect("utf-8 error message");
    assert!(
        msg.contains("msgpack decode"),
        "error message should name the decode failure, got: {msg:?}"
    );
    unsafe { jac_widetest_error_drop(err) };
}

/// 2.11 perf gate (wall-clock backstop half): a bulk `Vec<f64>` wide param
/// crossing the real macro-generated shim must stay well within a GENEROUS
/// ceiling. This is deliberately coarse -- it exists to catch a pathological
/// regression (an accidental per-element allocation, an O(n^2) decode, a
/// double-copy), not to measure microbenchmarks, so the ceiling is ~100x the
/// expected debug-build cost and the assertion only trips on a gross blow-up.
/// The deterministic lane-selection guard (a scalar signature must never emit
/// wide-lane calls) lives in the binder
/// (`tests::wide_lane::scalar_signatures_never_emit_wide_lane_calls`).
#[test]
fn wide_bulk_vec_f64_under_ceiling() {
    use std::time::Instant;

    let handle = new_calc();

    const N: usize = 10_000; // elements per payload
    const ITERS: usize = 100; // round-trips timed

    let xs: Vec<f64> = (0..N).map(|i| i as f64 * 0.5).collect();
    let payload = rmp_serde::to_vec_named(&xs).expect("encode Vec<f64>");

    let start = Instant::now();
    for _ in 0..ITERS {
        let mut out_int: u64 = 0;
        let mut err: u64 = 0;
        let st = unsafe {
            jac_widetest_Calc_tally(
                handle,
                payload.as_ptr(),
                payload.len() as u32,
                &mut out_int,
                &mut err,
            )
        };
        assert_eq!(st, 0, "tally should succeed");
        // The whole payload decoded -- not truncated at some fixed cap.
        assert_eq!(out_int as usize, N, "tally must see every element");
    }
    let elapsed = start.elapsed();

    // A generous ceiling: 100 round-trips of a 10k-element vector is a few
    // milliseconds of real work even in a debug build. 10 s is ~1000x that
    // headroom -- it fires only on a catastrophic regression, never on CI jitter.
    assert!(
        elapsed.as_secs() < 10,
        "wide bulk round-trip too slow: {ITERS} x {N} f64 took {elapsed:?} (ceiling 10s)"
    );
}
