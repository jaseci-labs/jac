//! libjacpyembed -- the C-ABI bridge that lets the `na` desktop host run on the
//! SAME fused runtime the `jac` CLI ships, instead of binding the build machine's
//! libpython by soname.
//!
//! The `na` native compiler links foreign symbols as link-time DT_NEEDED and
//! cannot cast a dlsym'd pointer to a callable, so the dlopen/dlsym/forwarding
//! that bringing up the bundled CPython requires can't live in `na`. It lives
//! here, in one shared library the host DT_NEEDEDs:
//!
//!   * `jac_engine_boot()` runs the shared bring-up (embed.zig: materialize the
//!     trailer payload -> dlopen the bundled libpython -> PEP 741 config init,
//!     hermetic + env-leak-free), then resolves the CPython C-API the host
//!     calls into module globals. No path args: the shim resolves its own process
//!     image (/proc/self/exe), which is the host binary carrying the trailer.
//!   * `jpy_`-PREFIXED thin forwarders (`jpy_PyRun_SimpleString`, ...) re-export
//!     the surface `_host_bootstrap.jac` declares; the host DT_NEEDEDs libjacpyembed
//!     (never libpython) and binds these at load, each calling the real symbol
//!     through the pointer resolved at boot. The prefix is LOAD-BEARING: a
//!     same-named export (`PyRun_SimpleString`) would, under Linux's flat namespace
//!     + the RTLD_GLOBAL libpython dlopen, INTERPOSE libpython's own symbol -- so
//!     libpython's internal calls (e.g. PyUnicode_FromString during Py_Initialize)
//!     would route through this shim's forwarder before its pointer is resolved and
//!     segfault on a null call. macOS's two-level namespace hid this; the prefix
//!     makes the shim's symbols never collide with libpython's on any platform.
//!
//! This is the desktop half of the "one source of responsibility" split: the
//! interpreter bring-up is embed.zig (shared with launcher.zig); the bundling is
//! the trailer payload (shared with pack.zig); this file only adapts that core to
//! the na host's C-ABI calling convention.

const std = @import("std");
const builtin = @import("builtin");
const embed = @import("embed.zig");

const MAX_PATH = std.Io.Dir.max_path_bytes;

// ── CPython C-API typedefs (the surface _host_bootstrap.jac imports) ─────────
// `na` passes its `int` (i64) for every PyObject*/handle and its `str` for char*;
// on 64-bit those share the SysV integer-class ABI with the pointer types below,
// so the forwarder signatures are call-compatible with the host's declarations.
const PyFinalize_t = *const fn () callconv(.c) void;
const PyRunSimpleString_t = *const fn (cmd: [*:0]const u8) callconv(.c) c_int;
const PyImportAddModule_t = *const fn (name: [*:0]const u8) callconv(.c) ?*anyopaque;
const PyModuleGetDict_t = *const fn (m: ?*anyopaque) callconv(.c) ?*anyopaque;
const PyRunString_t = *const fn (s: [*:0]const u8, start: c_int, g: ?*anyopaque, l: ?*anyopaque) callconv(.c) ?*anyopaque;
const PyLongAsLong_t = *const fn (o: ?*anyopaque) callconv(.c) c_long;
const PyEvalSaveThread_t = *const fn () callconv(.c) ?*anyopaque;
const PyEvalRestoreThread_t = *const fn (s: ?*anyopaque) callconv(.c) void;
const PyGILStateEnsure_t = *const fn () callconv(.c) c_int;
const PyGILStateRelease_t = *const fn (s: c_int) callconv(.c) void;
const PyObjectCallOneArg_t = *const fn (callable: ?*anyopaque, arg: ?*anyopaque) callconv(.c) ?*anyopaque;
const PyUnicodeFromString_t = *const fn (s: [*:0]const u8) callconv(.c) ?*anyopaque;
const PyUnicodeAsUTF8_t = *const fn (o: ?*anyopaque) callconv(.c) ?[*:0]const u8;
const PyDecRef_t = *const fn (o: ?*anyopaque) callconv(.c) void;

// ── Boot state ──────────────────────────────────────────────────────────────
// `rt_buf` backs the materialized-tree slice and must outlive boot (the
// interpreter runs for the process lifetime), so it is a module global.
var rt_buf: [MAX_PATH]u8 = undefined;
var booted: bool = false;

var p_finalize: PyFinalize_t = undefined;
var p_run_simple: PyRunSimpleString_t = undefined;
var p_add_module: PyImportAddModule_t = undefined;
var p_get_dict: PyModuleGetDict_t = undefined;
var p_run_string: PyRunString_t = undefined;
var p_long_aslong: PyLongAsLong_t = undefined;
var p_save_thread: PyEvalSaveThread_t = undefined;
var p_restore_thread: PyEvalRestoreThread_t = undefined;
var p_gil_ensure: PyGILStateEnsure_t = undefined;
var p_gil_release: PyGILStateRelease_t = undefined;
var p_call_one: PyObjectCallOneArg_t = undefined;
var p_uni_from: PyUnicodeFromString_t = undefined;
var p_uni_utf8: PyUnicodeAsUTF8_t = undefined;
var p_decref: PyDecRef_t = undefined;

fn fail(comptime msg: []const u8) c_int {
    std.debug.print("libjacpyembed: {s}\n", .{msg});
    return 1;
}

/// Bring up the embedded interpreter on the fused runtime and resolve the C-API
/// the host calls. Idempotent. Returns 0 on success, non-zero on failure (the
/// host shows its native boot-error page when this is non-zero -- it must never
/// crash the process).
export fn jac_engine_boot() c_int {
    if (booted) return 0;

    // A properly-initialized blocking Io. The launcher gets its `io` from the Zig
    // runtime's std.process.Init; this shim has no such entry point, so build a
    // real Threaded instance (cpu-count + signal handlers + worker pool). The
    // static `init_single_threaded` const skips that setup and segfaults blocking
    // file I/O (materialize/executablePath) on Linux -- works on macOS by luck.
    const gpa = std.heap.c_allocator;
    var threaded = std.Io.Threaded.init(gpa, .{});
    const io = threaded.io();

    // The shim runs inside the host process, so its own image IS the host binary
    // (which carries the trailer payload). Resolve it for materialize + getpath.
    var exe_buf: [MAX_PATH]u8 = undefined;
    const exe_len = std.process.executablePath(io, &exe_buf) catch return fail("cannot resolve executable path");
    const exe_path = exe_buf[0..exe_len];
    var exe_zbuf: [MAX_PATH]u8 = undefined;
    const exe_z = std.fmt.bufPrintZ(&exe_zbuf, "{s}", .{exe_path}) catch return fail("executable path too long");

    const emb = embed.open(
        io,
        gpa,
        exe_path,
        exe_z,
        envOpt("XDG_CACHE_HOME"),
        envOpt("HOME"),
        envOpt("TMPDIR"),
        @intCast(std.c.getuid()),
        @intCast(std.c.getpid()),
        &rt_buf,
    ) catch return fail("runtime bring-up failed (trailer payload not materialized?)");

    // Initialize via the shared PEP 741 config path (program-name pin, hermetic
    // home/paths -- config values, never env, so nothing leaks to children,
    // #7047). embed owns dlopen/init; the host owns what runs after init
    // (SERVE/PLUGIN/DISPATCH), via the forwarders below. No argv: the embedded
    // host keeps CPython's `sys.argv == ['']` default, as before.
    // No argv is passed (parse_argv stays off), so CPython never processes a
    // print-and-exit flag here; a non-null exit request would mean the interpreter
    // refused to come up, which for the desktop host is an init failure.
    if (emb.initInterpreter(exe_z, .{}) catch return fail("interpreter initialization failed")) |_| {
        return fail("interpreter initialization failed");
    }

    // Resolve the host-facing C-API once. A missing symbol here is a packaging
    // bug; surface it cleanly rather than faulting on first forwarded call.
    p_finalize = emb.symOrErr(PyFinalize_t, "Py_Finalize") catch return fail("missing Py_Finalize");
    p_run_simple = emb.symOrErr(PyRunSimpleString_t, "PyRun_SimpleString") catch return fail("missing PyRun_SimpleString");
    p_add_module = emb.symOrErr(PyImportAddModule_t, "PyImport_AddModule") catch return fail("missing PyImport_AddModule");
    p_get_dict = emb.symOrErr(PyModuleGetDict_t, "PyModule_GetDict") catch return fail("missing PyModule_GetDict");
    p_run_string = emb.symOrErr(PyRunString_t, "PyRun_String") catch return fail("missing PyRun_String");
    p_long_aslong = emb.symOrErr(PyLongAsLong_t, "PyLong_AsLong") catch return fail("missing PyLong_AsLong");
    p_save_thread = emb.symOrErr(PyEvalSaveThread_t, "PyEval_SaveThread") catch return fail("missing PyEval_SaveThread");
    p_restore_thread = emb.symOrErr(PyEvalRestoreThread_t, "PyEval_RestoreThread") catch return fail("missing PyEval_RestoreThread");
    p_gil_ensure = emb.symOrErr(PyGILStateEnsure_t, "PyGILState_Ensure") catch return fail("missing PyGILState_Ensure");
    p_gil_release = emb.symOrErr(PyGILStateRelease_t, "PyGILState_Release") catch return fail("missing PyGILState_Release");
    p_call_one = emb.symOrErr(PyObjectCallOneArg_t, "PyObject_CallOneArg") catch return fail("missing PyObject_CallOneArg");
    p_uni_from = emb.symOrErr(PyUnicodeFromString_t, "PyUnicode_FromString") catch return fail("missing PyUnicode_FromString");
    p_uni_utf8 = emb.symOrErr(PyUnicodeAsUTF8_t, "PyUnicode_AsUTF8") catch return fail("missing PyUnicode_AsUTF8");
    p_decref = emb.symOrErr(PyDecRef_t, "Py_DecRef") catch return fail("missing Py_DecRef");

    booted = true;
    return 0;
}

/// `std.posix.getenv`-style lookup returning an optional slice for embed.open.
fn envOpt(name: [:0]const u8) ?[]const u8 {
    const v = std.c.getenv(name.ptr) orelse return null;
    return std.mem.span(v);
}

// ── Forwarders: same names the host DT_NEEDEDs; call the resolved real symbol ─
export fn jpy_Py_Finalize() void {
    p_finalize();
}
export fn jpy_PyRun_SimpleString(cmd: [*:0]const u8) c_int {
    return p_run_simple(cmd);
}
export fn jpy_PyImport_AddModule(name: [*:0]const u8) ?*anyopaque {
    return p_add_module(name);
}
export fn jpy_PyModule_GetDict(m: ?*anyopaque) ?*anyopaque {
    return p_get_dict(m);
}
export fn jpy_PyRun_String(s: [*:0]const u8, start: c_int, g: ?*anyopaque, l: ?*anyopaque) ?*anyopaque {
    return p_run_string(s, start, g, l);
}
export fn jpy_PyLong_AsLong(o: ?*anyopaque) c_long {
    return p_long_aslong(o);
}
export fn jpy_PyEval_SaveThread() ?*anyopaque {
    return p_save_thread();
}
export fn jpy_PyEval_RestoreThread(s: ?*anyopaque) void {
    p_restore_thread(s);
}
export fn jpy_PyGILState_Ensure() c_int {
    return p_gil_ensure();
}
export fn jpy_PyGILState_Release(s: c_int) void {
    p_gil_release(s);
}
export fn jpy_PyObject_CallOneArg(callable: ?*anyopaque, arg: ?*anyopaque) ?*anyopaque {
    return p_call_one(callable, arg);
}
export fn jpy_PyUnicode_FromString(s: [*:0]const u8) ?*anyopaque {
    return p_uni_from(s);
}
export fn jpy_PyUnicode_AsUTF8(o: ?*anyopaque) ?[*:0]const u8 {
    return p_uni_utf8(o);
}
export fn jpy_Py_DecRef(o: ?*anyopaque) void {
    p_decref(o);
}
