//! Shared CPython embed core for the Jac single-binary runtime.
//!
//! This is the ONE place that knows how to bring up the bundled, hermetic
//! CPython for any Jac host -- the headless `jac` CLI launcher (launcher.zig)
//! AND the `na`-compiled desktop host (via the libjacpyembed shim, pyembed.zig).
//! Before this module the launcher did materialize + env + dlopen + program-name
//! pinning inline; the desktop host bound the *build machine's* libpython by
//! soname instead. Both now route through here, so "where does the interpreter
//! come from" has a single source of responsibility.
//!
//! What it owns (and nothing more -- no argv, no BOOT_SRC, no worker mode; those
//! belong to each frontend):
//!
//!   1. materialize the trailer payload to `<cache>/rt/<hash16>-<pathhash>/` (runtime.zig),
//!   2. set the hermetic PYTHONHOME/PYTHONPATH/JAC_* env so a foreign/venv
//!      interpreter can never be adopted,
//!   3. dlopen the bundled libpython (RTLD_NOW|GLOBAL) -- GLOBAL so the embedded
//!      interpreter's own C-extensions resolve against it,
//!   4. pin the program name to the host binary (pre-Py_Initialize) so getpath
//!      cannot fall back to a PATH `python3` / venv prefix.
//!
//! It deliberately does NOT call Py_Initialize: the launcher's worker mode
//! (Py_BytesMain) forks between dlopen and init, and the desktop host wants to
//! resolve a few symbols of its own first. Callers drive Py_Initialize via the
//! resolved symbols. The interpreter is otherwise hermetic and self-contained.

const std = @import("std");
const builtin = @import("builtin");
const runtime = @import("runtime.zig");
const Io = std.Io;

/// libc env mutation (not surfaced by std); must run before Py init reads env.
extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: c_int) c_int;

/// Bundled CPython minor version. Must stay in lockstep with payload.zig
/// (PBS_PY / py_ver) staging; it names the dlopened libpython and the
/// lib-dynload path. A single bump point for the embedded interpreter, shared by
/// every frontend that embeds it.
pub const py_ver = "3.14";

pub const lib_basename = switch (builtin.os.tag) {
    .macos => "libpython" ++ py_ver ++ ".dylib",
    else => "libpython" ++ py_ver ++ ".so",
};

// ── CPython C-API entry points resolved via dlsym ───────────────────────────
// Opaque pointers stand in for wchar_t* so we never need Python.h / CPython
// struct layouts. Shared so every frontend types its symbols identically.
pub const Py_Initialize_t = *const fn () callconv(.c) void;
pub const Py_DecodeLocale_t = *const fn (arg: [*:0]const u8, size: ?*usize) callconv(.c) ?*anyopaque;
pub const Py_SetProgramName_t = *const fn (name: ?*anyopaque) callconv(.c) void;
pub const PySys_SetArgvEx_t = *const fn (argc: c_int, argv: ?[*]?*anyopaque, updatepath: c_int) callconv(.c) void;
pub const PyMem_RawFree_t = *const fn (p: ?*anyopaque) callconv(.c) void;
pub const PyRun_SimpleString_t = *const fn (cmd: [*:0]const u8) callconv(.c) c_int;
pub const Py_FinalizeEx_t = *const fn () callconv(.c) c_int;
pub const Py_BytesMain_t = *const fn (argc: c_int, argv: [*c][*c]u8) callconv(.c) c_int;

pub const Error = error{
    PathTooLong,
    EnvSetupFailed,
    DlopenFailed,
    MissingSymbol,
};

const MAX_PATH = Io.Dir.max_path_bytes;

/// A live embedded interpreter handle: the dlopened libpython plus the resolved
/// runtime tree. Callers resolve whatever C-API symbols they need via `sym`.
pub const Embed = struct {
    /// dlopen handle for the bundled libpython (RTLD_NOW|GLOBAL).
    handle: *anyopaque,
    /// `<cache>/rt/<hash16>-<pathhash>` -- the materialized runtime tree (slice
    /// into the caller-provided rt_buf passed to `open`).
    rt: []const u8,

    /// Resolve a CPython (or any libpython-visible) symbol; null if absent.
    pub fn sym(self: *const Embed, comptime T: type, comptime name: [:0]const u8) ?T {
        const p = std.c.dlsym(self.handle, name) orelse return null;
        return @ptrCast(@alignCast(p));
    }

    /// Resolve a required symbol, erroring (not crashing) if it is missing -- the
    /// shim path must surface a clean failure to the host, never abort the process.
    pub fn symOrErr(self: *const Embed, comptime T: type, comptime name: [:0]const u8) Error!T {
        return self.sym(T, name) orelse Error.MissingSymbol;
    }

    /// Pin the interpreter's program name to `exe_z` (the host binary) BEFORE
    /// Py_Initialize. Otherwise getpath, unable to recover the embedding host's
    /// path, searches PATH for `python3` and an activated venv's pyvenv.cfg can
    /// shift sys.prefix to a foreign environment. PYTHONHOME pins base_prefix, but
    /// only an explicit program name stops the venv-prefix takeover. The decoded
    /// string is intentionally not freed -- CPython retains it.
    pub fn setProgramName(self: *const Embed, exe_z: [*:0]const u8) Error!void {
        const Py_DecodeLocale = try self.symOrErr(Py_DecodeLocale_t, "Py_DecodeLocale");
        const Py_SetProgramName = try self.symOrErr(Py_SetProgramName_t, "Py_SetProgramName");
        const wexe = Py_DecodeLocale(exe_z, null) orelse return Error.EnvSetupFailed;
        Py_SetProgramName(wexe);
    }
};

/// Materialize the runtime, set the hermetic env, and dlopen the bundled
/// libpython. Returns a handle the caller drives Py_Initialize / Py_BytesMain
/// through. Does NOT initialize the interpreter (see the module doc comment).
///
/// `exe_path` is the running host binary (carries the trailer payload and is the
/// program-name pin); `exe_z` is the same path NUL-terminated for env/getpath.
/// The cache-dir env strings and uid/pid are passed in so this module -- like
/// runtime.zig -- stays free of any process/libc-global assumptions and is
/// callable from both the launcher's `std.process.Init` and the shim's getenv.
pub fn open(
    io: Io,
    gpa: std.mem.Allocator,
    exe_path: []const u8,
    exe_z: [*:0]const u8,
    xdg_cache_home: ?[]const u8,
    home: ?[]const u8,
    tmpdir: ?[]const u8,
    uid: u32,
    pid: i32,
    rt_out: []u8,
) !Embed {
    // 1. Materialize (first run) or locate (warm) the runtime tree.
    const rt = try runtime.materialize(
        io,
        gpa,
        exe_path,
        xdg_cache_home,
        home,
        tmpdir,
        uid,
        pid,
        rt_out,
    );

    // 2. Hermetic env. PYTHONHOME/PYTHONPATH are load-bearing: without them
    //    Py_Initialize would adopt a foreign/absent interpreter. The lib-dynload
    //    entry guards pbs flavors that ship stdlib C-extensions as shared .so.
    var b_home: [MAX_PATH]u8 = undefined;
    var b_pp: [2 * MAX_PATH]u8 = undefined;
    var b_lib: [MAX_PATH]u8 = undefined;
    const pyhome = std.fmt.bufPrintZ(&b_home, "{s}/python", .{rt}) catch return Error.PathTooLong;
    const pythonpath = std.fmt.bufPrintZ(&b_pp, "{s}/site:{s}/python/lib/python" ++ py_ver ++ "/lib-dynload", .{ rt, rt }) catch return Error.PathTooLong;
    const libpath = std.fmt.bufPrintZ(&b_lib, "{s}/python/lib/{s}", .{ rt, lib_basename }) catch return Error.PathTooLong;

    if (setenv("PYTHONHOME", pyhome, 1) != 0) return Error.EnvSetupFailed;
    if (setenv("PYTHONPATH", pythonpath, 1) != 0) return Error.EnvSetupFailed;
    _ = setenv("PYTHONUTF8", "1", 1);
    // Force UTF-8 stdio directly: PYTHONUTF8 alone does not pin stdout/stderr
    // encoding under embedding, so a C/POSIX locale would crash on non-ASCII.
    _ = setenv("PYTHONIOENCODING", "utf-8", 1);
    _ = setenv("PYTHONDONTWRITEBYTECODE", "1", 1);
    _ = setenv("PYTHONNOUSERSITE", "1", 1);
    // Marker so code can tell it runs under the self-contained binary.
    _ = setenv("JAC_STANDALONE", "1", 1);
    // Path to the host binary, consumed by callers (CLI BOOT_SRC) to pin
    // sys.executable so re-spawns come back through the bundled interpreter.
    _ = setenv("JAC_EXECUTABLE", exe_z, 1);

    // 3. dlopen the bundled libpython. GLOBAL so the interpreter's own builtin
    //    C-extensions (and, on the desktop host, the forwarded Py_* the shim
    //    re-exports) resolve against this image.
    const handle = std.c.dlopen(libpath.ptr, .{ .NOW = true, .GLOBAL = true }) orelse
        return Error.DlopenFailed;

    return .{ .handle = handle, .rt = rt };
}
