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
//! What it owns (and nothing more -- no BOOT_SRC, no worker mode; those belong
//! to each frontend):
//!
//!   1. materialize the trailer payload to `<cache>/rt/<hash16>-<pathhash>/` (runtime.zig),
//!   2. dlopen the bundled libpython (RTLD_NOW|GLOBAL) -- GLOBAL so the embedded
//!      interpreter's own C-extensions resolve against it,
//!   3. configure + initialize the interpreter via the PEP 741 stable-ABI init
//!      API (`initInterpreter`): home / module search paths / program name are
//!      handed to CPython DIRECTLY, never through the process environment, so a
//!      foreign/venv interpreter can never be adopted AND nothing leaks into
//!      subprocesses the app spawns (#7047: PYTHONHOME/PYTHONPATH in environ
//!      killed every python-based child -- `aws` exec-credentials, plain
//!      `python3`, ...). Only jac-namespaced JAC_* markers go into the env.
//!
//! `open` deliberately does NOT initialize: the desktop host wants to resolve a
//! few symbols of its own between dlopen and init. Callers run `initInterpreter`
//! (or drive the resolved symbols themselves). The interpreter is fully hermetic:
//! ambient PYTHON* env vars are ignored (`use_environment=0`) and pass through
//! to children untouched.

const std = @import("std");
const builtin = @import("builtin");
const runtime = @import("runtime.zig");
const Io = std.Io;

/// libc env mutation (not surfaced by std); JAC_* markers only -- interpreter
/// config must NEVER go through the environment (children inherit it, #7047).
extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: c_int) c_int;

/// Bundled CPython minor version -- the ONE definition; payload.zig imports it
/// and comptime-asserts its PBS_PY patch pin matches. It names the dlopened
/// libpython and the lib-dynload path, shared by every frontend that embeds
/// the interpreter.
pub const py_ver = "3.14";

pub const lib_basename = switch (builtin.os.tag) {
    .macos => "libpython" ++ py_ver ++ ".dylib",
    else => "libpython" ++ py_ver ++ ".so",
};

/// `py_ver` with the dot removed -- names the stdlib zip (python314.zip).
const py_ver_compact = compact: {
    var buf: [py_ver.len]u8 = undefined;
    var n: usize = 0;
    for (py_ver) |ch| {
        if (ch != '.') {
            buf[n] = ch;
            n += 1;
        }
    }
    const out: [n]u8 = buf[0..n].*;
    break :compact &out;
};

// ── CPython C-API entry points resolved via dlsym ───────────────────────────
// Opaque pointers stand in for CPython structs so we never need Python.h.
// Shared so every frontend types its symbols identically. Initialization goes
// through the PEP 741 stable-ABI config API (available since the bundled 3.14):
// opaque PyInitConfig handle + string-keyed setters, so no struct layouts and
// no PYTHON* environment variables are ever involved.
pub const PyRun_SimpleString_t = *const fn (cmd: [*:0]const u8) callconv(.c) c_int;
pub const Py_FinalizeEx_t = *const fn () callconv(.c) c_int;
pub const Py_RunMain_t = *const fn () callconv(.c) c_int;
pub const PyInitConfig_Create_t = *const fn () callconv(.c) ?*anyopaque;
pub const PyInitConfig_Free_t = *const fn (cfg: ?*anyopaque) callconv(.c) void;
pub const PyInitConfig_GetError_t = *const fn (cfg: ?*anyopaque, err: *?[*:0]const u8) callconv(.c) c_int;
pub const PyInitConfig_GetExitCode_t = *const fn (cfg: ?*anyopaque, exitcode: *c_int) callconv(.c) c_int;
pub const PyInitConfig_SetInt_t = *const fn (cfg: ?*anyopaque, name: [*:0]const u8, value: i64) callconv(.c) c_int;
pub const PyInitConfig_SetStr_t = *const fn (cfg: ?*anyopaque, name: [*:0]const u8, value: [*:0]const u8) callconv(.c) c_int;
pub const PyInitConfig_SetStrList_t = *const fn (cfg: ?*anyopaque, name: [*:0]const u8, length: usize, items: [*]const [*:0]const u8) callconv(.c) c_int;
pub const Py_InitializeFromInitConfig_t = *const fn (cfg: ?*anyopaque) callconv(.c) c_int;

pub const Error = error{
    PathTooLong,
    EnvSetupFailed,
    DlopenFailed,
    MissingSymbol,
    InitFailed,
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

    /// Configure and initialize the embedded interpreter via PEP 741
    /// (Py_InitializeFromInitConfig). This is the ONE place the hermetic paths
    /// (home, stdlib search path) and the program-name pin are established --
    /// as *config values*, never environment variables, so:
    ///
    ///   * getpath can never adopt a PATH `python3` / activated-venv prefix
    ///     (explicit `program_name` + `home` stop the venv-prefix takeover), and
    ///   * NOTHING leaks into subprocesses (#7047): the app's children see the
    ///     exact environment the user launched the host with, including their
    ///     own PYTHONHOME/PYTHONPATH if they had any.
    ///
    /// `use_environment=0` makes hermeticity total: ambient PYTHON* vars cannot
    /// perturb the bundled runtime either. `opts` carries the per-frontend argv
    /// split (CLI boot vs `python`-compatible worker mode vs desktop host).
    ///
    /// Returns `null` on a normal init (the caller proceeds to run its boot
    /// script / Py_RunMain). Returns an exit code when the interpreter handled a
    /// print-and-exit flag during config (`-h`, `-V`, `--help` under
    /// parse_argv=1) and asked to quit: CPython already printed and did NOT
    /// finish initializing, so the caller must exit with that code WITHOUT
    /// running or finalizing anything. Without this the exit request surfaces as
    /// a generic init failure (the launcher's exit 70) -- e.g. `jac -V`.
    pub fn initInterpreter(self: *const Embed, exe_z: [*:0]const u8, opts: InitOpts) Error!?u8 {
        const Create = try self.symOrErr(PyInitConfig_Create_t, "PyInitConfig_Create");
        const Free = try self.symOrErr(PyInitConfig_Free_t, "PyInitConfig_Free");
        const GetError = try self.symOrErr(PyInitConfig_GetError_t, "PyInitConfig_GetError");
        const SetInt = try self.symOrErr(PyInitConfig_SetInt_t, "PyInitConfig_SetInt");
        const SetStr = try self.symOrErr(PyInitConfig_SetStr_t, "PyInitConfig_SetStr");
        const SetStrList = try self.symOrErr(PyInitConfig_SetStrList_t, "PyInitConfig_SetStrList");
        const InitFromConfig = try self.symOrErr(Py_InitializeFromInitConfig_t, "Py_InitializeFromInitConfig");

        var b_home: [MAX_PATH]u8 = undefined;
        const pyhome = std.fmt.bufPrintZ(&b_home, "{s}/python", .{self.rt}) catch return Error.PathTooLong;
        // The FULL module search path, spelled out (with use_environment=0,
        // getpath ignores `pythonpath_env`, so the env-free way to inject the
        // bundled site dir is to own the whole list). Same order the env-based
        // bring-up produced: the jac site first, then the stdlib triplet. The
        // lib-dynload entry guards pbs flavors that ship stdlib C-extensions
        // as shared .so.
        var b_site: [MAX_PATH]u8 = undefined;
        var b_dyn: [MAX_PATH]u8 = undefined;
        var b_zip: [MAX_PATH]u8 = undefined;
        var b_std: [MAX_PATH]u8 = undefined;
        var b_pkgs: [MAX_PATH]u8 = undefined;
        const search_paths = [_][*:0]const u8{
            std.fmt.bufPrintZ(&b_site, "{s}/site", .{self.rt}) catch return Error.PathTooLong,
            std.fmt.bufPrintZ(&b_dyn, "{s}/python/lib/python" ++ py_ver ++ "/lib-dynload", .{self.rt}) catch return Error.PathTooLong,
            std.fmt.bufPrintZ(&b_zip, "{s}/python/lib/python" ++ py_ver_compact ++ ".zip", .{self.rt}) catch return Error.PathTooLong,
            std.fmt.bufPrintZ(&b_std, "{s}/python/lib/python" ++ py_ver, .{self.rt}) catch return Error.PathTooLong,
            std.fmt.bufPrintZ(&b_pkgs, "{s}/python/lib/python" ++ py_ver ++ "/site-packages", .{self.rt}) catch return Error.PathTooLong,
        };

        const cfg = Create() orelse return Error.InitFailed;
        defer Free(cfg);
        // Check every call as it happens: the config stores only the most
        // recent error, so accumulating return codes and reporting at the end
        // could print the wrong failure (or none at all).
        const check = struct {
            fn f(get_error: PyInitConfig_GetError_t, c: ?*anyopaque, rc: c_int) Error!void {
                if (rc == 0) return;
                var err: ?[*:0]const u8 = null;
                if (get_error(c, &err) != 0) {
                    if (err) |msg| std.debug.print("jac (embed): python init failed: {s}\n", .{msg});
                }
                return Error.InitFailed;
            }
        }.f;

        try check(GetError, cfg, SetStr(cfg, "program_name", exe_z));
        try check(GetError, cfg, SetStr(cfg, "home", pyhome));
        try check(GetError, cfg, SetStrList(cfg, "module_search_paths", search_paths.len, &search_paths));
        // Total hermeticity + no-leak (the point of this API): ignore ambient
        // PYTHON* entirely; never read/write user site or bytecode caches.
        try check(GetError, cfg, SetInt(cfg, "use_environment", 0));
        try check(GetError, cfg, SetInt(cfg, "user_site_directory", 0));
        try check(GetError, cfg, SetInt(cfg, "write_bytecode", 0));
        // Force UTF-8 regardless of locale; pin stdio explicitly too -- utf8_mode
        // alone does not pin stdout/stderr under embedding, so a C/POSIX locale
        // would crash on non-ASCII output.
        try check(GetError, cfg, SetInt(cfg, "utf8_mode", 1));
        try check(GetError, cfg, SetStr(cfg, "stdio_encoding", "utf-8"));
        // PyInitConfig_Create starts from the *isolated* preset, which also turns
        // these off; the previous Py_Initialize/Py_BytesMain bring-up had them on
        // (Ctrl-C -> KeyboardInterrupt, buffered C stdio). Keep that behavior,
        // and keep sys.flags.isolated=0 as apps observed it before.
        try check(GetError, cfg, SetInt(cfg, "install_signal_handlers", 1));
        try check(GetError, cfg, SetInt(cfg, "configure_c_stdio", 1));
        try check(GetError, cfg, SetInt(cfg, "isolated", 0));
        if (opts.argv) |argv| {
            try check(GetError, cfg, SetStrList(cfg, "argv", argv.len, argv.ptr));
        }
        // parse_argv=1 == behave like the `python` CLI (worker mode: interpret
        // -c/-m/script from argv). parse_argv=0 == argv verbatim into sys.argv.
        // safe_path stays 0 (the isolated preset flips it to 1): worker mode
        // must keep python's path0 semantics -- '' for -c, cwd for -m -- or
        // `jac -m <module-in-cwd>` re-spawns break (tests/compiler/
        // test_importer.jac). The CLI boot never runs Py_RunMain, so no path0
        // is ever computed there and sys.path stays exactly module_search_paths
        // (same as the old PySys_SetArgvEx(updatepath=0) boot).
        try check(GetError, cfg, SetInt(cfg, "parse_argv", @intFromBool(opts.parse_argv)));
        try check(GetError, cfg, SetInt(cfg, "safe_path", 0));

        // The init call is special: a non-zero return can mean either a real
        // error OR a requested clean exit (worker mode processed -h/-V/--help and
        // already printed). PEP 741 reports the exit through PyInitConfig_GetExitCode
        // (note the capital C -- the lowercase spelling silently misses via dlsym),
        // which must be consulted FIRST -- otherwise the exit is misread as an init
        // failure and the launcher dies with exit 70 instead of the code CPython
        // asked for (0 for --help/--version, 2 for an unknown flag).
        if (InitFromConfig(cfg) != 0) {
            const GetExitCode = try self.symOrErr(PyInitConfig_GetExitCode_t, "PyInitConfig_GetExitCode");
            var exitcode: c_int = 0;
            if (GetExitCode(cfg, &exitcode) != 0) {
                // Exit codes are 8-bit; truncate rather than @intCast (which panics
                // on a negative/out-of-range c_int in checked builds).
                return @truncate(@as(u32, @bitCast(exitcode)));
            }
            var err: ?[*:0]const u8 = null;
            if (GetError(cfg, &err) != 0) {
                if (err) |msg| std.debug.print("jac (embed): python init failed: {s}\n", .{msg});
            }
            return Error.InitFailed;
        }
        return null;
    }
};

/// Frontend-specific initialization knobs for `Embed.initInterpreter`.
pub const InitOpts = struct {
    /// Process argv (argv[0] included) to hand the interpreter; null leaves
    /// CPython's default (`sys.argv == ['']`, the embedded-host convention).
    argv: ?[]const [*:0]const u8 = null,
    /// Parse argv like the `python` binary (-c/-m/script...). Worker mode only.
    parse_argv: bool = false,
};

/// Materialize the runtime and dlopen the bundled libpython. Returns a handle
/// the caller initializes via `initInterpreter` (see the module doc comment).
/// The ONLY env this sets is jac-namespaced (JAC_*); all interpreter
/// configuration is passed through the init config, never the environment.
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

    // 2. Env: jac-namespaced markers ONLY. The interpreter's own configuration
    //    (home, search paths, utf8, ...) goes through initInterpreter's PEP 741
    //    config so it can never leak into subprocesses (#7047).
    var b_lib: [MAX_PATH]u8 = undefined;
    const libpath = std.fmt.bufPrintZ(&b_lib, "{s}/python/lib/{s}", .{ rt, lib_basename }) catch return Error.PathTooLong;

    // Marker so code can tell it runs under the self-contained binary.
    if (setenv("JAC_STANDALONE", "1", 1) != 0) return Error.EnvSetupFailed;
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
