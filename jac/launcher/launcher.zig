//! jaclang single-binary launcher (Zig) -- dlopen embed.
//!
//! This executable carries the jaclang runtime + a private CPython as a
//! zstd-compressed payload appended after the image (see `runtime.zig`). On
//! first run it materializes that payload into a versioned cache dir, then
//! **dlopens** the bundled shared libpython and drives it in-process. Nothing
//! Python is linked at build time -- the launcher links only libc/libdl, exactly
//! the way jac-native loads LLVM/native code at runtime (llvmlite + ctypes).
//! No system Python, uv, or pip is required at install or runtime.
//!
//! Payload layout (materialized to `<cache>/rt/<hash16>/`):
//!     python/lib/libpython3.14.{dylib,so}   <- dlopened
//!     python/lib/python3.14/                 <- stdlib (.pyc)
//!     site/                                  <- jaclang + _jac_finder + llvmlite
//!
//! The pure-Zig materialization half (trailer parse, cache resolution,
//! zstd+tar extract, GC) lives in `runtime.zig` and is unit-tested separately.

const std = @import("std");
const builtin = @import("builtin");
const runtime = @import("runtime.zig");

/// libc env mutation (not surfaced by std); must run before Py init reads env.
extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: c_int) c_int;

// CPython C-API entry points we resolve via dlsym. Opaque pointers stand in for
// wchar_t* so we never need Python.h / CPython struct layouts.
const Py_Initialize_t = *const fn () callconv(.c) void;
const Py_DecodeLocale_t = *const fn (arg: [*:0]const u8, size: ?*usize) callconv(.c) ?*anyopaque;
// Sets the program full path getpath uses to derive sys.prefix/sys.executable.
// Pinned to *this* binary so getpath does not fall back to a PATH search for
// `python3` (see hermeticity note at the call site). Legacy but stable on 3.x,
// and consistent with the other pre-PyConfig init calls used here.
const Py_SetProgramName_t = *const fn (name: ?*anyopaque) callconv(.c) void;
const PySys_SetArgvEx_t = *const fn (argc: c_int, argv: ?[*]?*anyopaque, updatepath: c_int) callconv(.c) void;
const PyMem_RawFree_t = *const fn (p: ?*anyopaque) callconv(.c) void;
const PyRun_SimpleString_t = *const fn (cmd: [*:0]const u8) callconv(.c) c_int;
const Py_FinalizeEx_t = *const fn () callconv(.c) c_int;
// The standard `python` entry point: handles -c/-m/-u/argv exactly like the
// interpreter. Used for worker mode so the binary is a drop-in `sys.executable`.
const Py_BytesMain_t = *const fn (argc: c_int, argv: [*c][*c]u8) callconv(.c) c_int;

/// The validated boot dance: pin `sys.executable` to *this* binary, install the
/// lazy `.jac` finder, then hand off to the jaclang CLI, which reads `sys.argv`.
///
/// Pinning `sys.executable` is load-bearing: under embedding (Py_Initialize),
/// CPython's getpath cannot recover the launcher's own path and falls back to a
/// PATH search for `python3`, so `sys.executable` ends up pointing at a *foreign*
/// interpreter (e.g. /bin/python3). Anything that re-spawns `sys.executable`
/// then runs that foreign Python while inheriting our PYTHONHOME/PYTHONPATH ->
/// it loads our bundled 3.14 stdlib with the wrong libpython and dies importing
/// builtin C-extensions (_decimal/_contextvars). That is exactly how pytest-xdist
/// / execnet workers crash. Re-pointing it at this binary makes every re-spawn
/// come back through worker mode (Py_BytesMain), which has the right interpreter.
/// The path is passed in via the JAC_EXECUTABLE env var (set in `boot`) to avoid
/// embedding a runtime path into this compile-time string.
const BOOT_SRC =
    "import sys, os\n" ++
    "_exe = os.environ.get('JAC_EXECUTABLE')\n" ++
    "if _exe:\n" ++
    "    sys.executable = _exe\n" ++
    "    sys._base_executable = _exe\n" ++
    "import _jac_finder; _jac_finder.install()\n" ++
    "from jaclang.jac0core.cli_boot import start_cli\n" ++
    "start_cli()\n";

/// Bundled CPython minor version. Must stay in lockstep with payload.zig
/// (PBS_PY / py_ver) staging; it names the dlopened libpython and the
/// lib-dynload path below. A single bump point for the embedded interpreter.
const py_ver = "3.14";

const lib_basename = switch (builtin.os.tag) {
    .macos => "libpython" ++ py_ver ++ ".dylib",
    else => "libpython" ++ py_ver ++ ".so",
};

fn die(comptime msg: []const u8) noreturn {
    std.debug.print("jac (launcher): {s}\n", .{msg});
    std.process.exit(70); // EX_SOFTWARE
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const env = init.environ_map;

    // 1. Resolve our own path (Linux /proc/self/exe, macOS _NSGetExecutablePath).
    var exe_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const exe_len = std.process.executablePath(io, &exe_buf) catch die("cannot resolve executable path");
    const exe_path = exe_buf[0..exe_len];

    // 2. Materialize (first run) or locate (warm) the runtime tree.
    var rt_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const rt = runtime.materialize(
        io,
        init.gpa,
        exe_path,
        env.get("XDG_CACHE_HOME"),
        env.get("HOME"),
        env.get("TMPDIR"),
        @intCast(std.c.getuid()),
        @intCast(std.c.getpid()),
        &rt_buf,
    ) catch die("runtime materialization failed");

    // 3. dlopen the bundled libpython and boot in-process.
    std.process.exit(boot(rt, exe_path, init));
}

fn boot(rt: []const u8, exe_path: []const u8, init: std.process.Init) u8 {
    var b1: [std.Io.Dir.max_path_bytes]u8 = undefined;
    var b3: [std.Io.Dir.max_path_bytes]u8 = undefined;
    var ppbuf: [2 * std.Io.Dir.max_path_bytes]u8 = undefined;
    const home = std.fmt.bufPrintZ(&b1, "{s}/python", .{rt}) catch die("path too long");
    const libpath = std.fmt.bufPrintZ(&b3, "{s}/python/lib/{s}", .{ rt, lib_basename }) catch die("path too long");
    // PYTHONPATH = site + lib-dynload. The lib-dynload entry guards pbs flavors
    // that ship stdlib C-extensions as shared .so (e.g. linux-aarch64 noopt)
    // rather than compiled into libpython: in worker mode (Py_BytesMain) that dir
    // is otherwise not on sys.path even with PYTHONHOME set. (On the pinned
    // linux-x86_64 pgo+lto-full pbs nearly everything is *builtin* -- lib-dynload
    // carries only a few stdlib C-extensions -- so it is mostly redundant there;
    // the xdist worker crash that looked like a missing _decimal/_contextvars was
    // actually a wrong sys.executable, fixed via JAC_EXECUTABLE below. See
    // XDIST_LINUX_NOTES.md.)
    const pythonpath = std.fmt.bufPrintZ(&ppbuf, "{s}/site:{s}/python/lib/python" ++ py_ver ++ "/lib-dynload", .{ rt, rt }) catch die("path too long");

    // We own a private, hermetic interpreter: point it at our tree, force UTF-8,
    // never write bytecode (shipped stdlib is .pyc), ignore user site.
    // PYTHONHOME/PYTHONPATH are load-bearing: if setenv fails (e.g. environ full),
    // Py_Initialize would fall back to a foreign/absent interpreter with confusing
    // errors, so fail loudly instead.
    if (setenv("PYTHONHOME", home, 1) != 0) die("setenv PYTHONHOME failed");
    if (setenv("PYTHONPATH", pythonpath, 1) != 0) die("setenv PYTHONPATH failed");
    _ = setenv("PYTHONUTF8", "1", 1);
    // Force UTF-8 stdio directly. PYTHONUTF8 alone does not pin the stdout/stderr
    // encoding under this Py_Initialize path, so a C/POSIX locale (no LANG, as in
    // minimal containers/cron) would otherwise crash on non-ASCII output (emoji,
    // box-drawing) with UnicodeEncodeError.
    _ = setenv("PYTHONIOENCODING", "utf-8", 1);
    _ = setenv("PYTHONDONTWRITEBYTECODE", "1", 1);
    _ = setenv("PYTHONNOUSERSITE", "1", 1);
    // Marker so code can tell it runs under the self-contained binary (jaclang
    // materialized in the cache, always loaded) rather than a pip/editable
    // install. Set before the worker-mode branch so re-invoked workers inherit
    // it too. Used e.g. to skip pip-`.pth`-shim-specific tests.
    _ = setenv("JAC_STANDALONE", "1", 1);
    // Path to *this* binary, consumed by BOOT_SRC to pin `sys.executable` (see
    // the BOOT_SRC doc comment). Passed via env so no runtime path is baked into
    // the compile-time boot string. Children inherit it (harmless: worker mode
    // doesn't run BOOT_SRC and already resolves sys.executable correctly).
    var b_exe: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const exe_z = std.fmt.bufPrintZ(&b_exe, "{s}", .{exe_path}) catch die("path too long");
    _ = setenv("JAC_EXECUTABLE", exe_z, 1);

    const h = std.c.dlopen(libpath.ptr, .{ .NOW = true, .GLOBAL = true }) orelse
        die("dlopen libpython failed (payload not materialized?)");

    // Worker mode: when re-invoked as a Python interpreter (execnet/xdist and
    // multiprocessing re-spawn `sys.executable` with flags like `-u -c ...`),
    // behave exactly like `python` via Py_BytesMain instead of the jac CLI. The
    // env we set above points it at the bundled stdlib + site.
    if (isPythonInvocation(init)) {
        const Py_BytesMain: Py_BytesMain_t = sym(h, Py_BytesMain_t, "Py_BytesMain");
        // POSIX requires argv[argc] == NULL; reserve the last slot for it and
        // refuse a pathologically long argv rather than silently truncating.
        var argv_storage: [4096][*c]u8 = undefined;
        var n: usize = 0;
        var wit = init.minimal.args.iterate();
        while (wit.next()) |arg| {
            if (n >= argv_storage.len - 1) die("too many arguments");
            argv_storage[n] = @constCast(arg.ptr);
            n += 1;
        }
        argv_storage[n] = null;
        // Exit codes are 8-bit (the OS masks them). Truncate rather than @intCast,
        // which panics on a negative/out-of-range c_int in checked builds.
        const code = Py_BytesMain(@intCast(n), @ptrCast(&argv_storage));
        return @truncate(@as(u32, @bitCast(code)));
    }

    const Py_Initialize: Py_Initialize_t = sym(h, Py_Initialize_t, "Py_Initialize");
    const Py_DecodeLocale: Py_DecodeLocale_t = sym(h, Py_DecodeLocale_t, "Py_DecodeLocale");
    const Py_SetProgramName: Py_SetProgramName_t = sym(h, Py_SetProgramName_t, "Py_SetProgramName");
    const PySys_SetArgvEx: PySys_SetArgvEx_t = sym(h, PySys_SetArgvEx_t, "PySys_SetArgvEx");
    const PyMem_RawFree: PyMem_RawFree_t = sym(h, PyMem_RawFree_t, "PyMem_RawFree");
    const PyRun_SimpleString: PyRun_SimpleString_t = sym(h, PyRun_SimpleString_t, "PyRun_SimpleString");
    const Py_FinalizeEx: Py_FinalizeEx_t = sym(h, Py_FinalizeEx_t, "Py_FinalizeEx");

    // Hermeticity: pin the program name to this binary BEFORE init. Otherwise
    // getpath, unable to recover the launcher's own path under embedding, searches
    // PATH for `python3` -- and if an activated venv's bin is on PATH it adopts
    // that venv's pyvenv.cfg, shifting sys.prefix (and thus site-packages) to a
    // foreign environment. PYTHONHOME already pins base_prefix/stdlib, but only an
    // explicit program name stops the venv-prefix takeover. Our binary has no
    // adjacent pyvenv.cfg, so prefix stays the bundled runtime regardless of host.
    // The decoded string is intentionally not freed -- CPython retains it.
    const wexe = Py_DecodeLocale(exe_z.ptr, null) orelse die("failed to decode executable path");
    Py_SetProgramName(wexe);

    Py_Initialize();

    // sys.argv: decode each process arg to wchar_t* and hand CPython the vector.
    // updatepath=0 keeps the script dir off sys.path (isolation).
    var wargv: [4096]?*anyopaque = undefined;
    var argc: usize = 0;
    var it = init.minimal.args.iterate();
    while (it.next()) |arg| {
        if (argc >= wargv.len) die("too many arguments");
        // Py_DecodeLocale returns null on OOM; a null in the vector would make
        // PySys_SetArgvEx -> PyUnicode_FromWideChar segfault. Free what we have
        // and die instead.
        wargv[argc] = Py_DecodeLocale(arg.ptr, null) orelse {
            for (wargv[0..argc]) |w| PyMem_RawFree(w);
            die("failed to decode argument");
        };
        argc += 1;
    }
    PySys_SetArgvEx(@intCast(argc), &wargv, 0);
    for (wargv[0..argc]) |w| PyMem_RawFree(w);

    const rc = PyRun_SimpleString(BOOT_SRC);
    _ = Py_FinalizeEx();
    return if (rc == 0) 0 else 1;
}

/// True if argv[1] is a Python interpreter short flag (`-c`, `-u`, `-m`, `-`,
/// ...). Single-dash short flags mean "act like python"; jac subcommands (`run`,
/// `test`) and long flags (`--version`) keep the jac CLI.
fn isPythonInvocation(init: std.process.Init) bool {
    var it = init.minimal.args.iterate();
    _ = it.next(); // skip argv[0]
    if (it.next()) |a| {
        return a.len >= 1 and a[0] == '-' and (a.len == 1 or a[1] != '-');
    }
    return false;
}

fn sym(h: ?*anyopaque, comptime T: type, comptime name: [:0]const u8) T {
    return @ptrCast(@alignCast(std.c.dlsym(h, name) orelse die("libpython missing symbol: " ++ name)));
}

test {
    std.testing.refAllDecls(runtime);
}
