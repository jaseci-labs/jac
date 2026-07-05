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
//! The materialize + dlopen + config-init bring-up lives in `embed.zig`, shared
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
/// Pinning `sys.executable` is load-bearing: under embedding, getpath derives
/// `sys.executable` from the program name, and anything that re-spawns it must
/// come back through THIS binary -- worker mode below is what makes execnet /
/// pytest-xdist / multiprocessing re-spawns land on the right interpreter
/// instead of a foreign PATH `python3`.
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

    // NUL-terminated copy for the JAC_EXECUTABLE marker + the config's
    // program-name pin (initInterpreter below).
    var b_exe: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const exe_z = std.fmt.bufPrintZ(&b_exe, "{s}", .{exe_path}) catch die("path too long");

    // 2. Shared bring-up: materialize the runtime and dlopen the bundled
    //    libpython. Identical to what the desktop host does.
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
    // Collect argv once; both modes hand it to the interpreter through the
    // init config (no locale-decode dance -- PEP 741 takes char* directly).
    var argv_storage: [4096][*:0]const u8 = undefined;
    var argc: usize = 0;
    var it = init.minimal.args.iterate();
    while (it.next()) |arg| {
        if (argc >= argv_storage.len) die("too many arguments");
        argv_storage[argc] = arg.ptr;
        argc += 1;
    }
    const argv = argv_storage[0..argc];

    // Worker mode: when re-invoked as a Python interpreter (execnet/xdist and
    // multiprocessing re-spawn `sys.executable` with flags like `-u -c ...`),
    // behave exactly like `python` (parse_argv) instead of booting the jac CLI.
    const worker = isPythonInvocation(init);

    emb.initInterpreter(exe_z, .{ .argv = argv, .parse_argv = worker }) catch
        die("interpreter initialization failed");

    if (worker) {
        const Py_RunMain = emb.symOrErr(embed.Py_RunMain_t, "Py_RunMain") catch die("libpython missing symbol: Py_RunMain");
        // Py_RunMain executes the parsed -c/-m/script and finalizes. Exit codes
        // are 8-bit (the OS masks them). Truncate rather than @intCast, which
        // panics on a negative/out-of-range c_int in checked builds.
        return @truncate(@as(u32, @bitCast(Py_RunMain())));
    }

    const PyRun_SimpleString = emb.symOrErr(embed.PyRun_SimpleString_t, "PyRun_SimpleString") catch die("libpython missing symbol: PyRun_SimpleString");
    const Py_FinalizeEx = emb.symOrErr(embed.Py_FinalizeEx_t, "Py_FinalizeEx") catch die("libpython missing symbol: Py_FinalizeEx");

    const rc = PyRun_SimpleString(BOOT_SRC);
    _ = Py_FinalizeEx();
    return if (rc == 0) 0 else 1;
}

/// True if argv[1] is a Python interpreter short flag (`-c`, `-u`, `-m`, `-`,
/// ...). Single-dash short flags mean "act like python"; jac subcommands (`run`,
/// `test`) and long flags (`--version`) keep the jac CLI. This dispatch is a
/// CONTRACT: the jac CLI must never accept a single-dash short flag as its
/// first argument, or execnet/xdist worker re-spawns (`jac -u -c ...`) would
/// be misrouted.
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
