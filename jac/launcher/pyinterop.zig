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
