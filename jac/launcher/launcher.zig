//! jaclang single-binary launcher (Zig) -- dlopen embed.
//!
//! This executable carries the jaclang runtime + a private CPython as a
//! gzip-compressed payload appended after the image (see `runtime.zig`). On
//! first run it materializes that payload into a versioned cache dir, then
//! **dlopens** the bundled shared libpython and drives it in-process. Nothing
//! Python is linked at build time -- the launcher links only libc/libdl, exactly
//! the way jac-native loads LLVM at runtime (the LLVMPY_* shim + ctypes).
//! No system Python, uv, or pip is required at install or runtime.
//!
//! The materialize + hermetic-env + dlopen bring-up lives in `embed.zig`, shared
//! verbatim with the `na` desktop host (via the libjacpyembed shim). This file
//! is now just the *headless CLI frontend* over that shared core: worker mode
//! (drop-in `python`) and the jaclang CLI boot. The pure-Zig materialization
//! half (trailer parse, cache resolution, gzip+tar extract, GC) lives in
//! `runtime.zig` and is unit-tested separately.

const std = @import("std");
const builtin = @import("builtin");
const embed = @import("embed.zig");

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
/// The path is passed in via the JAC_EXECUTABLE env var (set by embed.open) to
/// avoid embedding a runtime path into this compile-time string.
const BOOT_SRC =
    "import sys, os\n" ++
    "_exe = os.environ.get('JAC_EXECUTABLE')\n" ++
    "if _exe:\n" ++
    "    sys.executable = _exe\n" ++
    "    sys._base_executable = _exe\n" ++
    "import _jac_finder as _jf\n" ++
    "_jf.apply_dev_source_override()\n" ++
    "_jf.install()\n" ++
    "from jaclang.jac0core.cli_boot import start_cli\n" ++
    "start_cli()\n";

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

    // NUL-terminated copy for env + getpath program-name pinning (embed sets
    // JAC_EXECUTABLE from it and uses it for Py_SetProgramName below).
    var b_exe: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const exe_z = std.fmt.bufPrintZ(&b_exe, "{s}", .{exe_path}) catch die("path too long");

    // 2. Shared bring-up: materialize the runtime, set the hermetic env, and
    //    dlopen the bundled libpython. Identical to what the desktop host does.
    //    `rt_buf` backs `emb.rt`, so it must outlive the boot below.
    var rt_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const emb = embed.open(
        io,
        init.gpa,
        exe_path,
        exe_z,
        env.get("XDG_CACHE_HOME"),
        env.get("HOME"),
        env.get("TMPDIR"),
        @intCast(std.c.getuid()),
        @intCast(std.c.getpid()),
        &rt_buf,
    ) catch die("runtime bring-up failed (payload not materialized?)");

    std.process.exit(boot(&emb, exe_z, init));
}

fn boot(emb: *const embed.Embed, exe_z: [*:0]const u8, init: std.process.Init) u8 {
    // Worker mode: when re-invoked as a Python interpreter (execnet/xdist and
    // multiprocessing re-spawn `sys.executable` with flags like `-u -c ...`),
    // behave exactly like `python` via Py_BytesMain instead of the jac CLI. The
    // hermetic env embed.open set points it at the bundled stdlib + site.
    if (isPythonInvocation(init)) {
        const Py_BytesMain = emb.symOrErr(embed.Py_BytesMain_t, "Py_BytesMain") catch die("libpython missing symbol: Py_BytesMain");
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

    const Py_Initialize = emb.symOrErr(embed.Py_Initialize_t, "Py_Initialize") catch die("libpython missing symbol: Py_Initialize");
    const Py_DecodeLocale = emb.symOrErr(embed.Py_DecodeLocale_t, "Py_DecodeLocale") catch die("libpython missing symbol: Py_DecodeLocale");
    const PySys_SetArgvEx = emb.symOrErr(embed.PySys_SetArgvEx_t, "PySys_SetArgvEx") catch die("libpython missing symbol: PySys_SetArgvEx");
    const PyMem_RawFree = emb.symOrErr(embed.PyMem_RawFree_t, "PyMem_RawFree") catch die("libpython missing symbol: PyMem_RawFree");
    const PyRun_SimpleString = emb.symOrErr(embed.PyRun_SimpleString_t, "PyRun_SimpleString") catch die("libpython missing symbol: PyRun_SimpleString");
    const Py_FinalizeEx = emb.symOrErr(embed.Py_FinalizeEx_t, "Py_FinalizeEx") catch die("libpython missing symbol: Py_FinalizeEx");

    // Hermeticity: pin the program name to this binary BEFORE init (see embed).
    emb.setProgramName(exe_z) catch die("failed to pin program name");

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

test {
    std.testing.refAllDecls(@import("runtime.zig"));
    std.testing.refAllDecls(embed);
}
