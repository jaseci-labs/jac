//! pyinterop -- the high-level py-interop surface (Phase 3.1) layered on top of
//! the raw `jpy_` forwarders in pyembed.zig.
//!
//! Where pyembed.zig re-exports the CPython C-API 1:1 (thin `jpy_` forwarders the
//! 3.0 spike drove by hand, managing refcounts/GIL/format-strings itself), this
//! file is the *ergonomic* boundary the na `python.na.jac` wrapper (3.2) binds:
//! a small, FIXED set of `jac_py_*` calls that follow the same status-code + JacBuf
//! ownership conventions as the Rust bridges, so na-side code marshals Python the
//! same way it marshals a Rust bridge return. Two rules make that work:
//!
//!   * GIL is managed HERE, per call (`PyGILState_Ensure/Release`) -- callers never
//!     touch it. Ensure is reentrant/counted, so this is correct whether the caller
//!     already holds the GIL (main thread post-boot) or not, and cheap (~100 ns
//!     uncontended; marshaling dominates).
//!   * Fallible ops (`import`/`getattr`/`to_*`/`call`) return an `i32` status and
//!     write their result into a caller-owned out-slot, plus a trailing
//!     `out_err: *JacBuf` that receives the formatted Python exception text on the
//!     `ERR_PY` path (shim-allocated, `cap == len != 0` -- na reclaims it via
//!     `jac_py_free_buf`, exactly the JacBuf ownership rule the Rust bridges use).
//!     Infallible constructors (`from_*`, `none`) just return the new-ref handle
//!     directly (0 == allocation failure), since a PyObject constructor has no error
//!     channel worth a status code.
//!
//! Handles are `PyObject*` as na `int` (i64) -- the SysV integer class the pointer
//! shares on 64-bit (see pyembed.zig:37-40). Every handle this surface HANDS OUT is
//! a NEW reference the caller owns and must eventually `jac_py_decref` (including
//! `jac_py_none`, which increfs the singleton so the caller can decref uniformly).
//!
//! This file resolves the CPython symbols it needs into its OWN globals (via
//! `resolve`, called from `jac_engine_boot` after the base surface is up) rather
//! than sharing pyembed.zig's -- one-directional import (pyembed -> pyinterop), no
//! cross-file mutable-global coupling. The dlopen/dlsym itself still lives entirely
//! inside the shim (embed.zig owns the handle); na never sees a dlsym'd pointer.

const std = @import("std");
const embed = @import("embed.zig");

/// The Rust-bridge return buffer, byte-identical to `jac-bridge`'s `JacBuf`
/// (`ptr: *mut u8, len: u32, cap: u32`; the na side reads it as `struct("<QII")`).
/// A returned buffer with `cap != 0` is shim-allocated and the caller frees it via
/// `jac_py_free_buf`; `cap == 0` (and a null ptr) is the empty/none sentinel.
pub const JacBuf = extern struct { ptr: ?[*]u8, len: u32, cap: u32 };

const NULL_BUF: JacBuf = .{ .ptr = null, .len = 0, .cap = 0 };

// Status codes (match the Rust bridges' i32 convention: 0 == OK).
const OK: c_int = 0;
const ERR_PY: c_int = 1; // a Python exception was raised (text in out_err)
const ERR_USE: c_int = 2; // misuse: a null handle where an object was required

// ── CPython C-API typedefs this surface calls ────────────────────────────────
const PyGILStateEnsure_t = *const fn () callconv(.c) c_int;
const PyGILStateRelease_t = *const fn (s: c_int) callconv(.c) void;
const PyIncRef_t = *const fn (o: ?*anyopaque) callconv(.c) void;
const PyDecRef_t = *const fn (o: ?*anyopaque) callconv(.c) void;
const PyImportImportModule_t = *const fn (name: [*:0]const u8) callconv(.c) ?*anyopaque;
const PyObjectGetAttrString_t = *const fn (o: ?*anyopaque, name: [*:0]const u8) callconv(.c) ?*anyopaque;
const PyLongFromLongLong_t = *const fn (v: c_longlong) callconv(.c) ?*anyopaque;
const PyLongAsLongLong_t = *const fn (o: ?*anyopaque) callconv(.c) c_longlong;
const PyFloatFromDouble_t = *const fn (v: f64) callconv(.c) ?*anyopaque;
const PyFloatAsDouble_t = *const fn (o: ?*anyopaque) callconv(.c) f64;
const PyBoolFromLong_t = *const fn (v: c_long) callconv(.c) ?*anyopaque;
const PyUnicodeFromStringAndSize_t = *const fn (u: [*]const u8, len: isize) callconv(.c) ?*anyopaque;
const PyUnicodeAsUTF8AndSize_t = *const fn (o: ?*anyopaque, len: *isize) callconv(.c) ?[*]const u8;
const PyBytesFromStringAndSize_t = *const fn (v: [*]const u8, len: isize) callconv(.c) ?*anyopaque;
const PyBytesAsStringAndSize_t = *const fn (o: ?*anyopaque, buf: *?[*]const u8, len: *isize) callconv(.c) c_int;
const PyObjectIsTrue_t = *const fn (o: ?*anyopaque) callconv(.c) c_int;
const PyObjectStr_t = *const fn (o: ?*anyopaque) callconv(.c) ?*anyopaque;
const PyErrOccurred_t = *const fn () callconv(.c) ?*anyopaque;
const PyErrClear_t = *const fn () callconv(.c) void;
const PyErrFetch_t = *const fn (t: *?*anyopaque, v: *?*anyopaque, tb: *?*anyopaque) callconv(.c) void;
const PyErrNormalize_t = *const fn (t: *?*anyopaque, v: *?*anyopaque, tb: *?*anyopaque) callconv(.c) void;
// Stage B (`jac_py_call`): drive the injected `_jacpyi` codec + the actual call.
const PyRunSimpleString_t = *const fn (cmd: [*:0]const u8) callconv(.c) c_int;
const PyObjectCallOneArg_t = *const fn (callable: ?*anyopaque, arg: ?*anyopaque) callconv(.c) ?*anyopaque;
const PyObjectCall_t = *const fn (callable: ?*anyopaque, args: ?*anyopaque, kwargs: ?*anyopaque) callconv(.c) ?*anyopaque;
const PySequenceTuple_t = *const fn (o: ?*anyopaque) callconv(.c) ?*anyopaque;

var p_gil_ensure: PyGILStateEnsure_t = undefined;
var p_gil_release: PyGILStateRelease_t = undefined;
var p_incref: PyIncRef_t = undefined;
var p_decref: PyDecRef_t = undefined;
var p_import: PyImportImportModule_t = undefined;
var p_getattr: PyObjectGetAttrString_t = undefined;
var p_long_from: PyLongFromLongLong_t = undefined;
var p_long_as: PyLongAsLongLong_t = undefined;
var p_float_from: PyFloatFromDouble_t = undefined;
var p_float_as: PyFloatAsDouble_t = undefined;
var p_bool_from: PyBoolFromLong_t = undefined;
var p_uni_from: PyUnicodeFromStringAndSize_t = undefined;
var p_uni_utf8: PyUnicodeAsUTF8AndSize_t = undefined;
var p_bytes_from: PyBytesFromStringAndSize_t = undefined;
var p_bytes_as: PyBytesAsStringAndSize_t = undefined;
var p_is_true: PyObjectIsTrue_t = undefined;
var p_obj_str: PyObjectStr_t = undefined;
var p_err_occurred: PyErrOccurred_t = undefined;
var p_err_clear: PyErrClear_t = undefined;
var p_err_fetch: PyErrFetch_t = undefined;
var p_err_normalize: PyErrNormalize_t = undefined;
// `Py_None` is a DATA symbol: dlsym("_Py_NoneStruct") returns the address OF the
// singleton, i.e. the `PyObject*` for None itself.
var p_none: ?*anyopaque = undefined;
var p_run_simple: PyRunSimpleString_t = undefined;
var p_call_one: PyObjectCallOneArg_t = undefined;
var p_call: PyObjectCall_t = undefined;
var p_seq_tuple: PySequenceTuple_t = undefined;

// Stage B lazy bootstrap: the `_jacpyi._decode`/`_encode` callables (owned
// forever once resolved) and the one-shot install latch. Lazy so a host that
// boots the engine but never calls Python pays no codec-injection cost.
var p_decode: ?*anyopaque = null;
var p_encode: ?*anyopaque = null;
var bootstrap_failed: bool = false;

/// Resolve the C-API this surface needs. Called from `jac_engine_boot` after the
/// base forwarder surface is resolved; returns false (never crashes) on a missing
/// symbol so the host can surface a clean packaging error. GIL not required here
/// (dlsym only) -- the interpreter is initialized but these are plain lookups.
pub fn resolve(emb: *const embed.Embed) bool {
    p_gil_ensure = emb.sym(PyGILStateEnsure_t, "PyGILState_Ensure") orelse return false;
    p_gil_release = emb.sym(PyGILStateRelease_t, "PyGILState_Release") orelse return false;
    p_incref = emb.sym(PyIncRef_t, "Py_IncRef") orelse return false;
    p_decref = emb.sym(PyDecRef_t, "Py_DecRef") orelse return false;
    p_import = emb.sym(PyImportImportModule_t, "PyImport_ImportModule") orelse return false;
    p_getattr = emb.sym(PyObjectGetAttrString_t, "PyObject_GetAttrString") orelse return false;
    p_long_from = emb.sym(PyLongFromLongLong_t, "PyLong_FromLongLong") orelse return false;
    p_long_as = emb.sym(PyLongAsLongLong_t, "PyLong_AsLongLong") orelse return false;
    p_float_from = emb.sym(PyFloatFromDouble_t, "PyFloat_FromDouble") orelse return false;
    p_float_as = emb.sym(PyFloatAsDouble_t, "PyFloat_AsDouble") orelse return false;
    p_bool_from = emb.sym(PyBoolFromLong_t, "PyBool_FromLong") orelse return false;
    p_uni_from = emb.sym(PyUnicodeFromStringAndSize_t, "PyUnicode_FromStringAndSize") orelse return false;
    p_uni_utf8 = emb.sym(PyUnicodeAsUTF8AndSize_t, "PyUnicode_AsUTF8AndSize") orelse return false;
    p_bytes_from = emb.sym(PyBytesFromStringAndSize_t, "PyBytes_FromStringAndSize") orelse return false;
    p_bytes_as = emb.sym(PyBytesAsStringAndSize_t, "PyBytes_AsStringAndSize") orelse return false;
    p_is_true = emb.sym(PyObjectIsTrue_t, "PyObject_IsTrue") orelse return false;
    p_obj_str = emb.sym(PyObjectStr_t, "PyObject_Str") orelse return false;
    p_err_occurred = emb.sym(PyErrOccurred_t, "PyErr_Occurred") orelse return false;
    p_err_clear = emb.sym(PyErrClear_t, "PyErr_Clear") orelse return false;
    p_err_fetch = emb.sym(PyErrFetch_t, "PyErr_Fetch") orelse return false;
    p_err_normalize = emb.sym(PyErrNormalize_t, "PyErr_NormalizeException") orelse return false;
    p_none = emb.sym(*anyopaque, "_Py_NoneStruct") orelse return false;
    p_run_simple = emb.sym(PyRunSimpleString_t, "PyRun_SimpleString") orelse return false;
    p_call_one = emb.sym(PyObjectCallOneArg_t, "PyObject_CallOneArg") orelse return false;
    p_call = emb.sym(PyObjectCall_t, "PyObject_Call") orelse return false;
    p_seq_tuple = emb.sym(PySequenceTuple_t, "PySequence_Tuple") orelse return false;
    return true;
}

// ── internal helpers (all assume the GIL is held) ────────────────────────────

/// Copy `bytes` into a fresh libc-`malloc`'d JacBuf the caller frees via
/// `jac_py_free_buf`. Empty input (or OOM) yields the null/empty sentinel.
fn allocBuf(bytes: []const u8) JacBuf {
    if (bytes.len == 0) return NULL_BUF;
    const raw = std.c.malloc(bytes.len) orelse return NULL_BUF;
    const dst: [*]u8 = @ptrCast(raw);
    @memcpy(dst[0..bytes.len], bytes);
    return .{ .ptr = dst, .len = @intCast(bytes.len), .cap = @intCast(bytes.len) };
}

/// Drain the pending Python exception into `out_err` as `str(value)` UTF-8 and
/// clear it. Always returns `ERR_PY`; if the message can't be materialized,
/// `out_err` is left as the null sentinel (status still signals the failure).
fn captureErr(out_err: *JacBuf) c_int {
    var t: ?*anyopaque = null;
    var v: ?*anyopaque = null;
    var tb: ?*anyopaque = null;
    p_err_fetch(&t, &v, &tb);
    p_err_normalize(&t, &v, &tb);
    if (v) |val| {
        if (p_obj_str(val)) |sv| {
            var n: isize = 0;
            if (p_uni_utf8(sv, &n)) |u| {
                if (n > 0) out_err.* = allocBuf(u[0..@intCast(n)]);
            }
            p_decref(sv);
        }
    }
    if (t) |x| p_decref(x);
    if (v) |x| p_decref(x);
    if (tb) |x| p_decref(x);
    p_err_clear();
    return ERR_PY;
}

/// Inject the `_jacpyi` msgpack codec module (once) and resolve its
/// `_decode`/`_encode` callables. Lazy: called from the first `jac_py_call*`.
/// Assumes the GIL is held. Latches on failure so a broken bootstrap doesn't
/// re-run every call. Returns false with `out_err` populated on failure.
fn ensureBootstrap(out_err: *JacBuf) bool {
    if (p_decode != null) return true;
    if (bootstrap_failed) {
        out_err.* = allocBuf("jac_py_call: py-interop bootstrap previously failed");
        return false;
    }
    if (p_run_simple(BOOTSTRAP_PY) != 0) {
        bootstrap_failed = true;
        _ = captureErr(out_err);
        return false;
    }
    const m = p_import("_jacpyi");
    if (m == null) {
        bootstrap_failed = true;
        _ = captureErr(out_err);
        return false;
    }
    const dec = p_getattr(m, "_decode");
    const enc = p_getattr(m, "_encode");
    p_decref(m);
    if (dec == null or enc == null) {
        if (dec) |d| p_decref(d);
        if (enc) |e| p_decref(e);
        bootstrap_failed = true;
        _ = captureErr(out_err);
        return false;
    }
    p_decode = dec;
    p_encode = enc;
    return true;
}

/// Decode the msgpack arg blob to a Python arg tuple, call `callable(*args)`, and
/// return the result as a NEW reference (or null with `out_err` set). Assumes the
/// GIL is held. The arg blob MUST be a msgpack array (`packb([])` for no args).
fn callCommon(callable: ?*anyopaque, args_ptr: [*]const u8, args_len: usize, out_err: *JacBuf) ?*anyopaque {
    if (!ensureBootstrap(out_err)) return null;
    const args_obj = p_bytes_from(args_ptr, @intCast(args_len));
    if (args_obj == null) {
        _ = captureErr(out_err);
        return null;
    }
    const arglist = p_call_one(p_decode, args_obj); // -> a Python list
    p_decref(args_obj);
    if (arglist == null) {
        _ = captureErr(out_err);
        return null;
    }
    const argtuple = p_seq_tuple(arglist);
    p_decref(arglist);
    if (argtuple == null) {
        _ = captureErr(out_err);
        return null;
    }
    const result = p_call(callable, argtuple, null);
    p_decref(argtuple);
    if (result == null) {
        _ = captureErr(out_err);
        return null;
    }
    return result;
}

// ── exported surface ─────────────────────────────────────────────────────────

/// Import a module by (NUL-terminated) name. New-ref handle -> `*out_handle`.
export fn jac_py_import(name: [*:0]const u8, out_handle: *u64, out_err: *JacBuf) c_int {
    out_handle.* = 0;
    out_err.* = NULL_BUF;
    const g = p_gil_ensure();
    defer p_gil_release(g);
    const m = p_import(name);
    if (m == null) return captureErr(out_err);
    out_handle.* = @intFromPtr(m);
    return OK;
}

/// `getattr(obj, name)`. New-ref handle -> `*out_handle`.
export fn jac_py_getattr(obj: ?*anyopaque, name: [*:0]const u8, out_handle: *u64, out_err: *JacBuf) c_int {
    out_handle.* = 0;
    out_err.* = NULL_BUF;
    if (obj == null) return ERR_USE;
    const g = p_gil_ensure();
    defer p_gil_release(g);
    const a = p_getattr(obj, name);
    if (a == null) return captureErr(out_err);
    out_handle.* = @intFromPtr(a);
    return OK;
}

/// Build a Python `int` from an na `int`. Returns a new-ref handle (0 on failure).
export fn jac_py_from_int(v: i64) u64 {
    const g = p_gil_ensure();
    defer p_gil_release(g);
    return @intFromPtr(p_long_from(@intCast(v)));
}

/// Build a Python `float` from an na `float`. New-ref handle (0 on failure).
export fn jac_py_from_float(v: f64) u64 {
    const g = p_gil_ensure();
    defer p_gil_release(g);
    return @intFromPtr(p_float_from(v));
}

/// Build a Python `bool` (`v != 0`). New-ref handle (0 on failure).
export fn jac_py_from_bool(v: c_int) u64 {
    const g = p_gil_ensure();
    defer p_gil_release(g);
    return @intFromPtr(p_bool_from(if (v != 0) 1 else 0));
}

/// Build a Python `str` from `len` UTF-8 bytes. New-ref handle (0 on failure).
export fn jac_py_from_str(ptr: [*]const u8, len: usize) u64 {
    const g = p_gil_ensure();
    defer p_gil_release(g);
    return @intFromPtr(p_uni_from(ptr, @intCast(len)));
}

/// Build a Python `bytes` from `len` bytes. New-ref handle (0 on failure).
export fn jac_py_from_bytes(ptr: [*]const u8, len: usize) u64 {
    const g = p_gil_ensure();
    defer p_gil_release(g);
    return @intFromPtr(p_bytes_from(ptr, @intCast(len)));
}

/// A new reference to the `None` singleton (so the caller decrefs uniformly).
export fn jac_py_none() u64 {
    const g = p_gil_ensure();
    defer p_gil_release(g);
    p_incref(p_none);
    return @intFromPtr(p_none);
}

/// Coerce a handle to an na `int` (`PyLong_AsLongLong`; accepts any int-like).
export fn jac_py_to_int(obj: ?*anyopaque, out_val: *i64, out_err: *JacBuf) c_int {
    out_val.* = 0;
    out_err.* = NULL_BUF;
    if (obj == null) return ERR_USE;
    const g = p_gil_ensure();
    defer p_gil_release(g);
    const r = p_long_as(obj);
    // -1 is a legitimate value; only an actually-set exception is an error.
    if (r == -1 and p_err_occurred() != null) return captureErr(out_err);
    out_val.* = @intCast(r);
    return OK;
}

/// Coerce a handle to an na `float` (`PyFloat_AsDouble`; accepts any float-like).
export fn jac_py_to_float(obj: ?*anyopaque, out_val: *f64, out_err: *JacBuf) c_int {
    out_val.* = 0;
    out_err.* = NULL_BUF;
    if (obj == null) return ERR_USE;
    const g = p_gil_ensure();
    defer p_gil_release(g);
    const r = p_float_as(obj);
    if (r == -1.0 and p_err_occurred() != null) return captureErr(out_err);
    out_val.* = r;
    return OK;
}

/// Truthiness of a handle (`PyObject_IsTrue`) as `0`/`1` into `*out_val`.
export fn jac_py_to_bool(obj: ?*anyopaque, out_val: *c_int, out_err: *JacBuf) c_int {
    out_val.* = 0;
    out_err.* = NULL_BUF;
    if (obj == null) return ERR_USE;
    const g = p_gil_ensure();
    defer p_gil_release(g);
    const r = p_is_true(obj);
    if (r < 0) return captureErr(out_err);
    out_val.* = r;
    return OK;
}

/// UTF-8 of `str(obj)`... no: of the str object itself (`PyUnicode_AsUTF8AndSize`)
/// copied into a fresh JacBuf. `obj` must be a `str`; a non-str raises, surfaced as
/// `ERR_PY`. (Use `to_str` on a handle you already coerced with `str()`.)
export fn jac_py_to_str(obj: ?*anyopaque, out_val: *JacBuf, out_err: *JacBuf) c_int {
    out_val.* = NULL_BUF;
    out_err.* = NULL_BUF;
    if (obj == null) return ERR_USE;
    const g = p_gil_ensure();
    defer p_gil_release(g);
    var n: isize = 0;
    const u = p_uni_utf8(obj, &n);
    if (u == null) return captureErr(out_err);
    // AsUTF8AndSize returns a pointer into obj's own buffer; copy before releasing.
    out_val.* = allocBuf(u.?[0..@intCast(n)]);
    return OK;
}

/// Raw bytes of a `bytes` handle (`PyBytes_AsStringAndSize`) into a fresh JacBuf.
export fn jac_py_to_bytes(obj: ?*anyopaque, out_val: *JacBuf, out_err: *JacBuf) c_int {
    out_val.* = NULL_BUF;
    out_err.* = NULL_BUF;
    if (obj == null) return ERR_USE;
    const g = p_gil_ensure();
    defer p_gil_release(g);
    var buf: ?[*]const u8 = null;
    var n: isize = 0;
    if (p_bytes_as(obj, &buf, &n) != 0) return captureErr(out_err);
    if (buf) |b| out_val.* = allocBuf(b[0..@intCast(n)]);
    return OK;
}

/// Call `callable(*args)` where `args` is a msgpack array blob, returning the
/// result as a msgpack blob in `out_val` (scalar or container-of-scalars). A
/// non-encodable result (an arbitrary object) raises -> `ERR_PY`; use
/// `jac_py_call_h` for object results. `args` MUST be a msgpack array.
export fn jac_py_call(callable: ?*anyopaque, args_ptr: [*]const u8, args_len: usize, out_val: *JacBuf, out_err: *JacBuf) c_int {
    out_val.* = NULL_BUF;
    out_err.* = NULL_BUF;
    if (callable == null) return ERR_USE;
    const g = p_gil_ensure();
    defer p_gil_release(g);
    const result = callCommon(callable, args_ptr, args_len, out_err) orelse return ERR_PY;
    const enc = p_call_one(p_encode, result); // -> a Python `bytes`
    p_decref(result);
    if (enc == null) return captureErr(out_err); // non-encodable result
    var buf: ?[*]const u8 = null;
    var n: isize = 0;
    if (p_bytes_as(enc, &buf, &n) != 0) {
        p_decref(enc);
        return captureErr(out_err);
    }
    if (buf) |b| out_val.* = allocBuf(b[0..@intCast(n)]);
    p_decref(enc);
    return OK;
}

/// Call `callable(*args)` (msgpack array blob) and return the result as a new-ref
/// handle -> `*out_handle`. The general path (objects, DataFrames, ...); the
/// caller `jac_py_decref`s the handle. `args` MUST be a msgpack array.
export fn jac_py_call_h(callable: ?*anyopaque, args_ptr: [*]const u8, args_len: usize, out_handle: *u64, out_err: *JacBuf) c_int {
    out_handle.* = 0;
    out_err.* = NULL_BUF;
    if (callable == null) return ERR_USE;
    const g = p_gil_ensure();
    defer p_gil_release(g);
    const result = callCommon(callable, args_ptr, args_len, out_err) orelse return ERR_PY;
    out_handle.* = @intFromPtr(result);
    return OK;
}

/// Bump a handle's refcount (a second na wrapper adopting the same object).
export fn jac_py_incref(obj: ?*anyopaque) void {
    if (obj == null) return;
    const g = p_gil_ensure();
    defer p_gil_release(g);
    p_incref(obj);
}

/// Drop a handle's refcount -- the na wrapper's `__del__`. GIL-guarded because the
/// last decref runs the object's destructor.
export fn jac_py_decref(obj: ?*anyopaque) void {
    if (obj == null) return;
    const g = p_gil_ensure();
    defer p_gil_release(g);
    p_decref(obj);
}

/// Free a JacBuf this surface handed out (`cap != 0`). No GIL: plain libc free.
export fn jac_py_free_buf(ptr: ?*anyopaque) void {
    if (ptr) |p| std.c.free(p);
}

// The Python codec injected on first `jac_py_call*` (see ensureBootstrap).
// A throwaway installer defines a msgpack subset codec as nested closures and
// registers module `_jacpyi` with `_decode`/`_encode`, then deletes itself --
// no __main__ pollution. The wire format is standard MessagePack, byte-identical
// to the wide lane's, and differential-tested against the `msgpack` package on
// CPython 3.14 (the bundled pbs version). Value shapes: None/bool/int/float/
// str/bytes + list/dict.
const BOOTSTRAP_PY =
    \\def _jpi_install():
    \\    import sys, struct as _st, types
    \\
    \\    def _decode(buf):
    \\        v, off = _dec(buf, 0)
    \\        return v
    \\
    \\    def _dec(b, off):
    \\        c = b[off]
    \\        off += 1
    \\        if c <= 0x7F:
    \\            return c, off
    \\        if c >= 0xE0:
    \\            return c - 0x100, off
    \\        if 0x80 <= c <= 0x8F:
    \\            return _dec_map(b, off, c & 0x0F)
    \\        if 0x90 <= c <= 0x9F:
    \\            return _dec_arr(b, off, c & 0x0F)
    \\        if 0xA0 <= c <= 0xBF:
    \\            n = c & 0x1F
    \\            return b[off:off + n].decode("utf-8"), off + n
    \\        if c == 0xC0:
    \\            return None, off
    \\        if c == 0xC2:
    \\            return False, off
    \\        if c == 0xC3:
    \\            return True, off
    \\        if c == 0xC4 or c == 0xC5 or c == 0xC6:
    \\            n, off = _dec_len(b, off, 1 << (c - 0xC4))
    \\            return bytes(b[off:off + n]), off + n
    \\        if c == 0xCA:
    \\            (f,) = _st.unpack_from(">f", b, off)
    \\            return f, off + 4
    \\        if c == 0xCB:
    \\            (f,) = _st.unpack_from(">d", b, off)
    \\            return f, off + 8
    \\        if 0xCC <= c <= 0xCF:
    \\            return _dec_uint(b, off, 1 << (c - 0xCC))
    \\        if 0xD0 <= c <= 0xD3:
    \\            return _dec_int(b, off, 1 << (c - 0xD0))
    \\        if c == 0xD9 or c == 0xDA or c == 0xDB:
    \\            n, off = _dec_len(b, off, 1 << (c - 0xD9))
    \\            return b[off:off + n].decode("utf-8"), off + n
    \\        if c == 0xDC:
    \\            (n,) = _st.unpack_from(">H", b, off)
    \\            return _dec_arr(b, off + 2, n)
    \\        if c == 0xDD:
    \\            (n,) = _st.unpack_from(">I", b, off)
    \\            return _dec_arr(b, off + 4, n)
    \\        if c == 0xDE:
    \\            (n,) = _st.unpack_from(">H", b, off)
    \\            return _dec_map(b, off + 2, n)
    \\        if c == 0xDF:
    \\            (n,) = _st.unpack_from(">I", b, off)
    \\            return _dec_map(b, off + 4, n)
    \\        raise ValueError("jac_py: bad msgpack lead 0x%02x" % c)
    \\
    \\    def _dec_len(b, off, width):
    \\        if width == 1:
    \\            return b[off], off + 1
    \\        if width == 2:
    \\            (n,) = _st.unpack_from(">H", b, off)
    \\            return n, off + 2
    \\        (n,) = _st.unpack_from(">I", b, off)
    \\        return n, off + 4
    \\
    \\    def _dec_uint(b, off, width):
    \\        fmt = {1: ">B", 2: ">H", 4: ">I", 8: ">Q"}[width]
    \\        (n,) = _st.unpack_from(fmt, b, off)
    \\        return n, off + width
    \\
    \\    def _dec_int(b, off, width):
    \\        fmt = {1: ">b", 2: ">h", 4: ">i", 8: ">q"}[width]
    \\        (n,) = _st.unpack_from(fmt, b, off)
    \\        return n, off + width
    \\
    \\    def _dec_arr(b, off, n):
    \\        out = []
    \\        i = 0
    \\        while i < n:
    \\            v, off = _dec(b, off)
    \\            out.append(v)
    \\            i += 1
    \\        return out, off
    \\
    \\    def _dec_map(b, off, n):
    \\        out = {}
    \\        i = 0
    \\        while i < n:
    \\            k, off = _dec(b, off)
    \\            v, off = _dec(b, off)
    \\            out[k] = v
    \\            i += 1
    \\        return out, off
    \\
    \\    def _encode(v):
    \\        out = bytearray()
    \\        _enc(v, out)
    \\        return bytes(out)
    \\
    \\    def _enc(v, out):
    \\        if v is None:
    \\            out.append(0xC0)
    \\        elif v is True:
    \\            out.append(0xC3)
    \\        elif v is False:
    \\            out.append(0xC2)
    \\        elif isinstance(v, int):
    \\            _enc_int(v, out)
    \\        elif isinstance(v, float):
    \\            out.append(0xCB)
    \\            out += _st.pack(">d", v)
    \\        elif isinstance(v, str):
    \\            _enc_str(v, out)
    \\        elif isinstance(v, (bytes, bytearray)):
    \\            _enc_bin(v, out)
    \\        elif isinstance(v, (list, tuple)):
    \\            _enc_len(out, len(v), 0x90, 0xDC, 0xDD)
    \\            for e in v:
    \\                _enc(e, out)
    \\        elif isinstance(v, dict):
    \\            _enc_len(out, len(v), 0x80, 0xDE, 0xDF)
    \\            for k, val in v.items():
    \\                _enc(k, out)
    \\                _enc(val, out)
    \\        else:
    \\            raise TypeError("jac_py_call: non-encodable result %r" % type(v).__name__)
    \\
    \\    def _enc_int(v, out):
    \\        if 0 <= v <= 0x7F:
    \\            out.append(v)
    \\        elif -32 <= v < 0:
    \\            out.append(v + 0x100)
    \\        elif 0 <= v <= 0xFFFFFFFFFFFFFFFF:
    \\            out.append(0xCF)
    \\            out += _st.pack(">Q", v)
    \\        elif -(1 << 63) <= v < 0:
    \\            out.append(0xD3)
    \\            out += _st.pack(">q", v)
    \\        else:
    \\            raise OverflowError("jac_py_call: int out of 64-bit range")
    \\
    \\    def _enc_str(v, out):
    \\        data = v.encode("utf-8")
    \\        n = len(data)
    \\        if n <= 0x1F:
    \\            out.append(0xA0 | n)
    \\        else:
    \\            _enc_len_only(out, n, 0xD9, 0xDA, 0xDB)
    \\        out += data
    \\
    \\    def _enc_bin(v, out):
    \\        n = len(v)
    \\        _enc_len_only(out, n, 0xC4, 0xC5, 0xC6)
    \\        out += bytes(v)
    \\
    \\    def _enc_len(out, n, fix_base, tag16, tag32):
    \\        if n <= 0x0F:
    \\            out.append(fix_base | n)
    \\        elif n <= 0xFFFF:
    \\            out.append(tag16)
    \\            out += _st.pack(">H", n)
    \\        else:
    \\            out.append(tag32)
    \\            out += _st.pack(">I", n)
    \\
    \\    def _enc_len_only(out, n, tag8, tag16, tag32):
    \\        if n <= 0xFF:
    \\            out.append(tag8)
    \\            out.append(n)
    \\        elif n <= 0xFFFF:
    \\            out.append(tag16)
    \\            out += _st.pack(">H", n)
    \\        else:
    \\            out.append(tag32)
    \\            out += _st.pack(">I", n)
    \\
    \\    m = types.ModuleType("_jacpyi")
    \\    m._decode = _decode
    \\    m._encode = _encode
    \\    sys.modules["_jacpyi"] = m
    \\
    \\
    \\_jpi_install()
    \\del _jpi_install
;
